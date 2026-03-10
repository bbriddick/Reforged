import Foundation

// MARK: - KJV API Configuration
// Using the free Bible API at bible-api.com which provides KJV text

struct KJVConfig {
    static let baseURL = "https://bible-api.com/"
}

// MARK: - KJV API Response Models

struct KJVPassageResponse: Codable {
    let reference: String
    let verses: [KJVVerse]
    let text: String
    let translationId: String
    let translationName: String
    let translationNote: String

    enum CodingKeys: String, CodingKey {
        case reference, verses, text
        case translationId = "translation_id"
        case translationName = "translation_name"
        case translationNote = "translation_note"
    }
}

struct KJVVerse: Codable {
    let bookId: String
    let bookName: String
    let chapter: Int
    let verse: Int
    let text: String

    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case bookName = "book_name"
        case chapter, verse, text
    }
}

// MARK: - KJV Service Errors

enum KJVError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noPassageFound
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from KJV API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noPassageFound:
            return "No passage found for the given reference"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        }
    }
}

// MARK: - KJV Cache Model

struct KJVCachedChapter: Codable {
    let book: String
    let chapter: Int
    let passages: String
    let canonical: String
    let cachedAt: Date
    let verses: [KJVCachedVerse]

    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < thirtyDaysAgo
    }
}

struct KJVCachedVerse: Codable {
    let number: Int
    let text: String
    let reference: String
}

// MARK: - KJV Service

class KJVService {
    static let shared = KJVService()

    private let baseURL = KJVConfig.baseURL

    // Local cache for chapters
    private var chapterCache: [String: KJVCachedChapter] = [:]
    private let cacheKey = "kjv_chapter_cache"

    private init() {
        loadCacheFromDisk()
    }

    // MARK: - Cache Management

    private func cacheKeyFor(book: String, chapter: Int) -> String {
        return "\(book)_\(chapter)"
    }

    private func loadCacheFromDisk() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode([String: KJVCachedChapter].self, from: data) {
            chapterCache = cache
            print("Loaded \(cache.count) KJV chapters from cache")
        }
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedChapter(book: String, chapter: Int) -> KJVCachedChapter? {
        let key = cacheKeyFor(book: book, chapter: chapter)
        guard let cached = chapterCache[key] else { return nil }

        if !cached.isStale {
            return cached
        }
        return nil
    }

    private func cacheChapter(_ chapter: KJVCachedChapter) {
        let key = cacheKeyFor(book: chapter.book, chapter: chapter.chapter)
        chapterCache[key] = chapter
        saveCacheToDisk()
    }

    func clearCache() {
        chapterCache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("KJV chapter cache cleared.")
    }

    /// Bulk-import a pre-built bundle. Sets cachedAt to now so content stays fresh.
    func injectBundle(_ bundle: [String: KJVCachedChapter]) {
        let now = Date()
        for (key, chapter) in bundle where chapterCache[key] == nil {
            chapterCache[key] = KJVCachedChapter(
                book: chapter.book,
                chapter: chapter.chapter,
                passages: chapter.passages,
                canonical: chapter.canonical,
                cachedAt: now,
                verses: chapter.verses
            )
        }
        saveCacheToDisk()
        print("KJV bundle injected: \(bundle.count) chapters.")
    }

    var cachedChapterCount: Int { chapterCache.count }

    // MARK: - Book Name Conversion

    /// Convert our book names to bible-api.com format
    private func apiBookName(for book: String) -> String {
        // bible-api.com uses slightly different book names
        let mapping: [String: String] = [
            "1 Samuel": "1Samuel",
            "2 Samuel": "2Samuel",
            "1 Kings": "1Kings",
            "2 Kings": "2Kings",
            "1 Chronicles": "1Chronicles",
            "2 Chronicles": "2Chronicles",
            "Song of Solomon": "SongOfSolomon",
            "1 Corinthians": "1Corinthians",
            "2 Corinthians": "2Corinthians",
            "1 Thessalonians": "1Thessalonians",
            "2 Thessalonians": "2Thessalonians",
            "1 Timothy": "1Timothy",
            "2 Timothy": "2Timothy",
            "1 Peter": "1Peter",
            "2 Peter": "2Peter",
            "1 John": "1John",
            "2 John": "2John",
            "3 John": "3John"
        ]
        return mapping[book] ?? book
    }

    // MARK: - Fetch Chapter Parsed

    func fetchChapterParsed(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String) {
        // Check local cache first
        if let cached = getCachedChapter(book: book, chapter: chapter) {
            let verses = cached.verses.map { cachedVerse in
                ParsedVerse(
                    id: cachedVerse.reference,
                    number: cachedVerse.number,
                    text: cachedVerse.text,
                    reference: cachedVerse.reference,
                    startsNewParagraph: cachedVerse.number == 1
                )
            }
            return (verses: verses, canonical: cached.canonical)
        }

        // Fetch from API
        let apiBook = apiBookName(for: book)
        let reference = "\(apiBook)+\(chapter)?translation=kjv"

        guard let url = URL(string: baseURL + reference) else {
            throw KJVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, httpResponse) = try await performWithRetry(request)

        guard httpResponse.statusCode == 200 else {
            throw KJVError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(KJVPassageResponse.self, from: data)

            // Parse the response into verses
            var verses: [ParsedVerse] = []

            for kjvVerse in decoded.verses {
                let cleanText = kjvVerse.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")

                let reference = "\(book) \(chapter):\(kjvVerse.verse)"
                verses.append(ParsedVerse(
                    id: reference,
                    number: kjvVerse.verse,
                    text: cleanText,
                    reference: reference,
                    startsNewParagraph: kjvVerse.verse == 1
                ))
            }

            // Sort by verse number
            verses.sort { $0.number < $1.number }

            let canonical = "\(book) \(chapter)"

            // Cache the result
            let cachedVerses = verses.map { KJVCachedVerse(number: $0.number, text: $0.text, reference: $0.reference) }
            let cachedChapter = KJVCachedChapter(
                book: book,
                chapter: chapter,
                passages: decoded.text,
                canonical: canonical,
                cachedAt: Date(),
                verses: cachedVerses
            )
            cacheChapter(cachedChapter)

            return (verses: verses, canonical: canonical)
        } catch let decodingError as DecodingError {
            throw KJVError.decodingError(decodingError.localizedDescription)
        }
    }

    // MARK: - Fetch Verse for Memory

    func fetchVerseForMemory(reference: String) async throws -> (text: String, canonical: String) {
        // Parse the reference (e.g., "John 3:16" or "Genesis 1:1-3")
        let apiReference = reference
            .replacingOccurrences(of: " ", with: "+")

        guard let url = URL(string: baseURL + apiReference + "?translation=kjv") else {
            throw KJVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, httpResponse) = try await performWithRetry(request)

        guard httpResponse.statusCode == 200 else {
            throw KJVError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(KJVPassageResponse.self, from: data)

        let cleanText = decoded.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        return (text: cleanText, canonical: decoded.reference)
    }
}
