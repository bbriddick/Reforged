import SwiftUI

struct MemoryReviewView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var currentIndex = 0
    @State private var reviewComplete = false
    @State private var reviewedCount = 0

    var versesToReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    var currentVerse: MemoryVerse? {
        guard currentIndex < versesToReview.count else { return nil }
        return versesToReview[currentIndex]
    }

    var currentMode: MemoryMode {
        guard let verse = currentVerse else { return .flashcard }
        return MemoryMode.progressiveMode(for: verse)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            if !reviewComplete && !versesToReview.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Card \(currentIndex + 1) of \(versesToReview.count)")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        Spacer()

                        Text("\(reviewedCount) reviewed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.reforgedGold)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.adaptiveBorder(colorScheme))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.reforgedNavy, Color.reforgedGold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(versesToReview.count), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding()
            }

            if reviewComplete {
                ReviewCompleteView(
                    reviewedCount: reviewedCount,
                    onDismiss: { dismiss() }
                )
            } else if let verse = currentVerse {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: currentMode.icon)
                        Text(currentMode.displayName)
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    MemoryExerciseView(
                        verse: verse,
                        mode: currentMode,
                        onComplete: { quality in
                            rateVerse(quality: quality)
                        }
                    )
                    .id(verse.id)
                }
            } else {
                // No verses to review
                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.reforgedGold)
                    }

                    Text("All caught up!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("No verses due for review")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Spacer()

                    Button("Go Back") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    func rateVerse(quality: Int) {
        guard let verse = currentVerse else { return }
        appState.updateVerseReview(verseId: verse.id, quality: quality)
        appState.addXP(quality >= 3 ? 15 : 5, source: "review")
        reviewedCount += 1

        if currentIndex < versesToReview.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentIndex += 1
            }
        } else {
            // Bonus XP for completing all due reviews
            appState.addXP(25, source: "review-complete")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                reviewComplete = true
            }
        }
    }
}

// MARK: - Review Complete View

struct ReviewCompleteView: View {
    let reviewedCount: Int
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.reforgedGold.opacity(0.3), Color.reforgedGold.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(showConfetti ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showConfetti)

                Image(systemName: "star.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.reforgedGold)
                    .rotationEffect(.degrees(showConfetti ? 10 : -10))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showConfetti)
            }

            Text("Review Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("You reviewed \(reviewedCount) verse\(reviewedCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            // XP earned card
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("+\(reviewedCount * 10)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedGold)

                    Text("XP Earned")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.reforgedGold.opacity(0.2), radius: 12, y: 6)

            Spacer()

            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.reforgedNavy)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            showConfetti = true
        }
    }
}

#Preview {
    NavigationStack {
        MemoryReviewView()
            .environmentObject(AppState.shared)
    }
}
