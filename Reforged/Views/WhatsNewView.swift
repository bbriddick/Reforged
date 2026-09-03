import SwiftUI

// MARK: - What's New View

struct WhatsNewView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    cardContent

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // Feature list
            VStack(spacing: 0) {
                ForEach(WhatsNewFeature.currentVersion, id: \.title) { feature in
                    featureRow(feature)

                    if feature.title != WhatsNewFeature.currentVersion.last?.title {
                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 24)
                    }
                }
            }

            Divider()
                .padding(.horizontal, 24)

            // CTA button
            ctaButton
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.25), radius: 40)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.reforgedNavy, Color.reforgedNavy.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.reforgedNavy.opacity(0.35), radius: 16)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 28)

            Text("What's New")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Here's what's new in this update")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        let accent = feature.accent.color(colorScheme)

        return HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isPresented = false
            }
        } label: {
            Text("Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.reforgedNavy, Color.reforgedNavy.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - What's New Feature Model

/// Accent for a feature row. `navy` resolves through `adaptiveNavyText` because the
/// brand navy is near-black charcoal — as a literal color it disappears on a dark card.
enum WhatsNewAccent {
    case gold
    case coral
    case purple
    case navy

    func color(_ scheme: ColorScheme?) -> Color {
        switch self {
        case .gold: return .reforgedGold
        case .coral: return .reforgedCoral
        case .purple: return .purple
        case .navy: return .adaptiveNavyText(scheme)
        }
    }
}

struct WhatsNewFeature {
    let icon: String
    let accent: WhatsNewAccent
    let title: String
    let description: String

    static let currentVersion: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "text.magnifyingglass",
            accent: .gold,
            title: "Verse Study",
            description: "Tap any verse and choose Study for cross references, a Greek and Hebrew word breakdown, and questions to journal through."
        ),
        WhatsNewFeature(
            icon: "tag",
            accent: .navy,
            title: "Topical Bible",
            description: "Search a topic like anxiety or forgiveness and jump straight to the passages that speak to it, ranked by what readers found most helpful."
        ),
        WhatsNewFeature(
            icon: "brain.head.profile",
            accent: .purple,
            title: "Sharper Memory Review",
            description: "Reviews now open with a swipeable flashcard deck, then step each verse up through harder exercises as it sticks."
        ),
        WhatsNewFeature(
            icon: "shield.lefthalf.filled",
            accent: .coral,
            title: "A Stronger Shield",
            description: "Set blocking schedules, start a focus session on demand, reach for the SOS flow when tempted, and keep a partner in the loop."
        ),
        WhatsNewFeature(
            icon: "headphones",
            accent: .gold,
            title: "KJV Audio, Offline",
            description: "Listen to the KJV with a new public-domain recording, and download chapters to hear them without a connection."
        ),
    ]
}

// MARK: - Version Tracking

enum AppVersionTracker {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private static let lastSeenVersionKey = "lastSeenAppVersion"
    private static let lastSeenBuildKey = "lastSeenAppBuild"

    static var shouldShowWhatsNew: Bool {
        let lastVersion = UserDefaults.standard.string(forKey: lastSeenVersionKey) ?? ""
        // Show when the version string has changed (i.e. this is an update)
        // and the user has already completed onboarding (not a fresh install)
        return !lastVersion.isEmpty && lastVersion != currentVersion
    }

    static func markAsSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
        UserDefaults.standard.set(currentBuild, forKey: lastSeenBuildKey)
    }

    /// Call on first onboarding completion to seed the version so the popup
    /// doesn't appear immediately after a fresh install.
    static func seedVersion() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
        UserDefaults.standard.set(currentBuild, forKey: lastSeenBuildKey)
    }
}
