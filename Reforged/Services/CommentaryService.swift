import Foundation

/// The commentaries available in the app. Scofield ships in the bundle; the four large
/// public-domain commentaries are optional downloads (see `CommentaryDownloadManager`).
enum CommentarySource: String, CaseIterable, Identifiable {
    case scofield
    case mhc
    case barnes
    case tdavid
    case calvin

    var id: String { rawValue }

    /// Bundled resource base name, or nil if this commentary is download-only.
    var bundledResource: String? {
        self == .scofield ? "Scofield" : nil
    }

    /// Remote/on-disk file name for downloadable commentaries.
    var remoteFile: String? {
        switch self {
        case .scofield: return nil
        case .mhc: return "MHC.json"
        case .barnes: return "Barnes.json"
        case .tdavid: return "TDavid.json"
        case .calvin: return "CalvinCommentaries.json"
        }
    }

    var isBundled: Bool { bundledResource != nil }

    var displayName: String {
        switch self {
        case .scofield: return "Scofield Reference Notes"
        case .mhc: return "Matthew Henry"
        case .barnes: return "Barnes' Notes"
        case .tdavid: return "Treasury of David"
        case .calvin: return "Calvin's Commentaries"
        }
    }

    /// One-line description for the Study Library catalog.
    var blurb: String {
        switch self {
        case .scofield: return "Concise dispensational study notes (built in)."
        case .mhc: return "The classic devotional whole-Bible commentary."
        case .barnes: return "Clear verse-by-verse notes, especially on the New Testament."
        case .tdavid: return "Spurgeon's rich exposition of the Psalms."
        case .calvin: return "The Reformer's careful exegetical commentary."
        }
    }

    /// Approximate download size, for the downloads UI.
    var approxBytes: Int64 {
        switch self {
        case .scofield: return 0
        case .mhc: return 39_150_777
        case .barnes: return 15_306_338
        case .tdavid: return 11_828_045
        case .calvin: return 38_624_682
        }
    }

    /// Treasury of David only covers the Psalms.
    var coversWholeBible: Bool { self != .tdavid }
}

/// A commentary entry resolved for a verse.
struct CommentaryEntry: Identifiable, Equatable {
    let source: CommentarySource
    let text: String
    var id: String { source.rawValue }
}

/// Verse-keyed commentary lookup across bundled + downloaded public-domain commentaries
/// (CrossWire SWORD modules, extracted offline). Mirrors `CrossReferenceService`: synchronous,
/// cached, empty-fallback. Scripture references inside the text are plain readable strings so
/// `LinkedScriptureText` re-links them at display time.
final class CommentaryService {
    static let shared = CommentaryService()

    /// "Book Chapter" -> verses (sorted ascending) -> text, per source.
    private var indexBySource: [CommentarySource: [String: [(verse: Int, text: String)]]] = [:]
    private var loadedSources: Set<CommentarySource> = []

    private init() {}

    /// Sources that have data available right now (bundled, or downloaded to disk).
    func availableSources() -> [CommentarySource] {
        CommentarySource.allCases.filter { source in
            ensureLoaded(source)
            return indexBySource[source] != nil
        }
    }

    /// Commentary entries for a verse, in enum order. Passage-level commentaries fall back to
    /// the nearest preceding keyed verse within the same chapter (the block that covers it).
    func entries(for reference: String) -> [CommentaryEntry] {
        guard let parsed = BibleData.parseReference(reference) else { return [] }
        let chapterKey = "\(parsed.book) \(parsed.chapter)"
        var results: [CommentaryEntry] = []
        for source in CommentarySource.allCases {
            ensureLoaded(source)
            guard let chapters = indexBySource[source],
                  let verses = chapters[chapterKey] else { continue }
            var best: String?
            for entry in verses {
                if entry.verse <= parsed.verseStart { best = entry.text } else { break }
            }
            if let best { results.append(CommentaryEntry(source: source, text: best)) }
        }
        return results
    }

