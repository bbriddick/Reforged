import SwiftUI

// MARK: - "Finish setting up this device"
//
// After a restore, a few things are tied to the device itself and can't come from the
// cloud: notification permission, the home-screen widget, optional commentary downloads,
// and focus protection. (KJV and the study texts ship with the app, so there is no Bible
// download step.) They live in one calm, dismissible card on Home. Preferences
// (translation, theme, font, reminder time) were already restored silently.

@MainActor
final class DeviceSetup: ObservableObject {
    static let shared = DeviceSetup()

    @Published private(set) var isActive: Bool
    @Published private(set) var remindersDone: Bool
    @Published private(set) var widgetDone: Bool
    /// Commentary downloads (stored under the original "offline" key so progress carries over).
    @Published private(set) var offlineDone: Bool
    @Published private(set) var focusDone: Bool
    /// Optional: bringing saved verses over from another Bible app. Never blocks the card
    /// from finishing, since plenty of people have nothing to import.
    @Published private(set) var importDone: Bool

    private(set) var reminders: SyncedPreferences.ReminderPreferences?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let active = "deviceSetup.active"
        static let reminders = "deviceSetup.reminders"
        static let remindersDone = "deviceSetup.remindersDone"
        static let widgetDone = "deviceSetup.widgetDone"
        static let offlineDone = "deviceSetup.offlineDone"
        static let importDone = "deviceSetup.importDone"
        static let focusDone = "deviceSetup.focusDone"
    }

    private init() {
        isActive = defaults.bool(forKey: Key.active)
        remindersDone = defaults.bool(forKey: Key.remindersDone)
        widgetDone = defaults.bool(forKey: Key.widgetDone)
        offlineDone = defaults.bool(forKey: Key.offlineDone)
        importDone = defaults.bool(forKey: Key.importDone)
        focusDone = defaults.bool(forKey: Key.focusDone)
        if let data = defaults.data(forKey: Key.reminders) {
            reminders = try? JSONDecoder().decode(SyncedPreferences.ReminderPreferences.self, from: data)
        }
    }

    /// Whether the person had reminders running on their other device.
    var hadReminders: Bool { reminders?.anyOn == true }

    /// Called once when an account is restored on this device.
    func activate(reminders: SyncedPreferences.ReminderPreferences?) {
        self.reminders = reminders
        if let reminders, let data = try? JSONEncoder().encode(reminders) { defaults.set(data, forKey: Key.reminders) }
        remindersDone = false; widgetDone = false; offlineDone = false; importDone = false; focusDone = false
        defaults.set(false, forKey: Key.importDone)
        defaults.set(false, forKey: Key.focusDone)
        defaults.set(false, forKey: Key.remindersDone)
        defaults.set(false, forKey: Key.widgetDone)
        defaults.set(false, forKey: Key.offlineDone)
        isActive = true
        defaults.set(true, forKey: Key.active)
    }

    func dismiss() {
        isActive = false
        defaults.set(false, forKey: Key.active)
    }

    func markWidgetDone() { widgetDone = true; defaults.set(true, forKey: Key.widgetDone); finishIfComplete() }
    func markImportDone() { importDone = true; defaults.set(true, forKey: Key.importDone) }
    func markFocusDone() { focusDone = true; defaults.set(true, forKey: Key.focusDone); finishIfComplete() }
    func markOfflineDone() { offlineDone = true; defaults.set(true, forKey: Key.offlineDone); finishIfComplete() }

    /// Asks for permission on THIS device, then turns on the same reminders they had before.
    func enableReminders() {
        NotificationManager.shared.requestAuthorization { [weak self] granted in
            guard let self, granted, let r = self.reminders else { return }
            let s = SettingsManager.shared
            s.dailyMemoryReminders = r.dailyMemory
            s.readingPlanReminders = r.readingPlan
            s.memoryReviewReminders = r.memoryReview
            s.lessonReminders = r.lesson
            s.streakFreezeReminders = r.streakFreeze
            s.notificationsEnabled = true
            self.remindersDone = true
            self.defaults.set(true, forKey: Key.remindersDone)
            self.finishIfComplete()
        }
    }

    private func finishIfComplete() {
        let remindersSettled = !hadReminders || remindersDone
        if remindersSettled && widgetDone && offlineDone && focusDone { dismiss() }
    }
}

struct DeviceSetupCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var setup = DeviceSetup.shared
    @State private var showWidgetHelp = false
    @State private var showCommentaries = false
    @State private var showFocus = false
    @State private var showImport = false

    private var reminderTime: String {
        guard let time = setup.reminders?.time else { return "" }
        return time.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        if setup.isActive {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finish setting up this device")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("Your settings are already here.")
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Button { withAnimation { setup.dismiss() } } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Dismiss")
                    .padding(.trailing, -10).padding(.top, -10)
                }
                .padding(.bottom, 6)

                if setup.hadReminders {
                    row(icon: "bell.fill", title: "Daily reminder, \(reminderTime)",
                        subtitle: "Needs permission on this device",
                        done: setup.remindersDone, action: "Turn on") { setup.enableReminders() }
                }
                row(icon: "square.grid.2x2.fill", title: "Home-screen widget",
                    subtitle: "See your streak at a glance",
                    done: setup.widgetDone, action: "Show me") { showWidgetHelp = true }
                row(icon: "text.book.closed.fill", title: "Commentaries",
                    subtitle: "Download them for offline study",
                    done: setup.offlineDone, action: "Download") { showCommentaries = true }
                row(icon: "shield.lefthalf.filled", title: "Focus protection",
                    subtitle: "Block adult content and distracting apps",
                    done: setup.focusDone || FocusBlockingService.shared.isAnyBlockingActive,
                    action: "Set up") { showFocus = true }
                row(icon: "arrow.triangle.swap", title: "Bring your verses",
                    subtitle: "Coming from YouVersion? Import saved verses",
                    done: setup.importDone, action: "Import") { showImport = true }

                Button {
                    AppTour.shared.start()
                } label: {
                    Text("New to this device? Take a 60-second tour")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)
            .sheet(isPresented: $showWidgetHelp, onDismiss: { setup.markWidgetDone() }) { WidgetHelpSheet() }
            .sheet(isPresented: $showCommentaries, onDismiss: { setup.markOfflineDone() }) {
                NavigationStack {
                    ScrollView {
                        CommentaryDownloadsView().padding()
                    }
                    .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
                    .navigationTitle("Commentaries")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showCommentaries = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showFocus, onDismiss: { setup.markFocusDone() }) {
                NavigationStack {
                    FocusBlockingView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showFocus = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showImport, onDismiss: { setup.markImportDone() }) {
                NavigationStack {
                    SwitchFromYouVersionView()
                        .environmentObject(AppState.shared)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showImport = false }
                            }
                        }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func row(icon: String, title: String, subtitle: String, done: Bool,
                     action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 34, height: 34)
                .background(Color.reforgedGold.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle).font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.4))
            } else {
                Button(action: perform) {
                    Text(action)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(Color.reforgedCoral))
                }
                .buttonStyle(NoBlobButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
    }
}

private struct WidgetHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add the Reforged widget")
                    .font(.title2.bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                ForEach(Array(["Touch and hold an empty spot on your Home Screen.",
                               "Tap the + button in the top corner.",
                               "Search for Reforged and choose a widget.",
                               "Tap Add Widget, then Done."].enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.reforgedGold)
                            .frame(width: 28, height: 28)
                            .background(Color.reforgedGold.opacity(0.14), in: Circle())
                        Text(text).font(.body).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
                Spacer()
            }
            .padding(24)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
