import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

// MARK: - Device Activity Monitor (social daily limit)
//
// Enforces the social-media daily usage limit. Threshold events are registered by
// the app (SocialLimitService) every 5 minutes from the base limit up to base+60.
// When social usage reaches an event's threshold, we shield the social apps IF
// that threshold has reached the user's CURRENT allowance (base + minutes earned
// today). Earning raises the allowance in the App Group and clears the shield;
// the next threshold at/above the new allowance re-applies it.
//
// Keep the App Group keys in sync with Reforged/Services/SocialLimitService.swift.

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
}

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let defaults = UserDefaults(suiteName: Keys.suite)
    private var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(Keys.storeName))
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

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
        // New day: reset earned time, usage, and lift the shield for the fresh allowance.
        let base = defaults?.object(forKey: Keys.baseMinutes) as? Int ?? Keys.defaultLimit
        defaults?.set(0, forKey: Keys.earnedToday)
        defaults?.set(0, forKey: Keys.usageMinutes)
        defaults?.set(false, forKey: Keys.shieldActive)
        defaults?.set(base, forKey: Keys.allowanceMinutes)
        defaults?.set(todayKey(), forKey: Keys.dayKey)
        clearShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearShield()
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
