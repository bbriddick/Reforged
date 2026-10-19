import Foundation

// MARK: - Southland Summer 2026 Camper Verses
//
// The memory verses for Southland Christian Ministries' Summer 2026 camp
// ("Take Courage"), offered as their own track inside the Memory tab as part of
// the Southland partnership. Text is the public-domain King James Version, taken
// from the camp's Scripture Memory - Camper sheet. Reuses CurriculumUnit so the
// track rides the same journey path, lessons, and review loop as the main path.

enum SouthlandCurriculum {
    static let title = "Southland 2026 Verses"
    static let theme = "Take Courage"
    /// Stored as MemoryVerse.category for verses started from this track.
    static let category = "Southland 2026"

    /// Monday to Thursday: new verses, one day at a time.
    static let dayUnits: [CurriculumUnit] = [
        CurriculumUnit(id: "southland-mon", title: "Monday", theme: category,
            subtitle: "Day 1 · 5 XP per verse", icon: "figure.walk", accent: .teal, verses: [
            CurriculumVerse(reference: "Joshua 1:8-9", text: "This book of the law shall not depart out of thy mouth; but thou shalt meditate therein day and night, that thou mayest observe to do according to all that is written therein: for then thou shalt make thy way prosperous, and then thou shalt have good success. Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest."),
            CurriculumVerse(reference: "Micah 6:8", text: "He hath shewed thee, O man, what is good; and what doth the Lord require of thee, but to do justly, and to love mercy, and to walk humbly with thy God?"),
            CurriculumVerse(reference: "1 Timothy 4:12", text: "Let no man despise thy youth; but be thou an example of the believers, in word, in conversation, in charity, in spirit, in faith, in purity."),
            CurriculumVerse(reference: "Psalm 61:1-2", text: "Hear my cry, O God; attend unto my prayer. From the end of the earth will I cry unto thee, when my heart is overwhelmed: lead me to the rock that is higher than I."),
            CurriculumVerse(reference: "Romans 3:23", text: "For all have sinned, and come short of the glory of God;"),
        ], pointsPerVerse: 5),
        CurriculumUnit(id: "southland-tue", title: "Tuesday", theme: category,
            subtitle: "Day 2 · 10 XP per verse", icon: "shield.lefthalf.filled", accent: .gold, verses: [
            CurriculumVerse(reference: "Proverbs 4:23", text: "Keep thy heart with all diligence; for out of it are the issues of life."),
            CurriculumVerse(reference: "2 Peter 1:3-4", text: "According as his divine power hath given unto us all things that pertain unto life and godliness, through the knowledge of him that hath called us to glory and virtue: Whereby are given unto us exceeding great and precious promises: that by these ye might be partakers of the divine nature, having escaped the corruption that is in the world through lust."),
            CurriculumVerse(reference: "Romans 13:14", text: "But put ye on the Lord Jesus Christ, and make not provision for the flesh, to fulfil the lusts thereof."),
            CurriculumVerse(reference: "Psalm 61:3-4", text: "For thou hast been a shelter for me, and a strong tower from the enemy. I will abide in thy tabernacle for ever: I will trust in the covert of thy wings. Selah."),
            CurriculumVerse(reference: "Romans 5:8", text: "But God commendeth his love toward us, in that, while we were yet sinners, Christ died for us."),
        ], pointsPerVerse: 10),
        CurriculumUnit(id: "southland-wed", title: "Wednesday", theme: category,
            subtitle: "Day 3 · 25 XP per verse", icon: "sun.max.fill", accent: .coral, verses: [
            CurriculumVerse(reference: "Psalm 119:105-106", text: "Thy word is a lamp unto my feet, and a light unto my path. I have sworn, and I will perform it, that I will keep thy righteous judgments."),
            CurriculumVerse(reference: "Ephesians 4:31-32", text: "Let all bitterness, and wrath, and anger, and clamour, and evil speaking, be put away from you, with all malice: And be ye kind one to another, tenderhearted, forgiving one another, even as God for Christ’s sake hath forgiven you."),
            CurriculumVerse(reference: "2 Timothy 1:7", text: "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind."),
            CurriculumVerse(reference: "Psalm 61:5-6", text: "For thou, O God, hast heard my vows: thou hast given me the heritage of those that fear thy name. Thou wilt prolong the king’s life: and his years as many generations."),
            CurriculumVerse(reference: "Romans 6:23", text: "For the wages of sin is death; but the gift of God is eternal life through Jesus Christ our Lord."),
        ], pointsPerVerse: 25),
        CurriculumUnit(id: "southland-thu", title: "Thursday", theme: category,
            subtitle: "Day 4 · 15 XP per verse", icon: "flag.fill", accent: .purple, verses: [
            CurriculumVerse(reference: "Psalm 141:3", text: "Set a watch, O Lord, before my mouth; keep the door of my lips."),
            CurriculumVerse(reference: "1 Chronicles 29:11-12", text: "Thine, O Lord, is the greatness, and the power, and the glory, and the victory, and the majesty: for all that is in the heaven and in the earth is thine; thine is the kingdom, O Lord, and thou art exalted as head above all. Both riches and honour come of thee, and thou reignest over all; and in thine hand is power and might; and in thine hand it is to make great, and to give strength unto all."),
            CurriculumVerse(reference: "James 4:8", text: "Draw nigh to God, and he will draw nigh to you. Cleanse your hands, ye sinners; and purify your hearts, ye double minded."),
            CurriculumVerse(reference: "Psalm 61:7-8", text: "He shall abide before God for ever: O prepare mercy and truth, which may preserve him. So will I sing praise unto thy name for ever, that I may daily perform my vows."),
            CurriculumVerse(reference: "Romans 10:9", text: "That if thou shalt confess with thy mouth the Lord Jesus, and shalt believe in thine heart that God hath raised him from the dead, thou shalt be saved."),
        ], pointsPerVerse: 15),
    ]

