import SwiftUI
import AuthenticationServices
import UIKit
import CoreImage
import AVFoundation

// MARK: - Groups Tab Root
//
// Top-level router for the Groups tab. Decides, in order:
//   1. signed out           -> sign-in prompt
//   2. age unknown          -> AgeGateView            (Requirements §1)
//   3. under 13 (restricted)-> RestrictedView         (Requirements §1)
//   4. 13+ and signed in    -> GroupsHubContainer      (join + hub)
//
// All shared state (age status, auth, block list) lives in singletons already
// used elsewhere in the app, so the router just observes them.

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var ageGate = AgeGateManager.shared
    @StateObject private var auth = SupabaseAuthService.shared

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    GroupsSignInView()
                } else if ageGate.needsAgeCheck {
                    AgeGateView()
                } else if ageGate.isRestricted {
                    RestrictedView()
                } else {
                    GroupsHubContainer()
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        }
        .tint(Color.reforgedGold)
    }
}

// Local copy of the onboarding auth-field styling (the original is fileprivate
// to OnboardingFlowView), so Groups sign-in fields match the rest of the app.
private extension View {
    func authTextField(colorScheme: ColorScheme) -> some View {
        self
            .padding()
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1.5)
            )
    }
}

// MARK: - Sign In (Supabase email/password)
//
// Groups talks to Supabase (PostgREST + RLS keyed on auth.uid()), which requires
// a Supabase session token. Signing in with Apple alone does NOT create a
// Supabase session, so Groups needs a Reforged email account here even for users
// who onboarded with Apple. On success, `SupabaseAuthService.isSignedIn` flips
// and the router (which observes it) advances past this screen automatically.

private enum GroupsAuthTab { case signIn, createAccount }

