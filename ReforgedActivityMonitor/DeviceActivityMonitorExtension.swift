import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

// MARK: - Device Activity Monitor
//
// One monitor extension handles three kinds of activities, branched by name:
//
//   "socialDailyLimit"  — the social-media daily usage limit. Threshold events
//     are registered by the app (SocialLimitService) every 5 minutes from the
//     base limit up to base+60. When usage reaches an event's threshold, we
//     shield the social apps IF that threshold has reached the user's CURRENT
//     allowance (base + minutes earned today). Earning raises the allowance in
//     the App Group and clears the shield.
//
//   "schedule_<uuid>"   — a time-window block (ScheduledBlockingService). The
//     interval start/end callbacks apply/clear that schedule's own store, with
//     the weekday check done here (one activity per schedule).
//
//   "focusSession"      — a one-shot timed session (FocusSessionService). The
//     app applies the shield immediately at start; we lift it at interval end
//     so the session finishes even if the app was killed.
//
//   "unlockGate"        — the Scripture unlock gate (UnlockGateService). A daily
//     interval whose start re-locks the social apps for the new day; the app
//     lifts the shield once the user reads/recites in Reforged.
//
// Keep the App Group keys in sync with Reforged/Services/SocialLimitService.swift,
// ScheduledBlockingService.swift, FocusSessionService.swift, and UnlockGateService.swift.

private enum Keys {
    static let suite            = "group.com.reforged.app"
    static let baseMinutes      = "socialLimitMinutes"
    static let allowanceMinutes = "socialAllowanceMinutes"
    static let earnedToday      = "socialEarnedTodayMinutes"
    static let dayKey           = "socialLimitDayKey"
    static let selectionData    = "socialLimitSelectionData"
    static let usageMinutes     = "socialUsageMinutes"
    static let shieldActive     = "socialLimitShieldActive"
    static let lastLimitNotifAt = "lastSocialLimitNotificationAt"
    static let monitorStartedAt = "socialLimitMonitorStartedAt"
    static let monitorGrace: TimeInterval = 20
    static let storeName        = "reforged-social-limit"
    static let defaultLimit     = 30

    static let socialActivity   = "socialDailyLimit"

    // Scheduled blocking (ScheduledBlockingService)
    static let schedulePrefix   = "schedule_"
    static let schedulesData    = "blockSchedulesData"
    static let scheduleActiveIds = "scheduleActiveIds"
    static func scheduleStoreName(_ id: String) -> String { "reforged-schedule-\(id)" }

    // Scripture unlock gate (UnlockGateService)
    static let gateActivity     = "unlockGate"
    static let gateStoreName    = "reforged-unlock-gate"
    static let gateEnabled      = "unlockGateEnabled"
    static let gateDayKey       = "unlockGateDayKey"
    static let gateClearedAt    = "unlockGateClearedAt"
    static let gateClearedBy    = "unlockGateClearedBy"
    static let gateSelection    = "unlockGateSelectionData"
    static let gatePending      = "unlockGatePending"

    // Focus sessions (FocusSessionService)
    static let focusActivity    = "focusSession"
    static let focusStoreName   = "reforged-focus-session"
    static let focusEndsAt      = "focusSessionEndsAt"
    static let focusStartedAt   = "focusSessionStartedAt"
    static let focusDifficulty  = "focusSessionDifficulty"
    static let focusSelection   = "focusSessionSelectionData"
}

