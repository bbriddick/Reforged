import Foundation

// MARK: - Memory Verse Models

struct MemoryVerse: Codable, Identifiable, Equatable {
    let id: String
    let reference: String
    let text: String
    var esvText: String?
    let category: String
    var translation: String?
    var lastFetched: String?
    var nextReviewDate: Date
    var reviewCount: Int
    var easeFactor: Double
    var interval: Int
    var isLearning: Bool
    var accuracy: Double?
    var modeStats: MemoryVerseModeStats?
    var reflectionNote: String?
    /// Recite-test history: the single source of truth for whether the member can
    /// actually write this verse out. Nil until the first Recite test.
    var recitation: RecitationProgress?
    /// True when the member chose this verse themselves (add sheet, Bible reader, import,
    /// a friend's share), false when it came from a Journey lesson. Nil on older verses.
    var addedByUser: Bool?

    var level: Int {
        if interval >= 365 {
            return 5 // Mastered
        } else if interval >= 90 {
            return 4 // Well-known
        } else if interval >= 30 {
            return 3 // Known
        } else if interval >= 7 {
            return 2 // Familiar
        } else {
            return 1 // Learning
        }
    }

    var levelName: String { Self.levelName(for: level) }

    static func levelName(for level: Int) -> String {
        switch level {
        // Review strength only. "Memorized"/"Mastered" come from the Recite test
        // (see `status`), never from how far apart reviews are.
        case 5: return "Rooted"
        case 4: return "Well-Known"
        case 3: return "Known"
        case 2: return "Familiar"
        default: return "Learning"
        }
    }

    /// What the member has proven, from Recite tests. See `RecitationProgress`.
    var status: VerseMemoryStatus { recitation?.status ?? .notYetTested }

    /// Added but never learned: no lesson finished and no recite yet. Its first step is a
    /// lesson, so it isn't "due" for a review it has never had.
    var isNew: Bool { reviewCount == 0 && recitation == nil }

    /// What to call the verse's status in the UI ("New" reads better than "Not yet tested"
    /// for a verse the member just added).
    var statusLabel: String {
        if inStepsPhase, let step = currentStep {
            return status == .learning ? "Step 3 of 3" : "Step \(step.rawValue) of 3"
        }
        return isNew ? "New" : status.displayName
    }

    /// True when the member chose this verse (My Verses) rather than a Journey lesson.
    /// Older verses without `addedByUser` fall back to: not on a path, or never started.
    var isUserChosen: Bool {
        if let addedByUser { return addedByUser }
        let onPath = MemoryCurriculum.allVerses.contains { $0.reference == reference }
            || SouthlandCurriculum.references.contains(reference)
        return !onPath || isNew
    }

    /// A My Verses verse that hasn't passed step 3 yet: its next move is a step, not a review.
    var inStepsPhase: Bool { isUserChosen && recitation?.memorizedAt == nil }

    /// The three steps on a verse page.
    enum Step: Int, CaseIterable, Identifiable {
        case type = 1, gaps, recite
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .type: return "Type it"
            case .gaps: return "Fill the gaps"
            case .recite: return "Recite it"
            }
        }
        var detail: String {
            switch self {
            case .type: return "Type the first letter of each word while you read"
            case .gaps: return "Every other word is hidden. Fill them in"
            case .recite: return "Write the whole verse from memory. 95% passes"
            }
        }
        var xp: Int {
            switch self {
            case .type: return 10
            case .gaps: return 15
            case .recite: return 25
            }
        }
    }

    func isStepDone(_ step: Step) -> Bool {
        if recitation?.memorizedAt != nil { return true }
        switch step {
        case .type: return recitation?.typedAt != nil
        case .gaps: return recitation?.gapsAt != nil
        case .recite: return false
        }
    }

    /// The first unfinished step, or nil once the verse is memorized.
    var currentStep: Step? { Step.allCases.first { !isStepDone($0) } }

    var isDueForReview: Bool {
        return !isNew && !inStepsPhase && nextReviewDate <= Date()
    }

    // SM-2 Algorithm for spaced repetition
    mutating func updateReview(quality: Int) {
        // Quality: 0-5 (0 = complete blackout, 5 = perfect recall)
        var newEaseFactor = easeFactor + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        newEaseFactor = max(1.3, newEaseFactor)

        var newInterval: Int
        var newReviewCount = reviewCount + 1

        if quality < 3 {
            newInterval = 1
            newReviewCount = 0
        } else if newReviewCount == 1 {
            newInterval = 1
        } else if newReviewCount == 2 {
            newInterval = 2
        } else if newReviewCount == 3 {
            newInterval = 4
        } else if newReviewCount == 4 {
            newInterval = 7
        } else {
            newInterval = Int(round(Double(interval) * newEaseFactor))
        }

        easeFactor = newEaseFactor
        interval = newInterval
        reviewCount = newReviewCount
        nextReviewDate = Calendar.current.date(byAdding: .day, value: newInterval, to: Date()) ?? Date()
        isLearning = newInterval < 21
    }
}

