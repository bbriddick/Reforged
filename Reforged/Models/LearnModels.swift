import Foundation

// MARK: - Learn / Tracks Models
//
// Read-side models for the expanded track system (leader_tracks → track_lessons
// → track_items). Verified against the LIVE Supabase schema on 2026-07-21:
//   • the block jsonb column is `content` (NOT `payload` as the spec stated),
//   • `track_lessons` has no `summary` column,
//   • `track_group_assignments` has no `id` (composite key).
// Every payload field is decoded defensively (optional) and unknown block types
// fall through to `.unknown` rather than crashing.

// MARK: - Track (leader_tracks)

struct LearnTrack: Codable, Identifiable, Hashable {
    let id: String
    let ownerId: String?
    let title: String
    let description: String?
    let summary: String?
    let coverImagePath: String?
    let publishedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, summary
        case ownerId        = "owner_id"
        case coverImagePath  = "cover_image_path"
        case publishedAt     = "published_at"
        case createdAt       = "created_at"
    }

    /// Published within the last 7 days → show a "New" badge.
    var isNew: Bool {
        guard let date = LearnDate.parse(publishedAt) else { return false }
        return Date().timeIntervalSince(date) < 7 * 24 * 3600 && date <= Date()
    }
}

// MARK: - Lesson (track_lessons)

struct TrackLesson: Codable, Identifiable, Hashable {
    let id: String
    let trackId: String
    let position: Int
    let title: String?
    let publishedAt: String?
    let createdAt: String?
    /// Optional per-lesson thumbnail (group-covers bucket). Decodes to nil until
    /// the backend adds `track_lessons.cover_image_path` — see the leader-console
    /// note. Safe against the column being absent.
    let coverImagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, position, title
        case trackId        = "track_id"
        case publishedAt    = "published_at"
        case createdAt      = "created_at"
        case coverImagePath = "cover_image_path"
    }
}

// MARK: - Block (track_items) + typed payload

struct LessonBlock: Identifiable {
    let id: String
    let lessonId: String?
    let trackId: String?
    let position: Int
    let type: String
    let payload: BlockPayload
}

/// Typed content block payloads, built defensively from the `content` jsonb.
enum BlockPayload {
    case reading(reference: String?, translation: String?, body: String?)
    case memory(reference: String?, translation: String?, text: String?)
    case prompt(question: String?, guidance: String?)
    case video(url: String?, title: String?, provider: String?)
    case audio(url: String?, title: String?, durationSeconds: Int?)
    case handout(handoutId: String?, title: String?)
    case question(question: String?, answerType: String?, choices: [String]?)
    case discussion(prompt: String?, notes: String?)
    case notes(body: String?)
    case unknown(type: String)

    init(type: String, content c: RawBlockContent?) {
        switch type.lowercased() {
        case "reading":    self = .reading(reference: c?.reference, translation: c?.translation, body: c?.body)
        case "memory":     self = .memory(reference: c?.reference, translation: c?.translation, text: c?.text)
        case "prompt":     self = .prompt(question: c?.question ?? c?.prompt, guidance: c?.guidance)
        case "video":      self = .video(url: c?.url, title: c?.title, provider: c?.provider)
        case "audio":      self = .audio(url: c?.url, title: c?.title, durationSeconds: c?.durationSeconds)
        case "handout":    self = .handout(handoutId: c?.handoutId, title: c?.title)
        case "question":   self = .question(question: c?.question ?? c?.prompt, answerType: c?.answerType, choices: c?.choices)
        case "discussion": self = .discussion(prompt: c?.prompt ?? c?.question, notes: c?.notes)
        case "notes":      self = .notes(body: c?.body ?? c?.notes ?? c?.text)
        default:           self = .unknown(type: type)
        }
    }
}

// MARK: - Decoding rows

/// PostgREST row for a `track_items` record; `content` is the block jsonb.
struct TrackItemRow: Decodable {
    let id: String
    let lessonId: String?
    let trackId: String?
    let position: Int?
    let type: String?
    let content: RawBlockContent?

    enum CodingKeys: String, CodingKey {
        case id, type, content, position
        case lessonId = "lesson_id"
        case trackId  = "track_id"
    }

    func toBlock() -> LessonBlock {
        LessonBlock(id: id, lessonId: lessonId, trackId: trackId,
                    position: position ?? 0, type: type ?? "unknown",
                    payload: BlockPayload(type: type ?? "unknown", content: content))
    }
}

/// Union of every field any block payload might carry. All optional — a missing
/// or NULL field never fails the decode.
struct RawBlockContent: Decodable {
    let reference, translation, body, text: String?
    let question, guidance, prompt, notes: String?
    let url, title, provider, handoutId, answerType: String?
    let durationSeconds: Int?
    let choices: [String]?

    enum CodingKeys: String, CodingKey {
        case reference, translation, body, text, question, guidance, prompt, notes
        case url, title, provider, choices
        case handoutId      = "handout_id"
        case answerType     = "answer_type"
        case durationSeconds = "duration_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reference       = try? c.decode(String.self, forKey: .reference)
        translation     = try? c.decode(String.self, forKey: .translation)
        body            = try? c.decode(String.self, forKey: .body)
        text            = try? c.decode(String.self, forKey: .text)
        question        = try? c.decode(String.self, forKey: .question)
        guidance        = try? c.decode(String.self, forKey: .guidance)
        prompt          = try? c.decode(String.self, forKey: .prompt)
        notes           = try? c.decode(String.self, forKey: .notes)
        url             = try? c.decode(String.self, forKey: .url)
        title           = try? c.decode(String.self, forKey: .title)
        provider        = try? c.decode(String.self, forKey: .provider)
        handoutId       = try? c.decode(String.self, forKey: .handoutId)
        answerType      = try? c.decode(String.self, forKey: .answerType)
        durationSeconds = try? c.decode(Int.self,    forKey: .durationSeconds)
        choices         = try? c.decode([String].self, forKey: .choices)
    }
}

// MARK: - Date helper

enum LearnDate {
    static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
