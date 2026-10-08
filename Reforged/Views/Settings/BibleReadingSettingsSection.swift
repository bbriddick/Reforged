import SwiftUI

struct BibleReadingSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showReorder = false
    @State private var showManageBibles = false

    var body: some View {
        VStack(spacing: 0) {
            translationBlock

            groupHeader("Display")
            SettingsToggleRow(
                title: "Superscript Verse Numbers",
                subtitle: "Display verse numbers in smaller, raised text",
                isOn: $settings.showSuperscriptVerseNumbers
            )
            SettingsDivider()
            SettingsToggleRow(
                title: "Show Paragraph Headings",
                subtitle: "Display section headings when available",
                isOn: $settings.showParagraphHeadings
            )

            groupHeader("Navigation")
            SettingsToggleRow(
                title: "Remember Reading Position",
                subtitle: "Return to your last reading location when opening the Bible",
                isOn: $settings.autoRestoreReadingLocation
            )
            SettingsDivider()
            SettingsToggleRow(
                title: "Chapter Navigation Arrows",
                subtitle: "Show navigation arrows to quickly move between chapters",
                isOn: $settings.persistentChapterNavigation
            )

            groupHeader("Original Languages")
            SettingsToggleRow(
                title: "Original Language Text",
                subtitle: "Show Textus Receptus (Greek NT) and Westminster Leningrad Codex (Hebrew OT) in word study",
                isOn: $settings.showOriginalLanguageText
            )
            SettingsDivider()
            SettingsToggleRow(
                title: "Original Languages in Switcher",
                subtitle: "Add TR (Greek NT) and WLC (Hebrew OT) as readable versions in the translation menu",
                isOn: $settings.showOriginalLanguagesInSwitcher
            )

            groupHeader("Offline Commentaries")
            CommentaryDownloadsView()
                .padding(.bottom, 6)

            groupHeader("Streak")
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
                .padding(.top, 14)

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

    // MARK: - Pieces

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private var translationBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Default Translation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Button {
                    showReorder = true
                } label: {
                    Label("Reorder", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.defaultTranslation.fullName)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(settings.defaultTranslation.copyright)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { showManageBibles = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Bibles")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("Offline reading, downloads, Greek & Hebrew")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .sheet(isPresented: $showReorder) {
            TranslationReorderSheet(translationOrder: $settings.translationOrder)
        }
        .sheet(isPresented: $showManageBibles) { ManageBiblesView() }
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
            Text(translation.rawValue)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(translation.fullName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

#if false
#Preview {
    ScrollView {
        BibleReadingSettingsSection()
            .padding()
    }
}
#endif
