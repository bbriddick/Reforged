import SwiftUI

struct DisplaySettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // Maximum width for option buttons on iPad/Mac
    private var optionRowMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 400 : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Font Size
            VStack(alignment: .leading, spacing: 10) {
                Text("Font Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 8) {
                    ForEach(FontSizeSetting.allCases, id: \.self) { size in
                        FontSizeButton(
                            size: size,
                            isSelected: settings.fontSize == size
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.fontSize = size
                            }
                        }
                    }
                }
                .frame(maxWidth: optionRowMaxWidth, alignment: .leading)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Font Type
            VStack(alignment: .leading, spacing: 10) {
                Text("Font Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 8) {
                    ForEach(FontTypeSetting.allCases, id: \.self) { type in
                        FontTypeButton(
                            type: type,
                            isSelected: settings.fontType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.fontType = type
                            }
                        }
                    }
                }
                .frame(maxWidth: optionRowMaxWidth, alignment: .leading)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Line Spacing
            VStack(alignment: .leading, spacing: 10) {
                Text("Line Spacing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 8) {
                    ForEach(LineSpacingSetting.allCases, id: \.self) { spacing in
                        LineSpacingButton(
                            spacing: spacing,
                            isSelected: settings.lineSpacing == spacing
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.lineSpacing = spacing
                            }
                        }
                    }
                }
                .frame(maxWidth: optionRowMaxWidth, alignment: .leading)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Verse Formatting
            VStack(alignment: .leading, spacing: 10) {
                Text("Verse Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 12) {
                    ForEach(VerseFormattingMode.allCases, id: \.self) { mode in
                        VerseFormatButton(
                            mode: mode,
                            isSelected: settings.verseFormatting == mode
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.verseFormatting = mode
                            }
                        }
                    }
                }
                .frame(maxWidth: optionRowMaxWidth, alignment: .leading)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Theme
            VStack(alignment: .leading, spacing: 10) {
                Text("Theme")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 12) {
                    ForEach(ThemeMode.allCases, id: \.self) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: settings.themeMode == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                settings.themeMode = theme
                            }
                        }
                    }
                }
                .frame(maxWidth: optionRowMaxWidth, alignment: .leading)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Reading Mode
            SettingsToggleRow(
                title: "Reading Mode",
                subtitle: "Hide navigation bars for a distraction-free experience. Tap the text to reveal them.",
                isOn: $settings.readingMode
            )

            SettingsDivider()

            // Preview
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                ScripturePreviewCard()
                    .frame(maxWidth: horizontalSizeClass == .regular ? 500 : nil)
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Reset Button
            SettingsButtonRow(
                title: "Reset Display Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                withAnimation {
                    settings.resetDisplaySettings()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Font Size Button

struct FontSizeButton: View {
    let size: FontSizeSetting
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text("Aa")
                .font(.system(size: fontSize, design: .serif))
                .fontWeight(.medium)
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
    }

    var fontSize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 15
        case .large: return 18
        case .extraLarge: return 21
        }
    }
}

// MARK: - Font Type Button

struct FontTypeButton: View {
    let type: FontTypeSetting
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(type.rawValue)
                .font(displayFont)
                .fontWeight(.medium)
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
    }

    var displayFont: Font {
        .system(size: 12, design: type.fontDesign)
    }
}

// MARK: - Line Spacing Button

struct LineSpacingButton: View {
    let spacing: LineSpacingSetting
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: spacingValue) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isSelected ? Color.white : Color.adaptiveTextSecondary(colorScheme))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 8)
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
    }

    var spacingValue: CGFloat {
        switch spacing {
        case .tight: return 4
        case .normal: return 6
        case .relaxed: return 8
        case .wide: return 10
        }
    }
}

// MARK: - Verse Format Button

struct VerseFormatButton: View {
    let mode: VerseFormattingMode
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode == .verseByVerse ? "list.number" : "text.alignleft")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))

                Text(mode.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Color.adaptiveTextSecondary(colorScheme))
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

// MARK: - Theme Button

struct ThemeButton: View {
    let theme: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : themeIconColor)

                Text(theme.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Color.adaptiveTextSecondary(colorScheme))
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

    var themeIconColor: Color {
        switch theme {
        case .light: return .orange
        case .dark: return .indigo
        case .system: return Color.adaptiveText(colorScheme)
        }
    }
}

// MARK: - Scripture Preview Card

struct ScripturePreviewCard: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: settings.lineSpacing.spacing) {
            Text("For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.")
                .font(settings.scriptureFont)
                .lineSpacing(settings.lineSpacing.spacing)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("— John 3:16")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.reforgedGold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    ScrollView {
        DisplaySettingsSection()
            .padding()
    }
}
