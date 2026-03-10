import SwiftUI
import AuthenticationServices
import PhotosUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case featuresReading      // Bible reading feature
    case featuresMemory       // Verse memorization
    case featuresJournal      // Journaling/reflection
    case auth
    case name
    case avatar
    case goals
    case notifications        // Ask about notifications (permission requested only on confirm)
    case final

    /// Steps that can be skipped when the user signs in with Apple
    static let skippableWithAppleSignIn: Set<OnboardingStep> = [.name]
}

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var currentStep: OnboardingStep = .welcome
    /// Set to true when the user signs in with Apple (skips name step)
    @State private var signedInWithApple = false

    var body: some View {
        ZStack {
            // Background based on step
            if currentStep == .welcome {
                Color.reforgedCharcoal.ignoresSafeArea()
            } else {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()
            }

            switch currentStep {
            case .welcome:
                WelcomeStepView(onNext: { nextStep() })
            case .featuresReading:
                FeaturesReadingView(onNext: { nextStep() })
            case .featuresMemory:
                FeaturesMemoryView(onNext: { nextStep() })
            case .featuresJournal:
                FeaturesJournalView(onNext: { nextStep() })
            case .auth:
                AuthStepView(
                    onNext: { nextStep() },
                    onExistingUser: { completeOnboarding() },
                    onSignedInWithApple: { signedInWithApple = true }
                )
            case .name:
                NameStepView(onNext: { nextStep() })
            case .avatar:
                AvatarStepView(onNext: { nextStep() })
            case .goals:
                GoalsStepView(onNext: { nextStep() })
            case .notifications:
                NotificationsStepView(onNext: { nextStep() })
            case .final:
                FinalStepView(onComplete: { completeOnboarding() })
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    func nextStep() {
        withAnimation {
            var nextRaw = currentStep.rawValue + 1
            // Skip steps that Apple already provided data for
            while let candidate = OnboardingStep(rawValue: nextRaw),
                  signedInWithApple && OnboardingStep.skippableWithAppleSignIn.contains(candidate) {
                nextRaw += 1
            }
            if let nextIndex = OnboardingStep(rawValue: nextRaw) {
                currentStep = nextIndex
            }
        }
    }

    func completeOnboarding() {
        appState.user.onboardingCompleted = true
    }
}

// MARK: - Welcome Step (Splash Screen Style)

struct WelcomeStepView: View {
    let onNext: () -> Void
    @State private var animate = false

    // Brand colors from the logo
    private let creamColor = Color.reforgedBrandCream
    private let subtitleColor = Color(red: 0.85, green: 0.83, blue: 0.80)
    private let mutedColor = Color(red: 0.65, green: 0.63, blue: 0.60)
    private let buttonBackgroundColor = Color.reforgedBrandCream
    private let buttonTextColor = Color.reforgedCharcoal

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main Content - Centered App Icon
            VStack(spacing: 32) {
                // App Icon from asset catalog
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)

                // Wordmark
                Text("Reforged")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(creamColor)

                // Quote
                VStack(spacing: 16) {
                    Text("\"Your word is a lamp to my feet\nand a light to my path.\"")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)

                    Text("— Psalm 119:105")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                .padding(.top, 8)
            }
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)

            Spacer()

            // Bottom Section
            VStack(spacing: 24) {
                Text("Transform your faith through\nScripture study and memorization")
                    .font(.subheadline)
                    .foregroundStyle(mutedColor)
                    .multilineTextAlignment(.center)

                Button(action: onNext) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(buttonBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 60)
            .opacity(animate ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }
        }
    }
}

// MARK: - Features Reading Step

