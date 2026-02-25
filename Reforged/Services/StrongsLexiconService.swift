import Foundation

// MARK: - Complete Study Bible API Config

private struct StudyBibleConfig {
    static let apiKey = "3c1bc86498mshb3150020425e7f9p19cf4bjsna6e2e86624dc"
    static let host = "complete-study-bible.p.rapidapi.com"
    static let baseURL = "https://complete-study-bible.p.rapidapi.com"
}

// MARK: - Strong's Lexicon Service

/// Provides Hebrew and Greek word study via the Complete Study Bible API.
/// Falls back to bundled Strong's dictionaries when offline or quota exceeded.
class StrongsLexiconService {
    static let shared = StrongsLexiconService()

    // Bundled offline dictionaries (fallback)
    private var hebrewDict: [String: StrongsEntry]?
    private var greekDict: [String: StrongsEntry]?

    // API caches
    private var verseInterlinearCache: [String: CachedVerseInterlinear] = [:]
    private var strongsDetailCache: [String: CachedStrongsDetail] = [:]

    private let verseCacheKey = "strongs_verse_interlinear_cache"
    private let detailCacheKey = "strongs_detail_cache"
    private let maxVerseCacheSize = 200
    private let maxDetailCacheSize = 500

    private init() {
        loadCachesFromDisk()
    }

    // MARK: - Main Lookup (API-first, fallback to bundled)

    /// Main entry point: looks up a tapped word with full interlinear data.
    func lookupWord(
        _ word: String,
        verseReference: String,
        bookName: String,
        chapter: Int,
        verseNumber: Int,
        isHebrew: Bool
    ) async -> WordLookupResult {
        // Step 1: Try API-based interlinear lookup
        if let apiResult = await lookupViaAPI(
            word: word,
            verseReference: verseReference,
            bookName: bookName,
            chapter: chapter,
            verseNumber: verseNumber,
            isHebrew: isHebrew
        ) {
            return apiResult
        }

        // Step 2: Fallback to bundled dictionary search
        return await lookupViaOfflineDictionary(
            word: word,
            verseReference: verseReference,
            isHebrew: isHebrew
        )
    }

    // MARK: - API-Based Lookup

    private func lookupViaAPI(
        word: String,
        verseReference: String,
        bookName: String,
        chapter: Int,
        verseNumber: Int,
        isHebrew: Bool
    ) async -> WordLookupResult? {
        // Get or fetch verse interlinear data
        guard let verseData = await getVerseInterlinear(
            bookName: bookName,
            chapter: chapter,
            verse: verseNumber
        ) else {
            return nil
        }

        // Find the tapped word in the interlinear data
        let loweredWord = word.lowercased()
        guard let matched = findWordInInterlinear(word: loweredWord, verseData: verseData) else {
            return nil
        }

        guard let strongsNum = matched.primaryStrongsNumber else { return nil }

        // Get Strong's detail
        let detail = await getStrongsDetail(number: strongsNum)

        if let detail = detail {
            let translationCounts = (detail.translation_counts ?? []).compactMap { tc -> (word: String, count: Int)? in
                guard let word = tc.trans_link ?? tc.trans,
                      let count = Int(tc.count) else { return nil }
                return (word: word, count: count)
            }

            return WordLookupResult(
                tappedWord: word,
                verseReference: verseReference,
                isHebrew: isHebrew,
                isFromAPI: true,
                originalWord: matched.originalWord,
                lexicalForm: detail.original_word,
                strongsNumber: detail.number,
                transliteration: detail.transliteration,
                pronunciation: detail.phonetics,
                strongsDefinition: detail.strong_definition.trimmingCharacters(in: .whitespacesAndNewlines),
                detailedDefinition: isHebrew
                    ? stripHTML(detail.bdb_definition)
                    : stripHTML(detail.thayers_definition),
                mounceDefinition: detail.mounce_definition.trimmingCharacters(in: .whitespacesAndNewlines),
                kjvUsage: detail.kjv_usage,
                derivation: stripHTML(detail.linked_derivation),
                occurrenceCount: detail.count,
                translationCounts: translationCounts,
                strongsEntries: []
            )
        }

        // Have interlinear match but no detail — use bundled dictionary for the Strong's number
        if let bundled = lookupBundledEntry(strongsNum) {
            return WordLookupResult(
                tappedWord: word,
                verseReference: verseReference,
                isHebrew: isHebrew,
                isFromAPI: true,
                originalWord: matched.originalWord,
                lexicalForm: bundled.lemma,
                strongsNumber: strongsNum,
                transliteration: bundled.transliteration,
                pronunciation: bundled.pronunciation,
                strongsDefinition: bundled.shortDefinition,
                detailedDefinition: bundled.definition,
                mounceDefinition: "",
                kjvUsage: bundled.usage,
                derivation: bundled.source,
                occurrenceCount: 0,
                translationCounts: [],
                strongsEntries: []
            )
        }

        return nil
    }

