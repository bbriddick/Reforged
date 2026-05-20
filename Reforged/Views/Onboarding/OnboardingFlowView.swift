import SwiftUI
import AuthenticationServices
import PhotosUI

enum OnboardingStep: Int, CaseIterable {
    case welcome               // 0  — unchanged splash
    case featureReader         // 1  — Bible reader + hold-to-define
    case featureMemory         // 2  — spaced repetition + games
    case featureDiscipleship   // 3  — tracks + XP / levels / streaks
    case walkTalks             // 4  — Southland / Walk Talks partnership
    case featureOriginalLang   // 5  — Greek / Hebrew bundled
    case auth                  // 6  — email tabs + Apple SIWA + skip
    case name                  // 7  — user's name
    case avatar                // 8  — emoji / photo
    case goals                 // 9  — selected goals
    case versionPicker         // 10 — preferred translation
    case displayPreferences    // 11 — theme, font, verse format, orig-lang toggles
    case aiFeatures            // 12 — AI opt-in/out
    case notifications         // 13 — permission request
    case final                 // 14 — completion

    /// Steps that can be skipped when the user signs in with Apple
    static let skippableWithAppleSignIn: Set<OnboardingStep> = [.name]
}

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var currentStep: OnboardingStep = .welcome
    /// True once the user has signed in with any provider — skips the name step
    @State private var signedInWithApple = false
    @State private var signedInWithSupabase = false

    private var anySignIn: Bool { signedInWithApple || signedInWithSupabase }

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
            case .featureReader:
                FeatureReaderStepView(onNext: { nextStep() })
            case .featureMemory:
                FeatureMemoryStepView(onNext: { nextStep() })
            case .featureDiscipleship:
                FeatureDiscipleshipStepView(onNext: { nextStep() })
            case .walkTalks:
                WalkTalksOnboardingStepView(onNext: { nextStep() })
            case .featureOriginalLang:
                FeatureOriginalLangStepView(onNext: { nextStep() })
            case .auth:
                AuthStepView(
                    onNext: { nextStep() },
                    onExistingUser: { completeOnboarding() },
                    onSignedInWithApple: { signedInWithApple = true },
                    onSignedInWithSupabase: { signedInWithSupabase = true }
                )
            case .name:
                NameStepView(onNext: { nextStep() })
            case .avatar:
                AvatarStepView(onNext: { nextStep() })
            case .goals:
                GoalsStepView(onNext: { nextStep() })
            case .versionPicker:
                VersionPickerStepView(onNext: { nextStep() })
            case .displayPreferences:
                DisplayPreferencesStepView(onNext: { nextStep() })
            case .aiFeatures:
                AIFeaturesStepView(onNext: { nextStep() })
            case .notifications:
                NotificationsStepView(onNext: { nextStep() })
            case .final:
                FinalStepView(onComplete: { tab in completeOnboarding(navigatingTo: tab) })
            }
        }
        .overlay(alignment: .topLeading) {
            if currentStep != .welcome && currentStep != .final {
                Button(action: { previousStep() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 32, height: 32)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Circle())
                }
                .padding(.top, 16)
                .padding(.leading, 20)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .buttonStyle(NoBlobButtonStyle())
    }

    func previousStep() {
        withAnimation {
            var prevRaw = currentStep.rawValue - 1
            while let candidate = OnboardingStep(rawValue: prevRaw),
                  anySignIn && OnboardingStep.skippableWithAppleSignIn.contains(candidate) {
                prevRaw -= 1
            }
            if let prevIndex = OnboardingStep(rawValue: prevRaw) {
                currentStep = prevIndex
            }
        }
    }

    func nextStep() {
        withAnimation {
            var nextRaw = currentStep.rawValue + 1
            // Skip steps that Apple already provided data for
            while let candidate = OnboardingStep(rawValue: nextRaw),
                  anySignIn && OnboardingStep.skippableWithAppleSignIn.contains(candidate) {
                nextRaw += 1
            }
            if let nextIndex = OnboardingStep(rawValue: nextRaw) {
                currentStep = nextIndex
            }
        }
    }

    /// Marks onboarding complete and optionally navigates to a specific tab.
    /// - Parameter tab: The tab index to land on (0=Home, 1=Learn, 2=Bible, 3=Memory). Defaults to Bible.
    func completeOnboarding(navigatingTo tab: Int = 2) {
        appState.user.onboardingCompleted = true
        // Seed the current version so What's New doesn't appear on a fresh install.
        AppVersionTracker.seedVersion()
        // Persist new user profile to Supabase if signed in via email/password.
        if SupabaseAuthService.shared.isSignedIn {
            Task { await SupabaseAuthService.shared.upsertProfile(appState.user) }
        }
        // The SwitchTab notification is handled by ContentView.
        // Post after a brief delay so AdaptiveNavigationView has time to appear.
        guard tab != 2 else { return }   // Bible is the default; no notification needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: .switchTab,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: tab]
            )
        }
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

