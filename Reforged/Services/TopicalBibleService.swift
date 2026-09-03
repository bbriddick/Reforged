import Foundation

/// A verse ranked under a topic, e.g. reference "Philippians 4:6-7" with community votes.
struct TopicalVerseEntry: Codable, Identifiable, Equatable {
    let reference: String
    let votes: Int

    var id: String { reference }
}

/// Offline topic-to-verse lookups, bundled from the openbible.info Topical Bible
/// dataset (CC-BY, community-voted rankings). Synchronous lookup — no network involved.
final class TopicalBibleService {
    static let shared = TopicalBibleService()

    private struct TopicalData: Codable {
        let topics: [String: [TopicalVerseEntry]]
        let verseTopics: [String: [String]]
    }

    private var data: TopicalData?
    private var sortedTopicNames: [String] = []

    private init() {}

    /// Ranked verses for a topic like "anxiety", sorted by descending votes.
    func verses(for topic: String) -> [TopicalVerseEntry] {
        ensureLoaded()
        return data?.topics[normalize(topic)] ?? []
    }

    /// Topic names matching a search query — exact/prefix matches first, then substring.
    func matchingTopics(for query: String, limit: Int = 5) -> [String] {
        let q = normalize(query)
        guard q.count >= 3 else { return [] }
        ensureLoaded()

        var prefixMatches: [String] = []
        var substringMatches: [String] = []
        for topic in sortedTopicNames {
            if topic.hasPrefix(q) {
                prefixMatches.append(topic)
            } else if topic.contains(q) {
                substringMatches.append(topic)
            }
            if prefixMatches.count >= limit { break }
        }
        return Array((prefixMatches + substringMatches).prefix(limit))
    }

    /// Topics a verse reference like "John 3:16" ranks in, strongest first.
    func topics(for verseReference: String) -> [String] {
        ensureLoaded()
        return data?.verseTopics[verseReference] ?? []
    }

    private func normalize(_ topic: String) -> String {
        topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func ensureLoaded() {
        guard data == nil else { return }

        guard let url = Bundle.main.url(forResource: "TopicalVerses", withExtension: "json") else {
            debugLog("TopicalBibleService: Could not find TopicalVerses.json in bundle")
            data = TopicalData(topics: [:], verseTopics: [:])
            return
        }

        do {
            let raw = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(TopicalData.self, from: raw)
            data = decoded
            sortedTopicNames = decoded.topics.keys.sorted()
        } catch {
            debugLog("TopicalBibleService: Failed to load TopicalVerses.json: \(error)")
            data = TopicalData(topics: [:], verseTopics: [:])
        }
    }
}
