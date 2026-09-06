import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation
    @StateObject private var searchModel = HomeSearchModel()
    @State private var searchText = ""
    /// Measured content width (after the 1200pt cap), used to pick the iPad
    /// dashboard's column count. Read from a background GeometryReader rather than
    /// horizontalSizeClass, so a narrow iPad split view still lays out sensibly.
    @State private var dashboardWidth: CGFloat = 0

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Reward overlays are not here — they're attached once at the root in
    // ContentView (`.celebrationOverlay()`), so XP earned in the Bible reader or a
    // lesson celebrates where it was earned instead of only over Home.
    var body: some View {
        Group {
            if isSidebarNavigation {
                // iPad/Mac: No NavigationStack needed (provided by parent)
                homeContent
            } else {
                NavigationStack {
                    homeContent
                        .navigationTitle("Reforged")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { profileToolbarItem }
                }
            }
        }
    }

    /// The account button — top-trailing of the Home nav bar, the same place App
    /// Store, Music, and Fitness put it. This is Profile's only entry point on
    /// iPhone, which has no Profile tab (iPad reaches it from the sidebar).
    ///
    /// On iOS 26 the toolbar wraps each item in a Liquid Glass capsule, which reads
    /// as a grey blob around an avatar that already draws its own ring — so the
    /// shared background is hidden and the avatar sits directly on the bar.
    @ToolbarContentBuilder
    private var profileToolbarItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                profileToolbarButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                profileToolbarButton
            }
        }
    }

    private var profileToolbarButton: some View {
        NavigationLink {
            ProfileView(embedsNavigationStack: false)
                .environmentObject(appState)
        } label: {
            ProfileAvatarView(size: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityHint("Your profile, badges, and app settings")
    }

    var homeContent: some View {
        ZStack {
            homeScroll

            if isSearchActive {
                HomeSearchResultsView(query: searchText, model: searchModel)
                    .environmentObject(appState)
            }
        }
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search Scripture, topics, words…")
        .onChange(of: searchText) { query in
            if query.isEmpty { searchModel.invalidateJournalCache() }
            searchModel.updateLocal(query: query, appState: appState)
        }
        .onSubmit(of: .search) {
            searchModel.runDeepSearch(query: searchText)
        }
    }

    // Ordered by what the screen is asking of the reader, not by card size:
    // the hero names the one thing to do, DueTodaySection lists what's actually
    // outstanding, the stat cards report where that leaves them, and everything
    // below is optional — devotional reading, then browsing, then utilities.
    private var homeScroll: some View {
        ScrollView {
            VStack(spacing: ReforgedTheme.spacingL) {
                // iPad/Mac: a command band (hero + key stats) over an adaptive
                // multi-column dashboard that fills the width. iPhone keeps the
                // single-column stack with the hero on top.
                if horizontalSizeClass == .regular {
                    iPadDashboard
                } else {
                    WelcomeHeader()
                    DueTodaySection()
                    StatsSection()
                    DailyInsightCard()
                    ContinueLearningSection()
                    QuickActionsSection()
                    BibleProgressCard()
                    ShareGospelCard()
                }

                BuyMeACoffeeButton()
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
            .frame(maxWidth: horizontalSizeClass == .regular ? 1200 : .infinity)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DashboardWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(DashboardWidthKey.self) { dashboardWidth = $0 }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    /// 3 columns on a full-screen iPad/Mac, 2 on a narrower regular width (portrait
    /// or split view), 1 as a safety net. Thresholds are content width after the cap.
    private var dashboardColumnCount: Int {
        if dashboardWidth >= 1040 { return 3 }
        if dashboardWidth >= 680 { return 2 }
        return 1
    }

    /// The iPad/Mac home layout: a command band over a balanced card grid.
    ///
    /// The band pairs the greeting/suggestion hero (primary, flexible width) with a
    /// fixed-width stats rail (streak + level), so the hero no longer trails a wide
    /// band of empty charcoal and the day's key numbers lead alongside the one thing
    /// to do. Below, the remaining cards flow into 2–3 natural-height columns; the
    /// actionable "Due Today" leads. Stat cards are kept out of the grid so their
    /// equal-height behavior never stretches a tall column into a near-empty tile.
    @ViewBuilder
    private var iPadDashboard: some View {
        let spacing = ReforgedTheme.spacingL
        VStack(spacing: spacing) {
            commandBand(spacing: spacing)
            dashboardGrid(spacing: spacing)
        }
    }

    /// Hero + key-stats band: side by side when there is room, stacked when narrow.
    /// The fixed 300pt rail is what reclaims the hero's former dead space on wide
    /// screens; below two columns it folds under the hero instead.
    @ViewBuilder
    private func commandBand(spacing: CGFloat) -> some View {
        if dashboardColumnCount >= 2 {
            HStack(alignment: .top, spacing: spacing) {
                WelcomeHeader()
                    .frame(maxWidth: .infinity)

                VStack(spacing: spacing) {
                    StreakCard()
                    LevelCard(xp: appState.user.xp)
                }
                .frame(width: 300)
            }
        } else {
            VStack(spacing: spacing) {
                WelcomeHeader()
                HStack(spacing: spacing) {
                    StreakCard()
                    LevelCard(xp: appState.user.xp)
                }
            }
        }
    }

    /// The remaining cards as a balanced, natural-height column grid. Assignment is
    /// curated (not measured): "Due Today" leads, devotional and browse content fill
    /// the rest, and columns are paired so their heights stay close.
    @ViewBuilder
    private func dashboardGrid(spacing: CGFloat) -> some View {
        switch dashboardColumnCount {
        case 3:
            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) {
                    DueTodaySection()
                    BibleProgressCard()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: spacing) {
                    DailyInsightCard()
                    ShareGospelCard()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: spacing) {
                    ContinueLearningSection()
                    QuickActionsSection()
                }
                .frame(maxWidth: .infinity)
            }
        case 2:
            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) {
                    DueTodaySection()
                    DailyInsightCard()
                    BibleProgressCard()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: spacing) {
                    ContinueLearningSection()
                    QuickActionsSection()
                    ShareGospelCard()
                }
                .frame(maxWidth: .infinity)
            }
        default:
            VStack(spacing: spacing) {
                DueTodaySection()
                DailyInsightCard()
                ContinueLearningSection()
                QuickActionsSection()
                BibleProgressCard()
                ShareGospelCard()
            }
        }
    }
}

