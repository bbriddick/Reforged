import SwiftUI

// MARK: - First-run onboarding for the Friends tab
//
// Shown once per account after sign-in and the age check. Four steps:
// welcome, what friends can see (explicit opt-in, all off by default),
// encouragement + notifications, and inviting someone. Nothing is shared
// unless the user turns it on here or later in the Friends tab.

enum FriendsOnboarding {
    private static func key(_ uid: String?) -> String { "friends.onboarding.done.\(uid ?? "anon")" }
    static func isDone(for uid: String?) -> Bool { UserDefaults.standard.bool(forKey: key(uid)) }
    static func markDone(for uid: String?) { UserDefaults.standard.set(true, forKey: key(uid)) }
}

struct FriendsOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = FriendsStore.shared

    /// Called when the user finishes or skips; the host marks onboarding done.
    let onFinish: () -> Void

    @State private var page = 0
    @State private var draft = FriendSharingPrefs()
    @State private var enteredCode = ""
    @State private var savedChoices = false

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 12)

            TabView(selection: $page) {
                welcomePage.tag(0)
                sharingPage.tag(1)
                encouragementPage.tag(2)
                invitePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            footer
        }
        .background(Color.adaptiveBackground(colorScheme))
        .task { draft = store.prefs }
    }

    // MARK: Chrome

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPage, id: \.self) { i in
                Capsule()
                    .fill(i <= page ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.25))
                    .frame(width: i == page ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut, value: page)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: advance) {
                Text(page == lastPage ? "Done" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.reforgedGold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            if page == 1 {
                Button("Share nothing for now") {
                    draft = FriendSharingPrefs()
                    advance()
                }
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            } else if page == 0 {
                Button("Not now") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            } else {
                // Reserve the same height so Continue doesn't jump between pages.
                Text(" ").font(.subheadline).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: 520)
    }

    private func advance() {
        if page == 2 { saveChoices() }          // persist consent before invites
        if page == lastPage { finish() } else { withAnimation { page += 1 } }
    }

    private func saveChoices() {
        guard !savedChoices else { return }
        savedChoices = true
        let choices = draft
        Task { await store.updatePrefs(choices) }
    }

    private func finish() {
        if !savedChoices { saveChoices() }
        onFinish()
    }

    // MARK: Pages

    private func pageShell<Content: View>(icon: String, title: String, subtitle: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color.reforgedGold.opacity(0.15)).frame(width: 84, height: 84)
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                .padding(.top, 28)
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                content()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var welcomePage: some View {
        pageShell(icon: "person.2.fill",
                  title: "Grow in the Word together",
                  subtitle: "Invite people you trust. Cheer each other on, and keep each other going in reading and memorizing Scripture.") {
            VStack(alignment: .leading, spacing: 14) {
                bullet("hands.clap.fill", "Encourage with one tap", "Send a cheer, a prayer, or a gentle nudge.")
                bullet("flame.fill", "See each other's momentum", "Streaks and progress, only if you choose to share.")
                bullet("lock.shield.fill", "Private by default", "Invite-only. No public profiles, no search, no chat.")
            }
            .padding(.top, 6)
            if store.pendingInviteCode != nil {
                Label("You've been invited. We'll connect you when you finish.", systemImage: "envelope.open.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.reforgedGold)
                    .padding(.top, 6)
            }
        }
    }

    private var sharingPage: some View {
        pageShell(icon: "eye.fill",
                  title: "You choose what friends see",
                  subtitle: "Everything is off until you turn it on. Friends see only totals, never what you read, your notes, or your prayers.") {
            VStack(spacing: 0) {
                toggleRow("Streak and read-today", "flame.fill", $draft.shareStreak)
                Divider()
                toggleRow("Chapters read this week", "book.fill", $draft.shareWeeklyChapters)
                Divider()
                toggleRow("Verses memorized", "brain.head.profile", $draft.shareVersesMemorized)
            }
            .padding(.horizontal, 14)
            .background(Color.adaptiveCardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Sharing your Bible reading can reveal your faith, so this is your call. You can change it any time in the Friends tab.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    private var encouragementPage: some View {
        pageShell(icon: "bell.badge.fill",
                  title: "Let friends encourage you",
                  subtitle: "Friends can send a short, kind message like \"Keep going\" or \"Praying for you\". There's no free text, and you can mute anyone.") {
            VStack(spacing: 0) {
                toggleRow("Allow encouragement", "bell.badge.fill", $draft.allowNudges)
            }
            .padding(.horizontal, 14)
            .background(Color.adaptiveCardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(draft.allowNudges
                 ? "We'll ask for notification permission next so these can reach you."
                 : "You won't receive notifications from friends.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    private var invitePage: some View {
        pageShell(icon: "person.badge.plus",
                  title: "Bring someone along",
                  subtitle: "Share your invite or enter a friend's code. It's one person per code and expires in 7 days.") {
            VStack(spacing: 14) {
                if let link = store.inviteLink, let code = store.myInviteCode {
                    QRCodeView(string: link.absoluteString)
                        .frame(width: 140, height: 140)
                        .padding(10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    Text(code)
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    ShareLink(item: link, message: Text("Join me on Reforged to read and memorize Scripture together. Code: \(code)")) {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                            .font(.headline)
                    }
                } else {
                    ProgressView().padding(.vertical, 40)
                }

                InviteFromContactsButton()
                    .font(.headline)

                HStack {
                    TextField("Have a code? Enter it", text: $enteredCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Add") {
                        let code = enteredCode
                        Task { if await store.redeem(code) { enteredCode = "" } }
                    }
                    .disabled(enteredCode.trimmingCharacters(in: .whitespaces).count < 6)
                }
                .padding(14)
                .background(Color.adaptiveCardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let msg = store.infoMessage {
                    Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline)
                }
                if let msg = store.errorMessage {
                    Label(msg, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.subheadline)
                }
            }
        }
        .task(id: page) {
            if page == lastPage, store.myInviteCode == nil { await store.createInvite() }
        }
    }

    // MARK: Pieces

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Color.adaptiveText(colorScheme))
                Text(detail).font(.subheadline).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer(minLength: 0)
        }
    }

    private func toggleRow(_ title: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: icon).foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .tint(Color.reforgedGold)
        .padding(.vertical, 12)
    }
}
