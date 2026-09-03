import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Scripture Unlock Gate
//
// Social media starts each day SHIELDED and stays shielded until the user does one
// spiritual discipline in Reforged — mark a chapter read, listen to a full chapter,
// or complete a memory-verse practice. Clearing the gate lifts the shield for the
// rest of the day; at midnight it re-locks.
//
// This is the inverse of SocialLimitService: that one gives time and takes it away
// as it's spent; this one gives nothing until the Word comes first. The two (and the
// always-on social block in FocusBlockingService) are mutually exclusive — enabling
// any one turns the others off, since all three shield the same social selection.
//
// How the midnight re-lock works: a daily DeviceActivity schedule ("unlockGate")
// fires `intervalDidStart` at 00:00, and the monitor extension re-applies the shield
// and resets the day. That way the gate closes even if the app is never launched.
// `refresh()` on foreground is the backstop for a missed callback (reboot, extension
// not woken).
//
// A dedicated ManagedSettingsStore ("reforged-unlock-gate") keeps this isolated from
// the other blocking features' stores.
//
// NOTE: keep the App Group keys below in sync with the monitor and shield extensions.

enum UnlockGateKeys {
    static let suite         = "group.com.reforged.app"
    static let enabled       = "unlockGateEnabled"
    static let dayKey        = "unlockGateDayKey"
    /// When today's gate was cleared. Absent = still locked.
    static let clearedAt     = "unlockGateClearedAt"
    /// Human label for what cleared it ("a chapter read", "a memory verse").
    static let clearedBy     = "unlockGateClearedBy"
    static let selectionData = "unlockGateSelectionData"
    /// True while the gate is armed and unmet — the shield extension reads this to
    /// render "do this to unlock" copy instead of the generic encouragement.
    static let pending       = "unlockGatePending"

    static let storeName     = "reforged-unlock-gate"
    static let activityName  = "unlockGate"

    static func todayKey() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

/// What satisfied the gate — used for the confirmation copy and the partner log.
enum UnlockGateAction: String {
    case chapterRead
    case chapterListened
    case memoryVerse

    var label: String {
        switch self {
        case .chapterRead:     return "a chapter read"
        case .chapterListened: return "a chapter listened to"
        case .memoryVerse:     return "a memory verse"
        }
    }
}

@MainActor
final class UnlockGateService: ObservableObject {

    static let shared = UnlockGateService()

    @Published var isEnabled: Bool = false
    /// Nil while today's gate is still locked.
    @Published private(set) var clearedAt: Date? = nil
    @Published private(set) var clearedBy: String? = nil

    private let defaults = UserDefaults(suiteName: UnlockGateKeys.suite)
    private let center = DeviceActivityCenter()

    private init() {
        isEnabled = defaults?.bool(forKey: UnlockGateKeys.enabled) ?? false
        loadClearedState()
    }

    // MARK: - Derived

    /// The social apps/categories to gate (shared with FocusBlockingService and the
    /// daily limit, so all three features agree on what "social media" means).
    private var selection: FamilyActivitySelection {
        FocusBlockingService.shared.socialSelection
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
        || !selection.categoryTokens.isEmpty
        || !selection.webDomainTokens.isEmpty
    }

    var isClearedToday: Bool { clearedAt != nil }

    /// True when the gate is actively holding social media shut right now.
    var isGateActive: Bool { isEnabled && hasSelection && !isClearedToday }

    var statusDescription: String {
        guard isEnabled else { return "Off" }
        guard hasSelection else { return "Choose social apps to gate" }
        if let by = clearedBy {
            return "Unlocked today with \(by)"
        }
        return "Locked until you open the Word"
    }

    // MARK: - Configuration

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults?.set(enabled, forKey: UnlockGateKeys.enabled)
        ShieldStreakService.shared.refreshProtectionState()

        if enabled {
            // All three social features shield the same apps — only one may own them.
            Task { await FocusBlockingService.shared.setBlockSocialMedia(false) }
            SocialLimitService.shared.setEnabled(false)
            // A fresh enable starts locked, whatever today's stale state said.
            resetDay(cleared: false)
            applyGate()
            startMonitoring()
        } else {
            stopMonitoring()
            clearGateShield()
            defaults?.set(false, forKey: UnlockGateKeys.pending)
        }
    }

