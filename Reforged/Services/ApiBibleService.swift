import Foundation

// MARK: - API.Bible Configuration

struct ApiBibleConfig {
    static let baseURL = "https://rest.api.bible/v1"
    static let apiKey = "UUTCGJADLTugGkW5aXiIt"

    // Bible IDs for each translation
    static let bibleIds: [BibleTranslation: String] = [
        .csb: "a556c5305ee15c3f-01",
        .nkjv: "63097d2a0a2f7db3-01",
        .nasb: "b8ee27bcd1cae43a-01",
        .rvr1960: "592420522e16049f-01"
    ]
}

// MARK: - API.Bible Response Models

struct ApiBibleChapterResponse: Codable {
    let data: ApiBibleChapterData
}

struct ApiBibleChapterData: Codable {
    let id: String
    let bibleId: String
    let bookId: String
    let number: String
    let content: String
    let reference: String
    let verseCount: Int
    let copyright: String
}

struct ApiBiblePassageResponse: Codable {
    let data: ApiBiblePassageData
}

struct ApiBiblePassageData: Codable {
    let id: String
    let bibleId: String
    let orgId: String?
    let content: String
    let reference: String
    let verseCount: Int
    let copyright: String
}

struct ApiBibleVersesListResponse: Codable {
    let data: [ApiBibleVerseSummary]
}

struct ApiBibleVerseSummary: Codable {
    let id: String
    let orgId: String
    let bibleId: String
    let bookId: String
    let chapterId: String
    let reference: String
}

struct ApiBibleVerseResponse: Codable {
    let data: ApiBibleVerseData
}

struct ApiBibleVerseData: Codable {
    let id: String
    let bibleId: String
    let bookId: String
    let chapterId: String
    let content: String
    let reference: String
    let copyright: String
}

struct ApiBibleSearchResponse: Codable {
    let data: ApiBibleSearchData
}

struct ApiBibleSearchData: Codable {
    let query: String
    let limit: Int
    let offset: Int
    let total: Int
    let verseCount: Int
    let verses: [ApiBibleSearchVerse]?
}

struct ApiBibleSearchVerse: Codable {
    let id: String
    let orgId: String?
    let bibleId: String
    let bookId: String
    let chapterId: String
    let text: String
    let reference: String
}

// MARK: - API.Bible Service Errors

enum ApiBibleError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noPassageFound
    case decodingError(String)
    case unsupportedTranslation

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from API.Bible"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noPassageFound:
            return "No passage found for the given reference"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .unsupportedTranslation:
            return "This translation is not supported via API.Bible"
        }
    }
}

// MARK: - Cache Model

struct ApiBibleCachedChapter: Codable {
    let book: String
    let chapter: Int
    let translationId: String
    let canonical: String
    let cachedAt: Date
    let verses: [ApiBibleCachedVerse]
    /// Raw API text stored so that headings and paragraph breaks can be
    /// re-derived on cache hits without a network round-trip.
    /// Empty string for entries cached before heading support was added.
    let content: String

    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < thirtyDaysAgo
    }

    // Explicit memberwise init (Codable synthesised init is overridden below)
    init(book: String, chapter: Int, translationId: String, canonical: String,
         cachedAt: Date, verses: [ApiBibleCachedVerse], content: String) {
        self.book = book; self.chapter = chapter; self.translationId = translationId
        self.canonical = canonical; self.cachedAt = cachedAt
        self.verses = verses; self.content = content
    }

    // Backward-compatible decoding: `content` did not exist in earlier cache entries.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        book         = try c.decode(String.self,                  forKey: .book)
        chapter      = try c.decode(Int.self,                     forKey: .chapter)
        translationId = try c.decode(String.self,                 forKey: .translationId)
        canonical    = try c.decode(String.self,                  forKey: .canonical)
        cachedAt     = try c.decode(Date.self,                    forKey: .cachedAt)
        verses       = try c.decode([ApiBibleCachedVerse].self,   forKey: .verses)
        content      = (try? c.decode(String.self,                forKey: .content)) ?? ""
    }
}

struct ApiBibleCachedVerse: Codable {
    let number: Int
    let text: String
    let reference: String
}

// MARK: - API.Bible Service

class ApiBibleService {
    static let shared = ApiBibleService()

    private let apiKey = ApiBibleConfig.apiKey

    // Local cache for chapters
    private var chapterCache: [String: ApiBibleCachedChapter] = [:]
    private let cacheKey = "apibible_chapter_cache"

    private init() {
        loadCacheFromDisk()
    }

    // MARK: - Book ID Mapping