struct FeaturesReadingView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedNavy.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "book.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }

            VStack(spacing: 16) {
                Text("Read Scripture")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Read the Bible with a clean,\ndistraction-free interface.\nHighlight verses, take notes,\nand track your reading streak.")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Features Memory Step

struct FeaturesMemoryView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedCoral.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.reforgedCoral)
            }

            VStack(spacing: 16) {
                Text("Memorize Verses")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Hide God's Word in your heart\nusing scientifically-proven\nspaced repetition techniques")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Features Journal Step

struct FeaturesJournalView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedGold.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.reforgedGold)
            }

            VStack(spacing: 16) {
                Text("Journal & Reflect")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Capture your thoughts and\nspiritual insights in a private journal.\nYour reflections stay securely\non your device.")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Auth Step

struct AuthStepView: View {
    let onNext: () -> Void
    var onExistingUser: (() -> Void)?
    /// Called when the user successfully signs in with Apple
    var onSignedInWithApple: (() -> Void)?

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let appleSignIn = AppleSignInService.shared
    private let cloudKit = CloudKitSyncService.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Sign In")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Sign in with your Apple ID to sync your progress across all your devices")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // Sign In with Apple Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .padding(.horizontal, 24)

            if isLoading {
                ProgressView("Signing in...")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.reforgedCoral)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Skip Button
            Button(action: onNext) {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign In with Apple

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential received"
                return
            }

            isLoading = true
            errorMessage = nil

            let userId = credential.user
            let fullName = credential.fullName
            let email = credential.email

            // Store in AppleSignInService
            Task {
                // Save credentials to Keychain
                appleSignIn.userIdentifier = userId
                appleSignIn.isSignedIn = true

                if let givenName = fullName?.givenName {
                    appleSignIn.userName = givenName
                }
                if let email = email {
                    appleSignIn.userEmail = email
                }

                // Save to Keychain manually since we already have the credential
                saveAppleCredentialToKeychain(userId: userId, name: fullName?.givenName, email: email)

                // Exchange authorization code for refresh token (needed for account deletion)
                if let authCodeData = credential.authorizationCode,
                   let authCode = String(data: authCodeData, encoding: .utf8) {
                    Task {
                        await appleSignIn.exchangeAuthCodeForTokens(authCode: authCode)
                    }
                }

                // Resolve name/email: prefer Apple credential, fall back to Keychain
                let resolvedName = fullName?.givenName ?? appleSignIn.userName
                let resolvedEmail = email ?? appleSignIn.userEmail

                // Check if existing user in CloudKit
                await handleSuccessfulAuth(name: resolvedName, email: resolvedEmail)

                isLoading = false
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled — do nothing
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func saveAppleCredentialToKeychain(userId: String, name: String?, email: String?) {
        let service = "com.reforged.app"

        // Helper to save a value
        func save(key: String, value: String) {
            let data = Data(value.utf8)
            let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecAttrService as String: service]
            SecItemDelete(deleteQuery as CFDictionary)
            let addQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecAttrService as String: service, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
            SecItemAdd(addQuery as CFDictionary, nil)
        }

        save(key: "reforged.apple.userIdentifier", value: userId)
        if let name = name { save(key: "reforged.apple.userName", value: name) }
        if let email = email { save(key: "reforged.apple.userEmail", value: email) }
    }

    private func handleSuccessfulAuth(name: String?, email: String?) async {
        do {
            // Check CloudKit for existing profile
            let cloudProfile = try await cloudKit.fetchProfile()

            if let profile = cloudProfile, !profile.firstName.isEmpty {
                // Existing user — restore from cloud
                await appState.performFullSync()
                appState.user.loggedIn = true
                appState.user.onboardingCompleted = true

                if let onExistingUser = onExistingUser {
                    onExistingUser()
                }
            } else {
                // New user — use name/email from Apple (no need to ask again)
                if let name = name, !name.isEmpty {
                    appState.user.firstName = name
                    appState.user.displayName = name
                }
                if let email = email {
                    appState.user.email = email
                }
                appState.user.loggedIn = true
                onSignedInWithApple?()
                onNext()
            }
        } catch {
            print("Error checking existing profile: \(error)")
            // Still continue — user is signed in, just no cloud data yet
            if let name = name, !name.isEmpty {
                appState.user.firstName = name
                appState.user.displayName = name
            }
            appState.user.loggedIn = true
            onSignedInWithApple?()
            onNext()
        }
    }
}

// MARK: - Name Step

struct NameStepView: View {
    let onNext: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var firstName = ""
    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Text("What's your name?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("We'd love to get to know you")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            VStack(spacing: 16) {
                TextField("First Name", text: $firstName)
                    .padding()
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1.5)
                    )
                    .textContentType(.givenName)

                TextField("Display Name (optional)", text: $displayName)
                    .padding()
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1.5)
                    )
            }
            .padding(.horizontal)

            Spacer()

            Button(action: {
                appState.user.firstName = firstName
                appState.user.displayName = displayName.isEmpty ? firstName : displayName
                onNext()
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(firstName.isEmpty ? Color(.systemGray4) : Color.reforgedNavy)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            }
            .padding(.horizontal, 24)
            .disabled(firstName.isEmpty)
        }
        .padding()
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Pre-fill from Apple Sign In data if available
            if firstName.isEmpty, !appState.user.firstName.isEmpty {
                firstName = appState.user.firstName
            }
        }
    }
}

// MARK: - Avatar Step

struct AvatarStepView: View {
    let onNext: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedAvatar = "🦁"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCamera = false

