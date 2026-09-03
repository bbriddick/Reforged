import Foundation
import WidgetKit

/// The kinds of activity that satisfy a day's streak.
/// Any one of these on a given day keeps the streak alive.
enum StreakActivity: String, Codable, CaseIterable {
    case reading
    case memory
    case lesson

    var displayName: String {
        switch self {
        case .reading: return "Bible reading"
        case .memory:  return "Memory review"
        case .lesson:  return "Lesson"
        }
    }

    var iconName: String {
        switch self {
        case .reading: return "book.fill"
        case .memory:  return "brain.head.profile"
        case .lesson:  return "graduationcap.fill"
        }
    }

    /// Maps an `AppState.addXP` source to the activity that satisfies the day.
    ///
    /// Returns nil for sources that earn XP without counting toward the streak
    /// (journal reflections), so the streak stays tied to the three core
    /// disciplines. New XP sources default to not counting — add them here
    /// deliberately.
    static func forXPSource(_ source: String) -> StreakActivity? {
        switch source {
        case "chapter":
            return .reading
        case "lesson":
            return .lesson
        case "review", "review-complete", "practice", "deep drill",
             "matching_game", "complete_verse_quiz", "collection_practice":
            return .memory
        default:
            return nil
        }
    }
}

/// Single source of truth for the daily streak.
///
/// A day counts if the user did any `StreakActivity` on it, or if a streak freeze
/// covered it. `AppState.user.streak` is a mirror of `currentStreak` kept only so the
/// value can round-trip through CloudKit/Supabase — never write to it directly.
class ReadingStreakManager: ObservableObject {
    static let shared = ReadingStreakManager()

    private let userDefaults = UserDefaults.standard
    private let sharedDefaults = UserDefaults(suiteName: "group.com.reforged.app")
    private let readingDatesKey = "reforged_reading_dates"
    private let activityDatesKey = "reforged_streak_dates"
    private let chaptersReadByDateKey = "reforged_chapters_read_by_date"
    private let frozenDatesKey = "reforged_frozen_dates"
    private let activityKindsKey = "reforged_streak_kinds_by_date"

    /// Dates when the user read at least one chapter (ISO date strings YYYY-MM-DD).
    /// A subset of `activityDates`, retained for the calendar's chapter detail.
    @Published var readingDates: Set<String> = []

    /// Dates when the user did *any* qualifying activity. Drives the streak.
    @Published var activityDates: Set<String> = []

    /// Which activity kinds happened on each date, for calendar/insight display.
    @Published var activityKindsByDate: [String: Set<StreakActivity>] = [:]

    /// Dates that were covered by a streak freeze (not active, but protected).
    @Published var frozenDates: Set<String> = []

    /// Chapters read by date (date string -> chapter keys like "John 3").
    @Published var chaptersReadByDate: [String: [String]] = [:]

    /// Set when a milestone is reached, for triggering celebration.
    @Published var showMilestoneCelebration = false
    @Published var milestoneDays: Int = 0

    /// Set when the user completes a full 7-day week.
    @Published var showPerfectWeekCelebration = false

    /// Streak lengths worth celebrating. 365 is the Streak Society threshold.
    static let milestones: [Int] = [7, 14, 21, 30, 50, 100, 150, 200, 250, 300, 365, 500, 730, 1000]

    /// The streak length at which a user joins the Streak Society.
    static let streakSocietyThreshold = 365

    private let calendar = Calendar.current

    private init() {
        loadFromStorage()
        migrateReadingDatesIntoActivityIfNeeded()
    }

    // MARK: - Reading the streak

    /// Consecutive days of activity, including today's grace period.
    var currentStreak: Int {
        calculateCurrentStreak()
    }

    /// Longest streak ever achieved.
    var longestStreak: Int {
        get { userDefaults.integer(forKey: "reforged_longest_reading_streak") }
        set { userDefaults.set(newValue, forKey: "reforged_longest_reading_streak") }
    }

    /// True once the user's streak has ever reached a full year.
    var isInStreakSociety: Bool {
        longestStreak >= Self.streakSocietyThreshold
    }

    /// Whether today's streak requirement is already satisfied.
    var hasActivityToday: Bool {
        activityDates.contains(todayString)
    }

    /// Whether a chapter specifically was read today.
    var hasReadToday: Bool {
        readingDates.contains(todayString)
    }

    /// The day's goal: two distinct disciplines — a chapter and a verse review,
    /// or any other two. The streak only asks for one; this is the fuller day.
    static let dailyActivityGoal = 2

    /// Distinct disciplines done today. Lives here rather than on `activityKinds(on:)`
    /// because `todayString` is the only correct boundary — it honours
    /// settings.dayStartHour, which the date-keyed lookup does not.
    var todayActivityKinds: Set<StreakActivity> {
        activityKindsByDate[todayString] ?? []
    }

    /// True once the day's two disciplines are done.
    var isDailyGoalMet: Bool {
        todayActivityKinds.count >= Self.dailyActivityGoal
    }

