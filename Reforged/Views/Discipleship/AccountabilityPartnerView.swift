import SwiftUI

// MARK: - Accountability Partner View
//
// Partner contact, the tamper log (clearable only with the partner's PIN), and
// the user-sent weekly report. Honest about the iOS boundary: Reforged can't
// message anyone itself and can't see browsing content — what it CAN show is
// whether protection stood all week and every time it was lowered.

struct AccountabilityPartnerView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var partnerService = AccountabilityPartnerService.shared
    @StateObject private var lockService = AccountabilityLockService.shared
    @StateObject private var streakService = ShieldStreakService.shared

    @State private var showReportComposer = false
    @State private var showClearLogPIN = false
    @State private var showReminderOptIn = false
    /// Tracks the partner-name field so the reminder ask waits until the user has
    /// finished typing (`hasPartner` flips true on the very first character).
    @FocusState private var nameFieldFocused: Bool

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private static let eventFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Form {
            Section {
                TextField("Partner's name", text: $partnerService.partnerName)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                TextField("Partner's phone", text: $partnerService.partnerPhone)
                    .keyboardType(.phonePad)
            } header: {
                Text("Your Partner")
            } footer: {
                Text("Pick someone who will actually ask you the hard questions. Have them set the Accountability PIN so protection can't be lowered without them.")
            }

            Section {
                Button {
                    HapticManager.shared.buttonTap()
                    showReportComposer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Send Weekly Report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!partnerService.hasPartner)
                Toggle("Weekly reminder", isOn: $partnerService.reminderEnabled)
                    .tint(Color.reforgedGold)
                    .disabled(!partnerService.hasPartner)

                if partnerService.reminderEnabled && partnerService.hasPartner {
                    Picker("Day", selection: $partnerService.reminderDay) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Self.weekdayNames[day - 1]).tag(day)
                        }
                    }
                    DatePicker("Time", selection: $partnerService.reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Weekly Report")
            } footer: {
                Text("Reforged can't send messages for you — tap to review and send your report yourself. It covers your protection status, streak, shield encounters, and any protection changes. The reminder just nudges you; it never sends anything on its own.")
            }

            Section {
                if partnerService.tamperLog.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.green)
                        Text("No protection changes recorded.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                } else {
                    ForEach(partnerService.tamperLog.suffix(30).reversed()) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.kind.title)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text(event.detail)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            Text(Self.eventFormatter.string(from: event.date))
                                .font(.caption2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.vertical, 2)
                    }

                    if lockService.isLockEnabled {
                        Button(role: .destructive) {
                            showClearLogPIN = true
                        } label: {
                            Text("Clear Log (partner PIN)")
                        }
                    }
                }
            } header: {
                Text("Protection Log")
            } footer: {
                Text("Every time protection is lowered — even with the PIN — it's recorded here. If Reforged is deleted or Screen Time access is revoked, blocking stops; that's an iOS boundary worth telling your partner about.")
            }
        }
        .navigationTitle("Accountability")
        .navigationBarTitleDisplayMode(.inline)
        // One-time ask once a partner actually exists — reminders are opt-in, so
        // this is the only place the toggle ever gets suggested. Fires when the
        // name field is committed, not mid-typing.
        .onChange(of: nameFieldFocused) { isFocused in
            guard !isFocused else { return }
            if partnerService.hasPartner
                && !partnerService.hasPromptedForReminder
                && !partnerService.reminderEnabled {
                showReminderOptIn = true
            }
        }
        .alert("Weekly reminder?", isPresented: $showReminderOptIn) {
            Button("Yes, remind me") {
                partnerService.hasPromptedForReminder = true
                NotificationManager.shared.requestAuthorization()
                partnerService.reminderEnabled = true
            }
            Button("No thanks", role: .cancel) {
                partnerService.hasPromptedForReminder = true
            }
        } message: {
            Text("Reports only help if they actually get sent. Want a nudge every Sunday evening to send yours?")
        }
        .sheet(isPresented: $showReportComposer) {
            reportSheet
        }
        .sheet(isPresented: $showClearLogPIN) {
            PINEntryView(mode: .verify, lockService: lockService) { success in
                if success {
                    partnerService.clearLogVerified()
                }
            }
        }
    }

    @ViewBuilder
    private var reportSheet: some View {
        if MessageComposeView.canSendText && !partnerService.partnerPhone.isEmpty {
            MessageComposeView(
                recipients: [partnerService.partnerPhone],
                body: partnerService.weeklyReportText()
            ) {
                showReportComposer = false
            }
            .ignoresSafeArea()
        } else {
            // No SMS available (iPad/simulator, or no phone number) — share sheet.
            ReportShareSheet(text: partnerService.weeklyReportText())
        }
    }
}

/// Plain share-sheet fallback for the weekly report.
private struct ReportShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
