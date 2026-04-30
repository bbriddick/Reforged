import Foundation
import SwiftUI

// MARK: - BiblePlanEntry

struct BiblePlanEntry: Identifiable, Hashable {
    let planId: String
    let day: Int
    let scriptureReference: String
    let refinementPrompt: String

    var id: String { "\(planId)-\(day)" }

    var isReflectionDay: Bool {
        scriptureReference == "Reflection" || scriptureReference == "Final Review"
    }

    /// Maps the raw CSV reference to the format BibleView's parser accepts: "BookName Chapter"
    var navRef: String? {
        BiblePlanEntry.navigationRef(for: scriptureReference)
    }

    /// All (bookName, chapterNumber) pairs that must be marked as read for this entry to
    /// auto-complete. Verse-range entries (e.g. "Psalm 119:1-16") return [] — those are
    /// intended for deep study and should be completed manually via the checkmark.
    var requiredChapters: [(book: String, chapter: Int)] {
        BiblePlanEntry.parseRequiredChapters(for: scriptureReference)
    }

    // MARK: - Reference Parsing

    static func parseRequiredChapters(for ref: String) -> [(book: String, chapter: Int)] {
        guard ref != "Reflection", ref != "Final Review" else { return [] }

        if let toRange = ref.range(of: " to ", options: .caseInsensitive) {
            let left  = String(ref[..<toRange.lowerBound])
            let right = String(ref[toRange.upperBound...])
            return parseCrossBookRange(left: normalizeBookName(left),
                                       right: normalizeBookName(right))
        }
        return parseSameBookRange(normalizeBookName(ref))
    }

    private static func parseSameBookRange(_ ref: String) -> [(book: String, chapter: Int)] {
        let words = ref.components(separatedBy: " ")
        guard words.count >= 2, let chapterPart = words.last else { return [] }
        let bookName = words.dropLast().joined(separator: " ")

        // Verse-range entries ("119:1-16") — return [] so they're manual-only
        if chapterPart.contains(":") { return [] }

        let rangeParts = chapterPart.components(separatedBy: "-")
        if rangeParts.count == 2,
           let start = Int(rangeParts[0]),
           let end   = Int(rangeParts[1]),
           start <= end {
            return (start...end).map { (bookName, $0) }
        }
        if let ch = Int(chapterPart) { return [(bookName, ch)] }
        return []
    }

    private static func parseCrossBookRange(left: String,
                                            right: String) -> [(book: String, chapter: Int)] {
        let leftWords  = left.components(separatedBy: " ")
        let rightWords = right.components(separatedBy: " ")
        guard leftWords.count  >= 2,
              rightWords.count >= 2,
              let startCh = Int(leftWords.last  ?? ""),
              let endCh   = Int(rightWords.last ?? "") else { return [] }

        let startBookName = leftWords.dropLast().joined(separator: " ")
        let endBookName   = rightWords.dropLast().joined(separator: " ")

        guard let startIdx = BibleData.books.firstIndex(where: { $0.name == startBookName }),
              let endIdx   = BibleData.books.firstIndex(where: { $0.name == endBookName }),
              startIdx <= endIdx else { return [] }

        var result: [(String, Int)] = []
        for bookIdx in startIdx...endIdx {
            let book      = BibleData.books[bookIdx]
            let fromChap  = (bookIdx == startIdx) ? startCh : 1
            let toChap    = (bookIdx == endIdx)   ? endCh   : book.chapters
            guard fromChap <= toChap else { continue }
            for ch in fromChap...toChap { result.append((book.name, ch)) }
        }
        return result
    }

    static func navigationRef(for ref: String) -> String? {
        guard ref != "Reflection", ref != "Final Review" else { return nil }

        // Strip cross-book suffix: "Genesis 49 to Exodus 2" → "Genesis 49"
        var clean = ref
        if let toRange = clean.range(of: " to ", options: .caseInsensitive) {
            clean = String(clean[..<toRange.lowerBound])
        }

        // Normalize common abbreviations and singular "Psalm" → "Psalms"
        clean = normalizeBookName(clean)

        // Split into words; last word is the chapter (possibly "1-2", "119:1-16", "119-121")
        let words = clean.components(separatedBy: " ")
        guard words.count >= 2, let last = words.last else { return clean }

        // Extract just the opening chapter number from ranges
        let chapterStr = last.components(separatedBy: CharacterSet(charactersIn: "-:")).first ?? last
        guard Int(chapterStr) != nil else { return clean }

        let bookName = words.dropLast().joined(separator: " ")
        return "\(bookName) \(chapterStr)"
    }

    private static func normalizeBookName(_ ref: String) -> String {
        let substitutions: [(String, String)] = [
            ("Psalm ", "Psalms "),
            ("1 Cor ", "1 Corinthians "),
            ("2 Cor ", "2 Corinthians "),
        ]
        for (abbr, full) in substitutions {
            if ref.hasPrefix(abbr) {
                return full + ref.dropFirst(abbr.count)
            }
        }
        return ref
    }
}

// MARK: - BibleReadingPlan

struct BibleReadingPlan: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let accentColor: Color
    let entries: [BiblePlanEntry]

    var totalDays: Int { entries.count }
    var readingDays: Int { entries.filter { !$0.isReflectionDay }.count }
}

// MARK: - All Plans namespace

enum BibleReadingPlans {
    static let all: [BibleReadingPlan] = [
        foundation, character, discipleship, bibleInAYear, newTestament
    ]
}