// MARK: - Feature: Bible Reader + Hold-to-Define

struct FeatureReaderStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 16)

                    VStack(spacing: 8) {
                        Text("Read & Explore Scripture")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("A clean, distraction-free reader. Long-press any word to instantly pull up its Greek or Hebrew definition, transliteration, and Strong's number.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // ── Mock Bible reader ──────────────────────────────────
                    VStack(spacing: 0) {
                        // Fake nav bar
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            Spacer()
                            Text("John 1")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Text("ESV")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.adaptiveChipBackground(colorScheme))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .overlay(Divider(), alignment: .bottom)

                        // Verse text — AttributedString keeps paragraph flow intact
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 5) {
                                Text("1")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.reforgedGold)
                                    .baselineOffset(4)
                                    .frame(width: 14)
                                Text(OnboardingHighlightedText.john1v1)
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            HStack(alignment: .top, spacing: 5) {
                                Text("2")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.reforgedGold)
                                    .baselineOffset(4)
                                    .frame(width: 14)
                                Text("He was in the beginning with God.")
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            HStack(alignment: .top, spacing: 5) {
                                Text("3")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.reforgedGold)
                                    .baselineOffset(4)
                                    .frame(width: 14)
                                Text("All things were made through him, and without him was not any thing made that was made.")
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.adaptiveBackground(colorScheme))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // ── Mock Word Study popup ─────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        // Sheet drag handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.adaptiveBorder(colorScheme))
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)

                        HStack {
                            Text("Word Study")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Text("Done")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.reforgedGold)
                        }

                        // Header badges row
                        HStack(spacing: 8) {
                            Text("Greek")
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.reforgedGold.opacity(0.2))
                                .foregroundStyle(Color.reforgedGold)
                                .clipShape(Capsule())

                            Text("G3056")
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.adaptiveChipBackground(colorScheme))
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                .clipShape(Capsule())

                            Spacer()
                            Text("John 1:1")
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        // "word" → original word arrow
                        HStack(spacing: 10) {
                            Text("\"Word\"")
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Image(systemName: "arrow.right")
                                .font(.caption).foregroundStyle(Color.reforgedGold)
                            Text("λόγος")
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }

                        // Main entry card
                        VStack(alignment: .leading, spacing: 10) {
                            // Original / lexical form
                            VStack(alignment: .leading, spacing: 3) {
                                Text("As Used in Text")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.reforgedGold)
                                Text("λόγος")
                                    .font(.system(size: 28, design: .serif))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            // Transliteration
                            HStack(spacing: 6) {
                                Text("logos")
                                    .font(.subheadline).italic()
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("(log'-os)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }

                            Divider()

                            // Definition
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Definition")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Text("word, reason, the divine Word")
                                    .font(.headline).fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            // KJV Usage
                            VStack(alignment: .leading, spacing: 3) {
                                Text("KJV Translations")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Text("word (218x), saying (50x), speech (8x), reason (2x)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }

                            // Occurrence count
                            Label("330 occurrences", systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(14)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    }
                    .padding(16)
                    .background(Color.adaptiveBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, y: -4)
                    .padding(.horizontal, 12)

                    // Feature pills
                    HStack(spacing: 8) {
                        ForEach(["📖 Clean Reader", "🔍 Hold to Define", "✏️ Highlight & Note"], id: \.self) { pill in
                            Text(pill)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color.adaptiveChipBackground(colorScheme))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Feature: Scripture Memory

struct FeatureMemoryStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.reforgedCoral.opacity(0.12))
                                .frame(width: 100, height: 100)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.reforgedCoral)
                        }

                        Text("Hide God's Word in Your Heart")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("Science-backed spaced repetition schedules exactly when to review each verse. Two built-in games make practice feel like play.")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // Feature pills
                    VStack(spacing: 10) {
                        ForEach([
                            ("🃏", "Matching Game", "Match verses to their references in under a minute"),
                            ("✍️", "Complete the Verse", "Fill in the blanks as you memorize"),
                            ("📅", "Spaced Repetition", "Review exactly when your brain needs it most")
                        ], id: \.0) { emoji, title, desc in
                            HStack(spacing: 14) {
                                Text(emoji).font(.title2)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Stat row
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundStyle(Color.reforgedCoral)
                        Text("Verse-by-verse progress tracking")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Feature: Discipleship Tracks

struct FeatureDiscipleshipStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    // Computed so "Foundation" (navy) adapts to near-white in dark mode
    private var phases: [(String, Color)] {
        [
            ("Foundation", Color.adaptivePrimaryIcon(colorScheme)),
            ("Christ",     .reforgedGold),
            ("Theology",   .reforgedCoral),
            ("Living",     Color(red: 0.2, green: 0.7, blue: 0.4))
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 10) {
                        Text("Grow Through Structured Discipleship")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("Four-phase curriculum guides you from Scripture foundations to faithful living. Earn XP, level up, and build streaks as you grow.")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // 4-phase progress strip
                    HStack(spacing: 0) {
                        ForEach(Array(phases.enumerated()), id: \.0) { index, phase in
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(phase.1.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Circle()
                                        .fill(phase.1)
                                        .frame(width: 14, height: 14)
                                }
                                Text(phase.0)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(phase.1)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)

                            if index < phases.count - 1 {
                                Rectangle()
                                    .fill(Color.adaptiveBorder(colorScheme))
                                    .frame(height: 2)
                                    .frame(maxWidth: 24)
                                    .padding(.bottom, 24)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    .padding(.horizontal, 24)

                    // Gamification row
                    HStack(spacing: 12) {
                        ForEach([("🏆", "30 Levels"), ("🔥", "Streaks"), ("🥇", "Badges")], id: \.0) { emoji, label in
                            VStack(spacing: 4) {
                                Text(emoji).font(.title2)
                                Text(label)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Walk Talks Partnership

struct WalkTalksOnboardingStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var notifyNewEpisodes = false

    private let artworkURL = URL(string: "https://d3t3ozftmdmh3i.cloudfront.net/staging/podcast_uploaded_nologo/24104082/24104082-1692647468238-9795be178feee.jpg")

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Podcast artwork
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            ZStack {
                                Color.purple.opacity(0.15)
                                Image(systemName: "headphones")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.purple)
                            }
                        }
                    }
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)

                    // Header text
                    VStack(spacing: 10) {
                        Text("Walk Talks Podcast")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("Reforged partners with **Southland Christian Camp** in Ringgold, LA to bring you Walk Talks — short, Scripture-focused episodes from Southland staff designed to strengthen your walk with God every week.")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // Feature highlights
                    VStack(spacing: 12) {
                        featureRow(icon: "waveform", color: Color.purple,
                                   title: "Weekly Episodes",
                                   subtitle: "New content every week covering one Scriptural theme")
                        featureRow(icon: "person.3.fill", color: Color.reforgedGold,
                                   title: "Southland Staff",
                                   subtitle: "Delivered by the full-time team at Southland Christian Camp")
                        featureRow(icon: "book.closed.fill", color: Color(red: 0.2, green: 0.7, blue: 0.4),
                                   title: "Practical Application",
                                   subtitle: "Short episodes built for everyday believers of all ages")
                    }
                    .padding(.horizontal, 24)

                    // Notification opt-in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notify me about new episodes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("You can change this anytime in Settings.")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                        Toggle("", isOn: $notifyNewEpisodes)
                            .labelsHidden()
                            .tint(Color.purple)
                    }
                    .padding(16)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button {
                SettingsManager.shared.podcastNewEpisodeNotifications = notifyNewEpisodes
                onNext()
            } label: {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
    }
}

// MARK: - Feature: Greek & Hebrew Originals

private enum OriginalLangTab { case greek, hebrew }

struct FeatureOriginalLangStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedLang: OriginalLangTab = .greek

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 16)

                    VStack(spacing: 8) {
                        Text("Unlock the Original Languages")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("The complete Greek NT and Hebrew OT are bundled — no download needed. Long-press any word to see its entry from the original text.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // Language tab picker
                    HStack(spacing: 0) {
                        ForEach([(OriginalLangTab.greek, "🇬🇷", "Greek (TR)"),
                                 (OriginalLangTab.hebrew, "🔤", "Hebrew (WLC)")],
                                id: \.1) { tab, flag, label in
                            let isSelected = selectedLang == tab
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedLang = tab }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(flag)
                                    Text(label)
                                        .font(.subheadline)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                }
                                .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? Color.adaptiveBackground(colorScheme) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    .padding(.horizontal, 24)

                    // ── Tabbed reader + word study mock ───────────────────
                    if selectedLang == .greek {
                        OriginalLangGreekPreview(colorScheme: colorScheme)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else {
                        OriginalLangHebrewPreview(colorScheme: colorScheme)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    // Enable toggles inline — no need to go to Settings
                    VStack(spacing: 0) {
                        DisplayPrefToggleRow(
                            icon: "character.magnify",
                            iconColor: Color.adaptivePrimaryIcon(colorScheme),
                            title: "Original language in word study",
                            caption: "Shows the Greek or Hebrew entry when you long-press any word.",
                            isOn: $settings.showOriginalLanguageText,
                            colorScheme: colorScheme
                        )
                        Divider().padding(.leading, 52)
                        DisplayPrefToggleRow(
                            icon: "globe",
                            iconColor: Color.adaptivePrimaryIcon(colorScheme),
                            title: "Show TR / WLC in translation menu",
                            caption: "Adds the full Greek NT and Hebrew OT to the reader's translation switcher.",
                            isOn: $settings.showOriginalLanguagesInSwitcher,
                            colorScheme: colorScheme
                        )
                    }
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: Greek preview

private struct OriginalLangGreekPreview: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Mock reader – Textus Receptus (John 1:1)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("John 1  ·  TR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.adaptiveCardBackground(colorScheme))
                .overlay(Divider(), alignment: .bottom)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 5) {
                        Text("1")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                            .baselineOffset(4).frame(width: 14)
                        Text(OnboardingHighlightedText.john1v1Greek)
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    HStack(alignment: .top, spacing: 5) {
                        Text("2")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.reforgedGold)
                            .baselineOffset(4).frame(width: 14)
                        Text("Οὗτος ἦν ἐν ἀρχῇ πρὸς τὸν θεόν.")
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))

            // Word study card (matches StrongsDefinitionSheet style)
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveBorder(colorScheme))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)

                HStack {
                    Text("Word Study").font(.headline).foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text("Done").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.reforgedGold)
                }

                HStack(spacing: 8) {
                    Text("Greek").font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(0.2)).foregroundStyle(Color.reforgedGold).clipShape(Capsule())
                    Text("G3056").font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.adaptiveChipBackground(colorScheme)).foregroundStyle(Color.adaptiveNavyText(colorScheme)).clipShape(Capsule())
                    Spacer()
                    Text("John 1:1").font(.subheadline).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                HStack(spacing: 8) {
                    Text("\"Word\"").font(.title3).fontWeight(.semibold).foregroundStyle(Color.adaptiveText(colorScheme))
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.reforgedGold)
                    Text("λόγος").font(.system(size: 24, weight: .bold, design: .serif)).foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("As Used in Text").font(.caption).fontWeight(.semibold).foregroundStyle(Color.reforgedGold)
                        Text("λόγος").font(.system(size: 26, design: .serif)).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    HStack(spacing: 6) {
                        Text("logos").font(.subheadline).italic().foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("(log'-os)").font(.subheadline).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Definition").font(.caption).fontWeight(.semibold).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text("word, reason, the divine Word")
                            .font(.headline).fontWeight(.semibold).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("KJV Translations").font(.caption).fontWeight(.semibold).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text("word (218x), saying (50x), speech (8x)")
                            .font(.subheadline).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    Label("330 occurrences", systemImage: "number")
                        .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(14)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            }
            .padding(16)
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 16, y: -3)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: Hebrew preview

private struct OriginalLangHebrewPreview: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Mock reader – WLC (Genesis 1:1)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Genesis 1  ·  WLC")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.adaptiveCardBackground(colorScheme))
                .overlay(Divider(), alignment: .bottom)

                HStack(alignment: .top, spacing: 5) {
                    Text("1")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                        .baselineOffset(4).frame(width: 14)
                    Text(OnboardingHighlightedText.gen1v1Hebrew)
                        .font(.custom("Ezra SIL", size: 18))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))

            // Word study card
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveBorder(colorScheme))
                    .frame(width: 36, height: 4).frame(maxWidth: .infinity)

                HStack {
                    Text("Word Study").font(.headline).foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text("Done").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.reforgedGold)
                }

                HStack(spacing: 8) {
                    Text("Hebrew").font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(0.2)).foregroundStyle(Color.reforgedGold).clipShape(Capsule())
                    Text("H430").font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.adaptiveChipBackground(colorScheme)).foregroundStyle(Color.adaptiveNavyText(colorScheme)).clipShape(Capsule())
                    Spacer()
                    Text("Gen 1:1").font(.subheadline).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                HStack(spacing: 8) {
                    Text("\"God\"").font(.title3).fontWeight(.semibold).foregroundStyle(Color.adaptiveText(colorScheme))
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.reforgedGold)
                    Text("אֱלֹהִים")
                        .font(.custom("Ezra SIL", size: 26))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 10) {
                    // Westminster text card (matches originalLanguageCard style)
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack {
                            Text("Westminster Leningrad Codex")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            Spacer()
                            Text("עברית")
                                .font(.caption2)
                                .foregroundStyle(Color.reforgedGold.opacity(0.85))
                        }
                        Text("בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם")
                            .font(.custom("Ezra SIL", size: 18))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(12)
                    .background(Color.reforgedGold.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1))

                    Divider()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Definition").font(.caption).fontWeight(.semibold).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text("God, gods, judges, the (true) God")
                            .font(.headline).fontWeight(.semibold).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("KJV Translations").font(.caption).fontWeight(.semibold).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Text("God (2346x), god (244x), judge (5x)")
                            .font(.subheadline).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    Label("2,602 occurrences", systemImage: "number")
                        .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(14)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            }
            .padding(16)
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 16, y: -3)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Auth Step

