import Foundation

// MARK: - User Profile Models

struct UserProfile: Codable {
    var id: String
    var firstName: String
    var lastName: String
    var displayName: String
    var email: String?
    var avatar: String
    var goals: [String]
    var xp: Int
    var level: Int
    var streak: Int
    var longestStreak: Int
    var lastActiveDate: String
    var badges: [Badge]
    var completedLessons: [String]
    var memoryVerses: [String]
    var onboardingCompleted: Bool
    var loggedIn: Bool
    var streakFreezes: Int
    var freezeUsedDates: [String]
    var lastFreezeReplenishMonth: String
    var activeDates: [String]
    var chaptersRead: [String]
    var weeklyActivity: WeeklyActivity
    var perks: [Perk]
    var activeProfileBorder: String
    var activeTheme: String
    var profileImagePath: String?

    init(id: String, firstName: String, lastName: String, displayName: String, email: String?, avatar: String, goals: [String], xp: Int, level: Int, streak: Int, longestStreak: Int, lastActiveDate: String, badges: [Badge], completedLessons: [String], memoryVerses: [String], onboardingCompleted: Bool, loggedIn: Bool, streakFreezes: Int, freezeUsedDates: [String], lastFreezeReplenishMonth: String = "", activeDates: [String], chaptersRead: [String], weeklyActivity: WeeklyActivity, perks: [Perk] = [], activeProfileBorder: String = "", activeTheme: String = "", profileImagePath: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = displayName
        self.email = email
        self.avatar = avatar
        self.goals = goals
        self.xp = xp
        self.level = level
        self.streak = streak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.badges = badges
        self.completedLessons = completedLessons
        self.memoryVerses = memoryVerses
        self.onboardingCompleted = onboardingCompleted
        self.loggedIn = loggedIn
        self.streakFreezes = streakFreezes
        self.freezeUsedDates = freezeUsedDates
        self.lastFreezeReplenishMonth = lastFreezeReplenishMonth
        self.activeDates = activeDates
        self.chaptersRead = chaptersRead
        self.weeklyActivity = weeklyActivity
        self.perks = perks
        self.activeProfileBorder = activeProfileBorder
        self.activeTheme = activeTheme
        self.profileImagePath = profileImagePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatar = try container.decode(String.self, forKey: .avatar)
        goals = try container.decode([String].self, forKey: .goals)
        xp = try container.decode(Int.self, forKey: .xp)
        level = try container.decode(Int.self, forKey: .level)
        streak = try container.decode(Int.self, forKey: .streak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastActiveDate = try container.decode(String.self, forKey: .lastActiveDate)
        badges = try container.decode([Badge].self, forKey: .badges)
        completedLessons = try container.decode([String].self, forKey: .completedLessons)
        memoryVerses = try container.decode([String].self, forKey: .memoryVerses)
        onboardingCompleted = try container.decode(Bool.self, forKey: .onboardingCompleted)
        loggedIn = try container.decode(Bool.self, forKey: .loggedIn)
        streakFreezes = try container.decode(Int.self, forKey: .streakFreezes)
        freezeUsedDates = try container.decode([String].self, forKey: .freezeUsedDates)
        lastFreezeReplenishMonth = (try? container.decode(String.self, forKey: .lastFreezeReplenishMonth)) ?? ""
        activeDates = try container.decode([String].self, forKey: .activeDates)
        chaptersRead = try container.decode([String].self, forKey: .chaptersRead)
        weeklyActivity = try container.decode(WeeklyActivity.self, forKey: .weeklyActivity)
        // Backward-compatible: new fields default if missing
        perks = (try? container.decode([Perk].self, forKey: .perks)) ?? []
        activeProfileBorder = (try? container.decode(String.self, forKey: .activeProfileBorder)) ?? ""
        activeTheme = (try? container.decode(String.self, forKey: .activeTheme)) ?? ""
        profileImagePath = try? container.decode(String.self, forKey: .profileImagePath)
    }

    /// Computed level based on XP thresholds
    var currentLevel: Int {
        // XP thresholds for each level
        let thresholds = [
            0,      // Level 1
            100,    // Level 2
            250,    // Level 3
            500,    // Level 4
            850,    // Level 5
            1300,   // Level 6
            1900,   // Level 7
            2600,   // Level 8
            3500,   // Level 9
            4600,   // Level 10
            5900,   // Level 11
            7400,   // Level 12
            9200,   // Level 13
            11300,  // Level 14
            13700,  // Level 15
            16500,  // Level 16
            19700,  // Level 17
            23400,  // Level 18
            27600,  // Level 19
            32500,  // Level 20
            38000,  // Level 21
            44200,  // Level 22
            51100,  // Level 23
            58800,  // Level 24
            67500,  // Level 25
            77200,  // Level 26
            88000,  // Level 27
            100000, // Level 28
            113200, // Level 29
            127800, // Level 30
        ]

        for (index, threshold) in thresholds.enumerated().reversed() {
            if xp >= threshold {
                return index + 1
            }
        }
        return 1
    }
    
    static let empty = UserProfile(
        id: "",
        firstName: "",
        lastName: "",
        displayName: "",
        email: nil,
        avatar: "🦁",
        goals: [],
        xp: 0,
        level: 1,
        streak: 0,
        longestStreak: 0,
        lastActiveDate: ISO8601DateFormatter().string(from: Date()),
        badges: [],
        completedLessons: [],
        memoryVerses: [],
        onboardingCompleted: false,
        loggedIn: false,
        streakFreezes: 0,
        freezeUsedDates: [],
        activeDates: [],
        chaptersRead: [],
        weeklyActivity: WeeklyActivity()
    )
}

struct WeeklyActivity: Codable {
    var lessonsCompleted: [LessonActivity] = []
    var versesReviewed: [VerseActivity] = []
    var chaptersRead: [ChapterActivity] = []
    var reflectionsWritten: [ReflectionActivity] = []
    var xpEarned: [XPActivity] = []
}

struct LessonActivity: Codable {
    let lessonId: String
    let date: String
}

struct VerseActivity: Codable {
    let verseId: String
    let date: String
}

struct ChapterActivity: Codable {
    let chapter: String
    let date: String
}

struct ReflectionActivity: Codable {
    let date: String
    let xp: Int
}

struct XPActivity: Codable {
    let date: String
    let amount: Int
    let source: String
}

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var earnedDate: String?
    var isEarned: Bool
}

