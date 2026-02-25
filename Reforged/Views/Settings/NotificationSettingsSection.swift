import SwiftUI

struct NotificationSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showTimePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Master Toggle
            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Enable Notifications",
                    subtitle: "Receive reminders and updates from Reforged",
                    isOn: $settings.notificationsEnabled
                )
            }

            if settings.notificationsEnabled {
                SettingsDivider()

                // Daily Reminder Time
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Reminder Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("When to send your daily devotion reminder")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()

                        Button(action: { showTimePicker.toggle() }) {
                            Text(settings.dailyReminderTime.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if showTimePicker {
                        DatePicker(
                            "Reminder Time",
                            selection: $settings.dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 150)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 10)

                SettingsDivider()

                // Notification Categories
                Text("Notification Types")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                // Reading Plan Reminders
                SettingsToggleRow(
                    title: "Reading Plan Reminders",
                    subtitle: "Get reminded to complete your daily reading",
                    isOn: $settings.readingPlanReminders
                )

                SettingsDivider()

                // Memory Review Reminders
                SettingsToggleRow(
                    title: "Memory Review Reminders",
                    subtitle: "Notifications when verses are due for review",
                    isOn: $settings.memoryReviewReminders
                )

                SettingsDivider()

                // Lesson Reminders
                SettingsToggleRow(
                    title: "Lesson Reminders",
                    subtitle: "Reminders to continue learning tracks",
                    isOn: $settings.lessonReminders
                )
            }

            SettingsDivider()

            // Notification Permissions Info
            NotificationPermissionStatus()
                .padding(.vertical, 10)

            SettingsDivider()

            // Reset Button
            SettingsButtonRow(
                title: "Reset Notification Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                withAnimation {
                    settings.resetNotificationSettings()
                }
            }
        }
    }
}

// MARK: - Notification Permission Status

struct NotificationPermissionStatus: View {
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Notification Permission")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            if permissionStatus == .denied {
                Button(action: openSettings) {
                    Text("Settings")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.reforgedNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else if permissionStatus == .notDetermined {
                Button(action: requestPermission) {
                    Text("Enable")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.reforgedNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .task {
            await checkPermissionStatus()
        }
    }

    var statusColor: Color {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .reforgedCoral
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    var statusIcon: String {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    var statusMessage: String {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are enabled"
        case .denied:
            return "Notifications are disabled in system settings"
        case .notDetermined:
            return "Permission not yet requested"
        @unknown default:
            return "Unknown status"
        }
    }

    func checkPermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    func requestPermission() {
        NotificationManager.shared.requestAuthorization()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            await checkPermissionStatus()
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ScrollView {
        NotificationSettingsSection()
            .padding()
    }
}
