import SwiftUI

/// Duolingo-style daily guided lesson container:
/// Walks the user through progressive tasks (Listen -> Phrase Tap -> Drag & Drop -> Fill Blank -> Say It Back)
/// with continuous progress tracking, 3D bottom drawer feedback, XP rewards, and daily check-offs.
struct DailyLessonRunnerView: View {
    let verse: MemoryVerse
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var session: DailyWorkoutSession
    @State private var currentStageQuality: Int = 4
    @State private var showDrawer: Bool = false
    @State private var earnedXPSoFar: Int = 0
    @State private var isFinalCelebration: Bool = false

    init(verse: MemoryVerse, onFinished: @escaping () -> Void) {
        self.verse = verse
        self.onFinished = onFinished
        _session = State(initialValue: DailyWorkoutSession.generate(for: verse))
    }

    var currentStage: WorkoutStageType {
        session.currentStage ?? .listen
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Duolingo-Style Header: Close Button + Animated Progress Bar
                HStack(spacing: 14) {
                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(8)
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.adaptiveBorder(colorScheme))
                                .frame(height: 12)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.reforgedGold, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(session.progress), height: 12)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: session.progress)
                        }
                    }
                    .frame(height: 12)

                    // Stage counter badge
                    Text("\(session.currentStageIndex + 1)/\(session.stages.count)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider()

                // Active Stage Workout Content
                ZStack {
                    switch currentStage {
                    case .listen:
                        ListenAndAbsorbStage(
                            verse: verse,
                            onComplete: { quality in
                                handleStageCompletion(quality: quality)
                            },
                            onSkip: skipCurrentStage
                        )
                    case .phraseByPhrase:
                        TapToRevealView(verse: verse) { quality in
                            handleStageCompletion(quality: quality)
                        }
                    case .dragAndDrop:
                        DragAndDropView(verse: verse) { quality in
                            handleStageCompletion(quality: quality)
                        }
                    case .fillBlank:
                        FillInBlankView(verse: verse) { quality in
                            handleStageCompletion(quality: quality)
                        }
                    case .sayItBack:
                        SayItBackView(verse: verse) { quality in
                            handleStageCompletion(quality: quality)
                        }
                    }
                }
                .id(currentStage.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())

            // Duolingo-Style Bottom Success Drawer
            if showDrawer {
                stageCompleteDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Full-screen Lesson Completion Celebration
            if isFinalCelebration {
                finalCelebration
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showDrawer)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFinalCelebration)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Bottom Success Drawer
    private var stageCompleteDrawer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.65, blue: 0.35))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nicely Done!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.1, green: 0.6, blue: 0.3))

                    Text("+\(currentStage.xpReward) XP earned")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                }

                Spacer()
            }

            Button {
                advanceToNextStage()
            } label: {
                Text("CONTINUE")
            }
            .buttonStyle(Chunky3DButtonStyle(
                backgroundColor: Color(red: 0.15, green: 0.65, blue: 0.35),
                bevelColor: Color(red: 0.1, green: 0.5, blue: 0.25)
            ))
        }
        .padding(20)
        .background(
            colorScheme == .dark
                ? Color(red: 0.12, green: 0.18, blue: 0.14)
                : Color(red: 0.92, green: 0.98, blue: 0.94)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Final Celebration
    private var finalCelebration: some View {
        JackpotStage(
            config: JackpotConfig(
                hero: .symbol("crown.fill"),
                headline: "Lesson complete",
                title: "You hid \(verse.reference) in your heart today.",
                accent: .gold,
                reels: [
                    JackpotReel(icon: "star.fill", label: "XP earned", value: earnedXPSoFar, tint: .reforgedGold),
                    JackpotReel(icon: "flame.fill", label: "Day streak", value: appState.user.streak, prefix: "", tint: .reforgedCoral),
                ],
                cta: "Claim & return",
                intensity: .max
            ),
            onDismiss: {
                dismiss()
                onFinished()
            }
        )
    }

    // MARK: - Logic
    private func handleStageCompletion(quality: Int) {
        currentStageQuality = quality
        // Accrue XP locally only — it is granted once the whole lesson is
        // finished (see advanceToNextStage). Abandoning a lesson early awards
        // nothing, so XP always reflects a completed lesson.
        earnedXPSoFar += currentStage.xpReward

        session.completedStageIndices.insert(session.currentStageIndex)
        HapticManager.shared.lessonStageComplete()

        withAnimation {
            showDrawer = true
        }
    }

    private func skipCurrentStage() {
        session.completedStageIndices.insert(session.currentStageIndex)
        HapticManager.shared.buttonTap()

        if session.currentStageIndex + 1 < session.stages.count {
            withAnimation(.easeInOut(duration: 0.25)) {
                session.currentStageIndex += 1
            }
        }
    }

    private func advanceToNextStage() {
        showDrawer = false

        if session.currentStageIndex + 1 < session.stages.count {
            withAnimation(.easeInOut(duration: 0.25)) {
                session.currentStageIndex += 1
            }
        } else {
            // Finished all stages for today! A first-time curriculum verse is only
            // committed to memory now (see MemoryJourneyView.startOrOpen), so it
            // joins the review queue and unlocks the next node only on completion.
            if !appState.memoryVerses.contains(where: { $0.id == verse.id }) {
                appState.addMemoryVerse(verse)
            }
            // Grant the full lesson's XP now — the only place XP is awarded, so it
            // always means a completed lesson.
            appState.addXP(earnedXPSoFar, source: "memory-daily-lesson")
            DailyMemoryPlanManager.shared.markTodayCompleted(verseId: verse.id)
            appState.updateVerseReview(verseId: verse.id, quality: max(3, currentStageQuality))
            SocialLimitService.shared.grantForMemoryActivity()
            UnlockGateService.shared.clear(with: .memoryVerse)

            // JackpotStage scores its own haptics (drumroll → slam → payout).
            withAnimation {
                isFinalCelebration = true
            }
        }
    }
}

