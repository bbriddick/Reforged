import SwiftUI
import FamilyControls

// MARK: - Focus Blocking View
//
// The interactive Focus & Purity Shield screen. Lets the user authorize Screen
// Time, toggle adult-content / social-media blocking, and pick specific apps to
// shield.

struct FocusBlockingView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var lockService = AccountabilityLockService.shared
    @StateObject private var limitService = SocialLimitService.shared

    /// Whether the social picker is being shown to set up the daily limit (vs. always-block).
    @State private var socialPickerForLimit = false

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showSocialPicker = false
    @State private var socialPickerSelection = FamilyActivitySelection()
    @State private var showPrayerSheet = false

    // Onboarding + accountability lock
    @State private var showOnboarding = false
    @State private var showLockSetup = false
    @State private var showRemoveLock = false
    @State private var showPINVerify = false
    /// Action to run after the accountability PIN is verified (e.g. lowering protection).
    @State private var pendingUnlockAction: (() -> Void)? = nil

    private static let onboardingSeenKey = "hasSeenShieldOnboarding"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                heroCard

                if !focusService.isAuthorized {
                    authorizationCard
                }

                blockingControls

                dailyLimitCard

                accountabilityLockCard

                launchpad

                scriptureFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
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
        .familyActivityPicker(isPresented: $showSocialPicker, selection: $socialPickerSelection)
        .onChange(of: showSocialPicker) { isPresenting in
            // Apple gives no programmatic "social media" category, so the user picks
            // it once here. Enable social blocking only if they actually chose something;
            // otherwise the toggle reverts (it reads blockSocialMedia from the service).
            if !isPresenting {
                let isEmpty = socialPickerSelection.applicationTokens.isEmpty
                    && socialPickerSelection.categoryTokens.isEmpty
                    && socialPickerSelection.webDomainTokens.isEmpty
                let forLimit = socialPickerForLimit
                socialPickerForLimit = false
                if !isEmpty {
                    focusService.updateSocialSelection(socialPickerSelection)
                    if forLimit {
                        limitService.setEnabled(true)
                    } else {
                        // Always-block and daily-limit are mutually exclusive.
                        limitService.setEnabled(false)
                        Task { await focusService.setBlockSocialMedia(true) }
                    }
                }
            }
        }
        .onAppear {
            pickerSelection = focusService.selection
            // Authorization can read stale at launch — re-check so the "Enable
            // Blocking" card doesn't show when access is already granted.
            focusService.refreshAuthorizationStatus()
            limitService.reloadUsage()
            // Needed so the shield extension can fire "you hit a block" notifications.
            NotificationManager.shared.requestAuthorization()
            if !UserDefaults.standard.bool(forKey: Self.onboardingSeenKey) {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showPrayerSheet) {
            PrayerPromptSheet()
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
            PINEntryView(mode: .remove, lockService: lockService) { _ in }
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

    /// Turning on "Block Social Media" requires authorization, then opens the
    /// system picker so the user selects the Social Networking category (and any
    /// apps). The selection is committed when the picker is dismissed.
    private func beginSocialBlocking() {
        Task {
            if !focusService.isAuthorized {
                await focusService.requestAuthorization()
            }
            guard focusService.isAuthorized else { return }
            socialPickerForLimit = false
            socialPickerSelection = focusService.socialSelection
            showSocialPicker = true
        }
    }

    /// Opens the social picker to change the shared social selection (used by both
    /// the always-block toggle and the daily limit), keeping the two in sync.
    private func changeSocialApps() {
        Task {
            if !focusService.isAuthorized {
                await focusService.requestAuthorization()
            }
            guard focusService.isAuthorized else { return }
            socialPickerForLimit = true
            socialPickerSelection = focusService.socialSelection
            showSocialPicker = true
        }
    }

    /// Short summary of the chosen social apps/categories for the limit card.
    private var socialSelectionSummary: String {
        let sel = focusService.socialSelection
        let apps = sel.applicationTokens.count
        let cats = sel.categoryTokens.count
        if apps == 0 && cats == 0 { return "Choose" }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    /// Turning on the daily limit needs authorization and a social selection. If the
    /// user hasn't chosen social apps yet, open the picker (committing enables the limit).
    private func beginDailyLimit() {
        Task {
            if !focusService.isAuthorized {
                await focusService.requestAuthorization()
            }
            guard focusService.isAuthorized else { return }
            if limitService.hasSelection {
                limitService.setEnabled(true)
            } else {
                socialPickerForLimit = true
                socialPickerSelection = focusService.socialSelection
                showSocialPicker = true
            }
        }
    }

    /// Changes the daily limit. Raising it grants more social time = lowering
    /// protection, so it's PIN-gated when the accountability lock is on. Lowering
    /// the limit (more protection) applies immediately.
    private func changeLimit(to minutes: Int) {
        HapticManager.shared.selectionChanged()
        if minutes > limitService.limitMinutes {
            guardedReduce { limitService.setLimitMinutes(minutes) }
        } else {
            limitService.setLimitMinutes(minutes)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.48).opacity(0.18),
                                Color.reforgedGold.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.48),
                                Color.reforgedGold
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Guard Your Mind")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Block distracting and harmful content right from within Reforged — no third-party apps needed. Just you, choosing to stay focused.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 12, y: 4)
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
                        colors: [Color(red: 0.12, green: 0.22, blue: 0.48), Color.reforgedGold],
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

    // MARK: - Blocking Controls

    private var blockingControls: some View {
        VStack(spacing: 14) {
            toggleRow(
                icon: "shield.fill",
                color: Color(red: 0.12, green: 0.22, blue: 0.48),
                title: "Block Adult Content",
                detail: "Shields pornography & adult sites in Safari",
                isOn: protectionBinding(
                    get: { focusService.blockNSFW },
                    set: { newValue in Task { await focusService.setBlockNSFW(newValue) } }
                )
            )

            toggleRow(
                icon: "hand.raised.fill",
                color: Color(red: 0.85, green: 0.45, blue: 0.20),
                title: "Block Social Media",
                detail: socialDetail,
                isOn: Binding(
                    get: { focusService.blockSocialMedia },
                    set: { newValue in
                        if newValue {
                            // Turning on → pick the social category/apps via the system picker.
                            beginSocialBlocking()
                        } else {
                            // Turning off lowers protection → PIN-gated when locked.
                            guardedReduce { Task { await focusService.setBlockSocialMedia(false) } }
                        }
                    }
                )
            )

            Button {
                HapticManager.shared.buttonTap()
                // When locked, changing the app list (which can remove apps) needs the PIN.
                let openPicker = {
                    pickerSelection = focusService.selection
                    showAppPicker = true
                }
                if lockService.isLockEnabled {
                    guardedReduce(openPicker)
                } else {
                    openPicker()
                }
            } label: {
                HStack(spacing: 16) {
                    iconBadge("hand.raised.square.fill", color: .purple)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Block Specific Apps")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(focusService.selectedAppCount > 0
                             ? "\(focusService.selectedAppCount) app\(focusService.selectedAppCount == 1 ? "" : "s") selected"
                             : "Choose any installed app to lock yourself out of")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(16)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleRow(icon: String, color: Color, title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            iconBadge(icon, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if lockService.isLockEnabled && isOn.wrappedValue {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .accessibilityHidden(true)
            }

            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    HapticManager.shared.selectionChanged()
                    isOn.wrappedValue = newValue
                }
            ))
                .labelsHidden()
                .tint(Color.reforgedGold)
                .accessibilityLabel(title)
                .accessibilityHint(lockService.isLockEnabled ? "\(detail). Locked by accountability PIN." : detail)
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    /// Helper text under the "Block Social Media" toggle, reflecting picker state.
    private var socialDetail: String {
        if focusService.blockSocialMedia {
            return "Blocking your selected social apps & sites"
        }
        return focusService.hasSocialSelection
            ? "Tap to re-block your chosen social apps"
            : "Tap to pick the Social Networking category to block"
    }

    private func iconBadge(_ icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 50, height: 50)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Daily Social Limit

    private let limitOptions = [15, 30, 45, 60, 90, 120]

    /// Keeps the countdown fresh while the screen is open (usage is written in the
    /// background by the monitor extension).
    private let usageTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    /// "Time left today" banner — Quittr-style remaining-time readout with a progress bar.
    /// Ticks once a second via `TimelineView` so the bar creeps forward between the
    /// monitor's real 5-min-granularity updates (see `projectedUsedMinutes`) instead
    /// of sitting frozen for minutes at a time.
    private var countdownBanner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            countdownBannerContent(at: context.date)
        }
    }

    private func countdownBannerContent(at date: Date) -> some View {
        let allowance = limitService.allowanceMinutes
        let used = min(limitService.projectedUsedMinutes(at: date), allowance)
        let remaining = max(0, allowance - used)
        let fraction = allowance > 0 ? min(1, Double(used) / Double(allowance)) : 0
        let reached = limitService.isLimitReached
        let accent = reached ? Color.reforgedCoral : Color(red: 0.20, green: 0.55, blue: 0.55)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if reached {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Time's up for today")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                } else {
                    Text("\(remaining)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Text("min left today")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Text("\(used) / \(allowance) min")
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.18))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(.linear(duration: 1), value: fraction)
                }
            }
            .frame(height: 8)

            if reached {
                Text("Listen to a Bible chapter or finish a memory activity to unlock more time.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var dailyLimitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                iconBadge("hourglass", color: Color(red: 0.20, green: 0.55, blue: 0.55))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Social Limit")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Cap social media each day — then earn more time with Scripture.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { limitService.isEnabled },
                    set: { newValue in
                        HapticManager.shared.selectionChanged()
                        if newValue {
                            beginDailyLimit()
                        } else {
                            guardedReduce { limitService.setEnabled(false) }
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.reforgedGold)
            }

            if limitService.isEnabled {
                if limitService.hasSelection {
                    countdownBanner
                }

                Divider()

                HStack {
                    Text("Daily limit")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if lockService.isLockEnabled {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Menu {
                        ForEach(limitOptions, id: \.self) { m in
                            Button("\(m) min") { changeLimit(to: m) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(limitService.limitMinutes) min").fontWeight(.semibold)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    }
                }

                Button {
                    HapticManager.shared.buttonTap()
                    if lockService.isLockEnabled {
                        guardedReduce { changeSocialApps() }
                    } else {
                        changeSocialApps()
                    }
                } label: {
                    HStack {
                        Text("Social apps")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Text(socialSelectionSummary)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                .buttonStyle(.plain)

                if limitService.earnedTodayMinutes > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill").font(.caption).foregroundStyle(Color.reforgedGold)
                        Text("Earned today: +\(limitService.earnedTodayMinutes) of \(SocialLimitKeys.dailyEarnCap) min")
                            .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Spacer()
                        Text("Today: \(limitService.allowanceMinutes) min")
                            .font(.caption2).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                Text("Listen to a full Bible chapter (+\(SocialLimitKeys.chapterReward) min) or finish a memory activity (+\(SocialLimitKeys.memoryReward) min) to extend — up to +\(SocialLimitKeys.dailyEarnCap) min/day.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
        .onReceive(usageTimer) { _ in
            if limitService.isEnabled { limitService.reloadUsage() }
        }
    }

    // MARK: - Accountability Lock

    private var accountabilityLockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                iconBadge(lockService.isLockEnabled ? "lock.fill" : "lock.open.fill",
                          color: lockService.isLockEnabled ? Color.green : .purple)

                VStack(alignment: .leading, spacing: 3) {
                    Text(lockService.isLockEnabled ? "Accountability Lock On" : "Accountability Lock")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(lockService.isLockEnabled
                         ? "Your partner's PIN is required to lower any protection."
                         : "Have a trusted friend set a PIN so you can't lower your protection alone.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button {
                HapticManager.shared.buttonTap()
                if lockService.isLockEnabled {
                    showRemoveLock = true
                } else {
                    showLockSetup = true
                }
            } label: {
                Text(lockService.isLockEnabled ? "Remove Lock" : "Set Up Accountability PIN")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(lockService.isLockEnabled ? Color.reforgedCoral : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        lockService.isLockEnabled
                            ? AnyShapeStyle(Color.reforgedCoral.opacity(0.12))
                            : AnyShapeStyle(Color.reforgedNavy)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if lockService.isLockEnabled {
                ScreenTimePasscodeTip()
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lockService.isLockEnabled ? Color.green.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Launchpad ("do this instead")

    private var launchpad: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("When you feel the pull, do this instead")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .padding(.horizontal, 4)

            launchpadCard(icon: "brain.head.profile", color: Color.reforgedGold,
                          title: "Review memory verses",
                          subtitle: "Strengthen what's stored in your heart") {
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: nil,
                    userInfo: [AppNotificationUserInfoKey.tab: 3]
                )
            }

            launchpadCard(icon: "text.book.closed.fill", color: Color(red: 0.12, green: 0.22, blue: 0.48),
                          title: "Read a chapter",
                          subtitle: "Open the Word and let it speak") {
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: nil,
                    userInfo: [AppNotificationUserInfoKey.tab: 2]
                )
            }

            NavigationLink(destination: JournalView()) {
                launchpadCardLabel(icon: "square.and.pencil", color: Color(red: 0.85, green: 0.45, blue: 0.20),
                                   title: "Journal a reflection",
                                   subtitle: "Write out where your heart is")
            }
            .buttonStyle(.plain)

            launchpadCard(icon: "hands.and.sparkles.fill", color: .purple,
                          title: "Pray",
                          subtitle: "Bring this moment to God") {
                showPrayerSheet = true
            }
        }
    }

    private func launchpadCard(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            launchpadCardLabel(icon: icon, color: color, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func launchpadCardLabel(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            iconBadge(icon, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
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

// MARK: - Prayer Prompt Sheet

private struct PrayerPromptSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private let prompts = [
        "Lord, give me strength to turn away. Set my eyes on what is pure and lovely.",
        "Father, in this moment of temptation, be my refuge and my way of escape.",
        "Jesus, capture my attention. Help me treasure You more than this fleeting pull.",
        "Holy Spirit, renew my mind right now and lead me into what is good.",
        "God, thank You for grace. Help me walk in the freedom You've already given me."
    ]

    // Chosen once on appear so the prayer doesn't re-roll on every re-render.
    @State private var prompt: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.reforgedGold)

            Text("A prayer for this moment")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text(prompt)
                .font(.system(.title3, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(6)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Amen")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedGold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { prompt = prompts.randomElement() ?? prompts[0] }
    }
}
