import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Focus Session Service
//
// On-demand timed blocking ("Block distractions for 45 minutes while I read").
// The shield is applied immediately in-app when the session starts (waiting for
// DeviceActivity's intervalDidStart can lag by minutes); a one-shot activity
// ("focusSession") makes the monitor extension lift it at the end time even if
// the app has been killed. `reconcile()` on foreground is the backstop for a
// missed end callback.
//
// Difficulty ladder:
//   normal — end anytime.
//   strict — ending early requires the accountability PIN (enforced in the
//            view via PINEntryView); logged as a tamper event.
//   deep   — no early end; the session runs to completion.
//
// NOTE: keep the App Group keys below in sync with the monitor extension.

enum FocusSessionDifficulty: String, Codable, CaseIterable, Identifiable {
    case normal, strict, deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .strict: return "Strict"
        case .deep:   return "Deep"
        }
    }

    var detail: String {
        switch self {
        case .normal: return "End anytime"
        case .strict: return "PIN to end early"
        case .deep:   return "No ending early"
        }
    }
}

struct FocusSession: Codable, Equatable {
    let startedAt: Date
    let endsAt: Date
    let difficulty: FocusSessionDifficulty
}

enum FocusSessionKeys {
    static let suite          = "group.com.reforged.app"
    static let endsAt         = "focusSessionEndsAt"
    static let startedAt      = "focusSessionStartedAt"
    static let difficulty     = "focusSessionDifficulty"
    static let selectionData  = "focusSessionSelectionData"

    static let storeName      = "reforged-focus-session"
    static let activityName   = "focusSession"
    /// DeviceActivitySchedule rejects intervals under 15 minutes.
    static let durationsMinutes = [15, 25, 45, 60, 90]
}

@MainActor
final class FocusSessionService: ObservableObject {

    static let shared = FocusSessionService()

    @Published private(set) var activeSession: FocusSession?

    private let defaults = UserDefaults(suiteName: FocusSessionKeys.suite)
    private let center = DeviceActivityCenter()
    private var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusSessionKeys.storeName))
    }

    private init() {
        loadActiveSession()
        reconcile()
    }

    var isSessionActive: Bool {
        guard let session = activeSession else { return false }
        return Date() < session.endsAt
    }

    // MARK: - Lifecycle

    func start(durationMinutes: Int, difficulty: FocusSessionDifficulty, selection: FamilyActivitySelection) {
        guard !isSessionActive else { return }
        let minutes = max(FocusSessionKeys.durationsMinutes.first ?? 15, durationMinutes)
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .minute, value: minutes, to: now) else { return }

        let session = FocusSession(startedAt: now, endsAt: end, difficulty: difficulty)
        activeSession = session

        defaults?.set(now, forKey: FocusSessionKeys.startedAt)
        defaults?.set(end, forKey: FocusSessionKeys.endsAt)
        defaults?.set(difficulty.rawValue, forKey: FocusSessionKeys.difficulty)
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: FocusSessionKeys.selectionData)
        }

        // Shield now — the monitor's intervalDidStart can lag well behind "Start".
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        // One-shot schedule so the monitor lifts the shield at `end` even if the
        // app is killed in the meantime.
        let calendar = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(comps, from: now),
            intervalEnd: calendar.dateComponents(comps, from: end),
            repeats: false
        )
        do {
            center.stopMonitoring([DeviceActivityName(FocusSessionKeys.activityName)])
            try center.startMonitoring(DeviceActivityName(FocusSessionKeys.activityName), during: deviceSchedule)
        } catch {
            debugLog("[FocusSession] startMonitoring failed: \(error.localizedDescription)")
            // The in-app shield is already up; reconcile() will lift it at the
            // end time when the app next foregrounds.
        }
    }

    /// Ends the session early. `strict` callers must verify the PIN first;
    /// `deep` sessions never end early.
    @discardableResult
    func endEarly() -> Bool {
        guard let session = activeSession else { return false }
        if session.difficulty == .deep && Date() < session.endsAt {
            return false
        }
        tearDown()
        return true
    }

    /// Foreground backstop: lifts the shield if the end time passed while the
    /// monitor callback was missed (or never registered).
    func reconcile() {
        let storedEnd = defaults?.object(forKey: FocusSessionKeys.endsAt) as? Date
        if let end = storedEnd, Date() >= end {
            tearDown()
        } else if storedEnd == nil, activeSession != nil {
            // Monitor already cleaned up (session ended while backgrounded).
            activeSession = nil
        }
    }

    // MARK: - Private

    private func tearDown() {
        center.stopMonitoring([DeviceActivityName(FocusSessionKeys.activityName)])
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        defaults?.removeObject(forKey: FocusSessionKeys.endsAt)
        defaults?.removeObject(forKey: FocusSessionKeys.startedAt)
        defaults?.removeObject(forKey: FocusSessionKeys.difficulty)
        defaults?.removeObject(forKey: FocusSessionKeys.selectionData)
        activeSession = nil
    }

    private func loadActiveSession() {
        guard let end = defaults?.object(forKey: FocusSessionKeys.endsAt) as? Date,
              let start = defaults?.object(forKey: FocusSessionKeys.startedAt) as? Date,
              let raw = defaults?.string(forKey: FocusSessionKeys.difficulty),
              let difficulty = FocusSessionDifficulty(rawValue: raw) else {
            return
        }
        activeSession = FocusSession(startedAt: start, endsAt: end, difficulty: difficulty)
    }
}