    // MARK: - Verse Interlinear Data

    /// Gets interlinear data for a verse, from cache or API.
    private func getVerseInterlinear(bookName: String, chapter: Int, verse: Int) async -> CachedVerseInterlinear? {
        let cacheKey = "\(bookName)_\(chapter)_\(verse)"

        // Check memory cache
        if let cached = verseInterlinearCache[cacheKey], !cached.isStale {
            return cached
        }

        // Fetch from API
        guard let apiBookName = BibleData.books.first(where: { $0.name == bookName })?.studyBibleAPIName else {
            return nil
        }

        async let kjvResponse = fetchKJVStrongs(book: apiBookName, chapter: chapter, verse: verse)
        async let origResponse = fetchORIG(book: apiBookName, chapter: chapter, verse: verse)

        guard let kjvData = await kjvResponse,
              let origData = await origResponse else {
            return nil
        }

        // Correlate KJV phrases with ORIG phrases via matching Strong's numbers
        let words = correlateInterlinear(kjv: kjvData, orig: origData, verse: verse)

        let cached = CachedVerseInterlinear(
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            words: words,
            cachedAt: Date()
        )

        // Save to cache
        verseInterlinearCache[cacheKey] = cached
        pruneAndSaveVerseCache()

        return cached
    }

    /// Pre-fetches interlinear data for an entire chapter (2 API calls instead of 2 per verse).
    func prefetchChapter(bookName: String, chapter: Int, totalVerses: Int) async {
        guard let apiBookName = BibleData.books.first(where: { $0.name == bookName })?.studyBibleAPIName else {
            return
        }

        // Check if we already have most verses cached
        let uncachedCount = (1...totalVerses).filter { verse in
            let key = "\(bookName)_\(chapter)_\(verse)"
            return verseInterlinearCache[key] == nil || verseInterlinearCache[key]!.isStale
        }.count

        // Only fetch if >50% of verses are uncached
        guard uncachedCount > totalVerses / 2 else { return }

        // Fetch full chapter KJV-Strongs and ORIG
        async let kjvChapter = fetchKJVStrongsChapter(book: apiBookName, chapter: chapter)
        async let origChapter = fetchORIGChapter(book: apiBookName, chapter: chapter)

        guard let kjvVerses = await kjvChapter,
              let origVerses = await origChapter else {
            return
        }

        // Build a lookup by verse number
        let origByVerse = Dictionary(grouping: origVerses, by: { $0.verse })

        for kjvVerse in kjvVerses {
            let verseNum = kjvVerse.verse
            let cacheKey = "\(bookName)_\(chapter)_\(verseNum)"

            // Skip if already cached and not stale
            if let existing = verseInterlinearCache[cacheKey], !existing.isStale {
                continue
            }

            let matchingOrig = origByVerse[verseNum]?.first
            if let origVerse = matchingOrig {
                let words = correlateInterlinear(kjv: kjvVerse, orig: origVerse, verse: verseNum)
                verseInterlinearCache[cacheKey] = CachedVerseInterlinear(
                    bookName: bookName,
                    chapter: chapter,
                    verse: verseNum,
                    words: words,
                    cachedAt: Date()
                )
            }
        }

        pruneAndSaveVerseCache()
    }

