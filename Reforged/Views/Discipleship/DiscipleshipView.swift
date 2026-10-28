import SwiftUI

private extension Color {
    static let walkTalksTeal = Color(red: 0.004, green: 0.490, blue: 0.616)
}

// MARK: - Discipleship Hub View

struct DiscipleshipView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var rhythmStore = RhythmStorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showTemptedSOS = false
    @State private var showAccountability = false
    @State private var showStudyLibraryHub = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // One clear next step, then everything else in quiet, labelled groups.
                    continueCard

                    HonorLinkStatusCard()

                    group("Protection") {
                        shieldRow
                        divider
                        temptedRow
                    }

                    group("Daily") {
                        disciplinesRow
                        divider
                        journalRow
                    }

                    group("Learn") {
                        readingPlansRow
                        divider
                        tracksRow
                        divider
                        studyLibraryRow
                        divider
                        walkTalksRow
                    }

                    group("Share") {
                        shareGospelRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
                // A readable column on iPad/Mac instead of a stretched one.
                .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Discipleship")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showTemptedSOS) {
                TemptedSOSView()
            }
            // Weekly report reminder taps land here (the accountability screen
            // normally lives two pushes deep under the shield).
            .sheet(isPresented: $showAccountability) {
                NavigationStack {
                    AccountabilityPartnerView()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAccountabilityPartner)) { _ in
                showAccountability = true
            }
            // Deep link from the verse-study "Library" button.
            .navigationDestination(isPresented: $showStudyLibraryHub) {
                StudyLibraryHubView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openStudyLibrary)) { _ in
                showStudyLibraryHub = true
            }
        }
    }

    // MARK: - Building blocks

    /// A labelled group: small caption above, one bordered container of rows below.
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.leading, 4)

            VStack(spacing: 0) { content() }
                .practiceCard(radius: 18)
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 66)
    }

    /// One row: icon chip, title, one line of context, and a trailing accessory.
    private func rowLabel<Trailing: View>(icon: String, tint: Color, title: String, subtitle: String,
                                          @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.14),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailing()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.14), in: Capsule())
    }

    // MARK: - The one primary action

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentLesson == nil ? "YOUR LEARNING PATH" : "NEXT LESSON")
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(Color.reforgedCoral)
                Text(currentLesson?.title ?? "Start your discipleship journey")
                    .font(.title3.bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(progressSubtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            if currentLesson != nil {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.adaptiveBorder(colorScheme)).frame(height: 10)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.reforgedGold, Color.orange],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(10, geo.size.width * overallProgress), height: 10)
                        }
                    }
                    .frame(height: 10)
                    Text(progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            NavigationLink(destination: LearningPathView()) {
                Text(currentLesson == nil ? "Start" : "Continue")
            }
            .buttonStyle(Chunky3DButtonStyle(
                backgroundColor: Color.reforgedCoral,
                bevelColor: Color.reforgedCoral.practiceBevel()))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceCard(radius: 22)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 12, y: 6)
    }

    // MARK: - Protection

    private var shieldRow: some View {
        let active = focusService.isAnyBlockingActive
        return NavigationLink(destination: FocusBlockingView()) {
            rowLabel(icon: active ? "checkmark.shield.fill" : "shield.lefthalf.filled",
                     tint: shieldIconColor,
                     title: "Focus & Purity Shield",
                     subtitle: active ? focusService.statusDescription : "Block adult content and distracting apps") {
                statusPill(active ? "On" : "Set up", tint: shieldIconColor)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { FeatureUsage.record(.shield) })
    }

    private var temptedRow: some View {
        Button {
            HapticManager.shared.buttonTap()
            showTemptedSOS = !HonorLink.shared.handOffSOS()
        } label: {
            rowLabel(icon: "hand.raised.brakesignal", tint: Color.reforgedCoral,
                     title: "I'm Being Tempted",
                     subtitle: "Pause, breathe, and take hold of a way out") { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily

    private var disciplinesRow: some View {
        NavigationLink(destination: RhythmHubView()) {
            rowLabel(icon: "calendar.badge.clock", tint: Color.reforgedGold,
                     title: "My Disciplines", subtitle: rhythmSubtitle) { EmptyView() }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { FeatureUsage.record(.disciplines) })
    }

    private var journalRow: some View {
        NavigationLink(destination: JournalView()) {
            rowLabel(icon: "pencil.line", tint: Color(red: 0.20, green: 0.65, blue: 0.40),
                     title: "Notes", subtitle: "Reflections, prayers and Bible notes") { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    private var rhythmSubtitle: String {
        let due = rhythmStore.todayDueCount
        guard due > 0 else { return "Daily checklist, reminders and plans" }
        return "Today: \(rhythmStore.todayCompletedCount) of \(due) done"
    }

    // MARK: - Learn

    private var readingPlansRow: some View {
        NavigationLink(destination: ReadingPlansView()) {
            rowLabel(icon: "calendar.badge.checkmark", tint: Color(red: 0.1, green: 0.65, blue: 0.8),
                     title: "Reading Plans", subtitle: readingPlansSubtitle) { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    private var tracksRow: some View {
        NavigationLink(destination: TracksView()) {
            rowLabel(icon: "books.vertical.fill", tint: Color.reforgedGold,
                     title: "Tracks", subtitle: tracksSubtitle) { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    private var studyLibraryRow: some View {
        NavigationLink(destination: StudyLibraryHubView()) {
            rowLabel(icon: "building.columns.fill", tint: Color(red: 0.55, green: 0.35, blue: 0.7),
                     title: "Study Library",
                     subtitle: "Atlas, commentaries, dictionaries") { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    private var walkTalksRow: some View {
        NavigationLink(destination: PodcastView()) {
            rowLabel(icon: "headphones", tint: Color.walkTalksTeal,
                     title: "Walk Talks", subtitle: podcastSubtitle) { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    private var podcastSubtitle: String {
        if let latest = PodcastService.shared.feed?.episodes.first?.title {
            return "Latest: \(latest)"
        }
        return "Southland Christian Ministries"
    }

    // MARK: - Share

    private var shareGospelRow: some View {
        NavigationLink(destination: ShareGospelDetailView()) {
            rowLabel(icon: "person.2.fill", tint: Color.reforgedGold,
                     title: "Share the Gospel", subtitle: "The Four P's") { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Helpers

    private var currentLesson: Lesson? {
        for track in appState.tracks {
            if let lesson = track.lessons.first(where: { !$0.isCompleted }) {
                return lesson
            }
        }
        return nil
    }

    private var progressSubtitle: String {
        let total = appState.tracks.reduce(0) { $0 + $1.totalLessons }
        let completed = appState.tracks.reduce(0) { $0 + $1.completedLessons }
        guard total > 0 else { return "Begin your journey" }
        let pct = Int((Double(completed) / Double(total)) * 100)
        let name = appState.user.firstName
        let lead = name.isEmpty ? "" : "Growing in Christ, \(name). "
        return "\(lead)\(pct)% of the learning path complete"
    }

    private var overallProgress: CGFloat {
        let total = appState.tracks.reduce(0) { $0 + $1.totalLessons }
        let completed = appState.tracks.reduce(0) { $0 + $1.completedLessons }
        guard total > 0 else { return 0 }
        return CGFloat(completed) / CGFloat(total)
    }

    private var progressLabel: String {
        let total = appState.tracks.reduce(0) { $0 + $1.totalLessons }
        let completed = appState.tracks.reduce(0) { $0 + $1.completedLessons }
        return "\(completed)/\(total) lessons"
    }

    private var readingPlansSubtitle: String {
        let service = ReadingPlanService.shared
        let inProgress = BibleReadingPlans.all.filter {
            service.hasStarted($0.id) && !service.isComplete($0.id)
        }
        let finished = BibleReadingPlans.all.filter { service.isComplete($0.id) }
        if inProgress.isEmpty && finished.isEmpty {
            return "5 plans available"
        }
        var parts: [String] = []
        if !inProgress.isEmpty { parts.append("\(inProgress.count) in progress") }
        if !finished.isEmpty  { parts.append("\(finished.count) done") }
        return parts.joined(separator: " · ")
    }

    private var tracksSubtitle: String {
        let total = appState.tracks.count
        let completed = appState.tracks.filter { $0.completedLessons == $0.totalLessons && $0.totalLessons > 0 }.count
        return "\(total) track\(total == 1 ? "" : "s") · \(completed) completed"
    }

    /// Matches the shield screen's status semantics: green = protected,
    /// coral = needs attention.
    private var shieldIconColor: Color {
        focusService.isAnyBlockingActive ? Color.green : Color.reforgedCoral
    }

    private var focusStatusLabel: String {
        if focusService.isAnyBlockingActive {
            return focusService.statusDescription
        }
        return "Tap to set up content blocking"
    }
}

#if false
#Preview {
    DiscipleshipView()
        .environmentObject(AppState.shared)
}
#endif


/// Shared status in Discipleship and the shield screen, including a way to revisit restoration.
struct HonorLinkStatusCard: View {
    @ObservedObject private var link = HonorLink.shared

    var body: some View {
        if link.isHonorInstalled || HonorLink.blockingIsPaused {
            VStack(alignment: .leading, spacing: 8) {
                if link.isHonorInstalled {
                    Text(link.protection?.active == true
                         ? "Protected by Reforged Honor" : "Reforged Honor protection is paused")
                        .font(.headline)
                    if let since = link.protection?.since {
                        Text("Protection started \(since.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                    }
                    Text("\(link.faithfulDays.count) faithful days in the last 90 days")
                        .font(.subheadline)
                    Button("Open Reforged Honor") { link.openHonor() }
                }
                if HonorLink.blockingIsPaused {
                    Text("Reforged Bible’s blocking is paused.")
                        .font(.subheadline)
                    if !link.isHonorInstalled || link.protection?.active == false {
                        Button("Turn Reforged Bible Blocking Back On") { link.prompt = .restore }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .practiceCard(radius: 18)
        }
    }
}
