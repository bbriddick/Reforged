import Foundation

/// Stores the per-day Morning Routine records.
///
/// UserDefaults-backed (Codable JSON), mirroring the app's other lightweight
/// per-day caches. Day keys come from `ReadingStreakManager.currentDayKey` so
/// "completed today" turns over with the user's local day. The sensitive prose
/// (prayer, gratitude) is additionally written to the encrypted journal by the
/// caller — this store only keeps what Home needs to show state and re-display.
@MainActor
final class MorningRoutineStorageManager: ObservableObject {
    static let shared = MorningRoutineStorageManager()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "reforged_morning_routine_entries"

    /// All entries, keyed by day. Published so the Home card updates on completion.
    @Published private(set) var entriesByDay: [String: MorningRoutineEntry] = [:]

    private init() {
        load()
    }

    // MARK: - Queries

    /// Today's key in the streak engine's local-day space.
    var todayKey: String { ReadingStreakManager.shared.currentDayKey }

    /// Today's entry, if the routine has been started or completed today.
    var todayEntry: MorningRoutineEntry? { entriesByDay[todayKey] }

    /// Whether today's routine has been finished.
    var isCompletedToday: Bool { todayEntry?.isComplete ?? false }

    // MARK: - Mutations

    /// Insert or replace an entry, keyed by its day.
    func save(_ entry: MorningRoutineEntry) {
        entriesByDay[entry.dayKey] = entry
        persist()
    }

    /// Convenience: mark today's routine complete with the collected reflection.
    func completeToday(
        scriptureReference: String,
        scriptureText: String,
        prayerText: String,
        prayerFocuses: [String],
        gratitudeQuestions: [String],
        gratitudeAnswers: [String],
        reviewedVerseReference: String?
    ) {
        let entry = MorningRoutineEntry(
            dayKey: todayKey,
            scriptureReference: scriptureReference,
            scriptureText: scriptureText,
            prayerText: prayerText,
            prayerFocuses: prayerFocuses,
            gratitudeQuestions: gratitudeQuestions,
            gratitudeAnswers: gratitudeAnswers,
            reviewedVerseReference: reviewedVerseReference,
            completedAt: Date()
        )
        save(entry)
    }

    /// Clears just today's entry so the routine can be walked again. Only touches
    /// this store — the reading streak (owned by `ReadingStreakManager`) is left
    /// exactly as it is, so redoing the routine never affects the streak.
    func resetToday() {
        entriesByDay[todayKey] = nil
        persist()
    }

    /// Clears all routine history (for "reset all progress").
    func deleteAll() {
        entriesByDay = [:]
        userDefaults.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: MorningRoutineEntry].self, from: data) else {
            return
        }
        entriesByDay = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entriesByDay) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
}
