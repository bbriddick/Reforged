import Foundation

// MARK: - Verse Collection Models

/// A user-built collection of verses (e.g. an imported Bible chapter, split by verse, or a
/// hand-assembled set). Collections are practiced as a self-contained unit and are kept
/// SEPARATE from `AppState.memoryVerses` — they never enter the SM-2 daily review queue.
struct VerseCollection: Codable, Identifiable, Equatable {
    let id: String
    var name: String                 // e.g. "Psalm 23" or a custom title
    var verses: [CollectionVerse]    // ordered as in the chapter / as added
    var translation: String?         // compact code captured at import time
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         verses: [CollectionVerse],
         translation: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.verses = verses
        self.translation = translation
        self.createdAt = createdAt
    }
}

struct CollectionVerse: Codable, Identifiable, Equatable {
    let id: String           // "<collectionId>:<reference>"
    let reference: String    // e.g. "Psalm 23:1"
    let text: String

    init(id: String = UUID().uuidString, reference: String, text: String) {
        self.id = id
        self.reference = reference
        self.text = text
    }

    /// Bridges a collection verse into a transient `MemoryVerse` so the existing game views
    /// (which require a `MemoryVerse`) can be reused unchanged. The SR fields use neutral
    /// defaults; because this verse is not stored in `AppState.memoryVerses`, any
    /// `updateVerseReview(verseId:)` call from a game no-ops safely and never touches the
    /// real review schedule.
    func asMemoryVerse(translation: String? = nil) -> MemoryVerse {
        MemoryVerse(
            id: id,
            reference: reference,
            text: text,
            esvText: nil,
            category: "Collection",
            translation: translation,
            lastFetched: nil,
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
    }
}
