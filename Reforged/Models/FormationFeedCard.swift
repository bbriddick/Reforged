//
//  FormationFeedCard.swift
//  Reforged
//
//  Formation Feed data model.
//
//  The Formation Feed is a Scripture-first discovery feed. Every card is meant
//  to move the reader toward a concrete formation action (read Scripture in
//  context, pray, memorize, journal, take a step of obedience, contact an
//  accountability partner, open original-language study, or save for later).
//  It is intentionally NOT a social feed: there are no public likes, follower
//  counts, or engagement metrics in this model.
//
//  Editorial content lives in `Resources/formation_feed_seed.json` and is loaded
//  by `FormationFeedContentStore`. See that file's header for how to add cards.
//
//  Design notes:
//  - No Bible text is stored on a card. Cards carry references only; the app
//    renders the reader's currently selected translation at display time using
//    the existing Bible services (ESVService / KJVService / ApiBibleService /
//    NETService), exactly like `DailyInsightCard`.
//  - Types are Codable and forward-compatible: unknown action strings and
//    malformed optional fields are dropped rather than failing the whole load,
//    so future remote content can add richer cards without breaking old clients.
//

import Foundation

// MARK: - Card type

/// The kind of formation card. Each type has a distinct role in the feed;
/// see the editorial principles in the seed JSON for how they relate.
enum FormationFeedCardType: String, Codable, CaseIterable, Hashable {
    /// A passage surfaced with its surrounding context and a reflective prompt.
    case scripture
    /// A short summary of what Scripture teaches. Never a replacement for the text.
    case truth
    /// A grace-motivated, concrete response the reader can do now.
    case practice
    /// A journaling prompt that turns a passage inward.
    case reflection
    /// A weekly examen-style check-in with several questions.
    case weeklyCheckIn
    /// A nudge to review or begin memorizing a specific verse.
    case memory
    /// An invitation into deeper study, often original-language word study.
    case studySpark

    /// A short human label suitable for a section header or chip.
    var displayName: String {
        switch self {
        case .scripture: return "Scripture"
        case .truth: return "Truth"
        case .practice: return "Practice"
        case .reflection: return "Reflection"
        case .weeklyCheckIn: return "Weekly Check-In"
        case .memory: return "Memory"
        case .studySpark: return "Study Spark"
        }
    }
}

// MARK: - Actions

/// A formation action a card can invite. These map onto existing Reforged
/// systems (Bible reader navigation, memorization, journaling, Focus & Purity
/// Shield, accountability, original-language study, save-for-later). The feed
/// UI is responsible for translating each action into the matching in-app flow.
enum FormationFeedAction: String, Codable, CaseIterable, Hashable {
    /// Open the passage in the Bible reader with surrounding context.
    case readContext
    /// Open a prayer moment or prompt.
    case pray
    /// Open the journal, optionally seeded with a placeholder.
    case journal
    /// Save the card to the reader's saved items.
    case save
    /// Start a short quiet timer (used by practices).
    case startTimer
    /// Schedule a reminder to return to this practice.
    case setReminder
    /// Create or extend a reading or practice plan.
    case createPlan
    /// Reach out to an accountability partner.
    case contactAccountability
    /// Compose a message (encouragement, confession, or check-in).
    case composeMessage
    /// Choose a verse to add to memorization.
    case chooseVerse
    /// Start a memory review session.
    case startMemoryReview
    /// Open original-language (Greek / Hebrew / Strong's) study for the reference.
    case openOriginalLanguage
    /// Open the Focus & Purity Shield to set a guardrail.
    case openFocusShield
    /// Share the reflection with the reader's group.
    case shareWithGroup

    /// A short label for a button rendering this action.
    var defaultLabel: String {
        switch self {
        case .readContext: return "Read in context"
        case .pray: return "Pray"
        case .journal: return "Journal"
        case .save: return "Save"
        case .startTimer: return "Start timer"
        case .setReminder: return "Remind me"
        case .createPlan: return "Add to plan"
        case .contactAccountability: return "Reach out"
        case .composeMessage: return "Compose"
        case .chooseVerse: return "Choose verse"
        case .startMemoryReview: return "Review"
        case .openOriginalLanguage: return "Study the word"
        case .openFocusShield: return "Set a guardrail"
        case .shareWithGroup: return "Share with group"
        }
    }
}

// MARK: - Card

