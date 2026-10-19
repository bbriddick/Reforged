import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation
    @State private var showSetupConfirmation = false

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
                sectionNavRow(.widgets,       hint: AppState.shared.equippedItem(.widget)?.name)
            }

            Section("Friends and switching") {
                NavigationLink { SwitchFromYouVersionView() } label: {
                    switchRow(icon: "arrow.triangle.swap", title: "Coming from YouVersion?",
                              subtitle: "Bring your verses and plan progress")
                }
                NavigationLink { SwitchKitView() } label: {
                    switchRow(icon: "paperplane.fill", title: "Send the switch kit",
                              subtitle: "A poster and note for friends who haven't switched")
                }
            }

            Section {
                sectionNavRow(.about)
            }

            Section {
                Button {
                    HapticManager.shared.buttonTap()
                    AppTour.shared.start()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                            .frame(width: 30, height: 30)
                            .background(Color.reforgedGold.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text("Take the app tour")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    HapticManager.shared.buttonTap()
                    DeviceSetup.shared.activate(reminders: DeviceSetup.shared.reminders)
                    showSetupConfirmation = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "checklist")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.reforgedCoral)
                            .frame(width: 30, height: 30)
                            .background(Color.reforgedCoral.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text("Show setup checklist")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("A quick walkthrough of the main features, or bring back the setup checklist on Home.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Settings")
        .alert("Checklist added to Home", isPresented: $showSetupConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The \u{201C}Finish setting up this device\u{201D} card is back at the top of Home.")
        }
    }

    private var accountRow: some View {
        HStack(spacing: 16) {
            if AppleSignInService.shared.isSignedIn {
                ProfileAvatarView(size: 60)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 2) {
                if AppleSignInService.shared.isSignedIn {
                    Text(appState.user.displayName.isEmpty
                         ? appState.user.firstName
                         : appState.user.displayName)
                        .font(.title3.weight(.semibold))
                    Text(AppleSignInService.shared.userEmail ?? "Apple ID")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("Sign in to Reforged")
                        .font(.title3.weight(.semibold))
                    Text("Sync progress across your devices")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func sectionNavRow(_ section: SettingsSection, hint: String? = nil) -> some View {
        NavigationLink {
            SettingsDetailPage(title: section.rawValue) {
                sectionContent(section)
            }
        } label: {
            HStack(spacing: 14) {
                // One quiet brand tint for every row: gold glyph on a soft gold wash.
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 30, height: 30)
                    .background(Color.reforgedGold.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(section.rawValue)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                if let hint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func switchRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.reforgedCoral)
                .frame(width: 30, height: 30)
                .background(Color.reforgedCoral.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle).font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(.vertical, 2)
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
        case .widgets:      WidgetSettingsSection()
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

#if false
#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
#endif