    /// Maps standard book names to API.Bible 3-letter book IDs
    private static let bookIdMap: [String: String] = [
        "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV",
        "Numbers": "NUM", "Deuteronomy": "DEU", "Joshua": "JOS",
        "Judges": "JDG", "Ruth": "RUT", "1 Samuel": "1SA",
        "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
        "1 Chronicles": "1CH", "2 Chronicles": "2CH", "Ezra": "EZR",
        "Nehemiah": "NEH", "Esther": "EST", "Job": "JOB",
        "Psalms": "PSA", "Psalm": "PSA", "Proverbs": "PRO",
        "Ecclesiastes": "ECC", "Song of Solomon": "SNG",
        "Isaiah": "ISA", "Jeremiah": "JER", "Lamentations": "LAM",
        "Ezekiel": "EZK", "Daniel": "DAN", "Hosea": "HOS",
        "Joel": "JOL", "Amos": "AMO", "Obadiah": "OBA",
        "Jonah": "JON", "Micah": "MIC", "Nahum": "NAM",
        "Habakkuk": "HAB", "Zephaniah": "ZEP", "Haggai": "HAG",
        "Zechariah": "ZEC", "Malachi": "MAL",
        "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK",
        "John": "JHN", "Acts": "ACT", "Romans": "ROM",
        "1 Corinthians": "1CO", "2 Corinthians": "2CO",
        "Galatians": "GAL", "Ephesians": "EPH", "Philippians": "PHP",
        "Colossians": "COL", "1 Thessalonians": "1TH",
        "2 Thessalonians": "2TH", "1 Timothy": "1TI",
        "2 Timothy": "2TI", "Titus": "TIT", "Philemon": "PHM",
        "Hebrews": "HEB", "James": "JAS", "1 Peter": "1PE",
        "2 Peter": "2PE", "1 John": "1JN", "2 John": "2JN",
        "3 John": "3JN", "Jude": "JUD", "Revelation": "REV"
    ]

    private func bookId(for name: String) -> String? {
        return ApiBibleService.bookIdMap[name]
    }

    // MARK: - Cache Management

    private func cacheKeyFor(translation: String, book: String, chapter: Int) -> String {
        return "\(translation)_\(book)_\(chapter)"
    }

    private func loadCacheFromDisk() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode([String: ApiBibleCachedChapter].self, from: data) {
            // Evict any previously-poisoned entries that contain fewer than 2 verses.
            let cleaned = cache.filter { $0.value.verses.count >= 2 }
            chapterCache = cleaned
            let evicted = cache.count - cleaned.count
            if evicted > 0 {
                saveCacheToDisk()
                print("API.Bible cache: evicted \(evicted) under-populated entries on load")
            }
            print("Loaded \(cleaned.count) API.Bible chapters from cache")
        }
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedChapter(translation: String, book: String, chapter: Int) -> ApiBibleCachedChapter? {
        let key = cacheKeyFor(translation: translation, book: book, chapter: chapter)
        guard let cached = chapterCache[key] else { return nil }
        // Reject stale entries and entries with suspiciously few verses (cache poisoning guard)
        if !cached.isStale && cached.verses.count >= 2 { return cached }
        return nil
    }

    private func cacheChapter(_ chapter: ApiBibleCachedChapter, translation: String) {
        let key = cacheKeyFor(translation: translation, book: chapter.book, chapter: chapter.chapter)
        chapterCache[key] = chapter
        saveCacheToDisk()
    }

    func clearCache() {
        chapterCache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("API.Bible chapter cache cleared.")
    }

    func cachedChapterCount(for translation: BibleTranslation) -> Int {
        guard let bibleId = ApiBibleConfig.bibleIds[translation] else { return 0 }
        let prefix = "\(bibleId)_"
        return chapterCache.keys.filter { $0.hasPrefix(prefix) }.count
    }

    func clearCache(for translation: BibleTranslation) {
        guard let bibleId = ApiBibleConfig.bibleIds[translation] else { return }
        let prefix = "\(bibleId)_"
        chapterCache = chapterCache.filter { !$0.key.hasPrefix(prefix) }
        saveCacheToDisk()
        print("\(translation.rawValue) chapter cache cleared.")
    }

    /// Bulk-import a pre-built bundle. Sets cachedAt to now so content stays fresh.
    func injectBundle(_ bundle: [String: ApiBibleCachedChapter]) {
        let now = Date()
        for (key, chapter) in bundle where chapterCache[key] == nil || (chapterCache[key]?.verses.count ?? 0) < 2 {
            chapterCache[key] = ApiBibleCachedChapter(
                book: chapter.book,
                chapter: chapter.chapter,
                translationId: chapter.translationId,
                canonical: chapter.canonical,
                cachedAt: now,
                verses: chapter.verses,
                content: chapter.content
            )
        }
        saveCacheToDisk()
        print("API.Bible bundle injected: \(bundle.count) chapters.")
    }