// MARK: - Stage 1: Listen and Absorb Component
struct ListenAndAbsorbStage: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    let onSkip: () -> Void

    @ObservedObject private var player = MemoryAudioPlayer.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var hasListened: Bool = false
    @State private var startedPlayback: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.title3)
                        .foregroundStyle(Color.reforgedGold)
                    Text("Listen & Absorb")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                Text("Listen to the verse spoken aloud while reading along.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.top, 16)

            Spacer()

            // Big Card with Scripture
            VStack(spacing: 18) {
                Text(verse.reference)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                Text("\"\(verse.text)\"")
                    .font(.title3)
                    .italic()
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(.horizontal)
            }
            .padding(28)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 14, y: 6)
            .padding(.horizontal)

            Spacer()

            // Playback and Continue Actions
            VStack(spacing: 14) {
                Button {
                    HapticManager.shared.buttonTap()
                    if player.isPlaying {
                        player.pause()
                    } else {
                        // Play the verse through once (no endless loop) so it stops
                        // on its own when the reading finishes.
                        player.targetLoopCount = 1
                        player.play(verse: verse)
                        startedPlayback = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        Text(player.isPlaying ? "PAUSE AUDIO" : "LISTEN TO VERSE")
                    }
                }
                .buttonStyle(Chunky3DButtonStyle(
                    backgroundColor: Color.reforgedNavy,
                    bevelColor: Color.reforgedDarkBlue
                ))
                .padding(.horizontal, 24)

                if hasListened {
                    Button {
                        player.stop()
                        HapticManager.shared.lessonStageComplete()
                        onComplete(4)
                    } label: {
                        Text("I'VE LISTENED")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    }
                    .padding(.vertical, 8)
                } else {
                    Button {
                        player.stop()
                        onSkip()
                    } label: {
                        Text("CAN'T LISTEN RIGHT NOW")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .onChange(of: player.currentVerse?.id) { currentVerseID in
            guard startedPlayback, currentVerseID == nil else { return }
            hasListened = true
            HapticManager.shared.success()
        }
        // Stop playback whenever this stage leaves the screen (advancing to the
        // next stage, or closing the lesson mid-listen), and restore the shared
        // player's default looping for other surfaces (e.g. the Loop Audio tool).
        .onDisappear {
            player.stop()
            player.targetLoopCount = nil
        }
    }
}
