import Foundation

/// One morning or evening devotional reading.
struct SpurgeonReading: Codable, Equatable {
    let title: String      // e.g. "Morning, January 1"
    let verse: String      // the opening verse quotation
    let reference: String  // e.g. "Joshua 5:12"
    let body: String
}

struct SpurgeonSearchHit: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let reference: String
    let snippet: String
}

/// A single day of Spurgeon's Morning and Evening.
struct SpurgeonDay: Codable, Identifiable, Equatable {
    let day: Int      // 1...366, in calendar order
    let key: String   // "MM.DD"
    let label: String // e.g. "January 1"
    let morning: SpurgeonReading
    let evening: SpurgeonReading

    var id: Int { day }
}

/// Offline reader data for C. H. Spurgeon's "Morning and Evening" daily devotional (public
/// domain, via CrossWire's SME module). Bundled JSON, synchronous — mirrors
/// `CrossReferenceService`. Devotional references inside the prose are plain readable strings
/// so `LinkedScriptureText` re-links them.
final class SpurgeonDevotionalService {
    static let shared = SpurgeonDevotionalService()

    private struct Bundle_: Decodable { let days: [SpurgeonDay] }

    private var days: [SpurgeonDay] = []
    private var byDay: [Int: SpurgeonDay] = [:]
    private var byKey: [String: SpurgeonDay] = [:]
    private var loaded = false

    private init() {}

    var totalDays: Int {
        ensureLoaded()
        return days.count
    }

    var allDays: [SpurgeonDay] {
        ensureLoaded()
        return days
    }

    /// Full-text search across all morning and evening readings.
    func search(_ query: String, limit: Int = 3) -> [SpurgeonSearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 3 else { return [] }
        var hits: [SpurgeonSearchHit] = []
        for day in allDays {
            for reading in [day.morning, day.evening] {
                let haystacks = [reading.title, reading.verse, reading.body]
                guard let match = haystacks.first(where: { $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }),
                      let range = match.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
                let start = match.index(range.lowerBound, offsetBy: -40, limitedBy: match.startIndex) ?? match.startIndex
                let end = match.index(range.upperBound, offsetBy: 110, limitedBy: match.endIndex) ?? match.endIndex
                let snippet = match[start..<end].replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                hits.append(SpurgeonSearchHit(day: day.day, title: reading.title, reference: reading.reference, snippet: "…\(snippet)…"))
                if hits.count >= limit { return hits }
            }
        }
        return hits
    }

    func day(_ day: Int) -> SpurgeonDay? {
        ensureLoaded()
        return byDay[day]
    }

    /// The 1-based day number for today's calendar date (falls back to day 1).
    func todayDayNumber(_ date: Date = Date()) -> Int {
        ensureLoaded()
        let key = Self.keyFormatter.string(from: date)
        return byKey[key]?.day ?? 1
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM.dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "SpurgeonMorningEvening", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Bundle_.self, from: data) else {
            debugLog("SpurgeonDevotionalService: Could not load SpurgeonMorningEvening.json")
            return
        }
        days = decoded.days
        byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        byKey = Dictionary(days.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }
}
