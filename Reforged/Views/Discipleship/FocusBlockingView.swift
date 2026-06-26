import SwiftUI
import FamilyControls

// MARK: - Focus Blocking View
//
// The interactive Focus & Purity Shield screen. Lets the user authorize Screen
// Time, toggle adult-content / social-media blocking, and pick specific apps to
// shield. Because Apple's shield overlay cannot open the app, the "do this
// instead" launchpad lives here and routes into Reforged's own features.

struct FocusBlockingView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var lockService = AccountabilityLockService.shared

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
                if !isEmpty {
                    focusService.updateSocialSelection(socialPickerSelection)
                    Task { await focusService.setBlockSocialMedia(true) }
                }
            }
        }
        .onAppear {
            pickerSelection = focusService.selection
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
            // Notify the accountability partner of the attempt (before the PIN prompt).
            Task { await lockService.notifyPartnerOfDisableAttempt() }
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
            socialPickerSelection = focusService.socialSelection
            showSocialPicker = true
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

                    if lockService.isLockEnabled, let partner = lockService.partnerContactMasked {
                        Label("Alerts \(partner) if you try to lower it", systemImage: "bell.fill")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(Color.reforgedGold)
                    }
                }

                Spacer()
            }

            Button {
                HapticManager.shared.buttonTap()
                if lockService.isLockEnabled {
                    // Removing the lock is the biggest reduction — alert the partner.
                    Task { await lockService.notifyPartnerOfDisableAttempt(reason: "tried to remove the accountability lock entirely") }
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