/// A single Formation Feed card. Value type, `Codable` for bundled + future
/// remote content, `Identifiable` and `Hashable` for SwiftUI lists.
struct FormationFeedCard: Codable, Identifiable, Hashable {
    /// Stable, human-readable id (for example `scripture_001`). Must be unique
    /// within a collection; used for saved-state keys and deep links.
    let id: String
    let type: FormationFeedCardType
    let title: String
    /// Short feed-length body. Optional because `scripture` cards may rely on a
    /// `prompt` instead.
    let body: String?
    /// A single "primary" reference to feature (for example the memory verse).
    let reference: String?
    /// All references the card touches. Text is never stored; rendered live.
    let references: [String]
    /// The surrounding passage to open so Scripture is never proof-texted in
    /// isolation (for example `Psalm 46:1-11` for a card on `Psalm 46:10`).
    let contextReference: String?
    /// Topic tags used for filtering and personalization.
    let tags: [String]
    /// A reflective question for `scripture` cards.
    let prompt: String?
    /// A reflective question for `truth` cards.
    let reflectionPrompt: String?
    /// Seed text for the journal editor on `reflection` cards.
    let journalPlaceholder: String?
    /// The affirmation shown when a `practice` is marked done.
    let completionLabel: String?
    /// The set of questions for a `weeklyCheckIn`.
    let questions: [String]?
    /// The formation actions this card invites, in display order.
    let actions: [FormationFeedAction]

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case id, type, title, body, reference, references, contextReference
        case tags, prompt, reflectionPrompt, journalPlaceholder
        case completionLabel, questions, actions
    }

    /// Lenient decoding: `id` and `type` are required (a card missing either is
    /// treated as malformed and skipped by the store); everything else falls
    /// back to sensible defaults, and unrecognized action strings are dropped so
    /// future content stays forward-compatible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(FormationFeedCardType.self, forKey: .type)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body)
        reference = try c.decodeIfPresent(String.self, forKey: .reference)
        references = try c.decodeIfPresent([String].self, forKey: .references) ?? []
        contextReference = try c.decodeIfPresent(String.self, forKey: .contextReference)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt)
        reflectionPrompt = try c.decodeIfPresent(String.self, forKey: .reflectionPrompt)
        journalPlaceholder = try c.decodeIfPresent(String.self, forKey: .journalPlaceholder)
        completionLabel = try c.decodeIfPresent(String.self, forKey: .completionLabel)
        questions = try c.decodeIfPresent([String].self, forKey: .questions)
        let rawActions = try c.decodeIfPresent([String].self, forKey: .actions) ?? []
        actions = rawActions.compactMap { FormationFeedAction(rawValue: $0) }
    }

    /// Memberwise initializer for programmatic construction (tests, previews,
    /// or future generated cards).
    init(
        id: String,
        type: FormationFeedCardType,
        title: String,
        body: String? = nil,
        reference: String? = nil,
        references: [String] = [],
        contextReference: String? = nil,
        tags: [String] = [],
        prompt: String? = nil,
        reflectionPrompt: String? = nil,
        journalPlaceholder: String? = nil,
        completionLabel: String? = nil,
        questions: [String]? = nil,
        actions: [FormationFeedAction] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.reference = reference
        self.references = references
        self.contextReference = contextReference
        self.tags = tags
        self.prompt = prompt
        self.reflectionPrompt = reflectionPrompt
        self.journalPlaceholder = journalPlaceholder
        self.completionLabel = completionLabel
        self.questions = questions
        self.actions = actions
    }
}

// MARK: - Convenience

extension FormationFeedCard {
    /// The best reference to open the reader at: the explicit context passage if
    /// present, otherwise the primary reference, otherwise the first reference.
    var contextOrPrimaryReference: String? {
        contextReference ?? reference ?? references.first
    }

    /// All references this card involves, primary first, de-duplicated while
    /// preserving order. Handy for "read", "memorize", and study flows.
    var allReferences: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ref in ([reference].compactMap { $0 } + references) where seen.insert(ref).inserted {
            result.append(ref)
        }
        return result
    }

    /// Whether the card invites a given action.
    func offers(_ action: FormationFeedAction) -> Bool {
        actions.contains(action)
    }

    /// Case- and whitespace-insensitive tag membership.
    func hasTag(_ tag: String) -> Bool {
        let needle = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tags.contains { $0.lowercased() == needle }
    }
}
