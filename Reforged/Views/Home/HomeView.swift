import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var streakManager = ReadingStreakManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation

    var body: some View {
        ZStack {
            Group {
                if isSidebarNavigation {
                    // iPad/Mac: No NavigationStack needed (provided by parent)
                    homeContent
                } else {
                    NavigationStack {
                        homeContent
                            .navigationTitle("Reforged")
                            .navigationBarTitleDisplayMode(.large)
                    }
                }
            }

            // XP Gain Notification
            VStack {
                Spacer()
                XPGainView(
                    amount: appState.lastXPGain,
                    source: appState.lastXPSource,
                    isPresented: $appState.showXPGain
                )
                .padding(.bottom, 120)
            }

            // Level Up Celebration
            LevelUpView(
                newLevel: appState.newLevel,
                isPresented: $appState.showLevelUp
            )

            // Streak Milestone Celebration
            StreakMilestoneView(
                streakCount: streakManager.milestoneDays,
                isPresented: $streakManager.showMilestoneCelebration
            )

            // Badge Earned Celebration
            if let badge = appState.earnedBadge {
                BadgeEarnedView(
                    badge: badge,
                    isPresented: $appState.showBadgeEarned
                )
                .onChange(of: appState.showBadgeEarned) { showing in
                    if !showing {
                        appState.earnedBadge = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showXPGain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showLevelUp)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streakManager.showMilestoneCelebration)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showBadgeEarned)
    }

    var homeContent: some View {
        ScrollView {
            VStack(spacing: ReforgedTheme.spacingL) {
                // Welcome Header
                WelcomeHeader()

                // Stats Cards - Responsive layout
                StatsSection()

                // iPad/Mac: Two-column layout for middle content
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: ReforgedTheme.spacingL) {
                        // Left column
                        VStack(spacing: ReforgedTheme.spacingL) {
                            DailyInsightCard()
                        }
                        .frame(maxWidth: .infinity)

                        // Right column
                        VStack(spacing: ReforgedTheme.spacingL) {
                            ReviewDueSection()
                            QuickActionsSection()
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // iPhone: Single column
                    DailyInsightCard()

                    // MARK: - Continue Learning (Hidden until devotional tracks are ready)
                    // ContinueLearningSection()

                    ReviewDueSection()
                    QuickActionsSection()
                }
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
            .frame(maxWidth: horizontalSizeClass == .regular ? 1200 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }
}

// MARK: - Welcome Header (Hero Style)

struct WelcomeHeader: View {
    @EnvironmentObject var appState: AppState

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.8))

                    Text(appState.user.displayName.isEmpty ? "Friend" : appState.user.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(appState.user.avatar)
                    .font(.system(size: 44))
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Text("Your daily journey in God's Word awaits")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(ReforgedTheme.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard()
    }
}

// MARK: - Stats Section (Gamified Cards)

struct StatsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Streak Card with flame - now uses ReadingStreakManager
            StreakCard()

            // XP/Level Card
            LevelCard(xp: appState.user.xp)
        }
    }
}

struct StreakCard: View {
    @StateObject private var streakManager = ReadingStreakManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showCalendar = false
    @State private var showShareStreak = false
    @State private var showBuyFreezeAlert = false

    var streak: Int {
        streakManager.currentStreak
    }

    var nextMilestone: Int {
        let milestones = [7, 14, 30, 60, 90, 180, 365]
        return milestones.first(where: { $0 > streak }) ?? 365
    }

    var progress: Double {
        let prev = [0, 7, 14, 30, 60, 90, 180].last(where: { $0 < nextMilestone }) ?? 0
        guard nextMilestone > prev else { return 1 }
        return Double(streak - prev) / Double(nextMilestone - prev)
    }