    // MARK: - API Request Helper

    private func makeRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"

        let (data, httpResponse) = try await performWithRetry(request)

        guard httpResponse.statusCode == 200 else {
            throw ApiBibleError.httpError(httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Fetch Chapter Parsed

    func fetchChapterParsed(book: String, chapter: Int, translation: BibleTranslation) async throws -> (verses: [ParsedVerse], canonical: String) {
        guard let bibleId = ApiBibleConfig.bibleIds[translation] else {
            throw ApiBibleError.unsupportedTranslation
        }

        // Check local cache first
        if let cached = getCachedChapter(translation: bibleId, book: book, chapter: chapter) {
            // Re-parse from raw content when available so that paragraph breaks
            // and section headings are fully restored without a network request.
            if !cached.content.isEmpty {
                let verses = parseChapterContent(cached.content, book: book, chapter: chapter)
                return (verses: verses, canonical: cached.canonical)
            }
            // Fallback for pre-heading cache entries (content field is empty)
            let verses = cached.verses.map { cv in
                ParsedVerse(id: cv.reference, number: cv.number, text: cv.text,
                            reference: cv.reference, startsNewParagraph: cv.number == 1)
            }
            return (verses: verses, canonical: cached.canonical)
        }

        guard let bookCode = bookId(for: book) else { throw ApiBibleError.invalidURL }
        let chapterId = "\(bookCode).\(chapter)"

        // include-titles=true so section headings appear in the text for extraction
        let urlString = "\(ApiBibleConfig.baseURL)/bibles/\(bibleId)/chapters/\(chapterId)?content-type=text&include-verse-numbers=true&include-titles=true&include-chapter-numbers=false&include-verse-spans=false"

        guard let url = URL(string: urlString) else { throw ApiBibleError.invalidURL }

        let data = try await makeRequest(url: url)

        do {
            let decoded = try JSONDecoder().decode(ApiBibleChapterResponse.self, from: data)
            let content = decoded.data.content

            let verses = parseChapterContent(content, book: book, chapter: chapter)
            let canonical = "\(book) \(chapter)"

            // Store raw content alongside the parsed verse list so future cache
            // hits can re-derive headings and paragraph breaks without a network call.
            let cachedVerses = verses.map { ApiBibleCachedVerse(number: $0.number, text: $0.text, reference: $0.reference) }
            let cachedChapter = ApiBibleCachedChapter(
                book: book, chapter: chapter, translationId: bibleId,
                canonical: canonical, cachedAt: Date(),
                verses: cachedVerses, content: content
            )
            cacheChapter(cachedChapter, translation: bibleId)

            return (verses: verses, canonical: canonical)
        } catch let decodingError as DecodingError {
            throw ApiBibleError.decodingError(decodingError.localizedDescription)
        }
    }

    // MARK: - Fetch Verse for Memory

    func fetchVerseForMemory(reference: String, translation: BibleTranslation) async throws -> (text: String, canonical: String) {
        guard let bibleId = ApiBibleConfig.bibleIds[translation] else {
            throw ApiBibleError.unsupportedTranslation
        }

        // Convert reference like "John 3:16" or "Genesis 1:1-3" to API.Bible passage ID
        let passageId = convertReferenceToPassageId(reference)

        let urlString = "\(ApiBibleConfig.baseURL)/bibles/\(bibleId)/passages/\(passageId)?content-type=text&include-verse-numbers=false&include-titles=false&include-chapter-numbers=false&include-verse-spans=false"

        guard let url = URL(string: urlString) else {
            throw ApiBibleError.invalidURL
        }

        let data = try await makeRequest(url: url)

        let decoded = try JSONDecoder().decode(ApiBiblePassageResponse.self, from: data)

        let cleanText = decoded.data.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .cleanApiBibleContent()

        return (text: cleanText, canonical: decoded.data.reference)
    }

    // MARK: - Search

    func searchPassages(query: String, translation: BibleTranslation, pageSize: Int = 20) async throws -> [ApiBibleSearchVerse] {
        guard let bibleId = ApiBibleConfig.bibleIds[translation] else {
            throw ApiBibleError.unsupportedTranslation
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(ApiBibleConfig.baseURL)/bibles/\(bibleId)/search?query=\(encodedQuery)&limit=\(pageSize)"

        guard let url = URL(string: urlString) else {
            throw ApiBibleError.invalidURL
        }

        let data = try await makeRequest(url: url)
        let decoded = try JSONDecoder().decode(ApiBibleSearchResponse.self, from: data)
        return decoded.data.verses ?? []
    }

    // MARK: - Reference Conversion

    /// Converts "John 3:16" to "JHN.3.16" or "Genesis 1:1-3" to "GEN.1.1-GEN.1.3"
    private func convertReferenceToPassageId(_ reference: String) -> String {
        // Parse the reference into components
        // Examples: "John 3:16", "1 Corinthians 13:4-7", "Genesis 1:1-3", "Psalm 23"

        // Find the book name and the chapter:verse part
        var bookName = ""
        var chapterVerse = ""

        // Handle numbered books like "1 Corinthians 13:4-7"
        let parts = reference.components(separatedBy: " ")
        if parts.count >= 3, let firstChar = parts[0].first, firstChar.isNumber {
            // Numbered book: "1 Corinthians 13:4-7"
            bookName = "\(parts[0]) \(parts[1])"
            chapterVerse = parts.dropFirst(2).joined(separator: " ")
        } else if parts.count >= 2 {
            // Regular book: "John 3:16"
            bookName = parts[0]
            // Handle multi-word books like "Song of Solomon"
            // Find the last part that contains a digit (the chapter:verse)
            for i in stride(from: parts.count - 1, through: 0, by: -1) {
                if parts[i].contains(":") || parts[i].first?.isNumber == true {
                    chapterVerse = parts[i...].joined(separator: " ")
                    bookName = parts[0..<i].joined(separator: " ")
                    break
                }
            }
        }

        guard let bookCode = bookId(for: bookName) else {
            // Fallback: try the raw reference with URL encoding
            return reference.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? reference
        }

        // Parse chapter:verse
        if chapterVerse.contains(":") {
            let cv = chapterVerse.components(separatedBy: ":")
            let chapterNum = cv[0]
            let versePart = cv.count > 1 ? cv[1] : ""

            if versePart.contains("-") {
                // Range: "4-7" -> "GEN.1.4-GEN.1.7"
                let range = versePart.components(separatedBy: "-")
                if range.count == 2 {
                    return "\(bookCode).\(chapterNum).\(range[0])-\(bookCode).\(chapterNum).\(range[1])"
                }
            }

            return "\(bookCode).\(chapterNum).\(versePart)"
        } else {
            // Just chapter: "Psalm 23" -> "PSA.23"
            return "\(bookCode).\(chapterVerse)"
        }
    }

    // MARK: - Content Parsing

    /// Parses the raw API.Bible chapter text into individual verses, extracting
    /// section headings and paragraph-break flags along the way.
    private func parseChapterContent(_ content: String, book: String, chapter: Int) -> [ParsedVerse] {
        var verses: [ParsedVerse] = []
        var headings: [Int: String] = [:]

        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\[(\d+)\]"#

        func fallbackVerse() -> [ParsedVerse] {
            guard !text.isEmpty else { return [] }
            let ref = "\(book) \(chapter):1"
            return [ParsedVerse(id: ref, number: 1, text: text.cleanApiBibleContent(),
                                reference: ref, startsNewParagraph: true)]
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return fallbackVerse()
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        guard !matches.isEmpty else { return fallbackVerse() }

        for (index, match) in matches.enumerated() {
            guard let verseNumRange = Range(match.range(at: 1), in: text),
                  let verseNum = Int(text[verseNumRange]),
                  let matchRange = Range(match.range, in: text) else { continue }

            let textStart = matchRange.upperBound

            // ── Paragraph break detection ──────────────────────────────────────
            var startsNewParagraph = index == 0
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let br = Range(NSRange(location: prevEnd,
                                          length: match.range.location - prevEnd), in: text) {
                    let between = String(text[br])
                    startsNewParagraph = between.contains("\n\n")
                        || between.contains("\n    ")
                        || between.contains("\n\t")
                }
            }

            // ── Section heading extraction ─────────────────────────────────────
            if index > 0 {
                let prevEnd = matches[index - 1].range.upperBound
                if let br = Range(NSRange(location: prevEnd,
                                          length: match.range.location - prevEnd), in: text) {
                    let between = String(text[br])
                    if let h = extractSectionHeading(from: between, isFirstVerse: false) {
                        headings[verseNum] = h
                        // Retroactively strip the heading text from the previous verse body
                        if !verses.isEmpty {
                            let last = verses[verses.count - 1]
                            if let r = last.text.range(of: h, options: .caseInsensitive) {
                                let patched = String(last.text[..<r.lowerBound])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                verses[verses.count - 1] = ParsedVerse(
                                    id: last.id, number: last.number,
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
                let before = String(text[text.startIndex..<matchRange.lowerBound])
                if let h = extractSectionHeading(from: before, isFirstVerse: true) {
                    headings[verseNum] = h
                }
            }

            // ── Verse text ────────────────────────────────────────────────────
            let textEnd: String.Index
            if index + 1 < matches.count,
               let next = Range(matches[index + 1].range, in: text) {
                textEnd = next.lowerBound
            } else {
                textEnd = text.endIndex
            }

            var verseText = String(text[textStart..<textEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .cleanApiBibleContent()
            while verseText.contains("  ") {
                verseText = verseText.replacingOccurrences(of: "  ", with: " ")
            }

            if !verseText.isEmpty {
                let reference = "\(book) \(chapter):\(verseNum)"
                verses.append(ParsedVerse(
                    id: reference, number: verseNum,
                    text: verseText, reference: reference,
                    startsNewParagraph: startsNewParagraph,
                    sectionHeading: headings[verseNum]
                ))
            }
        }

        verses.sort { $0.number < $1.number }
        return verses
    }

    /// Extracts a section heading from the gap between two verse markers.
    ///
    /// API.Bible places headings as plain-text lines inside the chapter text.
    /// Uses the same backward-scan strategy as ESVService: the heading always
    /// sits at the END of the gap immediately before the next `[N]` marker.
    /// A sentence-terminator guard (`.`, `,`, `;`, `:`) prevents verse text
    /// that ends mid-clause from being mistaken for a heading.
    private func extractSectionHeading(from text: String, isFirstVerse: Bool) -> String? {
        guard text.contains("\n") else { return nil }

        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Characters that end a sentence/clause — section headings never end with these.
        // Includes both straight and curly quote variants so block-quote lines (e.g.
        // `"They shall not enter my rest."`) are correctly rejected.
        let sentenceEnders: Set<Character> = [".", ",", ";", ":",
                                              "\"", "\u{201C}", "\u{201D}",
                                              "'",  "\u{2018}", "\u{2019}"]

        // Opening quote characters — a line that STARTS with one of these is a block
        // quote, not a section heading.
        let openingQuotes: Set<Character> = ["\"", "\u{201C}", "'", "\u{2018}"]

        if isFirstVerse {
            var prevWasEmpty = true
            for (i, line) in lines.enumerated() {
                if line.isEmpty { prevWasEmpty = true; continue }
                if prevWasEmpty,
                   line.count >= 3, line.count <= 80,
                   !sentenceEnders.contains(line.last ?? " "),
                   !openingQuotes.contains(line.first ?? " "),
                   line.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
                    let next = i + 1
                    let followedByBlankOrEnd = next >= lines.count || lines[next].isEmpty
                    if followedByBlankOrEnd { return line }
                }
                prevWasEmpty = false
            }
        } else {
            guard text.contains("\n\n") else { return nil }
            var nextWasEmpty = true
            for i in stride(from: lines.count - 1, through: 0, by: -1) {
                let line = lines[i]
                if line.isEmpty { nextWasEmpty = true; continue }
                if nextWasEmpty,
                   line.count >= 3, line.count <= 80,
                   !sentenceEnders.contains(line.last ?? " "),
                   !openingQuotes.contains(line.first ?? " "),
                   line.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
                    let prev = i - 1
                    let precededByBlankOrStart = prev < 0 || lines[prev].isEmpty
                    if precededByBlankOrStart { return line }
                }
                nextWasEmpty = false
            }
        }
        return nil
    }
}

// MARK: - String Helper

private extension String {
    func cleanMultipleSpaces() -> String {
        var result = self
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }

    /// Clean API.Bible specific formatting artifacts from text content
    func cleanApiBibleContent() -> String {
        var result = self
        // Replace #— # patterns with em dash
        result = result.replacingOccurrences(of: "#— #", with: "—")
        result = result.replacingOccurrences(of: "#—#", with: "—")
        // Remove stray # markers
        result = result.replacingOccurrences(of: " # ", with: " ")
        result = result.replacingOccurrences(of: "#", with: "")
        // Remove leading commas that sometimes appear at line starts
        result = result.replacingOccurrences(of: "\n ,", with: "\n")
        result = result.replacingOccurrences(of: "\n,", with: "\n")
        // Clean leading comma after verse number bracket
        if result.hasPrefix(",") {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        // Clean up multiple spaces
        result = result.cleanMultipleSpaces()
        return result
    }
}
