import Foundation

// MARK: - Groups Feature Models
//
// Codable mirrors of the Supabase tables backing the Groups tab. All rows come
// back from PostgREST in snake_case, so every model declares explicit
// `CodingKeys`. Keep these structs *value types with no reference to fetched
// free-text that must stay server-authoritative* — see `GroupPrayer` and the
// SRS engine in `GroupPrayerReviewView` for why prayer text is never persisted.
//
// Schema note: the requirements reference a group feed (SOAP/HEAR reflections)
// and prayer requests, but those two tables are NOT in the provided schema
// list. `GroupPrayer` and `GroupFeedPost` below are coded against the assumed
// tables `prayer_requests` and `reflections`; both are flagged with
// `// ASSUMED TABLE` so the backend work is easy to find.

// MARK: - Group

struct GroupSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let inviteCode: String
    let leaderId: String
    /// Path into the (private) `group-covers` bucket for the leader's cover
    /// image; resolved to a signed URL for display.
    let coverImagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case inviteCode     = "invite_code"
        case leaderId       = "leader_id"
        case coverImagePath = "cover_image_path"
    }
}

/// A group member's display identity, assembled from `group_members` +
/// `profiles` (there's no FK between them, so it's a two-step fetch).
struct GroupMemberProfile: Identifiable, Hashable {
    let userId: String
    let displayName: String
    let avatar: String
    var id: String { userId }
}

// MARK: - Membership

struct GroupMembership: Codable, Identifiable {
    let id: String
    let groupId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId  = "user_id"
    }
}

/// Decodes the PostgREST embedded-resource shape
/// `group_members?select=groups(*)` where each membership row nests its group.
struct MembershipWithGroup: Decodable {
    let group: GroupSummary?

    enum CodingKeys: String, CodingKey {
        case group = "leader_groups"
    }
}

// MARK: - Tracks

struct GroupTrack: Codable, Identifiable {
    let id: String
    let groupId: String
    let title: String
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case groupId     = "group_id"
        case publishedAt = "published_at"
    }

    var isPublished: Bool { publishedAt != nil }
}

enum GroupTrackItemType: String, Codable {
    case reading, memory, prompt

    var iconName: String {
        switch self {
        case .reading: return "book.fill"
        case .memory:  return "brain.head.profile"
        case .prompt:  return "square.and.pencil"
        }
    }

    var label: String {
        switch self {
        case .reading: return "Reading"
        case .memory:  return "Memory Verse"
        case .prompt:  return "Journal Prompt"
        }
    }
}

struct GroupTrackItem: Codable, Identifiable {
    let id: String
    let trackId: String
    let type: GroupTrackItemType
    let content: GroupTrackItemContent

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case trackId = "track_id"
    }
}

/// Lenient decoder for the `track_items.content` jsonb column. The column is
/// free-form per item type; these are the fields the client renders. Unknown
/// keys are ignored, so the backend can add metadata without breaking clients.
struct GroupTrackItemContent: Codable {
    /// e.g. "Ephesians 1" (reading) or "Ephesians 1:4" (memory).
    let reference: String?
    /// Verse text (memory) or the prompt body (prompt).
    let text: String?
    /// Preferred translation for a reading/memory item, e.g. "ESV".
    let translation: String?

    enum CodingKeys: String, CodingKey {
        case reference, text, translation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reference   = try? c.decode(String.self, forKey: .reference)
        text        = try? c.decode(String.self, forKey: .text)
        translation = try? c.decode(String.self, forKey: .translation)
    }
}

// MARK: - Progress

/// Insert payload for `progress_logs`. `completedAt` is written client-side as
/// an ISO-8601 timestamp so an offline completion keeps its real time.
struct ProgressLogInsert: Encodable {
    let userId: String
    let groupId: String
    let itemId: String
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case groupId     = "group_id"
        case itemId      = "item_id"
        case completedAt = "completed_at"
    }
}

// MARK: - Moderation (Guideline 1.2)

enum ReportableContentType: String, Codable {
    case reflection
    case prayer
}

struct ContentReportInsert: Encodable {
    let reporterId: String
    let contentType: String
    let contentId: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterId  = "reporter_id"
        case contentType = "content_type"
        case contentId   = "content_id"
        case reason
    }
}

