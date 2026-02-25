import Foundation

// MARK: - Journal & Bible Models

struct JournalEntry: Codable, Identifiable {
    let id: String
    let date: String
    var content: String
    var tags: [String]
    var linkedVerse: String?
    var linkedLesson: String?
    var linkedInsight: String?
    var prompt: String?
}

struct DailyInsight: Codable, Identifiable {
    let id: String
    let date: String
    let title: String
    let verse: String
    let verseText: String
    let reflection: String
    let prayerPrompt: String?

    // Backwards compatibility
    var summary: String { reflection }
    var scripture: String { verse }
    var scriptureText: String? { verseText }
}

// MARK: - Verse Pack Models

struct VersePack: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: VersePackCategory
    let icon: String
    let color: String
    let verses: [VersePackVerse]
}

enum VersePackCategory: String, Codable {
    case topical
    case doctrinal
    case user
}

struct VersePackVerse: Codable, Identifiable {
    let id: String
    let reference: String
    let text: String
}

// MARK: - Bible Reading Models

struct BibleHighlight: Codable, Identifiable {
    let id: String
    let book: String
    let chapter: Int
    let verseStart: Int
    var verseEnd: Int?
    let color: String
    let createdAt: String
}

struct BibleNote: Codable, Identifiable {
    let id: String
    let book: String
    let chapter: Int
    let verse: Int
    var content: String
    let createdAt: String
}

struct ReadingPlan: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let totalDays: Int
    let icon: String
}

struct ReadingPlanProgress: Codable {
    let planId: String
    var currentDay: Int
    var completedReadings: [String]
    let startDate: String
    var lastReadDate: String?
}

struct BibleReading: Codable {
    let day: Int
    let passages: [BiblePassage]
}

struct BiblePassage: Codable {
    let book: String
    let chapter: Int
    var verses: String?
    var text: String?
}

// MARK: - Journal Prompts

let allJournalPrompts: [String] = [
    // Reflection & Understanding
    "What stood out to you in today's reading?",
    "What is God teaching you today?",
    "What truth do you need to remember?",
    "How does this passage reveal God's character?",
    "What prayer rises from your heart after this?",
    "What word or phrase kept drawing your attention?",
    "If you could summarize this passage in one sentence, what would it be?",
    "What question does this passage raise for you?",
    "How would you explain this passage to a friend?",
    "What is the main promise or command in this text?",
    "What was surprising or unexpected in this reading?",

    // Personal Application
    "How will you apply this to your life?",
    "What sin does this passage challenge you to turn from?",
    "What habit or practice is God calling you to start?",
    "Where in your life do you need to trust God more?",
    "What relationship could benefit from this truth?",
    "How does this passage speak to something you're currently going through?",
    "What would change if you fully believed this passage?",
    "What step of obedience is God asking you to take today?",
    "How does this challenge your current priorities?",

    // Emotional & Heart Check
    "What emotions came up as you read this?",
    "Where is your heart resistant to what God is saying?",
    "What fear does this passage address?",
    "What burden can you release to God after reading this?",
    "How does this passage bring you comfort today?",
    "What are you grateful for after reading this?",

    // God's Character & Gospel
    "How does this passage connect to the gospel?",
    "What does this teach you about God's love?",
    "How does this passage display God's faithfulness?",
    "Where do you see God's grace in this text?",
    "What does this reveal about God's power?",
    "How does this passage point to Jesus?",

    // Community & Witness
    "Who needs to hear the truth in this passage?",
    "How can this passage shape the way you treat others today?",
    "What would it look like to live this out in your community?",
    "How does this passage call you to serve someone else?",
    "Who can you share what you learned today with?",

    // Spiritual Growth
    "What area of spiritual growth is God highlighting?",
    "How does this passage strengthen your faith?",
    "What lie have you been believing that this truth corrects?",
    "What does this passage teach about prayer?",
    "How can you meditate on this truth throughout the day?",
    "What spiritual discipline does this passage encourage?",

    // Past, Present & Future
    "How have you seen this truth play out in your life before?",
    "What would your life look like one year from now if you lived by this passage?",
    "How does this passage give you hope for the future?",
    "What past experience helps you understand this passage more deeply?",

    // Closing & Surrender
    "Write a short prayer responding to what you read.",
    "What is one thing you want to carry with you from this passage today?",
    "How can you worship God in response to this reading?",
    "What do you need to surrender to God right now?",
]

/// Returns a random selection of journal prompts (fresh set each time).
func randomJournalPrompts(count: Int = 6) -> [String] {
    Array(allJournalPrompts.shuffled().prefix(count))
}