struct MemoryVerseModeStats: Codable, Equatable {
    var fillInBlank: ModeAttemptStats
    var firstLetter: ModeAttemptStats
    var typing: TypingStats
    var flashcard: FlashcardStats
    var tapToReveal: ModeAttemptStats?
    var dragAndDrop: ModeAttemptStats?
}

struct ModeAttemptStats: Codable, Equatable {
    var attempts: Int
    var accuracy: Double
    /// Optional for backward compatibility with verses saved before per-key
    /// results were tracked.
    var correct: Int? = nil
    var incorrect: Int? = nil
}

struct TypingStats: Codable, Equatable {
    var attempts: Int
    var accuracy: Double
    var bestWpm: Int?
}

struct FlashcardStats: Codable, Equatable {
    var attempts: Int
    var confidence: Double
}

enum MemoryMode: String, CaseIterable {
    case flashcard
    case tapToReveal
    case dragAndDrop
    case fillInBlank
    case firstLetter
    case typing

    var displayName: String {
        switch self {
        case .flashcard: return "Flashcard"
        case .tapToReveal: return "Tap to Reveal"
        case .dragAndDrop: return "Drag & Drop"
        case .fillInBlank: return "Fill in Blank"
        case .firstLetter: return "First Letter"
        case .typing: return "Type It Out"
        }
    }

    var icon: String {
        switch self {
        case .flashcard: return "rectangle.on.rectangle.angled"
        case .tapToReveal: return "hand.tap.fill"
        case .dragAndDrop: return "hand.draw.fill"
        case .fillInBlank: return "text.badge.plus"
        case .firstLetter: return "a.circle"
        case .typing: return "keyboard"
        }
    }

    var description: String {
        switch self {
        case .flashcard: return "Flip to reveal the verse"
        case .tapToReveal: return "Reveal phrase by phrase"
        case .dragAndDrop: return "Drag words to fill blanks"
        case .fillInBlank: return "Type missing words"
        case .firstLetter: return "Type first letters, words reveal"
        case .typing: return "Type the entire verse"
        }
    }

    /// Exercise pools by mastery level, ordered easiest to hardest recall.
    /// The ladder is a deliberate ramp so a verse is eased in and then pushed harder
    /// as it matures:
    ///   L1 Learning    → flashcards (pure recognition, swipe deck)
    ///   L2 Familiar    → phrase-by-phrase reveal
    ///   L3 Known       → fill-in / drag-and-drop (cued recall)
    ///   L4 Well-Known  → first-letter (near-free recall)
    ///   L5 Mastered    → typing (full free recall)
    private static let progressionPools: [Int: [MemoryMode]] = [
        1: [.flashcard],
        2: [.tapToReveal],
        3: [.fillInBlank, .dragAndDrop],
        4: [.firstLetter, .dragAndDrop],
        5: [.typing, .firstLetter]
    ]

    /// True while the verse is still at the recognition (flashcard) stage. These verses
    /// are batched into the Quizlet-style swipe deck at the start of a review session.
    static func isFlashcardStage(_ verse: MemoryVerse) -> Bool {
        progressiveMode(for: verse) == .flashcard
    }

    /// Picks an exercise for a due review: harder pools unlock as the verse matures,
    /// and the choice rotates within its pool as reviewCount changes so the same
    /// verse doesn't always get the same exercise.
    static func progressiveMode(for verse: MemoryVerse) -> MemoryMode {
        let pool = progressionPools[verse.level] ?? progressionPools[1]!
        let seed = "\(verse.id)-\(verse.reviewCount)".hashValue
        let index = abs(seed) % pool.count
        return pool[index]
    }
}

// MARK: - Recitation (the "can you write it out?" test)

/// What a member has proven about a verse. Driven only by Recite tests.
enum VerseMemoryStatus: String, Codable, Equatable {
    case notYetTested   // in the library, never recited (includes verses from before recite tests)
    case learning       // recited, but has not passed yet
    case memorized      // passed a Recite test; in spaced review
    case needsWork      // was memorized, then missed a recite
    case mastered       // passing reviews held across 30+ days