    /// True when the streak is alive but today is not yet satisfied — the
    /// "at risk" state that drives the evening reminder and the Home card's urgency.
    var isStreakAtRisk: Bool {
        currentStreak > 0 && !hasActivityToday
    }

    /// The next milestone above the current streak, or nil past the last one.
    var nextMilestone: Int? {
        Self.milestones.first { $0 > currentStreak }
    }

    // MARK: - Recording activity

    /// Record that a chapter was read. Satisfies the day and logs the chapter.
    func recordChapterRead(book: String, chapter: Int) {
        let today = todayString
        let chapterKey = "\(book) \(chapter)"

        var chaptersForToday = chaptersReadByDate[today] ?? []
        if !chaptersForToday.contains(chapterKey) {
            chaptersForToday.append(chapterKey)
            chaptersReadByDate[today] = chaptersForToday
        }
        readingDates.insert(today)

        recordActivity(.reading)
    }

    /// Record any qualifying activity for today. Idempotent within a day.
    func recordActivity(_ kind: StreakActivity) {
        let today = todayString
        let previousStreak = calculateCurrentStreak()
        let wasAlreadyActive = activityDates.contains(today)

        activityDates.insert(today)
        activityKindsByDate[today, default: []].insert(kind)

        let current = calculateCurrentStreak()
        if current > longestStreak {
            longestStreak = current
        }

        // Celebrate only when this is the action that extended the streak, so a
        // second chapter on a milestone day doesn't re-fire the celebration.
        if !wasAlreadyActive && current > previousStreak {
            if Self.milestones.contains(current) {
                milestoneDays = current
                showMilestoneCelebration = true
            }
            if isPerfectWeek() {
                showPerfectWeekCelebration = true
            }
        }

        saveToStorage()
        objectWillChange.send()
    }

    // MARK: - Freezes

