import SwiftUI

// MARK: - Focus Blocking View (Coming Soon)
// Full blocking UI is ready and commented out in FocusBlockingService.swift.
// Re-enable once Apple approves the com.apple.developer.family-controls entitlement.
// Apply at: https://developer.apple.com/contact/request/family-controls-distribution

struct FocusBlockingView: View {
    @Environment(\.colorScheme) var colorScheme

    private let features: [(icon: String, color: Color, title: String, detail: String)] = [
        ("shield.fill",       Color(red: 0.12, green: 0.22, blue: 0.48), "Block Adult Content",  "Automatically shields pornography & adult websites in Safari"),
        ("hand.raised.fill",  Color(red: 0.85, green: 0.45, blue: 0.20), "Block Social Media",   "Block Instagram, TikTok, X, Snapchat, Reddit & more"),
        ("hand.raised.square.fill", Color.purple,                         "Block Specific Apps",  "Choose any installed app you want to lock yourself out of")
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {

                // Hero
                heroCard

                // Feature preview list
                VStack(spacing: 14) {
                    ForEach(features, id: \.title) { feature in
                        featureRow(feature)
                    }
                }

                // Scripture footer
                scriptureFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 40)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Focus & Purity Shield")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.48).opacity(0.18),
                                Color.reforgedGold.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.48),
                                Color.reforgedGold
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Coming Soon")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.reforgedGold)
                        .clipShape(Capsule())
                }

                Text("Guard Your Mind")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("The Focus & Purity Shield will let you block distracting and harmful content right from within Reforged — no third-party apps, no parental controls needed. Just you, choosing to stay focused.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 12, y: 4)
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: (icon: String, color: Color, title: String, detail: String)) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.14))
                    .frame(width: 50, height: 50)
                Image(systemName: feature.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(feature.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Scripture Footer

    private var scriptureFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.reforgedGold)

            Text("\"I have stored up your word in my heart,\nthat I might not sin against you.\"")
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("— Psalm 119:11")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }
}
