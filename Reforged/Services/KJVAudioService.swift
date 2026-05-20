import Foundation

// MARK: - KJV Audio Service
// Uses the free, no-auth bible.helloao.org API.
// Fetching a chapter also pre-caches the next chapter's MP3 URL so
// auto-advancing to the next chapter never needs an extra network round-trip.

class KJVAudioService {
    static let shared = KJVAudioService()
    private init() {}

    private let baseURL = "https://bible.helloao.org/api"

    // Pre-populated from each chapter response's `nextChapterAudioLinks`
    private var audioCache: [String: String] = [:]   // "Book:chapter" → mp3 URL string

    // MARK: - Book ID Map (USFM / helloao.org 3-letter IDs)

    private let bookIdMap: [String: String] = [
        // Old Testament
        "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV", "Numbers": "NUM",
        "Deuteronomy": "DEU", "Joshua": "JOS", "Judges": "JDG", "Ruth": "RUT",
        "1 Samuel": "1SA", "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
        "1 Chronicles": "1CH", "2 Chronicles": "2CH", "Ezra": "EZR", "Nehemiah": "NEH",
        "Esther": "EST", "Job": "JOB", "Psalms": "PSA", "Proverbs": "PRO",
        "Ecclesiastes": "ECC", "Song of Solomon": "SNG", "Isaiah": "ISA",
        "Jeremiah": "JER", "Lamentations": "LAM", "Ezekiel": "EZK", "Daniel": "DAN",
        "Hosea": "HOS", "Joel": "JOL", "Amos": "AMO", "Obadiah": "OBA",
        "Jonah": "JON", "Micah": "MIC", "Nahum": "NAM", "Habakkuk": "HAB",
        "Zephaniah": "ZEP", "Haggai": "HAG", "Zechariah": "ZEC", "Malachi": "MAL",
        // New Testament
        "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN",
        "Acts": "ACT", "Romans": "ROM", "1 Corinthians": "1CO", "2 Corinthians": "2CO",
        "Galatians": "GAL", "Ephesians": "EPH", "Philippians": "PHP", "Colossians": "COL",
        "1 Thessalonians": "1TH", "2 Thessalonians": "2TH", "1 Timothy": "1TI",
        "2 Timothy": "2TI", "Titus": "TIT", "Philemon": "PHM", "Hebrews": "HEB",
        "James": "JAS", "1 Peter": "1PE", "2 Peter": "2PE", "1 John": "1JN",
        "2 John": "2JN", "3 John": "3JN", "Jude": "JUD", "Revelation": "REV"
    ]

    // MARK: - Public API

    /// Returns the MP3 URL for the given book + chapter.
    /// If the previous chapter's response already pre-cached this URL, returns it immediately.
    /// Otherwise fetches the chapter JSON and caches the next chapter's URL as a side-effect.
    func getAudioURL(book: String, chapter: Int) async throws -> URL {
        let key = cacheKey(book: book, chapter: chapter)

        if let cached = audioCache[key], let url = URL(string: cached) {
            audioCache.removeValue(forKey: key)
            return url
        }

        return try await fetchAndCache(book: book, chapter: chapter)
    }

    // MARK: - Private

    private func fetchAndCache(book: String, chapter: Int) async throws -> URL {
        guard let bookId = bookIdMap[book] else {
            throw KJVAudioError.unknownBook(book)
        }

        let urlString = "\(baseURL)/KJV/\(bookId)/\(chapter).json"
        guard let requestURL = URL(string: urlString) else {
            throw KJVAudioError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: requestURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw KJVAudioError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoded = try JSONDecoder().decode(HelloAOChapterResponse.self, from: data)

        // Pre-cache next chapter's URL using the next chapter key derived from BibleData
        if let nextLinks = decoded.nextChapterAudioLinks,
           let mp3String = preferredURL(from: nextLinks),
           let next = nextChapterInfo(book: book, chapter: chapter) {
            audioCache[cacheKey(book: next.book, chapter: next.chapter)] = mp3String
        }

        guard let mp3String = preferredURL(from: decoded.thisChapterAudioLinks),
              let audioURL = URL(string: mp3String) else {
            throw KJVAudioError.noAudioFound
        }

        return audioURL
    }

    /// Picks the preferred reader URL. Prefers "gilbert", then "hays", then first available.
    private func preferredURL(from links: [String: String]?) -> String? {
        guard let links = links, !links.isEmpty else { return nil }
        return links["gilbert"] ?? links["hays"] ?? links.values.first
    }

    private func cacheKey(book: String, chapter: Int) -> String {
        "\(book):\(chapter)"
    }

    /// Mirrors BibleAudioPlayer's chapter-advance logic so we can key the pre-cache correctly.
    private func nextChapterInfo(book: String, chapter: Int) -> (book: String, chapter: Int)? {
        guard let bookData = BibleData.books.first(where: { $0.name == book }) else { return nil }
        if chapter < bookData.chapters { return (book, chapter + 1) }
        guard let idx = BibleData.books.firstIndex(where: { $0.name == book }),
              idx + 1 < BibleData.books.count else { return nil }
        return (BibleData.books[idx + 1].name, 1)
    }
}

// MARK: - Response Models

private struct HelloAOChapterResponse: Decodable {
    let thisChapterAudioLinks: [String: String]?
    let nextChapterAudioLinks: [String: String]?
}

// MARK: - Errors

enum KJVAudioError: LocalizedError {
    case unknownBook(String)
    case invalidURL
    case httpError(Int)
    case noAudioFound

    var errorDescription: String? {
        switch self {
        case .unknownBook(let b): return "Unknown book: \(b)"
        case .invalidURL:        return "Invalid audio URL"
        case .httpError(let c):  return "KJV audio API error \(c)"
        case .noAudioFound:      return "No audio available for this chapter"
        }
    }
}