    /// The consecutive uncovered days between the last covered day and today.
    ///
    /// Today is excluded — it isn't missed until it's over. Returns [] when the
    /// streak is intact, and the days needing protection (oldest first) otherwise.
    /// Capped at `maxLookback` so a user returning after months doesn't get a
    /// pathological list.
    func missedDaysNeedingFreeze(maxLookback: Int = 30) -> [String] {
        guard let todayDate = stringToDate(todayString) else { return [] }
        let covered = coveredDates

        var missed: [String] = []
        for offset in 1...maxLookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayDate) else { break }
            let key = dateToString(day)
            if covered.contains(key) {
                // Found the last active day — everything after it is the gap.
                return missed.reversed()
            }
            missed.append(key)
        }
        // No covered day within the lookback: there is no streak left to protect.
        return []
    }

    /// Records that a streak freeze protected the given date.
    func noteFreezeUsed(on dateString: String) {
        frozenDates.insert(dateString)
        saveToStorage()
        objectWillChange.send()
    }

    /// Whether a freeze covered a given date, for the calendar's freeze marker.
    func wasFrozen(on date: Date) -> Bool {
        frozenDates.contains(dateToString(date))
    }

    // MARK: - Weekly goal

    /// The seven dates of the current week, Sunday-first, for the Home strip.
    func currentWeekDates() -> [Date] {
        guard let todayDate = stringToDate(todayString),
              let interval = calendar.dateInterval(of: .weekOfYear, for: todayDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// How many days of the current week are satisfied.
    func daysActiveThisWeek() -> Int {
        currentWeekDates().filter { coveredDates.contains(dateToString($0)) }.count
    }

    /// True when every day of the current week up to today is covered and today is done.
    private func isPerfectWeek() -> Bool {
        guard let todayDate = stringToDate(todayString) else { return false }
        let week = currentWeekDates().filter { $0 <= todayDate }
        guard week.count == 7 else { return false }
        return week.allSatisfy { coveredDates.contains(dateToString($0)) }
    }

    // MARK: - Queries

    func wasChapterRead(book: String, chapter: Int, on date: Date) -> Bool {
        chaptersReadByDate[dateToString(date)]?.contains("\(book) \(chapter)") ?? false
    }

    func chaptersRead(on date: Date) -> [String] {
        chaptersReadByDate[dateToString(date)] ?? []
    }

    /// Whether the given date counts toward the streak (activity or freeze).
    func didRead(on date: Date) -> Bool {
        coveredDates.contains(dateToString(date))
    }

    /// The activity kinds recorded on a date, for the calendar detail.
    func activityKinds(on date: Date) -> Set<StreakActivity> {
        activityKindsByDate[dateToString(date)] ?? []
    }

    /// Active dates within the given month, for the calendar grid.
    func readingDates(for month: Date) -> [Date] {
        let components = calendar.dateComponents([.year, .month], from: month)
        return activityDates.compactMap { dateString -> Date? in
            guard let date = stringToDate(dateString) else { return nil }
            let dateComponents = calendar.dateComponents([.year, .month], from: date)
            guard dateComponents.year == components.year,
                  dateComponents.month == components.month else { return nil }
            return date
        }
    }

    // MARK: - Streak math

    /// Days that keep the streak alive: any activity, or a freeze.
    private var coveredDates: Set<String> {
        activityDates.union(frozenDates)
    }

    private func calculateCurrentStreak() -> Int {
        let covered = coveredDates
        guard !covered.isEmpty, let todayDate = stringToDate(todayString) else { return 0 }

        // Today is a grace day: the streak survives until midnight even before
        // today's activity, so start the walk from yesterday when today is empty.
        var cursor = todayDate
        var streak = 0
        if covered.contains(dateToString(todayDate)) {
            streak = 1
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayDate),
                  covered.contains(dateToString(yesterday)) else { return 0 }
        }

        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor) {
            guard covered.contains(dateToString(previous)) else { break }
            streak += 1
            cursor = previous
        }
        return streak
    }

    // MARK: - Seeding & migration

    /// Back-fills history so the computed streak is at least `count`.
    ///
    /// Used when a synced or previously-mirrored streak claims more days than local
    /// history can prove — on a fresh install (no history at all), or after the
    /// unification, where the old activity-based counter may have outrun the
    /// reading-date log. We trust the higher number rather than take a streak away
    /// from someone who earned it under the old rules.
    func seedStreak(count: Int) {
        guard count > 0, count > calculateCurrentStreak() else { return }
        guard let today = stringToDate(todayString) else { return }

        // Walk back from the last covered day so the seeded block joins the
        // existing history into one unbroken run instead of leaving a hole.
        var anchor = today
        if !coveredDates.contains(dateToString(today)),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            anchor = yesterday
        }
        for offset in 0..<count {
            if let date = calendar.date(byAdding: .day, value: -offset, to: anchor) {
                activityDates.insert(dateToString(date))
            }
        }
        saveToStorage()
        objectWillChange.send()
    }

    /// Seeds historical freeze dates from `UserProfile.freezeUsedDates` on first
    /// launch / CloudKit restore so old freezes are honoured by the streak walk.
    func seedFrozenDates(_ dates: [String]) {
        guard !dates.isEmpty else { return }
        frozenDates.formUnion(dates)
        saveToStorage()
        objectWillChange.send()
    }

    /// Back-fills `activityDates` from the pre-unification `readingDates` so existing
    /// users keep every day they earned under the reading-only rule.
    private func migrateReadingDatesIntoActivityIfNeeded() {
        let migrationKey = "reforged_streak_unified_migration_v1"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        activityDates.formUnion(readingDates)
        for date in readingDates {
            activityKindsByDate[date, default: []].insert(.reading)
        }
        userDefaults.set(true, forKey: migrationKey)
        saveToStorage()
    }

    // MARK: - Date keys

    /// Today's key in the user's local timezone, honouring a custom day-start hour.
    /// Local (not UTC) by convention here — every key this class stores and reads
    /// must go through this path or lookups silently miss by a day.
    private var todayString: String {
        let dayStartHour = UserDefaults.standard.object(forKey: "settings.dayStartHour") as? Int ?? 0
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let logicalDate = (dayStartHour > 0 && currentHour < dayStartHour)
            ? (calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            : now
        return dateToString(logicalDate)
    }

    /// Exposed so callers outside this class can speak the same date keys.
    var currentDayKey: String { todayString }

    /// Yesterday's key in the same space as `currentDayKey`.
    var previousDayKey: String {
        guard let today = stringToDate(todayString),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return todayString }
        return dateToString(yesterday)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func dateToString(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func stringToDate(_ string: String) -> Date? {
        Self.dayFormatter.date(from: string)
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        if let dates = userDefaults.array(forKey: readingDatesKey) as? [String] {
            readingDates = Set(dates)
        }
        if let dates = userDefaults.array(forKey: activityDatesKey) as? [String] {
            activityDates = Set(dates)
        }
        if let dates = userDefaults.array(forKey: frozenDatesKey) as? [String] {
            frozenDates = Set(dates)
        }
        if let data = userDefaults.data(forKey: chaptersReadByDateKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            chaptersReadByDate = decoded
        }
        if let data = userDefaults.data(forKey: activityKindsKey),
           let decoded = try? JSONDecoder().decode([String: Set<StreakActivity>].self, from: data) {
            activityKindsByDate = decoded
        }
    }

    private func saveToStorage() {
        userDefaults.set(Array(readingDates), forKey: readingDatesKey)
        userDefaults.set(Array(activityDates), forKey: activityDatesKey)
        userDefaults.set(Array(frozenDates), forKey: frozenDatesKey)

        // The widget reads these three from the App Group.
        sharedDefaults?.set(Array(readingDates), forKey: readingDatesKey)
        sharedDefaults?.set(Array(activityDates), forKey: activityDatesKey)
        sharedDefaults?.set(Array(frozenDates), forKey: frozenDatesKey)

        if let data = try? JSONEncoder().encode(chaptersReadByDate) {
            userDefaults.set(data, forKey: chaptersReadByDateKey)
            sharedDefaults?.set(data, forKey: chaptersReadByDateKey)
        }
        if let data = try? JSONEncoder().encode(activityKindsByDate) {
            userDefaults.set(data, forKey: activityKindsKey)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingStreakWidget")
    }
}
