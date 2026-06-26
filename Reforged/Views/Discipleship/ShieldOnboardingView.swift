import SwiftUI
import UIKit

// MARK: - Screen Time Passcode Tip
//
// The in-app accountability PIN only gates changes inside Reforged. For a lock the
// user genuinely can't undo alone, the partner should ALSO set an iOS Screen Time
// passcode — without it, the user could revoke Screen Time access or delete the app.
// Shown in onboarding and on the lock card. Defined internally so FocusBlockingView
// can reuse it.

struct ScreenTimePasscodeTip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
                Text("Make it unbreakable")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Text("Have your partner set an iOS Screen Time passcode that only they know:\nSettings → Screen Time → Lock Screen Time Settings.\n\nWith it set, your protection can't be turned off — even by deleting Reforged.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.shared.buttonTap()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Open Settings")
                        .font(.caption).fontWeight(.semibold)
                }
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reforgedGold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - PIN Entry View
//
// Reusable numeric-keypad sheet for the accountability lock. Three modes:
//  • setup  — enter a PIN, confirm it, then store it.
//  • verify — enter the PIN to authorize a one-off protected action.
//  • remove — enter the PIN to remove the lock entirely.

struct PINEntryView: View {
    enum Mode {
        case setup
        case verify
        case remove
    }

    let mode: Mode
    @ObservedObject var lockService: AccountabilityLockService
    /// Called with whether the entry succeeded. The sheet dismisses itself on success.
    var onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var entry: String = ""
    @State private var firstPass: String? = nil   // setup: holds the first entry until confirmed
    @State private var error: String? = nil
    @State private var shake = false

    // setup: partner contact captured before the PIN step
    @State private var partnerContact: String = ""
    @State private var contactConfirmed = false

    private var pinLength: Int { AccountabilityLockService.pinLength }

    var body: some View {
        if mode == .setup && !contactConfirmed {
            contactStep
        } else {
            pinStep
        }
    }

    // MARK: - Contact Step (setup only)

    private var contactStep: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.reforgedGold.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
            }

            VStack(spacing: 8) {
                Text("Who's your accountability partner?")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)
                Text("Enter their email or phone number. They'll be notified any time you try to lower your protection.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            TextField("Email or phone number", text: $partnerContact)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                .padding(.horizontal, 8)

            if let error {
                Text(error)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedCoral)
                    .transition(.opacity)
            }

            Spacer()

            Button {
                continueFromContact()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button("Cancel") {
                onComplete(false)
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private func continueFromContact() {
        let trimmed = partnerContact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidContact(trimmed) else {
            HapticManager.shared.errorFeedback()
            withAnimation { error = "Enter a valid email or phone number." }
            return
        }
        partnerContact = trimmed
        withAnimation { error = nil }
        HapticManager.shared.buttonTap()
        contactConfirmed = true
    }

    /// Loose validation: an email (has "@" and a dot after it) or a phone (7+ digits).
    private static func isValidContact(_ contact: String) -> Bool {
        if contact.contains("@") {
            let parts = contact.split(separator: "@")
            return parts.count == 2 && parts[1].contains(".")
        }
        return contact.filter { $0.isNumber }.count >= 7
    }

    // MARK: - PIN Step

    private var pinStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedGold.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            // Dots
            HStack(spacing: 18) {
                ForEach(0..<pinLength, id: \.self) { i in
                    Circle()
                        .fill(i < entry.count ? Color.reforgedGold : Color.clear)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1.5)
                        )
                }
            }
            .offset(x: shake ? -8 : 0)

            if let error {
                Text(error)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedCoral)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            keypad

            Button("Cancel") {
                onComplete(false)
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Keypad

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    private var keypad: some View {
        VStack(spacing: 16) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private func keypadButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 72, height: 72)
        } else if key == "⌫" {
            Button {
                guard !entry.isEmpty else { return }
                HapticManager.shared.lightImpact()
                entry.removeLast()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                press(key)
            } label: {
                Text(key)
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(width: 72, height: 72)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func press(_ digit: String) {
        guard entry.count < pinLength else { return }
        HapticManager.shared.lightImpact()
        withAnimation(.easeOut(duration: 0.1)) { error = nil }
        entry.append(digit)
        if entry.count == pinLength {
            // Slight delay so the final dot fills before we act.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { handleComplete() }
        }
    }

    private func handleComplete() {
        switch mode {
        case .setup:
            if let first = firstPass {
                if entry == first {
                    if lockService.setPIN(entry, partnerContact: partnerContact) {
                        HapticManager.shared.success()
                        onComplete(true)
                        dismiss()
                    } else {
                        fail("Couldn't save PIN. Try again.")
                        firstPass = nil
                    }
                } else {
                    fail("PINs didn't match. Start over.")
                    firstPass = nil
                }
            } else {
                // First pass captured — ask for confirmation.
                firstPass = entry
                entry = ""
                HapticManager.shared.selectionChanged()
            }
        case .verify:
            if lockService.verifyPIN(entry) {
                HapticManager.shared.success()
                onComplete(true)
                dismiss()
            } else {
                fail("Incorrect PIN.")
            }
        case .remove:
            if lockService.removeLock(pin: entry) {
                HapticManager.shared.success()
                onComplete(true)
                dismiss()
            } else {
                fail("Incorrect PIN.")
            }
        }
    }

    private func fail(_ message: String) {
        HapticManager.shared.errorFeedback()
        withAnimation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true)) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        withAnimation { error = message }
        entry = ""
    }

    // MARK: - Copy

    private var iconName: String {
        switch mode {
        case .setup:  return "lock.shield.fill"
        case .verify: return "lock.open.fill"
        case .remove: return "lock.slash.fill"
        }
    }

    private var title: String {
        switch mode {
        case .setup:  return firstPass == nil ? "Create a PIN" : "Confirm your PIN"
        case .verify: return "Enter accountability PIN"
        case .remove: return "Remove accountability lock"
        }
    }

    private var subtitle: String {
        switch mode {
        case .setup:
            return firstPass == nil
                ? "Have your accountability partner choose a \(pinLength)-digit PIN. You won't be able to lower your protection without it."
                : "Re-enter the same PIN to confirm."
        case .verify:
            return "Ask your accountability partner to enter the PIN to make this change."
        case .remove:
            return "Enter the PIN to turn off the lock. This re-opens all of your blocking controls."
        }
    }
}