/// Content width of the home stack, used to choose the iPad dashboard columns.
private struct DashboardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Bible Progress Card

struct BibleProgressCard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var chaptersReadCount: Int { appState.user.chaptersRead.count }
    private let totalChapters = 1189

    var body: some View {
        NavigationLink {
            BibleProgressView()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.adaptiveChipBackground(colorScheme))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("\(chaptersReadCount) of \(totalChapters) chapters read")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(14)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Due Today
//
// The reading plan and the verses waiting for review are the only two things on
// Home with a deadline, so they're one group directly under the hero rather than
// two unrelated cards spaced apart by the insight and lesson cards. Both rows are
// gated from here, which is also what keeps the VStack from reserving a spacing
// slot for a section that renders nothing.

struct DueTodaySection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var planService = ReadingPlanService.shared
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var streakManager = ReadingStreakManager.shared

    private var versesForReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    /// The pill tracks the day's two-discipline goal, not a count of the cards
    /// below. The reading plan is a self-paced queue with a next entry always
    /// waiting, so "items on screen" can't tell you whether the day is done —
    /// only the disciplines completed today can. (This is exactly the bug where
    /// the pill read "1 left" forever no matter how many chapters were marked.)
    private var goalDone: Int { min(streakManager.todayActivityKinds.count, ReadingStreakManager.dailyActivityGoal) }
    private var goalTotal: Int { ReadingStreakManager.dailyActivityGoal }

    var body: some View {
        if planService.activePlan != nil || !versesForReview.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Due Today")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    if streakManager.isDailyGoalMet {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done for today")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)
                    } else {
                        Text("\(goalDone) of \(goalTotal)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.reforgedCoral)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(goalDone) of \(goalTotal) daily disciplines done")
                    }
                }

                if let plan = planService.activePlan, let entry = planService.activeEntry {
                    TodayReadingCard(plan: plan, entry: entry)
                }

                if !versesForReview.isEmpty {
                    ReviewDueCard(verses: versesForReview)
                }
            }
        }
    }
}

