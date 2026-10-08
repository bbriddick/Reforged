import Foundation

/// A single day's record of the guided Morning Routine.
///
/// One entry per local day (keyed by `ReadingStreakManager.currentDayKey` so the
/// day boundary matches the streak engine, not UTC). Stores just enough to show
/// "completed this morning" on Home and to re-display the day's reflection; the
/// prayer and gratitude prose is also written to the encrypted journal via
/// `JournalStorageManager` so it lives with the rest of the user's reflections.
struct MorningRoutineEntry: Codable, Identifiable, Equatable {
    /// Local day key, e.g. "2026-09-10". Also the stable id (one entry per day).
    let dayKey: String
    var id: String { dayKey }

    /// The scripture the routine was built around, for re-display.
    var scriptureReference: String
    var scriptureText: String

    /// Free-text prayer from the Prayer step.
    var prayerText: String
    /// Prayer-focus chips the user selected.
    var prayerFocuses: [String]

    /// The Gemini (or fallback) gratitude questions shown, paired 1:1 with answers.
    var gratitudeQuestions: [String]
    var gratitudeAnswers: [String]

    /// Reference of the verse reviewed in the Memory step (real or suggested-bank).
    var reviewedVerseReference: String?

    /// When the routine was finished. `nil` means started-but-not-completed.
    var completedAt: Date?

    var isComplete: Bool { completedAt != nil }
}
