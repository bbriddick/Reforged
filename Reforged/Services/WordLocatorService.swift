import Foundation

/// One verse in which a searched word occurs.
struct WordReference: Identifiable, Equatable {
    let reference: String   // "John 3:16"
    let text: String
    var id: String { reference }
}

/// Per-book occurrence count, in canonical book order.
struct WordBookCount: Identifiable, Equatable {
    let bookName: String
    let count: Int
    var id: String { bookName }
}

/// Result of locating a word across the whole Bible.
struct WordLocatorResult: Equatable {
    let word: String
    let totalOccurrences: Int
    let verseCount: Int
    /// All 66 books in canonical order (count may be 0), for the distribution strip.
    let perBook: [WordBookCount]
    let references: [WordReference]
}

/// Locates every occurrence of an English word across Scripture, with a per-book
/// distribution — the native counterpart to openbible.info's "Bible Word Locator" (lab #2).
/// Derived entirely from the bundled KJV text (`kjvpce.json`); no network, no new dataset.
///
/// The KJV is scanned linearly per query (~31k verses, well under a fraction of a second),
/// so no precomputed index is bundled. Verses are loaded once and cached in memory.
final class WordLocatorService {
    static let shared = WordLocatorService()

    private struct IndexedVerse {
        let bookName: String
        let reference: String
        let text: String
        let lowerText: String
    }

    private var verses: [IndexedVerse]?

    private init() {}

    /// Locates `rawWord` across the KJV. Returns nil for empty input or if the bundle is
    /// missing; a result with `totalOccurrences == 0` means the word was not found.
    func locate(_ rawWord: String) -> WordLocatorResult? {
        let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty else { return nil }
        ensureLoaded()
        guard let verses else { return nil }

        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        var perBookCount: [String: Int] = [:]
        var references: [WordReference] = []
        var total = 0

        for verse in verses {
            let range = NSRange(verse.lowerText.startIndex..., in: verse.lowerText)
            let matches = regex.numberOfMatches(in: verse.lowerText, options: [], range: range)
            guard matches > 0 else { continue }
            total += matches
            perBookCount[verse.bookName, default: 0] += matches
            references.append(WordReference(reference: verse.reference, text: verse.text))
        }

        let perBook = BibleData.books.map {
            WordBookCount(bookName: $0.name, count: perBookCount[$0.name] ?? 0)
        }
        return WordLocatorResult(
            word: word,
            totalOccurrences: total,
            verseCount: references.count,
            perBook: perBook,
            references: references
        )
    }

    private func ensureLoaded() {
        guard verses == nil else { return }

        guard let url = Bundle.main.url(forResource: "kjvpce", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            debugLog("WordLocatorService: Could not load kjvpce.json from bundle")
            verses = []
            return
        }

        struct BundledJSON: Decodable {
            struct Verse: Decodable {
                let book_name: String
                let chapter: Int
                let verse: Int
                let text: String
            }
            let verses: [Verse]
        }

        do {
            let json = try JSONDecoder().decode(BundledJSON.self, from: data)
            verses = json.verses.map { v in
                let trimmed = v.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return IndexedVerse(
                    bookName: v.book_name,
                    reference: "\(v.book_name) \(v.chapter):\(v.verse)",
                    text: trimmed,
                    lowerText: trimmed.lowercased()
                )
            }
        } catch {
            debugLog("WordLocatorService: Failed to decode kjvpce.json: \(error)")
            verses = []
        }
    }
}
