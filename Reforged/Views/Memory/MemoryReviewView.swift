import SwiftUI

struct MemoryReviewView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    /// When set, the session reviews only these references (a themed unit
    /// checkpoint) instead of the global due queue.
    var restrictReferences: Set<String>? = nil

    /// The session ramps difficulty in phases: an easy flashcard swipe deck first,
    /// then graduated single-card exercises that get harder as verses mature.
    private enum Phase { case loading, deck, graded, complete, empty }

    // Snapshotted once on appear so ratings during the session don't reshuffle the queue.
    @State private var flashcardVerses: [MemoryVerse] = []
    @State private var gradedVerses: [MemoryVerse] = []
    @State private var gradedIndex = 0
    @State private var reviewedCount = 0
    @State private var phase: Phase = .loading

    private var totalCount: Int { flashcardVerses.count + gradedVerses.count }

    private var currentGradedVerse: MemoryVerse? {
        guard gradedIndex < gradedVerses.count else { return nil }
        return gradedVerses[gradedIndex]
    }

    private var currentMode: MemoryMode {
        guard let verse = currentGradedVerse else { return .flashcard }
        return MemoryMode.progressiveMode(for: verse)
    }

    var body: some View {
        VStack(spacing: 0) {
            if phase == .deck || phase == .graded {
                progressHeader
            }

            switch phase {
            case .loading:
                Color.clear
            case .deck:
                FlashcardDeckView(
                    verses: flashcardVerses,
                    onRate: { verseId, quality in rate(verseId: verseId, quality: quality) },
                    onFinished: { advanceFromDeck() }
                )
            case .graded:
                if let verse = currentGradedVerse {
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
                                rate(verseId: verse.id, quality: quality)
                                advanceGraded()
                            }
                        )
                        .id(verse.id)
                    }
                }
            case .complete:
                ReviewCompleteView(reviewedCount: reviewedCount, onDismiss: { dismiss() })
            case .empty:
                emptyState
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startSessionIfNeeded)
    }

    // MARK: Progress header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(min(reviewedCount + 1, totalCount)) of \(totalCount)")
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
                        .frame(width: geo.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
    }

    private var progressFraction: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(reviewedCount) / CGFloat(totalCount)
    }

    private var emptyState: some View {
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

            Button("Go Back") { dismiss() }
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

    // MARK: Session flow

    private func startSessionIfNeeded() {
        guard phase == .loading else { return }
        let due: [MemoryVerse]
        if let refs = restrictReferences {
            // Unit checkpoint: review every started verse in the unit, due or not.
            due = appState.memoryVerses.filter { refs.contains($0.reference) }
        } else {
            due = appState.getVersesForReview()
        }
        flashcardVerses = due.filter { MemoryMode.isFlashcardStage($0) }
        // Graded exercises are ordered easiest → hardest so the session keeps ramping up.
        gradedVerses = due.filter { !MemoryMode.isFlashcardStage($0) }
            .sorted { $0.level < $1.level }

        if !flashcardVerses.isEmpty {
            phase = .deck
        } else if !gradedVerses.isEmpty {
            phase = .graded
        } else {
            phase = .empty
        }
    }

    private func advanceFromDeck() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            phase = gradedVerses.isEmpty ? .complete : .graded
        }
        if gradedVerses.isEmpty { awardCompletionBonus() }
    }

    private func advanceGraded() {
        if gradedIndex < gradedVerses.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                gradedIndex += 1
            }
        } else {
            awardCompletionBonus()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .complete
            }
        }
    }

    private func rate(verseId: String, quality: Int) {
        appState.updateVerseReview(verseId: verseId, quality: quality)
        appState.addXP(quality >= 3 ? 15 : 5, source: "review")
        reviewedCount += 1
    }

    private func awardCompletionBonus() {
        // Bonus XP for completing all due reviews.
        appState.addXP(25, source: "review-complete")
    }
}

// MARK: - Flashcard Swipe Deck (Quizlet-style)

/// Presents all flashcard-stage verses as a swipeable stack. Swipe right = Known,
/// swipe left = Still learning (the card requeues to the back for another pass this
/// session). Each verse reports its SM-2 verdict once, on its first decisive swipe.
struct FlashcardDeckView: View {
    let verses: [MemoryVerse]
    let onRate: (String, Int) -> Void
    let onFinished: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var queue: [MemoryVerse] = []
    @State private var ratedIds: Set<String> = []
    @State private var knownCount = 0
    @State private var didStart = false
    // Monotonic id for the top card so every swipe yields a fresh card view — even when
    // requeuing the last card leaves the queue count unchanged.
    @State private var presentationSeq = 0

    var body: some View {
        VStack(spacing: 16) {
            // Stage label
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle.angled")
                Text("Flashcards")
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Text("\(knownCount) of \(verses.count) known")
                .font(.caption2)
                .foregroundStyle(Color.reforgedGold)

            Spacer(minLength: 0)

            // Card stack
            ZStack {
                if queue.count > 1 {
                    // Peek of the next card behind the top one.
                    FlashcardFront(verse: queue[1], colorScheme: colorScheme)
                        .scaleEffect(0.94)
                        .offset(y: 18)
                        .opacity(0.45)
                        .allowsHitTesting(false)
                }

                if let top = queue.first {
                    SwipeableFlashcard(verse: top, onSwipe: { verdict in
                        handleSwipe(top, verdict)
                    })
                    .id(presentationSeq)
                    .transition(.identity)
                }
            }

            Spacer(minLength: 0)

            // Fallback buttons for those who'd rather tap than swipe.
            if let top = queue.first {
                HStack(spacing: 12) {
                    Button {
                        handleSwipe(top, .unknown)
                    } label: {
                        Label("Still learning", systemImage: "arrow.uturn.left")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        handleSwipe(top, .known)
                    } label: {
                        Label("Known", systemImage: "checkmark")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            queue = verses
        }
    }

    private func handleSwipe(_ verse: MemoryVerse, _ verdict: FlashcardSwipe) {
        // Record the SM-2 verdict once, on the verse's first decisive swipe.
        if !ratedIds.contains(verse.id) {
            onRate(verse.id, verdict.quality)
            ratedIds.insert(verse.id)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            // Remove the top instance of this verse.
            if let idx = queue.firstIndex(where: { $0.id == verse.id }) {
                queue.remove(at: idx)
            }
            if verdict == .known {
                knownCount += 1
            } else {
                // Still learning — send it to the back for another pass this session.
                queue.append(verse)
            }
            presentationSeq += 1
        }

        if queue.isEmpty {
            onFinished()
        }
    }
}

// MARK: - Review Complete View

struct ReviewCompleteView: View {
    let reviewedCount: Int
    let onDismiss: () -> Void

    var body: some View {
        JackpotStage(
            config: JackpotConfig(
                hero: .symbol("brain.head.profile"),
                headline: "Review complete",
                title: "Those verses are going deeper.",
                accent: .gold,
                reels: [
                    JackpotReel(icon: "book.closed.fill", label: "Verses reviewed", value: reviewedCount, prefix: "", tint: .reforgedCoral),
                    JackpotReel(icon: "star.fill", label: "Completion bonus", value: 25, suffix: " XP", tint: .reforgedGold),
                ],
                cta: "Done",
                intensity: .max
            ),
            onDismiss: onDismiss
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

#if false
#Preview {
    NavigationStack {
        MemoryReviewView()
            .environmentObject(AppState.shared)
    }
}
#endif
