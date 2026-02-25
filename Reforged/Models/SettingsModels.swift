import SwiftUI

// MARK: - Font Size Settings

enum FontSizeSetting: String, CaseIterable, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }

    var bodyFont: Font {
        switch self {
        case .small: return .subheadline
        case .medium: return .body
        case .large: return .title3
        case .extraLarge: return .title2
        }
    }
}

// MARK: - Font Type Settings

enum FontTypeSetting: String, CaseIterable, Codable {
    case serif = "Serif"
    case sansSerif = "Sans-Serif"
    case dyslexiaFriendly = "Dyslexia-Friendly"

    var fontDesign: Font.Design {
        switch self {
        case .serif: return .serif
        case .sansSerif: return .default
        case .dyslexiaFriendly: return .rounded
        }
    }

    var fontName: String? {
        switch self {
        case .serif: return "Georgia"
        case .sansSerif: return nil // System default
        case .dyslexiaFriendly: return "OpenDyslexic" // Fallback to system rounded
        }
    }
}

// MARK: - Line Spacing Settings

enum LineSpacingSetting: String, CaseIterable, Codable {
    case tight = "Tight"
    case normal = "Normal"
    case relaxed = "Relaxed"
    case wide = "Wide"

    var spacing: CGFloat {
        switch self {
        case .tight: return 2
        case .normal: return 6
        case .relaxed: return 10
        case .wide: return 16
        }
    }
}

// MARK: - Verse Formatting Mode

enum VerseFormattingMode: String, CaseIterable, Codable {
    case verseByVerse = "Verse-by-Verse"
    case paragraph = "Paragraph"
}

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Audio Playback Speed

enum PlaybackSpeed: String, CaseIterable, Codable {
    case slow = "0.75x"
    case normal = "1x"
    case fast = "1.25x"
    case faster = "1.5x"
    case fastest = "2x"

    var rate: Float {
        switch self {
        case .slow: return 0.75
        case .normal: return 1.0
        case .fast: return 1.25
        case .faster: return 1.5
        case .fastest: return 2.0
        }
    }
}

// MARK: - Skip Interval

enum SkipInterval: String, CaseIterable, Codable {
    case fiveSeconds = "5s"
    case tenSeconds = "10s"
    case thirtySeconds = "30s"
    case byVerse = "By Verse"

    var seconds: Double {
        switch self {
        case .fiveSeconds: return 5
        case .tenSeconds: return 10
        case .thirtySeconds: return 30
        case .byVerse: return 0 // Special handling needed
        }
    }
}

// MARK: - Bible Translation

enum BibleTranslation: String, CaseIterable, Codable, Identifiable {
    case esv = "ESV"
    case kjv = "KJV"
    case csb = "CSB"
    case nkjv = "NKJV"
    case nasb = "NASB"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .esv: return "English Standard Version"
        case .kjv: return "King James Version"
        case .csb: return "Christian Standard Bible"
        case .nkjv: return "New King James Version"
        case .nasb: return "New American Standard Bible"
        }
    }

    var copyright: String {
        switch self {
        case .esv: return "© 2001 Crossway"
        case .kjv: return "Public Domain"
        case .csb: return "© 2017 Holman Bible Publishers"
        case .nkjv: return "© 1982 Thomas Nelson"
        case .nasb: return "© 1995 The Lockman Foundation"
        }
    }

    var attribution: String {
        switch self {
        case .esv:
            return "Scripture quotations marked ESV are taken from the ESV® Bible (The Holy Bible, English Standard Version®), Copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved. The ESV text may not be quoted in any publication made available to the public by a Creative Commons license. The ESV may not be translated into any other language. Website: www.crossway.org"
        case .kjv:
            return "Scripture quotations marked KJV are from the King James Version (KJV) of the Holy Bible, which is in the public domain."
        case .csb:
            return "Scripture quotations marked CSB are taken from the Christian Standard Bible®, Copyright © 2017 Holman Bible Publishers. Used by permission. All rights reserved. The CSB text may not be quoted in any publication made available to the public by a Creative Commons license. The CSB may not be translated into any other language. Website: www.csbible.com"
        case .nkjv:
            return "Scripture quotations marked NKJV are taken from the New King James Version®, Copyright © 1982 Thomas Nelson. Used by permission. All rights reserved. The NKJV text may not be quoted in any publication made available to the public by a Creative Commons license. The NKJV may not be translated into any other language. Website: www.thomasnelson.com"
        case .nasb:
            return "Scripture quotations marked NASB are taken from the (NASB®) New American Standard Bible®, Copyright © 1960, 1971, 1977, 1995 by The Lockman Foundation. Used by permission. All rights reserved. The NASB text may not be quoted in any publication made available to the public by a Creative Commons license. The NASB may not be translated into any other language. Website: www.lockman.org"
        }
    }

    /// Whether this translation uses the API.Bible service
    var usesApiBible: Bool {
        switch self {
        case .csb, .nkjv, .nasb: return true
        case .esv, .kjv: return false
        }
    }
}

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    case display = "Display & Formatting"
    case bibleReading = "Bible Reading"
    case audio = "Audio"
    case memory = "Memory"
    case notifications = "Notifications"
    case account = "Account & Data"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .display: return "textformat.size"
        case .bibleReading: return "book.fill"
        case .audio: return "speaker.wave.2.fill"
        case .memory: return "brain.head.profile"
        case .notifications: return "bell.fill"
        case .account: return "person.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .display: return .reforgedNavy
        case .bibleReading: return .reforgedNavy
        case .audio: return .reforgedNavy
        case .memory: return .reforgedGold
        case .notifications: return .reforgedCoral
        case .account: return .reforgedNavy
        case .about: return .gray
        }
    }
}
