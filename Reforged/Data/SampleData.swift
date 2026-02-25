import Foundation

// MARK: - Sample Data

struct SampleData {

    // MARK: - Sample Memory Verses
    
    static let memoryVerses: [MemoryVerse] = [
        MemoryVerse(
            id: "mv-1",
            reference: "John 3:16",
            text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            esvText: nil,
            category: "Salvation",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        ),
        MemoryVerse(
            id: "mv-2",
            reference: "Romans 8:28",
            text: "And we know that for those who love God all things work together for good, for those who are called according to his purpose.",
            esvText: nil,
            category: "Trust",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            reviewCount: 3,
            easeFactor: 2.3,
            interval: 3,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        ),
        MemoryVerse(
            id: "mv-3",
            reference: "Philippians 4:13",
            text: "I can do all things through him who strengthens me.",
            esvText: nil,
            category: "Strength",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            reviewCount: 8,
            easeFactor: 2.6,
            interval: 7,
            isLearning: false,
            accuracy: nil,
            modeStats: nil
        ),
        MemoryVerse(
            id: "mv-4",
            reference: "Jeremiah 29:11",
            text: "For I know the plans I have for you, declares the LORD, plans for welfare and not for evil, to give you a future and a hope.",
            esvText: nil,
            category: "Hope",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Date(),
            reviewCount: 2,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        ),
        MemoryVerse(
            id: "mv-5",
            reference: "Proverbs 3:5-6",
            text: "Trust in the LORD with all your heart, and do not lean on your own understanding. In all your ways acknowledge him, and he will make straight your paths.",
            esvText: nil,
            category: "Guidance",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
    ]
    
    // MARK: - Sample Badges

    static let badges: [Badge] = [
        // Reading
        Badge(id: "first-chapter", name: "First Steps", description: "Read your first chapter", icon: "book.fill", earnedDate: nil, isEarned: false),
        Badge(id: "chapters-10", name: "Bookworm", description: "Read 10 chapters", icon: "books.vertical.fill", earnedDate: nil, isEarned: false),
        Badge(id: "chapters-50", name: "Avid Reader", description: "Read 50 chapters", icon: "text.book.closed.fill", earnedDate: nil, isEarned: false),
        Badge(id: "chapters-100", name: "Century Reader", description: "Read 100 chapters", icon: "book.circle.fill", earnedDate: nil, isEarned: false),
        Badge(id: "chapters-500", name: "Bible Scholar", description: "Read 500 chapters", icon: "graduationcap.fill", earnedDate: nil, isEarned: false),
        // Memory
        Badge(id: "first-verse", name: "Word in Heart", description: "Add your first memory verse", icon: "heart.fill", earnedDate: nil, isEarned: false),
        Badge(id: "verses-5", name: "Memory Builder", description: "Memorize 5 verses", icon: "brain", earnedDate: nil, isEarned: false),
        Badge(id: "verses-10", name: "Scripture Keeper", description: "Memorize 10 verses", icon: "brain.head.profile.fill", earnedDate: nil, isEarned: false),
        Badge(id: "verses-25", name: "Living Library", description: "Memorize 25 verses", icon: "books.vertical.fill", earnedDate: nil, isEarned: false),
        Badge(id: "perfect-review", name: "Perfect Recall", description: "Rate 'Easy' on 5 reviews in a row", icon: "star.circle.fill", earnedDate: nil, isEarned: false),
        // Streaks
        Badge(id: "streak-7", name: "Week Warrior", description: "Maintain a 7-day streak", icon: "flame.fill", earnedDate: nil, isEarned: false),
        Badge(id: "streak-14", name: "Fortnight Focus", description: "Maintain a 14-day streak", icon: "flame.circle.fill", earnedDate: nil, isEarned: false),
        Badge(id: "streak-30", name: "Monthly Devotion", description: "Maintain a 30-day streak", icon: "crown.fill", earnedDate: nil, isEarned: false),
        Badge(id: "streak-100", name: "Century Streak", description: "Maintain a 100-day streak", icon: "trophy.fill", earnedDate: nil, isEarned: false),
        Badge(id: "streak-365", name: "Year of Faith", description: "Maintain a 365-day streak", icon: "laurel.leading", earnedDate: nil, isEarned: false),
        // XP Milestones
        Badge(id: "xp-500", name: "Rising Star", description: "Earn 500 total XP", icon: "star.fill", earnedDate: nil, isEarned: false),
        Badge(id: "xp-5000", name: "Shining Light", description: "Earn 5,000 total XP", icon: "sun.max.fill", earnedDate: nil, isEarned: false),
        Badge(id: "xp-25000", name: "Radiant Glory", description: "Earn 25,000 total XP", icon: "sparkles", earnedDate: nil, isEarned: false),
        // Lessons
        Badge(id: "first-lesson", name: "Student", description: "Complete your first lesson", icon: "checkmark.circle.fill", earnedDate: nil, isEarned: false),
        Badge(id: "lessons-10", name: "Dedicated Learner", description: "Complete 10 lessons", icon: "medal.fill", earnedDate: nil, isEarned: false),
        Badge(id: "track-complete", name: "Track Master", description: "Complete an entire track", icon: "flag.checkered", earnedDate: nil, isEarned: false),
        // Journal
        Badge(id: "first-journal", name: "Reflector", description: "Write your first journal entry", icon: "pencil.circle.fill", earnedDate: nil, isEarned: false),
        Badge(id: "journals-10", name: "Thoughtful Writer", description: "Write 10 journal entries", icon: "pencil.and.outline", earnedDate: nil, isEarned: false),
        // Special
        Badge(id: "all-modes", name: "Mode Master", description: "Try all 6 memory practice modes", icon: "rectangle.grid.3x2.fill", earnedDate: nil, isEarned: false),
    ]

    // MARK: - Perks

    static let perks: [Perk] = [
        // Profile Borders
        Perk(id: "border-gold", name: "Gold Border", description: "A golden profile border", icon: "circle.circle.fill", type: .profileBorder, unlockCondition: .level(5), isUnlocked: false, isActive: false),
        Perk(id: "border-flame", name: "Flame Border", description: "A fiery profile border", icon: "flame.circle.fill", type: .profileBorder, unlockCondition: .streak(30), isUnlocked: false, isActive: false),
        Perk(id: "border-crown", name: "Royal Border", description: "A crown-adorned border", icon: "crown.fill", type: .profileBorder, unlockCondition: .level(20), isUnlocked: false, isActive: false),
        Perk(id: "border-diamond", name: "Diamond Border", description: "A sparkling diamond border", icon: "diamond.fill", type: .profileBorder, unlockCondition: .level(25), isUnlocked: false, isActive: false),
        // Theme Unlocks
        Perk(id: "theme-midnight", name: "Midnight Theme", description: "Deep blue dark theme", icon: "moon.stars.fill", type: .themeUnlock, unlockCondition: .level(8), isUnlocked: false, isActive: false),
        Perk(id: "theme-parchment", name: "Parchment Theme", description: "Warm vintage paper look", icon: "scroll.fill", type: .themeUnlock, unlockCondition: .level(12), isUnlocked: false, isActive: false),
        Perk(id: "theme-forest", name: "Forest Theme", description: "Serene green nature theme", icon: "leaf.fill", type: .themeUnlock, unlockCondition: .streak(50), isUnlocked: false, isActive: false),
        Perk(id: "theme-royal", name: "Royal Purple Theme", description: "Majestic purple accents", icon: "crown.fill", type: .themeUnlock, unlockCondition: .level(18), isUnlocked: false, isActive: false),
        // Avatar Unlocks
        Perk(id: "avatar-shield", name: "Shield of Faith", description: "Unlock the shield avatar", icon: "shield.fill", type: .avatarUnlock, unlockCondition: .level(7), isUnlocked: false, isActive: false),
        Perk(id: "avatar-sword", name: "Sword of the Spirit", description: "Unlock the sword avatar", icon: "bolt.fill", type: .avatarUnlock, unlockCondition: .streak(14), isUnlocked: false, isActive: false),
        Perk(id: "avatar-temple", name: "Temple", description: "Unlock the temple avatar", icon: "building.columns.fill", type: .avatarUnlock, unlockCondition: .level(15), isUnlocked: false, isActive: false),
        // Streak Freeze
        Perk(id: "freeze-bonus", name: "Freeze Stockpile", description: "Hold up to 8 streak freezes", icon: "snowflake", type: .streakFreeze, unlockCondition: .level(10), isUnlocked: false, isActive: false),
        // XP Boost
        Perk(id: "xp-boost-small", name: "1.25x XP Boost", description: "Permanent 25% XP bonus", icon: "arrow.up.circle.fill", type: .xpMultiplier, unlockCondition: .level(15), isUnlocked: false, isActive: false),
    ]

    // MARK: - Level Info

    static func getLevelInfo(xp: Int) -> LevelInfo {
        let levels: [(level: Int, minXp: Int, title: String)] = [
            (1, 0, "Seeker"),
            (2, 100, "Listener"),
            (3, 250, "Learner"),
            (4, 500, "Reader"),
            (5, 850, "Student"),
            (6, 1300, "Disciple"),
            (7, 1900, "Follower"),
            (8, 2600, "Devotee"),
            (9, 3500, "Scholar"),
            (10, 4600, "Teacher"),
            (11, 5900, "Guide"),
            (12, 7400, "Mentor"),
            (13, 9200, "Theologian"),
            (14, 11300, "Sage"),
            (15, 13700, "Shepherd"),
            (16, 16500, "Elder"),
            (17, 19700, "Watchman"),
            (18, 23400, "Steward"),
            (19, 27600, "Herald"),
            (20, 32500, "Apostle"),
            (21, 38000, "Prophet"),
            (22, 44200, "Guardian"),
            (23, 51100, "Warrior"),
            (24, 58800, "Champion"),
            (25, 67500, "Conqueror"),
            (26, 77200, "Defender"),
            (27, 88000, "Overcomer"),
            (28, 100000, "Patriarch"),
            (29, 113200, "Pillar"),
            (30, 127800, "Legend"),
        ]

        var currentLevel = levels[0]
        var nextLevel = levels[1]

        for i in (0..<levels.count).reversed() {
            if xp >= levels[i].minXp {
                currentLevel = levels[i]
                nextLevel = i + 1 < levels.count ? levels[i + 1] : levels[i]
                break
            }
        }

        let xpInLevel = xp - currentLevel.minXp
        let xpForNextLevel = nextLevel.minXp - currentLevel.minXp
        let progress = xpForNextLevel > 0 ? Double(xpInLevel) / Double(xpForNextLevel) : 1.0

        return LevelInfo(
            level: currentLevel.level,
            title: currentLevel.title,
            xpInLevel: xpInLevel,
            xpForNextLevel: xpForNextLevel,
            progress: min(progress, 1.0)
        )
    }

    static func getLevelInfo(level: Int) -> LevelInfo {
        let titles = [
            "Seeker", "Listener", "Learner", "Reader", "Student",
            "Disciple", "Follower", "Devotee", "Scholar", "Teacher",
            "Guide", "Mentor", "Theologian", "Sage", "Shepherd",
            "Elder", "Watchman", "Steward", "Herald", "Apostle",
            "Prophet", "Guardian", "Warrior", "Champion", "Conqueror",
            "Defender", "Overcomer", "Patriarch", "Pillar", "Legend",
        ]
        let index = max(0, min(level - 1, titles.count - 1))
        return LevelInfo(level: level, title: titles[index], xpInLevel: 0, xpForNextLevel: 0, progress: 0)
    }
}

struct LevelInfo {
    let level: Int
    let title: String
    let xpInLevel: Int
    let xpForNextLevel: Int
    let progress: Double
}
