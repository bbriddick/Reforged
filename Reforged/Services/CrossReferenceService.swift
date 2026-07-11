import Foundation

/// A single cross-reference target, e.g. reference "Hebrews 11:3" with a confidence score.
struct CrossReferenceEntry: Codable, Identifiable, Equatable {
    let reference: String
    let votes: Int

    var id: String { reference }
}

/// Offline verse-to-verse cross references, bundled from the Treasury of Scripture Knowledge
/// dataset (openbible.info, CC-BY). Synchronous lookup — no network involved.
final class CrossReferenceService {
    static let shared = CrossReferenceService()

    private var crossReferencesByVerse: [String: [CrossReferenceEntry]]?

    private init() {}

    /// Cross references for a verse reference like "John 3:16", sorted by descending votes.
    func crossReferences(for reference: String) -> [CrossReferenceEntry] {
        ensureLoaded()
        return crossReferencesByVerse?[reference] ?? []
    }

    private func ensureLoaded() {
        guard crossReferencesByVerse == nil else { return }

        guard let url = Bundle.main.url(forResource: "CrossReferences", withExtension: "json") else {
            debugLog("CrossReferenceService: Could not find CrossReferences.json in bundle")
            crossReferencesByVerse = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            crossReferencesByVerse = try JSONDecoder().decode([String: [CrossReferenceEntry]].self, from: data)
        } catch {
            debugLog("CrossReferenceService: Failed to load CrossReferences.json: \(error)")
            crossReferencesByVerse = [:]
        }
    }
}
