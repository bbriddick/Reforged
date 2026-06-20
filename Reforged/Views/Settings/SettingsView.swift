import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation

    var body: some View {
        Group {
            if isSidebarNavigation {
                settingsRoot
            } else {
                NavigationStack {
                    settingsRoot
                }
            }
        }
    }

    var settingsRoot: some View {
        List {
            // Profile / Account header — taps into Account settings
            Section {
                NavigationLink {
                    SettingsDetailPage(title: SettingsSection.account.rawValue) {
                        AccountSettingsSection()
                    }
                } label: {
                    accountRow
                }
            }

            Section("Reading") {
                sectionNavRow(.display,       hint: settings.themeMode.rawValue)
                sectionNavRow(.bibleReading,  hint: settings.defaultTranslation.rawValue)
                sectionNavRow(.audio)
            }

            Section("Learning") {
                sectionNavRow(.memory)
            }

            Section("Personalization") {
                sectionNavRow(.notifications, hint: settings.notificationsEnabled ? "On" : "Off")
                sectionNavRow(.ai,            hint: settings.aiEnabled ? "On" : "Off")
            }

            Section {
                sectionNavRow(.about)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Settings")
    }

    private var accountRow: some View {
        HStack(spacing: 14) {
            if AppleSignInService.shared.isSignedIn {
                ProfileAvatarView(size: 50)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundStyle(Color.teal)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if AppleSignInService.shared.isSignedIn {
                    Text(appState.user.displayName.isEmpty
                         ? appState.user.firstName
                         : appState.user.displayName)
                        .font(.headline)
                    Text(AppleSignInService.shared.userEmail ?? "Apple ID")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Signed in with Apple")
                            .font(.caption2)
                            .foregroundStyle(Color.green)
                    }
                } else {
                    Text("Sign in to Reforged")
                        .font(.headline)
                    Text("Sync progress across your devices")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Text("Tap to get started →")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.teal)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func sectionNavRow(_ section: SettingsSection, hint: String? = nil) -> some View {
        NavigationLink {
            SettingsDetailPage(title: section.rawValue) {
                sectionContent(section)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(section.color.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: section.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(section.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(section.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .display:      DisplaySettingsSection()
        case .bibleReading: BibleReadingSettingsSection()
        case .audio:        AudioSettingsSection()
        case .memory:       MemorySettingsSection()
        case .notifications: NotificationSettingsSection()
        case .account:      AccountSettingsSection()
        case .ai:           AISettingsSection()
        case .about:        HelpAndSupportView()
        }
    }
}

// MARK: - Settings Detail Page

struct SettingsDetailPage<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.colorScheme) var colorScheme

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content.padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
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
