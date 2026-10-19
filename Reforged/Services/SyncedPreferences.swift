import Foundation

// MARK: - Synced preferences
//
// The choices that should follow a person to a new device: how Reforged looks and reads,
// which reminders they like, and which parts of the app tour they've already seen.
//
// What is deliberately NOT restored as "on":
//  • Notification permission and the reminder switches. Permission is per device, so the
//    "Finish setting up this device" card offers to turn reminders back on, using the
//    time and types saved here.
//  • Downloads and widgets (also per device).
//
// Stored in the CloudKit profile record for anyone signed in with iCloud available, and
// best-effort in the Supabase profile (`profiles.preferences`) for everyone else.

struct SyncedPreferences: Codable, Equatable {
    var translation: String?
    var themeMode: String?
    var fontSize: String?
    var fontType: String?
    var lineSpacing: String?
    var verseFormatting: String?
    var readingMode: Bool?
    var showSuperscriptVerseNumbers: Bool?
    var showParagraphHeadings: Bool?
    var showRedLetterText: Bool?
    var aiEnabled: Bool?
    var enableSpacedRepetition: Bool?
    var showFirstLetterHints: Bool?
    var reminders: ReminderPreferences?
    var tour: TourPreferences?
    var modifiedAt = Date()

    struct ReminderPreferences: Codable, Equatable {
        var masterOn: Bool
        var dailyMemory: Bool
        var readingPlan: Bool
        var memoryReview: Bool
        var lesson: Bool
        var streakFreeze: Bool
        var time: Date
        var readingDays: [Int]
        var memoryDays: [Int]

        /// True when the person actually had reminders running on their other device.
        var anyOn: Bool { masterOn && (dailyMemory || readingPlan || memoryReview || lesson || streakFreeze) }
    }

    struct TourPreferences: Codable, Equatable {
        var started: Bool
        var disabled: Bool
        var doneSections: [Int]
    }
}

@MainActor
extension SyncedPreferences {
    /// Snapshot of this device's current choices.
    static func capture() -> SyncedPreferences {
        let s = SettingsManager.shared
        var p = SyncedPreferences()
        p.translation = s.defaultTranslation.rawValue
        p.themeMode = s.themeMode.rawValue
        p.fontSize = s.fontSize.rawValue
        p.fontType = s.fontType.rawValue
        p.lineSpacing = s.lineSpacing.rawValue
        p.verseFormatting = s.verseFormatting.rawValue
        p.readingMode = s.readingMode
        p.showSuperscriptVerseNumbers = s.showSuperscriptVerseNumbers
        p.showParagraphHeadings = s.showParagraphHeadings
        p.showRedLetterText = s.showRedLetterText
        p.aiEnabled = s.aiEnabled
        p.enableSpacedRepetition = s.enableSpacedRepetition
        p.showFirstLetterHints = s.showFirstLetterHints
        p.reminders = ReminderPreferences(
            masterOn: s.notificationsEnabled,
            dailyMemory: s.dailyMemoryReminders,
            readingPlan: s.readingPlanReminders,
            memoryReview: s.memoryReviewReminders,
            lesson: s.lessonReminders,
            streakFreeze: s.streakFreezeReminders,
            time: s.dailyReminderTime,
            readingDays: Array(s.readingReminderDays).sorted(),
            memoryDays: Array(s.memoryReminderDays).sorted())
        p.tour = AppTour.shared.exportPreferences()
        return p
    }

    /// Applies the look-and-reading choices on a new device. Reminder switches stay OFF
    /// (see the note at the top); only the reminder TIME and days are applied, since a
    /// time on its own schedules nothing.
    func applyForRestore() {
        let s = SettingsManager.shared
        if let v = translation.flatMap(BibleTranslation.init(rawValue:)) { s.defaultTranslation = v }
        if let v = themeMode.flatMap(ThemeMode.init(rawValue:)) { s.themeMode = v }
        if let v = fontSize.flatMap(FontSizeSetting.init(rawValue:)) { s.fontSize = v }
        if let v = fontType.flatMap(FontTypeSetting.init(rawValue:)) { s.fontType = v }
        if let v = lineSpacing.flatMap(LineSpacingSetting.init(rawValue:)) { s.lineSpacing = v }
        if let v = verseFormatting.flatMap(VerseFormattingMode.init(rawValue:)) { s.verseFormatting = v }
        if let v = readingMode { s.readingMode = v }
        if let v = showSuperscriptVerseNumbers { s.showSuperscriptVerseNumbers = v }
        if let v = showParagraphHeadings { s.showParagraphHeadings = v }
        if let v = showRedLetterText { s.showRedLetterText = v }
        if let v = aiEnabled { s.aiEnabled = v }
        if let v = enableSpacedRepetition { s.enableSpacedRepetition = v }
        if let v = showFirstLetterHints { s.showFirstLetterHints = v }
        if let r = reminders {
            s.dailyReminderTime = r.time
            if !r.readingDays.isEmpty { s.readingReminderDays = Set(r.readingDays) }
            if !r.memoryDays.isEmpty { s.memoryReminderDays = Set(r.memoryDays) }
        }
        AppTour.shared.restore(from: tour)
    }
}
