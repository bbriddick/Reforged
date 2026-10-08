import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Journal & Bible Models

struct RichTextNoteContent: Codable, Equatable {
    let plainText: String
    let rtfBase64: String

    init(plainText: String, rtfBase64: String) {
        self.plainText = plainText
        self.rtfBase64 = rtfBase64
    }

    var isEffectivelyEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func fromPlainText(_ text: String) -> RichTextNoteContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        #if canImport(UIKit)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label
        ]
        let attributed = NSAttributedString(string: trimmed, attributes: attributes)
        return RichTextNoteContent(attributedString: attributed)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    init?(attributedString: NSAttributedString) {
        let plainText = attributedString.string
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let range = NSRange(location: 0, length: attributedString.length)
        guard let data = try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            return nil
        }
        self.plainText = plainText
        self.rtfBase64 = data.base64EncodedString()
    }

    var attributedString: NSAttributedString {
        guard let data = Data(base64Encoded: rtfBase64),
              let attributed = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.rtf
                ],
                documentAttributes: nil
              ) else {
            return NSAttributedString(
                string: plainText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 17),
                    .foregroundColor: UIColor.label
                ]
            )
        }
        return attributed
    }
    #endif
}

struct JournalEntry: Codable, Identifiable {
    let id: String
    let date: String
    var content: String
    var formattedContent: RichTextNoteContent?
    var tags: [String]
    var linkedVerse: String?       // legacy single-verse field (kept for backward compat)
    var linkedVerses: [String]     // multi-verse support
    var linkedLesson: String?
    var linkedInsight: String?
    var prompt: String?
    var reflectionMethod: String?   // structured method acronym, e.g. "SOAP" (see ReflectionTemplate)

    // MARK: Organization (Notes library)
    /// Optional user-given title. When nil the first line of content is used.
    var title: String?
    /// ID of the folder this note belongs to (nil = "All Notes" / no folder).
    var folderId: String?
    /// Category classification (see `NoteCategory`); nil = general.
    var category: String?
    /// Pinned notes float to the top of the library.
    var isPinned: Bool
    /// Last modified timestamp (ISO-8601). Falls back to `date` for legacy entries.
    var updatedAt: String

    /// All linked verses, merging legacy `linkedVerse` with `linkedVerses`.
    var allLinkedVerses: [String] {
        var result = linkedVerses
        if let legacy = linkedVerse, !legacy.isEmpty, !result.contains(legacy) {
            result.insert(legacy, at: 0)
        }
        return result
    }

    var renderedContentText: String {
        let richText = formattedContent?.plainText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !richText.isEmpty {
            return richText
        }
        return content
    }

    /// The category, resolved to the enum (general when unset/unknown).
    var resolvedCategory: NoteCategory {
        NoteCategory(rawValue: category ?? "") ?? .general
    }

