import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Social Daily-Limit Service
//
// Enforces a daily *usage* limit on the user's chosen social apps via a
// DeviceActivityMonitor extension, and lets the user EARN more time by doing
// spiritual disciplines in Reforged (listening to a Bible chapter, completing a
// memory-verse activity).
//
// How the enforcement works (see ReforgedActivityMonitor):
//   • A daily schedule registers usage-threshold events every 5 minutes from the
//     base limit up to base+60 (the earn cap).
//   • When social usage reaches an event threshold, the monitor shields the social
//     apps IF that threshold has reached the user's CURRENT allowance.
//   • Earning raises the allowance (written to the App Group) and clears the shield;
//     the monitor re-shields once usage reaches the new, higher allowance.
//
// This makes earned time true *usage* minutes (exact to 5-min granularity) with no
// fragile timers. A dedicated ManagedSettingsStore ("reforged-social-limit") keeps
// it isolated from the always-on blocks in FocusBlockingService.
//
// NOTE: keep the App Group keys below in sync with the monitor extension.

enum SocialLimitKeys {
    static let suite              = "group.com.reforged.app"
    static let enabled            = "socialLimitEnabled"
    static let baseMinutes        = "socialLimitMinutes"
    static let allowanceMinutes   = "socialAllowanceMinutes"
    static let earnedTodayMinutes  = "socialEarnedTodayMinutes"
    static let dayKey             = "socialLimitDayKey"
    static let selectionData      = "socialLimitSelectionData"
    /// Highest usage threshold (minutes) the monitor has seen today — drives the
    /// in-app "time left" countdown. Granularity = `eventStep`.
    static let usageMinutes       = "socialUsageMinutes"
    /// Whether the monitor currently has the daily-limit shield applied.
    static let shieldActive       = "socialLimitShieldActive"
    /// Throttle for the "time's up" notification fired by the monitor.
    static let lastLimitNotifAt   = "lastSocialLimitNotificationAt"
    /// Signature (limit + selection) of the currently-armed monitoring, so we can
    /// avoid needlessly restarting DeviceActivity (restarts fire spurious events).
    static let monitorConfig      = "socialLimitMonitorConfig"
    /// When monitoring was last (re)armed. The monitor ignores threshold callbacks
    /// that arrive within `monitorGrace` of this, filtering the spurious burst iOS
    /// emits right after startMonitoring.
    static let monitorStartedAt   = "socialLimitMonitorStartedAt"
    static let monitorGrace: TimeInterval = 20

    static let storeName          = "reforged-social-limit"
    static let activityName       = "socialDailyLimit"
    static let defaultLimit       = 30
    static let dailyEarnCap       = 60
    static let chapterReward      = 15
    static let memoryReward       = 10
    static let eventStep          = 5

    static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

@MainActor
final class SocialLimitService: ObservableObject {

    static let shared = SocialLimitService()

    @Published var isEnabled: Bool = false
    @Published var limitMinutes: Int = SocialLimitKeys.defaultLimit
    @Published var earnedTodayMinutes: Int = 0
    /// Minutes of social usage the monitor has counted today (5-min granularity).
    @Published var usedTodayMinutes: Int = 0

    private let defaults = UserDefaults(suiteName: SocialLimitKeys.suite)
    private let center = DeviceActivityCenter()

    private init() {
        isEnabled          = defaults?.bool(forKey: SocialLimitKeys.enabled) ?? false
        limitMinutes       = defaults?.object(forKey: SocialLimitKeys.baseMinutes) as? Int ?? SocialLimitKeys.defaultLimit
        earnedTodayMinutes = defaults?.integer(forKey: SocialLimitKeys.earnedTodayMinutes) ?? 0
        usedTodayMinutes   = defaults?.integer(forKey: SocialLimitKeys.usageMinutes) ?? 0
        resetIfNewDay()
    }

    // MARK: - Derived

    /// The social apps/categories to monitor (shared with FocusBlockingService).
    private var selection: FamilyActivitySelection {
        FocusBlockingService.shared.socialSelection
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
        || !selection.categoryTokens.isEmpty
        || !selection.webDomainTokens.isEmpty
    }

    /// Today's total allowance = base limit + minutes earned today.
    var allowanceMinutes: Int { limitMinutes + earnedTodayMinutes }

    /// Approximate minutes of social time left today (never negative). Usage is
    /// tracked by the monitor at `eventStep` granularity, so this is a floor estimate.
    var remainingMinutes: Int { max(0, allowanceMinutes - usedTodayMinutes) }

    /// True once today's social usage has reached the current allowance.
    var isLimitReached: Bool { usedTodayMinutes >= allowanceMinutes }

    var canEarnMore: Bool { earnedTodayMinutes < SocialLimitKeys.dailyEarnCap }

    // MARK: - Configuration

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults?.set(enabled, forKey: SocialLimitKeys.enabled)
        if enabled {
            // Daily limit and always-on social block are mutually exclusive.
            Task { await FocusBlockingService.shared.setBlockSocialMedia(false) }
            // Fresh start: wipe any stale/poisoned usage + shield so the countdown
            // begins clean from "now" rather than inheriting a stuck state.
            startFreshDay()
            startMonitoring(force: true)
        } else {
            stopMonitoring()
        }
    }

    func setLimitMinutes(_ minutes: Int) {
        limitMinutes = max(5, minutes)
        defaults?.set(limitMinutes, forKey: SocialLimitKeys.baseMinutes)
        persistAllowance()
        // Thresholds shifted — must re-register the events.
        if isEnabled { startMonitoring(force: true) }
    }

