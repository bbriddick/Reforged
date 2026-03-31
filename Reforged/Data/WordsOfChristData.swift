import Foundation

// MARK: - WOC Segment

/// One contiguous run of text within a verse, tagged red or non-red.
struct WOCSegment {
    let text: String
    let isRed: Bool
}

// MARK: - Words of Christ Data

/// Loads segment-level red-letter markup from the bundled JSON and provides
/// fast O(1) look-ups by verse reference (e.g. "Matthew 5:3").
///
/// The JSON has the format:
/// ```json
/// { "verses": { "Matthew 3:15": { "segments": [ {"text":"…","red":false}, … ] } } }
/// ```
final class WordsOfChristData {
    static let shared = WordsOfChristData()

    /// Maps verse reference → ordered array of WOC segments.
    private let segmentsByReference: [String: [WOCSegment]]

    private init() {
        segmentsByReference = WordsOfChristData.loadFromBundle()
    }

    // MARK: - Public API

    /// Returns the ordered segments for `reference`, or `nil` if the verse
    /// is not present in the WOC data at all.
    func segments(for reference: String) -> [WOCSegment]? {
        segmentsByReference[reference]
    }

    /// `true` when at least one segment of the verse is spoken by Christ.
    func isWordsOfChrist(reference: String) -> Bool {
        segmentsByReference[reference] != nil
    }

    // MARK: - JSON Loading

    private static func loadFromBundle() -> [String: [WOCSegment]] {
        guard
            let url = Bundle.main.url(forResource: "kjv_words_of_christ_red_markup",
                                      withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return [:]
        }

        // Nested decodable types — private and scoped to this function
        struct RawSegment: Decodable {
            let text: String
            let red: Bool
        }
        struct RawVerse: Decodable {
            let segments: [RawSegment]
        }
        struct Root: Decodable {
            let verses: [String: RawVerse]
        }

        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return [:]
        }

        var result = [String: [WOCSegment]]()
        result.reserveCapacity(root.verses.count)
        for (ref, entry) in root.verses {
            result[ref] = entry.segments.map { WOCSegment(text: $0.text, isRed: $0.red) }
        }
        return result
    }
}
