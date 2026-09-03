import SwiftUI
import FamilyControls

// MARK: - Focus Blocking View
//
// The Focus & Purity Shield home. Structured around what the user needs, in
// order: is it protecting me right now, the one urgent action, what's live, and
// only then the settings.
//
// Everything set-once (social strategy, schedules, focus sessions, partner)
// lives one push away in its own screen. Earlier this screen carried eleven
// full-weight cards with every control expanded inline, which read as a wall
// with no hierarchy — the grouped rows here (see ShieldComponents.swift) are
// the fix.

struct FocusBlockingView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var lockService = AccountabilityLockService.shared
    @StateObject private var limitService = SocialLimitService.shared
    @StateObject private var gateService = UnlockGateService.shared
    @StateObject private var scheduleService = ScheduledBlockingService.shared
    @StateObject private var sessionService = FocusSessionService.shared
    @StateObject private var streakService = ShieldStreakService.shared
    @StateObject private var partnerService = AccountabilityPartnerService.shared

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showTemptedSOS = false

    // Onboarding + accountability lock
    @State private var showOnboarding = false
    @State private var showLockSetup = false
    @State private var showRemoveLock = false
    @State private var showPINVerify = false
    /// Action to run after the accountability PIN is verified (e.g. lowering protection).
    @State private var pendingUnlockAction: (() -> Void)? = nil

    /// Keeps the social countdown fresh while the screen is open (usage is
    /// written in the background by the monitor extension).
    private let usageTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private static let onboardingSeenKey = "hasSeenShieldOnboarding"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                statusCard

                temptedButton

                if !focusService.isAuthorized {
                    authorizationCard
                }

                activeNowSection

                protectionSection

                accountabilitySection

                scriptureFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Focus & Purity Shield")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.shared.buttonTap()
                    showOnboarding = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("How it works")
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onChange(of: showAppPicker) { isPresenting in
            // Commit the chosen apps when the picker is dismissed.
            if !isPresenting {
                focusService.updateSelection(pickerSelection)
            }
        }
        .onAppear {
            pickerSelection = focusService.selection
            // Authorization can read stale at launch — re-check so the "Enable
            // Blocking" card doesn't show when access is already granted.
            focusService.refreshAuthorizationStatus()
            limitService.reloadUsage()
            gateService.refresh()
            scheduleService.reconcileNow()
            sessionService.reconcile()
            streakService.recompute()
            // Needed so the shield extension can fire "you hit a block" notifications.
            NotificationManager.shared.requestAuthorization()
            if !UserDefaults.standard.bool(forKey: Self.onboardingSeenKey) {
                showOnboarding = true
            }
        }
        .onReceive(usageTimer) { _ in
            if limitService.isEnabled { limitService.reloadUsage() }
        }
        .fullScreenCover(isPresented: $showTemptedSOS) {
            TemptedSOSView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            ShieldOnboardingView {
                UserDefaults.standard.set(true, forKey: Self.onboardingSeenKey)
                showOnboarding = false
            }
        }
        .sheet(isPresented: $showLockSetup) {
            PINEntryView(mode: .setup, lockService: lockService) { _ in }
        }
        .sheet(isPresented: $showRemoveLock) {
            PINEntryView(mode: .remove, lockService: lockService) { success in
                if success {
                    AccountabilityPartnerService.shared.record(.lockRemoved, detail: "The accountability PIN was removed — protection changes no longer need a partner.")
                }
            }
        }
        .sheet(isPresented: $showPINVerify, onDismiss: { pendingUnlockAction = nil }) {
            PINEntryView(mode: .verify, lockService: lockService) { success in
                if success { pendingUnlockAction?() }
                pendingUnlockAction = nil
            }
        }
    }

    // MARK: - Lock helpers

    /// Runs `action` immediately, unless the accountability lock is on — in which case
    /// it requires the partner's PIN first. Use for any change that LOWERS protection.
    private func guardedReduce(_ action: @escaping () -> Void) {
        if lockService.isLockEnabled {
            HapticManager.shared.warning()
            pendingUnlockAction = action
            showPINVerify = true
        } else {
            action()
        }
    }

    /// A toggle binding that allows turning protection ON freely but requires the PIN to turn it OFF.
    private func protectionBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(
            get: get,
            set: { newValue in
                if newValue {
                    set(true)
                } else {
                    guardedReduce { set(false) }
                }
            }
        )
    }

    // MARK: - Status

    /// Whether anything at all is guarding the user right now.
    private var isProtected: Bool {
        focusService.isAnyBlockingActive
        || limitService.isEnabled
        || gateService.isEnabled
        || scheduleService.schedules.contains { $0.isEnabled && $0.hasSelection }
    }

    /// One-line summary of every protection that's on.
    private var statusDetail: String {
        guard isProtected else { return "Nothing is shielded yet — choose what to guard below." }
        var parts: [String] = []
        if focusService.blockNSFW { parts.append("Adult content") }
        if let social = socialModeValue { parts.append(social) }
        let apps = focusService.selectedAppCount
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        let schedules = scheduleService.schedules.filter { $0.isEnabled && $0.hasSelection }.count
        if schedules > 0 { parts.append("\(schedules) schedule\(schedules == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isProtected ? Color.green : Color.reforgedCoral).opacity(0.14))
                    .frame(width: 54, height: 54)
                Image(systemName: isProtected ? "shield.lefthalf.filled" : "shield.slash.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isProtected ? Color.green : Color.reforgedCoral)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isProtected ? "Protected" : "Not protected")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if streakService.currentStreak > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.reforgedGold)
                    Text("\(streakService.currentStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("days")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(streakService.currentStreak) protected days")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke((isProtected ? Color.green : Color.reforgedCoral).opacity(0.30), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.07), radius: 10, y: 4)
    }

    // MARK: - Tempted (the one urgent action)

    private var temptedButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            showTemptedSOS = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.brakesignal")
                    .font(.system(size: 16, weight: .semibold))
                Text("I'm Being Tempted")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.reforgedCoral)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.reforgedCoral.opacity(0.30), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Authorization

    private var authorizationCard: some View {
        VStack(spacing: 14) {
            Text("Enable Screen Time access so Reforged can shield the content you choose.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await focusService.requestAuthorization() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Enable Blocking")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.reforgedGold, Color.reforgedCoral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Active Now
    //
    // Only rendered when something is actually live, so the screen stays quiet
    // when there's nothing to report.

    private var hasActiveNow: Bool {
        sessionService.isSessionActive
        || (limitService.isEnabled && limitService.hasSelection)
        || gateService.isGateActive
        || !scheduleService.activeIds.isEmpty
    }

    @ViewBuilder
    private var activeNowSection: some View {
        if hasActiveNow {
            VStack(spacing: 8) {
                ShieldSectionLabel("Active now")

                ShieldSectionCard {
                    if let session = sessionService.activeSession, sessionService.isSessionActive {
                        activeSessionRow(session)
                    }

                    if limitService.isEnabled && limitService.hasSelection {
                        if sessionService.isSessionActive { ShieldRowDivider() }
                        activeLimitRow
                    }

                    if gateService.isGateActive {
                        if sessionService.isSessionActive || (limitService.isEnabled && limitService.hasSelection) {
                            ShieldRowDivider()
                        }
                        activeGateRow
                    }

                    ForEach(activeSchedules, id: \.id) { schedule in
                        ShieldRowDivider()
                        activeScheduleRow(schedule)
                    }
                }
            }
        }
    }

    private var activeSchedules: [BlockSchedule] {
        scheduleService.schedules.filter { scheduleService.activeIds.contains($0.id) }
    }

    private func activeSessionRow(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, session.endsAt.timeIntervalSince(context.date))
            let total = session.endsAt.timeIntervalSince(session.startedAt)
            let fraction = total > 0 ? 1 - remaining / total : 1

            NavigationLink(destination: FocusSessionView(sessionService: sessionService, guardedReduce: guardedReduce)) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ShieldRowIcon(systemName: "timer", color: .teal)
                        Text("Focus session")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Text(timeString(remaining))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.teal)
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.18))
                            Capsule().fill(Color.teal)
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: 5)
                    .padding(.leading, 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var activeLimitRow: some View {
        NavigationLink(destination: SocialMediaView(guardedReduce: guardedReduce)) {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: limitService.isLimitReached ? "lock.fill" : "hourglass",
                              color: limitService.isLimitReached ? Color.reforgedCoral : Color(red: 0.20, green: 0.55, blue: 0.55))
                Text(limitService.isLimitReached ? "Social time is up for today" : "Social time left")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                if !limitService.isLimitReached {
                    Text("\(limitService.remainingMinutes) min")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 0.55))
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var activeGateRow: some View {
        NavigationLink(destination: SocialMediaView(guardedReduce: guardedReduce)) {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: "book.closed.fill", color: Color.reforgedGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Word comes first")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Social opens once you read or memorize today")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func activeScheduleRow(_ schedule: BlockSchedule) -> some View {
        NavigationLink(destination: SchedulesListView(scheduleService: scheduleService, guardedReduce: guardedReduce)) {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: "moon.stars.fill", color: .indigo)
                Text(schedule.label)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text("On")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.green))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Protection

    /// Nil when no social strategy is active — keeps it out of the status line.
    private var socialModeValue: String? {
        if focusService.blockSocialMedia { return "Always blocked" }
        if gateService.isEnabled { return "Word first" }
        if limitService.isEnabled { return "Daily limit" }
        return nil
    }

    private var protectionSection: some View {
        VStack(spacing: 8) {
            ShieldSectionLabel("Protection")

            ShieldSectionCard {
                ShieldToggleRow(
                    icon: "shield.fill",
                    color: focusService.blockNSFW ? .green : Color.adaptiveTextSecondary(colorScheme),
                    title: "Adult content",
                    detail: "Blocks pornography & adult sites in Safari",
                    locked: lockService.isLockEnabled,
                    isOn: protectionBinding(
                        get: { focusService.blockNSFW },
                        set: { newValue in
                            if !newValue {
                                AccountabilityPartnerService.shared.record(.protectionLowered, detail: "Adult-content blocking turned off.")
                            }
                            Task { await focusService.setBlockNSFW(newValue) }
                        }
                    )
                )

                ShieldRowDivider()

                ShieldNavRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    color: socialModeValue == nil ? Color.adaptiveTextSecondary(colorScheme) : .green,
                    title: "Social media",
                    value: socialModeValue ?? "Off"
                ) {
                    SocialMediaView(guardedReduce: guardedReduce)
                }

                ShieldRowDivider()

                ShieldButtonRow(
                    icon: "apps.iphone",
                    color: focusService.selectedAppCount > 0 ? .purple : Color.adaptiveTextSecondary(colorScheme),
                    title: "Specific apps",
                    value: focusService.selectedAppCount > 0
                        ? "\(focusService.selectedAppCount) app\(focusService.selectedAppCount == 1 ? "" : "s")"
                        : "None"
                ) {
                    // Changing the list can remove apps → PIN-gated when locked.
                    let openPicker = {
                        pickerSelection = focusService.selection
                        showAppPicker = true
                    }
                    if lockService.isLockEnabled { guardedReduce(openPicker) } else { openPicker() }
                }

                ShieldRowDivider()

                ShieldNavRow(
                    icon: "moon.stars.fill",
                    color: enabledScheduleCount > 0 ? .indigo : Color.adaptiveTextSecondary(colorScheme),
                    title: "Schedules",
                    value: enabledScheduleCount > 0 ? "\(enabledScheduleCount) on" : "None"
                ) {
                    SchedulesListView(scheduleService: scheduleService, guardedReduce: guardedReduce)
                }

                ShieldRowDivider()

                ShieldNavRow(
                    icon: "timer",
                    color: sessionService.isSessionActive ? .teal : Color.adaptiveTextSecondary(colorScheme),
                    title: "Focus session",
                    value: sessionService.isSessionActive ? "Running" : "Start"
                ) {
                    FocusSessionView(sessionService: sessionService, guardedReduce: guardedReduce)
                }
            }
        }
    }

    private var enabledScheduleCount: Int {
        scheduleService.schedules.filter { $0.isEnabled && $0.hasSelection }.count
    }

    // MARK: - Accountability

    private var accountabilitySection: some View {
        VStack(spacing: 8) {
            ShieldSectionLabel("Accountability")

            ShieldSectionCard {
                ShieldButtonRow(
                    icon: lockService.isLockEnabled ? "lock.fill" : "lock.open.fill",
                    color: lockService.isLockEnabled ? .green : Color.adaptiveTextSecondary(colorScheme),
                    title: "Partner lock",
                    value: lockService.isLockEnabled ? "On" : "Off",
                    valueColor: lockService.isLockEnabled ? Color.green : nil
                ) {
                    if lockService.isLockEnabled { showRemoveLock = true } else { showLockSetup = true }
                }

                ShieldRowDivider()

                ShieldNavRow(
                    icon: "person.2.fill",
                    color: partnerService.hasPartner ? Color(red: 0.20, green: 0.55, blue: 0.55) : Color.adaptiveTextSecondary(colorScheme),
                    title: "Partner",
                    value: partnerService.hasPartner ? partnerService.partnerName : "Not set"
                ) {
                    AccountabilityPartnerView()
                }

                ShieldRowDivider()

                ShieldNavRow(
                    icon: "chart.bar.fill",
                    color: Color.reforgedGold,
                    title: "Insights & streak"
                ) {
                    ShieldInsightsView()
                }
            }

            if lockService.isLockEnabled {
                ScreenTimePasscodeTip()
            } else {
                Text("Have a trusted friend set a PIN so you can't lower your own protection alone.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Scripture Footer

    private var scriptureFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.reforgedGold)

            Text("\"I have stored up your word in my heart,\nthat I might not sin against you.\"")
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("— Psalm 119:11")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }
}

// MARK: - Refocus Verse (block notification → passage)

/// The passage shown when the user taps a "you hit a block" notification.
/// Carries the verse from the notification payload, or falls back to a random
/// temptation-focused passage from the shield bank.
struct RefocusVerse: Identifiable {
    let id = UUID()
    let verseText: String?
    let reference: String?
    let suggestion: String?

    var resolved: ShieldEncouragement {
        if let verseText, let reference, !verseText.isEmpty {
            return ShieldEncouragement(
                suggestion: suggestion ?? "Turn your eyes to the Lord",
                verseText: verseText,
                verseReference: reference
            )
        }
        return ShieldContentProvider.fallbackEncouragements.randomElement()
            ?? ShieldEncouragement(
                suggestion: "Turn your eyes to the Lord",
                verseText: "I have stored up your word in my heart, that I might not sin against you.",
                verseReference: "Psalm 119:11"
            )
    }
}

struct RefocusVerseSheet: View {
    let verse: RefocusVerse
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var item: ShieldEncouragement { verse.resolved }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.22, blue: 0.48).opacity(0.18),
                                         Color.reforgedGold.opacity(0.14)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.22, blue: 0.48), Color.reforgedGold],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 12)

                Text("A word for this moment")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                // Verse card
                VStack(spacing: 12) {
                    Text("\u{201C}\(item.verseText)\u{201D}")
                        .font(.system(.title3, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineSpacing(6)
                    Text("\u{2014} \(item.verseReference)")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1.5))

                Text(item.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.buttonTap()
                        NotificationCenter.default.post(
                            name: .navigateToBibleVerse,
                            object: nil,
                            userInfo: [AppNotificationUserInfoKey.reference: item.verseReference]
                        )
                        dismiss()
                    } label: {
                        actionLabel("Read it in context", icon: "book.fill", filled: true)
                    }

                    Button {
                        HapticManager.shared.buttonTap()
                        NotificationCenter.default.post(
                            name: .switchTab,
                            object: nil,
                            userInfo: [AppNotificationUserInfoKey.tab: 3]
                        )
                        dismiss()
                    } label: {
                        actionLabel("Review memory verses", icon: "brain.head.profile", filled: false)
                    }
                }

                Button("Close") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private func actionLabel(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(.headline)
        }
        .foregroundStyle(filled ? .white : Color.adaptiveNavyText(colorScheme))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            filled
                ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.12, green: 0.22, blue: 0.48), Color.reforgedGold],
                                               startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Color.reforgedGold.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// PrayerPromptSheet moved to its own file (Views/Discipleship/PrayerPromptSheet.swift)
// so the Tempted SOS flow can reuse it.
