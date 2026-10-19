import SwiftUI

// MARK: - What's New View
// Presented as a sheet on update. Laid out as a full page (not a floating card
// over a scrim) so it fills the sheet cleanly on iPhone and the iPad form sheet.
// Content is width-capped and the feature list switches to a grid when there's room.

struct WhatsNewView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    private let maxContentWidth: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                spotlightCard
                featureSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { ctaBar }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VERSION \(AppVersionTracker.currentVersion)")
                .font(.caption2)
                .fontWeight(.heavy)
                .tracking(1.4)
                .foregroundStyle(Color.reforgedCoral)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.reforgedCoral.opacity(0.12), in: Capsule())

            Text("What's New")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Read, memorize, and grow alongside your friends, with a smoother start and study tools that work anywhere.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Spotlight

    private var spotlightCard: some View {
        let spotlight = WhatsNewSpotlight.current

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label(spotlight.eyebrow.uppercased(), systemImage: "sparkles")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))

                Text(spotlight.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text(spotlight.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(spotlight.highlights, id: \.text) { highlight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: highlight.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.reforgedCoral)
                            .frame(width: 28, height: 28)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(highlight.text)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color.reforgedCoral, Color.reforgedGold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Oversized watermark glyph for a bit of texture.
                Image(systemName: spotlight.icon)
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(.white.opacity(0.12))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 18, y: -14)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Features

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Also in this update")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(WhatsNewFeature.currentVersion, id: \.title) { feature in
                    featureTile(feature)
                }
            }
        }
    }

    private func featureTile(_ feature: WhatsNewFeature) -> some View {
        let accent = feature.accent.color(colorScheme)

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.adaptiveCardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - CTA

    private var ctaBar: some View {
        Button {
            isPresented = false
        } label: {
            Text("Let's Go")
        }
        .buttonStyle(Chunky3DButtonStyle(
            backgroundColor: .reforgedCoral,
            bevelColor: Color(red: 0.72, green: 0.18, blue: 0.28)
        ))
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
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
            icon: "arrow.right.circle.fill",
            accent: .gold,
            title: "Pick Up Where You Left Off",
            description: "Home and the Bible navigator now share one Continue button that takes you to your next reading plan entry, or your last place in the Bible."
        ),
        WhatsNewFeature(
            icon: "sparkles",
            accent: .coral,
            title: "A Faster Start",
            description: "New onboarding has you learning a real verse in about a minute, with a short guided tour of each tab as you go."
        ),
        WhatsNewFeature(
            icon: "wifi.slash",
            accent: .purple,
            title: "Study Tools That Work Offline",
            description: "Original-language word studies and lexicons are built into the app, so they open instantly with no connection."
        ),
        WhatsNewFeature(
            icon: "arrow.triangle.2.circlepath",
            accent: .navy,
            title: "Coming From YouVersion?",
            description: "Bring your saved verses over as memory verses and set your place in a reading plan, so switching costs you nothing."
        ),
        WhatsNewFeature(
            icon: "iphone.and.arrow.forward",
            accent: .gold,
            title: "A New Device Feels Like Home",
            description: "Your reading and display choices follow you to a new device, and a short setup card helps you turn reminders, widgets, and focus protection back on."
        ),
        WhatsNewFeature(
            icon: "shield.lefthalf.filled",
            accent: .coral,
            title: "A Fuller SOS for Temptation",
            description: "Slow down, name what is pulling at you, fight with Scripture, take one concrete step, and pray. If you stumbled, a path to confession and grace is there too."
        ),
        WhatsNewFeature(
            icon: "tent.fill",
            accent: .purple,
            title: "Southland Camp Verses",
            description: "The Southland 2026 \"Take Courage\" camp verses now have their own track in the Memory tab."
        ),
        WhatsNewFeature(
            icon: "wand.and.stars",
            accent: .navy,
            title: "Polish Throughout",
            description: "Refreshed study sheets, notes, search, and the memory path, plus a round of reliability and performance fixes."
        ),
    ]
}

/// The headline feature of a release, shown as a large card above the feature list.
struct WhatsNewSpotlight {
    struct Highlight {
        let icon: String
        let text: String
    }

    let icon: String
    let eyebrow: String
    let title: String
    let description: String
    let highlights: [Highlight]

    static let current = WhatsNewSpotlight(
        icon: "person.2.fill",
        eyebrow: "Better Together",
        title: "Walk With Friends",
        description: "Scripture sticks when you share it. Add friends, memorize verses together, read side by side, and cheer each other on, all without a single chat message to manage.",
        highlights: [
            Highlight(icon: "qrcode", text: "Add friends with an invite code, a QR scan, or by finding people from your contacts"),
            Highlight(icon: "book.closed.fill", text: "Memorize a verse together, take quizzes, and build a shared streak"),
            Highlight(icon: "book.pages.fill", text: "Read a plan or passage together and see when your friend has read today"),
            Highlight(icon: "paperplane.fill", text: "Challenge a friend with a link that opens straight to the verse"),
        ]
    )
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