    var body: some View {
        Button {
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(Color.reforgedCoral)

                    Spacer()

                    Button {
                        showShareStreak = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(.trailing, 4)

                    Text("\(streak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                HStack(spacing: 4) {
                    Text("Daily Streak")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                // Progress to next milestone
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.reforgedCoral.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.reforgedCoral)
                                .frame(width: geo.size.width * max(0, min(1, progress)))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        if streakManager.hasReadToday {
                            Text("Read today! \(nextMilestone - streak) to \(nextMilestone)-day")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.reforgedCoral)
                        } else {
                            Text("Read a chapter to keep your streak!")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()

                        // Streak freezes indicator
                        Button {
                            showBuyFreezeAlert = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 10))
                                Text("\(appState.user.streakFreezes)")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Color.blue.opacity(0.7))
                        }
                    }
                }
            }
            .padding(ReforgedTheme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gamifiedStatCard(accent: .reforgedCoral)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCalendar) {
            ReadingCalendarView()
        }
        .sheet(isPresented: $showShareStreak) {
            StreakShareSheet()
        }
        .alert("Buy Streak Freeze", isPresented: $showBuyFreezeAlert) {
            Button("Buy for \(appState.freezePurchaseCost) XP") {
                if appState.purchaseStreakFreeze() {
                    HapticManager.shared.lightImpact()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(appState.user.streakFreezes) freezes. Spend \(appState.freezePurchaseCost) XP to buy another? (You have \(appState.user.xp) XP)")
        }
    }
}

// MARK: - Reading Calendar View

struct ReadingCalendarView: View {
    @StateObject private var streakManager = ReadingStreakManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var currentMonth = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak Stats
                    HStack(spacing: 16) {
                        StatBox(
                            title: "Current",
                            value: "\(streakManager.currentStreak)",
                            subtitle: "days",
                            color: .reforgedCoral
                        )

                        StatBox(
                            title: "Longest",
                            value: "\(streakManager.longestStreak)",
                            subtitle: "days",
                            color: .reforgedGold
                        )

                        StatBox(
                            title: "This Month",
                            value: "\(daysReadThisMonth)",
                            subtitle: "days",
                            color: .reforgedNavy
                        )
                    }
                    .padding(.horizontal)

