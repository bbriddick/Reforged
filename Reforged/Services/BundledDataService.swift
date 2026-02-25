import Foundation

// MARK: - Bundled Data Service

/// Service for loading pre-bundled CSV data from the app bundle
class BundledDataService {
    static let shared = BundledDataService()

    private init() {}

    // MARK: - Bible Verse Cache

    struct CachedVerse {
        let id: String
        let reference: String
        let text: String
        let canonical: String
    }

    private var verseCache: [String: CachedVerse] = [:]

    func loadVerseCache() {
        guard verseCache.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "Bible Verse Cache Export Feb 1 2026", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to load verse cache CSV")
            return
        }

        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        // Skip header line
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = parseCSVLine(line, separator: ";")
            guard columns.count >= 4 else { continue }

            let verse = CachedVerse(
                id: columns[0],
                reference: columns[1],
                text: cleanText(columns[2]),
                canonical: columns[3]
            )

            // Store by both reference and canonical for easy lookup
            verseCache[verse.reference.lowercased()] = verse
            verseCache[verse.canonical.lowercased()] = verse
        }

        print("Loaded \(verseCache.count / 2) cached verses")
    }

    func getCachedVerse(reference: String) -> CachedVerse? {
        loadVerseCache()
        return verseCache[reference.lowercased()]
    }

    // MARK: - Daily Insights

    struct BundledDailyInsight {
        let id: String
        let dayOfYear: Int
        let title: String
        let summary: String
        let scripture: String
        let scriptureText: String
        let category: String
    }

    private var dailyInsights: [Int: BundledDailyInsight] = [:]

    func loadDailyInsights() {
        guard dailyInsights.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "Daily Insights Export Feb 1 2026", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to load daily insights CSV")
            return
        }

        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        // Skip header line
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = parseCSVLine(line, separator: ";")
            guard columns.count >= 7 else { continue }

            guard let dayOfYear = Int(columns[1]) else { continue }

            let insight = BundledDailyInsight(
                id: columns[0],
                dayOfYear: dayOfYear,
                title: columns[2],
                summary: columns[3],
                scripture: columns[4],
                scriptureText: cleanText(columns[5]),
                category: columns[6]
            )

            dailyInsights[dayOfYear] = insight
        }

        print("Loaded \(dailyInsights.count) daily insights")
    }

    func getDailyInsight(forDayOfYear day: Int) -> BundledDailyInsight? {
        loadDailyInsights()
        return dailyInsights[day]
    }

    func getTodaysInsight() -> BundledDailyInsight? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return getDailyInsight(forDayOfYear: dayOfYear)
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
        // Remove leading/trailing quotes
        if cleaned.hasPrefix("\"") { cleaned.removeFirst() }
        if cleaned.hasSuffix("\"") { cleaned.removeLast() }
        // Handle escaped quotes
        cleaned = cleaned.replacingOccurrences(of: "\"\"", with: "\"")
        return cleaned
    }

}

// MARK: - Convert to App Models

extension BundledDataService {

    /// Convert bundled daily insight to app DailyInsight model
    func convertToDailyInsight(_ bundled: BundledDailyInsight) -> DailyInsight {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: Date())

        return DailyInsight(
            id: bundled.id,
            date: dateString,
            title: bundled.title,
            verse: bundled.scripture,
            verseText: bundled.scriptureText,
            reflection: bundled.summary,
            prayerPrompt: "Reflect on how \(bundled.scripture) applies to your life today."
        )
    }
}
