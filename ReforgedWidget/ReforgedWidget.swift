import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct ReadingStreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let hasReadToday: Bool
    let readingDates: Set<String>
}

// MARK: - Timeline Provider

struct ReadingStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingStreakEntry {
        ReadingStreakEntry(
            date: Date(),
            currentStreak: 7,
            hasReadToday: true,
            readingDates: sampleReadingDates()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStreakEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingStreakEntry>) -> Void) {
        let entry = loadEntry()

        // Update at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func loadEntry() -> ReadingStreakEntry {
        // Load from shared UserDefaults (App Group)
        let userDefaults = UserDefaults(suiteName: "group.com.reforged.app") ?? UserDefaults.standard

        let readingDatesArray = userDefaults.array(forKey: "reforged_reading_dates") as? [String] ?? []
        let readingDates = Set(readingDatesArray)

        let currentStreak = calculateStreak(from: readingDates)
        let hasReadToday = readingDates.contains(todayString())

        return ReadingStreakEntry(
            date: Date(),
            currentStreak: currentStreak,
            hasReadToday: hasReadToday,
            readingDates: readingDates
        )
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func calculateStreak(from readingDates: Set<String>) -> Int {
        guard !readingDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Check if today counts
        if readingDates.contains(formatter.string(from: currentDate)) {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // Count consecutive days backwards
        while readingDates.contains(formatter.string(from: currentDate)) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // If user hasn't read today, check if yesterday was the last day
        if streak == 0 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            if readingDates.contains(formatter.string(from: yesterday)) {
                currentDate = yesterday
                while readingDates.contains(formatter.string(from: currentDate)) {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                }
            }
        }

        return streak
    }

    private func sampleReadingDates() -> Set<String> {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var dates: Set<String> = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                dates.insert(formatter.string(from: date))
            }
        }
        return dates
    }
}

// MARK: - Widget Views

struct MiniCalendarView: View {
    let readingDates: Set<String>
    let currentMonth: Date

    private let calendar = Calendar.current
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 2) {
            // Day of week headers
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    Text(dayLetters[index])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
            }

            // Calendar grid
            let days = daysInMonth()
            let firstWeekday = firstDayOfMonthWeekday()

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 2), count: 7), spacing: 2) {
                // Empty cells for days before the first of the month
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(width: 16, height: 16)
                }

                // Days of the month
                ForEach(1...days, id: \.self) { day in
                    DayDotView(
                        day: day,
                        hasRead: hasReadOnDay(day),
                        isToday: isToday(day)
                    )
                }
            }
        }
    }

    private func daysInMonth() -> Int {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        return range.count
    }

    private func firstDayOfMonthWeekday() -> Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let firstOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    private func hasReadOnDay(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dayComponents = components
        dayComponents.day = day
        guard let date = calendar.date(from: dayComponents) else { return false }
        return readingDates.contains(formatter.string(from: date))
    }

    private func isToday(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dayComponents = components
        dayComponents.day = day
        guard let date = calendar.date(from: dayComponents) else { return false }
        return calendar.isDateInToday(date)
    }
}

struct DayDotView: View {
    let day: Int
    let hasRead: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1)
                    .frame(width: 14, height: 14)
            }

            if hasRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct SmallWidgetView: View {
    let entry: ReadingStreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(entry.currentStreak > 0 ? .orange : .secondary)
                Text("\(entry.currentStreak)")
                    .font(.system(size: 24, weight: .bold))
                Text("day\(entry.currentStreak == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.hasReadToday ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(entry.hasReadToday ? "Read today" : "Read to continue")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini calendar (last 7 days)
            WeekDotsView(readingDates: entry.readingDates)
        }
        .padding()
    }
}

struct WeekDotsView: View {
    let readingDates: Set<String>

    private let calendar = Calendar.current
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: -(6 - offset), to: Date())!
                let dateString = formatter.string(from: date)
                let hasRead = readingDates.contains(dateString)
                let isToday = offset == 6

                VStack(spacing: 2) {
                    Text(dayLetter(for: date))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)

                    ZStack {
                        if isToday {
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 1)
                                .frame(width: 14, height: 14)
                        }

                        Circle()
                            .fill(hasRead ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: hasRead ? 10 : 6, height: hasRead ? 10 : 6)
                    }
                    .frame(width: 16, height: 16)
                }
            }
        }
    }

    private func dayLetter(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return letters[weekday - 1]
    }
}