struct GroupsSignInView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var tab: GroupsAuthTab = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEmailConfirmation = false
    @State private var appleRawNonce = ""

    private let supabase = SupabaseAuthService.shared

    private var canSubmit: Bool { !isLoading && !email.isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.badge.key.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.reforgedGold)
                    Text(tab == .signIn ? "Sign in to Groups" : "Create your account")
                        .font(.title2).bold()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Groups sync securely across devices with a Reforged account. If you signed in with Apple, sign in or create an email account here to use Groups.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Picker("Auth", selection: $tab) {
                    Text("Sign In").tag(GroupsAuthTab.signIn)
                    Text("Create Account").tag(GroupsAuthTab.createAccount)
                }
                .pickerStyle(.segmented)
                .onChange(of: tab) { _ in errorMessage = nil; showEmailConfirmation = false }

                if showEmailConfirmation {
                    confirmationBanner
                } else {
                    formFields
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.reforgedCoral)
                            .multilineTextAlignment(.center)
                    }
                    ZStack {
                        Button(action: { Task { await handleAuth() } }) {
                            Text(tab == .signIn ? "Sign In" : "Create Account")
                                .reforgedPrimaryButton()
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.6)
                        if isLoading { ProgressView().tint(.white) }
                    }
                }

                // — or —
                HStack(spacing: 12) {
                    Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
                }

                // Sign in with Apple → exchanged for a Supabase session so Groups
                // works for Apple users without a separate email account.
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    let raw = AppleSignInService.randomNonceString()
                    appleRawNonce = raw
                    request.nonce = AppleSignInService.sha256(raw)
                } onCompletion: { handleAppleResult($0) }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                .disabled(isLoading)
            }
            .frame(maxWidth: 500)
            .padding(20)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  !appleRawNonce.isEmpty else {
                errorMessage = "Couldn't read your Apple credential. Please try again."
                return
            }
            isLoading = true
            Task {
                defer { isLoading = false }
                AppleSignInService.shared.userIdentifier = credential.user
                AppleSignInService.shared.isSignedIn = true
                let res = await supabase.signInWithApple(idToken: idToken, rawNonce: appleRawNonce)
                if res.success, let uid = res.userId {
                    appState.signedInWithSupabase(userId: uid, email: credential.email ?? "")
                    HapticManager.shared.success()
                } else {
                    errorMessage = res.errorMessage ?? "Apple sign-in failed."
                }
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        }
    }

    private var formFields: some View {
        VStack(spacing: 14) {
            if tab == .createAccount {
                TextField("Display Name", text: $displayName)
                    .authTextField(colorScheme: colorScheme)
                    .textContentType(.name)
            }
            TextField("Email", text: $email)
                .authTextField(colorScheme: colorScheme)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Password", text: $password)
                .authTextField(colorScheme: colorScheme)
                .textContentType(tab == .signIn ? .password : .newPassword)
            if tab == .createAccount {
                SecureField("Confirm Password", text: $confirmPassword)
                    .authTextField(colorScheme: colorScheme)
                    .textContentType(.newPassword)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tab)
    }

    private var confirmationBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.reforgedGold)
            Text("Check your inbox at **\(email)**.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
            Text("Tap the confirmation link, then come back and sign in.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
            Button("Sign In Instead") {
                withAnimation { tab = .signIn; showEmailConfirmation = false }
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
        }
        .padding(16)
        .background(Color.reforgedGold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func handleAuth() async {
        errorMessage = nil
        guard canSubmit else { return }

        if tab == .createAccount {
            guard password == confirmPassword else { errorMessage = "Passwords don't match."; return }
            guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        }

        isLoading = true
        defer { isLoading = false }

        if tab == .signIn {
            let result = await supabase.signIn(email: email, password: password)
            if result.success, let uid = result.userId {
                appState.signedInWithSupabase(userId: uid, email: email)
                HapticManager.shared.success()
            } else {
                errorMessage = result.errorMessage ?? "Sign-in failed."
            }
        } else {
            let name = displayName.isEmpty ? String(email.split(separator: "@").first ?? "") : displayName
            let result = await supabase.signUp(email: email, password: password, displayName: name)
            if result.success, let uid = result.userId {
                appState.signedInWithSupabase(userId: uid, email: email)
                if !name.isEmpty { appState.user.displayName = name }
                HapticManager.shared.success()
            } else if result.emailConfirmationRequired {
                withAnimation { showEmailConfirmation = true }
            } else {
                errorMessage = result.errorMessage ?? "Couldn't create your account."
            }
        }
    }
}

// MARK: - Age Gate (Requirements §1)

struct AgeGateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var ageGate = AgeGateManager.shared

    /// Default the picker to 13 years ago so a tap-through lands on the boundary
    /// rather than "today" (which would read as newborn).
    @State private var birthDate: Date = Calendar.current.date(
        byAdding: .year, value: -13, to: Date()) ?? Date()
    @State private var didInteract = false

    private var maxDate: Date { Date() }
    private var minDate: Date { Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.reforgedGold)
                    Text("One quick check")
                        .font(.title2).bold()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("To keep Groups safe for everyone, tell us your date of birth. We store this on your device and don't share it with your group.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                DatePicker(
                    "Date of birth",
                    selection: $birthDate,
                    in: minDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color.reforgedGold)
                .padding(12)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: birthDate) { _ in didInteract = true }

                Button {
                    HapticManager.shared.buttonTap()
                    ageGate.submit(birthDate: birthDate)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.reforgedGold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .opacity(didInteract ? 1 : 0.6)
                .disabled(!didInteract)

                Text("Reforged follows children's privacy laws (COPPA and GDPR-K). If you're under 13, Groups isn't available yet.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(20)
        }
    }
}

// MARK: - Restricted (under 13)

struct RestrictedView: View {
    var body: some View {
        GroupsMessageScaffold(
            systemImage: "hand.raised.fill",
            title: "Features restricted to ages 13 and up",
            message: "Group features are currently restricted to ages 13 and up. Parental permission options are coming in a future update. In the meantime, everything else in Reforged — reading, memory, and your journal — is all yours."
        )
    }
}

// MARK: - Hub Container (join vs. hub)

private struct GroupsHubContainer: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = GroupsHubViewModel()

    var body: some View {
        Group {
            switch model.loadState {
            case .idle, .loading:
                GroupsLoadingView(message: "Loading your groups…")
            case .error(let message):
                GroupsErrorView(message: message) { Task { await model.load() } }
            case .loaded:
                if model.groups.isEmpty {
                    GroupJoinView { joined in
                        Task { await model.selectAfterJoining(joined) }
                    }
                } else if let selected = model.selectedGroup {
                    GroupHubView(model: model, group: selected)
                } else {
                    GroupJoinView { joined in
                        Task { await model.selectAfterJoining(joined) }
                    }
                }
            }
        }
        .task { await model.loadIfNeeded() }
        .task(id: appState.pendingGroupInviteCode) { await consumePendingInvite() }
        .onChange(of: model.loadState) { _ in Task { await consumePendingInvite() } }
    }

    /// Auto-joins a code delivered by a `reforged://join?code=…` deep link once
    /// the hub has finished loading.
    private func consumePendingInvite() async {
        guard let code = appState.pendingGroupInviteCode, model.loadState == .loaded else { return }
        if await model.redeem(inviteCode: code) {
            appState.pendingGroupInviteCode = nil
        }
    }
}

