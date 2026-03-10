import Foundation
import WidgetKit

/// Manages daily reading streak tracking
/// Tracks which days the user logged in and read a chapter
class ReadingStreakManager: ObservableObject {
    static let shared = ReadingStreakManager()

    private let userDefaults = UserDefaults.standard
    private let sharedDefaults = UserDefaults(suiteName: "group.com.reforged.app")
    private let readingDatesKey = "reforged_reading_dates"
    private let chaptersReadByDateKey = "reforged_chapters_read_by_date"

    /// Dates when user read at least one chapter (stored as ISO date strings YYYY-MM-DD)
    @Published var readingDates: Set<String> = []

    /// Chapters read by date (date string -> array of chapter keys like "John 3")
    @Published var chaptersReadByDate: [String: [String]] = [:]

    /// Whether a milestone was just reached (for triggering celebration)
    @Published var showMilestoneCelebration = false
    @Published var milestoneDays: Int = 0

    /// Milestone streak values to celebrate
    private let milestones: Set<Int> = [7, 14, 21, 30, 50, 100, 150, 200, 250, 300, 365]

    private init() {
        loadFromStorage()
    }

    // MARK: - Public Interface

    /// Current streak (consecutive days of reading)
    var currentStreak: Int {
        calculateCurrentStreak()
    }

    /// Longest streak ever achieved
    var longestStreak: Int {
        get {
            userDefaults.integer(forKey: "reforged_longest_reading_streak")
        }
        set {
            userDefaults.set(newValue, forKey: "reforged_longest_reading_streak")
        }
    }

    /// Check if user has read today
    var hasReadToday: Bool {
        readingDates.contains(todayString)
    }

    /// Record that a chapter was read
    func recordChapterRead(book: String, chapter: Int) {
        let today = todayString
        let chapterKey = "\(book) \(chapter)"
        let previousStreak = calculateCurrentStreak()

        // Add to reading dates
        let isFirstReadToday = !readingDates.contains(today)
        readingDates.insert(today)

        // Add to chapters read by date
        var chaptersForToday = chaptersReadByDate[today] ?? []
        if !chaptersForToday.contains(chapterKey) {
            chaptersForToday.append(chapterKey)
            chaptersReadByDate[today] = chaptersForToday
        }

        // Update longest streak if needed
        let current = calculateCurrentStreak()
        if current > longestStreak {
            longestStreak = current
        }

        // Check for milestone celebration (only if this extended the streak)
        if isFirstReadToday && current > previousStreak && milestones.contains(current) {
            milestoneDays = current
            showMilestoneCelebration = true
        }

        saveToStorage()
        objectWillChange.send()
    }

    /// Check if a specific chapter was read on a specific date
    func wasChapterRead(book: String, chapter: Int, on date: Date) -> Bool {
        let dateString = dateToString(date)
        let chapterKey = "\(book) \(chapter)"
        return chaptersReadByDate[dateString]?.contains(chapterKey) ?? false
    }

    /// Get all chapters read on a specific date
    func chaptersRead(on date: Date) -> [String] {
        let dateString = dateToString(date)
        return chaptersReadByDate[dateString] ?? []
    }

    /// Check if user read on a specific date
    func didRead(on date: Date) -> Bool {
        readingDates.contains(dateToString(date))
    }

    /// Get reading dates for a specific month
    func readingDates(for month: Date) -> [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)

        return readingDates.compactMap { dateString -> Date? in
            guard let date = stringToDate(dateString) else { return nil }
            let dateComponents = calendar.dateComponents([.year, .month], from: date)
            if dateComponents.year == components.year && dateComponents.month == components.month {
                return date
            }
            return nil
        }
    }

    // MARK: - Private Helpers

    private var todayString: String {
        let dayStartHour = UserDefaults.standard.object(forKey: "settings.dayStartHour") as? Int ?? 0
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let logicalDate: Date
        if dayStartHour > 0 && currentHour < dayStartHour {
            logicalDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else {
            logicalDate = now
        }
        return String(ISO8601DateFormatter().string(from: logicalDate).prefix(10))
    }

    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func stringToDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func calculateCurrentStreak() -> Int {
        guard !readingDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Check if today counts
        if readingDates.contains(dateToString(currentDate)) {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // Count consecutive days backwards
        while readingDates.contains(dateToString(currentDate)) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // If user hasn't read today, check if yesterday was the last day
        // (streak is still valid until end of today)
        if streak == 0 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            if readingDates.contains(dateToString(yesterday)) {
                // Yesterday was a reading day, but today isn't yet
                // The streak is still active
                currentDate = yesterday
                while readingDates.contains(dateToString(currentDate)) {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                }
            }
        }

        return streak
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        if let dates = userDefaults.array(forKey: readingDatesKey) as? [String] {
            readingDates = Set(dates)
        }

        if let data = userDefaults.data(forKey: chaptersReadByDateKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            chaptersReadByDate = decoded
        }
    }

    private func saveToStorage() {
        let datesArray = Array(readingDates)
        userDefaults.set(datesArray, forKey: readingDatesKey)

        // Also save to shared defaults for widget access
        sharedDefaults?.set(datesArray, forKey: readingDatesKey)

        if let data = try? JSONEncoder().encode(chaptersReadByDate) {
            userDefaults.set(data, forKey: chaptersReadByDateKey)
            sharedDefaults?.set(data, forKey: chaptersReadByDateKey)
        }

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingStreakWidget")
    }
}
