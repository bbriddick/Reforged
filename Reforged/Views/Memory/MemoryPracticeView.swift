import SwiftUI

private func normalizedVerseWords(from text: String) -> [String] {
    text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
}

// MARK: - Hub groups and rows (Home and Discipleship)

/// A labelled group: a small caption above one bordered container of rows.
struct HubGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .practiceCard(radius: 18)
        }
    }
}

/// Divider that lines up with the text of `HubRowLabel`.
struct HubDivider: View {
    var body: some View { Divider().padding(.leading, 66) }
}

/// One row: icon chip, title, one line of context, optional accessory, chevron.
struct HubRowLabel<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    var showsChevron = true
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.14),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailing()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared practice styling
//
// One visual language for every practice mode, matching the Memory tab's path:
// content sits on bordered adaptive cards, actions are chunky 3D buttons with an
// extruded lip, progress is a thick capsule bar, and accents are coral (action)
// and gold (reward). `reforgedNavy` is deliberately avoided: it is charcoal and
// disappears on dark cards.

extension Color {
    /// Success green shared with the lesson flow's Continue drawer.
    static let practiceGreen = Color(red: 0.15, green: 0.65, blue: 0.35)

    /// A deeper shade of this color, used for the extruded lip under 3D buttons and tiles.
    func practiceBevel() -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self.opacity(0.7)
        }
        return Color(hue: Double(h), saturation: Double(min(1, s * 1.05)),
                     brightness: Double(b * 0.72), opacity: Double(a))
    }
}

/// A bordered card surface (the Memory tab's card treatment).
private struct PracticeCardModifier: ViewModifier {
    var radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
    }
}

extension View {
    func practiceCard(radius: CGFloat = 18) -> some View {
        modifier(PracticeCardModifier(radius: radius))
    }
}

/// Compact 3D press style for tiles and rating buttons: a colored face resting on a
/// deeper lip that the face presses down onto. Unlike `Chunky3DButtonStyle` it adds no
/// font or padding, so it fits four-across rows and grid cells.
struct PracticeLipButtonStyle: ButtonStyle {
    var face: Color
    var lip: Color
    var stroke: Color? = nil
    var cornerRadius: CGFloat = 14
    var depth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(
                ZStack {
                    shape.fill(lip).offset(y: pressed ? 1.5 : depth)
                    shape.fill(face)
                    if let stroke { shape.strokeBorder(stroke, lineWidth: 1) }
                }
            )
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: pressed)
    }
}

/// The primary action in every practice mode. Coral and chunky when active; a flat
/// gray lip when there is nothing to submit yet.
struct PracticeButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    var tint: Color = .reforgedCoral
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
        }
        .buttonStyle(Chunky3DButtonStyle(
            backgroundColor: enabled ? tint : Color.adaptiveBorder(colorScheme),
            bevelColor: enabled ? tint.practiceBevel() : Color.adaptiveBorder(colorScheme).practiceBevel(),
            textColor: enabled ? .white : Color.adaptiveTextSecondary(colorScheme)
        ))
        .disabled(!enabled)
        .padding(.horizontal)
    }
}

/// Reference title with an optional one-line instruction beneath it.
struct PracticeHeader: View {
    let reference: String
    var prompt: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(reference)
                .font(.title2.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))
            if let prompt {
                Text(prompt)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.horizontal)
    }
}

/// Thick segmented progress: gold for finished steps, coral for the current one.
struct PracticeStepBar: View {
    let total: Int
    let completed: Int
    var label: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { i in
                    Capsule()
                        .fill(i < completed ? Color.reforgedGold
                              : (i == completed ? Color.reforgedCoral : Color.adaptiveBorder(colorScheme)))
                        .frame(height: 8)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completed)

            if let label {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(.horizontal, 24)
    }
}

/// Small uppercase caption above a group, like the Memory tab's section labels.
struct PracticeSectionLabel: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
    }
}

/// Outcome summary shown after a round: tinted card with an icon chip and title.
struct PracticeResultBanner: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(tint.opacity(0.35), lineWidth: 1))
        .padding(.horizontal)
    }
}

/// "Again / Hard / Good / Easy" self-rating, the closing step of most modes.
struct PracticeRatingRow: View {
    var prompt: String? = "How well did you recall?"
    var subtitled: Bool = false
    let onRate: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            if let prompt {
                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            HStack(spacing: 10) {
                RatingButton(label: "Again", color: .red, quality: 1, onRate: rate,
                             subtitle: subtitled ? "I didn't know it" : nil)
                RatingButton(label: "Hard", color: .orange, quality: 2, onRate: rate,
                             subtitle: subtitled ? "I struggled" : nil)
                RatingButton(label: "Good", color: Color.practiceGreen, quality: 4, onRate: rate,
                             subtitle: subtitled ? "I knew it" : nil)
                RatingButton(label: "Easy", color: .blue, quality: 5, onRate: rate,
                             subtitle: subtitled ? "I knew it cold" : nil)
            }
        }
        .padding(.horizontal)
    }

    private func rate(_ quality: Int) {
        switch quality {
        case 1: HapticManager.shared.incorrectAnswer()
        case 2: HapticManager.shared.lightImpact()
        default: HapticManager.shared.correctAnswer()
        }
        onRate(quality)
    }
}

struct MemoryPracticeView: View {
    let verse: MemoryVerse
    let mode: MemoryMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var showCelebration = false
    @State private var completedQuality: Int = 0
    @State private var earnedXP: Int = 0

