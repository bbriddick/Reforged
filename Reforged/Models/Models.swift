import Foundation

// MARK: - Track & Lesson Models

struct Track: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: String
    let totalLessons: Int
    var completedLessons: Int
    var lessons: [Lesson]
}

struct Lesson: Codable, Identifiable {
    let id: String
    let trackId: String
    let title: String
    let description: String
    let order: Int
    let xpReward: Int
    var isCompleted: Bool
    let content: [LessonContent]
}

struct LessonContent: Codable, Identifiable {
    let id: String
    let type: LessonContentType
    let data: LessonContentData
}

enum LessonContentType: String, Codable {
    case scripture
    case explanation
    case question
    case reflection
}

enum LessonContentData: Codable {
    case scripture(ScriptureContent)
    case explanation(ExplanationContent)
    case question(QuestionContent)
    case reflection(ReflectionContent)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let scripture = try? container.decode(ScriptureContent.self) {
            self = .scripture(scripture)
        } else if let explanation = try? container.decode(ExplanationContent.self) {
            self = .explanation(explanation)
        } else if let question = try? container.decode(QuestionContent.self) {
            self = .question(question)
        } else if let reflection = try? container.decode(ReflectionContent.self) {
            self = .reflection(reflection)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown content type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .scripture(let content): try container.encode(content)
        case .explanation(let content): try container.encode(content)
        case .question(let content): try container.encode(content)
        case .reflection(let content): try container.encode(content)
        }
    }
}

struct ScriptureContent: Codable {
    let reference: String
    let text: String
    var version: String?
}

struct ExplanationContent: Codable {
    var title: String?
    let text: String
}

struct QuestionContent: Codable {
    let question: String
    let type: QuestionType
    var options: [AnswerChoice]?
    let correctAnswer: String
    let explanation: String
}

enum QuestionType: String, Codable {
    case multipleChoice = "multiple-choice"
    case fillBlank = "fill-blank"
}

struct AnswerChoice: Codable, Identifiable {
    let id: String
    let text: String
}

struct ReflectionContent: Codable {
    let prompt: String
}
