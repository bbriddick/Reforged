import Foundation
import SwiftUI

// MARK: - Rule-of-Life ("My Rhythm") Models
//
// A member's personal daily rhythm: a checklist they build themselves. Each item
// is either a habit to keep ("do") or a temptation to stay clear of ("avoid"),
// can run on chosen weekdays, and can carry a real daily reminder. The custom
// reading-plan spec lives here too, since a build-your-own plan is part of the
// same "design my own walk with God" surface.
//
// Everything is Codable with stable ids so it persists locally now and can sync
// to Supabase later without reshaping (see [[discipleship-plan-builder]] history).

// MARK: - Accent palette

/// On-brand accent choices. Stored as a raw string so it is Codable and
/// forward-compatible; unknown values fall back to `gold`.
enum PlanAccent: String, Codable, CaseIterable, Identifiable {
    case gold, coral, purple, teal, blue, green, navy

    var id: String { rawValue }

    /// A color safe in both light and dark. `navy` uses the adaptive
    /// charcoal/off-white so it never vanishes on dark cards.
    func color(_ scheme: ColorScheme?) -> Color {
        switch self {
        case .gold:   return .reforgedGold
        case .coral:  return .reforgedCoral
        case .purple: return Color(red: 0.55, green: 0.35, blue: 0.70)
        case .teal:   return Color(red: 0.004, green: 0.490, blue: 0.616)
        case .blue:   return Color(red: 0.10, green: 0.65, blue: 0.80)
        case .green:  return Color(red: 0.20, green: 0.65, blue: 0.40)
        case .navy:   return Color.adaptiveNavyText(scheme)
        }
    }

    var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .coral: return "Coral"
        case .purple: return "Purple"
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .green: return "Green"
        case .navy: return "Charcoal"
        }
    }
}

// MARK: - Rhythm item

/// Whether an item is a habit to keep or a temptation to avoid. `doHabit`
/// (raw "do") is the positive case; "do" is a Swift keyword so the case is named
/// `doHabit` while keeping the stored value "do".
enum RhythmKind: String, Codable {
    case doHabit = "do"
    case avoid

    /// Verb for the check-off action, tuned to the kind.
    var completedVerb: String { self == .doHabit ? "Done" : "Stayed faithful" }
}

/// A single self-authored checklist item.
struct RhythmItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var note: String = ""
    var kind: RhythmKind = .doHabit
    var iconName: String = "checkmark.circle.fill"
    var accent: PlanAccent = .gold

    /// Calendar weekdays (1 = Sunday … 7 = Saturday) the item is active. Empty is
    /// treated as every day.
    var weekdays: Set<Int> = Set(1...7)

    /// Optional daily reminder. When `reminderEnabled`, a real local notification
    /// fires at this time on each active weekday.
    var reminderEnabled: Bool = false
    var reminderHour: Int = 8
    var reminderMinute: Int = 0

    var sortOrder: Int = 0
    var createdAt: Date = Date()

    var hasReminder: Bool { reminderEnabled }

    /// Whether this item should appear on the given calendar weekday.
    func isActive(on weekday: Int) -> Bool {
        weekdays.isEmpty || weekdays.contains(weekday)
    }

    var reminderTimeLabel: String {
        var comps = DateComponents()
        comps.hour = reminderHour
        comps.minute = reminderMinute
        let date = Calendar.current.date(from: comps) ?? Date()
        return RhythmItem.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

// MARK: - Custom reading plan spec
//
// A user-built reading plan. Persisted as this lightweight Codable spec and
// rebuilt into a `BibleReadingPlan` at runtime (see BibleReadingPlan+Custom),
// so it flows through the existing ReadingPlanService / ReadingPlansView with no
// special-casing — progress tracks by the spec's `id`.

struct CustomReadingPlanSpec: Codable, Identifiable, Hashable {
    var id: String            // e.g. "custom-<uuid>"; also the ReadingPlanService key
    var name: String
    var planDescription: String
    var iconName: String = "book.closed.fill"
    var accent: PlanAccent = .teal
    var entries: [Entry]
    var createdAt: Date = Date()

    struct Entry: Codable, Hashable {
        var day: Int
        var reference: String     // e.g. "Genesis 1-3"
        var prompt: String = ""
    }

    var totalDays: Int { entries.count }
}
