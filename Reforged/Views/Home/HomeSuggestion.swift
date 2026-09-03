import SwiftUI

// MARK: - Home Suggestion
//
// The one thing to do first, shown in HomeView's hero card. Suggestions are
// CONTEXTUAL then ROTATING: `pick` gathers everything still undone right now,
// keeps only the most pressing tier, and returns a random one from it — so the
// card never nags about a chapter already read, but still varies morning to
// morning. It re-rolls on every app open (see WelcomeHeader).
//
// "Done for the day" means the day's two disciplines are done (see
// ReadingStreakManager.dailyActivityGoal) — NOT that the reading plan is finished.
// The plan is a self-paced queue with a next entry always waiting, so gating
// done-ness on it would nag forever.
//
// Deliberately excluded:
//   • The reading plan — Home's Today row already shows the next entry, and the
//     plan can't answer "am I done today?" anyway (see ReadingPlanService).
//   • Prayer — PrayerPromptSheet's prompts are written for a moment of
//     temptation, not for "what should I do first today".

enum HomeSuggestion: Equatable {
    /// Social is shielded until a discipline is done — the way out is the point.
    case unlockSocial
    case readChapter
    case reviewVerses(count: Int)
    case memorizeFirst
    case journal
    /// Everything's done. Not a task — a blessing.
    case restWell

    // MARK: - Selection

    /// Everything worth suggesting right now, most pressing tier first. Only the
    /// first non-empty tier is used, so a closed unlock gate outranks journaling.
    private static func tiers(
        hasReadToday: Bool,
        isDailyGoalMet: Bool,
        versesDue: Int,
        hasAnyVerses: Bool,
        isGateLocked: Bool
    ) -> [[HomeSuggestion]] {
        [
            // Blocking: the user is locked out of something until they act.
            isGateLocked ? [.unlockSocial] : [],

            // The day's two disciplines are done. Say so — and `restWell` was
            // unreachable until this tier existed, because the enrichment tier
            // below is never empty.
            isDailyGoalMet ? [.restWell, .journal] : [],

            // The daily core.
            [
                hasReadToday ? nil : .readChapter,
                versesDue > 0 ? .reviewVerses(count: versesDue) : nil,
                hasAnyVerses ? nil : .memorizeFirst
            ].compactMap { $0 },

            // Nothing pressing left, but the day's goal isn't met yet.
            [.journal]
        ]
    }

    /// Picks the next suggestion, avoiding `current` when there's a real choice so
    /// consecutive opens don't repeat.
    static func pick(
        excluding current: HomeSuggestion?,
        hasReadToday: Bool,
        isDailyGoalMet: Bool,
        versesDue: Int,
        hasAnyVerses: Bool,
        isGateLocked: Bool
    ) -> HomeSuggestion {
        let pool = tiers(
            hasReadToday: hasReadToday,
            isDailyGoalMet: isDailyGoalMet,
            versesDue: versesDue,
            hasAnyVerses: hasAnyVerses,
            isGateLocked: isGateLocked
        ).first { !$0.isEmpty } ?? []

        guard !pool.isEmpty else { return .restWell }
        if let current, pool.count > 1 {
            let others = pool.filter { $0 != current }
            if let pick = others.randomElement() { return pick }
        }
        return pool.randomElement() ?? .restWell
    }

    // MARK: - Presentation

    var icon: String {
        switch self {
        case .unlockSocial:  return "lock.open.fill"
        case .readChapter:   return "text.book.closed.fill"
        case .reviewVerses:  return "brain.head.profile"
        case .memorizeFirst: return "sparkles"
        case .journal:       return "square.and.pencil"
        case .restWell:      return "checkmark.circle.fill"
        }
    }

    /// Small, uppercase, wide-tracked, gold — the brand's eyebrow label.
    var eyebrow: String {
        switch self {
        case .unlockSocial:  return "Start here"
        case .readChapter:   return "Start here"
        case .reviewVerses:  return "Verses due"
        case .memorizeFirst: return "Scripture memory"
        case .journal:       return "Reflect"
        case .restWell:      return "Today's work is done"
        }
    }

    var title: String {
        switch self {
        case .unlockSocial:
            return "Open the Word to unlock"
        case .readChapter:
            return "Read a chapter"
        case .reviewVerses(let count):
            return count == 1 ? "One verse is ready for review" : "\(count) verses are ready for review"
        case .memorizeFirst:
            return "Memorize your first verse"
        case .journal:
            return "Write down what you're seeing"
        case .restWell:
            return "You've spent time in the Word today"
        }
    }

    var detail: String {
        switch self {
        case .unlockSocial:
            return "Your social apps stay shielded until you read a chapter or practice a verse."
        case .readChapter:
            return "A few minutes in Scripture is enough to start the day well."
        case .reviewVerses:
            return "A quick review is what moves a verse into long-term memory."
        case .memorizeFirst:
            return "Pick a verse that matters to you — spaced repetition does the rest."
        case .journal:
            return "A sentence about what God showed you is worth keeping."
        case .restWell:
            return "Rest in it. Come back whenever you want more."
        }
    }

    var actionLabel: String {
        switch self {
        case .unlockSocial:  return "Open the Bible"
        case .readChapter:   return "Open the Bible"
        case .reviewVerses:  return "Review now"
        case .memorizeFirst: return "Add a verse"
        case .journal:       return "Open Journal"
        case .restWell:      return "Read more"
        }
    }

    /// Where the button goes. Tab indices match MainTabView / the iPad sidebar.
    enum Destination: Equatable {
        case tab(Int)
        case journal
    }

    var destination: Destination {
        switch self {
        case .unlockSocial, .readChapter, .restWell: return .tab(2)
        case .reviewVerses, .memorizeFirst:          return .tab(3)
        case .journal:                               return .journal
        }
    }
}