struct MediumWidgetView: View {
    let entry: ReadingStreakEntry

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Streak info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(entry.currentStreak > 0 ? .orange : .secondary)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("\(entry.currentStreak)")
                            .font(.system(size: 32, weight: .bold))
                        Text("day streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.hasReadToday ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(entry.hasReadToday ? "Read today" : "Read to continue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Right side - Mini calendar
            VStack(alignment: .leading, spacing: 4) {
                Text(monthFormatter.string(from: Date()))
                    .font(.caption)
                    .fontWeight(.semibold)

                MiniCalendarView(
                    readingDates: entry.readingDates,
                    currentMonth: Date()
                )
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let entry: ReadingStreakEntry

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Reading Streak")
                        .font(.headline)
                    Text(monthFormatter.string(from: Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(entry.currentStreak > 0 ? .orange : .secondary)
                    Text("\(entry.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.hasReadToday ? .green : .orange)
                    .frame(width: 10, height: 10)
                Text(entry.hasReadToday ? "You've read Scripture today!" : "Read today to continue your streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Large calendar
            LargeCalendarView(
                readingDates: entry.readingDates,
                currentMonth: Date()
            )
        }
        .padding()
    }
}

struct LargeCalendarView: View {
    let readingDates: Set<String>
    let currentMonth: Date

    private let calendar = Calendar.current
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 8) {
            // Day of week headers
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    Text(dayNames[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = daysInMonth()
            let firstWeekday = firstDayOfMonthWeekday()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Empty cells for days before the first of the month
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 28)
                }

                // Days of the month
                ForEach(1...days, id: \.self) { day in
                    LargeDayView(
                        day: day,
                        hasRead: hasReadOnDay(day),
                        isToday: isToday(day),
                        isFuture: isFuture(day)
                    )
                }
            }
        }
    }

    private func daysInMonth() -> Int {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        return range.count
    }

    private func firstDayOfMonthWeekday() -> Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let firstOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    private func hasReadOnDay(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dayComponents = components
        dayComponents.day = day
        guard let date = calendar.date(from: dayComponents) else { return false }
        return readingDates.contains(formatter.string(from: date))
    }

    private func isToday(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dayComponents = components
        dayComponents.day = day
        guard let date = calendar.date(from: dayComponents) else { return false }
        return calendar.isDateInToday(date)
    }

    private func isFuture(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dayComponents = components
        dayComponents.day = day
        guard let date = calendar.date(from: dayComponents) else { return false }
        return date > Date()
    }
}

struct LargeDayView: View {
    let day: Int
    let hasRead: Bool
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }

            if hasRead {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
            }

            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.caption)
                    .foregroundColor(isFuture ? Color.secondary.opacity(0.5) : Color.primary)

                if hasRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 28)
    }
}

// MARK: - Widget Entry View

struct ReadingStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ReadingStreakEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct ReadingStreakWidget: Widget {
    let kind: String = "ReadingStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingStreakProvider()) { entry in
            if #available(iOS 17.0, *) {
                ReadingStreakWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ReadingStreakWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName("Reading Streak")
        .description("Track your daily Bible reading streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct ReforgedWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadingStreakWidget()
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    ReadingStreakWidget()
} timeline: {
    ReadingStreakEntry(
        date: Date(),
        currentStreak: 7,
        hasReadToday: true,
        readingDates: sampleDates()
    )
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    ReadingStreakWidget()
} timeline: {
    ReadingStreakEntry(
        date: Date(),
        currentStreak: 14,
        hasReadToday: false,
        readingDates: sampleDates()
    )
}

@available(iOS 17.0, *)
#Preview("Large", as: .systemLarge) {
    ReadingStreakWidget()
} timeline: {
    ReadingStreakEntry(
        date: Date(),
        currentStreak: 21,
        hasReadToday: true,
        readingDates: sampleDates()
    )
}

private func sampleDates() -> Set<String> {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"

    var dates: Set<String> = []
    for i in 0..<21 {
        if i % 3 != 2 { // Skip every 3rd day for variety
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                dates.insert(formatter.string(from: date))
            }
        }
    }
    return dates
}