    /// Title shown in lists: explicit title, else the first non-empty line of the body.
    var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        let firstLine = renderedContentText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine, !firstLine.isEmpty { return firstLine }
        return "New Note"
    }

    /// Body preview with the title line removed when the title is implicit.
    var previewBody: String {
        let full = renderedContentText.trimmingCharacters(in: .whitespacesAndNewlines)
        // If no explicit title, drop the first line (it's used as the title).
        if title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            let parts = full.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
        return full
    }

    init(id: String, date: String, content: String, tags: [String],
         formattedContent: RichTextNoteContent? = nil,
         linkedVerse: String? = nil, linkedVerses: [String] = [],
         linkedLesson: String? = nil, linkedInsight: String? = nil,
         prompt: String? = nil, reflectionMethod: String? = nil,
         title: String? = nil, folderId: String? = nil, category: String? = nil,
         isPinned: Bool = false, updatedAt: String? = nil) {
        self.id = id
        self.date = date
        self.content = content
        self.formattedContent = formattedContent ?? RichTextNoteContent.fromPlainText(content)
        self.tags = tags
        self.linkedVerse = linkedVerse
        self.linkedVerses = linkedVerses
        self.linkedLesson = linkedLesson
        self.linkedInsight = linkedInsight
        self.prompt = prompt
        self.reflectionMethod = reflectionMethod
        self.title = title
        self.folderId = folderId
        self.category = category
        self.isPinned = isPinned
        self.updatedAt = updatedAt ?? date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self,   forKey: .id)
        date          = try c.decode(String.self,   forKey: .date)
        content       = try c.decode(String.self,   forKey: .content)
        formattedContent = try c.decodeIfPresent(RichTextNoteContent.self, forKey: .formattedContent)
        tags          = try c.decode([String].self, forKey: .tags)
        linkedVerse   = try c.decodeIfPresent(String.self,   forKey: .linkedVerse)
        linkedVerses  = (try c.decodeIfPresent([String].self, forKey: .linkedVerses)) ?? []
        linkedLesson  = try c.decodeIfPresent(String.self,   forKey: .linkedLesson)
        linkedInsight = try c.decodeIfPresent(String.self,   forKey: .linkedInsight)
        prompt        = try c.decodeIfPresent(String.self,   forKey: .prompt)
        reflectionMethod = try c.decodeIfPresent(String.self, forKey: .reflectionMethod)
        title         = try c.decodeIfPresent(String.self,   forKey: .title)
        folderId      = try c.decodeIfPresent(String.self,   forKey: .folderId)
        category      = try c.decodeIfPresent(String.self,   forKey: .category)
        isPinned      = (try c.decodeIfPresent(Bool.self,    forKey: .isPinned)) ?? false
        updatedAt     = (try c.decodeIfPresent(String.self,  forKey: .updatedAt)) ?? date
        if formattedContent == nil {
            formattedContent = RichTextNoteContent.fromPlainText(content)
        }
    }
}

// MARK: - Note Organization Models

/// A fixed palette of accent colors used by folders and categories.
/// Stored as a raw string so the color mapping (which needs SwiftUI) can live
/// in the view layer.
enum NoteAccent: String, Codable, CaseIterable, Identifiable {
    case gold, coral, navy, blue, green, purple, orange, pink

    var id: String { rawValue }
}

/// A user-created folder that can hold both journal reflections and Bible notes.
struct NoteFolder: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var icon: String          // SF Symbol name
    var accent: NoteAccent
    var sortIndex: Int
    let createdAt: String

    init(id: String = UUID().uuidString,
         name: String,
         icon: String = "folder.fill",
         accent: NoteAccent = .navy,
         sortIndex: Int = 0,
         createdAt: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.accent = accent
        self.sortIndex = sortIndex
        self.createdAt = createdAt ?? AppDateFormatters.iso8601.string(from: Date())
    }
}

/// A lightweight classification applied to a note, orthogonal to folders.
enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case general
    case reflection
    case sermon
    case prayer
    case study
    case gratitude
    case devotion
    case question

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "Note"
        case .reflection: return "Reflection"
        case .sermon:     return "Sermon"
        case .prayer:     return "Prayer"
        case .study:      return "Study"
        case .gratitude:  return "Gratitude"
        case .devotion:   return "Devotion"
        case .question:   return "Question"
        }
    }

    var icon: String {
        switch self {
        case .general:    return "note.text"
        case .reflection: return "pencil.line"
        case .sermon:     return "person.wave.2.fill"
        case .prayer:     return "hands.sparkles.fill"
        case .study:      return "books.vertical.fill"
        case .gratitude:  return "heart.fill"
        case .devotion:   return "sun.max.fill"
        case .question:   return "questionmark.circle.fill"
        }
    }

    var accent: NoteAccent {
        switch self {
        case .general:    return .navy
        case .reflection: return .navy
        case .sermon:     return .blue
        case .prayer:     return .purple
        case .study:      return .gold
        case .gratitude:  return .coral
        case .devotion:   return .orange
        case .question:   return .green
        }
    }

    /// Categories offered in pickers (general first as the default).
    static var selectable: [NoteCategory] { allCases }
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

enum JournalPrompts {
    static let all: [String] = [
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

    /// Returns a random selection of journal prompts.
    static func random(count: Int = 6) -> [String] {
        Array(all.shuffled().prefix(count))
    }
}

/// Returns a random selection of journal prompts (fresh set each time).
func randomJournalPrompts(count: Int = 6) -> [String] {
    JournalPrompts.random(count: count)
}
