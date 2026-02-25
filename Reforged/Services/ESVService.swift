import Foundation

// MARK: - ESV API Configuration

struct ESVConfig {
    static let baseURL = "https://api.esv.org/v3/passage/text/"
    static let audioURL = "https://api.esv.org/v3/passage/audio/"
    static let searchURL = "https://api.esv.org/v3/passage/search/"
    static let apiKey = "e966ccd42b0de2053ab75c913d3dd61586c098c2"
}

// MARK: - ESV API Response Models

struct ESVPassageResponse: Codable {
    let query: String
    let canonical: String
    let parsed: [[Int]]?
    let passageMetadata: [PassageMetadata]?
    let passages: [String]

    enum CodingKeys: String, CodingKey {
        case query, canonical, parsed
        case passageMetadata = "passage_meta"
        case passages
    }
}

struct PassageMetadata: Codable {
    let canonical: String
    let chapterStart: [Int]?
    let chapterEnd: [Int]?
    let prevVerse: Int?
    let nextVerse: Int?
    let prevChapter: [Int]?
    let nextChapter: [Int]?

    enum CodingKeys: String, CodingKey {
        case canonical
        case chapterStart = "chapter_start"
        case chapterEnd = "chapter_end"
        case prevVerse = "prev_verse"
        case nextVerse = "next_verse"
        case prevChapter = "prev_chapter"
        case nextChapter = "next_chapter"
    }
}

// MARK: - ESV Service Errors

enum ESVError: LocalizedError {
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
            return "Invalid response from ESV API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noPassageFound:
            return "No passage found for the given reference"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        }
    }
}

// MARK: - Chapter Cache Model

struct ESVCachedChapter: Codable {
    let book: String
    let chapter: Int
    let passages: String
    let canonical: String
    let cachedAt: Date
    let verses: [ESVCachedVerse]

    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < thirtyDaysAgo
    }
}

struct ESVCachedVerse: Codable {
    let number: Int
    let text: String
    let reference: String
}

// MARK: - Local Verse Cache Model

struct LocalCachedVerse: Codable {
    let text: String
    let canonical: String
    let cachedAt: Date
}

// MARK: - ESV Service

class ESVService {
    static let shared = ESVService()

    private let baseURL = ESVConfig.baseURL
    private let apiKey = ESVConfig.apiKey

    // Local cache for chapters
    private var chapterCache: [String: ESVCachedChapter] = [:]
    private let cacheKey = "esv_chapter_cache"
    private let verseCacheKey = "esv_verse_cache"
    private let cacheRefreshDays = 30

    private init() {
        loadCacheFromDisk()
    }

    // MARK: - Cache Management

    private func cacheKeyFor(book: String, chapter: Int) -> String {
        return "\(book)_\(chapter)"
    }

    private func loadCacheFromDisk() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode([String: ESVCachedChapter].self, from: data) {
            chapterCache = cache
            print("Loaded \(cache.count) chapters from cache")
        }
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedChapter(book: String, chapter: Int) -> ESVCachedChapter? {
        let key = cacheKeyFor(book: book, chapter: chapter)
        guard let cached = chapterCache[key] else { return nil }

        // Return cached if not stale
        if !cached.isStale {
            return cached
        }

        return nil // Stale cache, need to refresh
    }

    private func cacheChapter(_ chapter: ESVCachedChapter) {
        let key = cacheKeyFor(book: chapter.book, chapter: chapter.chapter)
        chapterCache[key] = chapter
        saveCacheToDisk()
    }

    func clearCache() {
        chapterCache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("ESV chapter cache cleared.")
    }

    // MARK: - Fetch Passage with Caching

    func fetchPassage(
        reference: String,
        includeVerseNumbers: Bool = true,
        includeFootnotes: Bool = false,
        includeHeadings: Bool = true,
        includeShortCopyright: Bool = false,
        useCache: Bool = true
    ) async throws -> (text: String, canonical: String) {

        // Check cache first (only for simple verse fetches without extra formatting)
        if useCache && !includeVerseNumbers && !includeFootnotes && !includeHeadings && !includeShortCopyright {
            // Check bundled data first
            if let cached = BundledDataService.shared.getCachedVerse(reference: reference) {
                return (text: cached.text, canonical: cached.canonical)
            }
            // Check local UserDefaults verse cache
            if let cached = getLocalCachedVerse(reference: reference) {
                return cached
            }
        }

        // Fetch from ESV API
        let result = try await fetchFromAPI(
            reference: reference,
            includeVerseNumbers: includeVerseNumbers,
            includeFootnotes: includeFootnotes,
            includeHeadings: includeHeadings,
            includeShortCopyright: includeShortCopyright
        )

        // Cache the result locally
        if useCache && !includeVerseNumbers && !includeFootnotes && !includeHeadings && !includeShortCopyright {
            cacheVerseLocally(reference: reference, text: result.text, canonical: result.canonical)
        }

        return result
    }

