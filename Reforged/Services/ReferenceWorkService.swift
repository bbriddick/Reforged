import Foundation

/// The bundled, entry-keyed public-domain reference works (CrossWire SWORD modules).
enum ReferenceWork: String, CaseIterable, Identifiable {
    case easton       // Easton's Bible Dictionary — English headwords
    case abbottSmith  // Abbott-Smith Manual Greek Lexicon — Greek lemmas
    case nave         // Nave's Topical Bible — topics
    case tcr          // Thompson Chain topics — keywords

    var id: String { rawValue }

    var resource: String {
        switch self {
        case .easton: return "Easton"
        case .abbottSmith: return "AbbottSmith"
        case .nave: return "Nave"
        case .tcr: return "TCR"
        }
    }

    var displayName: String {
        switch self {
        case .easton: return "Easton's Bible Dictionary"
        case .abbottSmith: return "Abbott-Smith Greek Lexicon"
        case .nave: return "Nave's Topical Bible"
        case .tcr: return "Thompson Chain Topics"
        }
    }
}

/// A resolved reference-work entry.
struct ReferenceEntry: Identifiable, Equatable {
    let work: ReferenceWork
    let headword: String
    let text: String
    var id: String { "\(work.rawValue):\(headword)" }
}

/// Headword/topic lookup across the bundled dictionaries and topical works. Matching is
/// accent- and case-insensitive (so a tapped Greek lemma matches Abbott-Smith regardless of
/// diacritics, and English words match Easton/Nave/Thompson regardless of case). Mirrors the
/// `CrossReferenceService` load pattern.
final class ReferenceWorkService {
    static let shared = ReferenceWorkService()

    private struct Loaded {
        /// Original headword -> text.
        let entries: [String: String]
        /// Folded headword -> original headword, for tolerant lookup.
        let foldedKeys: [String: String]
    }

    private var loaded: [ReferenceWork: Loaded] = [:]
    private var attempted: Set<ReferenceWork> = []

    private init() {}

    /// Case/accent-insensitive lookup of a single work.
    func entry(_ work: ReferenceWork, for term: String) -> ReferenceEntry? {
        ensureLoaded(work)
        guard let data = loaded[work] else { return nil }
        let folded = Self.fold(term)
        guard !folded.isEmpty, let original = data.foldedKeys[folded],
              let text = data.entries[original] else { return nil }
        return ReferenceEntry(work: work, headword: original, text: text)
    }

    /// Easton entry for an English word.
    func eastonEntry(for word: String) -> ReferenceEntry? { entry(.easton, for: word) }

    /// Abbott-Smith entry for a Greek lemma (diacritics ignored).
    func greekEntry(forLemma lemma: String) -> ReferenceEntry? { entry(.abbottSmith, for: lemma) }

    /// Topical entries (Nave + Thompson) whose headword matches the term.
    func topicalEntries(for term: String) -> [ReferenceEntry] {
        [.nave, .tcr].compactMap { entry($0, for: term) }
    }

    /// Fuzzy headword search across all works (exact + prefix), for the search bars and the
    /// Study Library browser. Exact matches rank first, then shorter headwords.
    func search(_ term: String, limit: Int = 8) -> [ReferenceEntry] {
        let folded = Self.fold(term)
        guard folded.count >= 2 else { return [] }

        var hits: [ReferenceEntry] = []
        for work in ReferenceWork.allCases {
            ensureLoaded(work)
            guard let data = loaded[work] else { continue }
            for (foldedKey, original) in data.foldedKeys where foldedKey.hasPrefix(folded) {
                if let text = data.entries[original] {
                    hits.append(ReferenceEntry(work: work, headword: original, text: text))
                }
                if hits.count >= limit * 6 { break }
            }
        }
        hits.sort { a, b in
            let ea = Self.fold(a.headword) == folded, eb = Self.fold(b.headword) == folded
            if ea != eb { return ea }
            if a.headword.count != b.headword.count { return a.headword.count < b.headword.count }
            return a.headword < b.headword
        }
        return Array(hits.prefix(limit))
    }

    private func ensureLoaded(_ work: ReferenceWork) {
        guard !attempted.contains(work) else { return }
        attempted.insert(work)

        guard let url = Bundle.main.url(forResource: work.resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: String].self, from: data) else {
            debugLog("ReferenceWorkService: Could not load \(work.resource).json")
            return
        }
        var foldedKeys: [String: String] = [:]
        for key in entries.keys {
            foldedKeys[Self.fold(key)] = key
        }
        loaded[work] = Loaded(entries: entries, foldedKeys: foldedKeys)
    }

    /// Normalize for tolerant matching: strip diacritics + case.
    private static func fold(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