    var displayName: String {
        switch self {
        case .notYetTested: return "Not yet tested"
        case .learning: return "Learning"
        case .memorized: return "Memorized"
        case .needsWork: return "Needs work"
        case .mastered: return "Mastered"
        }
    }

    var icon: String {
        switch self {
        case .notYetTested: return "questionmark.circle"
        case .learning: return "book.fill"
        case .memorized: return "checkmark.seal.fill"
        case .needsWork: return "arrow.uturn.backward.circle.fill"
        case .mastered: return "crown.fill"
        }
    }

    var isMemorized: Bool { self == .memorized || self == .mastered }
}

/// How the member entered a recitation.
enum RecitationMethod: String, Codable, Equatable, CaseIterable {
    case firstLetters
    case fullWords

    var displayName: String {
        switch self {
        case .firstLetters: return "First letters"
        case .fullWords: return "Full words"
        }
    }
}

struct RecitationRecord: Codable, Equatable {
    var date: Date
    var accuracy: Double
    var method: RecitationMethod
    var passed: Bool
}

/// Persisted per-verse recite history. Stored as one JSON blob so sync needs one field.
struct RecitationProgress: Codable, Equatable {
    /// Score needed to pass, and no hints are offered during a test.
    static let passThreshold = 0.95
    /// Passing scheduled reviews that must span this many days for Mastered.
    static let masteryDays = 30
    static let masteryReviewPasses = 3

    var memorizedAt: Date?
    var masteredAt: Date?
    var last: RecitationRecord?
    /// Consecutive passing *scheduled* reviews since the last miss.
    var passStreak: Int = 0
    /// When the current unbroken run of passes began.
    var streakStart: Date?
    /// Step 1 ("Type it") and step 2 ("Fill the gaps") completion. Step 3 is the recite.
    var typedAt: Date?
    var gapsAt: Date?

    var status: VerseMemoryStatus {
        guard let last else { return .notYetTested }
        guard memorizedAt != nil else { return .learning }
        if !last.passed { return .needsWork }
        return masteredAt != nil ? .mastered : .memorized
    }

    /// Fraction of the way from Memorized to Mastered (0...1).
    var masteryProgress: Double {
        guard memorizedAt != nil else { return 0 }
        if masteredAt != nil { return 1 }
        let passes = min(1, Double(passStreak) / Double(Self.masteryReviewPasses))
        let days = streakStart.map { Double(Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0) } ?? 0
        let span = min(1, days / Double(Self.masteryDays))
        return min(passes, span)
    }

    /// Records one recitation. `scheduled` is true for due reviews (the only
    /// passes that count toward Mastered, so repeat practice can't shortcut it).
    mutating func record(_ record: RecitationRecord, scheduled: Bool) {
        last = record
        if record.passed {
            if memorizedAt == nil { memorizedAt = record.date }
            if streakStart == nil { streakStart = record.date }
            if scheduled { passStreak += 1 }
            if masteredAt == nil, passStreak >= Self.masteryReviewPasses,
               let start = streakStart,
               (Calendar.current.dateComponents([.day], from: start, to: record.date).day ?? 0) >= Self.masteryDays {
                masteredAt = record.date
            }
        } else {
            passStreak = 0
            streakStart = nil
            masteredAt = nil
        }
    }
}

/// Grades a typed recitation against the verse by aligning words, so one skipped or
/// extra word costs one word instead of shifting every word after it.
enum RecitationGrader {
    enum Mark: Equatable {
        case correct(String)                       // expected word, typed right
        case typo(expected: String, typed: String) // close enough; counts as correct
        case wrong(expected: String, typed: String)
        case missing(String)
        case extra(String)

        var countsCorrect: Bool {
            switch self {
            case .correct, .typo: return true
            default: return false
            }
        }
    }

    struct Result: Equatable {
        let marks: [Mark]
        let expectedCount: Int
        let correctCount: Int
        let extraCount: Int

        /// Correct words over (expected + extra), so padding with extra words doesn't help.
        var accuracy: Double {
            let denom = expectedCount + extraCount
            return denom == 0 ? 0 : Double(correctCount) / Double(denom)
        }

        var passed: Bool { accuracy >= RecitationProgress.passThreshold }
    }