struct UserBlock: Codable, Identifiable {
    let id: String
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case id
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct UserBlockInsert: Encodable {
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

// MARK: - Feed (ASSUMED TABLE: reflections)

/// An opt-in shared SOAP/HEAR reflection. Free-text, minor-authored, visible to
/// peers — so it carries report/block affordances everywhere it renders.
struct GroupFeedPost: Codable, Identifiable {
    let id: String
    let groupId: String
    let authorId: String
    let authorName: String?
    let passage: String?
    /// The "Application" section only — the private observation/prayer sections
    /// are never posted (see requirements §2).
    let applicationText: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, passage
        case groupId         = "group_id"
        case authorId        = "author_id"
        case authorName      = "author_name"
        case applicationText = "application_text"
        case createdAt       = "created_at"
    }
}

// MARK: - Handouts (Sunday School lessons)

/// One published handout. `segments` renders as an interactive fill-in-the-blank
/// lesson; `storagePath` points at the original file in the `handout-uploads`
/// bucket (download via a signed URL). Only handouts with a non-nil
/// `publishedAt` are ever fetched.
struct Handout: Codable, Identifiable {
    let id: String
    let groupId: String
    let title: String
    let sourceType: String?
    let storagePath: String?
    let bodyText: String?
    let segments: [HandoutSegment]?
    let publishedAt: String?
    let scheduledFor: String?
    let trackId: String?
    let trackItemId: String?

    enum CodingKeys: String, CodingKey {
        case id, title, segments
        case groupId      = "group_id"
        case sourceType   = "source_type"
        case storagePath  = "storage_path"
        case bodyText     = "body_text"
        case publishedAt  = "published_at"
        case scheduledFor = "scheduled_for"
        case trackId      = "track_id"
        case trackItemId  = "track_item_id"
    }
}

/// A run in a handout's `segments` jsonb: either literal `text` or a `blank`
/// whose `answer` is hidden until revealed. Backend shape:
/// `{"type":"text","value":"…"}` or `{"type":"blank","answer":"…"}`.
struct HandoutSegment: Codable, Hashable {
    let type: String
    let value: String?
    let answer: String?

    var isBlank: Bool { type == "blank" }
}

// MARK: - Prayer (ASSUMED TABLE: prayer_requests)

/// A group prayer request. IMPORTANT: instances of this type that are fetched
/// for SRS review are transient view state only — never write `.text` to
/// UserDefaults, files, or any local store (see requirements §4).
struct GroupPrayer: Codable, Identifiable {
    let id: String
    let groupId: String
    let authorId: String
    let authorName: String?
    let text: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, text
        case groupId    = "group_id"
        case authorId   = "author_id"
        case authorName = "author_name"
        case createdAt  = "created_at"
    }
}

/// Insert payload for a new prayer request (`prayer_requests`). `authorName` is
/// denormalised so co-members can attribute the request without a profile join.
/// `created_at` is left to the table's server-side default.
struct PrayerRequestInsert: Encodable {
    let groupId: String
    let authorId: String
    let authorName: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case text
        case groupId    = "group_id"
        case authorId   = "author_id"
        case authorName = "author_name"
    }
}

// MARK: - Prayer Responses (ASSUMED TABLE: prayer_interactions)

/// A member's response to a group prayer request. Deliberately a *closed set* of
/// preset options — Groups is no-chat / minor-safe, so there is NO free-text
/// reply surface here. `prayed` is the primary acknowledgement ("I prayed for
/// this"); the rest are quick encouragements the author sees tallied on their
/// own request. Each response is one `prayer_interactions` row keyed by
/// `(prayer_id, user_id, kind)`; re-sending the same kind is idempotent.
enum PrayerResponseKind: String, CaseIterable, Codable, Identifiable {
    case prayed
    case liftingUp = "lifting_up"
    case withYou   = "with_you"
    case amen

    var id: String { rawValue }

    /// Emoji shown on the encouragement chips / tallies.
    var emoji: String {
        switch self {
        case .prayed:    return "🙏"
        case .liftingUp: return "🕊️"
        case .withYou:   return "❤️"
        case .amen:      return "🙌"
        }
    }

    var label: String {
        switch self {
        case .prayed:    return "I prayed"
        case .liftingUp: return "Lifting you up"
        case .withYou:   return "With you"
        case .amen:      return "Amen"
        }
    }

    /// The encouragements offered alongside the primary "I prayed" action.
    static var encouragements: [PrayerResponseKind] { [.liftingUp, .withYou, .amen] }
}
