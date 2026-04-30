import Foundation

// MARK: - Gemini Error

enum GeminiError: LocalizedError {
    case missingAPIKey
    case aiDisabled
    case invalidResponse
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:   return "AI features are temporarily unavailable. Please try again later."
        case .aiDisabled:      return "AI features are disabled in Settings."
        case .invalidResponse: return "Invalid response from Gemini API."
        case .httpError(let code): return "Gemini API HTTP error: \(code)"
        case .decodingError(let msg): return "Failed to decode Gemini response: \(msg)"
        }
    }
}

// MARK: - Smart Search Result

struct SmartSearchVerse: Identifiable {
    var id: String { reference }
    let reference: String
    let text: String
    let testament: String  // "OT" or "NT"
}

struct SmartSearchResult {
    let summary: String
    let explanation: String
    let wordUsage: String
    let verses: [SmartSearchVerse]
    let strongsNumbers: [String]
    let relatedTerms: [String]
}

struct DailyInsightReflection {
    let reflection: String
    let prayerPrompt: String
}

// MARK: - Gemini Response Models (private)

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Gemini Service

final class GeminiService {
    static let shared = GeminiService()
    private init() {}

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    // In-memory caches (keyed by Strong's number / verse reference)
    private var wordStudyCache: [String: String] = [:]
    private var journalPromptCache: [String: [String]] = [:]

    // MARK: - Core Request

    private func generate(prompt: String, maxTokens: Int = 400) async throws -> String {
        let apiKey = await SettingsManager.shared.effectiveAPIKey

        if !apiKey.isEmpty {
            return try await generateDirect(prompt: prompt, maxTokens: maxTokens, apiKey: apiKey)
        }

        let hasManagedService = await SettingsManager.shared.hasManagedGeminiService
        if hasManagedService {
            let functionURL = await SettingsManager.shared.managedGeminiFunctionURL
            let anonKey = await SettingsManager.shared.supabaseAnonKey
            return try await generateViaManagedService(
                prompt: prompt,
                maxTokens: maxTokens,
                functionURL: functionURL,
                anonKey: anonKey
            )
        }

        throw GeminiError.missingAPIKey
    }

    private func generateDirect(prompt: String, maxTokens: Int, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "maxOutputTokens": maxTokens,
                "temperature": 0.7,
                // Disable thinking mode — thinking tokens consume maxOutputTokens
                // leaving almost no budget for actual output on gemini-2.5-flash
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            print("[Gemini] ❌ Non-HTTP response")
            throw GeminiError.invalidResponse
        }

