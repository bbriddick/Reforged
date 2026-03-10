import SwiftUI

// MARK: - Deep Drill View
// Chains Flashcard → Fill-in-Blank → Typing in one session.
// SM-2 is updated once after the Typing round. +30 bonus XP for completing all 3.

struct DeepDrillView: View {
    let verse: MemoryVerse
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var currentRound: Int = 0   // 0 = flashcard, 1 = fill-in-blank, 2 = typing
    @State private var showCelebration = false
    @State private var completedQuality: Int = 0
    @State private var earnedXP: Int = 0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                DrillProgressStepper(currentRound: currentRound)
                    .padding()

                Divider()

                Group {
                    switch currentRound {
                    case 0:
                        FlashcardPracticeView(verse: verse, onComplete: handleFlashcardComplete)
                    case 1:
                        FillInBlankView(verse: verse, onComplete: handleFillInBlankComplete)
                    default:
                        TypingPracticeView(verse: verse, onComplete: handleTypingComplete)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentRound)
            }
            .navigationTitle("Deep Drill")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())

            // Celebration overlay
            if showCelebration {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                PracticeCompleteCelebration(
                    score: completedQuality,
                    xpEarned: earnedXP,
                    isPresented: $showCelebration
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCelebration)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentRound)
        .onChange(of: showCelebration) { newValue in
            if !newValue { dismiss() }
        }
    }

    // MARK: - Round Handlers

    private func handleFlashcardComplete(_: Int) {
        currentRound = 1
    }

    private func handleFillInBlankComplete(_: Int) {
        currentRound = 2
    }

    private func handleTypingComplete(quality: Int) {
        appState.updateVerseReview(verseId: verse.id, quality: quality)
        let baseXP = quality >= 3 ? 20 : 5
        let bonusXP = 30
        earnedXP = baseXP + bonusXP
        appState.addXP(earnedXP, source: "deep drill")
        completedQuality = quality

        withAnimation {
            showCelebration = true
        }
    }
}

// MARK: - Drill Progress Stepper

struct DrillProgressStepper: View {
    let currentRound: Int

    private let rounds = ["Flashcard", "Fill Blank", "Typing"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(rounds.indices, id: \.self) { index in
                HStack(spacing: 0) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(stepColor(index))
                            .frame(width: 28, height: 28)

                        if index < currentRound {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(index == currentRound ? .white : Color.secondary)
                        }
                    }

                    // Label
                    Text(rounds[index])
                        .font(.caption2)
                        .fontWeight(index == currentRound ? .semibold : .regular)
                        .foregroundStyle(index <= currentRound ? stepColor(index) : Color.secondary)
                        .padding(.leading, 4)

                    // Connector line (not after last)
                    if index < rounds.count - 1 {
                        Rectangle()
                            .fill(index < currentRound ? Color.reforgedGold : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                    }
                }
            }
        }
    }

    private func stepColor(_ index: Int) -> Color {
        if index < currentRound {
            return Color.reforgedGold
        } else if index == currentRound {
            return Color.reforgedCoral
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
}