    /// Display words of a verse, without bracketed editorial notes. Long dashes
    /// separate words (ESV often prints them with no spaces).
    static func words(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\u{2013}\u{2014}]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !key($0).isEmpty }
    }

    /// Comparison key: case, accents, curly quotes and punctuation ignored.
    /// "LORD's" -> "lords", "Jesus." -> "jesus".
    static func key(_ word: String) -> String {
        let folded = word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// One-letter slips are forgiven in words of 5+ letters.
    static func isTypo(_ a: String, _ b: String) -> Bool {
        guard min(a.count, b.count) >= 5, abs(a.count - b.count) <= 1 else { return false }
        return editDistance(Array(a), Array(b)) <= 1
    }

    static func grade(expected: String, typed: String) -> Result {
        let exp = words(expected)
        let got = words(typed)
        let ek = exp.map(key), gk = got.map(key)
        let n = ek.count, m = gk.count

        // Word-level edit distance; matches (exact or typo) cost 0.
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let same = ek[i-1] == gk[j-1] || isTypo(ek[i-1], gk[j-1])
                    dp[i][j] = min(dp[i-1][j-1] + (same ? 0 : 1), dp[i-1][j] + 1, dp[i][j-1] + 1)
                }
            }
        }

        var marks: [Mark] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 {
                let exact = ek[i-1] == gk[j-1]
                let typo = !exact && isTypo(ek[i-1], gk[j-1])
                let cost = (exact || typo) ? 0 : 1
                if dp[i][j] == dp[i-1][j-1] + cost {
                    if exact { marks.append(.correct(exp[i-1])) }
                    else if typo { marks.append(.typo(expected: exp[i-1], typed: got[j-1])) }
                    else { marks.append(.wrong(expected: exp[i-1], typed: got[j-1])) }
                    i -= 1; j -= 1
                    continue
                }
            }
            if i > 0 && dp[i][j] == dp[i-1][j] + 1 {
                marks.append(.missing(exp[i-1])); i -= 1
            } else {
                marks.append(.extra(got[j-1])); j -= 1
            }
        }
        marks.reverse()

        let correct = marks.filter(\.countsCorrect).count
        let extras = marks.filter { if case .extra = $0 { return true }; return false }.count
        return Result(marks: marks, expectedCount: n, correctCount: correct, extraCount: extras)
    }

    /// First-letter recitation: each word is right or wrong on its first try.
    static func gradeFirstLetters(wordCount: Int, correct: Int) -> Double {
        wordCount == 0 ? 0 : Double(correct) / Double(wordCount)
    }

    /// SM-2 quality from a recite score. Anything under the pass mark resets the
    /// interval, so a missed verse comes back tomorrow.
    static func reviewQuality(accuracy: Double) -> Int {
        switch accuracy {
        case 0.999...: return 5
        case RecitationProgress.passThreshold...: return 4
        case 0.8..<RecitationProgress.passThreshold: return 2
        default: return 1
        }
    }

    /// Edit distance where swapping two neighbouring letters counts as one slip
    /// (optimal string alignment), so "strenghtens" is one typo from "strengthens".
    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                d[i][j] = min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + cost)
                if i > 1, j > 1, a[i-1] == b[j-2], a[i-2] == b[j-1] {
                    d[i][j] = min(d[i][j], d[i-2][j-2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }
}

// MARK: - Mastery score (front-loaded)

/// One step on the way to Mastered.
struct MasteryMilestone: Identifiable, Equatable {
    let id: String
    let title: String
    /// Score once this step is reached (0...100).
    let points: Int
    let reached: Bool
}

/// A 0-100 "how close to Mastered" score. Deliberately front-loaded (endowed progress):
/// starting and first attempts earn big chunks so the finish line feels close, the
/// Recite pass is the biggest single jump, and the long tail of reviews earns smaller
/// steps. The goal-gradient effect then pulls the member through the last stretch.
struct MasteryScore: Equatable {
    static let started = 20
    static let typed = 35          // step 1
    static let gaps = 50           // step 2
    static let firstRecite = 30
    static let learningCeiling = 55   // a near-miss recite lands just short of Memorized
    static let memorized = 65
    static let reviewPoints = [77, 86, 93]
    static let mastered = 100

    let percent: Int
    let milestones: [MasteryMilestone]
    /// One short line telling the member exactly what to do next.
    let nextStep: String

    var fraction: Double { Double(percent) / 100 }
    var nextMilestone: MasteryMilestone? { milestones.first { !$0.reached } }
}

extension MemoryVerse {
    /// Front-loaded credit for steps 1 and 2: 20 -> 35 -> 50.
    private var stepsScore: Int {
        MasteryScore.started
            + (recitation?.typedAt != nil ? MasteryScore.typed - MasteryScore.started : 0)
            + (recitation?.gapsAt != nil ? MasteryScore.gaps - MasteryScore.typed : 0)
    }

    var mastery: MasteryScore {
        let r = recitation
        let status = self.status
        let memorized = r?.memorizedAt != nil
        let passes = min(r?.passStreak ?? 0, 3)
        let attempted = r?.last != nil
        let days = r?.streakStart.map {
            max(0, Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0)
        } ?? 0

        let percent: Int
        switch status {
        case .notYetTested:
            percent = stepsScore
        case .learning:
            let acc = min(1, (r?.last?.accuracy ?? 0) / RecitationProgress.passThreshold)
            percent = max(stepsScore, MasteryScore.firstRecite
                + Int((Double(MasteryScore.learningCeiling - MasteryScore.firstRecite) * acc).rounded()))
        case .needsWork:
            percent = MasteryScore.memorized - 10
        case .memorized:
            let base = passes == 0 ? MasteryScore.memorized : MasteryScore.reviewPoints[passes - 1]
            // After three review passes, the remaining days fill the last stretch.
            let dayBonus = passes >= 3
                ? Int(Double(MasteryScore.mastered - 1 - base) * min(1, Double(days) / Double(RecitationProgress.masteryDays)))
                : 0
            percent = min(99, base + dayBonus)
        case .mastered:
            percent = MasteryScore.mastered
        }

        let milestones = [
            MasteryMilestone(id: "start", title: "Started", points: MasteryScore.started, reached: true),
            MasteryMilestone(id: "type", title: "Type it", points: MasteryScore.typed, reached: memorized || r?.typedAt != nil),
            MasteryMilestone(id: "gaps", title: "Fill the gaps", points: MasteryScore.gaps, reached: memorized || r?.gapsAt != nil),
            MasteryMilestone(id: "mem", title: "Memorized", points: MasteryScore.memorized, reached: memorized),
            MasteryMilestone(id: "r1", title: "Review 1", points: MasteryScore.reviewPoints[0], reached: memorized && passes >= 1),
            MasteryMilestone(id: "r2", title: "Review 2", points: MasteryScore.reviewPoints[1], reached: memorized && passes >= 2),
            MasteryMilestone(id: "r3", title: "Review 3", points: MasteryScore.reviewPoints[2], reached: memorized && passes >= 3),
            MasteryMilestone(id: "master", title: "Mastered", points: MasteryScore.mastered, reached: status == .mastered),
        ]

        return MasteryScore(percent: percent, milestones: milestones,
                            nextStep: nextStepText(status: status, passes: passes, days: days))
    }

    private func nextStepText(status: VerseMemoryStatus, passes: Int, days: Int) -> String {
        let when: String = {
            if isDueForReview { return "now" }
            let d = max(1, Calendar.current.dateComponents([.day], from: Date(), to: nextReviewDate).day ?? 1)
            return d == 1 ? "tomorrow" : "in \(d) days"
        }()
        switch status {
        case .notYetTested:
            if let step = currentStep, inStepsPhase { return "Next: Step \(step.rawValue), \(step.title)" }
            return "Take the Recite test to memorize it"
        case .learning:
            let pct = Int(((recitation?.last?.accuracy ?? 0) * 100).rounded())
            return "You hit \(pct)%. Recite at 95% to memorize it"
        case .needsWork:
            return "Pass your review \(when) to get back on track"
        case .memorized:
            if passes < 3 { return "Review \(passes + 1) of 3 \(when)" }
            let left = max(1, RecitationProgress.masteryDays - days)
            return "Keep it \(left) more day\(left == 1 ? "" : "s"). Next review \(when)"
        case .mastered:
            return "Mastered. Next review \(when)"
        }
    }

    /// This verse as it would be after recording a recitation (for before/after previews).
    func applyingRecitation(accuracy: Double, method: RecitationMethod, scheduled: Bool) -> MemoryVerse {
        var copy = self
        var progress = copy.recitation ?? RecitationProgress()
        progress.record(RecitationRecord(date: Date(), accuracy: accuracy, method: method,
                                         passed: accuracy >= RecitationProgress.passThreshold),
                        scheduled: scheduled)
        copy.recitation = progress
        return copy
    }
}
