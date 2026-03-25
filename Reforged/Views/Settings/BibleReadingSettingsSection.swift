import SwiftUI

struct BibleReadingSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showReorder = false

    var body: some View {
        VStack(spacing: 0) {
            // Default Translation
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Default Translation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Button {
                        showReorder = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text("Reorder")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(Color.reforgedNavy)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    ForEach(settings.translationOrder) { translation in
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
            .sheet(isPresented: $showReorder) {
                TranslationReorderSheet(translationOrder: $settings.translationOrder)
            }

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

            // Day Boundary
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bedtime")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Reading before your bedtime counts toward that day's streak. Set this if you're a night owl who reads past midnight.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker("Bedtime", selection: $settings.dayStartHour) {
                    Text("Midnight").tag(0)
                    Text("1:00 AM").tag(1)
                    Text("2:00 AM").tag(2)
                    Text("3:00 AM").tag(3)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Original Language Text (Word Study)
            SettingsToggleRow(
                title: "Original Language Text",
                subtitle: "Show Textus Receptus (Greek NT) and Westminster Leningrad Codex (Hebrew OT) in word study",
                isOn: $settings.showOriginalLanguageText
            )

            SettingsDivider()

            // Original Languages in Version Switcher
            SettingsToggleRow(
                title: "Original Languages in Switcher",
                subtitle: "Add TR (Greek NT) and WLC (Hebrew OT) as readable versions in the translation menu",
                isOn: $settings.showOriginalLanguagesInSwitcher
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

// MARK: - Translation Reorder Sheet

struct TranslationReorderSheet: View {
    @Binding var translationOrder: [BibleTranslation]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(translationOrder) { translation in
                        HStack(spacing: 12) {
                            Text(translation.rawValue)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 36)
                                .background(Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(translation.fullName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(translation.copyright)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { from, to in
                        translationOrder.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("Drag to set the order they appear in the switcher")
                        .textCase(nil)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .navigationTitle("Reorder Translations")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        BibleReadingSettingsSection()
            .padding()
    }
}