                    // Calendar
                    VStack(spacing: 16) {
                        // Month Navigation
                        HStack {
                            Button {
                                withAnimation {
                                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            Spacer()

                            Text(monthYearString)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Spacer()

                            Button {
                                withAnimation {
                                    let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                    if nextMonth <= Date() {
                                        currentMonth = nextMonth
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundStyle(canGoForward ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                            }
                            .disabled(!canGoForward)
                        }
                        .padding(.horizontal)

                        // Days of week header
                        HStack(spacing: 0) {
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Calendar Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(daysInMonth, id: \.self) { date in
                                if let date = date {
                                    CalendarDayCell(
                                        date: date,
                                        isToday: calendar.isDateInToday(date),
                                        didRead: streakManager.didRead(on: date),
                                        chaptersRead: streakManager.chaptersRead(on: date)
                                    )
                                } else {
                                    Color.clear
                                        .frame(height: 44)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Legend
                    HStack(spacing: 20) {
                        LegendItem(color: .reforgedCoral, label: "Chapter read")
                        LegendItem(color: .clear, borderColor: .reforgedCoral, label: "Today")
                    }
                    .padding(.horizontal)

                    // Encouragement message
                    if !streakManager.hasReadToday {
                        VStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                            Text("Read a chapter today to keep your streak going!")
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.reforgedNavy.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Reading Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
        }
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        return nextMonth <= Date()
    }

    var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        return days
    }

    var daysReadThisMonth: Int {
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        return streakManager.readingDates.filter { dateString in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateString) else { return false }
            let components = calendar.dateComponents([.year, .month], from: date)
            return components.year == currentComponents.year && components.month == currentComponents.month
        }.count
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let didRead: Bool
    let chaptersRead: [String]
    @Environment(\.colorScheme) var colorScheme
    @State private var showChapters = false

    private let calendar = Calendar.current

    var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    var isFutureDate: Bool {
        date > Date()
    }

    var body: some View {
        Button {
            if !chaptersRead.isEmpty {
                showChapters = true
            }
        } label: {
            ZStack {
                if didRead {
                    Circle()
                        .fill(Color.reforgedCoral)
                }

                if isToday {
                    Circle()
                        .stroke(Color.reforgedCoral, lineWidth: 2)
                }

                Text("\(dayNumber)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(
                        didRead ? .white :
                        isFutureDate ? Color.adaptiveTextSecondary(colorScheme).opacity(0.3) :
                        Color.adaptiveText(colorScheme)
                    )
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(chaptersRead.isEmpty)
        .popover(isPresented: $showChapters) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chapters Read")
                    .font(.headline)
                    .padding(.bottom, 4)

                ForEach(chaptersRead, id: \.self) { chapter in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.reforgedCoral)
                        Text(chapter)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
        }
    }
}

struct LegendItem: View {
    let color: Color
    var borderColor: Color? = nil
    let label: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)

                if let border = borderColor {
                    Circle()
                        .stroke(border, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }
}

struct LevelCard: View {
    let xp: Int
    @Environment(\.colorScheme) var colorScheme

    var levelInfo: LevelInfo {
        SampleData.getLevelInfo(xp: xp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(Color.reforgedGold)

                Spacer()

                Text("Lv.\(levelInfo.level)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Text(levelInfo.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            // XP Progress
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.reforgedGold.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.reforgedGold)
                            .frame(width: geo.size.width * levelInfo.progress)
                    }
                }
                .frame(height: 6)

                Text("\(levelInfo.xpInLevel) / \(levelInfo.xpForNextLevel) XP")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(ReforgedTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamifiedStatCard(accent: .reforgedGold)
    }
}

// MARK: - Daily Insight Card

struct DailyInsightCard: View {
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Insight")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()
            }

            if let insight = appState.dailyInsight {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(insight.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)

                    // Verse quote with decorative styling
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\"\(insight.verseText)\"")
                            .font(.body)
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(isExpanded ? nil : 3)

                        Button {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToBibleVerse"),
                                object: nil,
                                userInfo: ["reference": insight.verse]
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Text("— \(insight.verse)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.caption)
                            }
                            .foregroundStyle(Color.reforgedGold)
                        }
                    }
                    .padding(ReforgedTheme.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))

                    // Expand button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(isExpanded ? "Show less" : "Read more")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .tint(Color.reforgedGold)
                    Text("Loading today's insight...")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
        }
        .padding(ReforgedTheme.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reforgedCard(elevated: true)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Continue Learning Section

struct ContinueLearningSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var nextLesson: (track: Track, lesson: Lesson)? {
        for track in appState.tracks {
            if let lesson = track.lessons.first(where: { !$0.isCompleted }) {
                return (track, lesson)
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue Learning")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                NavigationLink(destination: TracksView()) {
                    Text("See all")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                }
            }

            if let next = nextLesson {
                NavigationLink(destination: LessonView(lesson: next.lesson)) {
                    HStack(spacing: 14) {
                        // Track icon with gradient background
                        ZStack {
                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.reforgedNavy, Color.reforgedDarkBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)

                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(next.track.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(next.lesson.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Label("+\(next.lesson.xpReward) XP", systemImage: "star.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.reforgedGold)
                            }
                        }

                        Spacer()

                        // Play button
                        ZStack {
                            Circle()
                                .fill(Color.reforgedNavy)
                                .frame(width: 40, height: 40)

                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(ReforgedTheme.spacingM)
                    .reforgedCard(elevated: true)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.reforgedGold)

                    Text("All caught up!")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Start a new track to keep learning")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(ReforgedTheme.spacingL)
                .frame(maxWidth: .infinity)
                .reforgedCard()
            }
        }
    }
}

// MARK: - Review Due Section

struct ReviewDueSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var versesForReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    var body: some View {
        if !versesForReview.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Verses Due for Review")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    Text("\(versesForReview.count) due")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.reforgedCoral)
                        .clipShape(Capsule())
                }

                NavigationLink(destination: MemoryReviewView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                .fill(Color.reforgedCoral.opacity(0.12))
                                .frame(width: 56, height: 56)

                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundStyle(Color.reforgedCoral)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(versesForReview.first?.reference ?? "")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("Tap to start review session")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.reforgedCoral)
                                .frame(width: 40, height: 40)

                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(ReforgedTheme.spacingM)
                    .gamifiedStatCard(accent: .reforgedCoral)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad/Mac: Can show more items or larger buttons
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            LazyVGrid(columns: columns, spacing: 12) {
                QuickActionButton(
                    icon: "book.fill",
                    label: "Read Bible",
                    color: .reforgedNavy,
                    destination: AnyView(BibleView())
                )

                QuickActionButton(
                    icon: "brain.head.profile",
                    label: "Practice",
                    color: .reforgedCoral,
                    destination: AnyView(MemoryView())
                )

                QuickActionButton(
                    icon: "pencil.line",
                    label: "Journal",
                    color: .reforgedGold,
                    destination: AnyView(JournalView())
                )
            }
        }
    }
}

struct QuickActionButton<Destination: View>: View {
    let icon: String
    let label: String
    let color: Color
    let destination: Destination
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .reforgedCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
}
