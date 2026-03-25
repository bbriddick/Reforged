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

    // Increment when the query format for any book group changes so stale
    // entries are automatically evicted and re-fetched on next launch.
    private static let cacheFormatVersion = 2
    private static let cacheFormatVersionKey = "esv_cache_format_version"

    private init() {
        loadCacheFromDisk()
    }

    // MARK: - Cache Management

    private func cacheKeyFor(book: String, chapter: Int) -> String {
        return "\(book)_\(chapter)"
    }

    private func loadCacheFromDisk() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           var cache = try? JSONDecoder().decode([String: ESVCachedChapter].self, from: data) {

            // Version migration: single-chapter books (Obadiah, Philemon, 2 John, 3 John,
            // Jude) were previously fetched with just the book name, which made the ESV API
            // return paragraph-flow text. That caused verse content to be misread as section
            // headings. Evict those entries once so they are re-fetched with the correct
            // "Book 1:1-99" query that returns properly delimited chapter text.
            let storedVersion = UserDefaults.standard.integer(forKey: Self.cacheFormatVersionKey)
            if storedVersion < Self.cacheFormatVersion {
                let singleChapterBooks: Set<String> = ["Obadiah", "Philemon", "2 John", "3 John", "Jude"]
                let before = cache.count
                cache = cache.filter { !singleChapterBooks.contains($0.value.book) }
                UserDefaults.standard.set(Self.cacheFormatVersion, forKey: Self.cacheFormatVersionKey)
                if cache.count < before {
                    print("ESV cache: migrated to v\(Self.cacheFormatVersion), evicted \(before - cache.count) single-chapter book entries")
                }
            }

            // Evict any previously-poisoned entries that contain fewer than 2 verses.
            let cleaned = cache.filter { $0.value.verses.count >= 2 }
            chapterCache = cleaned
            let evicted = cache.count - cleaned.count
            if evicted > 0 {
                saveCacheToDisk()
                print("ESV cache: evicted \(evicted) under-populated entries on load")
            }
            print("Loaded \(cleaned.count) chapters from cache")
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

        // Reject stale entries and entries with suspiciously few verses (cache poisoning guard)
        if !cached.isStale && cached.verses.count >= 2 {
            return cached
        }

        return nil
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

    /// Bulk-import a pre-built bundle. Sets cachedAt to now so content stays fresh.
    func injectBundle(_ bundle: [String: ESVCachedChapter]) {
        let now = Date()
        for (key, chapter) in bundle where chapterCache[key] == nil || (chapterCache[key]?.verses.count ?? 0) < 2 {
            chapterCache[key] = ESVCachedChapter(
                book: chapter.book,
                chapter: chapter.chapter,
                passages: chapter.passages,
                canonical: chapter.canonical,
                cachedAt: now,
                verses: chapter.verses
            )
        }
        saveCacheToDisk()
        print("ESV bundle injected: \(bundle.count) chapters.")
    }

    var cachedChapterCount: Int { chapterCache.count }

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

        let (data, httpResponse) = try await performWithRetry(request)

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

    /// Returns the ESV API query string for a chapter.
    /// Single-chapter books (Obadiah, Philemon, 2 John, 3 John, Jude) need special
    /// handling:
    ///   - Requesting just "Philemon" returns paragraph-flow text where verse content
    ///     bleeds between [N] markers, causing the heading extractor to misread verse
    ///     text as section headings.
    ///   - Requesting "Philemon 1" makes the API treat "1" as verse 1, returning only
    ///     the first verse.
    ///   - Requesting "Philemon 1:1-99" is unambiguous: chapter 1, all verses up to 99.
    ///     The API caps the range at the last verse, returning the full chapter in
    ///     proper verse-numbered format (same structure as any other chapter request).
    private func esvReference(book: String, chapter: Int) -> String {
        let singleChapterBooks: Set<String> = ["Obadiah", "Philemon", "2 John", "3 John", "Jude"]
        return singleChapterBooks.contains(book) ? "\(book) 1:1-99" : "\(book) \(chapter)"
    }

    func fetchChapter(book: String, chapter: Int) async throws -> (text: String, canonical: String) {
        let reference = esvReference(book: book, chapter: chapter)
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
        // Single-chapter books must be requested by book name only — appending " 1"
        // causes the ESV API to treat "1" as a verse index, returning only verse 1.
        let reference = esvReference(book: book, chapter: chapter)

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-headings", value: "true"),
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

        let (data, httpResponse) = try await performWithRetry(request)

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
        var headings: [Int: String] = [:]

        let originalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\[(\d+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        let nsRange = NSRange(originalText.startIndex..., in: originalText)
        let matches = regex.matches(in: originalText, options: [], range: nsRange)

        if matches.isEmpty {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        for (index, match) in matches.enumerated() {
            guard let verseNumRange = Range(match.range(at: 1), in: originalText),
                  let verseNum = Int(originalText[verseNumRange]),
                  let matchRange = Range(match.range, in: originalText) else { continue }

            let textStart = matchRange.upperBound

            // --- Paragraph break detection ---
            var startsNewParagraph = index == 0
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let betweenRange = Range(NSRange(location: prevEnd, length: match.range.location - prevEnd), in: originalText) {
                    let between = String(originalText[betweenRange])
                    startsNewParagraph = between.contains("\n\n") || between.contains("\n    ") || between.contains("\n\t")
                }
            }

            // --- Heading extraction: text between previous verse end and this verse marker ---
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let betweenRange = Range(NSRange(location: prevEnd, length: match.range.location - prevEnd), in: originalText) {
                    let between = String(originalText[betweenRange])
                    if let h = extractHeadingFromBetweenText(between, isFirstVerse: false) {
                        headings[verseNum] = h

                        // The raw verse text for the previous verse runs from after its
                        // [N] marker all the way to the start of this [M] marker — the
                        // same span as `between`. That means the heading text was included
                        // in the previous verse's processed string. Strip it now.
                        if !verses.isEmpty {
                            let last = verses[verses.count - 1]
                            if let headingRange = last.text.range(of: h, options: [.caseInsensitive]) {
                                let patched = String(last.text[..<headingRange.lowerBound])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                verses[verses.count - 1] = ParsedVerse(
                                    id: last.id,
                                    number: last.number,
                                    text: patched.isEmpty ? last.text : patched,
                                    reference: last.reference,
                                    startsNewParagraph: last.startsNewParagraph,
                                    sectionHeading: last.sectionHeading
                                )
                            }
                        }
                    }
                }
            } else {
                // Text before the first verse marker may contain a chapter heading
                // (e.g. "Greeting" in Philemon or "Salutation" in 2 John).
                let before = String(originalText[originalText.startIndex..<matchRange.lowerBound])
                if let h = extractHeadingFromBetweenText(before, isFirstVerse: true) {
                    headings[verseNum] = h
                }
            }

            // --- Verse text end ---
            let textEnd: String.Index
            if index + 1 < matches.count,
               let nextMatchRange = Range(matches[index + 1].range, in: originalText) {
                textEnd = nextMatchRange.lowerBound
            } else {
                textEnd = originalText.endIndex
            }

            let rawVerseText = String(originalText[textStart..<textEnd])
            var verseText = rawVerseText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            while verseText.contains("  ") {
                verseText = verseText.replacingOccurrences(of: "  ", with: " ")
            }
            // Remove trailing heading text that leaked into the verse body
            verseText = stripTrailingHeading(from: verseText)

            if !verseText.isEmpty {
                let reference = "\(book) \(chapter):\(verseNum)"
                verses.append(ParsedVerse(
                    id: reference,
                    number: verseNum,
                    text: verseText,
                    reference: reference,
                    startsNewParagraph: startsNewParagraph,
                    sectionHeading: headings[verseNum]
                ))
            }
        }

        if verses.isEmpty {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        verses.sort { $0.number < $1.number }
        return (verses, headings)
    }

    /// Extracts a section heading from the gap text around a verse marker.
    ///
    /// - Parameter text: The raw text segment to inspect.
    /// - Parameter isFirstVerse: Pass `true` when `text` is the content *before*
    ///   the very first verse marker (e.g. "Greeting\n\n"). In that position the
    ///   first non-empty line is always a heading candidate.
    ///   Pass `false` for the gap *between* two consecutive verse markers. In that
    ///   position the heading always appears at the **end** of the gap (immediately
    ///   before the next verse marker). Some books (e.g. Titus 1:4) split a single
    ///   verse across multiple paragraph blocks separated by `\n\n`, so a forward
    ///   scan would incorrectly promote the continuation text to a heading. Scanning
    ///   backward from the end avoids this. An additional sentence-terminator guard
    ///   (`.`, `,`, `;`, `:`) rejects verse content that ends mid-sentence, since
    ///   genuine ESV section headings are short, un-punctuated noun phrases.
    private func extractHeadingFromBetweenText(_ text: String, isFirstVerse: Bool = false) -> String? {
        guard text.contains("\n") else { return nil }

        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Characters that end a sentence/clause but never a section heading
        let sentenceEnders: Set<Character> = [".", ",", ";", ":"]

        if isFirstVerse {
            // Before the first verse, the heading appears at the top (e.g. "Greeting").
            // Scan forward; treat the very start as if preceded by a blank line.
            var prevWasEmpty = true
            for (i, line) in lines.enumerated() {
                if line.isEmpty { prevWasEmpty = true; continue }
                if prevWasEmpty,
                   line.count >= 3, line.count <= 80,
                   !(sentenceEnders.contains(line.last ?? " ")),
                   line.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
                    let nextIndex = i + 1
                    let followedByBlankOrEnd = nextIndex >= lines.count
                        || lines[nextIndex].isEmpty
                    if followedByBlankOrEnd { return line }
                }
                prevWasEmpty = false
            }
        } else {
            // Between verses the heading appears at the END of the gap — just before
            // the opening `[N]` of the next verse. Only proceed if there is at least
            // one paragraph break; plain verse continuation never needs this path.
            guard text.contains("\n\n") else { return nil }

            // Scan backward: treat the text end as if followed by a blank line.
            var nextWasEmpty = true
            for i in stride(from: lines.count - 1, through: 0, by: -1) {
                let line = lines[i]
                if line.isEmpty { nextWasEmpty = true; continue }
                if nextWasEmpty,
                   line.count >= 3, line.count <= 80,
                   !(sentenceEnders.contains(line.last ?? " ")),
                   line.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
                    let prevIndex = i - 1
                    let precededByBlankOrStart = prevIndex < 0 || lines[prevIndex].isEmpty
                    if precededByBlankOrStart { return line }
                }
                nextWasEmpty = false
            }
        }
        return nil
    }

    /// Strips any trailing heading-like text from a verse body string.
    private func stripTrailingHeading(from text: String) -> String {
        var result = text
        // Trailing ALL-CAPS header: one or more words all uppercase separated by spaces
        let headerPattern = #"\s+[A-Z][A-Z\s']+$"#
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

        let (data, httpResponse) = try await performWithRetry(request)

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