    // MARK: - Browsing
    //
    // These let a reader page through a commentary directly (book → chapter → entries),
    // rather than only looking it up for the verse in hand.

    /// Books that this commentary has entries for, in canonical order.
    func books(for source: CommentarySource) -> [String] {
        ensureLoaded(source)
        guard let index = indexBySource[source] else { return [] }
        var present = Set<String>()
        for key in index.keys {
            if let book = Self.splitBookChapter(key)?.book { present.insert(book) }
        }
        return BibleData.books.map(\.name).filter { present.contains($0) }
    }

    /// Chapters (ascending) that have entries in a book.
    func chapters(for source: CommentarySource, book: String) -> [Int] {
        ensureLoaded(source)
        guard let index = indexBySource[source] else { return [] }
        return index.keys.compactMap { key -> Int? in
            guard let parts = Self.splitBookChapter(key), parts.book == book else { return nil }
            return parts.chapter
        }.sorted()
    }

    /// Entries for a specific chapter, ascending by verse.
    func chapterEntries(for source: CommentarySource, book: String, chapter: Int)
        -> [(verse: Int, reference: String, text: String)] {
        ensureLoaded(source)
        let key = "\(book) \(chapter)"
        return (indexBySource[source]?[key] ?? []).map {
            (verse: $0.verse, reference: "\(book) \(chapter):\($0.verse)", text: $0.text)
        }
    }

    /// SWORD modules use their own book names; map the ones that differ from `BibleData.books`
    /// so lookups and browsing line up. Applied when the index is built, so it fixes bundled and
    /// downloaded data alike without regenerating anything.
    private static let bookAliases: [String: String] = [
        "Revelation of John": "Revelation",
        "I Samuel": "1 Samuel", "II Samuel": "2 Samuel",
        "I Kings": "1 Kings", "II Kings": "2 Kings",
        "I Chronicles": "1 Chronicles", "II Chronicles": "2 Chronicles",
        "I Corinthians": "1 Corinthians", "II Corinthians": "2 Corinthians",
        "I Thessalonians": "1 Thessalonians", "II Thessalonians": "2 Thessalonians",
        "I Timothy": "1 Timothy", "II Timothy": "2 Timothy",
        "I Peter": "1 Peter", "II Peter": "2 Peter",
        "I John": "1 John", "II John": "2 John", "III John": "3 John",
    ]

    /// Splits an index key like "1 Samuel 3" into ("1 Samuel", 3).
    private static func splitBookChapter(_ key: String) -> (book: String, chapter: Int)? {
        guard let lastSpace = key.lastIndex(of: " "),
              let chapter = Int(key[key.index(after: lastSpace)...]) else { return nil }
        return (String(key[..<lastSpace]), chapter)
    }

    /// (Re)load a source from disk/bundle. Called after a download completes.
    func reload(_ source: CommentarySource) {
        loadedSources.remove(source)
        indexBySource[source] = nil
        ensureLoaded(source)
    }

    private func ensureLoaded(_ source: CommentarySource) {
        guard !loadedSources.contains(source) else { return }
        loadedSources.insert(source)

        let url: URL?
        if let resource = source.bundledResource {
            url = Bundle.main.url(forResource: resource, withExtension: "json")
        } else if let file = source.remoteFile {
            let candidate = CommentaryDownloadManager.directory().appendingPathComponent(file)
            url = FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        } else {
            url = nil
        }

        guard let url, let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        var index: [String: [(verse: Int, text: String)]] = [:]
        for (key, text) in raw {
            guard let parsed = BibleData.parseReference(key) else { continue }
            let book = Self.bookAliases[parsed.book] ?? parsed.book
            index["\(book) \(parsed.chapter)", default: []]
                .append((parsed.verseStart, text))
        }
        for key in index.keys {
            index[key]?.sort { $0.verse < $1.verse }
        }
        indexBySource[source] = index
    }
}
