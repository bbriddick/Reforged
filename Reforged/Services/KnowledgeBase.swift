import Foundation

// MARK: - Knowledge Base Service

/// Centralized knowledge base for all app content including verses, insights, and learning content.
/// This service provides a unified interface to access all bundled and dynamic content.
class KnowledgeBase: ObservableObject {
    static let shared = KnowledgeBase()

    // MARK: - Published Properties

    @Published var isLoaded = false

    // MARK: - Private Data Stores

    private var verseCache: [String: VerseEntry] = [:]
    private var dailyInsights: [Int: InsightEntry] = [:]
    private var verseCategories: [String: [VerseEntry]] = [:]

    private let bundledService = BundledDataService.shared

    // MARK: - Data Models

    struct VerseEntry {
        let id: String
        let reference: String
        let text: String
        let canonicalReference: String
        let book: String
        let chapter: Int
        let verse: Int
        var category: String?
        var tags: [String]

        init(id: String, reference: String, text: String, canonicalReference: String, category: String? = nil, tags: [String] = []) {
            self.id = id
            self.reference = reference
            self.text = text
            self.canonicalReference = canonicalReference
            self.category = category
            self.tags = tags

            // Parse book, chapter, verse from reference
            let parts = reference.components(separatedBy: " ")
            if parts.count >= 2 {
                // Handle books like "1 John 3:16"
                let lastPart = parts.last ?? ""
                if lastPart.contains(":") {
                    let chapterVerse = lastPart.components(separatedBy: ":")
                    self.book = parts.dropLast().joined(separator: " ")
                    self.chapter = Int(chapterVerse[0]) ?? 1
                    self.verse = Int(chapterVerse.count > 1 ? chapterVerse[1].components(separatedBy: "-")[0] : "1") ?? 1
                } else {
                    self.book = parts.dropLast().joined(separator: " ")
                    self.chapter = Int(lastPart) ?? 1
                    self.verse = 1
                }
            } else {
                self.book = reference
                self.chapter = 1
                self.verse = 1
            }
        }
    }

    struct InsightEntry {
        let id: String
        let dayOfYear: Int
        let title: String
        let reflection: String
        let verseReference: String
        let verseText: String
        let category: String
        let prayerPrompt: String?
    }

    // MARK: - Initialization

    private init() {
        loadAllData()
    }

    // MARK: - Loading

    /// Load all knowledge base data from bundled sources
    func loadAllData() {
        loadVerseCache()
        loadDailyInsights()
        isLoaded = true
        print("KnowledgeBase: Loaded \(verseCache.count / 2) verses, \(dailyInsights.count) daily insights")
    }

    private func loadVerseCache() {
        bundledService.loadVerseCache()

        // Convert bundled verses to our VerseEntry format
        // The bundled service stores verses with reference as key
        guard let url = Bundle.main.url(forResource: "Bible Verse Cache Export Feb 1 2026", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = parseCSVLine(line, separator: ";")
            guard columns.count >= 4 else { continue }

            let entry = VerseEntry(
                id: columns[0],
                reference: columns[1],
                text: cleanText(columns[2]),
                canonicalReference: columns[3]
            )

            // Store by multiple keys for easy lookup
            verseCache[entry.reference.lowercased()] = entry
            verseCache[entry.canonicalReference.lowercased()] = entry
        }
    }

    private func loadDailyInsights() {
        bundledService.loadDailyInsights()

        guard let url = Bundle.main.url(forResource: "Daily Insights Export Feb 1 2026", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = parseCSVLine(line, separator: ";")
            guard columns.count >= 7, let dayOfYear = Int(columns[1]) else { continue }

            let entry = InsightEntry(
                id: columns[0],
                dayOfYear: dayOfYear,
                title: columns[2],
                reflection: columns[3],
                verseReference: columns[4],
                verseText: cleanText(columns[5]),
                category: columns[6],
                prayerPrompt: "Reflect on how \(columns[4]) applies to your life today."
            )

            dailyInsights[dayOfYear] = entry
        }
    }

    // MARK: - Verse Access

    /// Get a verse by reference (e.g., "John 3:16" or "1 Corinthians 13:4")
    func getVerse(reference: String) -> VerseEntry? {
        return verseCache[reference.lowercased()]
    }

    /// Search verses by keyword
    func searchVerses(query: String, limit: Int = 20) -> [VerseEntry] {
        let queryLower = query.lowercased()
        return verseCache.values
            .filter { verse in
                verse.text.lowercased().contains(queryLower) ||
                verse.reference.lowercased().contains(queryLower)
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Get verses by category
    func getVersesByCategory(_ category: String) -> [VerseEntry] {
        return verseCategories[category.lowercased()] ?? []
    }

    // MARK: - Daily Insight Access

    /// Get the daily insight for a specific day of year (1-366)
    func getDailyInsight(forDayOfYear day: Int) -> InsightEntry? {
        return dailyInsights[day]
    }

    /// Get today's daily insight
    func getTodaysInsight() -> InsightEntry? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return getDailyInsight(forDayOfYear: dayOfYear)
    }

    /// Convert InsightEntry to the app's DailyInsight model
    func convertToDailyInsight(_ entry: InsightEntry) -> DailyInsight {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: Date())

        return DailyInsight(
            id: entry.id,
            date: dateString,
            title: entry.title,
            verse: entry.verseReference,
            verseText: entry.verseText,
            reflection: entry.reflection,
            prayerPrompt: entry.prayerPrompt
        )
    }

    // MARK: - Memory Verse Suggestions

    /// Get suggested memory verses based on user's goals
    func getSuggestedMemoryVerses(forGoals goals: [String], limit: Int = 5) -> [VerseEntry] {
        // Map goals to verse categories
        let categoryMap: [String: [String]] = [
            "storyline": ["narrative", "history", "salvation"],
            "doctrine": ["doctrine", "theology", "teaching"],
            "daily-habit": ["devotional", "wisdom", "daily"],
            "memorize": ["key-verses", "popular", "foundation"],
            "big-picture": ["prophecy", "redemption", "overview"],
            "walk": ["faith", "prayer", "discipleship", "encouragement"]
        ]

        var relevantCategories: Set<String> = []
        for goal in goals {
            if let categories = categoryMap[goal] {
                relevantCategories.formUnion(categories)
            }
        }

        // Get verses from relevant categories
        var suggestions: [VerseEntry] = []
        for category in relevantCategories {
            suggestions.append(contentsOf: getVersesByCategory(category))
        }

        // Shuffle and limit
        return Array(suggestions.shuffled().prefix(limit))
    }

    // MARK: - Helpers

    private func parseCSVLine(_ line: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == separator && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result
    }

    private func cleanText(_ text: String) -> String {
        var cleaned = text
        if cleaned.hasPrefix("\"") { cleaned.removeFirst() }
        if cleaned.hasSuffix("\"") { cleaned.removeLast() }
        cleaned = cleaned.replacingOccurrences(of: "\"\"", with: "\"")
        return cleaned
    }
}

// MARK: - Quick Access Extensions

extension KnowledgeBase {
    /// Quick method to get verse text by reference
    func verseText(for reference: String) -> String? {
        return getVerse(reference: reference)?.text
    }

    /// Get a random verse for the day (useful for widgets, etc.)
    func getRandomDailyVerse() -> VerseEntry? {
        // Use day of year as seed for consistent daily selection
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let allVerses = Array(verseCache.values)
        guard !allVerses.isEmpty else { return nil }
        let index = dayOfYear % allVerses.count
        return allVerses[index]
    }
}
