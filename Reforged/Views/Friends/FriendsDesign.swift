import SwiftUI
import AuthenticationServices

// MARK: - Friends design system
//
// One small vocabulary shared by the whole Friends tab: soft cards (20pt
// continuous corners, hairline border, whisper shadow), pill buttons, quiet
// section headers, and a floating status toast. Gold stays the single accent.

enum FriendsLayout {
    static let maxWidth: CGFloat = 680
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 20
}

struct FriendsCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = FriendsLayout.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FriendsLayout.cornerRadius, style: .continuous)
                    .fill(Color.adaptiveCardBackground(scheme)))
            .overlay(
                RoundedRectangle(cornerRadius: FriendsLayout.cornerRadius, style: .continuous)
                    .strokeBorder(Color.adaptiveBorder(scheme).opacity(0.45), lineWidth: 0.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 14, y: 5)
    }
}

extension View {
    func friendsCard(padding: CGFloat = FriendsLayout.cardPadding) -> some View {
        modifier(FriendsCardModifier(padding: padding))
    }
}

/// Pill button: filled gold for the one primary action, tinted for secondary.
struct PillButtonStyle: ButtonStyle {
    var filled = true
    var prominent = false      // taller, full-size primary CTA

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(prominent ? .headline : .subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, prominent ? 24 : 16)
            .frame(minHeight: prominent ? 50 : 38)
            .foregroundStyle(filled ? Color.white : Color.reforgedGold)
            .background(filled ? Color.reforgedGold : Color.reforgedGold.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet section header: title with an optional trailing accessory.
struct FriendsSectionHeader<Accessory: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(scheme))
                }
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.horizontal, 4)
    }
}

extension FriendsSectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() })
    }
}

// MARK: - Loading skeleton

/// Shimmer that stands still when Reduce Motion is on.
private struct FriendsShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion { content } else { content.shimmer() }
    }
}

/// Grey stand-ins for the Friends tab, shaped like the real cards, shown while the first
/// load is in flight. The frame is on screen immediately; only the data is "thinking".
struct FriendsSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    private var fill: Color { Color.adaptiveTextSecondary(scheme).opacity(0.16) }

    private func bar(_ width: CGFloat, _ height: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
    }

    private var row: some View {
        HStack(spacing: 12) {
            Circle().fill(fill).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                bar(120)
                bar(190, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 10) {
                bar(150, 18).padding(.horizontal, 4)
                VStack(alignment: .leading, spacing: 12) {
                    bar(210)
                    bar(150, 10)
                    bar(96, 36)
                }
                .modifier(FriendsShimmer())
                .friendsCard()
            }
            VStack(alignment: .leading, spacing: 10) {
                bar(120, 18).padding(.horizontal, 4)
                VStack(spacing: 0) {
                    row
                    row
                    row
                }
                .modifier(FriendsShimmer())
                .friendsCard(padding: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your friends")
    }
}

/// Initial-letter avatar in a soft gold wash.
struct FriendAvatar: View {
    let name: String
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(Color.reforgedGold.opacity(0.16))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.reforgedGold)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Floating status toast that replaces inline banners.
struct FriendsToast: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color.red : Color.green)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Signed-out Friends

/// The full account sheet (email or Apple), used by both signed-out screens below.
private struct FriendsAuthSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            AuthStepView(
                onNext: { isPresented = false },
                onExistingUser: {
                    // Already inside the app: merge the account's data instead of re-running setup.
                    appState.isRestoringAccount = false
                    isPresented = false
                    Task { await appState.performFullSync() }
                },
                requireSession: true
            )
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(appState)
    }
}

/// Shown in the Friends tab when there is no account yet (for example after "Maybe later"
/// during setup). Friends needs an account, so say why and offer one clear action.
struct FriendsSignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAuth = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Color.reforgedGold.opacity(0.14)).frame(width: 96, height: 96)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                VStack(spacing: 10) {
                    Text("Read and memorize together.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Friends needs an account so you can connect with people you trust, memorize verses side by side, and cheer each other on. You choose what anyone can see.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ReturningPrimaryButton(title: "Sign in or create account") { showAuth = true }
                    .padding(.top, 6)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 120)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .sheet(isPresented: $showAuth) { FriendsAuthSheet(isPresented: $showAuth) }
    }
}

/// For people who are already signed in with Apple on this device. Friends talks to the
/// server with its own session, which Apple only hands out against a fresh confirmation,
/// so this asks for exactly that: one tap, no form. Failures show the server's reason.
struct FriendsConnectView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var supabase = SupabaseAuthService.shared

    @State private var rawNonce = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showOtherAccount = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(Color.reforgedGold.opacity(0.14)).frame(width: 96, height: 96)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                VStack(spacing: 10) {
                    Text("Read and memorize together.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("You're already signed in with Apple. Confirm once to turn on Friends for this account. You choose what anyone can see.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    let raw = AppleSignInService.randomNonceString()
                    rawNonce = raw
                    request.nonce = AppleSignInService.sha256(raw)
                } onCompletion: { handle($0) }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(Capsule())
                .disabled(isLoading)
                .overlay { if isLoading { ProgressView() } }
                .padding(.top, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.reforgedCoral)
                }

                Button("Use email instead") { showOtherAccount = true }
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 120)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .sheet(isPresented: $showOtherAccount) { FriendsAuthSheet(isPresented: $showOtherAccount) }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  !rawNonce.isEmpty else {
                errorMessage = "Couldn't read your Apple credential. Please try again."
                return
            }
            isLoading = true
            errorMessage = nil
            let nonce = rawNonce
            Task {
                defer { isLoading = false }
                let res = await supabase.signInWithApple(idToken: idToken, rawNonce: nonce)
                if res.success, let uid = res.userId {
                    // isSignedIn flips on the shared auth service, which swaps this screen out.
                    appState.signedInWithSupabase(userId: uid, email: credential.email ?? appState.user.email ?? "")
                    HapticManager.shared.success()
                } else {
                    debugLog("⚠️ Friends Apple→Supabase exchange failed: \(res.errorMessage ?? "unknown")")
                    errorMessage = "Couldn't connect your account: \(res.errorMessage ?? "unknown error")"
                }
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        }
    }
}