    private func fetchFromAPI(
        reference: String,
        includeVerseNumbers: Bool,
        includeFootnotes: Bool,
        includeHeadings: Bool,
        includeShortCopyright: Bool
    ) async throws -> (text: String, canonical: String) {

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "include-verse-numbers", value: includeVerseNumbers ? "true" : "false"),
            URLQueryItem(name: "include-footnotes", value: includeFootnotes ? "true" : "false"),
            URLQueryItem(name: "include-headings", value: includeHeadings ? "true" : "false"),
            URLQueryItem(name: "include-short-copyright", value: includeShortCopyright ? "true" : "false"),
            URLQueryItem(name: "include-passage-references", value: "false")
        ]

        guard let url = components?.url else {
            throw ESVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESVError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ESVError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(ESVPassageResponse.self, from: data)

            guard let passageText = decoded.passages.first, !passageText.isEmpty else {
                throw ESVError.noPassageFound
            }

            let cleanedText = passageText.trimmingCharacters(in: .whitespacesAndNewlines)
            return (text: cleanedText, canonical: decoded.canonical)
        } catch let decodingError as DecodingError {
            throw ESVError.decodingError(decodingError.localizedDescription)
        }
    }

    func fetchVerseForMemory(reference: String) async throws -> (text: String, canonical: String) {
        return try await fetchPassage(
            reference: reference,
            includeVerseNumbers: false,
            includeFootnotes: false,
            includeHeadings: false,
            includeShortCopyright: false,
            useCache: true
        )
    }

    func fetchChapter(book: String, chapter: Int) async throws -> (text: String, canonical: String) {
        let reference = "\(book) \(chapter)"
        return try await fetchPassage(
            reference: reference,
            includeVerseNumbers: true,
            includeFootnotes: false,
            includeHeadings: true,
            includeShortCopyright: true,
            useCache: false
        )
    }

    func precacheVerse(reference: String) async {
        // Check if already cached locally or in bundled data
        if BundledDataService.shared.getCachedVerse(reference: reference) != nil { return }
        if getLocalCachedVerse(reference: reference) != nil { return }

        do {
            let result = try await fetchFromAPI(
                reference: reference,
                includeVerseNumbers: false,
                includeFootnotes: false,
                includeHeadings: false,
                includeShortCopyright: false
            )

            cacheVerseLocally(reference: reference, text: result.text, canonical: result.canonical)
        } catch {
            print("Failed to precache verse \(reference): \(error)")
        }
    }

    // MARK: - Local Verse Cache (UserDefaults)

    private func getLocalCachedVerse(reference: String) -> (text: String, canonical: String)? {
        guard let data = UserDefaults.standard.data(forKey: verseCacheKey),
              let cache = try? JSONDecoder().decode([String: LocalCachedVerse].self, from: data),
              let cached = cache[reference.lowercased()] else {
            return nil
        }
        return (text: cached.text, canonical: cached.canonical)
    }

    private func cacheVerseLocally(reference: String, text: String, canonical: String) {
        var cache: [String: LocalCachedVerse] = [:]
        if let data = UserDefaults.standard.data(forKey: verseCacheKey),
           let existing = try? JSONDecoder().decode([String: LocalCachedVerse].self, from: data) {
            cache = existing
        }
        cache[reference.lowercased()] = LocalCachedVerse(text: text, canonical: canonical, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: verseCacheKey)
        }
    }

    // MARK: - Fetch Chapter Parsed (with Local Caching)

    func fetchChapterParsed(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String, headings: [Int: String]) {

        // Check local cache first
        if let cached = getCachedChapter(book: book, chapter: chapter) {
            // Re-parse from cached passage text to get paragraph information
            let (verses, headings) = parsePassageIntoVerses(cached.passages, book: book, chapter: chapter)
            return (verses: verses, canonical: cached.canonical, headings: headings)
        }

        // Fetch from API
        let reference = "\(book) \(chapter)"

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-first-verse-numbers", value: "true"),
            URLQueryItem(name: "indent-paragraphs", value: "0"),
            URLQueryItem(name: "indent-poetry", value: "false"),
            URLQueryItem(name: "indent-poetry-lines", value: "0"),
            URLQueryItem(name: "indent-declares", value: "0"),
            URLQueryItem(name: "indent-psalm-doxology", value: "0"),
            URLQueryItem(name: "line-length", value: "0") // No line wrapping
        ]

        guard let url = components?.url else {
            throw ESVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESVError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ESVError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ESVPassageResponse.self, from: data)

        guard let passageText = decoded.passages.first, !passageText.isEmpty else {
            throw ESVError.noPassageFound
        }

        // Parse the passage into individual verses
        let (verses, headings) = parsePassageIntoVerses(passageText, book: book, chapter: chapter)

        // Cache the result
        let cachedVerses = verses.map { ESVCachedVerse(number: $0.number, text: $0.text, reference: $0.reference) }
        let cachedChapter = ESVCachedChapter(
            book: book,
            chapter: chapter,
            passages: passageText,
            canonical: decoded.canonical,
            cachedAt: Date(),
            verses: cachedVerses
        )
        cacheChapter(cachedChapter)

        return (verses: verses, canonical: decoded.canonical, headings: headings)
    }

    // MARK: - Improved Verse Parsing

    private func parsePassageIntoVerses(_ text: String, book: String, chapter: Int) -> ([ParsedVerse], [Int: String]) {
        var verses: [ParsedVerse] = []
        let headings: [Int: String] = [:]

        // Keep original text to detect paragraph breaks (double newlines)
        let originalText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Primary parsing method: Use regex to find all [number] patterns
        // Pattern matches [1], [2], [13], etc.
        let pattern = #"\[(\d+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        let nsRange = NSRange(originalText.startIndex..., in: originalText)
        let matches = regex.matches(in: originalText, options: [], range: nsRange)

        if matches.isEmpty {
            // No verse numbers found, try fallback
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        // Extract verses based on positions
        for (index, match) in matches.enumerated() {
            guard let verseNumRange = Range(match.range(at: 1), in: originalText) else { continue }
            guard let verseNum = Int(originalText[verseNumRange]) else { continue }

            // Find the start of verse text (after the [number])
            guard let matchRange = Range(match.range, in: originalText) else { continue }
            let textStart = matchRange.upperBound

            // Check if this verse starts a new paragraph by looking for double newline before the verse number
            var startsNewParagraph = false
            if index == 0 {
                // First verse always starts a paragraph
                startsNewParagraph = true
            } else {
                // Look at text between previous verse end and this verse number
                let previousEnd = matches[index - 1].range.upperBound
                if let prevEndIndex = Range(NSRange(location: previousEnd, length: match.range.location - previousEnd), in: originalText) {
                    let textBetween = String(originalText[prevEndIndex])
                    // Check for paragraph break: double newline or newline followed by whitespace and newline
                    startsNewParagraph = textBetween.contains("\n\n") || textBetween.contains("\n    ") || textBetween.contains("\n\t")
                }
            }

            // Find the end of verse text (start of next verse number or end of string)
            let textEnd: String.Index
            if index + 1 < matches.count,
               let nextMatchRange = Range(matches[index + 1].range, in: originalText) {
                textEnd = nextMatchRange.lowerBound
            } else {
                textEnd = originalText.endIndex
            }

            // Extract the raw verse text preserving some structure
            let rawVerseText = String(originalText[textStart..<textEnd])

            // Clean up the verse text while preserving essential content
            var verseText = rawVerseText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            // Collapse multiple spaces into single space
            while verseText.contains("  ") {
                verseText = verseText.replacingOccurrences(of: "  ", with: " ")
            }

            // Remove any trailing section headers (all caps lines)
            verseText = removeTrailingSectionHeaders(from: verseText)

            if !verseText.isEmpty {
                let reference = "\(book) \(chapter):\(verseNum)"
                verses.append(ParsedVerse(
                    id: reference,
                    number: verseNum,
                    text: verseText,
                    reference: reference,
                    startsNewParagraph: startsNewParagraph
                ))
            }
        }

        // If we still didn't get verses, try fallback
        if verses.isEmpty {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        // Sort by verse number to ensure correct order
        verses.sort { $0.number < $1.number }

        return (verses, headings)
    }

    private func removeTrailingSectionHeaders(from text: String) -> String {
        // Remove trailing text that looks like a section header (all caps with only letters and spaces)
        var result = text

        // Pattern for section headers at the end: multiple capital letters/spaces
        let headerPattern = #"\s+[A-Z][A-Z\s]+$"#
        if let regex = try? NSRegularExpression(pattern: headerPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseVersesFallback(_ text: String, book: String, chapter: Int) -> [ParsedVerse] {
        var verses: [ParsedVerse] = []

        // More aggressive pattern: match [number] followed by any text until next [number] or end
        let pattern = #"\[(\d+)\]\s*([^\[]+)"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for (index, match) in matches.enumerated() {
                if match.numberOfRanges >= 3,
                   let numRange = Range(match.range(at: 1), in: text),
                   let textRange = Range(match.range(at: 2), in: text),
                   let verseNum = Int(text[numRange]) {

                    var verseText = String(text[textRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")

                    // Collapse multiple spaces
                    while verseText.contains("  ") {
                        verseText = verseText.replacingOccurrences(of: "  ", with: " ")
                    }

                    if !verseText.isEmpty {
                        let reference = "\(book) \(chapter):\(verseNum)"
                        // First verse starts a paragraph; for fallback, mark every verse as potential paragraph start
                        verses.append(ParsedVerse(
                            id: reference,
                            number: verseNum,
                            text: verseText,
                            reference: reference,
                            startsNewParagraph: index == 0
                        ))
                    }
                }
            }
        }

        // Sort by verse number
        verses.sort { $0.number < $1.number }

        return verses
    }

    // MARK: - Search

    func searchPassages(query: String, pageSize: Int = 10) async throws -> [ESVSearchResult] {
        var components = URLComponents(string: ESVConfig.searchURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page-size", value: String(pageSize))
        ]

        guard let url = components?.url else {
            throw ESVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESVError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ESVError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ESVSearchResponse.self, from: data)
        return decoded.results
    }

    // MARK: - Precache All Chapters (for offline use)

    func precacheBook(_ bookName: String) async {
        guard let book = BibleData.books.first(where: { $0.name == bookName }) else { return }

        for chapter in 1...book.chapters {
            // Skip if already cached and not stale
            if let cached = getCachedChapter(book: bookName, chapter: chapter), !cached.isStale {
                continue
            }

            do {
                _ = try await fetchChapterParsed(book: bookName, chapter: chapter)
                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            } catch {
                print("Failed to precache \(bookName) \(chapter): \(error)")
            }
        }
    }

    // Force refresh a chapter (ignores cache)
    func refreshChapter(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String, headings: [Int: String]) {
        // Remove from cache
        let key = cacheKeyFor(book: book, chapter: chapter)
        chapterCache.removeValue(forKey: key)
        saveCacheToDisk()

        // Fetch fresh
        return try await fetchChapterParsed(book: book, chapter: chapter)
    }
}

// MARK: - Search Response Models

struct ESVSearchResponse: Codable {
    let page: Int
    let totalResults: Int
    let results: [ESVSearchResult]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case results
        case totalPages = "total_pages"
    }
}

struct ESVSearchResult: Codable, Identifiable {
    let reference: String
    let content: String

    var id: String { reference }
}

// MARK: - Audio URL Builder

extension ESVService {
    func getAudioURL(book: String, chapter: Int) -> URL? {
        let reference = "\(book) \(chapter)"
        return getAudioURL(reference: reference)
    }

    func getAudioURL(reference: String) -> URL? {
        var components = URLComponents(string: ESVConfig.audioURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: reference)
        ]

        guard let url = components?.url else { return nil }

        var finalComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        finalComponents?.queryItems?.append(URLQueryItem(name: "api-key", value: apiKey))

        return finalComponents?.url
    }

    func fetchAudioInfo(reference: String) async throws -> ESVAudioInfo {
        var components = URLComponents(string: ESVConfig.audioURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: reference)
        ]

        guard let url = components?.url else {
            throw ESVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESVError.invalidResponse
        }

        let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length")
        let fileSize = Int(contentLength ?? "0") ?? 0

        return ESVAudioInfo(
            reference: reference,
            fileSize: fileSize,
            streamURL: getAudioURL(reference: reference)
        )
    }
}

// MARK: - Audio Info Model

struct ESVAudioInfo {
    let reference: String
    let fileSize: Int
    let streamURL: URL?

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
