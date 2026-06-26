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
            print("[ShieldContentProvider] Gemini refresh failed: \(error.localizedDescription)")
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
        )
    ]
}
