import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation

    @State private var expandedSections: Set<SettingsSection> = [.display]

    var body: some View {
        Group {
            if isSidebarNavigation {
                settingsContent
            } else {
                NavigationStack {
                    settingsContent
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.large)
                }
            }
        }
    }

    var settingsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSectionView(
                        section: section,
                        isExpanded: expandedSections.contains(section),
                        toggle: { toggleSection(section) }
                    )
                }
            }
            .padding(.vertical)
            .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    private func toggleSection(_ section: SettingsSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
}

// MARK: - Settings Section View

struct SettingsSectionView: View {
    let section: SettingsSection
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: toggle) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(section.color.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(section.color)
                    }

                    Text(section.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.adaptiveCardBackground(colorScheme))
            }
            .buttonStyle(.plain)

            // Section Content
            if isExpanded {
                VStack(spacing: 0) {
                    sectionContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.adaptiveBackground(colorScheme))
            }

            // Divider
            Divider()
                .background(Color.adaptiveBorder(colorScheme))
        }
    }

    @ViewBuilder
    var sectionContent: some View {
        switch section {
        case .display:
            DisplaySettingsSection()
        case .bibleReading:
            BibleReadingSettingsSection()
        case .audio:
            AudioSettingsSection()
        case .memory:
            MemorySettingsSection()
        case .notifications:
            NotificationSettingsSection()
        case .account:
            AccountSettingsSection()
        case .about:
            AboutSection()
        }
    }
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    @Environment(\.colorScheme) var colorScheme

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Color.reforgedGold)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

struct SettingsPickerRow<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let title: String
    let subtitle: String?
    @Binding var selection: T
    @Environment(\.colorScheme) var colorScheme

    init(title: String, subtitle: String? = nil, selection: Binding<T>) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            Picker("", selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 10)
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String?
    let value: String?
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    init(title: String, subtitle: String? = nil, value: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10)
    }
}

struct SettingsButtonRow: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    init(title: String, icon: String? = nil, color: Color = .reforgedNavy, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Divider()
            .background(Color.adaptiveBorder(colorScheme).opacity(0.5))
            .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
