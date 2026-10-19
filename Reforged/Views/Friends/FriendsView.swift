import SwiftUI
import UserNotifications

// MARK: - FriendsView
//
// Layout (top to bottom), each block only appears when it has something to say:
//   1. Friend requests     — only when someone is waiting on you
//   2. Memorize Together   — needs-you items, shared verses, quiz results
//   3. Friends             — one card, one row per friend; "+" opens Add a friend
//   4. Sharing & privacy   — a single row that opens settings
// With no friends yet, a single hero with one primary action replaces 2-3.

struct FriendsView: View {
    @State private var historyFriend: FriendActivity?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = FriendsStore.shared
    @StateObject private var shared = SharedVersesStore.shared
    @StateObject private var reading = SharedReadingsStore.shared
    @ObservedObject private var connectivity = ConnectivityState.shared
    @StateObject private var ageGate = AgeGateManager.shared
    @ObservedObject private var auth = SupabaseAuthService.shared
    @ObservedObject private var apple = AppleSignInService.shared

    @State private var showAddFriend = false
    @State private var friendToRemove: FriendActivity?
    @State private var friendToBlock: FriendActivity?
    /// False until we know whether this account has already been through onboarding.
    @State private var onboardingChecked = false
    /// The first-run walkthrough is a sheet over the tab, like Memory's.
    @State private var showOnboarding = false
    /// The first load has been running long enough to say so (see `initialLoad`).
    @State private var loadIsSlow = false

