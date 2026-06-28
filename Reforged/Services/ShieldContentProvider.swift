import Foundation

// MARK: - Shield Encouragement Model
//
// One encouraging pairing shown on the Focus & Purity Shield overlay: a short
// suggestion that points back into Reforged, plus an uplifting verse. Encoded as
// JSON into the shared App Group so the ReforgedShield extension can read it
// synchronously at shield-display time (it cannot call the network itself).
//
// NOTE: ReforgedShield/ShieldConfigurationExtension.swift decodes the SAME JSON
// shape with its own local copy of this struct. Keep the keys in sync.

struct ShieldEncouragement: Codable, Equatable {
    let suggestion: String
    let verseText: String
    let verseReference: String
}

// MARK: - Shield Content Provider

/// Generates encouraging shield content with Gemini (when available) and caches
/// it into the shared App Group for the shield extension to read. Always seeds a
/// bundled fallback so the overlay is meaningful even before AI has ever run.
@MainActor
final class ShieldContentProvider {

    static let shared = ShieldContentProvider()
    private init() {}

    private let suiteName = "group.com.reforged.app"

    private enum Keys {
        static let payload     = "shieldEncouragements"
        static let refreshedAt = "shieldEncouragementsRefreshedAt"
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// How often to regenerate the AI-curated pool.
    private let refreshInterval: TimeInterval = 24 * 60 * 60

    // MARK: - Public

    /// Ensure the shared store has content, and refresh the AI pool at most once
    /// per day. Safe to call on every foreground / block-apply.
    func refreshIfNeeded() {
        seedFallbackIfEmpty()

        let last = sharedDefaults?.object(forKey: Keys.refreshedAt) as? Date
        if let last, Date().timeIntervalSince(last) < refreshInterval {
            return
        }

        Task { await refreshFromGemini() }
    }

    // MARK: - Generation

    private func refreshFromGemini() async {
        do {
            let aiItems = try await GeminiService.shared.generateShieldEncouragements(count: 6)
            guard !aiItems.isEmpty else { return }

            // Blend the AI verses with the bundled, app-habit suggestions so the
            // overlay always nudges toward Reforged's own features too.
            let combined = aiItems + ShieldContentProvider.fallbackEncouragements
            store(combined)
            sharedDefaults?.set(Date(), forKey: Keys.refreshedAt)
        } catch {
            debugLog("[ShieldContentProvider] Gemini refresh failed: \(error.localizedDescription)")
            // Fallback already seeded; leave it in place.
        }
    }

    // MARK: - Storage

    private func store(_ items: [ShieldEncouragement]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        sharedDefaults?.set(data, forKey: Keys.payload)
    }

    private func seedFallbackIfEmpty() {
        guard let defaults = sharedDefaults else { return }
        if defaults.data(forKey: Keys.payload) == nil {
            store(ShieldContentProvider.fallbackEncouragements)
        }
    }

    // MARK: - Bundled Fallback

    /// Always-available pairings (no AI required). Suggestions point back into the
    /// app's own habits; verses are the KJV/ESV-shared public-domain wording.
    static let fallbackEncouragements: [ShieldEncouragement] = [
        ShieldEncouragement(
            suggestion: "Open Reforged and review your memory verses",
            verseText: "I have stored up your word in my heart, that I might not sin against you.",
            verseReference: "Psalm 119:11"
        ),
        ShieldEncouragement(
            suggestion: "Read a chapter in Reforged instead",
            verseText: "Your word is a lamp to my feet and a light to my path.",
            verseReference: "Psalm 119:105"
        ),
        ShieldEncouragement(
            suggestion: "Take two minutes to pray",
            verseText: "Do not be anxious about anything, but in everything by prayer and supplication with thanksgiving let your requests be made known to God.",
            verseReference: "Philippians 4:6"
        ),
        ShieldEncouragement(
            suggestion: "Write a line in your journal",
            verseText: "Create in me a clean heart, O God, and renew a right spirit within me.",
            verseReference: "Psalm 51:10"
        ),
        ShieldEncouragement(
            suggestion: "Set your mind on what is good",
            verseText: "Finally, brothers, whatever is true, whatever is honorable, whatever is just, whatever is pure, whatever is lovely... think about these things.",
            verseReference: "Philippians 4:8"
        ),
        ShieldEncouragement(
            suggestion: "Flee — and turn toward the Lord",
            verseText: "No temptation has overtaken you that is not common to man. God is faithful... he will also provide the way of escape.",
            verseReference: "1 Corinthians 10:13"
        ),
        ShieldEncouragement(
            suggestion: "Walk by the Spirit right now",
            verseText: "Walk by the Spirit, and you will not gratify the desires of the flesh.",
            verseReference: "Galatians 5:16"
        ),
        ShieldEncouragement(
            suggestion: "Run to the One who understands",
            verseText: "For we do not have a high priest who is unable to sympathize with our weaknesses, but one who in every respect has been tempted as we are, yet without sin.",
            verseReference: "Hebrews 4:15"
        ),
        ShieldEncouragement(
            suggestion: "Offer yourself to God instead",
            verseText: "Do not present your members to sin as instruments for unrighteousness, but present yourselves to God.",
            verseReference: "Romans 6:13"
        ),
        ShieldEncouragement(
            suggestion: "Look up — you were raised with Christ",
            verseText: "Set your minds on things that are above, not on things that are on earth.",
            verseReference: "Colossians 3:2"
        ),
        ShieldEncouragement(
            suggestion: "You belong to Him — you were bought with a price",
            verseText: "Flee from sexual immorality... you are not your own, for you were bought with a price. So glorify God in your body.",
            verseReference: "1 Corinthians 6:18-20"
        ),
        ShieldEncouragement(
            suggestion: "Draw near and He will draw near",
            verseText: "Submit yourselves therefore to God. Resist the devil, and he will flee from you. Draw near to God, and he will draw near to you.",
            verseReference: "James 4:7-8"
        ),
        ShieldEncouragement(
            suggestion: "Stand firm — His grace is enough",
            verseText: "My grace is sufficient for you, for my power is made perfect in weakness.",
            verseReference: "2 Corinthians 12:9"
        )
    ]
}
