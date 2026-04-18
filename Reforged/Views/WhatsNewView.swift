import SwiftUI

// MARK: - What's New View

struct WhatsNewView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var settingsManager: SettingsManager
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

            // Settings toggles
            togglesSection

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
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(feature.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(feature.color)
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

    // MARK: - Toggles Section

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customize Your Experience")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 4)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            toggleRow(
                icon: "text.word.spacing",
                iconColor: Color.reforgedCoral,
                title: "Words of Christ in Red",
                subtitle: "Highlight Jesus's words in red throughout the Gospels",
                isOn: $settingsManager.showRedLetterText
            )

            Divider()
                .padding(.leading, 68)
                .padding(.trailing, 24)

            toggleRow(
                icon: "sparkles",
                iconColor: Color.reforgedGold,
                title: "AI Features",
                subtitle: "Journal prompts, word study summaries, and smart search",
                isOn: $settingsManager.aiEnabled
            )
        }
        .padding(.bottom, 8)
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(iconColor)
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

struct WhatsNewFeature {
    let icon: String
    let color: Color
    let title: String
    let description: String

    static let currentVersion: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "text.word.spacing",
            color: .reforgedCoral,
            title: "Words of Christ in Red",
            description: "Jesus's words are now highlighted in red throughout the Gospels and Acts for deeper devotional reading."
        ),
        WhatsNewFeature(
            icon: "sparkles",
            color: .reforgedGold,
            title: "AI-Powered Study Tools",
            description: "Get journal prompts, word study summaries, and smarter search powered by AI. Can be disabled in Settings."
        ),
        WhatsNewFeature(
            icon: "square.and.arrow.up",
            color: Color.reforgedNavy,
            title: "Verse Share Cards",
            description: "Share beautifully designed verse cards with friends and family directly from any Bible passage."
        ),
        WhatsNewFeature(
            icon: "rectangle.3.group",
            color: Color.purple,
            title: "Home Screen Widget",
            description: "Add the Verse of the Day widget to your home screen to keep Scripture front and center."
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
