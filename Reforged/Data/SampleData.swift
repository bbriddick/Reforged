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
        let level = LevelProgression.level(forXP: xp)
        let floor = LevelProgression.minXP(for: level)
        let next = level < LevelProgression.maxLevel ? LevelProgression.minXP(for: level + 1) : floor
        let xpInLevel = xp - floor
        let xpForNextLevel = next - floor
        let progress = xpForNextLevel > 0 ? Double(xpInLevel) / Double(xpForNextLevel) : 1.0
        return LevelInfo(
            level: level,
            title: LevelProgression.title(for: level),
            xpInLevel: xpInLevel,
            xpForNextLevel: xpForNextLevel,
            progress: min(progress, 1.0)
        )
    }

    static func getLevelInfo(level: Int) -> LevelInfo {
        LevelInfo(level: level, title: LevelProgression.title(for: level), xpInLevel: 0, xpForNextLevel: 0, progress: 0)
    }
}

// MARK: - Level Progression (Armor of God)

/// The single source of truth for levels. 30 levels = the six pieces of the
/// armor of God (Ephesians 6:14–17) × five ranks each. Level is always derived
/// from LIFETIME XP (`UserProfile.lifetimeXP`), so spending XP never costs a level.
enum LevelProgression {
    struct ArmorPiece {
        let name: String          // "Shield of Faith"
        let shortName: String     // "Shield"
        let phrase: String        // mid-sentence form: "shield of faith", "sword of the Spirit"
        let icon: String          // SF Symbol, iOS 16-safe
        let reference: String
        let verseText: String     // KJV, public domain — the full verse, never trimmed
    }

    static let ranksPerPiece = 5

    static let pieces: [ArmorPiece] = [
        ArmorPiece(name: "Belt of Truth", shortName: "Belt", phrase: "belt of truth",
                   icon: "link",
                   reference: "Ephesians 6:14",
                   verseText: "Stand therefore, having your loins girt about with truth, and having on the breastplate of righteousness;"),
        ArmorPiece(name: "Breastplate of Righteousness", shortName: "Breastplate", phrase: "breastplate of righteousness",
                   icon: "shield.lefthalf.filled",
                   reference: "Ephesians 6:14",
                   verseText: "Stand therefore, having your loins girt about with truth, and having on the breastplate of righteousness;"),
        ArmorPiece(name: "Shoes of Peace", shortName: "Shoes", phrase: "shoes of peace",
                   icon: "figure.walk",
                   reference: "Ephesians 6:15",
                   verseText: "And your feet shod with the preparation of the gospel of peace;"),
        ArmorPiece(name: "Shield of Faith", shortName: "Shield", phrase: "shield of faith",
                   icon: "shield.fill",
                   reference: "Ephesians 6:16",
                   verseText: "Above all, taking the shield of faith, wherewith ye shall be able to quench all the fiery darts of the wicked."),
        ArmorPiece(name: "Helmet of Salvation", shortName: "Helmet", phrase: "helmet of salvation",
                   icon: "brain.head.profile",
                   reference: "Ephesians 6:17",
                   verseText: "And take the helmet of salvation, and the sword of the Spirit, which is the word of God:"),
        ArmorPiece(name: "Sword of the Spirit", shortName: "Sword", phrase: "sword of the Spirit",
                   icon: "book.closed.fill",
                   reference: "Ephesians 6:17",
                   verseText: "And take the helmet of salvation, and the sword of the Spirit, which is the word of God:"),
    ]

    /// Minimum lifetime XP for each level (index 0 = level 1). A smooth curve:
    /// level 2 on day one, level 5 in about a week, level 30 after years of daily use.
    static let thresholds: [Int] = [
        0, 100, 250, 500, 850,
        1300, 1900, 2600, 3500, 4600,
        5900, 7400, 9200, 11300, 13700,
        16500, 19700, 23400, 27600, 32500,
        38000, 44200, 51100, 58800, 67500,
        77200, 88000, 100000, 113200, 127800,
    ]

    static var maxLevel: Int { thresholds.count }

    static func level(forXP xp: Int) -> Int {
        (thresholds.lastIndex { xp >= $0 } ?? 0) + 1
    }

    static func minXP(for level: Int) -> Int {
        thresholds[max(0, min(level - 1, thresholds.count - 1))]
    }

    static func piece(for level: Int) -> ArmorPiece {
        pieces[pieceIndex(for: level)]
    }

    static func pieceIndex(for level: Int) -> Int {
        max(0, min((level - 1) / ranksPerPiece, pieces.count - 1))
    }

    /// 1...5 within the current piece.
    static func rank(for level: Int) -> Int {
        (max(level, 1) - 1) % ranksPerPiece + 1
    }

    /// True on the first level of a new piece (6, 11, 16…) — the "you took up
    /// the shield of faith" moment rather than an ordinary rank-up.
    static func isNewPiece(_ level: Int) -> Bool {
        level > 1 && rank(for: level) == 1
    }

    static func romanRank(_ rank: Int) -> String {
        ["I", "II", "III", "IV", "V"][max(0, min(rank - 1, 4))]
    }

    /// Level-up headline: a new piece is "taken up"; a rank-up strengthens it.
    static func levelUpLine(for level: Int) -> String {
        let piece = piece(for: level)
        if level == 1 || isNewPiece(level) {
            return "You took up the \(piece.phrase)"
        }
        return "\(piece.name) · rank \(romanRank(rank(for: level)))"
    }

    static func freezeRewardLine(_ freezes: Int) -> String? {
        guard freezes > 0 else { return nil }
        return freezes == 1 ? "+1 streak freeze" : "+\(freezes) streak freezes"
    }

    static func title(for level: Int) -> String {
        "\(piece(for: level).name) \(romanRank(rank(for: level)))"
    }
}

struct LevelInfo {
    let level: Int
    let title: String
    let xpInLevel: Int
    let xpForNextLevel: Int
    let progress: Double
}

