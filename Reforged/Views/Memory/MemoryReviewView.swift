import SwiftUI

struct MemoryReviewView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var rotation: Double = 0
    @State private var reviewComplete = false
    @State private var reviewedCount = 0

    var versesToReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    var currentVerse: MemoryVerse? {
        guard currentIndex < versesToReview.count else { return nil }
        return versesToReview[currentIndex]
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
                ReviewFlashcardView(
                    verse: verse,
                    isFlipped: $isFlipped,
                    rotation: $rotation,
                    onRate: { quality in
                        rateVerse(quality: quality)
                    }
                )
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
                isFlipped = false
                rotation = 0
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

// MARK: - Review Flashcard View (with 3D flip)

struct ReviewFlashcardView: View {
    let verse: MemoryVerse
    @Binding var isFlipped: Bool
    @Binding var rotation: Double
    let onRate: (Int) -> Void
    @Environment(\.colorScheme) var colorScheme

    // First letters hint
    var firstLetters: String {
        verse.text.components(separatedBy: " ")
            .prefix(8)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined(separator: " ")
        + (verse.text.components(separatedBy: " ").count > 8 ? " ..." : "")
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Flipping Card
            ZStack {
                // Back side (verse text)
                ReviewCardBack(verse: verse, colorScheme: colorScheme)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                // Front side (reference + hint)
                ReviewCardFront(verse: verse, firstLetters: firstLetters, colorScheme: colorScheme)
                    .opacity(isFlipped ? 0 : 1)
            }
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    rotation += 180
                    isFlipped.toggle()
                }
            }
            .padding(.horizontal)

            Spacer()

            // Rating Buttons (shown after flip)
            if isFlipped {
                VStack(spacing: 12) {
                    Text("How well did you recall?")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    HStack(spacing: 10) {
                        ReviewRatingButton(label: "Again", subtitle: "1 day", color: .red, quality: 1, onRate: onRate)
                        ReviewRatingButton(label: "Hard", subtitle: "3 days", color: .orange, quality: 2, onRate: onRate)
                        ReviewRatingButton(label: "Good", subtitle: "7 days", color: .green, quality: 4, onRate: onRate)
                        ReviewRatingButton(label: "Easy", subtitle: "14 days", color: .blue, quality: 5, onRate: onRate)
                    }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Hint to tap
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                    Text("Tap card to flip")
                }
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding()
            }
        }
    }
}

struct ReviewCardFront: View {
    let verse: MemoryVerse
    let firstLetters: String
    let colorScheme: ColorScheme?

    var body: some View {
        VStack(spacing: 20) {
            Text(verse.reference)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))

            Divider()

            VStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundStyle(Color.reforgedGold)

                Text("First letter hint:")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Text(firstLetters)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .padding(.vertical, 20)

            // Category badge
            Text(verse.category)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.reforgedNavy.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
        .padding(28)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.reforgedNavy.opacity(0.15), radius: 20, y: 10)
    }
}

struct ReviewCardBack: View {
    let verse: MemoryVerse
    let colorScheme: ColorScheme?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(verse.reference)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.reforgedGold.opacity(0.6))
            }

            Divider()
                .background(Color.white.opacity(0.2))

            ScrollView {
                Text("\"\(verse.text)\"")
                    .font(.body)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color.reforgedNavy, Color.reforgedDarkBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.reforgedNavy.opacity(0.3), radius: 20, y: 10)
    }
}

struct ReviewRatingButton: View {
    let label: String
    let subtitle: String
    let color: Color
    let quality: Int
    let onRate: (Int) -> Void

    var body: some View {
        Button(action: { onRate(quality) }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
