import Foundation

struct PodcastEpisode: Identifiable, Codable {
    let id: String
    let title: String
    let pubDate: Date
    let audioURL: URL
    let duration: String
    let descriptionHTML: String
    let imageURL: URL?

    var durationSeconds: Double {
        let parts = duration.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return 0
        }
    }

    var plainDescription: String {
        descriptionHTML
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: pubDate)
    }

    /// Named series this episode belongs to.
    var seriesName: String {
        // Friday Focus — weekly interview/feature episodes every Friday
        if title.contains("Friday Focus") { return PodcastSeries.fridayFocus.rawValue }

        // The Word Within — verse-by-verse through Psalm 119
        if title.contains("Psalm 119") || title.hasPrefix("The Word Within") ||
           title.contains("Center of the Psalm") {
            return PodcastSeries.wordWithin.rawValue
        }

        // Moses: Lessons from a Life of Faith — Exodus through Deuteronomy
        let mosesTriggers = ["(Exodus", "(Numbers", "(Deuteronomy", "(Psalm 90)", "(Hebrews 11:23"]
        if mosesTriggers.contains(where: { title.contains($0) }) ||
           title.hasPrefix("Moses") || title.contains("Stage for Moses") {
            return PodcastSeries.moses.rawValue
        }

        // Enduring Joy — verse-by-verse through Philippians
        if title.contains("Philippians") || title.hasPrefix("Enduring Joy") {
            return PodcastSeries.enduringJoy.rawValue
        }

        // Unshakeable Confidence — 12-week study through 1 John
        if title.contains("1 John") || title.hasPrefix("Unshakeable Confidence") {
            return PodcastSeries.unshakeableConfidence.rawValue
        }

        return PodcastSeries.other.rawValue
    }
}

struct PodcastFeed: Codable {
    let title: String
    let description: String
    let artworkURL: URL?
    let episodes: [PodcastEpisode]
    let cachedAt: Date

    var isStale: Bool {
        cachedAt < Date().addingTimeInterval(-4 * 3600)
    }

    /// Fixed ordered category list. Only includes series that have at least one episode in the feed.
    var categories: [String] {
        let populated = Set(episodes.map(\.seriesName))
        return PodcastSeries.displayOrder.map(\.rawValue).filter { populated.contains($0) }
    }
}

// MARK: - PodcastSeries

enum PodcastSeries: String {
    case fridayFocus           = "Friday Focus"
    case wordWithin            = "The Word Within"
    case moses                 = "Moses: Lessons from a Life of Faith"
    case enduringJoy           = "Enduring Joy"
    case unshakeableConfidence = "Unshakeable Confidence"
    case other                 = "Other"

    static let displayOrder: [PodcastSeries] = [
        .fridayFocus,
        .wordWithin,
        .moses,
        .enduringJoy,
        .unshakeableConfidence,
        .other,
    ]

    /// Short subtitle shown in the category chip tooltip / about sheet.
    var subtitle: String {
        switch self {
        case .fridayFocus:           return "Weekly features & interviews"
        case .wordWithin:            return "Verse-by-verse through Psalm 119"
        case .moses:                 return "Lessons from a Life of Faith"
        case .enduringJoy:           return "Verse-by-verse through Philippians"
        case .unshakeableConfidence: return "12 weeks through 1 John"
        case .other:                 return "Standalone episodes"
        }
    }
}