// MARK: - Perk Models

enum PerkType: String, Codable {
    case streakFreeze
    case xpMultiplier
    case profileBorder
    case themeUnlock
    case avatarUnlock
}

enum PerkUnlockCondition: Codable {
    case level(Int)
    case streak(Int)
    case badge(String)
    case xp(Int)

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .level(let v):
            try container.encode("level", forKey: .type)
            try container.encode(v, forKey: .value)
        case .streak(let v):
            try container.encode("streak", forKey: .type)
            try container.encode(v, forKey: .value)
        case .badge(let v):
            try container.encode("badge", forKey: .type)
            try container.encode(v, forKey: .value)
        case .xp(let v):
            try container.encode("xp", forKey: .type)
            try container.encode(v, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "level":
            self = .level(try container.decode(Int.self, forKey: .value))
        case "streak":
            self = .streak(try container.decode(Int.self, forKey: .value))
        case "badge":
            self = .badge(try container.decode(String.self, forKey: .value))
        case "xp":
            self = .xp(try container.decode(Int.self, forKey: .value))
        default:
            self = .level(1)
        }
    }
}

struct Perk: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let type: PerkType
    let unlockCondition: PerkUnlockCondition
    var isUnlocked: Bool
    var isActive: Bool
}

// MARK: - Goal & Avatar Options

struct GoalOption: Identifiable {
    let id: String
    let label: String
    let icon: String
}

let goalOptions: [GoalOption] = [
    GoalOption(id: "storyline", label: "Learn the storyline of the Bible", icon: "📖"),
    GoalOption(id: "doctrine", label: "Grow in doctrine", icon: "📚"),
    GoalOption(id: "daily-habit", label: "Build a daily Scripture habit", icon: "☀️"),
    GoalOption(id: "memorize", label: "Memorize verses", icon: "🧠"),
    GoalOption(id: "big-picture", label: "Understand the big picture", icon: "🌍"),
    GoalOption(id: "walk", label: "Strengthen my walk with Christ", icon: "🙏"),
]

struct AvatarOption: Identifiable {
    let id: String
    let emoji: String
    let label: String
}

let avatarOptions: [AvatarOption] = [
    AvatarOption(id: "lion", emoji: "🦁", label: "Lion"),
    AvatarOption(id: "dove", emoji: "🕊️", label: "Dove"),
    AvatarOption(id: "lamb", emoji: "🐑", label: "Lamb"),
    AvatarOption(id: "eagle", emoji: "🦅", label: "Eagle"),
    AvatarOption(id: "fish", emoji: "🐟", label: "Fish"),
    AvatarOption(id: "star", emoji: "⭐", label: "Star"),
    AvatarOption(id: "flame", emoji: "🔥", label: "Flame"),
    AvatarOption(id: "cross", emoji: "✝️", label: "Cross"),
    AvatarOption(id: "heart", emoji: "❤️", label: "Heart"),
    AvatarOption(id: "book", emoji: "📖", label: "Book"),
    AvatarOption(id: "crown", emoji: "👑", label: "Crown"),
    AvatarOption(id: "olive", emoji: "🌿", label: "Olive Branch"),
]