    // MARK: - API Fetch Methods

    private func fetchKJVStrongs(book: String, chapter: Int, verse: Int) async -> StudyBibleKJVResponse? {
        let url = "\(StudyBibleConfig.baseURL)/\(book)/\(chapter)/\(verse)/\(verse)/KJV-Strongs/"
        guard let results: [StudyBibleKJVResponse] = await fetchFromAPI(url: url) else { return nil }
        return results.first
    }

    private func fetchORIG(book: String, chapter: Int, verse: Int) async -> StudyBibleOrigResponse? {
        let url = "\(StudyBibleConfig.baseURL)/\(book)/\(chapter)/\(verse)/\(verse)/ORIG/"
        guard let results: [StudyBibleOrigResponse] = await fetchFromAPI(url: url) else { return nil }
        return results.first
    }

    private func fetchKJVStrongsChapter(book: String, chapter: Int) async -> [StudyBibleKJVResponse]? {
        let url = "\(StudyBibleConfig.baseURL)/\(book)/\(chapter)/KJV-Strongs/"
        return await fetchFromAPI(url: url)
    }

    private func fetchORIGChapter(book: String, chapter: Int) async -> [StudyBibleOrigResponse]? {
        let url = "\(StudyBibleConfig.baseURL)/\(book)/\(chapter)/ORIG/"
        return await fetchFromAPI(url: url)
    }

    /// Fetches Strong's detail for up to 3 numbers at once.
    func getStrongsDetail(number: String) async -> StudyBibleStrongsDetail? {
        // Check cache
        if let cached = strongsDetailCache[number], !cached.isStale {
            return cached.detail
        }

        let url = "\(StudyBibleConfig.baseURL)/strongs-detail/\(number)/"
        guard let results: [StudyBibleStrongsDetail] = await fetchFromAPI(url: url) else { return nil }
        guard let detail = results.first else { return nil }

        // Cache it
        strongsDetailCache[number] = CachedStrongsDetail(detail: detail, cachedAt: Date())
        pruneAndSaveDetailCache()

        return detail
    }

    private func fetchFromAPI<T: Codable>(url urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(StudyBibleConfig.apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(StudyBibleConfig.host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("StrongsLexiconService: API fetch failed for \(urlString): \(error)")
            return nil
        }
    }

    // MARK: - Interlinear Correlation

    /// Correlates KJV-Strongs phrases with ORIG phrases via shared Strong's numbers.
    private func correlateInterlinear(
        kjv: StudyBibleKJVResponse,
        orig: StudyBibleOrigResponse,
        verse: Int
    ) -> [InterlinearWordEntry] {
        // Build a lookup: Strong's number → original word
        var strongsToOrigWord: [String: String] = [:]
        for phrase in orig.orig_json {
            guard let nums = phrase.data_nums, !nums.isEmpty else { continue }
            let word = phrase.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            for num in nums {
                // First occurrence wins (preserves word order fidelity)
                if strongsToOrigWord[num] == nil {
                    strongsToOrigWord[num] = word
                }
            }
        }

        var results: [InterlinearWordEntry] = []
        for (index, phrase) in kjv.kjv_json.enumerated() {
            guard let nums = phrase.data_nums, !nums.isEmpty else { continue }

            // Find the original word for the first Strong's number
            let origWord = nums.compactMap { strongsToOrigWord[$0] }.first ?? ""

            results.append(InterlinearWordEntry(
                id: "v\(verse)_\(index)",
                englishPhrase: phrase.phrase,
                originalWord: origWord,
                strongsNumbers: nums
            ))
        }

        return results
    }

    /// Finds a tapped English word in the interlinear data.
    private func findWordInInterlinear(word: String, verseData: CachedVerseInterlinear) -> InterlinearWordEntry? {
        let lowered = word.lowercased()

        // First pass: exact word match within a phrase
        for entry in verseData.words {
            let phraseWords = entry.englishPhrase
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }

            if phraseWords.contains(lowered) {
                return entry
            }
        }

        // Second pass: substring match (for compound phrases like "only begotten")
        for entry in verseData.words {
            if entry.englishPhrase.lowercased().contains(lowered) {
                return entry
            }
        }

        return nil
    }