    private var hasPhoto: Bool { selectedImage != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Picture")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Add a photo or pick an emoji")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    // Preview circle with camera badge
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Text(selectedAvatar)
                                    .font(.system(size: 64))
                            }
                        }
                        .frame(width: 120, height: 120)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.reforgedGold, lineWidth: 4))
                        .shadow(color: ReforgedTheme.cardShadow, radius: 8, y: 4)

                        // Camera badge
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color.reforgedNavy)
                        }
                        .offset(x: 4, y: 4)
                    }
                    .onTapGesture { showPhotoPicker = true }

                    // Photo upload buttons
                    HStack(spacing: 12) {
                        Button { showPhotoPicker = true } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.reforgedNavy)
                                .clipShape(Capsule())
                        }

                        Button { showCamera = true } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.reforgedNavy)
                                .clipShape(Capsule())
                        }
                    }

                    // Remove photo button (only when photo selected)
                    if hasPhoto {
                        Button {
                            selectedImage = nil
                            selectedPhotoItem = nil
                        } label: {
                            Label("Remove Photo", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(Color.reforgedCoral)
                        }
                    }

                    // "or choose an emoji" divider
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.adaptiveBorder(colorScheme))
                            .frame(height: 1)
                        Text("or choose an emoji")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .fixedSize()
                        Rectangle()
                            .fill(Color.adaptiveBorder(colorScheme))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)
                    .opacity(hasPhoto ? 0.4 : 1.0)

                    // Emoji grid (dimmed when photo selected; tap clears photo)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(avatarOptions) { avatar in
                            Text(avatar.emoji)
                                .font(.largeTitle)
                                .frame(width: 60, height: 60)
                                .background(selectedAvatar == avatar.emoji && !hasPhoto
                                    ? Color.reforgedNavy.opacity(0.1)
                                    : Color.adaptiveCardBackground(colorScheme))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedAvatar == avatar.emoji && !hasPhoto
                                                ? Color.reforgedNavy
                                                : Color.adaptiveBorder(colorScheme),
                                            lineWidth: selectedAvatar == avatar.emoji && !hasPhoto ? 3 : 1.5
                                        )
                                )
                                .onTapGesture {
                                    selectedAvatar = avatar.emoji
                                    // Tapping an emoji clears any selected photo
                                    selectedImage = nil
                                    selectedPhotoItem = nil
                                }
                        }
                    }
                    .padding(.horizontal)
                    .opacity(hasPhoto ? 0.4 : 1.0)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }

            // Continue button pinned at bottom
            Button(action: {
                appState.user.avatar = selectedAvatar
                if let image = selectedImage,
                   let filename = ProfileImageService.shared.saveImage(image) {
                    appState.user.profileImagePath = filename
                }
                onNext()
            }) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .padding(.horizontal)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { selectedImage = image }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(image: $selectedImage)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Goals Step

struct GoalsStepView: View {
    let onNext: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedGoals: Set<String> = []

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("What are your goals?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Select all that apply")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.top, 40)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(goalOptions) { goal in
                        GoalRow(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal.id),
                            colorScheme: colorScheme
                        ) {
                            if selectedGoals.contains(goal.id) {
                                selectedGoals.remove(goal.id)
                            } else {
                                selectedGoals.insert(goal.id)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button(action: {
                appState.user.goals = Array(selectedGoals)
                onNext()
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedGoals.isEmpty ? Color(.systemGray4) : Color.reforgedNavy)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            }
            .padding(.horizontal, 24)
            .disabled(selectedGoals.isEmpty)
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

struct GoalRow: View {
    let goal: GoalOption
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(goal.icon)
                    .font(.title2)

                Text(goal.label)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
            }
            .padding()
            .background(isSelected ? Color.reforgedNavy.opacity(0.08) : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(isSelected ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme), lineWidth: isSelected ? 2 : 1.5)
            )
        }
    }
}

// MARK: - Notifications Step

struct NotificationsStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isRequestingPermission = false
    @State private var permissionGranted = false
    @State private var reminderTime = SettingsManager.shared.dailyReminderTime

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedCoral.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.reforgedCoral)
            }

            VStack(spacing: 16) {
                Text("Stay Encouraged")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Get daily reminders to read Scripture,\ncelebrate your streaks, and receive\nencouraging devotional insights.")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if permissionGranted {
                // Time picker after permission granted
                VStack(spacing: 12) {
                    Text("When should we remind you?")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 150)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            VStack(spacing: 16) {
                if permissionGranted {
                    // Continue button after setting time
                    Button(action: {
                        SettingsManager.shared.dailyReminderTime = reminderTime
                        NotificationManager.shared.scheduleDailyReminder()
                        onNext()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Continue")
                        }
                        .reforgedPrimaryButton()
                    }
                } else {
                    // Enable Notifications Button
                    Button(action: {
                        isRequestingPermission = true
                        NotificationManager.shared.requestAuthorization()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isRequestingPermission = false
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                permissionGranted = true
                            }
                        }
                    }) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "bell.fill")
                                Text("Enable Notifications")
                            }
                        }
                        .reforgedPrimaryButton()
                    }
                    .disabled(isRequestingPermission)

                    // Skip Button
                    Button(action: onNext) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .disabled(isRequestingPermission)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Final Step

struct FinalStepView: View {
    let onComplete: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedNavy.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }

                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Welcome, \(appState.user.firstName)!")
                    .font(.title2)
                    .foregroundStyle(Color.reforgedGold)

                Text("Start reading Scripture, memorizing\nverses, and growing in your faith")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button(action: {
                HapticManager.shared.success()
                onComplete()
            }) {
                Text("Start Reading")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .confetti(isActive: $showConfetti, intensity: .medium)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AppState.shared)
}