/// Local mirror of the app's BlockSchedule — the extension can't import app
/// types; decode the same JSON shape. Keep fields in sync.
private struct BlockSchedule: Codable {
    var id: UUID
    var label: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var weekdays: Set<Int>
    var selectionData: Data
    var isEnabled: Bool
}

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let defaults = UserDefaults(suiteName: Keys.suite)
    private var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(Keys.storeName))
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue == Keys.socialActivity else { return }

        // Ignore the spurious burst of callbacks iOS fires immediately after
        // (re)arming monitoring — real usage can't cross a 5-min threshold this fast.
        if let started = defaults?.object(forKey: Keys.monitorStartedAt) as? Date,
           Date().timeIntervalSince(started) < Keys.monitorGrace {
            return
        }

        // Event name is "social_<minutes>".
        let minutes = Int(event.rawValue.split(separator: "_").last.map(String.init) ?? "") ?? 0

        // Record usage so the app can show a "time left today" countdown.
        let priorUsage = defaults?.integer(forKey: Keys.usageMinutes) ?? 0
        if minutes > priorUsage {
            defaults?.set(minutes, forKey: Keys.usageMinutes)
        }

        let allowance = currentAllowance()
        if minutes >= allowance {
            applyShield()
            // Notify once per "ran out" — only when transitioning into the shielded state.
            let wasActive = defaults?.bool(forKey: Keys.shieldActive) ?? false
            if !wasActive {
                defaults?.set(true, forKey: Keys.shieldActive)
                scheduleLimitReachedNotification()
            }
        } else {
            clearShield()
            defaults?.set(false, forKey: Keys.shieldActive)
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let name = activity.rawValue

        if name == Keys.socialActivity {
            // New day: reset earned time, usage, and lift the shield for the fresh allowance.
            let base = defaults?.object(forKey: Keys.baseMinutes) as? Int ?? Keys.defaultLimit
            defaults?.set(0, forKey: Keys.earnedToday)
            defaults?.set(0, forKey: Keys.usageMinutes)
            defaults?.set(false, forKey: Keys.shieldActive)
            defaults?.set(base, forKey: Keys.allowanceMinutes)
            defaults?.set(todayKey(), forKey: Keys.dayKey)
            clearShield()
        } else if name.hasPrefix(Keys.schedulePrefix) {
            scheduleWindowStarted(id: String(name.dropFirst(Keys.schedulePrefix.count)))
        } else if name == Keys.gateActivity {
            unlockGateDayStarted()
        }
        // focusSession: the app already applied the shield at start; nothing to do.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue

        if name == Keys.socialActivity {
            clearShield()
        } else if name.hasPrefix(Keys.schedulePrefix) {
            scheduleWindowEnded(id: String(name.dropFirst(Keys.schedulePrefix.count)))
        } else if name == Keys.focusActivity {
            focusSessionEnded()
        }
    }

    // MARK: - Scheduled Blocking

    private func loadSchedules() -> [BlockSchedule] {
        guard let data = defaults?.data(forKey: Keys.schedulesData),
              let decoded = try? JSONDecoder().decode([BlockSchedule].self, from: data) else {
            return []
        }
        return decoded
    }

    private func scheduleStore(id: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(Keys.scheduleStoreName(id)))
    }

    private func scheduleWindowStarted(id: String) {
        guard let schedule = loadSchedules().first(where: { $0.id.uuidString == id }),
              schedule.isEnabled else {
            clearStore(scheduleStore(id: id))
            return
        }
        // One activity per schedule; the weekday check happens here. The window
        // starts "today", so today's weekday decides whether it runs.
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard schedule.weekdays.contains(weekday),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: schedule.selectionData) else {
            clearStore(scheduleStore(id: id))
            return
        }
        let store = scheduleStore(id: id)
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        updateActiveIds(adding: id)
    }

    private func scheduleWindowEnded(id: String) {
        clearStore(scheduleStore(id: id))
        updateActiveIds(removing: id)
    }

    private func updateActiveIds(adding: String? = nil, removing: String? = nil) {
        var ids = Set(defaults?.stringArray(forKey: Keys.scheduleActiveIds) ?? [])
        if let adding { ids.insert(adding) }
        if let removing { ids.remove(removing) }
        defaults?.set(Array(ids), forKey: Keys.scheduleActiveIds)
    }

    // MARK: - Scripture Unlock Gate

    /// Midnight: the new day's gate starts locked. Wipes yesterday's cleared stamp
    /// and re-applies the shield so social media is shut until the user opens the
    /// Word in Reforged. There's no `intervalDidEnd` counterpart — the shield must
    /// persist through the 23:59→00:00 gap rather than being lifted for a minute.
    private func unlockGateDayStarted() {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(Keys.gateStoreName))
        guard defaults?.bool(forKey: Keys.gateEnabled) == true,
              let data = defaults?.data(forKey: Keys.gateSelection),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            clearStore(store)
            defaults?.set(false, forKey: Keys.gatePending)
            return
        }

        defaults?.removeObject(forKey: Keys.gateClearedAt)
        defaults?.removeObject(forKey: Keys.gateClearedBy)
        defaults?.set(todayKey(), forKey: Keys.gateDayKey)
        defaults?.set(true, forKey: Keys.gatePending)

        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
    }

    // MARK: - Focus Session

    private func focusSessionEnded() {
        clearStore(ManagedSettingsStore(named: ManagedSettingsStore.Name(Keys.focusStoreName)))
        defaults?.removeObject(forKey: Keys.focusEndsAt)
        defaults?.removeObject(forKey: Keys.focusStartedAt)
        defaults?.removeObject(forKey: Keys.focusDifficulty)
        defaults?.removeObject(forKey: Keys.focusSelection)
        scheduleSessionCompleteNotification()
    }

    private func scheduleSessionCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "Well done — you stayed the course. \"Let us run with endurance the race that is set before us.\" — Hebrews 12:1"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reforged.focussession.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func clearStore(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // MARK: - Helpers

    private func currentAllowance() -> Int {
        let base = defaults?.object(forKey: Keys.baseMinutes) as? Int ?? Keys.defaultLimit
        let stored = defaults?.object(forKey: Keys.allowanceMinutes) as? Int
        return stored ?? base
    }

    private func socialSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: Keys.selectionData),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return sel
    }

    private func applyShield() {
        guard let sel = socialSelection() else { return }
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// Fires a local notification when the daily social limit is reached, nudging
    /// the user to open Reforged instead. Lightly throttled via the App Group so a
    /// quick re-shield can't double-fire. Tapping it deep-links to a refocus passage
    /// (action handled in AppDelegate).
    private func scheduleLimitReachedNotification() {
        if let last = defaults?.object(forKey: Keys.lastLimitNotifAt) as? Date,
           Date().timeIntervalSince(last) < 60 {
            return
        }
        defaults?.set(Date(), forKey: Keys.lastLimitNotifAt)

        let content = UNMutableNotificationContent()
        content.title = "Time's up on social media"
        content.body = "You've used your social time for today. Open Reforged to listen to God's Word or study a memory verse."
        content.sound = .default
        content.userInfo = ["action": "social-limit"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reforged.sociallimit.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