// MARK: - Today's Reading Card

struct TodayReadingCard: View {
    let plan: BibleReadingPlan
    let entry: BiblePlanEntry

    @StateObject private var service = ReadingPlanService.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let isComplete = service.isDayComplete(entry.day, planId: plan.id)

        HStack(spacing: 14) {
            // Plan icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(plan.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: plan.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(plan.accentColor)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Reading")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(plan.accentColor)
                Text(entry.scriptureReference)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isComplete
                                     ? Color.adaptiveTextSecondary(colorScheme)
                                     : Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                Text("Day \(entry.day) · \(plan.name)")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Right action
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(plan.accentColor)
            } else if entry.isReflectionDay {
                Button {
                    service.toggleDay(entry.day, planId: plan.id)
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    openReading(entry: entry)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(plan.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(plan.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
    }

    private func openReading(entry: BiblePlanEntry) {
        guard let navRef = entry.navRef else { return }
        appState.queueBibleVerseNavigation(navRef)
        NotificationCenter.default.post(name: .switchTab, object: nil, userInfo: ["tab": 2])
    }
}

// MARK: - Buy Me a Coffee Button

struct BuyMeACoffeeButton: View {
    private let coffeeYellow = Color(red: 1.0, green: 0.867, blue: 0.0)
    private let supportURL = URL(string: "https://www.buymeacoffee.com/reforgedapp")

    var body: some View {
        Group {
            if let supportURL {
                Link(destination: supportURL) {
                    HStack(spacing: 10) {
                        Text("☕")
                            .font(.title3)
                        Text("Support Reforged")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(coffeeYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                EmptyView()
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - Welcome Header (Hero Style)
//
// Suggestion-first: the greeting is a single quiet line and the hero's real job
// is naming the ONE thing to do first (see HomeSuggestion). The suggestion
// re-rolls on every app open, so this is the screen's live entry point rather
// than a static banner. The avatar lives in the nav bar now — one account
// control, not two.

struct WelcomeHeader: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var streakManager = ReadingStreakManager.shared
    @StateObject private var gateService = UnlockGateService.shared
    @StateObject private var planService = ReadingPlanService.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var suggestion: HomeSuggestion = .readChapter
    @State private var showJournal = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.user.displayName.isEmpty ? "friend" : appState.user.displayName
        switch hour {
        case 0..<12:  return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default:      return "Good evening, \(name)"
        }
    }

    private var versesDue: Int {
        appState.memoryVerses.filter { $0.isDueForReview }.count
    }

    private func reroll() {
        suggestion = HomeSuggestion.pick(
            excluding: suggestion,
            hasReadToday: streakManager.hasReadToday,
            isDailyGoalMet: streakManager.isDailyGoalMet,
            versesDue: versesDue,
            hasAnyVerses: !appState.memoryVerses.isEmpty,
            isGateLocked: gateService.isGateActive
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.7))

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(suggestion.eyebrow)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.reforgedGold)

                    Text(suggestion.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(suggestion.detail)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.shared.buttonTap()
                switch suggestion.destination {
                case .tab(let index):
                    NotificationCenter.default.post(
                        name: .switchTab,
                        object: nil,
                        userInfo: [AppNotificationUserInfoKey.tab: index]
                    )
                case .journal:
                    showJournal = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text(suggestion.actionLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.reforgedCoral)
                .clipShape(Capsule())
            }
            .buttonStyle(NoBlobButtonStyle())
        }
        .padding(ReforgedTheme.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard()
        .animation(.easeInOut(duration: 0.25), value: suggestion)
        .navigationDestination(isPresented: $showJournal) { JournalView() }
        .onAppear { reroll() }
        .onChange(of: scenePhase) { phase in
            // "Every app open" — a fresh suggestion each time the app foregrounds.
            if phase == .active { reroll() }
        }
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

/// The seven days of the current week, marking which are already satisfied.
/// Duolingo's core "don't break the chain" affordance — the gap is the motivator.
struct WeekStreakStrip: View {
    @StateObject private var streakManager = ReadingStreakManager.shared
    let colorScheme: ColorScheme

    private static let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]
    private let calendar = Calendar.current

    var body: some View {
        let today = Date()
        HStack(spacing: 3) {
            ForEach(Array(streakManager.currentWeekDates().enumerated()), id: \.offset) { index, date in
                let isFuture = calendar.compare(date, to: today, toGranularity: .day) == .orderedDescending
                let isToday = calendar.isDate(date, inSameDayAs: today)
                let isDone = streakManager.didRead(on: date)
                let isFrozen = streakManager.wasFrozen(on: date)

                VStack(spacing: 2) {
                    Text(Self.weekdayInitials[index])
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    ZStack {
                        Circle()
                            .fill(fill(isDone: isDone, isFrozen: isFrozen, isFuture: isFuture))
                            .frame(width: 12, height: 12)

                        if isFrozen {
                            Image(systemName: "snowflake")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.reforgedCoral, lineWidth: isToday && !isDone ? 1.5 : 0)
                            .frame(width: 12, height: 12)
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(date: date, isDone: isDone, isFrozen: isFrozen))
            }
        }
    }

    private func fill(isDone: Bool, isFrozen: Bool, isFuture: Bool) -> Color {
        if isFrozen { return .blue.opacity(0.7) }
        if isDone { return .reforgedCoral }
        return Color.adaptiveTextSecondary(colorScheme).opacity(isFuture ? 0.12 : 0.25)
    }

    private func accessibilityLabel(date: Date, isDone: Bool, isFrozen: Bool) -> String {
        let day = date.formatted(.dateTime.weekday(.wide))
        if isFrozen { return "\(day): protected by a streak freeze" }
        return isDone ? "\(day): complete" : "\(day): not complete"
    }
}

struct StreakCard: View {
    @StateObject private var streakManager = ReadingStreakManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showCalendar = false
    @State private var showBuyFreezeAlert = false

    var streak: Int {
        streakManager.currentStreak
    }

    /// Sourced from the engine so the card and the celebration agree on what
    /// counts as a milestone.
    var nextMilestone: Int {
        streakManager.nextMilestone ?? ReadingStreakManager.milestones.last ?? 365
    }

    var progress: Double {
        guard streakManager.nextMilestone != nil else { return 1 }
        let previous = ReadingStreakManager.milestones.last(where: { $0 <= streak }) ?? 0
        guard nextMilestone > previous else { return 1 }
        return Double(streak - previous) / Double(nextMilestone - previous)
    }

    /// The streak is alive but today isn't satisfied yet — the flame goes cold
    /// to create the "don't lose it" pull.
    private var isAtRisk: Bool { streakManager.isStreakAtRisk }

    private var flameColor: Color {
        isAtRisk ? Color.adaptiveTextSecondary(colorScheme).opacity(0.5) : Color.reforgedCoral
    }

    var body: some View {
        Button {
            showCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(flameColor)

                    if streakManager.isInStreakSociety {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.reforgedGold)
                    }

                    Spacer()

                    Text("\(streak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                WeekStreakStrip(colorScheme: colorScheme)

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

                    HStack(alignment: .top, spacing: 6) {
                        if streakManager.hasActivityToday {
                            Text("Done today! \(nextMilestone - streak) days to \(nextMilestone)-day milestone")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.reforgedCoral)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            // Any of the three core activities keeps the streak, so don't
                            // name only reading here.
                            Text(streak > 0
                                 ? "Read, review, or finish a lesson to keep your streak!"
                                 : "Read, review, or finish a lesson to start a streak!")
                                .font(.system(size: 10))
                                .foregroundStyle(isAtRisk ? Color.reforgedCoral : Color.adaptiveTextSecondary(colorScheme))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

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
            // maxHeight before the card background so the background paints the
            // stretched height, letting both stat cards match the taller one.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .gamifiedStatCard(accent: .reforgedCoral)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCalendar) {
            ReadingCalendarView()
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
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var currentMonth = Date()
    @State private var showBuyFreezeAlert = false
    @State private var freezePurchaseSuccess = false
    @State private var showShareStreak = false

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
                                        isFrozen: streakManager.wasFrozen(on: date),
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
                        LegendItem(color: .reforgedCoral, label: "Active day")
                        LegendItem(color: .blue.opacity(0.7), label: "Freeze used")
                        LegendItem(color: .clear, borderColor: .reforgedCoral, label: "Today")
                    }
                    .padding(.horizontal)

                    // Encouragement message
                    if !streakManager.hasActivityToday {
                        VStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                            Text("Read, review a verse, or finish a lesson today to keep your streak going!")
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

                    // MARK: - Streak Freezes Section
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.28 : 0.12))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "snowflake")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Streak Freezes")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))

                                Text("Protects your streak when you miss a day")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }

                            Spacer()
                        }

                        // Freeze count indicators
                        HStack(spacing: 6) {
                            ForEach(0..<8, id: \.self) { index in
                                ZStack {
                                    Circle()
                                        .fill(index < appState.user.streakFreezes ? Color.blue : Color.adaptiveBorder(colorScheme))
                                        .frame(width: 30, height: 30)

                                    Image(systemName: "snowflake")
                                        .font(.system(size: 12))
                                        .foregroundStyle(index < appState.user.streakFreezes ? .white : Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                        }

                        // Status text
                        HStack {
                            Text("\(appState.user.streakFreezes) of 8 freezes available")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(appState.user.streakFreezes > 0 ? Color.blue : Color.reforgedCoral)

                            Spacer()

                            Text("4 free monthly")
                                .font(.caption2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        // Buy more button
                        Button {
                            showBuyFreezeAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))

                                Text("Buy Freeze")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                    Text("\(appState.freezePurchaseCost) XP")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .foregroundStyle(appState.user.streakFreezes >= 8 ? Color.adaptiveTextSecondary(colorScheme) : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: appState.user.streakFreezes >= 8
                                        ? [Color.adaptiveBorder(colorScheme), Color.adaptiveBorder(colorScheme)]
                                        : [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(appState.user.streakFreezes >= 8 || appState.user.xp < appState.freezePurchaseCost)

                        if appState.user.streakFreezes >= 8 {
                            Text("Maximum freezes reached!")
                                .font(.caption2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        } else if appState.user.xp < appState.freezePurchaseCost {
                            Text("You need \(appState.freezePurchaseCost - appState.user.xp) more XP to buy a freeze")
                                .font(.caption2)
                                .foregroundStyle(Color.reforgedCoral)
                        }
                    }
                    .padding()
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Share Streak Button
                    if streakManager.currentStreak >= 1 {
                        Button {
                            showShareStreak = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Share Your Streak")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.reforgedCoral, Color.reforgedCoral.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
            .sheet(isPresented: $showShareStreak) {
                StreakShareSheet()
            }
            .alert("Buy Streak Freeze", isPresented: $showBuyFreezeAlert) {
                Button("Buy for \(appState.freezePurchaseCost) XP") {
                    if appState.purchaseStreakFreeze() {
                        HapticManager.shared.lightImpact()
                        freezePurchaseSuccess = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Spend \(appState.freezePurchaseCost) XP to buy a streak freeze?\n\nYou have \(appState.user.xp) XP available.")
            }
            .alert("Freeze Purchased!", isPresented: $freezePurchaseSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You now have \(appState.user.streakFreezes) streak freezes. Your streak is protected!")
            }
        }
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var monthYearString: String {
        Self.monthYearFormatter.string(from: currentMonth)
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
            guard let date = AppDateFormatters.yearMonthDay.date(from: dateString) else { return false }
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
    let isFrozen: Bool
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
                // A frozen day counts for the streak but wasn't earned — mark it
                // blue so the calendar tells the truth about how the run survived.
                if isFrozen {
                    Circle()
                        .fill(Color.blue.opacity(0.7))
                } else if didRead {
                    Circle()
                        .fill(Color.reforgedCoral)
                }

                if isToday {
                    Circle()
                        .stroke(Color.reforgedCoral, lineWidth: 2)
                }

                if isFrozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(dayNumber)")
                        .font(.subheadline)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(
                            didRead ? .white :
                            isFutureDate ? Color.adaptiveTextSecondary(colorScheme).opacity(0.3) :
                            Color.adaptiveText(colorScheme)
                        )
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(chaptersRead.isEmpty)
        .accessibilityLabel(
            isFrozen ? "\(dayNumber): protected by a streak freeze"
                     : "\(dayNumber): \(didRead ? "complete" : "not complete")"
        )
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

            // Absorbs the slack from whichever card is shorter, so both progress
            // bars sit on the same baseline instead of floating mid-card.
            Spacer(minLength: 0)

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
        // maxHeight before the card background so the background paints the
        // stretched height, letting both stat cards match the taller one.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .gamifiedStatCard(accent: .reforgedGold)
    }
}

// MARK: - Daily Insight Card

struct DailyInsightCard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.colorScheme) var colorScheme
    @State private var liveVerseText: String? = nil
    @State private var showShareSheet = false

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
                        Text("\"\(liveVerseText ?? insight.verseText)\"")
                            .font(.body)
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(3)

                        // Plain reference — no arrow or hyperlink
                        Text("— \(insight.verse)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                    }
                    .padding(ReforgedTheme.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))

                    Text(insight.reflection)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineSpacing(3)

                    // Action buttons row
                    HStack(spacing: 10) {
                        // Read more — primary capsule button
                        Button {
                            NotificationCenter.default.post(
                                name: .switchTab,
                                object: nil,
                                userInfo: [AppNotificationUserInfoKey.tab: 2]
                            )
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(
                                    name: .navigateToBibleVerse,
                                    object: nil,
                                    userInfo: [
                                        AppNotificationUserInfoKey.reference: insight.verse,
                                        AppNotificationUserInfoKey.translation: settingsManager.defaultTranslation.rawValue
                                    ]
                                )
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "book.fill")
                                    .font(.caption)
                                Text("Read More")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.reforgedGold)
                            .clipShape(Capsule())
                        }

                        // Share — secondary capsule button
                        Button {
                            let verseText = liveVerseText ?? insight.verseText
                            UIPasteboard.general.string = "\"\(verseText)\" — \(insight.verse)"
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Share")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .strokeBorder(
                                        colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy,
                                        lineWidth: 1.5
                                    )
                            )
                        }

                        Spacer()
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    let verseText = liveVerseText ?? insight.verseText
                    ShareSheet(activityItems: ["\"\(verseText)\" — \(insight.verse)"])
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
        .task(id: appState.dailyInsight?.verse) {
            guard let reference = appState.dailyInsight?.verse else { return }
            liveVerseText = await fetchVerseText(reference: reference)
        }
        .onChange(of: settingsManager.defaultTranslation) { _ in
            guard let reference = appState.dailyInsight?.verse else { return }
            Task { liveVerseText = await fetchVerseText(reference: reference) }
        }
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    var formattedDate: String {
        Self.headerDateFormatter.string(from: Date())
    }

    private func fetchVerseText(reference: String) async -> String? {
        do {
            switch settingsManager.defaultTranslation {
            case .esv:
                return try await ESVService.shared.fetchVerseForMemory(reference: reference).text
            case .kjv:
                return try await KJVService.shared.fetchVerseForMemory(reference: reference).text
            case .net:
                return try await NETService.shared.fetchVerseForMemory(reference: reference).text
            case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                return try await ApiBibleService.shared.fetchVerseForMemory(reference: reference, translation: settingsManager.defaultTranslation).text
            case .tr, .sblgnt, .wlc:
                return nil
            }
        } catch {
            return nil
        }
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

// MARK: - Review Due Card
//
// Deliberately shaped like TodayReadingCard: same icon tile, eyebrow, and trailing
// action capsule. The two rows are the same kind of thing — a commitment with a
// deadline — so they should read as siblings rather than as two different designs.

struct ReviewDueCard: View {
    let verses: [MemoryVerse]

    @Environment(\.colorScheme) var colorScheme

    private var subtitle: String {
        let reference = verses.first?.reference ?? ""
        guard verses.count > 1 else { return reference }
        return "\(reference) + \(verses.count - 1) more"
    }

    var body: some View {
        NavigationLink(destination: MemoryReviewView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.reforgedCoral.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.reforgedCoral)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Verse Review")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedCoral)
                    Text(verses.count == 1 ? "1 verse due" : "\(verses.count) verses due")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Review")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.reforgedCoral)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.reforgedCoral.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: .switchTab, object: nil, userInfo: ["tab": 2])
                } label: {
                    quickActionTile(
                        icon: "book.fill",
                        iconColor: Color.adaptiveNavyText(colorScheme),
                        iconBackground: Color.adaptiveNavyText(colorScheme).opacity(0.12),
                        title: "Read Bible",
                        subtitle: "Continue reading"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: JournalView()) {
                    quickActionTile(
                        icon: "pencil.line",
                        iconColor: Color.reforgedGold,
                        iconBackground: Color.reforgedGold.opacity(0.15),
                        title: "Journal",
                        subtitle: "Reflect on God's Word"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionTile(icon: String, iconColor: Color, iconBackground: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .reforgedCard()
    }
}


// MARK: - Share Gospel Card

struct ShareGospelCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: ShareGospelDetailView()) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.reforgedGold.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share the Gospel")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("The Four P's")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                // Four P's preview pills
                HStack(spacing: 8) {
                    ForEach(["Problem", "Penalty", "Payment", "Promise"], id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.reforgedGold.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text("Romans 3:23 · 6:23 · 5:8 · 10:9")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(ReforgedTheme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gamifiedStatCard(accent: .reforgedGold)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Gospel Detail View

struct GospelSection {
    let title: String
    let subtitle: String
    let verseRefs: [String]
    let body: String
}

struct ShareGospelDetailView: View {
    @Environment(\.colorScheme) var colorScheme

    private let sections: [GospelSection] = [
        GospelSection(
            title: "Problem",
            subtitle: "We All Fall Short",
            verseRefs: ["Romans 3:23"],
            body: "Every person who has ever lived, no matter how good they seem, has sinned. Sin is anything that goes against God's perfect standard — a lie, a selfish thought, a harsh word, a wrong action. Romans 3:23 tells us that all have sinned. Not most. Not the worst people. All of us. That includes me, and it includes you. God is perfectly holy, and our sin creates a real gap between us and Him. We cannot close that gap on our own, no matter how hard we try."
        ),
        GospelSection(
            title: "Penalty",
            subtitle: "Sin Has a Cost",
            verseRefs: ["Romans 6:23"],
            body: "Sin is not something God simply overlooks. Romans 6:23 says the wages of sin is death. A wage is something you earn. Because of our sin, what we have earned is death — not just physical death, but spiritual separation from God forever. That is a sobering reality. But notice that the same verse pivots: \"but the gift of God is eternal life.\" A gift is not earned. It is given. That contrast is everything."
        ),
        GospelSection(
            title: "Payment",
            subtitle: "God Made a Way",
            verseRefs: ["Romans 5:8"],
            body: "Here is where the good news really begins. God did not leave us without hope. Romans 5:8 says that while we were still sinners — not after we cleaned ourselves up, not once we became worthy — Christ died for us. Jesus, God's own Son, took the penalty that we deserved. He died in our place, was buried, and rose again three days later, defeating death. The debt was real, and it was paid in full. Not by us — by Him."
        ),
        GospelSection(
            title: "Promise",
            subtitle: "Salvation Is Available to You",
            verseRefs: ["Romans 10:9", "Romans 10:13"],
            body: "This is the personal invitation. Romans 10:9 says that if you confess with your mouth that Jesus is Lord and believe in your heart that God raised Him from the dead, you will be saved. And Romans 10:13 makes it as wide open as possible: whosoever calls on the name of the Lord will be saved. That word whosoever leaves no one out. It means you, right now, wherever you are and whatever you have done."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {

                // Intro banner
                VStack(alignment: .leading, spacing: 8) {
                    Text("Salvation is not about being good enough. It is about trusting what Jesus already did.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .italic()
                }
                .padding(ReforgedTheme.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .heroCard()

                // Four P sections
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    GospelSectionCard(index: index + 1, section: section, onNavigate: navigateToVerse)
                }

                // Closing prompt
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                        Text("How to Close the Conversation")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }

                    Text("\"Would you like to call on the Lord right now? I can walk you through a prayer, but what matters is not the words — it's the genuine belief in your heart.\"")
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .padding(12)
                        .background(Color.reforgedGold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(ReforgedTheme.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                        .stroke(Color.reforgedGold.opacity(0.2), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Share the Gospel")
        .navigationBarTitleDisplayMode(.large)
    }

    private func navigateToVerse(_ reference: String) {
        // Switch to the Bible tab, leaving this view on the stack so the user
        // can return to ShareGospelDetailView by tapping the Discipleship tab.
        NotificationCenter.default.post(
            name: .switchTab,
            object: nil,
            userInfo: [AppNotificationUserInfoKey.tab: 2]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(
                name: .navigateToBibleVerse,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.reference: reference]
            )
        }
    }
}

struct GospelSectionCard: View {
    let index: Int
    let section: GospelSection
    let onNavigate: (String) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedNavy.opacity(colorScheme == .dark ? 0.6 : 1.0))
                        .frame(width: 40, height: 40)
                    Text("\(index)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("—")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text(section.subtitle)
                            .font(.headline)
                            .foregroundStyle(colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                    }

                    // Tappable verse reference pills
                    HStack(spacing: 6) {
                        ForEach(section.verseRefs, id: \.self) { ref in
                            Button {
                                onNavigate(ref)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 9))
                                    Text(ref)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.reforgedGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.reforgedGold.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Body text with inline tappable verse references
            Text(attributedBody(section.body, refs: section.verseRefs))
                .font(.body)
                .lineSpacing(4)
                .accentColor(Color.reforgedGold)
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "bibleverse",
                          let encoded = url.host,
                          let ref = encoded.removingPercentEncoding else { return .systemAction }
                    onNavigate(ref)
                    return .handled
                })
        }
        .padding(ReforgedTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
    }

    private func attributedBody(_ text: String, refs: [String]) -> AttributedString {
        var result = AttributedString(text)
        for ref in refs {
            var searchStart = result.startIndex
            while let range = result[searchStart...].range(of: ref) {
                let encoded = ref.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ref
                result[range].link = URL(string: "bibleverse://\(encoded)")
                searchStart = range.upperBound
            }
        }
        return result
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
}