    var body: some View {
        ZStack {
            MemoryExerciseView(verse: verse, mode: mode, onComplete: handleComplete)
                .navigationTitle(mode.displayName)
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
        .onChange(of: showCelebration) { newValue in
            if !newValue {
                // Dismiss after celebration ends
                dismiss()
            }
        }
    }

    func handleComplete(quality: Int) {
        appState.updateVerseReview(verseId: verse.id, quality: quality)
        earnedXP = quality >= 3 ? 20 : 5
        appState.addXP(earnedXP, source: "practice")
        completedQuality = quality

        // Completing a memory activity earns social-media time (if the daily limit is
        // on) and satisfies the unlock gate.
        SocialLimitService.shared.grantForMemoryActivity()
        UnlockGateService.shared.clear(with: .memoryVerse)

        // Show celebration
        withAnimation {
            showCelebration = true
        }
    }
}

// MARK: - Exercise Router

/// Renders the practice UI for a given mode. Shared by manual practice and progressive due review.
struct MemoryExerciseView: View {
    let verse: MemoryVerse
    let mode: MemoryMode
    let onComplete: (Int) -> Void

    var body: some View {
        switch mode {
        case .flashcard:
            FlashcardPracticeView(verse: verse, onComplete: onComplete)
        case .tapToReveal:
            TapToRevealView(verse: verse, onComplete: onComplete)
        case .dragAndDrop:
            DragAndDropView(verse: verse, onComplete: onComplete)
        case .fillInBlank:
            FillInBlankView(verse: verse, onComplete: onComplete)
        case .firstLetter:
            FirstLetterView(verse: verse, onComplete: onComplete)
        case .typing:
            TypingPracticeView(verse: verse, onComplete: onComplete)
        }
    }
}

// MARK: - Flashcard swipe direction

/// A Quizlet-style swipe verdict on a flashcard.
enum FlashcardSwipe {
    case known    // swipe right  → recalled it
    case unknown  // swipe left   → still learning

    /// Maps the verdict onto the SM-2 quality scale.
    var quality: Int {
        switch self {
        case .known: return 4
        case .unknown: return 1
        }
    }
}

// MARK: - Swipeable Flashcard (tap-to-flip + swipe left/right)

/// The shared card used by both single-verse practice and the review swipe deck.
/// Tap flips front↔back; dragging left/right past a threshold reports a verdict.
/// Set `onSwipe` to nil to disable swiping (flip-only).
struct SwipeableFlashcard: View {
    let verse: MemoryVerse
    var onSwipe: ((FlashcardSwipe) -> Void)? = nil
    var onFlip: (() -> Void)? = nil
    @State private var isFlipped = false
    @State private var rotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var isLeaving = false
    @Environment(\.colorScheme) var colorScheme

    private let swipeThreshold: CGFloat = 110

    /// Which verdict the current drag is leaning toward (for the live stamp overlay).
    private var swipeHint: FlashcardSwipe? {
        guard abs(dragOffset.width) > 36 else { return nil }
        return dragOffset.width > 0 ? .known : .unknown
    }

    var body: some View {
        ZStack {
            // Back side (verse text)
            FlashcardBack(verse: verse, colorScheme: colorScheme)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

            // Front side (reference + prompt)
            FlashcardFront(verse: verse, colorScheme: colorScheme)
                .opacity(isFlipped ? 0 : 1)
        }
        .scaleEffect(cardScale)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        // The stamp sits OUTSIDE the flip rotation: inside it, a flipped card mirrored
        // the text, so "KNOWN" / "STILL LEARNING" read backward on the verse side.
        .overlay {
            if let hint = swipeHint {
                SwipeStamp(kind: hint)
                    .opacity(min(1, Double(abs(dragOffset.width) - 36) / 80))
            }
        }
        .rotationEffect(.degrees(Double(dragOffset.width / 22)))
        .offset(dragOffset)
        .onTapGesture {
            HapticManager.shared.cardFlipEdgeThud()
            withAnimation(.easeInOut(duration: 0.12)) { cardScale = 0.94 }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                rotation += 180
                isFlipped.toggle()
            }
            withAnimation(.easeOut(duration: 0.2).delay(0.12)) { cardScale = 1.0 }
            onFlip?()
        }
        .gesture(onSwipe == nil ? nil : dragGesture)
        .padding(.horizontal)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !isLeaving else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isLeaving else { return }
                if abs(value.translation.width) > swipeThreshold {
                    commitSwipe(value.translation.width > 0 ? .known : .unknown)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func commitSwipe(_ verdict: FlashcardSwipe) {
        isLeaving = true
        switch verdict {
        case .known: HapticManager.shared.correctAnswer()
        case .unknown: HapticManager.shared.incorrectAnswer()
        }
        // Fly the card off in the swiped direction, then report the verdict.
        withAnimation(.easeOut(duration: 0.28)) {
            dragOffset.width = verdict == .known ? 700 : -700
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            onSwipe?(verdict)
        }
    }
}

/// The "KNOWN" / "STILL LEARNING" stamp that fades in while dragging.
private struct SwipeStamp: View {
    let kind: FlashcardSwipe

    var body: some View {
        let known = kind == .known
        return Text(known ? "KNOWN" : "STILL LEARNING")
            .font(.system(size: known ? 34 : 22, weight: .heavy))
            .foregroundStyle(known ? Color.green : Color.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(known ? Color.green : Color.red, lineWidth: 4)
            )
            .rotationEffect(.degrees(known ? -18 : 18))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
    }
}

// MARK: - Flashcard Practice View (single verse: swipe or flip + rate)

struct FlashcardPracticeView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var hasFlipped = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            SwipeableFlashcard(verse: verse, onSwipe: { verdict in
                onComplete(verdict.quality)
            }, onFlip: {
                // Track the first flip so we can surface the finer 4-way rating.
                hasFlipped = true
            })