    // MARK: - Offline Dictionary Fallback

    private func lookupViaOfflineDictionary(
        word: String,
        verseReference: String,
        isHebrew: Bool
    ) async -> WordLookupResult {
        let offlineResults = searchByEnglishWord(word, isHebrew: isHebrew)

        return WordLookupResult(
            tappedWord: word,
            verseReference: verseReference,
            isHebrew: isHebrew,
            isFromAPI: false,
            originalWord: "",
            lexicalForm: "",
            strongsNumber: "",
            transliteration: "",
            pronunciation: "",
            strongsDefinition: "",
            detailedDefinition: "",
            mounceDefinition: "",
            kjvUsage: "",
            derivation: "",
            occurrenceCount: 0,
            translationCounts: [],
            strongsEntries: Array(offlineResults.prefix(5))
        )
    }

    // MARK: - Bundled Dictionary Loading (lazy)

    func ensureHebrewLoaded() {
        guard hebrewDict == nil else { return }
        hebrewDict = loadBundledDictionary(named: "StrongHebrewDictionary", prefix: "H")
    }

    func ensureGreekLoaded() {
        guard greekDict == nil else { return }
        greekDict = loadBundledDictionary(named: "StrongGreekDictionary", prefix: "G")
    }

    private func loadBundledDictionary(named name: String, prefix: String) -> [String: StrongsEntry] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("StrongsLexiconService: Could not find \(name).json in bundle")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode(RawStrongsDictionary.self, from: data)