private enum AuthTab { case signIn, createAccount }

struct AuthStepView: View {
    let onNext: () -> Void
    var onExistingUser: (() -> Void)?
    var onSignedInWithApple: (() -> Void)?
    var onSignedInWithSupabase: (() -> Void)?

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedTab: AuthTab = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEmailConfirmation = false

    private let appleSignIn = AppleSignInService.shared
    private let cloudKit = CloudKitSyncService.shared
    private let supabase = SupabaseAuthService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Header
                Text(selectedTab == .signIn ? "Welcome Back" : "Create Account")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .animation(.none, value: selectedTab)

                // Segmented tab
                Picker("Auth", selection: $selectedTab) {
                    Text("Sign In").tag(AuthTab.signIn)
                    Text("Create Account").tag(AuthTab.createAccount)
                }
                .pickerStyle(.segmented)
                .tint(Color.reforgedNavy)
                .padding(.horizontal, 24)
                .onChange(of: selectedTab) { _ in
                    errorMessage = nil
                    showEmailConfirmation = false
                }

                // Email confirmation message
                if showEmailConfirmation {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.reforgedGold)
                        Text("Check your inbox at **\(email)**.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)
                        Text("Tap the confirmation link, then come back here and sign in.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                        Button("Sign In Instead") {
                            withAnimation { selectedTab = .signIn; showEmailConfirmation = false }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    }
                    .padding(16)
                    .background(Color.reforgedGold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 24)
                } else {
                    // Email/password form
                    VStack(spacing: 14) {
                        if selectedTab == .createAccount {
                            TextField("Display Name", text: $displayName)
                                .authTextField(colorScheme: colorScheme)
                                .textContentType(.name)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        TextField("Email", text: $email)
                            .authTextField(colorScheme: colorScheme)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        SecureField("Password", text: $password)
                            .authTextField(colorScheme: colorScheme)
                            .textContentType(selectedTab == .signIn ? .password : .newPassword)

                        if selectedTab == .createAccount {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .authTextField(colorScheme: colorScheme)
                                .textContentType(.newPassword)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    .padding(.horizontal, 24)

                    // Error message
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(Color.reforgedCoral)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Primary CTA
                    ZStack {
                        Button(action: handleEmailAuth) {
                            Text(selectedTab == .signIn ? "Sign In" : "Create Account")
                                .reforgedPrimaryButton()
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1)
                        .padding(.horizontal, 24)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }

                // — or —
                HStack(spacing: 12) {
                    Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(height: 1)
                }
                .padding(.horizontal, 24)

                // Sign In with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignInResult(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                .padding(.horizontal, 24)
                .disabled(isLoading)

                // Skip
                Button(action: onNext) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .disabled(isLoading)

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Email Auth

    private func handleEmailAuth() {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else { return }

        if selectedTab == .createAccount {
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match."
                return
            }
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters."
                return
            }
        }

        isLoading = true
        Task {
            defer { isLoading = false }
            if selectedTab == .signIn {
                let result = await supabase.signIn(email: email, password: password)
                if result.success, let uid = result.userId {
                    appState.signedInWithSupabase(userId: uid, email: email)
                    onSignedInWithSupabase?()
                    onNext()
                } else if let msg = result.errorMessage {
                    errorMessage = msg
                }
            } else {
                let name = displayName.isEmpty ? String(email.split(separator: "@").first ?? "") : displayName
                let result = await supabase.signUp(email: email, password: password, displayName: name)
                if result.success, let uid = result.userId {
                    appState.signedInWithSupabase(userId: uid, email: email)
                    if !name.isEmpty { appState.user.displayName = name }
                    onSignedInWithSupabase?()
                    onNext()
                } else if result.emailConfirmationRequired {
                    withAnimation { showEmailConfirmation = true }
                } else if let msg = result.errorMessage {
                    errorMessage = msg
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential received."
                return
            }
            isLoading = true
            errorMessage = nil

            let userId    = credential.user
            let fullName  = credential.fullName
            let email     = credential.email

            Task {
                appleSignIn.userIdentifier = userId
                appleSignIn.isSignedIn     = true
                if let givenName = fullName?.givenName { appleSignIn.userName  = givenName }
                if let em = email                      { appleSignIn.userEmail = em }

                saveAppleCredentialToKeychain(userId: userId, name: fullName?.givenName, email: email)

                if let authCodeData = credential.authorizationCode,
                   let authCode = String(data: authCodeData, encoding: .utf8) {
                    await appleSignIn.exchangeAuthCodeForTokens(authCode: authCode)
                }

                let resolvedName  = fullName?.givenName ?? appleSignIn.userName
                let resolvedEmail = email ?? appleSignIn.userEmail
                await handleSuccessfulAppleAuth(name: resolvedName, email: resolvedEmail)
                isLoading = false
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        }
    }

    private func saveAppleCredentialToKeychain(userId: String, name: String?, email: String?) {
        let service = "com.reforged.app"
        func save(key: String, value: String) {
            let data = Data(value.utf8)
            let del: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                      kSecAttrAccount as String: key,
                                      kSecAttrService as String: service]
            SecItemDelete(del as CFDictionary)
            let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                      kSecAttrAccount as String: key,
                                      kSecAttrService as String: service,
                                      kSecValueData as String: data,
                                      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
            SecItemAdd(add as CFDictionary, nil)
        }
        save(key: "reforged.apple.userIdentifier", value: userId)
        if let n = name  { save(key: "reforged.apple.userName",  value: n) }
        if let e = email { save(key: "reforged.apple.userEmail", value: e) }
    }

    private func handleSuccessfulAppleAuth(name: String?, email: String?) async {
        do {
            let cloudProfile = try await cloudKit.fetchProfile()
            if let profile = cloudProfile, !profile.firstName.isEmpty {
                await appState.performFullSync()
                appState.user.loggedIn = true
                appState.user.onboardingCompleted = true
                onExistingUser?()
            } else {
                if let n = name, !n.isEmpty { appState.user.firstName = n; appState.user.displayName = n }
                if let e = email            { appState.user.email = e }
                appState.user.loggedIn = true
                onSignedInWithApple?()
                onNext()
            }
        } catch {
            if let n = name, !n.isEmpty { appState.user.firstName = n; appState.user.displayName = n }
            appState.user.loggedIn = true
            onSignedInWithApple?()
            onNext()
        }
    }
}

// Convenience modifier so all auth text fields share identical styling
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

// MARK: - Display Preferences Step

struct DisplayPreferencesStepView: View {
    let onNext: () -> Void
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 8) {
                        Text("Make It Yours")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Customize how Reforged looks and reads. You can always adjust these in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    // Section: Appearance (theme)
                    DisplayPrefSection(title: "Appearance") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                let isSelected = settings.themeMode == mode
                                Button {
                                    settings.themeMode = mode
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(isSelected ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                                        Text(mode.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(isSelected ? .semibold : .regular)
                                            .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveText(colorScheme))
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                                                .font(.subheadline)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.reforgedNavy.opacity(0.08)) : Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveBorder(colorScheme),
                                                    lineWidth: isSelected ? 2 : 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Section: Verse Layout
                    DisplayPrefSection(title: "Verse Layout") {
                        HStack(spacing: 10) {
                            ForEach(VerseFormattingMode.allCases, id: \.self) { mode in
                                let isSelected = settings.verseFormatting == mode
                                Button {
                                    settings.verseFormatting = mode
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(mode.rawValue)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveText(colorScheme))

                                        if mode == .verseByVerse {
                                            VStack(alignment: .leading, spacing: 3) {
                                                ForEach(["¹ In the beginning…", "² And the earth was…"], id: \.self) { line in
                                                    Text(line).font(.system(size: 9)).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                                }
                                            }
                                        } else {
                                            Text("¹ In the beginning God created the heavens and the earth. ² Now the earth…")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                                .lineLimit(3)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.reforgedNavy.opacity(0.06)) : Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveBorder(colorScheme),
                                                    lineWidth: isSelected ? 2 : 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Section: Font Style
                    DisplayPrefSection(title: "Font Style") {
                        HStack(spacing: 10) {
                            ForEach(FontTypeSetting.allCases, id: \.self) { fontType in
                                let isSelected = settings.fontType == fontType
                                Button {
                                    settings.fontType = fontType
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    VStack(spacing: 6) {
                                        Text("In the beginning")
                                            .font(fontType.makeFont(size: 11))
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                        Text(fontType.rawValue)
                                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                            .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.reforgedNavy.opacity(0.06)) : Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveBorder(colorScheme),
                                                    lineWidth: isSelected ? 2 : 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Section: Greek & Hebrew
                    DisplayPrefSection(title: "Greek & Hebrew") {
                        VStack(spacing: 0) {
                            DisplayPrefToggleRow(
                                icon: "character.magnify",
                                iconColor: Color.adaptivePrimaryIcon(colorScheme),
                                title: "Original language in word study",
                                caption: "Shows Greek / Hebrew definitions when you long-press a word.",
                                isOn: $settings.showOriginalLanguageText,
                                colorScheme: colorScheme
                            )
                            Divider().padding(.leading, 52)
                            DisplayPrefToggleRow(
                                icon: "globe",
                                iconColor: Color.adaptivePrimaryIcon(colorScheme),
                                title: "Show TR / WLC in translation menu",
                                caption: "Makes the full Greek NT and Hebrew OT available in the reader.",
                                isOn: $settings.showOriginalLanguagesInSwitcher,
                                colorScheme: colorScheme
                            )
                        }
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    }
                    .padding(.horizontal, 24)

                    // Section: Words of Christ
                    DisplayPrefSection(title: "Words of Christ") {
                        DisplayPrefToggleRow(
                            icon: "text.word.spacing",
                            iconColor: .reforgedCoral,
                            title: "Red letter text",
                            caption: "Displays Jesus' words in red in supported translations.",
                            isOn: $settings.showRedLetterText,
                            colorScheme: colorScheme
                        )
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

private struct DisplayPrefSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.8)
            content()
        }
    }
}

private struct DisplayPrefToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let caption: String
    @Binding var isOn: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.reforgedNavy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
                                    ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.reforgedNavy.opacity(0.10))
                                    : Color.adaptiveCardBackground(colorScheme))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedAvatar == avatar.emoji && !hasPhoto
                                                ? Color.adaptivePrimaryIcon(colorScheme)
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
            .background(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.reforgedNavy.opacity(0.08)) : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(isSelected ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveBorder(colorScheme), lineWidth: isSelected ? 2 : 1.5)
            )
        }
    }
}

// MARK: - AI Features Step

struct AIFeaturesStepView: View {
    let onNext: () -> Void
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.12))
                        .frame(width: 120, height: 120)

                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.reforgedGold)
                }

                VStack(spacing: 12) {
                    Text("AI Study Tools")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Reforged includes optional AI-powered features to enhance your study time. You can always change this later in Settings.")
                        .font(.body)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }

                // Feature cards
                VStack(spacing: 12) {
                    AIFeatureRow(
                        icon: "pencil.and.outline",
                        color: Color.reforgedGold,
                        title: "Journal Prompts",
                        description: "AI-generated reflection questions based on your reading"
                    )
                    AIFeatureRow(
                        icon: "book.and.wrench",
                        color: Color.adaptivePrimaryIcon(colorScheme),
                        title: "Word Study Summaries",
                        description: "Instant explanations of original Greek and Hebrew words"
                    )
                    AIFeatureRow(
                        icon: "magnifyingglass.circle",
                        color: Color.reforgedCoral,
                        title: "Smart Search",
                        description: "Find related passages by concept, not just exact words"
                    )
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Toggle + buttons
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable AI Features")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("Uses Gemini AI — no data is stored")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.aiEnabled)
                        .labelsHidden()
                        .tint(Color.reforgedGold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Button(action: onNext) {
                    Text("Continue")
                        .reforgedPrimaryButton()
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

private struct AIFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
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

// MARK: - Version Picker Step

struct VersionPickerStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settingsManager = SettingsManager.shared

    /// Standard translations shown during onboarding (exclude original-language editions)
    private let translations = BibleTranslation.allCases.filter { !$0.isOriginalLanguage }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 16)

                    // Header
                    VStack(spacing: 10) {
                        Text("Choose Your Bible")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Pick the translation you're most\ncomfortable reading")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 24)

                    // Translation cards
                    VStack(spacing: 12) {
                        ForEach(translations) { translation in
                            let isSelected = settingsManager.defaultTranslation == translation
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settingsManager.defaultTranslation = translation
                                }
                                HapticManager.shared.lightImpact()
                            } label: {
                                HStack(spacing: 16) {
                                    // Abbreviation badge
                                    Text(translation.rawValue)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isSelected ? .white : Color.adaptiveNavyText(colorScheme))
                                        .frame(width: 64)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(translation.fullName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                        Text(translation.copyright)
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                        .fill(isSelected
                                              ? Color.reforgedGold.opacity(0.07)
                                              : Color.adaptiveCardBackground(colorScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                        .stroke(isSelected ? Color.reforgedGold : Color.adaptiveBorder(colorScheme),
                                                lineWidth: isSelected ? 2 : 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Text("You can change this anytime in Settings")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }

            // Continue button pinned at bottom
            Button(action: onNext) {
                Text("Continue")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Final Step

struct FinalStepView: View {
    /// Called with the tab index the user wants to land on (1 = Learn, 2 = Bible).
    let onComplete: (Int) -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.reforgedNavy.opacity(0.10))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                }

                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Welcome, \(appState.user.firstName)!")
                    .font(.title2)
                    .foregroundStyle(Color.reforgedGold)

                Text("Where would you like to begin?")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: 14) {
                // Primary CTA — open the Bible reader
                Button {
                    HapticManager.shared.success()
                    onComplete(2)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.book.closed.fill")
                        Text("Open the Bible")
                    }
                    .reforgedPrimaryButton()
                }

                // Secondary CTA — jump straight to a lesson
                Button {
                    HapticManager.shared.lightImpact()
                    onComplete(1)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "book.fill")
                        Text("Start a Lesson")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(colorScheme == .dark ? Color.white.opacity(0.10) : Color.reforgedNavy.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.20) : Color.reforgedNavy.opacity(0.25), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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

// MARK: - Onboarding Highlighted Text (AttributedString helpers)

/// Pre-built AttributedStrings used in the onboarding feature slides.
/// Gold highlight simulates a long-pressed / selected word in the reader.
enum OnboardingHighlightedText {
    private static let goldHighlight = Color(red: 0.85, green: 0.65, blue: 0.10).opacity(0.35)

    /// John 1:1 (ESV) with "Word" highlighted in gold
    static var john1v1: AttributedString {
        highlighted(
            "In the beginning was the Word, and the Word was with God, and the Word was God.",
            word: "Word"
        )
    }

    /// John 1:1 (TR) with "λόγος" highlighted in gold
    static var john1v1Greek: AttributedString {
        highlighted(
            "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν, καὶ θεὸς ἦν ὁ λόγος.",
            word: "λόγος"
        )
    }

    /// Genesis 1:1 (WLC) with "אֱלֹהִים" highlighted in gold
    static var gen1v1Hebrew: AttributedString {
        highlighted(
            "בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ׃",
            word: "אֱלֹהִים"
        )
    }

    private static func highlighted(_ text: String, word: String) -> AttributedString {
        var str = AttributedString(text)
        if let range = str.range(of: word) {
            str[range].backgroundColor = goldHighlight
            str[range].font = .system(.body, design: .serif).weight(.semibold)
        }
        return str
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AppState.shared)
}