            // Swipe hint
            HStack(spacing: 10) {
                swipeHintPill(icon: "arrow.left", text: "Still learning", tint: .red, iconLeading: true)
                swipeHintPill(icon: "arrow.right", text: "Known", tint: Color.practiceGreen, iconLeading: false)
            }

            Spacer()

            // Optional finer rating once the card has been flipped to reveal the text.
            if hasFlipped {
                PracticeRatingRow(prompt: "Or rate how well you recalled", subtitled: true, onRate: onComplete)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasFlipped)
    }

    private func swipeHintPill(icon: String, text: String, tint: Color, iconLeading: Bool) -> some View {
        HStack(spacing: 6) {
            if iconLeading { Image(systemName: icon) }
            Text(text)
            if !iconLeading { Image(systemName: icon) }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.13), in: Capsule())
    }
}

struct FlashcardFront: View {
    let verse: MemoryVerse
    let colorScheme: ColorScheme?
    @ObservedObject private var settings = SettingsManager.shared

    // First letters hint
    var firstLetters: String {
        verse.text.components(separatedBy: " ")
            .prefix(8)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined(separator: " ")
        + (verse.text.components(separatedBy: " ").count > 8 ? " ..." : "")
    }

    private var scheme: ColorScheme { colorScheme ?? .light }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.reforgedCoral.opacity(scheme == .dark ? 0.22 : 0.13))
                    .frame(width: 56, height: 56)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.reforgedCoral)
            }

            Text(verse.reference)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            if settings.showFirstLetterHints {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color.reforgedGold)
                        Text("FIRST LETTERS")
                            .tracking(0.6)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .font(.caption2.weight(.semibold))

                    Text(firstLetters)
                        .font(.headline.monospaced())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color.reforgedGold.opacity(scheme == .dark ? 0.16 : 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                Text("Tap to flip")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .padding(24)
        .practiceCard(radius: 22)
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
    }
}

struct FlashcardBack: View {
    let verse: MemoryVerse
    let colorScheme: ColorScheme?

    var body: some View {
        VStack(spacing: 16) {
            Text(verse.reference)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.9))

            Divider()
                .background(Color.white.opacity(0.3))

            Text("\"\(verse.text)\"")
                .font(.body)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(6)

            if let note = verse.reflectionNote, !note.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your reflection")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(note)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(Color.white.opacity(0.75))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.reforgedCoral, Color.reforgedCoral.practiceBevel()],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.reforgedCoral.opacity(0.35), radius: 16, y: 8)
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding()
        )
    }
}

// MARK: - Tap to Reveal View (Phrase by Phrase)

struct TapToRevealView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var revealedPhrases: Int = 0
    @State private var showRating = false
    @Environment(\.colorScheme) var colorScheme

    var phrases: [String] {
        // Split verse into phrases of 3-5 words
        let words = verse.text.components(separatedBy: " ")
        var result: [String] = []
        var current: [String] = []

        for word in words {
            current.append(word)
            // Break on punctuation or every 4-5 words
            if current.count >= 4 || word.last?.isPunctuation == true {
                result.append(current.joined(separator: " "))
                current = []
            }
        }
        if !current.isEmpty {
            result.append(current.joined(separator: " "))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        PracticeHeader(reference: verse.reference, prompt: "Recall each phrase, then reveal it")

                        PracticeStepBar(total: phrases.count, completed: revealedPhrases)

                        // Phrase container
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<phrases.count, id: \.self) { index in
                                if index < revealedPhrases {
                                    Text(phrases[index])
                                        .font(.title3)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .scale(scale: 0.9)),
                                            removal: .opacity
                                        ))
                                } else if index == revealedPhrases {
                                    HStack(spacing: 4) {
                                        ForEach(0..<phrases[index].components(separatedBy: " ").count, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.adaptiveBorder(colorScheme))
                                                .frame(width: 40, height: 24)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .practiceCard(radius: 20)
                        .padding(.horizontal)
                        .id("phraseContainer")
                    }
                    .padding(.bottom, 12)
                }
                .onChange(of: revealedPhrases) { _ in
                    withAnimation { proxy.scrollTo("phraseContainer", anchor: .bottom) }
                }
            }

            Divider()

            // Sticky bottom action area
            if showRating {
                PracticeRatingRow(onRate: onComplete)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                PracticeButton(title: revealedPhrases == 0 ? "Tap to Start" : "Reveal Next",
                               icon: "hand.tap.fill", action: revealNextPhrase)
                    .padding(.vertical, 8)
            }
        }
    }

    func revealNextPhrase() {
        // Haptic feedback for each reveal
        HapticManager.shared.lightImpact()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            revealedPhrases += 1
            if revealedPhrases >= phrases.count {
                HapticManager.shared.success()
                showRating = true
            }
        }
    }
}

// MARK: - Drag and Drop View

struct DraggableWord: Identifiable, Equatable {
    let id = UUID()
    let word: String
    var isUsed: Bool = false
}