            var result: [String: StrongsEntry] = [:]
            for (key, entry) in raw.dict {
                let parsed = parseEntry(key: key, raw: entry)
                result[key] = parsed
            }
            return result
        } catch {
            print("StrongsLexiconService: Failed to load \(name).json: \(error)")
            return [:]
        }
    }

    private func parseEntry(key: String, raw: RawStrongsEntry) -> StrongsEntry {
        let shortDef = extractBetweenTags(raw.meaning, tag: "def") ?? stripTags(raw.meaning)
        let fullDef = stripTags(raw.meaning)
        let usageText = stripTags(raw.usage)
        let sourceText = stripTags(raw.source)

        return StrongsEntry(
            number: key,
            lemma: raw.w.w,
            transliteration: raw.w.xlit,
            pronunciation: raw.w.pron,
            partOfSpeech: expandPartOfSpeech(raw.w.pos),
            definition: fullDef.isEmpty ? usageText : fullDef,
            shortDefinition: shortDef.isEmpty ? (fullDef.isEmpty ? usageText : fullDef) : shortDef,
            usage: usageText,
            source: sourceText
        )
    }

    /// Looks up a single entry from the bundled dictionaries by Strong's number.
    func lookupBundledEntry(_ number: String) -> StrongsEntry? {
        if number.hasPrefix("H") {
            ensureHebrewLoaded()
            return hebrewDict?[number]
        } else if number.hasPrefix("G") {
            ensureGreekLoaded()
            return greekDict?[number]
        }
        return nil
    }

    /// Searches the bundled dictionary for entries whose usage/definition contains the given English word.
    func searchByEnglishWord(_ word: String, isHebrew: Bool) -> [StrongsEntry] {
        let lowered = word.lowercased()

        if isHebrew {
            ensureHebrewLoaded()
        } else {
            ensureGreekLoaded()
        }

        let dict = isHebrew ? hebrewDict : greekDict
        guard let entries = dict else { return [] }

        var results: [(entry: StrongsEntry, score: Int)] = []

        for (_, entry) in entries {
            var score = 0
            let usageLower = entry.usage.lowercased()
            let defLower = entry.definition.lowercased()
            let shortDefLower = entry.shortDefinition.lowercased()

            if shortDefLower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: lowered))\\b",
                                    options: .regularExpression) != nil {
                score += 10
            }

            if usageLower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: lowered))\\b",
                                 options: .regularExpression) != nil {
                score += 5
            }

            if defLower.contains(lowered) { score += 3 }
            if usageLower.contains(lowered) { score += 2 }

            if score > 0 {
                results.append((entry: entry, score: score))
            }
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.entry }
    }

    // MARK: - Text Cleaning Helpers

    private func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ html: String) -> String {
        guard !html.isEmpty else { return "" }
        // Remove HTML tags and clean up entities
        var cleaned = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x200E;", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Truncate very long definitions to keep UI manageable
        if cleaned.count > 800 {
            let index = cleaned.index(cleaned.startIndex, offsetBy: 800)
            cleaned = String(cleaned[..<index]) + "…"
        }

        return cleaned
    }

    private func extractBetweenTags(_ text: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return stripTags(String(text[range])).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func expandPartOfSpeech(_ abbr: String) -> String {
        let parts = abbr.components(separatedBy: "-")
        let mapped = parts.map { part -> String in
            switch part {
            case "n": return "noun"
            case "v": return "verb"
            case "adj": return "adjective"
            case "adv": return "adverb"
            case "prep": return "preposition"
            case "conj": return "conjunction"
            case "pron": return "pronoun"
            case "interj": return "interjection"
            case "pr": return "proper"
            case "m": return "masculine"
            case "f": return "feminine"
            case "c": return "common"
            case "loc": return "location"
            case "gent": return "gentilic"
            default: return part
            }
        }
        return mapped.joined(separator: ", ")
    }

    // MARK: - Cache Persistence

    private func loadCachesFromDisk() {
        // Verse interlinear cache
        if let data = UserDefaults.standard.data(forKey: verseCacheKey),
           let decoded = try? JSONDecoder().decode([String: CachedVerseInterlinear].self, from: data) {
            verseInterlinearCache = decoded.filter { !$0.value.isStale }
        }

        // Strong's detail cache
        if let data = UserDefaults.standard.data(forKey: detailCacheKey),
           let decoded = try? JSONDecoder().decode([String: CachedStrongsDetail].self, from: data) {
            strongsDetailCache = decoded.filter { !$0.value.isStale }
        }
    }

    private func pruneAndSaveVerseCache() {
        if verseInterlinearCache.count > maxVerseCacheSize {
            let sorted = verseInterlinearCache.sorted { $0.value.cachedAt > $1.value.cachedAt }
            verseInterlinearCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(maxVerseCacheSize - 50)))
        }
        if let data = try? JSONEncoder().encode(verseInterlinearCache) {
            UserDefaults.standard.set(data, forKey: verseCacheKey)
        }
    }

    private func pruneAndSaveDetailCache() {
        if strongsDetailCache.count > maxDetailCacheSize {
            let sorted = strongsDetailCache.sorted { $0.value.cachedAt > $1.value.cachedAt }
            strongsDetailCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(maxDetailCacheSize - 50)))
        }
        if let data = try? JSONEncoder().encode(strongsDetailCache) {
            UserDefaults.standard.set(data, forKey: detailCacheKey)
        }
    }

    func clearCache() {
        verseInterlinearCache = [:]
        strongsDetailCache = [:]
        UserDefaults.standard.removeObject(forKey: verseCacheKey)
        UserDefaults.standard.removeObject(forKey: detailCacheKey)
    }
}