        print("[Gemini] HTTP \(http.statusCode)")

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[Gemini] ❌ Error body: \(body)")
            throw GeminiError.httpError(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let text = decoded.candidates.first?.content.parts.first?.text else {
                print("[Gemini] ❌ No text in candidates")
                throw GeminiError.invalidResponse
            }
            print("[Gemini] ✅ Response received (\(text.count) chars)")
            return text
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[Gemini] ❌ Decode error: \(error). Raw: \(body.prefix(300))")
            throw GeminiError.decodingError(error.localizedDescription)
        }
    }

    private func generateViaManagedService(
        prompt: String,
        maxTokens: Int,
        functionURL: URL?,
        anonKey: String
    ) async throws -> String {
        guard let functionURL else { throw GeminiError.invalidResponse }

        // Use the signed-in user's JWT when available — unlocks the 4× higher
        // rate limit on the edge function and links requests to the user's account.
        // Fall back to the anon key for unauthenticated sessions.
        let bearerToken: String
        if let userJWT = await SupabaseAuthService.shared.validAccessToken() {
            bearerToken = userJWT
        } else {
            bearerToken = anonKey
        }

        let body: [String: Any] = [
            "operation": "generate",
            "prompt": prompt,
            "maxTokens": maxTokens
        ]

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey,              forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ios",                forHTTPHeaderField: "x-client-platform")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        print("[GeminiProxy] HTTP \(http.statusCode) — auth: \(bearerToken == anonKey ? "anon" : "user")")

        guard http.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[GeminiProxy] ❌ Error body: \(errorBody)")
            throw GeminiError.httpError(http.statusCode)
        }

        struct ProxyResponse: Decodable {
            let text: String
            let cached: Bool?
        }

        do {
            let decoded = try JSONDecoder().decode(ProxyResponse.self, from: data)
            print("[GeminiProxy] ✅ Response received (\(decoded.text.count) chars, cached: \(decoded.cached ?? false))")
            return decoded.text
        } catch {
            throw GeminiError.decodingError("Failed to decode Supabase Gemini proxy response")
        }
    }

    // MARK: - AI Enabled Guard

    private func checkEnabled() async throws {
        let enabled = await SettingsManager.shared.aiEnabled
        guard enabled else { throw GeminiError.aiDisabled }
    }

    // MARK: - Feature 1: Word Study Summary

    func generateWordStudySummary(_ result: WordLookupResult) async throws -> String {
        try await checkEnabled()

        let cacheKey = result.strongsNumber.isEmpty ? result.lexicalForm : result.strongsNumber
        if let cached = wordStudyCache[cacheKey] { return cached }

        // Build a rich context string from actual API data so the summary cites
        // real lexical data rather than producing a generic AI definition.
        let translationSummary: String = {
            let top = result.translationCounts.prefix(5)
            guard !top.isEmpty else { return result.kjvUsage }
            return top.map { "\"\($0.word)\" (\($0.count)x)" }.joined(separator: ", ")
        }()

        let prompt = """
        You are a biblical word study assistant. Synthesize the following lexical data \
        for the \(result.isHebrew ? "Hebrew" : "Greek") word \(result.strongsNumber) \
        into 2-3 concise, insightful sentences. Do not use markdown formatting. \
        Draw your summary directly from the data provided — do not add generic information.

        Word: \(result.lexicalForm) (\(result.transliteration)) — appears as "\(result.tappedWord)" in \(result.verseReference)
        Strong's definition: \(result.strongsDefinition)
        \(result.detailedDefinition.isEmpty ? "" : "Detailed definition: \(result.detailedDefinition.prefix(400))\n")\
        \(result.mounceDefinition.isEmpty ? "" : "Mounce: \(result.mounceDefinition.prefix(200))\n")\
        \(result.derivation.isEmpty ? "" : "Derivation: \(result.derivation)\n")\
        KJV translations: \(translationSummary)
        Occurrences in Scripture: \(result.occurrenceCount)

        Write a 2-3 sentence summary covering: the core meaning from the definitions above, \
        how it is actually translated across Scripture, and one theological insight grounded in the data.
        """

        let summary = try await generate(prompt: prompt, maxTokens: 500)
        wordStudyCache[cacheKey] = summary
        return summary
    }

    // MARK: - Feature 2: Journal Prompts

    func generateJournalPrompts(reference: String, verseText: String) async throws -> [String] {
        try await checkEnabled()

        if let cached = journalPromptCache[reference] { return cached }

        let prompt = """
        Generate exactly 6 reflective journal prompts for a Christian reader studying \(reference): "\(verseText)". \
        Each prompt must be under 90 characters. \
        Cover distinct angles: observation, personal application, prayer, character of God, challenge to act, and surrender. \
        Return only a valid JSON array of 6 strings with no markdown or extra text. Example: ["Prompt 1","Prompt 2","Prompt 3","Prompt 4","Prompt 5","Prompt 6"]
        """

        let raw = try await generate(prompt: prompt, maxTokens: 300)
        let prompts = parseJSONStringArray(from: raw)
        guard prompts.count >= 3 else { throw GeminiError.decodingError("Not enough prompts returned") }

        journalPromptCache[reference] = prompts
        return prompts
    }

    // MARK: - Feature 3: Smart Search

    func smartBibleSearch(query: String) async throws -> SmartSearchResult {
        try await checkEnabled()

        let prompt = """
        You are a biblical study assistant. Output ONLY a JSON object with no markdown, no code fences, \
        and no text before or after the JSON. Use these exact keys for the topic "\(query)":
        summary — one sentence overview (string)
        explanation — 2 to 3 sentences of theological context (string)
        word_usage — how key Hebrew or Greek words are used (string)
        strongs — array of up to 5 Strong's numbers such as G4335 or H8605 (array of strings)
        terms — array of up to 4 English KJV search keywords (array of strings)
        refs — array of up to 8 Bible verse references such as Matthew 6:9 (array of strings)
        """

        let raw = try await generate(prompt: prompt, maxTokens: 2048)
        print("[SmartSearch] Raw Gemini response: \(raw.prefix(600))")
        let partial = parseSmartSearchResult(from: raw, query: query)

        // Resolve verse references to real KJV texts from the bundle
        let resolvedVerses = await resolveVerseReferences(partial.verses.map { $0.reference })

        return SmartSearchResult(
            summary: partial.summary,
            explanation: partial.explanation,
            wordUsage: partial.wordUsage,
            verses: resolvedVerses.isEmpty ? partial.verses : resolvedVerses,
            strongsNumbers: partial.strongsNumbers,
            relatedTerms: partial.relatedTerms
        )
    }

    // MARK: - Feature 4: Daily Reading Notification

    /// Generates a short, personalized push notification for a daily Bible reading reminder.
    /// Returns a (title, body) pair ready to pass to UNMutableNotificationContent.
    func generateDailyReadingNotification(
        planName: String?,
        todaysReading: String?
    ) async throws -> (title: String, body: String) {
        try await checkEnabled()

        let planContext: String
        if let plan = planName, let reading = todaysReading {
            planContext = "The user is following the \"\(plan)\" reading plan. Today's reading is \(reading)."
        } else if let reading = todaysReading {
            planContext = "Today's Bible reading is \(reading)."
        } else {
            planContext = "The user has no active reading plan."
        }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let prompt = """
        You are writing a short, encouraging iOS push notification to remind a Christian to read their Bible today.
        \(planContext)
        Day of year: \(dayOfYear) (use this to vary the message — each day should feel fresh).

        Return ONLY a JSON object with exactly two keys:
        title — 3 to 6 words, punchy and warm (string)
        body — one sentence of 8 to 15 words that motivates opening the Bible (string)

        Rules:
        - Sound human and warm, not robotic or generic
        - Ground it in Scripture or the specific reading if one is given
        - No hashtags, no emojis, no markdown
        - Do not start body with "It's time" or "Don't forget"
        """

        let raw = try await generate(prompt: prompt, maxTokens: 120)
        return try parseNotificationContent(from: raw)
    }

    private func parseNotificationContent(from raw: String) throws -> (title: String, body: String) {
        struct Payload: Decodable {
            let title: String
            let body: String
        }
        var cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = cleaned.firstIndex(of: "{") { cleaned = String(cleaned[s...]) }
        if let e = cleaned.lastIndex(of: "}") { cleaned = String(cleaned[...e]) }
        guard let data = cleaned.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw GeminiError.decodingError("Could not parse notification content JSON")
        }
        return (decoded.title, decoded.body)
    }

    // MARK: - Feature 5: Daily Insight Reflection

    func generateDailyInsightReflection(topic: String, reference: String, verseText: String) async throws -> DailyInsightReflection {
        try await checkEnabled()

        let prompt = """
        You are writing a brief daily Scripture insight for a Christian believer.
        Return ONLY a valid JSON object with these exact keys:
        reflection — a warm, biblically grounded reflection in 2 concise sentences
        prayer_prompt — one sentence prayer prompt under 120 characters

        Topic: \(topic)
        Scripture: \(reference)
        Verse text: "\(verseText)"

        Keep the tone devotional, practical, and faithful to the verse itself.
        Do not use markdown. Do not include any keys other than reflection and prayer_prompt.
        """

        let raw = try await generate(prompt: prompt, maxTokens: 220)
        return try parseDailyInsightReflection(from: raw)
    }

    // MARK: - Verse Reference Resolution

    /// Parse "John 3:16" or "1 Kings 17:1" → (book, chapter, verse)
    private func parseVerseReference(_ ref: String) -> (book: String, chapter: Int, verse: Int)? {
        let colonParts = ref.components(separatedBy: ":")
        guard colonParts.count == 2,
              let verseNum = Int(colonParts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        let beforeColon = colonParts[0].trimmingCharacters(in: .whitespaces)
        let words = beforeColon.components(separatedBy: " ")
        guard words.count >= 2, let lastWord = words.last, let chapterNum = Int(lastWord) else { return nil }
        let bookName = words.dropLast().joined(separator: " ")
        return (bookName, chapterNum, verseNum)
    }

    /// Resolve an array of reference strings to SmartSearchVerse by fetching from the KJV bundle.
    private func resolveVerseReferences(_ refs: [String]) async -> [SmartSearchVerse] {
        var results: [SmartSearchVerse] = []
        // Group refs by chapter to minimise fetchChapterParsed calls
        var byChapter: [(ref: String, book: String, chapter: Int, verse: Int)] = []
        for ref in refs {
            guard let parsed = parseVerseReference(ref) else { continue }
            byChapter.append((ref, parsed.book, parsed.chapter, parsed.verse))
        }

        // Fetch each unique chapter once
        var chapterCache: [String: [ParsedVerse]] = [:]
        for item in byChapter {
            let key = "\(item.book)_\(item.chapter)"
            if chapterCache[key] == nil {
                if let (verses, _) = try? await KJVService.shared.fetchChapterParsed(book: item.book, chapter: item.chapter) {
                    chapterCache[key] = verses
                }
            }
        }

        for item in byChapter {
            let key = "\(item.book)_\(item.chapter)"
            guard let verses = chapterCache[key],
                  let verse = verses.first(where: { $0.number == item.verse }) else { continue }
            let testament = BibleData.books.first(where: { $0.name == item.book })?.testament == .old ? "OT" : "NT"
            results.append(SmartSearchVerse(reference: item.ref, text: verse.text, testament: testament))
        }
        return results
    }

    private func parseDailyInsightReflection(from raw: String) throws -> DailyInsightReflection {
        struct Payload: Decodable {
            let reflection: String
            let prayer_prompt: String
        }

        let jsonString: String
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") {
            jsonString = String(raw[start...end])
        } else {
            jsonString = raw
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw GeminiError.decodingError("Daily insight reflection was not valid UTF-8")
        }

        do {
            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            return DailyInsightReflection(
                reflection: decoded.reflection.trimmingCharacters(in: .whitespacesAndNewlines),
                prayerPrompt: decoded.prayer_prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            throw GeminiError.decodingError("Could not parse daily insight reflection JSON")
        }
    }

    // MARK: - Parsing Helpers

    private func parseJSONStringArray(from text: String) -> [String] {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    private func parseSmartSearchResult(from text: String, query: String) -> SmartSearchResult {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the JSON object even if Gemini adds surrounding text
        if let start = cleaned.firstIndex(of: "{") { cleaned = String(cleaned[start...]) }
        if let end = cleaned.lastIndex(of: "}") { cleaned = String(cleaned[...end]) }

        // Use JSONSerialization (not Codable) so a single wrong type doesn't kill the whole parse.
        // Gemini sometimes returns a string where an array is expected; we handle that below.
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[SmartSearch] ❌ JSON parse failed. Cleaned: \(cleaned.prefix(500))")
            return SmartSearchResult(
                summary: query, explanation: "", wordUsage: "",
                verses: [], strongsNumbers: [], relatedTerms: [query]
            )
        }

        // Safe string extractor
        func str(_ key: String) -> String { obj[key] as? String ?? "" }

        // Safe string-array extractor — handles both ["a","b"] and "a" from Gemini
        func strArray(_ key: String) -> [String] {
            if let arr = obj[key] as? [String] { return arr }
            if let arr = obj[key] as? [Any] { return arr.compactMap { $0 as? String } }
            if let s = obj[key] as? String { return [s] }
            return []
        }

        let refs = strArray("refs")
        let placeholderVerses = refs.map { SmartSearchVerse(reference: $0, text: "", testament: "NT") }

        return SmartSearchResult(
            summary: str("summary").isEmpty ? query : str("summary"),
            explanation: str("explanation"),
            wordUsage: str("word_usage"),
            verses: placeholderVerses,
            strongsNumbers: strArray("strongs"),
            relatedTerms: strArray("terms")
        )
    }
}
