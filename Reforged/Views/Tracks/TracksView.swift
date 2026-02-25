import SwiftUI

struct TracksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ReforgedTheme.spacingL) {
                    // Header section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Learning Tracks")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Deepen your understanding of Scripture through guided devotional tracks")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Tracks list
                    LazyVStack(spacing: 16) {
                        ForEach(appState.tracks) { track in
                            NavigationLink(destination: TrackDetailView(track: track)) {
                                TrackCard(track: track)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Track Card

struct TrackCard: View {
    let track: Track
    @Environment(\.colorScheme) var colorScheme

    var progress: Double {
        guard track.totalLessons > 0 else { return 0 }
        return Double(track.completedLessons) / Double(track.totalLessons)
    }

    var trackColor: Color {
        switch track.color {
        case "blue": return .reforgedNavy
        case "red": return .reforgedCoral
        case "green": return Color(red: 0.2, green: 0.6, blue: 0.4)
        case "purple": return Color(red: 0.5, green: 0.3, blue: 0.6)
        case "indigo": return Color(red: 0.3, green: 0.3, blue: 0.6)
        case "orange": return .reforgedGold
        default: return .reforgedNavy
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                        .fill(
                            LinearGradient(
                                colors: [trackColor, trackColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: trackColor.opacity(0.3), radius: 8, y: 4)

                    Image(systemName: track.icon.isEmpty ? "book.fill" : track.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(track.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(track.description)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            // Progress section
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(trackColor.opacity(0.15))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(trackColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(track.completedLessons)/\(track.totalLessons) lessons")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(trackColor)
                }
            }
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard(elevated: true)
    }
}

// MARK: - Track Detail View

struct TrackDetailView: View {
    let track: Track
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var currentTrack: Track {
        appState.tracks.first { $0.id == track.id } ?? track
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Track Header
                TrackHeader(track: currentTrack)

                // Lessons List
                VStack(spacing: 12) {
                    ForEach(currentTrack.lessons) { lesson in
                        LessonRow(lesson: lesson)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrackHeader: View {
    let track: Track
    @Environment(\.colorScheme) var colorScheme

    var progress: Double {
        guard track.totalLessons > 0 else { return 0 }
        return Double(track.completedLessons) / Double(track.totalLessons)
    }

    var trackColor: Color {
        switch track.color {
        case "blue": return .reforgedNavy
        case "red": return .reforgedCoral
        case "green": return Color(red: 0.2, green: 0.6, blue: 0.4)
        case "purple": return Color(red: 0.5, green: 0.3, blue: 0.6)
        case "indigo": return Color(red: 0.3, green: 0.3, blue: 0.6)
        case "orange": return .reforgedGold
        default: return .reforgedNavy
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon with gradient
            ZStack {
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusXLarge)
                    .fill(
                        LinearGradient(
                            colors: [trackColor, trackColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: trackColor.opacity(0.3), radius: 12, y: 6)

                Image(systemName: track.icon.isEmpty ? "book.fill" : track.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            Text(track.description)
                .font(.body)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Progress bar
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(trackColor.opacity(0.15))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(trackColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(track.completedLessons) of \(track.totalLessons) lessons")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Spacer()

                    Text("\(Int(progress * 100))% Complete")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(trackColor)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(ReforgedTheme.spacingL)
        .frame(maxWidth: .infinity)
        .reforgedCard(elevated: true)
        .padding(.horizontal)
    }
}

struct LessonRow: View {
    let lesson: Lesson
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: LessonView(lesson: lesson)) {
            HStack(spacing: 14) {
                // Lesson number/check circle
                ZStack {
                    Circle()
                        .fill(lesson.isCompleted ?
                              Color(red: 0.2, green: 0.7, blue: 0.4) :
                              Color.reforgedNavy.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if lesson.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    } else {
                        Text("\(lesson.order)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(lesson.description)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("+\(lesson.xpReward)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Color.reforgedGold)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(ReforgedTheme.spacingM)
            .reforgedCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TracksView()
        .environmentObject(AppState.shared)
}