struct DragAndDropView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    // Each blank tracks the *identity* (UUID) of the tile placed in it, not its
    // string. Tracking by string breaks whenever a verse repeats a word ("love"
    // twice): two distinct tiles share the same text, so value-based bookkeeping
    // would clear one blank when the other is filled and miscount the score.
    @State private var blanks: [(index: Int, word: String, filledID: UUID?)] = []
    @State private var availableWords: [DraggableWord] = []
    @State private var displayWords: [String] = []
    @State private var showResult = false
    @State private var score = 0
    @State private var selectedWordForTap: DraggableWord? = nil
    @State private var draggingWord: DraggableWord? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragOrigin: CGPoint = .zero
    @State private var dropZoneFrames: [Int: CGRect] = [:]
    @State private var hoveredBlankIndex: Int? = nil
    @State private var currentSegment: Int = 0
    @Environment(\.colorScheme) var colorScheme

    // Split multi-verse / long passages into sentence-sized sections (~18+ words
    // each, breaking at clause punctuation) so a long passage becomes several
    // smaller drag-and-drop rounds instead of one overwhelming blank+word-bank grid.
    // Mirrors FillInBlankView.segments.
    var segments: [[String]] {
        let words = normalizedVerseWords(from: verse.text)
        guard words.count > 25 else { return [words] }
        var result: [[String]] = []
        var current: [String] = []
        for word in words {
            current.append(word)
            let endsClause = word.last == "." || word.last == ";" || word.last == "!" || word.last == "?"
            if current.count >= 18 && endsClause {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var isLastSegment: Bool { currentSegment >= segments.count - 1 }
    var hasMultipleSegments: Bool { segments.count > 1 }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    PracticeHeader(
                        reference: verse.reference,
                        prompt: hasMultipleSegments ? nil : "Tap words to fill the blanks, or drag them into place"
                    )

                    if hasMultipleSegments {
                        PracticeStepBar(total: segments.count, completed: currentSegment,
                                        label: "Part \(currentSegment + 1) of \(segments.count)")
                    }

                    // Verse with blanks
                    FlowLayout(spacing: 6) {
                        ForEach(displayWords.indices, id: \.self) { index in
                            if let blankIdx = blanks.firstIndex(where: { $0.index == index }) {
                                DropZone(
                                    correctWord: blanks[blankIdx].word,
                                    filledWord: filledWord(for: blanks[blankIdx]),
                                    showResult: showResult,
                                    isHighlighted: (selectedWordForTap != nil && blanks[blankIdx].filledID == nil) || hoveredBlankIndex == blankIdx,
                                    onTap: {
                                        if let selected = selectedWordForTap {
                                            fillBlank(at: blankIdx, with: selected)
                                            selectedWordForTap = nil
                                        } else if blanks[blankIdx].filledID != nil {
                                            // Tap filled blank to remove word
                                            unfillBlank(at: blankIdx)
                                        }
                                    }
                                )
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                dropZoneFrames[blankIdx] = geo.frame(in: .global)
                                            }
                                            .onChange(of: geo.frame(in: .global)) { newFrame in
                                                dropZoneFrames[blankIdx] = newFrame
                                            }
                                    }
                                )
                            } else {
                                Text(displayWords[index])
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                        }
                    }
                    .padding(18)
                    .practiceCard()
                    .padding(.horizontal)

                    // Word bank
                    if !showResult {
                        VStack(spacing: 12) {
                            PracticeSectionLabel(text: "Word bank")

                            FlowLayout(spacing: 10) {
                                ForEach(availableWords.filter { !$0.isUsed }) { word in
                                    DraggableWordTile(
                                        word: word,
                                        isSelected: selectedWordForTap?.id == word.id,
                                        isDragging: draggingWord?.id == word.id
                                    )
                                    .opacity(draggingWord?.id == word.id ? 0.3 : 1.0)
                                    .onTapGesture {
                                        if let nextBlank = blanks.firstIndex(where: { $0.filledID == nil }) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                                fillBlank(at: nextBlank, with: word)
                                            }
                                        }
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                                            .onChanged { value in
                                                if draggingWord == nil {
                                                    draggingWord = word
                                                    dragOrigin = value.startLocation
                                                    selectedWordForTap = nil
                                                    HapticManager.shared.lightImpact()
                                                }
                                                dragOffset = value.translation

                                                let currentPos = CGPoint(
                                                    x: value.startLocation.x + value.translation.width,
                                                    y: value.startLocation.y + value.translation.height
                                                )
                                                hoveredBlankIndex = blankIndexAt(point: currentPos)
                                            }
                                            .onEnded { value in
                                                let dropPoint = CGPoint(
                                                    x: value.startLocation.x + value.translation.width,
                                                    y: value.startLocation.y + value.translation.height
                                                )

                                                if let blankIdx = blankIndexAt(point: dropPoint) {
                                                    fillBlank(at: blankIdx, with: word)
                                                }

                                                withAnimation(.spring(response: 0.3)) {
                                                    draggingWord = nil
                                                    dragOffset = .zero
                                                    hoveredBlankIndex = nil
                                                }
                                            }
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.adaptiveBorder(colorScheme).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal)
                    }

                    if showResult {
                        VStack(spacing: 16) {
                            PracticeResultBanner(
                                icon: score == blanks.count ? "star.fill" : "checkmark",
                                tint: score == blanks.count ? Color.reforgedGold : Color.practiceGreen,
                                title: "Score: \(score)/\(blanks.count)"
                            )

                            if !isLastSegment {
                                PracticeButton(title: "Continue to Part \(currentSegment + 2)") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        currentSegment += 1
                                        setupBlanks()
                                    }
                                }
                            } else {
                                PracticeRatingRow(prompt: nil, onRate: onComplete)
                            }
                        }
                        .padding(.vertical)
                    } else {
                        PracticeButton(title: "Check Answers", enabled: allBlanksFilled) {
                            checkAnswers()
                        }
                    }
                }
                .padding(.bottom)
            }
            .scrollDisabled(draggingWord != nil)

            // Floating drag preview
            if let word = draggingWord {
                Text(word.word)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.reforgedCoral)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.reforgedCoral.opacity(0.4), radius: 8, y: 4)
                    .position(
                        x: dragOrigin.x + dragOffset.width,
                        y: dragOrigin.y + dragOffset.height
                    )
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            setupBlanks()
        }
    }

    // Find which blank zone the drag is hovering over
    func blankIndexAt(point: CGPoint) -> Int? {
        for (idx, frame) in dropZoneFrames {
            // Expand hit area slightly for easier dropping
            let expanded = frame.insetBy(dx: -10, dy: -10)
            if expanded.contains(point) && blanks[idx].filledID == nil {
                return idx
            }
        }
        return nil
    }

    var allBlanksFilled: Bool {
        blanks.allSatisfy { $0.filledID != nil }
    }

    /// The text currently shown in a blank, resolved from the placed tile's id so
    /// repeated words stay distinct.
    func filledWord(for blank: (index: Int, word: String, filledID: UUID?)) -> String? {
        guard let id = blank.filledID else { return nil }
        return availableWords.first(where: { $0.id == id })?.word
    }

    func setupBlanks() {
        let words = segments[currentSegment]
        displayWords = words

        // Drop-zone frames are keyed by blank index; clear stale frames from the
        // previous segment so blankIndexAt never resolves against out-of-range blanks.
        dropZoneFrames = [:]
        selectedWordForTap = nil
        draggingWord = nil
        dragOffset = .zero
        hoveredBlankIndex = nil
        showResult = false
        score = 0

        // Select significant words to blank (not short words like "the", "a", etc.)
        let significantIndices = words.indices.filter { index in
            let word = words[index].trimmingCharacters(in: .punctuationCharacters).lowercased()
            return word.count > 3 && !["that", "this", "with", "from", "they", "have", "been", "were", "will"].contains(word)
        }

        let blankCount = min(max(3, significantIndices.count / 2), 6)
        let selectedIndices = Array(significantIndices.shuffled().prefix(blankCount)).sorted()

        blanks = selectedIndices.map { index in
            (index: index, word: words[index].trimmingCharacters(in: .punctuationCharacters), filledID: nil)
        }

        // Shuffle words for word bank
        availableWords = blanks.map { DraggableWord(word: $0.word) }.shuffled()
    }

    func fillBlank(at index: Int, with tile: DraggableWord) {
        HapticManager.shared.magneticSnapClick()

        // If this exact tile already sits in another blank, clear it there first.
        // Matched by id, so an identical-looking tile in a different blank is left
        // alone.
        for i in blanks.indices where blanks[i].filledID == tile.id {
            blanks[i].filledID = nil
        }

        // Return this blank's previous tile (if any) to the bank.
        if let oldID = blanks[index].filledID,
           let oldIdx = availableWords.firstIndex(where: { $0.id == oldID }) {
            availableWords[oldIdx].isUsed = false
        }

        // Place this tile and mark exactly it as used.
        blanks[index].filledID = tile.id
        if let tileIdx = availableWords.firstIndex(where: { $0.id == tile.id }) {
            availableWords[tileIdx].isUsed = true
        }
    }

    func unfillBlank(at index: Int) {
        guard let filledID = blanks[index].filledID else { return }
        HapticManager.shared.lightImpact()

        blanks[index].filledID = nil

        // Mark exactly that tile available again.
        if let tileIdx = availableWords.firstIndex(where: { $0.id == filledID }) {
            availableWords[tileIdx].isUsed = false
        }
    }

    func checkAnswers() {
        // A blank is correct when the placed tile's text matches the blank's word;
        // resolved by tile id so either "love" tile satisfies either "love" blank.
        score = blanks.filter { filledWord(for: $0)?.lowercased() == $0.word.lowercased() }.count

        if score == blanks.count {
            HapticManager.shared.correctAnswer()
        } else if score > 0 {
            HapticManager.shared.lightImpact()
        } else {
            HapticManager.shared.incorrectAnswer()
        }

        withAnimation {
            showResult = true
        }
    }
}

