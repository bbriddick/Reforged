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
    /// Last time this chapter was read; the least recently read are evicted first (see `ESVStorageLimit`).
    var lastRead: Date? = nil

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
    var lastRead: Date? = nil
}

// MARK: - Storage limit

/// Crossway's terms limit how much ESV text may be stored on the device. Everything ESVService
/// keeps (cached chapters and cached verses combined) stays within `maxStoredVerses`; the least
/// recently read entries are dropped first.
enum ESVStorageLimit {
    static let maxStoredVerses = 500

    /// Verses covered by a reference like "John 3:16", "Psalm 19:7-11" or "Psalm 23" (counted as 1).
    static func verseCount(forReference reference: String) -> Int {
        guard let colon = reference.lastIndex(of: ":") else { return 1 }
        let tail = reference[reference.index(after: colon)...]
        let numbers = tail.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let first = numbers.first else { return 1 }
        guard numbers.count > 1, numbers[1] >= first else { return 1 }
        return numbers[1] - first + 1
    }
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
    private static let cacheFormatVersion = 3
    private static let cacheFormatVersionKey = "esv_cache_format_version"

    private init() {
        loadCacheFromDisk()
        enforceStorageLimit()
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
                // v3: chapters are requested with poetry indentation; older entries have flat lines.
                if storedVersion < 3 { cache = [:] }
                let singleChapterBooks: Set<String> = ["Obadiah", "Philemon", "2 John", "3 John", "Jude"]
                let before = cache.count
                cache = cache.filter { !singleChapterBooks.contains($0.value.book) }
                UserDefaults.standard.set(Self.cacheFormatVersion, forKey: Self.cacheFormatVersionKey)
                if cache.count < before {
                    debugLog("ESV cache: migrated to v\(Self.cacheFormatVersion), evicted \(before - cache.count) single-chapter book entries")
                }
            }

