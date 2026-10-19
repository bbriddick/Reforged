import Foundation

// MARK: - Continue Reading
//
// One answer to "where do I pick up?", shared by Home and the Bible navigator so they never
// disagree. With a reading plan running it is the plan's next entry (resuming at the first chapter
// not yet read); otherwise it is the reader's last position. The plan is a self-paced queue, so
// there is always a next entry until it finishes — missed days are never surfaced as debt.

struct ContinueTarget: Equatable {
    /// Reference the Bible view opens, e.g. "Psalms 23" or "John 3:16".
    let reference: String
    let book: String
    let chapter: Int
    /// First verse to land on (1 = chapter top).
    let verse: Int
    let title: String
    let subtitle: String
    let isPlan: Bool
}

@MainActor
enum ContinueReading {
    static func current() -> ContinueTarget? {
        planTarget() ?? positionTarget()
    }

    private static func planTarget() -> ContinueTarget? {
        let service = ReadingPlanService.shared
        guard let plan = service.activePlan, let entry = service.activeEntry,
              !entry.isReflectionDay, let navRef = entry.navRef else { return nil }

        let resume = service.firstUnreadChapter(in: entry)
        let reference = resume.map { "\($0.book) \($0.chapter)" } ?? navRef
        guard let (book, chapter) = split(reference) else { return nil }

        let partial = service.isPartiallyRead(entry)
        let title = partial ? "Continue at \(reference)" : entry.scriptureReference
        let day = "Day \(entry.day) of \(plan.totalDays)"
        return ContinueTarget(
            reference: reference, book: book, chapter: chapter, verse: 1,
            title: title,
            subtitle: partial ? "\(plan.name) · \(day)" : "Today's reading · \(day)",
            isPlan: true
        )
    }

    private static func positionTarget() -> ContinueTarget? {
        let defaults = UserDefaults.standard
        guard let book = defaults.string(forKey: "bible_last_book"),
              BibleData.books.contains(where: { $0.name == book }) else { return nil }
        let chapter = max(defaults.integer(forKey: "bible_last_chapter"), 1)
        let verse = max(defaults.integer(forKey: "bible_last_verse"), 1)
        return ContinueTarget(
            reference: verse > 1 ? "\(book) \(chapter):\(verse)" : "\(book) \(chapter)",
            book: book, chapter: chapter, verse: verse,
            title: "Continue \(book) \(chapter)",
            subtitle: verse > 1 ? "Verse \(verse) · where you left off" : "Where you left off",
            isPlan: false
        )
    }

    private static func split(_ reference: String) -> (String, Int)? {
        guard let space = reference.lastIndex(of: " "),
              let chapter = Int(reference[reference.index(after: space)...]) else { return nil }
        return (String(reference[..<space]), chapter)
    }
}