    /// Re-applies the gate on launch/foreground and handles a day rollover the
    /// monitor extension may have missed.
    func refresh() {
        resetIfNewDay()
        loadClearedState()
        guard isEnabled, hasSelection else {
            clearGateShield()
            defaults?.set(false, forKey: UnlockGateKeys.pending)
            return
        }
        startMonitoring()
        applyGate()
    }

    /// Applies or lifts the shield to match today's cleared state.
    private func applyGate() {
        guard isEnabled, hasSelection else { return }
        if isClearedToday {
            clearGateShield()
            defaults?.set(false, forKey: UnlockGateKeys.pending)
        } else {
            shareSelection()
            applyGateShield()
            defaults?.set(true, forKey: UnlockGateKeys.pending)
        }
    }

    // MARK: - Clearing the Gate

    /// Called from the disciplines that satisfy the gate. Idempotent — clearing an
    /// already-cleared gate is a no-op, so hook sites don't need to check first.
    @discardableResult
    func clear(with action: UnlockGateAction) -> Bool {
        guard isEnabled, hasSelection else { return false }
        resetIfNewDay()
        guard !isClearedToday else { return false }

        let now = Date()
        clearedAt = now
        clearedBy = action.label
        defaults?.set(now, forKey: UnlockGateKeys.clearedAt)
        defaults?.set(action.label, forKey: UnlockGateKeys.clearedBy)
        defaults?.set(UnlockGateKeys.todayKey(), forKey: UnlockGateKeys.dayKey)
        defaults?.set(false, forKey: UnlockGateKeys.pending)
        clearGateShield()
        return true
    }

    // MARK: - Day Reset

    private func resetIfNewDay() {
        let today = UnlockGateKeys.todayKey()
        guard defaults?.string(forKey: UnlockGateKeys.dayKey) != today else { return }
        resetDay(cleared: false)
    }

    /// Rewrites today's gate state. `cleared: false` = locked again.
    private func resetDay(cleared: Bool) {
        clearedAt = nil
        clearedBy = nil
        defaults?.removeObject(forKey: UnlockGateKeys.clearedAt)
        defaults?.removeObject(forKey: UnlockGateKeys.clearedBy)
        defaults?.set(UnlockGateKeys.todayKey(), forKey: UnlockGateKeys.dayKey)
        defaults?.set(!cleared && isEnabled && hasSelection, forKey: UnlockGateKeys.pending)
    }

    private func loadClearedState() {
        // A stamp from an earlier day doesn't count — the gate re-locks at midnight.
        guard defaults?.string(forKey: UnlockGateKeys.dayKey) == UnlockGateKeys.todayKey() else {
            clearedAt = nil
            clearedBy = nil
            return
        }
        clearedAt = defaults?.object(forKey: UnlockGateKeys.clearedAt) as? Date
        clearedBy = defaults?.string(forKey: UnlockGateKeys.clearedBy)
    }

    // MARK: - DeviceActivity Monitoring

    /// Arms the daily schedule whose `intervalDidStart` re-locks the gate at midnight.
    /// Unlike the daily limit, this registers no threshold events, so a redundant
    /// restart is harmless — but skip it anyway when already armed.
    private func startMonitoring() {
        guard hasSelection else { stopMonitoring(); return }
        shareSelection()

        let name = DeviceActivityName(UnlockGateKeys.activityName)
        guard !center.activities.contains(name) else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            debugLog("[UnlockGate] startMonitoring failed: \(error.localizedDescription)")
        }
    }

    private func stopMonitoring() {
        center.stopMonitoring([DeviceActivityName(UnlockGateKeys.activityName)])
    }

    // MARK: - Shield

    /// Shares the gated selection so the monitor extension can re-apply the shield
    /// at midnight without the app running.
    private func shareSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: UnlockGateKeys.selectionData)
        }
    }

    private var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(UnlockGateKeys.storeName))
    }

    private func applyGateShield() {
        let sel = selection
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
    }

    private func clearGateShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
