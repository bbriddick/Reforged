import SwiftUI

private extension Color {
    static let walkTalksTeal = Color(red: 0.004, green: 0.490, blue: 0.616)
}

// MARK: - Discipleship Hub View

struct DiscipleshipView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var focusService = FocusBlockingService.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showTemptedSOS = false
    @State private var showAccountability = false
    @State private var showStudyLibraryHub = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                    learningPathCard

                    sectionLabel("Resources")
                    resourcesGrid

                    sectionLabel("Tools")
                    ShareGospelCard()
                    focusShieldCard
                    temptedSOSCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
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

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .tracking(1.0)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, -4)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                let name = appState.user.firstName
                Text(name.isEmpty ? "Grow in Faith" : "Growing in Christ, \(name)")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Text(progressSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            }

            Spacer()

            HStack(spacing: 8) {
                statBadge(icon: "flame.fill", value: "\(appState.user.streak)", color: .orange)
                statBadge(icon: "star.fill", value: "\(appState.user.xp) XP", color: Color.reforgedGold)
            }
        }
        .padding(.top, 4)
    }

    private var progressSubtitle: String {
        let total = appState.tracks.reduce(0) { $0 + $1.totalLessons }
        let completed = appState.tracks.reduce(0) { $0 + $1.completedLessons }
        guard total > 0 else { return "Begin your journey" }
        let pct = Int((Double(completed) / Double(total)) * 100)
        return "\(pct)% of learning path complete"
    }

    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.07), radius: 4, y: 2)
    }

    // MARK: - Learning Path Card

    private var learningPathCard: some View {
        NavigationLink(destination: LearningPathView()) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.18, blue: 0.38),
                        Color(red: 0.18, green: 0.28, blue: 0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 160, height: 160)
                    .offset(x: 220, y: -60)

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 100, height: 100)
                    .offset(x: 260, y: 20)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                        Text("My Learning Path")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    if let currentLesson = currentLesson {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next up")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.65))
                            Text(currentLesson.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.20))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.reforgedGold)
                                    .frame(width: geo.size.width * overallProgress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    } else {
                        Text("Start your discipleship journey")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.80))
                    }

                    HStack {
                        Text("Continue →")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                        Spacer()
                        Text(progressLabel)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .frame(height: 165)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.22), radius: 12, y: 5)
    }

    // MARK: - Resources Grid

    private var resourcesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            readingPlansMiniCard
            tracksMiniCard
            studyLibraryMiniCard
            walkTalksMiniCard
        }
    }

    private var walkTalksMiniCard: some View {
        NavigationLink(destination: PodcastView()) {
            VStack(alignment: .leading, spacing: 10) {
                AsyncImage(url: PodcastService.shared.feed?.artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.walkTalksTeal.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "headphones")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.walkTalksTeal)
                        }
                    }
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Walk Talks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(podcastSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var studyLibraryMiniCard: some View {
        let accent = Color(red: 0.55, green: 0.35, blue: 0.7)
        return NavigationLink(destination: StudyLibraryHubView()) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Study Library")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text("Atlas, commentaries, dictionaries & devotionals")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var readingPlansMiniCard: some View {
        let accent = Color(red: 0.1, green: 0.65, blue: 0.8)
        return NavigationLink(destination: ReadingPlansView()) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading Plans")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(readingPlansSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var tracksMiniCard: some View {
        NavigationLink(destination: TracksView()) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.reforgedGold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Tracks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(tracksSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if overallProgress > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.reforgedGold)
                                .frame(width: geo.size.width * overallProgress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Podcast Card

    private var podcastSubtitle: String {
        if let latest = PodcastService.shared.feed?.episodes.first?.title {
            return "Latest: \(latest)"
        }
        return "Southland Christian Ministries"
    }

    // MARK: - Focus Shield Card

    private var focusShieldCard: some View {
        NavigationLink(destination: FocusBlockingView()) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(shieldIconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(shieldIconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Focus & Purity Shield")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(focusStatusLabel)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tempted SOS Card

    private var temptedSOSCard: some View {
        Button {
            HapticManager.shared.buttonTap()
            showTemptedSOS = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.reforgedCoral.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "hand.raised.brakesignal")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.reforgedCoral)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("I'm Being Tempted")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Pause, breathe, and take hold of a way out")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
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

#Preview {
    DiscipleshipView()
        .environmentObject(AppState.shared)
}