            // Evict any previously-poisoned entries that contain fewer than 2 verses.
            let cleaned = cache.filter { $0.value.verses.count >= 2 }
            chapterCache = cleaned
            let evicted = cache.count - cleaned.count
            if evicted > 0 {
                saveCacheToDisk()
                debugLog("ESV cache: evicted \(evicted) under-populated entries on load")
            }
            debugLog("Loaded \(cleaned.count) chapters from cache")
        }
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // Coalesces bursts of chapter caching (e.g. whole-Bible downloads) into a
    // single full-cache encode instead of re-serializing every chapter fetch.
    private var pendingCacheSave: DispatchWorkItem?
    private let cacheSaveDelay: TimeInterval = 2.0

    private func scheduleCacheSave() {
        pendingCacheSave?.cancel()
        let snapshot = chapterCache
        let key = cacheKey
        let work = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        pendingCacheSave = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + cacheSaveDelay, execute: work)
    }

    private func getCachedChapter(book: String, chapter: Int) -> ESVCachedChapter? {
        let key = cacheKeyFor(book: book, chapter: chapter)
        guard let cached = chapterCache[key] else { return nil }

        // Reject stale entries and entries with suspiciously few verses (cache poisoning guard)
        if !cached.isStale && cached.verses.count >= 2 {
            chapterCache[key]?.lastRead = Date()
            return cached
        }

        return nil
    }

    private func cacheChapter(_ chapter: ESVCachedChapter) {
        let key = cacheKeyFor(book: chapter.book, chapter: chapter.chapter)
        chapterCache[key] = chapter
        enforceStorageLimit()
        scheduleCacheSave()
    }

    // MARK: - Storage limit

    /// Evicts least recently read chapters/verses until the combined total is within the limit.
    private func enforceStorageLimit() {
        enum Kind { case chapter(String), verse(String) }
        var items: [(kind: Kind, last: Date, count: Int)] = []
        for (k, c) in chapterCache {
            items.append((.chapter(k), c.lastRead ?? c.cachedAt, c.verses.count))
        }
        let verseCache = loadedLocalVerseCache()
        for (k, v) in verseCache {
            items.append((.verse(k), v.lastRead ?? v.cachedAt, ESVStorageLimit.verseCount(forReference: k)))
        }
        var total = items.reduce(0) { $0 + $1.count }
        guard total > ESVStorageLimit.maxStoredVerses else { return }

        var chaptersChanged = false
        var versesChanged = false
        for item in items.sorted(by: { $0.last < $1.last }) {
            if total <= ESVStorageLimit.maxStoredVerses { break }
            switch item.kind {
            case .chapter(let k): chapterCache[k] = nil; chaptersChanged = true
            case .verse(let k): localVerseCache?[k] = nil; versesChanged = true
            }
            total -= item.count
        }
        if chaptersChanged { scheduleCacheSave() }
        if versesChanged, let cache = localVerseCache, let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: verseCacheKey)
        }
    }

    func clearCache() {
        pendingCacheSave?.cancel()
        pendingCacheSave = nil
        chapterCache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        localVerseCache = [:]
        UserDefaults.standard.removeObject(forKey: verseCacheKey)
        debugLog("ESV chapter and verse caches cleared.")
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
        enforceStorageLimit()
        pendingCacheSave?.cancel()
        pendingCacheSave = nil
        saveCacheToDisk()
        debugLog("ESV bundle injected (capped to \(ESVStorageLimit.maxStoredVerses) verses).")
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
            debugLog("Failed to precache verse \(reference): \(error)")
        }
    }

    // MARK: - Local Verse Cache (UserDefaults)

    // Loaded lazily once; every lookup previously decoded the entire dictionary
    // from UserDefaults.
    private var localVerseCache: [String: LocalCachedVerse]?

    private func loadedLocalVerseCache() -> [String: LocalCachedVerse] {
        if let cache = localVerseCache { return cache }
        var cache: [String: LocalCachedVerse] = [:]
        if let data = UserDefaults.standard.data(forKey: verseCacheKey),
           let decoded = try? JSONDecoder().decode([String: LocalCachedVerse].self, from: data) {
            cache = decoded
        }
        localVerseCache = cache
        return cache
    }

    private func getLocalCachedVerse(reference: String) -> (text: String, canonical: String)? {
        let key = reference.lowercased()
        guard let cached = loadedLocalVerseCache()[key] else { return nil }
        localVerseCache?[key]?.lastRead = Date()
        return (text: cached.text, canonical: cached.canonical)
    }

    private func cacheVerseLocally(reference: String, text: String, canonical: String) {
        var cache = loadedLocalVerseCache()
        cache[reference.lowercased()] = LocalCachedVerse(text: text, canonical: canonical, cachedAt: Date())
        localVerseCache = cache
        enforceStorageLimit()
        if let data = try? JSONEncoder().encode(localVerseCache ?? cache) {
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
            URLQueryItem(name: "indent-poetry", value: "true"),
            URLQueryItem(name: "indent-poetry-lines", value: "2"),
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

        // Poetry indentation makes ESV emit whitespace-only lines for stanza breaks; treat them as
        // empty. Only newlines are trimmed from the ends so the first marker keeps its indent.
        let originalText = text
            .replacingOccurrences(of: #"(?m)^[ \t]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .newlines)
        let pattern = #"\[(\d+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        let nsRange = NSRange(originalText.startIndex..., in: originalText)
        let matches = regex.matches(in: originalText, options: [], range: nsRange)

        if matches.isEmpty {
            return (parseVersesFallback(text, book: book, chapter: chapter), headings)
        }

        func leadingSpaces(_ s: Substring) -> Int { s.prefix(while: { $0 == " " }).count }
        func trailingNewlineCount(_ s: String) -> Int {
            var n = 0
            for ch in s.reversed() {
                if ch == "\n" { n += 1 } else if ch == " " || ch == "\t" { continue } else { break }
            }
            return n
        }

        for (index, match) in matches.enumerated() {
            guard let verseNumRange = Range(match.range(at: 1), in: originalText),
                  let verseNum = Int(originalText[verseNumRange]),
                  let matchRange = Range(match.range, in: originalText) else { continue }

            let textStart = matchRange.upperBound

            // --- Where the marker sits on its line (drives poetry indent + mid-line starts) ---
            let lineStart = originalText[..<matchRange.lowerBound].lastIndex(of: "\n")
                .map { originalText.index(after: $0) } ?? originalText.startIndex
            let beforeMarkerOnLine = originalText[lineStart..<matchRange.lowerBound]
            let markerAtLineStart = beforeMarkerOnLine.allSatisfy { $0 == " " || $0 == "\t" }
            let markerIndent = markerAtLineStart ? beforeMarkerOnLine.count : 0

            // --- Paragraph / stanza break: a blank line immediately before this verse ---
            var startsNewParagraph = index == 0
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let betweenRange = Range(NSRange(location: prevEnd, length: match.range.location - prevEnd), in: originalText) {
                    startsNewParagraph = trailingNewlineCount(String(originalText[betweenRange])) >= 2
                }
            }

            // --- Heading extraction: text between previous verse end and this verse marker ---
            var title: String? = nil
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let betweenRange = Range(NSRange(location: prevEnd, length: match.range.location - prevEnd), in: originalText) {
                    let between = String(originalText[betweenRange])
                    if let h = extractHeadingFromBetweenText(between, isFirstVerse: false) {
                        headings[verseNum] = h

                        // The previous verse's prose text runs up to this marker, so it
                        // swallowed the heading. Strip it. (Poetry verses stop at the first
                        // unindented line, so they never contain it.)
                        if !verses.isEmpty, verses[verses.count - 1].poetryLines == nil {
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
                                    sectionHeading: last.sectionHeading,
                                    title: last.title
                                )
                            }
                        }
                    }
                }
            } else {
                // Text before the first verse marker: a section heading (e.g. "Greeting" in
                // Philemon) and, after it, a psalm title ("A Psalm of David.") or acrostic
                // title ("Aleph").
                let before = String(originalText[originalText.startIndex..<matchRange.lowerBound])
                if let h = extractHeadingFromBetweenText(before, isFirstVerse: true) {
                    headings[verseNum] = h
                }
                let blocks = before
                    .components(separatedBy: "\n\n")
                    .map { $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ") }
                    .filter { !$0.isEmpty }
                if blocks.count >= 2 {
                    title = blocks.dropFirst().joined(separator: " ")
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

            let rawLines = String(originalText[textStart..<textEnd]).components(separatedBy: "\n")

            // --- Poetry: marker on an indented line, or indented continuation lines ---
            let hangingLines = rawLines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let isPoetry = (markerAtLineStart && markerIndent >= 2) || hangingLines.first.map { leadingSpaces(Substring($0)) >= 2 } == true

            var poetryLines: [PoetryLine]? = nil
            var verseText: String

            if isPoetry {
                var lines: [PoetryLine] = []
                if let first = rawLines.first {
                    let firstText = first.trimmingCharacters(in: .whitespaces)
                    if !firstText.isEmpty {
                        let extra = max(0, leadingSpaces(Substring(first)) - 1)
                        lines.append(PoetryLine(text: firstText, indent: markerAtLineStart ? max(0, (markerIndent + extra - 2) / 2) : 0))
                    }
                }
                for raw in rawLines.dropFirst() {
                    let trimmed = raw.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    let spaces = leadingSpaces(Substring(raw))
                    if spaces < 2 { break }   // unindented text after the poem (e.g. a heading)
                    lines.append(PoetryLine(text: trimmed, indent: max(0, (spaces - 2) / 2)))
                }
                poetryLines = lines.isEmpty ? nil : lines
                verseText = lines.map(\.text).joined(separator: " ")
            } else {
                verseText = rawLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                while verseText.contains("  ") {
                    verseText = verseText.replacingOccurrences(of: "  ", with: " ")
                }
                // Remove trailing heading text that leaked into the verse body
                verseText = stripTrailingHeading(from: verseText)
            }

            if !verseText.isEmpty {
                let reference = "\(book) \(chapter):\(verseNum)"
                verses.append(ParsedVerse(
                    id: reference,
                    number: verseNum,
                    text: verseText,
                    reference: reference,
                    startsNewParagraph: startsNewParagraph,
                    sectionHeading: headings[verseNum],
                    poetryLines: poetryLines,
                    continuesPreviousLine: index > 0 && !markerAtLineStart && poetryLines != nil,
                    title: title
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

        // Characters that end a sentence/clause — section headings never end with these.
        // Includes both straight and curly quote variants so block-quote lines (e.g.
        // `"They shall not enter my rest."`) are correctly rejected.
        let sentenceEnders: Set<Character> = [".", ",", ";", ":",
                                              "\"", "\u{201C}", "\u{201D}",  // straight + curly double quotes
                                              "'",  "\u{2018}", "\u{2019}"]  // straight + curly single quotes

        // Opening quote characters — a line that STARTS with one of these is a block
        // quote, not a section heading.
        let openingQuotes: Set<Character> = ["\"", "\u{201C}", "'", "\u{2018}"]

        if isFirstVerse {
            // Before the first verse, the heading appears at the top (e.g. "Greeting").
            // Scan forward; treat the very start as if preceded by a blank line.
            var prevWasEmpty = true
            for (i, line) in lines.enumerated() {
                if line.isEmpty { prevWasEmpty = true; continue }
                if prevWasEmpty,
                   line.count >= 3, line.count <= 80,
                   !(sentenceEnders.contains(line.last ?? " ")),
                   !(openingQuotes.contains(line.first ?? " ")),
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
                   !(openingQuotes.contains(line.first ?? " ")),
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

    /// Intentionally a no-op: ESV text may not be stored in bulk (see `ESVStorageLimit`), so books
    /// are never pre-cached. Chapters are fetched as they are read and only the most recent are kept.
    func precacheBook(_ bookName: String) async {}

    // Force refresh a chapter (ignores cache)
    func refreshChapter(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String, headings: [Int: String]) {
        // Remove from cache
        let key = cacheKeyFor(book: book, chapter: chapter)
        chapterCache.removeValue(forKey: key)
        scheduleCacheSave()

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
