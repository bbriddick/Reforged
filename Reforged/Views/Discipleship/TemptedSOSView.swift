import SwiftUI

// MARK: - Tempted SOS Flow
//
// Full-screen panic button flow for the moment of temptation, staged so the
// user slows down before deciding anything: breathe (~30 s) → a verse → a
// short prayer → optionally text their accountability partner. Uses count as a
// positive stat (see AccountabilityPartnerService.recordSOSUse).

struct TemptedSOSView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private enum Stage {
        case breathe, verse, prayer, reach
    }

    @State private var stage: Stage = .breathe
    @State private var breathScale: CGFloat = 0.6
    @State private var breathingIn = true
    @State private var secondsLeft = 30
    @State private var verse: ShieldEncouragement = ShieldContentProvider.fallbackEncouragements.first
        ?? ShieldEncouragement(
            suggestion: "Turn your eyes to the Lord",
            verseText: "I have stored up your word in my heart, that I might not sin against you.",
            verseReference: "Psalm 119:11"
        )
    @State private var showMessageComposer = false
    @State private var showJournal = false

    private let breathTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let breathPeriod = 5.0

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                switch stage {
                case .breathe: breatheStage
                case .verse:   verseStage
                case .prayer:  PrayerPromptSheet { advance(to: .reach) }
                case .reach:   reachStage
                }
            }
        }
        .onAppear {
            AccountabilityPartnerService.shared.recordSOSUse()
            verse = randomVerse()
        }
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(
                recipients: [AccountabilityPartnerService.shared.partnerPhone],
                body: "Hey — I'm being tempted right now and could use prayer. Can you check in with me?"
            ) {
                showMessageComposer = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack {
                JournalView()
            }
        }
    }

    private func advance(to next: Stage) {
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = next
        }
    }

    private func randomVerse() -> ShieldEncouragement {
        ShieldContentProvider.fallbackEncouragements.randomElement() ?? verse
    }

    // MARK: - Stage 1: Breathe

    private var breatheStage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("You're here. That's the right move.")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.22, blue: 0.48).opacity(0.25),
                                     Color.reforgedGold.opacity(0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: breathPeriod), value: breathScale)

                Text(breathingIn ? "Breathe in" : "Breathe out")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .frame(height: 260)

            Text("Slow down for \(secondsLeft) seconds. The pull fades; the Word stays.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                HapticManager.shared.buttonTap()
                advance(to: .verse)
            } label: {
                Text(secondsLeft > 0 ? "Skip ahead" : "Continue")
                    .font(.headline)
                    .foregroundStyle(secondsLeft > 0 ? Color.adaptiveTextSecondary(colorScheme) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(secondsLeft > 0 ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Color.reforgedNavy))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            breathScale = 1.0
        }
        .onReceive(breathTimer) { _ in
            guard stage == .breathe else { return }
            if secondsLeft > 0 {
                secondsLeft -= 1
            }
            if secondsLeft % Int(breathPeriod) == 0 {
                breathingIn.toggle()
                breathScale = breathingIn ? 1.0 : 0.6
            }
            if secondsLeft == 0 {
                advance(to: .verse)
            }
        }
    }

    // MARK: - Stage 2: Verse

    private var verseStage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.reforgedGold)

            VStack(spacing: 12) {
                Text("\u{201C}\(verse.verseText)\u{201D}")
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(6)
                Text("\u{2014} \(verse.verseReference)")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)
            }
            .padding(24)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1.5))
            .padding(.horizontal, 24)

            Text(verse.suggestion)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                HapticManager.shared.buttonTap()
                advance(to: .prayer)
            } label: {
                Text("Pray it back")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Stage 4: Reach Out

    private var reachStage: some View {
        let partner = AccountabilityPartnerService.shared

        return VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.green)

            Text("Well done. Now do the next thing.")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Text("Temptation loses its grip when you turn toward something better — and when you say it out loud to someone.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                if partner.hasPartner && !partner.partnerPhone.isEmpty && MessageComposeView.canSendText {
                    Button {
                        HapticManager.shared.buttonTap()
                        showMessageComposer = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Text \(partner.partnerName)")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [Color.reforgedGold, Color.reforgedCoral],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // The shield screen used to carry a separate "when you feel the
                // pull, do this instead" launchpad. It addressed this exact
                // moment, so it lives here now — one path, not two.
                HStack(spacing: 10) {
                    instead(title: "Read", icon: "text.book.closed.fill", tab: 2)
                    instead(title: "Memorize", icon: "brain.head.profile", tab: 3)
                }

                Button {
                    HapticManager.shared.buttonTap()
                    showJournal = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Journal a reflection")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button("I'm okay now") {
                    HapticManager.shared.success()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    /// One "do this instead" shortcut — closes the flow and lands on the tab.
    private func instead(title: String, icon: String, tab: Int) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            dismiss()
            NotificationCenter.default.post(
                name: .switchTab,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: tab]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.subheadline).fontWeight(.semibold)
            }
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.reforgedGold.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
