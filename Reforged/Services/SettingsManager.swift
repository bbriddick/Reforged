import SwiftUI
import Combine

// MARK: - Settings Manager

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Display & Formatting Settings

    @Published var fontSize: FontSizeSetting {
        didSet {
            save(fontSize.rawValue, forKey: Keys.fontSize)
            syncToBibleReadingSettings()
        }
    }

    @Published var fontType: FontTypeSetting {
        didSet {
            save(fontType.rawValue, forKey: Keys.fontType)
            syncToBibleReadingSettings()
        }
    }

    @Published var lineSpacing: LineSpacingSetting {
        didSet {
            save(lineSpacing.rawValue, forKey: Keys.lineSpacing)
            syncToBibleReadingSettings()
        }
    }

    @Published var verseFormatting: VerseFormattingMode {
        didSet {
            save(verseFormatting.rawValue, forKey: Keys.verseFormatting)
            syncToBibleReadingSettings()
        }
    }

    @Published var themeMode: ThemeMode {
        didSet {
            save(themeMode.rawValue, forKey: Keys.themeMode)
            updateTheme()
        }
    }

    // MARK: - Bible Reading Preferences

    @Published var defaultTranslation: BibleTranslation {
        didSet { save(defaultTranslation.rawValue, forKey: Keys.defaultTranslation) }
    }

    @Published var translationOrder: [BibleTranslation] {
        didSet { UserDefaults.standard.set(translationOrder.map(\.rawValue), forKey: Keys.translationOrder) }
    }

    @Published var readingMode: Bool {
        didSet { save(readingMode, forKey: Keys.readingMode) }
    }

    @Published var keepScreenOn: Bool {
        didSet { save(keepScreenOn, forKey: Keys.keepScreenOn) }
    }

    @Published var showSuperscriptVerseNumbers: Bool {
        didSet { save(showSuperscriptVerseNumbers, forKey: Keys.showSuperscriptVerseNumbers) }
    }

    @Published var showParagraphHeadings: Bool {
        didSet { save(showParagraphHeadings, forKey: Keys.showParagraphHeadings) }
    }

    @Published var showRedLetterText: Bool {
        didSet { save(showRedLetterText, forKey: Keys.showRedLetterText) }
    }

    @Published var autoRestoreReadingLocation: Bool {
        didSet { save(autoRestoreReadingLocation, forKey: Keys.autoRestoreReadingLocation) }
    }

    @Published var persistentChapterNavigation: Bool {
        didSet { save(persistentChapterNavigation, forKey: Keys.persistentChapterNavigation) }
    }

    @Published var showOriginalLanguageText: Bool {
        didSet { save(showOriginalLanguageText, forKey: Keys.showOriginalLanguageText) }
    }

    @Published var showOriginalLanguagesInSwitcher: Bool {
        didSet { save(showOriginalLanguagesInSwitcher, forKey: Keys.showOriginalLanguagesInSwitcher) }
    }

    // MARK: - Audio Settings

    @Published var playbackSpeed: PlaybackSpeed {
        didSet { save(playbackSpeed.rawValue, forKey: Keys.playbackSpeed) }
    }

    @Published var skipInterval: SkipInterval {
        didSet { save(skipInterval.rawValue, forKey: Keys.skipInterval) }
    }

    @Published var continueAudioOnNavigate: Bool {
        didSet { save(continueAudioOnNavigate, forKey: Keys.continueAudioOnNavigate) }
    }

    // MARK: - Memory System Settings

    @Published var enableSpacedRepetition: Bool {
        didSet { save(enableSpacedRepetition, forKey: Keys.enableSpacedRepetition) }
    }

    @Published var dailyMemoryReminders: Bool {
        didSet { save(dailyMemoryReminders, forKey: Keys.dailyMemoryReminders) }
    }

    // MARK: - Notification Settings

    @Published var dailyReminderTime: Date {
        didSet {
            // Store hour and minute separately for robust persistence across timezones/DST
            let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
            save(components.hour ?? 8, forKey: Keys.dailyReminderHour)
            save(components.minute ?? 0, forKey: Keys.dailyReminderMinute)
            // Keep legacy key updated for backward compatibility
            save(dailyReminderTime.timeIntervalSince1970, forKey: Keys.dailyReminderTime)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    @Published var readingPlanReminders: Bool {
        didSet {
            save(readingPlanReminders, forKey: Keys.readingPlanReminders)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    /// Days of the week on which reading reminders fire (1 = Sunday … 7 = Saturday).
    /// An empty set is treated as every day.
    @Published var readingReminderDays: Set<Int> {
        didSet {
            save(Array(readingReminderDays), forKey: Keys.readingReminderDays)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    @Published var memoryReviewReminders: Bool {
        didSet {
            save(memoryReviewReminders, forKey: Keys.memoryReviewReminders)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    /// Days of the week on which memory-review reminders fire (1 = Sunday … 7 = Saturday).
    /// An empty set is treated as every day.
    @Published var memoryReminderDays: Set<Int> {
        didSet {
            save(Array(memoryReminderDays), forKey: Keys.memoryReminderDays)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    @Published var lessonReminders: Bool {
        didSet { save(lessonReminders, forKey: Keys.lessonReminders) }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            save(notificationsEnabled, forKey: Keys.notificationsEnabled)
            NotificationManager.shared.scheduleDailyReminder()
        }
    }

    // MARK: - Sync Preferences

    @Published var syncEnabled: Bool {
        didSet { save(syncEnabled, forKey: Keys.syncEnabled) }
    }

    // MARK: - Day Boundary Setting

    /// The hour at which a new "logical day" begins (0 = midnight, 22 = 10 PM, etc.).
    /// When set to a non-zero value, activity before that hour counts toward the previous day.
    @Published var dayStartHour: Int {
        didSet {
            save(dayStartHour, forKey: Keys.dayStartHour)
            // Mirror to the shared app-group suite so the widget can apply the same
            // day boundary when computing streaks.
            UserDefaults(suiteName: "group.com.reforged.app")?.set(dayStartHour, forKey: Keys.dayStartHour)
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let fontSize = "settings.fontSize"
        static let fontType = "settings.fontType"
        static let lineSpacing = "settings.lineSpacing"
        static let verseFormatting = "settings.verseFormatting"
        static let themeMode = "settings.themeMode"
        static let defaultTranslation = "settings.defaultTranslation"
        static let translationOrder = "settings.translationOrder"
        static let readingMode = "settings.readingMode"
        static let keepScreenOn = "settings.keepScreenOn"
        static let showSuperscriptVerseNumbers = "settings.showSuperscriptVerseNumbers"
        static let showParagraphHeadings = "settings.showParagraphHeadings"
        static let showRedLetterText = "settings.showRedLetterText"
        static let autoRestoreReadingLocation = "settings.autoRestoreReadingLocation"
        static let persistentChapterNavigation = "settings.persistentChapterNavigation"
        static let showOriginalLanguageText = "settings.showOriginalLanguageText"
        static let showOriginalLanguagesInSwitcher = "settings.showOriginalLanguagesInSwitcher"
        static let playbackSpeed = "settings.playbackSpeed"
        static let skipInterval = "settings.skipInterval"
        static let continueAudioOnNavigate = "settings.continueAudioOnNavigate"
        static let enableSpacedRepetition = "settings.enableSpacedRepetition"
        static let dailyMemoryReminders = "settings.dailyMemoryReminders"
        static let dailyReminderTime = "settings.dailyReminderTime"
        static let dailyReminderHour = "settings.dailyReminderHour"
        static let dailyReminderMinute = "settings.dailyReminderMinute"
        static let readingPlanReminders = "settings.readingPlanReminders"
        static let readingReminderDays = "settings.readingReminderDays"
        static let memoryReviewReminders = "settings.memoryReviewReminders"
        static let memoryReminderDays = "settings.memoryReminderDays"
        static let lessonReminders = "settings.lessonReminders"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let syncEnabled = "settings.syncEnabled"
        static let dayStartHour = "settings.dayStartHour"
    }

    // MARK: - Initialization

    private init() {
        // Load Display Settings
        self.fontSize = FontSizeSetting(rawValue: UserDefaults.standard.string(forKey: Keys.fontSize) ?? "") ?? .medium
        self.fontType = FontTypeSetting(rawValue: UserDefaults.standard.string(forKey: Keys.fontType) ?? "") ?? .serif
        self.lineSpacing = LineSpacingSetting(rawValue: UserDefaults.standard.string(forKey: Keys.lineSpacing) ?? "") ?? .normal
        self.verseFormatting = VerseFormattingMode(rawValue: UserDefaults.standard.string(forKey: Keys.verseFormatting) ?? "") ?? .paragraph
        self.themeMode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: Keys.themeMode) ?? "") ?? .system

        // Load Display Settings (continued)
        self.readingMode = UserDefaults.standard.object(forKey: Keys.readingMode) as? Bool ?? false
        self.keepScreenOn = UserDefaults.standard.object(forKey: Keys.keepScreenOn) as? Bool ?? false

        // Load Bible Reading Settings
        self.defaultTranslation = BibleTranslation(rawValue: UserDefaults.standard.string(forKey: Keys.defaultTranslation) ?? "") ?? .kjv
        if let raw = UserDefaults.standard.array(forKey: Keys.translationOrder) as? [String] {
            let ordered = raw.compactMap { BibleTranslation(rawValue: $0) }.filter { !$0.isOriginalLanguage }
            let missing = BibleTranslation.allCases.filter { !$0.isOriginalLanguage && !ordered.contains($0) }
            self.translationOrder = ordered + missing
        } else {
            self.translationOrder = BibleTranslation.allCases.filter { !$0.isOriginalLanguage }
        }
        self.showSuperscriptVerseNumbers = UserDefaults.standard.object(forKey: Keys.showSuperscriptVerseNumbers) as? Bool ?? true
        self.showParagraphHeadings = UserDefaults.standard.object(forKey: Keys.showParagraphHeadings) as? Bool ?? true
        self.showRedLetterText = UserDefaults.standard.object(forKey: Keys.showRedLetterText) as? Bool ?? false
        self.autoRestoreReadingLocation = UserDefaults.standard.object(forKey: Keys.autoRestoreReadingLocation) as? Bool ?? true
        self.persistentChapterNavigation = UserDefaults.standard.object(forKey: Keys.persistentChapterNavigation) as? Bool ?? true
        self.showOriginalLanguageText = UserDefaults.standard.object(forKey: Keys.showOriginalLanguageText) as? Bool ?? true
        self.showOriginalLanguagesInSwitcher = UserDefaults.standard.object(forKey: Keys.showOriginalLanguagesInSwitcher) as? Bool ?? false

        // Load Audio Settings
        self.playbackSpeed = PlaybackSpeed(rawValue: UserDefaults.standard.string(forKey: Keys.playbackSpeed) ?? "") ?? .normal
        self.skipInterval = SkipInterval(rawValue: UserDefaults.standard.string(forKey: Keys.skipInterval) ?? "") ?? .tenSeconds
        self.continueAudioOnNavigate = UserDefaults.standard.object(forKey: Keys.continueAudioOnNavigate) as? Bool ?? false

        // Load Memory Settings
        self.enableSpacedRepetition = UserDefaults.standard.object(forKey: Keys.enableSpacedRepetition) as? Bool ?? true
        self.dailyMemoryReminders = UserDefaults.standard.object(forKey: Keys.dailyMemoryReminders) as? Bool ?? true

        // Load Notification Settings — prefer hour/minute keys, fall back to legacy timestamp
        let savedHour = UserDefaults.standard.object(forKey: Keys.dailyReminderHour) as? Int
        let savedMinute = UserDefaults.standard.object(forKey: Keys.dailyReminderMinute) as? Int
        if let hour = savedHour, let minute = savedMinute {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            self.dailyReminderTime = Calendar.current.date(from: components) ?? Self.defaultReminderTime()
        } else {
            let savedTime = UserDefaults.standard.double(forKey: Keys.dailyReminderTime)
            self.dailyReminderTime = savedTime > 0 ? Date(timeIntervalSince1970: savedTime) : Self.defaultReminderTime()
        }
        self.readingPlanReminders = UserDefaults.standard.object(forKey: Keys.readingPlanReminders) as? Bool ?? true
        let savedReadingDays = UserDefaults.standard.array(forKey: Keys.readingReminderDays) as? [Int]
        self.readingReminderDays = savedReadingDays.map { Set($0) } ?? Set(1...7)
        self.memoryReviewReminders = UserDefaults.standard.object(forKey: Keys.memoryReviewReminders) as? Bool ?? true
        let savedMemoryDays = UserDefaults.standard.array(forKey: Keys.memoryReminderDays) as? [Int]
        self.memoryReminderDays = savedMemoryDays.map { Set($0) } ?? Set(1...7)
        self.lessonReminders = UserDefaults.standard.object(forKey: Keys.lessonReminders) as? Bool ?? true
        self.notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool ?? true

        // Load Sync Settings
        self.syncEnabled = UserDefaults.standard.object(forKey: Keys.syncEnabled) as? Bool ?? true

        // Load Day Boundary Setting (default 0 = midnight)
        self.dayStartHour = UserDefaults.standard.object(forKey: Keys.dayStartHour) as? Int ?? 0

        // Sync to BibleReadingSettings on initialization
        syncToBibleReadingSettings()
        // Apply the loaded theme so ThemeManager reflects persisted value on startup
        updateTheme()
    }

    // MARK: - Helper Methods

    private func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private static func defaultReminderTime() -> Date {
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func updateTheme() {
        ThemeManager.shared.setTheme(themeMode)
    }

    // MARK: - Day Boundary Utility

    /// Returns the current "logical date" as a YYYY-MM-DD string, accounting for a custom day start hour.
    /// If `dayStartHour` is non-zero and the current hour is before that threshold,
    /// we are still in yesterday's logical day.
    func currentLogicalDateString() -> String {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let logicalDate = (dayStartHour > 0 && currentHour < dayStartHour)
            ? (calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            : now
        // Use local-timezone DateFormatter — ISO8601DateFormatter formats in UTC and
        // produces wrong date keys for users in UTC-negative timezones reading in the evening.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: logicalDate)
    }

    // MARK: - Computed Properties

    var scriptureFontSize: CGFloat {
        switch fontSize {
        case .tiny:       return 10
        case .extraSmall: return 12
        case .small:      return 15
        case .medium:     return 17
        case .large:      return 20
        case .extraLarge: return 24
        case .huge:       return 29
        case .massive:    return 36
        }
    }

    var scriptureFont: Font {
        let size = scriptureFontSize
        switch fontType {
        case .serif:
            return .system(size: size, design: .serif)
        case .sansSerif:
            return .system(size: size, design: .default)
        case .dyslexiaFriendly:
            return .system(size: size, design: .rounded)
        }
    }

    // MARK: - Reset Methods

    func resetDisplaySettings() {
        fontSize = .medium
        fontType = .serif
        lineSpacing = .normal
        verseFormatting = .paragraph
        themeMode = .system
        readingMode = false
        keepScreenOn = false
    }

    func resetBibleSettings() {
        defaultTranslation = .kjv
        translationOrder = BibleTranslation.allCases.filter { !$0.isOriginalLanguage }
        showSuperscriptVerseNumbers = true
        showParagraphHeadings = true
        autoRestoreReadingLocation = true
        persistentChapterNavigation = true
        showOriginalLanguageText = true
        showOriginalLanguagesInSwitcher = false
        dayStartHour = 0
    }

    func resetAudioSettings() {
        playbackSpeed = .normal
        skipInterval = .tenSeconds
        continueAudioOnNavigate = false
    }

    func resetMemorySettings() {
        enableSpacedRepetition = true
        dailyMemoryReminders = true
    }

    func resetNotificationSettings() {
        dailyReminderTime = Self.defaultReminderTime()
        readingPlanReminders = true
        readingReminderDays = Set(1...7)
        memoryReviewReminders = true
        memoryReminderDays = Set(1...7)
        lessonReminders = true
        notificationsEnabled = true
    }

    func resetAllSettings() {
        resetDisplaySettings()
        resetBibleSettings()
        resetAudioSettings()
        resetMemorySettings()
        resetNotificationSettings()
        syncEnabled = true
    }

    // MARK: - Cache Management

    func clearLocalCache() {
        // Clear all translation caches
        ESVService.shared.clearCache()
        KJVService.shared.clearCache()
        ApiBibleService.shared.clearCache()

        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()

        // Clear any temporary files
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - ThemeManager Extension

extension ThemeManager {
    func setTheme(_ mode: ThemeMode) {
        currentMode = mode
    }
}

// MARK: - BibleReadingSettings Sync Extension

extension SettingsManager {
    /// Syncs settings to the existing BibleReadingSettings class
    func syncToBibleReadingSettings() {
        let bibleSettings = BibleReadingSettings.shared

        // Sync font size
        switch fontSize {
        case .tiny:       bibleSettings.fontSize = .tiny
        case .extraSmall: bibleSettings.fontSize = .extraSmall
        case .small:      bibleSettings.fontSize = .small
        case .medium:     bibleSettings.fontSize = .medium
        case .large:      bibleSettings.fontSize = .large
        case .extraLarge: bibleSettings.fontSize = .extraLarge
        case .huge:       bibleSettings.fontSize = .huge
        case .massive:    bibleSettings.fontSize = .massive
        }

        // Sync font type
        switch fontType {
        case .serif:
            bibleSettings.fontType = .serif
        case .sansSerif, .dyslexiaFriendly:
            bibleSettings.fontType = .sansSerif
        }

        // Sync line spacing
        switch lineSpacing {
        case .tight:
            bibleSettings.lineSpacing = .tight
        case .normal:
            bibleSettings.lineSpacing = .normal
        case .relaxed:
            bibleSettings.lineSpacing = .relaxed
        case .wide:
            bibleSettings.lineSpacing = .wide
        }

        // Sync verse formatting
        bibleSettings.verseByVerse = (verseFormatting == .verseByVerse)
    }
}