    static let allVerses: [CurriculumVerse] = dayUnits.flatMap { $0.verses }
    static let references: Set<String> = Set(allVerses.map { $0.reference })

    /// XP per verse reviewed on Friday. (Friday's value wasn't specified separately; adjust here.)
    static let fridayPointsPerVerse = 15

    /// Friday revisits every verse from the week.
    static let fridayUnit = CurriculumUnit(
        id: "southland-fri", title: "Friday", theme: category,
        subtitle: "Day 5 · Review all \(allVerses.count) · \(fridayPointsPerVerse) XP each",
        icon: "star.circle.fill", accent: .green, verses: allVerses,
        pointsPerVerse: fridayPointsPerVerse, isReview: true)

    static let units: [CurriculumUnit] = dayUnits + [fridayUnit]

    /// The day (Mon-Thu) a verse is learned on.
    static func dayUnit(for reference: String) -> CurriculumUnit? {
        dayUnits.first { $0.verses.contains { $0.reference == reference } }
    }

    // One-time award keys (stored in user.cosmetics.awardedKeys).
    static func learnKey(_ reference: String) -> String { "southland:learn:\(reference)" }
    static func reviewKey(_ reference: String) -> String { "southland:review:\(reference)" }

    /// Every XP point the track can pay out.
    static var totalPoints: Int {
        dayUnits.reduce(0) { $0 + ($1.pointsPerVerse ?? 0) * $1.verses.count }
            + fridayPointsPerVerse * allVerses.count
    }
}

// MARK: - Progress & points

extension AppState {
    private var southlandStarted: Set<String> { Set(memoryVerses.map { $0.reference }) }

    func southlandDayComplete(_ unit: CurriculumUnit) -> Bool {
        unit.verses.allSatisfy { southlandStarted.contains($0.reference) }
    }

    /// Friday opens once all of Monday to Thursday has been learned.
    var southlandReviewOpen: Bool {
        SouthlandCurriculum.dayUnits.allSatisfy { southlandDayComplete($0) }
    }

    var southlandReviewedCount: Int {
        SouthlandCurriculum.allVerses.filter {
            user.cosmetics.awardedKeys.contains(SouthlandCurriculum.reviewKey($0.reference))
        }.count
    }

    var southlandReviewComplete: Bool { southlandReviewedCount == SouthlandCurriculum.allVerses.count }

    /// XP earned so far from the camp track.
    var southlandPointsEarned: Int {
        let keys = Set(user.cosmetics.awardedKeys)
        let learned = SouthlandCurriculum.dayUnits.reduce(0) { total, unit in
            total + unit.verses.filter { keys.contains(SouthlandCurriculum.learnKey($0.reference)) }.count
                * (unit.pointsPerVerse ?? 0)
        }
        return learned + southlandReviewedCount * SouthlandCurriculum.fridayPointsPerVerse
    }

    /// Pays a Monday-Thursday verse's points once, when its lesson is completed.
    func awardSouthlandLearnPoints(reference: String) {
        guard let unit = SouthlandCurriculum.dayUnit(for: reference),
              let points = unit.pointsPerVerse else { return }
        let key = SouthlandCurriculum.learnKey(reference)
        guard !user.cosmetics.awardedKeys.contains(key) else { return }
        user.cosmetics.awardedKeys.append(key)
        addXP(points, source: "southland-camp")
        saveToLocalStorage()
    }

    /// Pays Friday's review points once per verse, after Friday has opened.
    func awardSouthlandReviewPoints(reference: String) {
        guard SouthlandCurriculum.references.contains(reference), southlandReviewOpen else { return }
        let key = SouthlandCurriculum.reviewKey(reference)
        guard !user.cosmetics.awardedKeys.contains(key) else { return }
        user.cosmetics.awardedKeys.append(key)
        addXP(SouthlandCurriculum.fridayPointsPerVerse, source: "southland-camp")
        saveToLocalStorage()
    }
}
