import SwiftUI

// MARK: - Shareable Streak Card (1080x1080, always dark)

struct StreakShareCardView: View {
    let displayName: String
    let avatar: String
    let profileImagePath: String?
    let streak: Int
    let longestStreak: Int
    let level: Int
    let levelTitle: String

    var body: some View {
        ZStack {
            // Dark gradient background
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.22, blue: 0.25),
                    Color(red: 0.12, green: 0.12, blue: 0.14)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 600
            )

            // Subtle decorative circles in background
            Circle()
                .fill(Color.reforgedCoral.opacity(0.04))
                .frame(width: 600, height: 600)
                .offset(y: -50)

            VStack(spacing: 0) {
                Spacer().frame(height: 90)

                // Avatar
                StandaloneProfileAvatar(
                    avatar: avatar,
                    profileImagePath: profileImagePath,
                    size: 100,
                    borderColor: Color.reforgedGold
                )

                Spacer().frame(height: 20)

                // Display name
                Text(displayName.isEmpty ? "Believer" : displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer().frame(height: 6)

                // Level title
                Text(levelTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.reforgedGold)

                Spacer().frame(height: 36)

                // Gold divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.reforgedGold.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 300, height: 1)

                Spacer().frame(height: 44)

                // Flame icon with glow
                Image(systemName: "flame.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.reforgedCoral, Color(red: 1.0, green: 0.5, blue: 0.2)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .shadow(color: Color.reforgedCoral.opacity(0.5), radius: 30)
                    .shadow(color: Color.reforgedCoral.opacity(0.3), radius: 60)

                Spacer().frame(height: 12)

                // Big streak number
                Text("\(streak)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // "Day Streak"
                Text(streak == 1 ? "Day Streak" : "Day Streak")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer().frame(height: 44)

                // Gold divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.reforgedGold.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 300, height: 1)

                Spacer().frame(height: 28)

                // Secondary stats
                HStack(spacing: 60) {
                    VStack(spacing: 6) {
                        Text("\(longestStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Best Streak")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Vertical separator
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 40)

                    VStack(spacing: 6) {
                        Text("Lv. \(level)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Level")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                // App branding
                VStack(spacing: 6) {
                    Text("REFORGED")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.reforgedGold)
                        .tracking(6)

                    Text("Bible Reading & Discipleship")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer().frame(height: 60)
            }
        }
        .frame(width: 1080, height: 1080)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Streak Share Presentation

struct StreakShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var streakManager = ReadingStreakManager.shared

    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false

    private var levelInfo: LevelInfo {
        SampleData.getLevelInfo(xp: appState.user.xp)
    }

    private var shareCard: some View {
        StreakShareCardView(
            displayName: appState.user.displayName,
            avatar: appState.user.avatar,
            profileImagePath: appState.user.profileImagePath,
            streak: streakManager.currentStreak,
            longestStreak: streakManager.longestStreak,
            level: levelInfo.level,
            levelTitle: levelInfo.title
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Scaled-down preview
                shareCard
                    .scaleEffect(0.3)
                    .frame(width: 324, height: 324)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        renderImage()
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .reforgedPrimaryButton()
                    }

                    Button {
                        HapticManager.shared.lightImpact()
                        renderImage()
                        saveToPhotos()
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                            .reforgedSecondaryButton()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Share Your Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(activityItems: [image])
                }
            }
            .alert("Saved!", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your streak card has been saved to your photo library.")
            }
        }
    }

    private func renderImage() {
        guard renderedImage == nil else { return }
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
    }

    private func saveToPhotos() {
        renderImage()
        guard let image = renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaveConfirmation = true
    }
}
