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

    @Published var showSuperscriptVerseNumbers: Bool {
        didSet { save(showSuperscriptVerseNumbers, forKey: Keys.showSuperscriptVerseNumbers) }
    }

    @Published var showParagraphHeadings: Bool {
        didSet { save(showParagraphHeadings, forKey: Keys.showParagraphHeadings) }
    }

    @Published var autoRestoreReadingLocation: Bool {
        didSet { save(autoRestoreReadingLocation, forKey: Keys.autoRestoreReadingLocation) }
    }

    @Published var persistentChapterNavigation: Bool {
        didSet { save(persistentChapterNavigation, forKey: Keys.persistentChapterNavigation) }
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

    @Published var memoryReviewReminders: Bool {
        didSet {
            save(memoryReviewReminders, forKey: Keys.memoryReviewReminders)
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

    // MARK: - Keys

    private enum Keys {
        static let fontSize = "settings.fontSize"
        static let fontType = "settings.fontType"
        static let lineSpacing = "settings.lineSpacing"
        static let verseFormatting = "settings.verseFormatting"
        static let themeMode = "settings.themeMode"
        static let defaultTranslation = "settings.defaultTranslation"
        static let showSuperscriptVerseNumbers = "settings.showSuperscriptVerseNumbers"
        static let showParagraphHeadings = "settings.showParagraphHeadings"
        static let autoRestoreReadingLocation = "settings.autoRestoreReadingLocation"
        static let persistentChapterNavigation = "settings.persistentChapterNavigation"
        static let playbackSpeed = "settings.playbackSpeed"
        static let skipInterval = "settings.skipInterval"
        static let continueAudioOnNavigate = "settings.continueAudioOnNavigate"
        static let enableSpacedRepetition = "settings.enableSpacedRepetition"
        static let dailyMemoryReminders = "settings.dailyMemoryReminders"
        static let dailyReminderTime = "settings.dailyReminderTime"
        static let dailyReminderHour = "settings.dailyReminderHour"
        static let dailyReminderMinute = "settings.dailyReminderMinute"
        static let readingPlanReminders = "settings.readingPlanReminders"
        static let memoryReviewReminders = "settings.memoryReviewReminders"
        static let lessonReminders = "settings.lessonReminders"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let syncEnabled = "settings.syncEnabled"
    }

    // MARK: - Initialization

    private init() {
        // Load Display Settings
        self.fontSize = FontSizeSetting(rawValue: UserDefaults.standard.string(forKey: Keys.fontSize) ?? "") ?? .medium
        self.fontType = FontTypeSetting(rawValue: UserDefaults.standard.string(forKey: Keys.fontType) ?? "") ?? .serif
        self.lineSpacing = LineSpacingSetting(rawValue: UserDefaults.standard.string(forKey: Keys.lineSpacing) ?? "") ?? .normal
        self.verseFormatting = VerseFormattingMode(rawValue: UserDefaults.standard.string(forKey: Keys.verseFormatting) ?? "") ?? .paragraph
        self.themeMode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: Keys.themeMode) ?? "") ?? .system

        // Load Bible Reading Settings
        self.defaultTranslation = BibleTranslation(rawValue: UserDefaults.standard.string(forKey: Keys.defaultTranslation) ?? "") ?? .esv
        self.showSuperscriptVerseNumbers = UserDefaults.standard.object(forKey: Keys.showSuperscriptVerseNumbers) as? Bool ?? true
        self.showParagraphHeadings = UserDefaults.standard.object(forKey: Keys.showParagraphHeadings) as? Bool ?? true
        self.autoRestoreReadingLocation = UserDefaults.standard.object(forKey: Keys.autoRestoreReadingLocation) as? Bool ?? true
        self.persistentChapterNavigation = UserDefaults.standard.object(forKey: Keys.persistentChapterNavigation) as? Bool ?? true

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
        self.memoryReviewReminders = UserDefaults.standard.object(forKey: Keys.memoryReviewReminders) as? Bool ?? true
        self.lessonReminders = UserDefaults.standard.object(forKey: Keys.lessonReminders) as? Bool ?? true
        self.notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool ?? true

        // Load Sync Settings
        self.syncEnabled = UserDefaults.standard.object(forKey: Keys.syncEnabled) as? Bool ?? true

        // Sync to BibleReadingSettings on initialization
        syncToBibleReadingSettings()
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

    // MARK: - Computed Properties

    var scriptureFontSize: CGFloat {
        switch fontSize {
        case .small: return 14
        case .medium: return 17
        case .large: return 20
        case .extraLarge: return 24
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
    }

    func resetBibleSettings() {
        defaultTranslation = .esv
        showSuperscriptVerseNumbers = true
        showParagraphHeadings = true
        autoRestoreReadingLocation = true
        persistentChapterNavigation = true
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
        memoryReviewReminders = true
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
        switch mode {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        }
    }
}

// MARK: - BibleReadingSettings Sync Extension

extension SettingsManager {
    /// Syncs settings to the existing BibleReadingSettings class
    func syncToBibleReadingSettings() {
        let bibleSettings = BibleReadingSettings.shared

        // Sync font size
        switch fontSize {
        case .small:
            bibleSettings.fontSize = .small
        case .medium:
            bibleSettings.fontSize = .medium
        case .large:
            bibleSettings.fontSize = .large
        case .extraLarge:
            bibleSettings.fontSize = .extraLarge
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
