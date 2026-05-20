import Foundation

// MARK: - NET Bible API Configuration
// https://labs.bible.org/api_web_service
// Free public API — no key required. Returns JSON array of verse objects.

struct NETConfig {
    static let baseURL = "https://labs.bible.org/api/"
}

// MARK: - NET API Response Models

struct NETVerse: Codable {
    let bookname: String
    let chapter: String
    let verse: String
    let text: String
    let title: String?
}

// MARK: - NET Service Errors

enum NETError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noPassageFound
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL"
        case .invalidResponse:     return "Invalid response from NET Bible API"
        case .httpError(let code): return "HTTP error: \(code)"
        case .noPassageFound:      return "No passage found"
        case .decodingError(let m): return "Failed to decode response: \(m)"
        }
    }
}

// MARK: - NET Cache Models

struct NETCachedChapter: Codable {
    let book: String
    let chapter: Int
    let canonical: String
    let cachedAt: Date
    let verses: [NETCachedVerse]

    var isStale: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < cutoff
    }
}

struct NETCachedVerse: Codable {
    let number: Int
    let text: String
    let reference: String
}

// MARK: - NET Service

class NETService {
    static let shared = NETService()

    private let baseURL = NETConfig.baseURL
    private var chapterCache: [String: NETCachedChapter] = [:]
    private let cacheKey = "net_chapter_cache"
    private let cacheQueue = DispatchQueue(label: "com.reforged.netcache")

    private init() {
        cacheQueue.async { self.loadCacheFromDisk() }
    }

    // MARK: - Cache

    private func cacheKeyFor(book: String, chapter: Int) -> String { "\(book)_\(chapter)" }

    private func loadCacheFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode([String: NETCachedChapter].self, from: data) else { return }
        chapterCache = cache
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(chapterCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func getCachedChapter(book: String, chapter: Int) -> NETCachedChapter? {
        cacheQueue.sync {
            let key = cacheKeyFor(book: book, chapter: chapter)
            guard let cached = chapterCache[key], !cached.isStale else { return nil }
            return cached
        }
    }

    private func cacheChapter(_ chapter: NETCachedChapter) {
        cacheQueue.async {
            self.chapterCache[self.cacheKeyFor(book: chapter.book, chapter: chapter.chapter)] = chapter
            self.saveCacheToDisk()
        }
    }

    func clearCache() {
        cacheQueue.async {
            self.chapterCache.removeAll()
            UserDefaults.standard.removeObject(forKey: self.cacheKey)
        }
    }

    // MARK: - API

    private func buildURL(passage: String) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "passage", value: passage),
            URLQueryItem(name: "type", value: "json"),
            URLQueryItem(name: "formatting", value: "plain")
        ]
        return components?.url
    }

    private func fetch(passage: String) async throws -> [NETVerse] {
        guard let url = buildURL(passage: passage) else { throw NETError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw NETError.invalidResponse }
        guard http.statusCode == 200 else { throw NETError.httpError(http.statusCode) }

        do {
            let verses = try JSONDecoder().decode([NETVerse].self, from: data)
            guard !verses.isEmpty else { throw NETError.noPassageFound }
            return verses
        } catch let e as NETError {
            throw e
        } catch {
            throw NETError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Chapter

    func fetchChapterParsed(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String) {
        if let cached = getCachedChapter(book: book, chapter: chapter) {
            let verses = cached.verses.map {
                ParsedVerse(id: $0.reference, number: $0.number, text: $0.text, reference: $0.reference)
            }
            return (verses, cached.canonical)
        }

        let passage = "\(book) \(chapter)"
        let netVerses = try await fetch(passage: passage)
        let canonical = "\(book) \(chapter)"

        let parsed = netVerses.compactMap { v -> ParsedVerse? in
            guard let verseNum = Int(v.verse) else { return nil }
            let ref = "\(book) \(chapter):\(verseNum)"
            return ParsedVerse(id: ref, number: verseNum, text: v.text, reference: ref)
        }.sorted { $0.number < $1.number }

        let cachedVerses = parsed.map { NETCachedVerse(number: $0.number, text: $0.text, reference: $0.reference) }
        cacheChapter(NETCachedChapter(book: book, chapter: chapter, canonical: canonical, cachedAt: Date(), verses: cachedVerses))

        return (parsed, canonical)
    }

    // MARK: - Fetch Verse for Memory

    func fetchVerseForMemory(reference: String) async throws -> (text: String, canonical: String) {
        let netVerses = try await fetch(passage: reference)
        let text = netVerses.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, reference)
    }

    // MARK: - Search (local cache)

    func searchPassages(query: String, pageSize: Int = 50) async -> [BibleSearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        var matches: [(result: BibleSearchResult, score: Int)] = []

        cacheQueue.sync {
            for chapter in chapterCache.values {
                for verse in chapter.verses {
                    let lowered = verse.text.lowercased()
                    guard lowered.contains(normalized) else { continue }

                    var score = 1
                    if lowered == normalized { score += 10 }
                    if lowered.hasPrefix(normalized) { score += 4 }
                    if lowered.range(of: "\\b\(NSRegularExpression.escapedPattern(for: normalized))\\b",
                                     options: .regularExpression) != nil { score += 6 }

                    matches.append((
                        result: BibleSearchResult(reference: verse.reference, content: verse.text, translation: .net),
                        score: score
                    ))
                }
            }
        }

        return matches
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.result.reference < $1.result.reference }
            .prefix(pageSize)
            .map(\.result)
    }
}