// MARK: - Group Join (Requirements §2)

struct GroupJoinView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    let onJoined: (GroupSummary) -> Void

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showScanner = false
    @FocusState private var fieldFocused: Bool

    private let codeLength = 6
    private let leaderURL = URL(string: "https://reforgedapp.org/leader")!

    private var normalized: String {
        String(code.uppercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.prefix(codeLength))
    }
    private var canSubmit: Bool { normalized.count == codeLength && !isSubmitting }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                whatAreGroups
                studentCard
                leaderCard
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showScanner) {
            GroupQRScannerView { scanned in
                showScanner = false
                handleScanned(scanned)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.reforgedGold)
            Text("Groups")
                .font(.title2).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Read Scripture, memorize verses, and pray together — guided by a leader.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(.top, 8)
    }

    // MARK: What groups are

    private var whatAreGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(icon: "book.fill",
                       title: "Follow a shared plan",
                       detail: "Your leader assigns readings, memory verses, and reflection prompts that show up right here.")
            benefitRow(icon: "hands.and.sparkles.fill",
                       title: "Pray for one another",
                       detail: "Share requests and lift up your group through the week.")
            benefitRow(icon: "chart.line.uptrend.xyaxis",
                       title: "Grow together",
                       detail: "Keep each other encouraged and accountable as you dig into God's Word.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).bold()
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    // MARK: Student path

    private var studentCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Have a code?")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Scan your leader's QR code, or enter the 6-character code.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Button {
                showScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR code")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.reforgedGold)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 10) {
                Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
                Text("or")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
            }

            codeField

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.reforgedCoral)
                    .transition(.opacity)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Joining…" : "Join")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.reforgedGold : Color.reforgedGold.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Leader path

    private var leaderCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Want to lead a group?")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Create a group, invite members, and build reading plans from the leader dashboard.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Button {
                openURL(leaderURL)
            } label: {
                HStack(spacing: 8) {
                    Text("Get started at reforgedapp.org/leader")
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.reforgedGold)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.reforgedGold, lineWidth: 1.5)
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var codeField: some View {
        // A single hidden text field drives six visible character slots.
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .opacity(0.01)
                .onChange(of: code) { _ in
                    code = normalized
                    errorMessage = nil
                }

            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    let chars = Array(normalized)
                    Text(index < chars.count ? String(chars[index]) : "")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(width: 44, height: 56)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(index == normalized.count ? Color.reforgedGold : Color.adaptiveBorder(colorScheme),
                                        lineWidth: index == normalized.count ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .onTapGesture { fieldFocused = true }
        }
    }

    /// Accepts a raw code, a `reforged://join?code=…` deep link, or a web invite link
    /// (`https://reforgedapp.org/join/{code}`) from the scanned QR payload, fills the field,
    /// and auto-joins when it's a valid code.
    private func handleScanned(_ raw: String) {
        var candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URLComponents(string: candidate) {
            if let queryCode = url.queryItems?.first(where: { $0.name.lowercased() == "code" })?.value {
                candidate = queryCode
            } else {
                // Path-based invite link, e.g. https://reforgedapp.org/join/ABC123
                // or reforged://join/ABC123 (where "join" is the host).
                let parts = url.path.split(separator: "/").map(String.init)
                if let joinIdx = parts.firstIndex(where: { $0.lowercased() == "join" }),
                   joinIdx + 1 < parts.count {
                    candidate = parts[joinIdx + 1]
                } else if url.host?.lowercased() == "join", let first = parts.first {
                    candidate = first
                }
            }
        }
        code = candidate           // triggers onChange, which normalizes `code`
        let cleaned = normalized   // recomputed from the value just set
        if cleaned.count == codeLength {
            Task { await submit() }
        } else {
            // Defer so the field's onChange (which clears errors) doesn't wipe this.
            DispatchQueue.main.async { errorMessage = "That QR code didn't contain a valid group code." }
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            // One atomic RPC: look up the group by code + join it, server-side.
            let group = try await GroupsService.shared.redeemInviteCode(normalized)
            HapticManager.shared.success()
            onJoined(group)
        } catch GroupsError.notFound {
            errorMessage = "No group found for that code. Double-check it with your leader."
        } catch {
            errorMessage = (error as? GroupsError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Group Hub

struct GroupHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: GroupsHubViewModel
    let group: GroupSummary

    // "Lessons" hosts the assignment-based tracks browser (the old flat "Track"
    // view keyed off the now-legacy leader_tracks.group_id). The free-text
    // reflection Feed stays hidden until that table exists; Prayer is live.
    enum Section: String, CaseIterable { case lessons = "Lessons", prayer = "Prayer", handouts = "Handouts", members = "Members" }
    @State private var section: Section = .lessons

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupHeroHeader(group: group, members: model.members)

                Picker("Section", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Group {
                    switch section {
                    case .lessons:  TracksListView()
                    case .prayer:   GroupPrayerHubView(group: group)
                    case .handouts: GroupHandoutsList(model: model, group: group)
                    case .members:  GroupMembersList(model: model, group: group)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .coordinateSpace(name: "groupScroll")
        .ignoresSafeArea(edges: .top)               // let the hero reach the very top
        .refreshable { await model.refreshCurrent() }
        // The group name in the hero is the real title, so hide the app-level nav bar
        // entirely — that's what lets the cover image bleed to the very top with its
        // scrims intact (a large parent title would otherwise reserve an opaque bar).
        .toolbar(.hidden, for: .navigationBar)
        // Group switcher floats over the hero instead of living in the (hidden) nav bar.
        .overlay(alignment: .topTrailing) { groupSwitcher }
    }

    @ViewBuilder private var groupSwitcher: some View {
        if model.groups.count > 1 {
            Menu {
                ForEach(model.groups) { g in
                    Button(g.name) { Task { await model.select(g) } }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 12)
            .padding(.top, 54)   // clear the status bar / dynamic island
        }
    }
}

// MARK: - Hero Header (full-bleed, stretchy cover)

/// Edge-to-edge cover that reaches the top of the screen behind the nav title.
/// Stretches when the scroll rubber-bands, with top/bottom scrims so both the
/// white "Groups" nav title and the overlaid group name stay legible.
private struct GroupHeroHeader: View {
    let group: GroupSummary
    let members: [GroupMemberProfile]

    private let baseHeight: CGFloat = 300

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("groupScroll")).minY
            let stretch = max(0, minY)
            let height = baseHeight + stretch

            ZStack(alignment: .bottomLeading) {
                cover
                    .frame(width: geo.size.width, height: height)
                    .clipped()

                // Top scrim (nav title) + bottom scrim (group name).
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0.0),
                        .init(color: .clear,               location: 0.32),
                        .init(color: .clear,               location: 0.5),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: geo.size.width, height: height)

                VStack(alignment: .leading, spacing: 10) {
                    Text(group.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)

                    if let desc = group.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }

                    if !members.isEmpty { memberStrip }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(width: geo.size.width, height: height)
            .offset(y: -stretch)
        }
        .frame(height: baseHeight)
    }

    @ViewBuilder private var cover: some View {
        if let path = group.coverImagePath, !path.isEmpty {
            SignedAsyncImage(bucket: "group-covers", path: path)
        } else {
            LinearGradient(colors: [Color.reforgedGold.opacity(0.7), Color.reforgedCoral.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var memberStrip: some View {
        HStack(spacing: -10) {
            ForEach(members.prefix(5)) { m in
                Text(m.avatar)
                    .font(.subheadline)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
            }
            Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                .font(.caption).bold()
                .foregroundStyle(.white.opacity(0.9))
                .padding(.leading, 14)
                .shadow(color: .black.opacity(0.4), radius: 3)
        }
    }
}

// MARK: - Signed image loader (private buckets)

/// Loads an image from a private Supabase bucket by minting a signed URL first,
/// then handing it to `AsyncImage`. Falls back to a brand gradient on failure.
struct SignedAsyncImage: View {
    let bucket: String
    let path: String
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .empty:              ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:                  placeholder
                    }
                }
            } else if failed {
                placeholder
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: path) {
            url = try? await GroupsService.shared.signedURL(bucket: bucket, path: path)
            failed = (url == nil)
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color.reforgedGold.opacity(0.65), Color.reforgedCoral.opacity(0.5)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - QR Code

/// Renders a QR code for `string` using CoreImage. Black modules on a clear
/// background — place it on a light backing for scannability.
struct QRCodeView: View {
    let string: String
    private static let context = CIContext()

    var body: some View {
        if let image = Self.make(string) {
            Image(uiImage: image)
                .interpolation(.none)      // keep modules crisp when scaled
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable().scaledToFit()
                .foregroundStyle(.black.opacity(0.3))
        }
    }

    private static func make(_ string: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Members List + Leave

private struct GroupMembersList: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: GroupsHubViewModel
    let group: GroupSummary

    @State private var showLeaveConfirm = false
    @State private var isLeaving = false
    @State private var leaveError: String?
    @State private var didCopy = false

    /// Deep link that opens Reforged straight to the Groups tab and auto-joins.
    private var inviteLink: String { "reforged://join?code=\(group.inviteCode)" }

    private var shareMessage: String {
        """
        Join “\(group.name)” on Reforged 📖

        Tap to join (opens the app): \(inviteLink)

        Or open Reforged → Groups tab → enter invite code: \(group.inviteCode)
        """
    }

    var body: some View {
        VStack(spacing: 12) {
            inviteCard

            if model.members.isEmpty {
                GroupsMessageScaffold(systemImage: "person.2",
                                      title: "No members to show",
                                      message: "Members will appear here.")
                    .padding(.top, 20)
            } else {
                ForEach(model.members) { m in
                    HStack(spacing: 12) {
                        Text(m.avatar)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.reforgedGold.opacity(0.15)))
                        Text(m.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        if m.userId == group.leaderId {
                            Text("Leader")
                                .font(.caption2).bold()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.reforgedGold.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        }
                    }
                    .padding(14)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            if let leaveError {
                Text(leaveError).font(.caption).foregroundStyle(Color.reforgedCoral)
            }

            Button(role: .destructive) {
                showLeaveConfirm = true
            } label: {
                HStack {
                    if isLeaving { ProgressView().tint(Color.reforgedCoral) }
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Leave group")
                }
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Color.reforgedCoral)
                .background(Color.reforgedCoral.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLeaving)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .confirmationDialog("Leave \(group.name)?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave group", role: .destructive) { Task { await leave() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll stop seeing this group's track and handouts. You can rejoin anytime with the invite code.")
        }
    }

    private var inviteCard: some View {
        VStack(spacing: 14) {
            // Scannable QR that opens the app and auto-joins. Black modules need
            // a light backing to stay scannable on a dark card.
            QRCodeView(string: inviteLink)
                .frame(width: 168, height: 168)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Scan to join instantly — or share the code below")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INVITE CODE")
                        .font(.caption2).bold()
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(group.inviteCode)
                        .font(.system(.title2, design: .monospaced)).bold()
                        .foregroundStyle(Color.reforgedGold)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = group.inviteCode
                    HapticManager.shared.success()
                    withAnimation { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { didCopy = false }
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(Color.reforgedGold)
                        .frame(width: 40, height: 40)
                        .background(Color.reforgedGold.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            ShareLink(item: shareMessage) {
                Label("Share invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.reforgedGold)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func leave() async {
        isLeaving = true
        leaveError = nil
        defer { isLeaving = false }
        do {
            try await model.leaveGroup(group)
            HapticManager.shared.success()
        } catch {
            leaveError = "Couldn't leave the group: \((error as? GroupsError)?.errorDescription ?? error.localizedDescription)"
        }
    }
}

// MARK: - Pulse Card

private struct PulseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let completed: Int
    let total: Int

    private var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Progress")
                .font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text(total == 0 ? "No items yet" : "\(completed)/\(total) completed")
                .font(.title3).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            ProgressView(value: fraction)
                .tint(Color.reforgedGold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Feed List + Moderated Card (Requirements §3)

private struct GroupFeedList: View {
    @ObservedObject var model: GroupsHubViewModel
    @StateObject private var blocks = BlockListStore.shared
    let group: GroupSummary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if model.feed.isEmpty {
                    GroupsMessageScaffold(
                        systemImage: "text.bubble",
                        title: "No reflections yet",
                        message: "When your group shares a reflection, it'll show up here."
                    )
                    .padding(.top, 40)
                } else {
                    // Second-layer client-side filter: even if a block landed
                    // after the fetch, hidden authors never render.
                    ForEach(model.feed.filter { !blocks.isBlocked($0.authorId) }) { post in
                        GroupFeedCard(post: post)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await model.refreshFeed(group: group) }
    }
}

/// A free-text feed card carrying the Guideline 1.2 report + block affordances.
struct GroupFeedCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var blocks = BlockListStore.shared
    let post: GroupFeedPost

    @State private var showReport = false
    @State private var actionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.authorName ?? "Group member")
                    .font(.subheadline).bold()
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                moderationMenu
            }
            if let passage = post.passage, !passage.isEmpty {
                Text(passage)
                    .font(.caption).bold()
                    .foregroundStyle(Color.reforgedGold)
            }
            LinkedScriptureText(text: post.applicationText,
                                font: .body,
                                baseColor: Color.adaptiveText(colorScheme))
            if let actionError {
                Text(actionError).font(.caption).foregroundStyle(Color.reforgedCoral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("Report this reflection?",
                            isPresented: $showReport, titleVisibility: .visible) {
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.label, role: .destructive) {
                    Task { await report(reason) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var moderationMenu: some View {
        Menu {
            Button(role: .destructive) { showReport = true } label: {
                Label("Flag Content", systemImage: "flag")
            }
            Button(role: .destructive) { Task { await blockAuthor() } } label: {
                Label("Block \(post.authorName ?? "User")", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }

    private func report(_ reason: ReportReason) async {
        do {
            try await GroupsService.shared.report(contentType: .reflection,
                                                   contentId: post.id,
                                                   reason: reason.rawValue)
            HapticManager.shared.success()
        } catch {
            actionError = "Couldn't submit report. Please try again."
        }
    }

    private func blockAuthor() async {
        do {
            // Optimistic hide is immediate; the parent list filters on
            // `blocks.isBlocked`, so the card disappears the moment this returns.
            try await blocks.block(userId: post.authorId)
            HapticManager.shared.success()
        } catch {
            actionError = "Couldn't block this user. Please try again."
        }
    }
}

enum ReportReason: String, CaseIterable {
    case harassment, inappropriate, spam, selfHarm = "self_harm", other

    var label: String {
        switch self {
        case .harassment:    return "Harassment or bullying"
        case .inappropriate: return "Inappropriate content"
        case .spam:          return "Spam"
        case .selfHarm:      return "Concern for their safety"
        case .other:         return "Something else"
        }
    }
}

// MARK: - Tracks List

private struct GroupTracksList: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: GroupsHubViewModel
    let group: GroupSummary
    @State private var addedMemoryIds: Set<String> = []

    var body: some View {
        LazyVStack(spacing: 12) {
                NavigationLink {
                    TracksListView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(Color.reforgedGold).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse all lessons").font(.subheadline).bold()
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("Tracks & lessons from your groups")
                                .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).bold()
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(14)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if model.trackItems.isEmpty {
                    GroupsMessageScaffold(
                        systemImage: "list.bullet.rectangle",
                        title: "Nothing assigned yet",
                        message: "When your leader publishes a track, its readings, memory verses, and prompts appear here."
                    )
                    .padding(.top, 40)
                } else {
                    if let err = model.completionError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.reforgedCoral)
                            Text("Couldn't save your progress: \(err)")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.reforgedCoral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    ForEach(model.trackItems) { item in
                        GroupTrackItemRow(
                            item: item,
                            isDone: model.completedItemIds.contains(item.id),
                            isAddedToMemory: addedMemoryIds.contains(item.id),
                            onComplete: { Task { await model.toggleComplete(item: item, group: group) } },
                            onPrimary: { primaryAction(item) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
    }

    /// Reading → open the passage in the Bible reader; Memory → add to the
    /// Memory section; Prompt → no cross-app action.
    private func primaryAction(_ item: GroupTrackItem) {
        switch item.type {
        case .reading: openPassage(item.content.reference)
        case .memory:  addMemory(item)
        case .prompt:  break
        }
    }

    private func openPassage(_ reference: String?) {
        guard let reference, !reference.isEmpty else { return }
        HapticManager.shared.buttonTap()
        // Mirror the app's existing cross-tab navigation (see HomeView).
        NotificationCenter.default.post(name: .switchTab, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 2])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .navigateToBibleVerse, object: nil,
                                            userInfo: [AppNotificationUserInfoKey.reference: reference])
        }
    }

    private func addMemory(_ item: GroupTrackItem) {
        // Prefer the leader-provided verse text; if it's missing, fall back to
        // opening the passage so the user can add it from the reader.
        guard let text = item.content.text, !text.isEmpty else {
            openPassage(item.content.reference)
            return
        }
        let translation = BibleTranslation(rawValue: item.content.translation ?? "") ?? .esv
        let verse = MemoryVerse(
            id: UUID().uuidString,
            reference: item.content.reference ?? "Memory Verse",
            text: text,
            esvText: translation == .esv ? text : nil,
            category: "Group",
            translation: translation.rawValue,
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
        appState.addMemoryVerse(verse)
        addedMemoryIds.insert(item.id)
        HapticManager.shared.success()
    }
}

private struct GroupTrackItemRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: GroupTrackItem
    let isDone: Bool
    let isAddedToMemory: Bool
    let onComplete: () -> Void
    let onPrimary: () -> Void

    /// Whether tapping the row does something beyond marking complete.
    private var hasPrimaryAction: Bool {
        switch item.type {
        case .reading: return item.content.reference?.isEmpty == false
        case .memory:  return (item.content.reference?.isEmpty == false) || (item.content.text?.isEmpty == false)
        case .prompt:  return false
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrimary) {
                HStack(spacing: 12) {
                    Image(systemName: item.type.iconName)
                        .foregroundStyle(Color.reforgedGold)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.type.label)
                            .font(.caption).bold()
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text(item.content.reference ?? item.content.text ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(2)
                    }
                    Spacer()
                    affordance
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasPrimaryAction)

            Button(action: onComplete) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var affordance: some View {
        switch item.type {
        case .reading:
            HStack(spacing: 3) {
                Text("Open").font(.caption2).bold()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(Color.reforgedGold)
        case .memory:
            if isAddedToMemory {
                Label("Added", systemImage: "checkmark")
                    .font(.caption2).bold()
                    .foregroundStyle(Color.reforgedGold)
            } else {
                Label("Add", systemImage: "plus.circle")
                    .font(.caption2).bold()
                    .foregroundStyle(Color.reforgedGold)
            }
        case .prompt:
            EmptyView()
        }
    }
}

// MARK: - Shared Loading / Error / Message Scaffolds

struct GroupsLoadingView: View {
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Color.reforgedGold)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GroupsErrorView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.reforgedCoral)
            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Color.reforgedGold)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GroupsMessageScaffold: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Color.reforgedGold)
            Text(title)
                .font(.title3).bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - QR Scanner (join by camera)

/// Full-screen camera sheet that scans a group-invite QR code and hands the raw
/// string back to the caller. Handles the permission gate itself so the caller
/// only ever receives a successful scan.
struct GroupQRScannerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onCode: (String) -> Void

    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch permission {
            case .authorized:
                QRCameraView { code in
                    HapticManager.shared.success()
                    onCode(code)
                }
                .ignoresSafeArea()
                reticle
            case .denied, .restricted:
                deniedView
            case .notDetermined:
                Color.clear.onAppear { requestAccess() }
            @unknown default:
                deniedView
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding(20)
                }
                Spacer()
                if permission == .authorized {
                    Text("Point your camera at your leader's QR code")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(Color.reforgedGold, lineWidth: 3)
            .frame(width: 240, height: 240)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.8))
            Text("Camera access needed")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to scan a group's QR code. You can also enter the code by hand.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.headline)
            .foregroundStyle(Color.reforgedGold)
            .padding(.top, 4)
        }
        .padding(32)
    }

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                permission = granted ? .authorized : .denied
            }
        }
    }
}

/// Thin UIViewController bridge that runs an `AVCaptureSession` and reports the
/// first QR payload it reads. Stops capturing after the first hit.
private struct QRCameraView: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    func makeUIViewController(context: Context) -> QRCaptureController {
        let controller = QRCaptureController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCaptureController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onFound: (String) -> Void
        private var didFind = false
        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didFind,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }
            didFind = true
            onFound(value)
        }
    }
}

/// Hosts the capture session + preview layer; keeps the session on a background
/// queue and tears it down when the view disappears.
final class QRCaptureController: UIViewController {
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "org.reforgedapp.qr-scan")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        sessionQueue.async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }
}