    /// Resets today's usage/earn/shield state to a clean slate (shared App Group +
    /// published mirrors). Used when enabling the limit so a previously poisoned or
    /// stale count can't immediately trip the shield.
    private func startFreshDay() {
        earnedTodayMinutes = 0
        usedTodayMinutes = 0
        defaults?.set(0, forKey: SocialLimitKeys.earnedTodayMinutes)
        defaults?.set(0, forKey: SocialLimitKeys.usageMinutes)
        defaults?.set(false, forKey: SocialLimitKeys.shieldActive)
        defaults?.set(SocialLimitKeys.todayKey(), forKey: SocialLimitKeys.dayKey)
        persistAllowance()
        clearLimitShield()
    }

    /// Re-applies monitoring on launch/foreground (and handles the daily reset).
    func refresh() {
        resetIfNewDay()
        reloadUsage()
        if isEnabled && hasSelection {
            startMonitoring()
        }
    }

    /// Re-reads the usage the monitor has written to the App Group. Cheap; safe to
    /// call from a timer while the limit card is on screen so the countdown stays live.
    func reloadUsage() {
        let stored = defaults?.integer(forKey: SocialLimitKeys.usageMinutes) ?? 0
        if stored != usedTodayMinutes { usedTodayMinutes = stored }
    }

    // MARK: - Earning

    @discardableResult
    func grantForChapter() -> Bool { grant(SocialLimitKeys.chapterReward) }

    @discardableResult
    func grantForMemoryActivity() -> Bool { grant(SocialLimitKeys.memoryReward) }

    @discardableResult
    private func grant(_ minutes: Int) -> Bool {
        guard isEnabled, hasSelection else { return false }
        resetIfNewDay()
        guard canEarnMore else { return false }

        let reward = min(minutes, SocialLimitKeys.dailyEarnCap - earnedTodayMinutes)
        guard reward > 0 else { return false }

        earnedTodayMinutes += reward
        defaults?.set(earnedTodayMinutes, forKey: SocialLimitKeys.earnedTodayMinutes)
        persistAllowance()

        // Give immediate access; the monitor re-shields when usage reaches the
        // new, higher allowance.
        clearLimitShield()
        return true
    }

    // MARK: - Day Reset

    private func resetIfNewDay() {
        let today = SocialLimitKeys.todayKey()
        let stored = defaults?.string(forKey: SocialLimitKeys.dayKey)
        if stored != today {
            earnedTodayMinutes = 0
            usedTodayMinutes = 0
            defaults?.set(0, forKey: SocialLimitKeys.earnedTodayMinutes)
            defaults?.set(0, forKey: SocialLimitKeys.usageMinutes)
            defaults?.set(false, forKey: SocialLimitKeys.shieldActive)
            defaults?.set(today, forKey: SocialLimitKeys.dayKey)
            persistAllowance()
            clearLimitShield()
        }
    }

    private func persistAllowance() {
        defaults?.set(allowanceMinutes, forKey: SocialLimitKeys.allowanceMinutes)
    }

    // MARK: - DeviceActivity Monitoring

    /// A stable fingerprint of the monitoring config (limit + chosen apps). When this
    /// is unchanged and monitoring is already running, we must NOT restart — repeated
    /// stop/start churn makes DeviceActivity fire `eventDidReachThreshold` spuriously,
    /// which instantly slams usage to the cap and shields the apps (the "blocked 20s
    /// after opening" bug).
    private func currentSignature() -> String {
        let selData = (try? JSONEncoder().encode(selection)) ?? Data()
        return "\(limitMinutes)|\(selData.base64EncodedString())"
    }

    private func startMonitoring(force: Bool = false) {
        guard hasSelection else { stopMonitoring(); return }

        // Share the social selection so the monitor can apply the shield.
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: SocialLimitKeys.selectionData)
        }
        persistAllowance()

        // Skip the restart entirely if nothing changed and we're already monitoring.
        let signature = currentSignature()
        let alreadyMonitoring = center.activities.contains(DeviceActivityName(SocialLimitKeys.activityName))
        if !force, alreadyMonitoring, defaults?.string(forKey: SocialLimitKeys.monitorConfig) == signature {
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let apps = selection.applicationTokens
        let cats = selection.categoryTokens
        let webs = selection.webDomainTokens
        // Start thresholds at the first step (not the base limit) so usage is tracked
        // from the very first minutes — this drives the in-app countdown. The shield
        // itself is only applied once usage reaches the allowance (handled in the monitor).
        for m in stride(from: SocialLimitKeys.eventStep, through: limitMinutes + SocialLimitKeys.dailyEarnCap, by: SocialLimitKeys.eventStep) {
            events[DeviceActivityEvent.Name("social_\(m)")] = DeviceActivityEvent(
                applications: apps,
                categories: cats,
                webDomains: webs,
                threshold: DateComponents(minute: m)
            )
        }

        do {
            center.stopMonitoring([DeviceActivityName(SocialLimitKeys.activityName)])
            try center.startMonitoring(
                DeviceActivityName(SocialLimitKeys.activityName),
                during: schedule,
                events: events
            )
            defaults?.set(signature, forKey: SocialLimitKeys.monitorConfig)
            defaults?.set(Date(), forKey: SocialLimitKeys.monitorStartedAt)
        } catch {
            debugLog("[SocialLimit] startMonitoring failed: \(error.localizedDescription)")
        }
    }

    private func stopMonitoring() {
        center.stopMonitoring([DeviceActivityName(SocialLimitKeys.activityName)])
        defaults?.removeObject(forKey: SocialLimitKeys.monitorConfig)
        clearLimitShield()
    }

    private func clearLimitShield() {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(SocialLimitKeys.storeName))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        // Let the monitor re-notify if the user runs out again after earning more time.
        defaults?.set(false, forKey: SocialLimitKeys.shieldActive)
    }
}
