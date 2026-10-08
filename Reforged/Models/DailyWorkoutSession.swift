import Foundation
import SwiftUI

/// Represents an individual stage in today's guided workout
enum WorkoutStageType: String, CaseIterable, Identifiable {
    case listen
    case phraseByPhrase
    case dragAndDrop
    case fillBlank
    case sayItBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listen: return "Listen & Absorb"
        case .phraseByPhrase: return "Phrase by Phrase"
        case .dragAndDrop: return "Word Placement"
        case .fillBlank: return "Fill in the Blank"
        case .sayItBack: return "Say It Back"
        }
    }

    var subtitle: String {
        switch self {
        case .listen: return "Listen to the verse read aloud while following the words"
        case .phraseByPhrase: return "Tap through each phrase to build mental rhythm"
        case .dragAndDrop: return "Snap the scrambled words into their correct order"
        case .fillBlank: return "Retrieve missing keywords from memory"
        case .sayItBack: return "Speak the scripture aloud into the microphone"
        }
    }

    var icon: String {
        switch self {
        case .listen: return "headphones"
        case .phraseByPhrase: return "hand.tap.fill"
        case .dragAndDrop: return "hand.draw.fill"
        case .fillBlank: return "text.badge.plus"
        case .sayItBack: return "mic.fill"
        }
    }

    var xpReward: Int {
        switch self {
        case .listen: return 10
        case .phraseByPhrase: return 15
        case .dragAndDrop: return 20
        case .fillBlank: return 25
        case .sayItBack: return 35
        }
    }
}

/// The daily structured workout session model
struct DailyWorkoutSession: Identifiable {
    let id = UUID()
    let verse: MemoryVerse
    let stages: [WorkoutStageType]
    var currentStageIndex: Int = 0
    var completedStageIndices: Set<Int> = []
    var totalXPEarned: Int = 0

    var currentStage: WorkoutStageType? {
        guard currentStageIndex < stages.count else { return nil }
        return stages[currentStageIndex]
    }

    var progress: Double {
        guard !stages.isEmpty else { return 0 }
        return Double(completedStageIndices.count) / Double(stages.count)
    }

    var isComplete: Bool {
        completedStageIndices.count >= stages.count
    }

    /// Curates a personalized multi-stage workout based on verse mastery level
    static func generate(for verse: MemoryVerse) -> DailyWorkoutSession {
        let stages: [WorkoutStageType]
        switch verse.level {
        case 1: // Learning
            stages = [.listen, .phraseByPhrase, .dragAndDrop, .sayItBack]
        case 2: // Familiar
            stages = [.phraseByPhrase, .dragAndDrop, .fillBlank, .sayItBack]
        case 3: // Known
            stages = [.dragAndDrop, .fillBlank, .sayItBack]
        case 4, 5: // Well-known / Mastered
            stages = [.fillBlank, .sayItBack]
        default:
            stages = [.listen, .phraseByPhrase, .dragAndDrop, .sayItBack]
        }
        return DailyWorkoutSession(verse: verse, stages: stages)
    }
}

/// Persistent tracker for today's lesson status
final class DailyMemoryPlanManager: ObservableObject {
    static let shared = DailyMemoryPlanManager()

    private let completionDateKey = "reforged_last_memory_lesson_date"
    private let completedVerseIdKey = "reforged_last_memory_lesson_verse_id"

    @Published var completedToday: Bool = false

    private init() {
        checkTodayCompletion()
    }

    func checkTodayCompletion() {
        let today = AppDateFormatters.yearMonthDay.string(from: Date())
        if let savedDate = UserDefaults.standard.string(forKey: completionDateKey), savedDate == today {
            completedToday = true
        } else {
            completedToday = false
        }
    }

    func markTodayCompleted(verseId: String) {
        let today = AppDateFormatters.yearMonthDay.string(from: Date())
        UserDefaults.standard.set(today, forKey: completionDateKey)
        UserDefaults.standard.set(verseId, forKey: completedVerseIdKey)
        completedToday = true
    }
}
