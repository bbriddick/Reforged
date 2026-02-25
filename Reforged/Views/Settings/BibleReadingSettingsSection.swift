import SwiftUI

struct BibleReadingSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Default Translation
            VStack(alignment: .leading, spacing: 10) {
                Text("Default Translation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack {
                    ForEach(BibleTranslation.allCases) { translation in
                        TranslationButton(
                            translation: translation,
                            isSelected: settings.defaultTranslation == translation
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.defaultTranslation = translation
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Show Superscript Verse Numbers
            SettingsToggleRow(
                title: "Superscript Verse Numbers",
                subtitle: "Display verse numbers in smaller, raised text",
                isOn: $settings.showSuperscriptVerseNumbers
            )

            SettingsDivider()

            // Show Paragraph Headings
            SettingsToggleRow(
                title: "Show Paragraph Headings",
                subtitle: "Display section headings when available",
                isOn: $settings.showParagraphHeadings
            )

            SettingsDivider()

            // Auto-restore Reading Location
            SettingsToggleRow(
                title: "Remember Reading Position",
                subtitle: "Return to your last reading location when opening the Bible",
                isOn: $settings.autoRestoreReadingLocation
            )

            SettingsDivider()

            // Persistent Chapter Navigation
            SettingsToggleRow(
                title: "Chapter Navigation Arrows",
                subtitle: "Show navigation arrows to quickly move between chapters",
                isOn: $settings.persistentChapterNavigation
            )

            SettingsDivider()

            // Reset Button
            SettingsButtonRow(
                title: "Reset Bible Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                withAnimation {
                    settings.resetBibleSettings()
                }
            }
        }
    }
}

// MARK: - Translation Button

struct TranslationButton: View {
    let translation: BibleTranslation
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(translation.rawValue)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))

                Text(translation.copyright)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.adaptiveTextSecondary(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        BibleReadingSettingsSection()
            .padding()
    }
}