struct DraggableWordTile: View {
    let word: DraggableWord
    var isSelected: Bool = false
    var isDragging: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Word-bank tile: a card face resting on a lip, like the Memory path's tokens.
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let face = isSelected ? Color.reforgedCoral : Color.adaptiveCardBackground(colorScheme)
        let lip = isSelected ? Color.reforgedCoral.practiceBevel() : Color.adaptiveBorder(colorScheme)

        Text(word.word)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    shape.fill(lip).offset(y: 3)
                    shape.fill(face)
                    shape.strokeBorder(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
                }
            )
            .padding(.bottom, 3)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct DropZone: View {
    let correctWord: String
    let filledWord: String?
    let showResult: Bool
    var isHighlighted: Bool = false
    var onTap: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var isCorrect: Bool {
        filledWord?.lowercased() == correctWord.lowercased()
    }

    var body: some View {
        ZStack {
            if let filled = filledWord {
                Text(filled)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(showResult ? (isCorrect ? Color.practiceGreen : .red) : Color.adaptiveText(colorScheme))
            } else {
                Text(String(repeating: "_", count: max(correctWord.count, 4)))
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .frame(minWidth: CGFloat(max(correctWord.count, 5)) * 10)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            showResult
                ? (isCorrect ? Color.practiceGreen.opacity(0.15) : Color.red.opacity(0.15))
                : (isHighlighted ? Color.reforgedGold.opacity(0.25) : Color.adaptiveBorder(colorScheme).opacity(0.6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    showResult
                        ? (isCorrect ? Color.practiceGreen : Color.red)
                        : (isHighlighted ? Color.reforgedGold : Color.clear),
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Fill in the Blank View (Typing)

struct FillInBlankView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var userInputs: [String] = []
    @State private var blanks: [(index: Int, word: String)] = []
    @State private var displayWords: [String] = []
    @State private var showResult = false
    @State private var score = 0
    @State private var hintUsed = false
    @State private var currentSegment: Int = 0
    @Environment(\.colorScheme) var colorScheme

    // Split long verses into sentence-sized chunks (~20 words each, breaking at punctuation)
    var segments: [[String]] {
        let words = normalizedVerseWords(from: verse.text)
        guard words.count > 25 else { return [words] }
        var result: [[String]] = []
        var current: [String] = []
        for word in words {
            current.append(word)
            let endsClause = word.last == "." || word.last == ";" || word.last == "!" || word.last == "?"
            if current.count >= 18 && endsClause {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var isLastSegment: Bool { currentSegment >= segments.count - 1 }
    var hasMultipleSegments: Bool { segments.count > 1 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PracticeHeader(
                    reference: verse.reference,
                    prompt: hasMultipleSegments ? nil : "Type the missing words"
                )

                if hasMultipleSegments {
                    PracticeStepBar(total: segments.count, completed: currentSegment,
                                    label: "Part \(currentSegment + 1) of \(segments.count)")
                }

                // Verse with blanks
                FlowLayout(spacing: 6) {
                    ForEach(displayWords.indices, id: \.self) { index in
                        if let blankIndex = blanks.firstIndex(where: { $0.index == index }) {
                            BlankField(
                                text: Binding(
                                    get: { userInputs.indices.contains(blankIndex) ? userInputs[blankIndex] : "" },
                                    set: { if userInputs.indices.contains(blankIndex) { userInputs[blankIndex] = $0 } }
                                ),
                                correctWord: blanks[blankIndex].word,
                                showResult: showResult,
                                colorScheme: colorScheme
                            )
                        } else {
                            Text(displayWords[index])
                                .font(.body)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                    }
                }
                .padding(18)
                .practiceCard()
                .padding(.horizontal)

                if showResult {
                    VStack(spacing: 16) {
                        PracticeResultBanner(
                            icon: score == blanks.count ? "star.fill" : "checkmark",
                            tint: score == blanks.count ? Color.reforgedGold : Color.practiceGreen,
                            title: "Score: \(score)/\(blanks.count)"
                        )

                        if !isLastSegment {
                            PracticeButton(title: "Continue to Part \(currentSegment + 2)") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    currentSegment += 1
                                    hintUsed = false
                                    setupBlanks()
                                }
                            }
                        } else {
                            PracticeRatingRow(prompt: nil, onRate: { onComplete(hintUsed ? min($0, 2) : $0) })
                        }
                    }
                    .padding(.vertical)
                } else {
                    HintButton(hintUsed: hintUsed) {
                        if let i = userInputs.indices.first(where: { userInputs[$0].isEmpty }),
                           i < blanks.count {
                            userInputs[i] = String(blanks[i].word.prefix(1))
                        }
                        hintUsed = true
                    }
                    .padding(.horizontal)

                    PracticeButton(title: "Check Answers") {
                        checkAnswers()
                    }
                }
            }
            .padding(.bottom)
        }
        .onAppear {
            setupBlanks()
        }
    }

    func setupBlanks() {
        let words = segments[currentSegment]
        displayWords = words

        let blankCount = max(2, words.count / 4)
        let indices = Array(0..<words.count).shuffled().prefix(blankCount)

        blanks = indices.sorted().map { index in
            (index: index, word: words[index].trimmingCharacters(in: .punctuationCharacters))
        }

        userInputs = Array(repeating: "", count: blanks.count)
        showResult = false
        score = 0
    }

    func checkAnswers() {
        score = 0
        for (index, blank) in blanks.enumerated() {
            if userInputs.indices.contains(index) {
                let userAnswer = userInputs[index].lowercased().trimmingCharacters(in: .whitespaces)
                let correctAnswer = blank.word.lowercased()
                if userAnswer == correctAnswer {
                    score += 1
                }
            }
        }
        withAnimation {
            showResult = true
        }
    }
}

struct BlankField: View {
    @Binding var text: String
    let correctWord: String
    let showResult: Bool
    let colorScheme: ColorScheme?

    var isCorrect: Bool {
        text.lowercased().trimmingCharacters(in: .whitespaces) == correctWord.lowercased()
    }

    var body: some View {
        TextField("___", text: $text)
            .textFieldStyle(.plain)
            .frame(width: CGFloat(max(correctWord.count, 5)) * 11)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                showResult
                    ? (isCorrect ? Color.practiceGreen.opacity(0.15) : Color.red.opacity(0.15))
                    : Color.adaptiveBorder(colorScheme).opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(showResult ? (isCorrect ? Color.practiceGreen : Color.red)
                            : Color.adaptiveTextSecondary(colorScheme).opacity(0.35), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(showResult)
    }
}

// MARK: - First Letter View
//
// Guided recall: every first-letter attempt reveals the next word. Correct words
// land green; incorrect words land red, so the verse rebuilds in order while
// preserving an honest visual record of the run.

struct FirstLetterView: View {
    private enum InputFeedback: Equatable {
        case neutral, correct, incorrect
    }

    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @EnvironmentObject private var appState: AppState
    @State private var revealedCount = 0
    @State private var attempts = 0
    @State private var correctAttempts = 0
    @State private var incorrectWordIndices: Set<Int> = []
    @State private var incorrectPulse = 0
    @State private var inputFeedback: InputFeedback = .neutral
    @State private var feedbackGeneration = 0
    @State private var showResult = false
    @State private var accuracy: Double = 0
    @State private var fieldText = ""
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    private var words: [String] { normalizedVerseWords(from: verse.text) }

    private var expectedLetters: [Character] {
        words.compactMap { $0.first.map { Character(String($0).uppercased()) } }
    }

    private var quality: Int {
        switch accuracy {
        case 0.95...:      return 5
        case 0.85..<0.95:  return 4
        case 0.65..<0.85:  return 3
        case 0.40..<0.65:  return 2
        default:           return 1
        }
    }

    private var gradeLabel: String {
        switch quality {
        case 5: return "Perfect recall"
        case 4: return "You know this well"
        case 3: return "Solid — keep reviewing"
        case 2: return "Shaky — review soon"
        default: return "Needs work — back soon"
        }
    }

    private var gradeColor: Color {
        switch quality {
        case 5: return Color.reforgedGold
        case 4, 3: return Color.practiceGreen
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PracticeHeader(
                    reference: verse.reference,
                    prompt: showResult ? nil : "Type the first letter of each word. Every letter reveals the next word."
                )

                if showResult {
                    resultSection
                } else {
                    Text("\(min(revealedCount, words.count)) / \(words.count) words")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())
                }

                // Word grid — reveals whole words as letters are committed.
                FlowLayout(spacing: 8) {
                    ForEach(words.indices, id: \.self) { index in
                        WordRevealChip(
                            word: words[index],
                            state: chipState(at: index),
                            colorScheme: colorScheme
                        )
                    }
                }
                .padding(18)
                .practiceCard()
                .padding(.horizontal)
                .contentShape(Rectangle())
                .onTapGesture { if !showResult { isFocused = true } }

                if showResult {
                    PracticeButton(title: "Continue") {
                        appState.recordFirstLetterAttempt(
                            verseId: verse.id,
                            correct: correctAttempts,
                            incorrect: attempts - correctAttempts
                        )
                        onComplete(quality)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.headline)
                            .foregroundStyle(Color.reforgedCoral)

                        TextField("Type the next first letter", text: $fieldText)
                            .focused($isFocused)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .submitLabel(.done)
                            .onChange(of: fieldText) { newValue in handleInput(newValue) }

                        if revealedCount < expectedLetters.count {
                            Text(String(expectedLetters[revealedCount]))
                                .font(.headline.monospaced())
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.35))
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(inputFeedbackColor, lineWidth: inputFeedback == .neutral ? 1 : 2)
                    }
                    .background(inputFeedbackColor.opacity(inputFeedback == .neutral ? 0 : 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .rotationEffect(.degrees(inputFeedback == .incorrect ? (incorrectPulse.isMultiple(of: 2) ? -1.2 : 1.2) : 0))
                    .padding(.horizontal)
                    .onTapGesture { isFocused = true }
                    .onAppear {
                        DispatchQueue.main.async { isFocused = true }
                    }

                    Text("Correct words appear green. A wrong letter reveals the word in red.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: revealedCount)
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: incorrectPulse)
        .animation(.easeOut(duration: 0.16), value: inputFeedback)
        .animation(.easeInOut(duration: 0.2), value: showResult)
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 14) {
            PracticeResultBanner(
                icon: quality >= 5 ? "star.fill" : (quality >= 3 ? "checkmark" : "arrow.counterclockwise"),
                tint: gradeColor,
                title: gradeLabel,
                subtitle: "\(correctAttempts) correct in \(attempts) attempt\(attempts == 1 ? "" : "s") · \(Int(accuracy * 100))%"
            )

            Text("\"\(verse.text)\"")
                .font(.body)
                .italic()
                .lineSpacing(4)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .padding(16)
                .frame(maxWidth: .infinity)
                .practiceCard(radius: 16)
                .padding(.horizontal)
        }
    }

    private func chipState(at index: Int) -> WordRevealChip.State {
        if index < revealedCount {
            return incorrectWordIndices.contains(index) ? .incorrect : .correct
        }
        return index == revealedCount ? .current : .upcoming
    }

    private var inputFeedbackColor: Color {
        switch inputFeedback {
        case .neutral: return Color.adaptiveBorder(colorScheme)
        case .correct: return Color.practiceGreen
        case .incorrect: return Color.reforgedCoral
        }
    }

    /// Treat the field as a one-key capture target. Correct letters reveal the
    /// next word; incorrect letters leave the cursor in place for another try.
    private func handleInput(_ raw: String) {
        guard !showResult, revealedCount < expectedLetters.count else { return }
        guard let letter = raw.uppercased().first(where: { $0.isLetter }) else {
            if !raw.isEmpty { fieldText = "" }
            return
        }

        // Clear immediately so every keyboard tap creates a fresh change event.
        fieldText = ""
        attempts += 1

        let wordIndex = revealedCount
        if letter == expectedLetters[wordIndex] {
            correctAttempts += 1
            showFeedback(.correct)
            HapticManager.shared.correctAnswer()
        } else {
            incorrectWordIndices.insert(wordIndex)
            incorrectPulse += 1
            showFeedback(.incorrect)
            HapticManager.shared.incorrectAnswer()
        }

        revealedCount += 1
        if revealedCount >= words.count { finish() }
    }

    private func showFeedback(_ feedback: InputFeedback) {
        feedbackGeneration += 1
        let generation = feedbackGeneration
        withAnimation(.easeOut(duration: 0.12)) { inputFeedback = feedback }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard generation == feedbackGeneration, !showResult else { return }
            withAnimation(.easeOut(duration: 0.18)) { inputFeedback = .neutral }
        }
    }

    private func finish() {
        accuracy = attempts == 0 ? 0 : Double(correctAttempts) / Double(attempts)
        isFocused = false
        withAnimation { showResult = true }
    }
}

// MARK: - Word Reveal Chip

struct WordRevealChip: View {
    enum State { case upcoming, current, correct, incorrect }
    let word: String
    let state: State
    let colorScheme: ColorScheme?

    private var placeholder: String { String(repeating: "_", count: max(word.count, 1)) }

    var body: some View {
        Text(state == .correct || state == .incorrect ? word : placeholder)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: state == .current ? 2 : 0)
            )
    }

    private var foregroundColor: Color {
        switch state {
        case .upcoming: return Color.adaptiveTextSecondary(colorScheme).opacity(0.5)
        case .current: return Color.reforgedCoral
        case .correct: return Color.practiceGreen
        case .incorrect: return .red
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .upcoming: return .clear
        case .current: return Color.reforgedCoral.opacity(0.12)
        case .correct: return Color.practiceGreen.opacity(0.14)
        case .incorrect: return Color.red.opacity(0.12)
        }
    }

    private var borderColor: Color {
        state == .current ? Color.reforgedCoral : .clear
    }
}

// MARK: - Typing Practice View

struct TypingPracticeView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var userText = ""
    @State private var showResult = false
    @State private var accuracy: Double = 0
    @State private var hintUsed = false
    @Environment(\.colorScheme) var colorScheme

    var hintWords: String {
        let words = normalizedVerseWords(from: verse.text)
        return words.prefix(3).joined(separator: " ") + "..."
    }

    private var accuracyTint: Color {
        accuracy >= 0.9 ? Color.reforgedGold : (accuracy >= 0.7 ? Color.practiceGreen : Color.orange)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PracticeHeader(reference: verse.reference, prompt: "Type the verse from memory")

                if hintUsed {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color.reforgedGold)
                        Text("Starts with: \"\(hintWords)\"")
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                TextEditor(text: $userText)
                    .frame(minHeight: 180)
                    .padding(14)
                    .scrollContentBackground(.hidden)
                    .practiceCard(radius: 18)
                    .disabled(showResult)
                    .padding(.horizontal)

                if showResult {
                    VStack(spacing: 16) {
                        PracticeResultBanner(
                            icon: accuracy >= 0.9 ? "star.fill" : "checkmark",
                            tint: accuracyTint,
                            title: "Accuracy: \(Int(accuracy * 100))%"
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            PracticeSectionLabel(text: "Correct verse")

                            Text("\"\(verse.text)\"")
                                .font(.body)
                                .italic()
                                .lineSpacing(4)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .practiceCard(radius: 16)
                        .padding(.horizontal)
                    }

                    PracticeRatingRow(prompt: nil, onRate: { onComplete(hintUsed ? min($0, 2) : $0) })
                        .padding(.vertical, 4)
                } else {
                    HintButton(hintUsed: hintUsed) {
                        withAnimation(.easeIn(duration: 0.2)) { hintUsed = true }
                    }
                    .padding(.horizontal)

                    PracticeButton(title: "Check Answer", enabled: !userText.isEmpty) {
                        calculateAccuracy()
                        withAnimation {
                            showResult = true
                        }
                    }
                }
            }
            .padding(.bottom)
        }
    }

    func calculateAccuracy() {
        let userWords = userText.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let correctWords = verse.text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        var matches = 0
        for (index, word) in userWords.enumerated() {
            if index < correctWords.count {
                let cleanUser = word.trimmingCharacters(in: .punctuationCharacters)
                let cleanCorrect = correctWords[index].trimmingCharacters(in: .punctuationCharacters)
                if cleanUser == cleanCorrect {
                    matches += 1
                }
            }
        }

        let totalWords = max(correctWords.count, userWords.count)
        accuracy = totalWords > 0 ? Double(matches) / Double(totalWords) : 0
    }
}

// MARK: - Hint Button

struct HintButton: View {
    let hintUsed: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: hintUsed ? {} : action) {
            HStack(spacing: 6) {
                Image(systemName: hintUsed ? "lightbulb.fill" : "lightbulb")
                    .font(.subheadline)
                Text(hintUsed ? "Hint used — max rating: Hard" : "Get a Hint")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(hintUsed ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(hintUsed ? Color.reforgedGold.opacity(0.12) : Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(hintUsed ? Color.reforgedGold.opacity(0.45) : Color.adaptiveBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(hintUsed)
    }
}

// MARK: - Rating Button

struct RatingButton: View {
    let label: String
    let color: Color
    let quality: Int
    let onRate: (Int) -> Void
    var subtitle: String? = nil

    var body: some View {
        Button(action: { onRate(quality) }) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle != nil ? 10 : 14)
        }
        .buttonStyle(PracticeLipButtonStyle(face: color, lip: color.practiceBevel(), depth: 4))
    }
}

// FlowLayout is defined in Views/Components/FlowLayout.swift

#if false
#Preview {
    NavigationStack {
        MemoryPracticeView(verse: MemoryVerse(
            id: "1",
            reference: "John 3:16",
            text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            esvText: nil,
            category: "Salvation",
            translation: "ESV",
            lastFetched: nil,
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        ), mode: .flashcard)
            .environmentObject(AppState.shared)
    }
}
#endif
