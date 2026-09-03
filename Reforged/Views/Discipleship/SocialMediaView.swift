import SwiftUI
import FamilyControls

// MARK: - Social Media Strategy
//
// Three features shield the SAME social apps and are mutually exclusive at the
// service layer (each one's `setEnabled(true)` turns the other two off):
//
//   • Always blocked  — FocusBlockingService.blockSocialMedia
//   • Daily limit     — SocialLimitService (usage cap + earn-back)
//   • Unlock gate     — UnlockGateService (locked until you open the Word)
//
// Presented as three separate toggles on separate cards, that exclusivity was
// invisible: turning one on silently switched another off. Here they're one
// picker — you choose a strategy, and only its settings appear. The mode's
// strictness rank drives the accountability PIN: loosening needs the partner,
// tightening never does.

struct SocialMediaView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var limitService = SocialLimitService.shared
    @StateObject private var gateService = UnlockGateService.shared
    @StateObject private var lockService = AccountabilityLockService.shared

    /// PIN gate supplied by the parent so every protection-lowering path in the
    /// shield shares one implementation.
    let guardedReduce: (@escaping () -> Void) -> Void

    @State private var showSocialPicker = false
    @State private var socialPickerSelection = FamilyActivitySelection()
    /// Mode to apply once the picker supplies a selection.
    @State private var pendingMode: SocialMode? = nil

    enum SocialMode: String, CaseIterable, Identifiable {
        case off, dailyLimit, unlockGate, alwaysBlocked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off:           return "Off"
            case .dailyLimit:    return "Daily limit"
            case .unlockGate:    return "Word first"
            case .alwaysBlocked: return "Always blocked"
            }
        }

        var blurb: String {
            switch self {
            case .off:           return "Social apps aren't shielded."
            case .dailyLimit:    return "Cap social time each day — earn more with Scripture."
            case .unlockGate:    return "Social stays shut until you read or memorize today."
            case .alwaysBlocked: return "Social apps stay shielded around the clock."
            }
        }

        var icon: String {
            switch self {
            case .off:           return "circle.slash"
            case .dailyLimit:    return "hourglass"
            case .unlockGate:    return "book.closed.fill"
            case .alwaysBlocked: return "hand.raised.fill"
            }
        }

        /// Higher = more protection. Dropping to a lower rank needs the PIN.
        var strictness: Int {
            switch self {
            case .off:           return 0
            case .dailyLimit:    return 1
            case .unlockGate:    return 2
            case .alwaysBlocked: return 3
            }
        }
    }

    private var currentMode: SocialMode {
        if focusService.blockSocialMedia { return .alwaysBlocked }
        if gateService.isEnabled { return .unlockGate }
        if limitService.isEnabled { return .dailyLimit }
        return .off
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                modePicker

                if currentMode != .off {
                    appsRow
                }

                switch currentMode {
                case .dailyLimit:    dailyLimitDetail
                case .unlockGate:    unlockGateDetail
                case .alwaysBlocked: alwaysBlockedDetail
                case .off:           EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Social Media")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showSocialPicker, selection: $socialPickerSelection)
        .onChange(of: showSocialPicker) { isPresenting in
            guard !isPresenting else { return }
            let isEmpty = socialPickerSelection.applicationTokens.isEmpty
                && socialPickerSelection.categoryTokens.isEmpty
                && socialPickerSelection.webDomainTokens.isEmpty
            let mode = pendingMode
            pendingMode = nil
            guard !isEmpty else { return }
            focusService.updateSocialSelection(socialPickerSelection)
            if let mode { apply(mode) }
        }
        .onAppear { socialPickerSelection = focusService.socialSelection }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(SocialMode.allCases.enumerated()), id: \.element.id) { index, mode in
                if index > 0 { ShieldRowDivider() }
                modeRow(mode)
            }
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    private func modeRow(_ mode: SocialMode) -> some View {
        let selected = currentMode == mode
        return Button {
            HapticManager.shared.selectionChanged()
            select(mode)
        } label: {
            HStack(spacing: 12) {
                ShieldRowIcon(systemName: mode.icon,
                              color: mode == .off ? Color.adaptiveTextSecondary(colorScheme) : accent(for: mode))

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.subheadline).fontWeight(selected ? .semibold : .regular)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(mode.blurb)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if lockService.isLockEnabled && mode.strictness < currentMode.strictness {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .accessibilityHidden(true)
                }

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(selected ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func accent(for mode: SocialMode) -> Color {
        switch mode {
        case .off:           return Color.adaptiveTextSecondary(colorScheme)
        case .dailyLimit:    return Color(red: 0.20, green: 0.55, blue: 0.55)
        case .unlockGate:    return Color.reforgedGold
        case .alwaysBlocked: return Color.green
        }
    }

    // MARK: - Mode Switching

    private func select(_ mode: SocialMode) {
        guard mode != currentMode else { return }

        let commit = {
            // Needs a selection first — the picker commits the mode on dismiss.
            if mode != .off && !focusService.hasSocialSelection {
                pendingMode = mode
                socialPickerSelection = focusService.socialSelection
                showSocialPicker = true
                return
            }
            apply(mode)
        }

        if mode.strictness < currentMode.strictness {
            let from = currentMode
            guardedReduce {
                AccountabilityPartnerService.shared.record(
                    tamperKind(leaving: from, to: mode),
                    detail: "Social media strategy changed from \"\(from.title)\" to \"\(mode.title)\"."
                )
                commit()
            }
        } else {
            commit()
        }
    }

    private func tamperKind(leaving from: SocialMode, to: SocialMode) -> TamperEvent.Kind {
        if to == .off {
            switch from {
            case .dailyLimit: return .limitDisabled
            case .unlockGate: return .gateDisabled
            default:          return .protectionLowered
            }
        }
        return .protectionLowered
    }

    /// Each service's `setEnabled(true)` disables the other two, so applying a
    /// mode is just enabling the winner (and turning everything off for `.off`).
    private func apply(_ mode: SocialMode) {
        switch mode {
        case .off:
            Task { await focusService.setBlockSocialMedia(false) }
            limitService.setEnabled(false)
            gateService.setEnabled(false)
        case .dailyLimit:
            limitService.setEnabled(true)
        case .unlockGate:
            gateService.setEnabled(true)
        case .alwaysBlocked:
            Task { await focusService.setBlockSocialMedia(true) }
        }
    }

    // MARK: - Apps Row

    private var appsRow: some View {
        VStack(spacing: 8) {
            ShieldSectionCard {
                ShieldButtonRow(
                    icon: "apps.iphone",
                    color: focusService.hasSocialSelection ? .purple : Color.adaptiveTextSecondary(colorScheme),
                    title: "Social apps",
                    value: socialSelectionSummary,
                    valueColor: focusService.hasSocialSelection ? nil : Color.reforgedCoral
                ) {
                    let open = {
                        pendingMode = nil
                        socialPickerSelection = focusService.socialSelection
                        showSocialPicker = true
                    }
                    // Changing the list can remove apps → PIN-gated when locked.
                    if lockService.isLockEnabled { guardedReduce(open) } else { open() }
                }
            }

            if !focusService.hasSocialSelection {
                footnote("Pick the apps this applies to — iOS gives no automatic \"social media\" list, so you choose them once here.")
            }
        }
    }

    private var socialSelectionSummary: String {
        let sel = focusService.socialSelection
        let apps = sel.applicationTokens.count
        let cats = sel.categoryTokens.count
        if apps == 0 && cats == 0 { return "Not set" }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Daily Limit Detail

    private let limitOptions = [15, 30, 45, 60, 90, 120]
    private let usageTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private var dailyLimitDetail: some View {
        VStack(spacing: 16) {
            if limitService.hasSelection {
                SocialLimitCountdown(limitService: limitService)
            }

            ShieldSectionCard {
                HStack(spacing: 12) {
                    ShieldRowIcon(systemName: "gauge.with.needle", color: Color(red: 0.20, green: 0.55, blue: 0.55))
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
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                if limitService.earnedTodayMinutes > 0 {
                    ShieldRowDivider()
                    HStack(spacing: 12) {
                        ShieldRowIcon(systemName: "gift.fill", color: Color.reforgedGold)
                        Text("Earned today")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Text("+\(limitService.earnedTodayMinutes) of \(SocialLimitKeys.dailyEarnCap) min")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }

            footnote("Listen to a full Bible chapter (+\(SocialLimitKeys.chapterReward) min) or finish a memory activity (+\(SocialLimitKeys.memoryReward) min) to extend — up to +\(SocialLimitKeys.dailyEarnCap) min a day.")
        }
        .onReceive(usageTimer) { _ in
            if limitService.isEnabled { limitService.reloadUsage() }
        }
    }

    private func changeLimit(to minutes: Int) {
        HapticManager.shared.selectionChanged()
        if minutes > limitService.limitMinutes {
            let previous = limitService.limitMinutes
            guardedReduce {
                AccountabilityPartnerService.shared.record(
                    .protectionLowered,
                    detail: "Daily social limit raised from \(previous) to \(minutes) min."
                )
                limitService.setLimitMinutes(minutes)
            }
        } else {
            limitService.setLimitMinutes(minutes)
        }
    }

    // MARK: - Unlock Gate Detail

    private var unlockGateDetail: some View {
        VStack(spacing: 16) {
            let cleared = gateService.isClearedToday

            VStack(spacing: 12) {
                Image(systemName: cleared ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(cleared ? Color.green : Color.reforgedGold)

                Text(cleared ? "Unlocked for today" : "The Word comes first")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(cleared
                     ? "You opened the Word today\(gateService.clearedBy.map { " — \($0)" } ?? "."). Social is open until midnight."
                     : "Read a chapter or practice a memory verse, and social opens for the rest of today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !cleared {
                    HStack(spacing: 10) {
                        gateAction(title: "Read", icon: "text.book.closed.fill", tab: 2)
                        gateAction(title: "Memorize", icon: "brain.head.profile", tab: 3)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background((cleared ? Color.green : Color.reforgedGold).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            footnote("The gate resets at midnight. Reforged shows a verse on the shield until you've opened the Word.")
        }
    }

    private func gateAction(title: String, icon: String, tab: Int) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            NotificationCenter.default.post(
                name: .switchTab, object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: tab]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.subheadline).fontWeight(.semibold)
            }
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Always Blocked Detail

    private var alwaysBlockedDetail: some View {
        footnote("Social apps and sites stay shielded until you change this — the strongest option, and the one your partner's PIN protects.")
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

// MARK: - Countdown

/// "Time left today" readout. Ticks each second so the bar creeps between the
/// monitor's real 5-min-granularity updates (see `projectedUsedMinutes`) rather
/// than sitting frozen for minutes at a time.
struct SocialLimitCountdown: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var limitService: SocialLimitService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
    }

    private func content(at date: Date) -> some View {
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
                        .monospacedDigit()
                    Text("min left today")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Text("\(used) / \(allowance) min")
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .monospacedDigit()
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
}