    var body: some View {
        Group {
            if !auth.isSignedIn {
                // Already signed in with Apple on this device: one tap, not a sign-in form.
                if apple.isSignedIn { FriendsConnectView() } else { FriendsSignInView() }
            } else if ageGate.isRestricted {
                restrictedView
            } else if ageGate.needsAgeCheck {
                AgeGateView()
            } else {
                // Always the real layout, never a blank spinner: cached data paints at once and
                // the skeleton stands in until the first load lands.
                content
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) { toast }
        .task { await bootstrap() }
        // Keep the screen live while open (friends join, progress changes).
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if !store.isLoading { await refreshAll() }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await refreshAll() } }
        }
        // Connection came back: don't make the user find the Try again button.
        .onChange(of: connectivity.hasNetwork) { online in
            if online { Task { await refreshAll() } }
        }
        .onChange(of: auth.isSignedIn) { _ in
            onboardingChecked = false   // re-decide for whichever account signs in next
            showOnboarding = false
            Task { await bootstrap() }
        }
        .onChange(of: ageGate.status) { _ in Task { await bootstrap() } }
        .onChange(of: store.pendingInviteCode) { _ in Task { await consumePendingInvite() } }
        .onChange(of: store.infoMessage) { msg in autoClear(msg) { store.infoMessage = nil } }
        .onChange(of: store.errorMessage) { msg in autoClear(msg, after: 6) { store.errorMessage = nil } }
        .onChange(of: shared.infoMessage) { msg in autoClear(msg) { shared.infoMessage = nil } }
        .onChange(of: shared.errorMessage) { msg in autoClear(msg, after: 6) { shared.errorMessage = nil } }
        .onChange(of: reading.infoMessage) { msg in autoClear(msg) { reading.infoMessage = nil } }
        .onChange(of: reading.errorMessage) { msg in autoClear(msg, after: 6) { reading.errorMessage = nil } }
        .sheet(isPresented: $showOnboarding, onDismiss: finishOnboarding) {
            FriendsOnboardingView { showOnboarding = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAddFriend) { AddFriendSheet() }
        .sheet(item: $historyFriend) { QuizHistorySheet(friendName: $0.displayName) }
        .alert("Remove friend?", isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } })) {
            Button("Remove", role: .destructive) { if let f = friendToRemove { Task { await store.remove(f) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("\(friendToRemove?.displayName ?? "They") won't see your activity anymore.") }
        .alert("Block \(friendToBlock?.displayName ?? "this person")?", isPresented: Binding(get: { friendToBlock != nil }, set: { if !$0 { friendToBlock = nil } })) {
            Button("Block", role: .destructive) { if let f = friendToBlock { Task { await store.block(f) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("They'll be removed as a friend and can't reconnect with you.") }
    }

    // MARK: Toast

    @ViewBuilder
    private var toast: some View {
        let error = store.errorMessage ?? shared.errorMessage ?? reading.errorMessage
        let info = store.infoMessage ?? shared.infoMessage ?? reading.infoMessage
        Group {
            if let error { FriendsToast(message: error, isError: true) }
            else if let info { FriendsToast(message: info, isError: false) }
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: error)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: info)
    }

    private func autoClear(_ message: String?, after seconds: UInt64 = 4, _ clear: @escaping () -> Void) {
        guard message != nil else { return }
        Task { try? await Task.sleep(nanoseconds: seconds * 1_000_000_000); clear() }
    }

    // MARK: Lifecycle

    /// Loads friends, shared verses and shared readings at the same time. The work runs in an
    /// unstructured task so leaving the tab mid-load doesn't cancel it (and flag us offline).
    private func refreshAll() async {
        await Task {
            async let friends: Void = store.refresh()
            async let verses: Void = shared.refresh()
            async let readings: Void = reading.refresh()
            _ = await (friends, verses, readings)
        }.value
    }

    private func bootstrap() async {
        store.hydrateFromCache()
        // Local decision (per account, per device): doesn't need to wait on the network.
        decideOnboarding()
        async let invite: Void = consumePendingInvite()
        await refreshAll()
        await invite
        await store.syncActivity()
    }

    /// The walkthrough runs once per account on this device, the first time the tab is opened
    /// with a connected account. Sharing stays off unless the user turns it on there.
    private func decideOnboarding() {
        guard auth.isSignedIn, ageGate.status == .allowed, !onboardingChecked else { return }
        onboardingChecked = true
        if !FriendsOnboarding.isDone(for: auth.userId) { showOnboarding = true }
    }

    /// Runs when the sheet goes away, whether the user finished, skipped, or swiped it down.
    private func finishOnboarding() {
        FriendsOnboarding.markDone(for: auth.userId)
        Task {
            await consumePendingInvite()
            await refreshAll()
        }
    }

    private func consumePendingInvite() async {
        // Hold the invite until onboarding (and its consent step) is finished.
        guard onboardingChecked, !showOnboarding else { return }
        guard auth.isSignedIn, ageGate.status == .allowed, let code = store.pendingInviteCode else { return }
        store.pendingInviteCode = nil
        await store.redeem(code)
    }

    private var restrictedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Color.reforgedGold)
            Text("Friends is for ages 13 and up")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("You can keep reading and memorizing on your own.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(spacing: FriendsLayout.sectionSpacing) {
                if store.hasLoadedOnce {
                    if connectivity.isOffline { offlinePill }

                    if !store.requests.isEmpty { friendRequestsBlock }

                    if store.friends.isEmpty && store.requests.isEmpty {
                        emptyHero
                    } else if !store.friends.isEmpty {
                        TogetherCards()
                        ReadTogetherCards()
                        friendsBlock
                    }

                    settingsRow
                } else {
                    initialLoad
                }
            }
            .frame(maxWidth: FriendsLayout.maxWidth)
            .padding(.horizontal, FriendsLayout.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)   // clear the floating tab bar
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .refreshable {
            // Run in an unstructured task: SwiftUI cancels the refreshable task when the
            // content re-renders, which would abort the requests mid-flight.
            await refreshAll()
        }
    }

    // MARK: Offline

    /// True offline vs. a server or connection that is merely failing or slow.
    private var offlineTitle: String {
        connectivity.hasNetwork ? "Can't reach Reforged" : "You're offline"
    }

    /// Small, quiet note instead of an error banner: data on screen is the last update.
    private var offlinePill: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash").font(.footnote.weight(.semibold))
            Text("\(offlineTitle). Showing your last update.")
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        .padding(.horizontal, 14).frame(minHeight: 34)
        .background(Color.adaptiveCardBackground(colorScheme), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.adaptiveBorder(colorScheme).opacity(0.5), lineWidth: 0.5))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: First load

    /// What the tab shows before any real data exists (no cache, nothing loaded yet):
    /// the skeleton while we wait, then a clear offline or retry card if the load fails.
    /// A failed load is never allowed to look like "no friends".
    @ViewBuilder
    private var initialLoad: some View {
        if store.loadFailed {
            loadFailedCard
        } else {
            VStack(spacing: 18) {
                FriendsSkeleton()
                if loadIsSlow {
                    VStack(spacing: 10) {
                        Text("Taking longer than usual…")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Button("Try again") { retry() }
                            .buttonStyle(PillButtonStyle(filled: false))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: loadIsSlow)
            .task {
                // Restarts each time the skeleton appears; cancelled when real data replaces it.
                loadIsSlow = false
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if !Task.isCancelled { loadIsSlow = true }
            }
        }
    }

    private var loadFailedCard: some View {
        let offline = connectivity.isOffline
        return VStack(spacing: 14) {
            Image(systemName: offline ? "wifi.slash" : "exclamationmark.icloud")
                .font(.system(size: 34))
                .foregroundStyle(Color.reforgedGold)
            Text(offline ? offlineTitle : "Couldn't load Friends")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(offline
                 ? "Your friends and shared readings will load when you're back online."
                 : "Something went wrong on our end. Give it another try.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Button("Try again") { retry() }
                .buttonStyle(PillButtonStyle())
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func retry() {
        loadIsSlow = false
        store.beginRetry()
        Task { await refreshAll() }
    }

    // MARK: Empty state

    private var emptyHero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.reforgedGold.opacity(0.14)).frame(width: 96, height: 96)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
            }
            VStack(spacing: 8) {
                Text("Better together")
                    .font(.title2.bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Invite someone you trust. Encourage each other and memorize verses side by side.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Button { showAddFriend = true } label: {
                Label("Invite a friend", systemImage: "person.badge.plus")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: Friend requests

    private var friendRequestsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Friend requests")
            VStack(spacing: 0) {
                ForEach(Array(store.requests.enumerated()), id: \.element.id) { index, request in
                    if index > 0 { Divider().padding(.leading, 60) }
                    HStack(spacing: 12) {
                        FriendAvatar(name: request.displayName)
                        Text(request.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer(minLength: 8)
                        Button("Decline") { Task { await store.respond(to: request, accept: false) } }
                            .buttonStyle(PillButtonStyle(filled: false))
                        Button("Accept") { Task { await store.respond(to: request, accept: true) } }
                            .buttonStyle(PillButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
            }
            .friendsCard()
        }
    }

    // MARK: Friends

    private var friendsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Your friends", subtitle: "\(store.friends.count) connected") {
                Button { showAddFriend = true } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.reforgedGold)
                        .frame(width: 44, height: 44)
                        .background(Color.reforgedGold.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("Add a friend")
            }
            VStack(spacing: 0) {
                ForEach(Array(store.friends.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 { Divider().padding(.leading, 60) }
                    friendRow(friend)
                }
            }
            .friendsCard(padding: 8)
        }
    }

    private func friendRow(_ friend: FriendActivity) -> some View {
        HStack(spacing: 12) {
            FriendAvatar(name: friend.displayName)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(friend.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if friend.isMuted {
                        Image(systemName: "bell.slash.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                statusLine(friend)
            }
            Spacer(minLength: 8)
            Menu {
                Section("Encourage") {
                    ForEach(FriendNudgeKind.allCases) { kind in
                        Button { Task { await store.nudge(friend, kind: kind) } } label: {
                            Label(kind.label, systemImage: kind.icon)
                        }
                    }
                }
                if !SharedVersesStore.shared.log(for: friend.displayName).isEmpty {
                    Button { historyFriend = friend } label: {
                        Label("Quiz history", systemImage: "clock.arrow.circlepath")
                    }
                }
                Button { Task { await store.setMuted(friend, muted: !friend.isMuted) } } label: {
                    Label(friend.isMuted ? "Unmute" : "Mute", systemImage: friend.isMuted ? "bell.fill" : "bell.slash")
                }
                Button(role: .destructive) { friendToRemove = friend } label: {
                    Label("Remove friend", systemImage: "person.badge.minus")
                }
                Button(role: .destructive) { friendToBlock = friend } label: {
                    Label("Block", systemImage: "hand.raised.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(friend.displayName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusLine(_ friend: FriendActivity) -> some View {
        if friend.sharesNothing {
            Text("Not sharing activity")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if let streak = friend.currentStreak {
                        Label("\(streak) day\(streak == 1 ? "" : "s")", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                    if let read = friend.readToday {
                        Text(read ? "Read today" : "Not yet today")
                            .foregroundStyle(read ? Color.green : Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                let details = [friend.chaptersThisWeek.map { "\($0) chapter\($0 == 1 ? "" : "s") this week" },
                               friend.versesMemorized.map { "\($0) verse\($0 == 1 ? "" : "s")" }]
                    .compactMap { $0 }.joined(separator: " · ")
                if !details.isEmpty {
                    Text(details).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .font(.footnote)
        }
    }

    // MARK: Settings row

    private var settingsRow: some View {
        NavigationLink {
            SharingSettingsView(onReplayIntro: { withAnimation { showOnboarding = true } })
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 36, height: 36)
                    .background(Color.reforgedGold.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sharing & privacy")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(store.prefs.sharesAnything ? "You're sharing some progress" : "Nothing is shared yet")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .friendsCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add a friend

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store = FriendsStore.shared
    @State private var enteredCode = ""
    @State private var showFind = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FriendsLayout.sectionSpacing) {
                    inviteCard
                    actionsCard
                    codeCard
                    Text("Friends connect only through invite codes, links, or requests. Picking a contact stays on your phone; nothing from your contacts is uploaded. There's no public search.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: FriendsLayout.maxWidth)
                .padding(FriendsLayout.screenPadding)
                .frame(maxWidth: .infinity)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { if store.myInviteCode == nil { await store.createInvite() } }
            .sheet(isPresented: $showFind) { FindFromContactsView() }
            .overlay(alignment: .top) {
                if let msg = store.errorMessage { FriendsToast(message: msg, isError: true).padding(.top, 8) }
                else if let msg = store.infoMessage { FriendsToast(message: msg, isError: false).padding(.top, 8) }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.errorMessage)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.infoMessage)
        }
    }

    private var inviteCard: some View {
        VStack(spacing: 16) {
            if let link = store.inviteLink, let code = store.myInviteCode {
                QRCodeView(string: link.absoluteString)
                    .frame(width: 160, height: 160)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(code)
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .textSelection(.enabled)
                Text("Works once, and expires in 7 days.")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                ShareLink(item: link, message: Text("Join me on Reforged to read and memorize Scripture together. Code: \(code)")) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle(prominent: true))
            } else {
                ProgressView().padding(.vertical, 60)
            }
        }
        .frame(maxWidth: .infinity)
        .friendsCard(padding: 24)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            InviteFromContactsButton()
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.isAdult {
                Divider()
                Button { showFind = true } label: {
                    Label("Find friends on Reforged", systemImage: "person.crop.circle.badge.questionmark")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
            }
        }
        .tint(Color.reforgedGold)
        .friendsCard()
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Have a code?")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            HStack(spacing: 10) {
                TextField("Enter code", text: $enteredCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Color.reforgedGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("Add") {
                    let code = enteredCode
                    Task { if await store.redeem(code) { enteredCode = ""; dismiss() } }
                }
                .buttonStyle(PillButtonStyle())
                .disabled(enteredCode.trimmingCharacters(in: .whitespaces).count < 6)
            }
        }
        .friendsCard()
    }
}

// MARK: - Sharing & privacy

struct SharingSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store = FriendsStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDeleteAll = false
    @State private var iosNotificationsDenied = false
    var onReplayIntro: () -> Void

    var body: some View {
        Form {
            Section {
                toggle("Streak and read-today", icon: "flame.fill", \.shareStreak)
                toggle("Chapters read this week", icon: "book.fill", \.shareWeeklyChapters)
                toggle("Verses memorized", icon: "brain.head.profile", \.shareVersesMemorized)
            } header: {
                Text("What friends can see")
            } footer: {
                Text("Everything is off until you turn it on. Sharing your Bible reading can reveal your faith, so it's your choice. Friends see only totals, never what you read, your notes, or your prayers.")
            }

            Section {
                toggle("Allow friends to encourage me", icon: "bell.badge.fill", \.allowNudges)
                if store.prefs.allowNudges && iosNotificationsDenied {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notifications are off for Reforged in iOS Settings, so friends' encouragement can't reach you.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Encouragement")
            } footer: {
                Text("Friends can send short preset messages like \"Keep going\". You can mute anyone.")
            }

            if store.isAdult {
                Section {
                    Toggle(isOn: Binding(get: { store.discoverable },
                                         set: { on in Task { await store.setDiscoverable(on) } })) {
                        Label("Let people with my email find me", systemImage: "magnifyingglass")
                    }
                    .tint(Color.reforgedGold)
                } header: {
                    Text("Finding you")
                } footer: {
                    Text("People who have your email in their contacts and have also turned this on can see your first name and send a request. Nothing is shared until you accept.")
                }
            }

            Section {
                Button { onReplayIntro() } label: { Label("How Friends works", systemImage: "questionmark.circle") }
                Button(role: .destructive) { confirmDeleteAll = true } label: {
                    Label("Delete my Friends data", systemImage: "trash")
                }
            } footer: {
                Text("Friends is for ages 13 and up. Adults and under-18s can't connect with each other.")
            }
        }
        .tint(Color.reforgedGold)
        .navigationTitle("Sharing & privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkIOSNotifications() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await checkIOSNotifications() } }
        }
        .alert("Delete all Friends data?", isPresented: $confirmDeleteAll) {
            Button("Delete", role: .destructive) { Task { await store.deleteAllMyFriendData() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes your friendships, sharing choices and shared activity from our servers.") }
    }

    private func checkIOSNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        iosNotificationsDenied = settings.authorizationStatus == .denied
    }

    private func toggle(_ title: String, icon: String, _ keyPath: WritableKeyPath<FriendSharingPrefs, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { store.prefs[keyPath: keyPath] },
            set: { newValue in
                var p = store.prefs
                p[keyPath: keyPath] = newValue
                Task { await store.updatePrefs(p) }
            })) {
            Label(title, systemImage: icon)
        }
        .tint(Color.reforgedGold)
    }
}
