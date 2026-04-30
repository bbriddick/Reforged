import SwiftUI

private extension Color {
    static let walkTalksTeal = Color(red: 0.004, green: 0.490, blue: 0.616)
}

// MARK: - Discipleship Hub View

struct DiscipleshipView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var focusService = FocusBlockingService.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    learningPathCard
                    readingPlansCard
                    tracksCard
                    podcastCard
                    ShareGospelCard()
                    focusShieldCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Discipleship")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                let name = appState.user.firstName
                Text(name.isEmpty ? "Grow in Faith" : "Growing in Christ, \(name)")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            // XP & Streak badges
            HStack(spacing: 8) {
                statBadge(icon: "flame.fill", value: "\(appState.user.streak)", color: .orange)
                statBadge(icon: "star.fill", value: "\(appState.user.xp) XP", color: Color.reforgedGold)
            }
        }
        .padding(.top, 4)
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
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.18, blue: 0.38),
                        Color(red: 0.18, green: 0.28, blue: 0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles
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

                        // Progress bar
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

    // MARK: - Reading Plans Card

    private var readingPlansCard: some View {
        NavigationLink(destination: ReadingPlansView()) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.1, green: 0.65, blue: 0.8).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(red: 0.1, green: 0.65, blue: 0.8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading Plans")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(readingPlansSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
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

    private var readingPlansSubtitle: String {
        let service = ReadingPlanService.shared
        let inProgress = BibleReadingPlans.all.filter {
            service.hasStarted($0.id) && !service.isComplete($0.id)
        }
        let finished = BibleReadingPlans.all.filter { service.isComplete($0.id) }
        if inProgress.isEmpty && finished.isEmpty {
            return "5 plans · Start your reading journey"
        }
        var parts: [String] = []
        if !inProgress.isEmpty { parts.append("\(inProgress.count) in progress") }
        if !finished.isEmpty  { parts.append("\(finished.count) completed") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Tracks Card

    private var tracksCard: some View {
        NavigationLink(destination: TracksView()) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.reforgedGold.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Explore Tracks")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(tracksSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
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

    // MARK: - Podcast Card

    private var podcastCard: some View {
        NavigationLink(destination: PodcastView()) {
            HStack(spacing: 16) {
                AsyncImage(url: PodcastService.shared.feed?.artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.walkTalksTeal.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "headphones")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.walkTalksTeal)
                        }
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Walk Talks")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(podcastSubtitle)
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

    private var tracksSubtitle: String {
        let total = appState.tracks.count
        let completed = appState.tracks.filter { $0.completedLessons == $0.totalLessons && $0.totalLessons > 0 }.count
        return "\(total) track\(total == 1 ? "" : "s") · \(completed) completed"
    }

    private var shieldIconColor: Color {
        focusService.isAnyBlockingActive ? Color.reforgedGold : Color.reforgedCoral
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
