import Foundation

// MARK: - Memory Verse Models

struct MemoryVerse: Codable, Identifiable {
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

    var isDueForReview: Bool {
        return nextReviewDate <= Date()
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
            newInterval = 6
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

struct MemoryVerseModeStats: Codable {
    var fillInBlank: ModeAttemptStats
    var firstLetter: ModeAttemptStats
    var typing: TypingStats
    var flashcard: FlashcardStats
    var tapToReveal: ModeAttemptStats?
    var dragAndDrop: ModeAttemptStats?
}

struct ModeAttemptStats: Codable {
    var attempts: Int
    var accuracy: Double
}

struct TypingStats: Codable {
    var attempts: Int
    var accuracy: Double
    var bestWpm: Int?
}

struct FlashcardStats: Codable {
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
        case .firstLetter: return "Use first letters as hints"
        case .typing: return "Type the entire verse"
        }
    }
}
