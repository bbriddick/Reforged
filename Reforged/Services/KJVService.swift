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

    // Local cache for chapters — protected by cacheQueue
    private var chapterCache: [String: KJVCachedChapter] = [:]
    private let cacheKey = "kjv_chapter_cache"
    private let cacheQueue = DispatchQueue(label: "com.reforged.kjvcache")
    // Guard against concurrent/duplicate calls to loadBundledJSON
    private var bundleLoaded = false

    private init() {
        // Load chapter cache on a background thread so the main thread
        // (and thus the splash screen) is never blocked by JSON decoding.
        cacheQueue.async { self.loadCacheFromDisk() }
    }

    // MARK: - Cache Management

    private func cacheKeyFor(book: String, chapter: Int) -> String {
        return "\(book)_\(chapter)"
    }

    private func loadCacheFromDisk() {
        // Always called on cacheQueue
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode([String: KJVCachedChapter].self, from: data) {
            let cleaned = cache.filter { $0.value.verses.count >= 2 }
            chapterCache = cleaned
            let evicted = cache.count - cleaned.count
            if evicted > 0 {
                saveCacheToDisk()
                print("KJV cache: evicted \(evicted) under-populated entries on load")
            }
            print("Loaded \(cleaned.count) KJV chapters from cache")
        }
    }

    private func saveCacheToDisk() {
        // Always called on cacheQueue
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedChapter(book: String, chapter: Int) -> KJVCachedChapter? {
        cacheQueue.sync {
            let key = cacheKeyFor(book: book, chapter: chapter)
            guard let cached = chapterCache[key] else { return nil }
            if !cached.isStale && cached.verses.count >= 2 { return cached }
            return nil
        }
    }

    private func cacheChapter(_ chapter: KJVCachedChapter) {
        cacheQueue.async {
            let key = self.cacheKeyFor(book: chapter.book, chapter: chapter.chapter)
            self.chapterCache[key] = chapter
            self.saveCacheToDisk()
        }
    }

    func clearCache() {
        cacheQueue.async {
            self.chapterCache.removeAll()
            UserDefaults.standard.removeObject(forKey: self.cacheKey)
            print("KJV chapter cache cleared.")
        }
    }

    /// Bulk-import a pre-built bundle. Sets cachedAt to now so content stays fresh.
    func injectBundle(_ bundle: [String: KJVCachedChapter]) {
        cacheQueue.async {
            let now = Date()
            for (key, chapter) in bundle where self.chapterCache[key] == nil || (self.chapterCache[key]?.verses.count ?? 0) < 2 {
                self.chapterCache[key] = KJVCachedChapter(
                    book: chapter.book,
                    chapter: chapter.chapter,
                    passages: chapter.passages,
                    canonical: chapter.canonical,
                    cachedAt: now,
                    verses: chapter.verses
                )
            }
            self.saveCacheToDisk()
            print("KJV bundle injected: \(bundle.count) chapters.")
        }
    }

    var cachedChapterCount: Int { cacheQueue.sync { chapterCache.count } }

    // MARK: - Search

    func searchPassages(query: String, pageSize: Int = 50) async -> [BibleSearchResult] {
        // AppDelegate pre-loads the bundle on startup; skip the fallback call here
        // if loading is already in progress to avoid a concurrent-write race.
        if chapterCache.isEmpty && !bundleLoaded {
            loadBundledJSON()
        }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        var matches: [(result: BibleSearchResult, score: Int)] = []

        for chapter in chapterCache.values {
            for verse in chapter.verses {
                let searchableText = Self.stripSuppliedWordBrackets(verse.text)
                let lowered = searchableText.lowercased()
                guard lowered.contains(normalizedQuery) else { continue }

                var score = 1
                if lowered == normalizedQuery { score += 10 }
                if lowered.hasPrefix(normalizedQuery) { score += 4 }
                if lowered.range(of: "\\b\(NSRegularExpression.escapedPattern(for: normalizedQuery))\\b",
                                 options: .regularExpression) != nil {
                    score += 6
                }

                matches.append((
                    result: BibleSearchResult(
                        reference: verse.reference,
                        content: searchableText,
                        translation: .kjv
                    ),
                    score: score
                ))
            }
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.result.reference < rhs.result.reference
            }
            .prefix(pageSize)
            .map(\.result)
    }

    // MARK: - Bundled JSON Loading

    /// Parses `kjvpce.json` from the app bundle and fills missing/stale cache entries.
    /// Idempotent — returns immediately if already loaded. Safe to call from a background thread.
    func loadBundledJSON() {
        guard !bundleLoaded else { return }
        bundleLoaded = true
        guard let url = Bundle.main.url(forResource: "kjvpce", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("KJV: bundled JSON not found in app bundle")
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

        guard let json = try? JSONDecoder().decode(BundledJSON.self, from: data) else {
            print("KJV: failed to decode bundled JSON")
            return
        }

        var chapterMap: [String: [BundledJSON.Verse]] = [:]
        for v in json.verses {
            chapterMap["\(v.book_name)_\(v.chapter)", default: []].append(v)
        }

        let now = Date()
        var injected = 0
        for (key, verses) in chapterMap {
            if let existing = chapterCache[key], !existing.isStale, existing.verses.count >= 2 { continue }
            let sorted = verses.sorted { $0.verse < $1.verse }
            guard let first = sorted.first else { continue }
            let book = first.book_name
            let chapter = first.chapter
            let canonical = "\(book) \(chapter)"
            let cachedVerses = sorted.map { v in
                KJVCachedVerse(
                    number: v.verse,
                    text: v.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    reference: "\(book) \(chapter):\(v.verse)"
                )
            }
            chapterCache[key] = KJVCachedChapter(
                book: book,
                chapter: chapter,
                passages: sorted.map(\.text).joined(separator: " "),
                canonical: canonical,
                cachedAt: now,
                verses: cachedVerses
            )
            injected += 1
        }
        if injected > 0 {
            saveCacheToDisk()
            print("KJV: loaded \(injected) chapters from bundled JSON")
        } else {
            print("KJV: bundled JSON — all chapters already fresh in cache")
        }
    }

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

    // MARK: - KJV Text Parsing Helpers

    /// Extracts a ‹‹psalm title›› from the start of a KJV verse, returning (cleanText, title?).
    /// Used for Psalms that embed their heading in verse 1.
    static func extractTitleAndCleanText(from raw: String) -> (text: String, heading: String?) {
        // The PCE edition marks psalm titles with ‹‹ ... ›› at the very start of verse text.
        // U+2039 = ‹  U+203A = ›
        let open = "‹‹"
        let close = "›› "
        guard raw.hasPrefix(open),
              let closeRange = raw.range(of: close) else {
            return (raw, nil)
        }
        let headingStart = raw.index(raw.startIndex, offsetBy: open.count)
        let heading = String(raw[headingStart..<closeRange.lowerBound])
        let rest = String(raw[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (rest, heading)
    }

    /// Strips KJV supplied-word brackets [word] from text, returning clean display text.
    /// The brackets are preserved so italic rendering can be applied at display time;
    /// this variant removes them for plain-text contexts (search, memory, etc.).
    static func stripSuppliedWordBrackets(_ text: String) -> String {
        (try? NSRegularExpression(pattern: #"\[([^\]]+)\]"#))
            .map { $0.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1") }
            ?? text
    }

    // MARK: - Fetch Chapter Parsed

    func fetchChapterParsed(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String) {
        // Check local cache first
        if let cached = getCachedChapter(book: book, chapter: chapter) {
            let verses = cached.verses.map { cachedVerse -> ParsedVerse in
                let (cleanText, heading) = KJVService.extractTitleAndCleanText(from: cachedVerse.text)
                return ParsedVerse(
                    id: cachedVerse.reference,
                    number: cachedVerse.number,
                    text: cleanText,
                    reference: cachedVerse.reference,
                    startsNewParagraph: cachedVerse.number == 1,
                    sectionHeading: heading
                )
            }
            return (verses: verses, canonical: cached.canonical)
        }

        // Fetch from API
        let apiBook = apiBookName(for: book)

        // Single-chapter books (Obadiah, Philemon, 2 John, 3 John, Jude) must be
        // requested by book name only — appending "+1" causes bible-api.com to treat
        // "1" as a verse index rather than a chapter index, returning only verse 1.
        let singleChapterBooks: Set<String> = ["Obadiah", "Philemon", "2John", "3John", "Jude"]
        let isSingleChapter = singleChapterBooks.contains(apiBook)
        let reference = isSingleChapter
            ? "\(apiBook)?translation=kjv"
            : "\(apiBook)+\(chapter)?translation=kjv"

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
                let raw = kjvVerse.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                let (cleanText, heading) = KJVService.extractTitleAndCleanText(from: raw)
                let reference = "\(book) \(chapter):\(kjvVerse.verse)"
                verses.append(ParsedVerse(
                    id: reference,
                    number: kjvVerse.verse,
                    text: cleanText,
                    reference: reference,
                    startsNewParagraph: kjvVerse.verse == 1,
                    sectionHeading: heading
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

        var cleanText = decoded.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        // Strip supplied-word brackets for plain-text memory usage
        cleanText = KJVService.stripSuppliedWordBrackets(cleanText)
        let (displayText, _) = KJVService.extractTitleAndCleanText(from: cleanText)
        return (text: displayText, canonical: decoded.reference)
    }
}