// MARK: - Shield Onboarding View
//
// A dedicated first-run flow for the Focus & Purity Shield, presented the first
// time the user opens the shield screen (and re-openable via "How it works").

struct ShieldOnboardingView: View {
    /// Called when the user finishes or skips the flow.
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var focusService = FocusBlockingService.shared
    @StateObject private var lockService = AccountabilityLockService.shared

    @State private var page = 0
    @State private var showPINSetup = false
    @State private var isRequestingAuth = false

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(icon: "shield.lefthalf.filled",
             title: "Guard Your Mind",
             body: "Reforged can block pornography, social media, and any app that pulls you away — right from inside the app. No third-party tools needed."),
        Page(icon: "hand.raised.fill",
             title: "Private & On-Device",
             body: "Blocking is powered by Apple Screen Time and runs entirely on your device. Reforged never sees what you browse or which apps you open."),
        Page(icon: "slider.horizontal.3",
             title: "You Choose What to Block",
             body: "Turn off adult content and social media with a tap, or pick specific apps to lock yourself out of. You're always in control of what's shielded."),
        Page(icon: "person.2.fill",
             title: "Real Accountability",
             body: "Set a PIN that a trusted friend holds. Once it's locked, you can't lower your protection without them — turning temptation into a conversation.")
    ]

    private var isLastInfoPage: Bool { page == pages.count } // the final "enable" page
    private var accountabilityPageIndex: Int { pages.count - 1 } // "Real Accountability" page

    var body: some View {
        VStack(spacing: 0) {
            // Skip
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                    infoPage(p, showScreenTimeTip: index == accountabilityPageIndex)
                        .tag(index)
                }
                enablePage
                    .tag(pages.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: page)

            bottomButton
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .sheet(isPresented: $showPINSetup) {
            PINEntryView(mode: .setup, lockService: lockService) { _ in }
        }
    }

    // MARK: - Info pages

    private func infoPage(_ p: Page, showScreenTimeTip: Bool = false) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.48).opacity(0.18),
                                Color.reforgedGold.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: p.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.22, blue: 0.48), Color.reforgedGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 14) {
                Text(p.title)
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)
                Text(p.body)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            if showScreenTimeTip {
                ScreenTimePasscodeTip()
                    .padding(.horizontal, 28)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Enable page

    private var enablePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.reforgedGold.opacity(0.14))
                    .frame(width: 120, height: 120)
                Image(systemName: focusService.isAuthorized ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
            }

            VStack(spacing: 14) {
                Text(focusService.isAuthorized ? "You're All Set" : "Turn On Protection")
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)
                Text(focusService.isAuthorized
                     ? "Screen Time is connected. Choose what to block on the next screen — and consider setting an accountability PIN."
                     : "Grant Screen Time access so Reforged can shield the content you choose. You can change what's blocked anytime.")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            // Optional accountability PIN shortcut
            Button {
                HapticManager.shared.buttonTap()
                showPINSetup = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: lockService.isLockEnabled ? "checkmark.circle.fill" : "lock.shield")
                    Text(lockService.isLockEnabled ? "Accountability PIN set" : "Set an accountability PIN (optional)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(lockService.isLockEnabled ? Color.green : Color.adaptiveNavyText(colorScheme))
            }
            .disabled(lockService.isLockEnabled)
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom button

    @ViewBuilder
    private var bottomButton: some View {
        if isLastInfoPage {
            Button {
                if focusService.isAuthorized {
                    finish()
                } else {
                    requestAuthorization()
                }
            } label: {
                Group {
                    if isRequestingAuth {
                        ProgressView().tint(.white)
                    } else {
                        Text(focusService.isAuthorized ? "Start Protecting" : "Enable Screen Time")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.22, blue: 0.48), Color.reforgedGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isRequestingAuth)
        } else {
            Button {
                HapticManager.shared.buttonTap()
                withAnimation { page += 1 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func requestAuthorization() {
        isRequestingAuth = true
        Task {
            await focusService.requestAuthorization()
            isRequestingAuth = false
            // Whether or not granted, the flow is done; the main screen shows status.
            finish()
        }
    }

    private func finish() {
        HapticManager.shared.buttonTap()
        onFinish()
    }
}
