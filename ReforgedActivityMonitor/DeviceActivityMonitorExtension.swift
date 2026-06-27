import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

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

        // Event name is "social_<minutes>".
        let minutes = Int(event.rawValue.split(separator: "_").last.map(String.init) ?? "") ?? 0
        let allowance = currentAllowance()

        if minutes >= allowance {
            applyShield()
        } else {
            clearShield()
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New day: reset earned time and lift the shield for the fresh allowance.
        let base = defaults?.object(forKey: Keys.baseMinutes) as? Int ?? Keys.defaultLimit
        defaults?.set(0, forKey: Keys.earnedToday)
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

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
