import SwiftUI

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
            Group {
                switch mode {
                case .flashcard:
                    FlashcardPracticeView(verse: verse, onComplete: handleComplete)
                case .tapToReveal:
                    TapToRevealView(verse: verse, onComplete: handleComplete)
                case .dragAndDrop:
                    DragAndDropView(verse: verse, onComplete: handleComplete)
                case .fillInBlank:
                    FillInBlankView(verse: verse, onComplete: handleComplete)
                case .firstLetter:
                    FirstLetterView(verse: verse, onComplete: handleComplete)
                case .typing:
                    TypingPracticeView(verse: verse, onComplete: handleComplete)
                }
            }
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

        // Show celebration
        withAnimation {
            showCelebration = true
        }
    }
}

// MARK: - Flashcard Practice View (Tap-to-Flip)

struct FlashcardPracticeView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var isFlipped = false
    @State private var rotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Flipping Card
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
            .onTapGesture {
                // Haptic feedback for card flip
                HapticManager.shared.cardFlip()

                // Scale animation for tactile feel
                withAnimation(.easeInOut(duration: 0.1)) {
                    cardScale = 0.95
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    rotation += 180
                    isFlipped.toggle()
                }

                // Return to normal scale
                withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                    cardScale = 1.0
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
                        RatingButton(label: "Again", color: .red, quality: 1, onRate: { quality in
                            HapticManager.shared.incorrectAnswer()
                            onComplete(quality)
                        })
                        RatingButton(label: "Hard", color: .orange, quality: 2, onRate: { quality in
                            HapticManager.shared.lightImpact()
                            onComplete(quality)
                        })
                        RatingButton(label: "Good", color: .green, quality: 4, onRate: { quality in
                            HapticManager.shared.correctAnswer()
                            onComplete(quality)
                        })
                        RatingButton(label: "Easy", color: .blue, quality: 5, onRate: { quality in
                            HapticManager.shared.correctAnswer()
                            onComplete(quality)
                        })
                    }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct FlashcardFront: View {
    let verse: MemoryVerse
    let colorScheme: ColorScheme?

    // First letters hint
    var firstLetters: String {
        verse.text.components(separatedBy: " ")
            .prefix(8)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined(separator: " ")
        + (verse.text.components(separatedBy: " ").count > 8 ? " ..." : "")
    }

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
            .padding(.vertical, 16)

            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                Text("Tap to flip")
                    .font(.caption)
            }
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .padding(28)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.reforgedNavy.opacity(0.15), radius: 20, y: 10)
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
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
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
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Color.reforgedGold.opacity(0.5))
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
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<phrases.count, id: \.self) { index in
                    Circle()
                        .fill(index < revealedPhrases ? Color.reforgedGold : Color.adaptiveBorder(colorScheme))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top)

            Text(verse.reference)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))

            Spacer()

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
                        // Next phrase to reveal (hidden)
                        HStack(spacing: 4) {
                            ForEach(0..<phrases[index].components(separatedBy: " ").count, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.reforgedNavy.opacity(0.2))
                                    .frame(width: 40, height: 24)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
            .padding(.horizontal)

            Spacer()

            if showRating {
                // Rating buttons
                VStack(spacing: 12) {
                    Text("How well did you recall?")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    HStack(spacing: 10) {
                        RatingButton(label: "Again", color: .red, quality: 1, onRate: onComplete)
                        RatingButton(label: "Hard", color: .orange, quality: 2, onRate: onComplete)
                        RatingButton(label: "Good", color: .green, quality: 4, onRate: onComplete)
                        RatingButton(label: "Easy", color: .blue, quality: 5, onRate: onComplete)
                    }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Tap to reveal button
                Button(action: revealNextPhrase) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                        Text(revealedPhrases == 0 ? "Tap to Start" : "Reveal Next")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
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
    @State private var blanks: [(index: Int, word: String, filled: String?)] = []
    @State private var availableWords: [DraggableWord] = []
    @State private var displayWords: [String] = []
    @State private var showResult = false
    @State private var score = 0
    @State private var draggedWord: DraggableWord?
    @State private var selectedWordForTap: DraggableWord? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(verse.reference)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.top)

                Text("Tap a word, then tap a blank to place it")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                // Verse with blanks
                FlowLayout(spacing: 6) {
                    ForEach(displayWords.indices, id: \.self) { index in
                        if let blankIdx = blanks.firstIndex(where: { $0.index == index }) {
                            DropZone(
                                correctWord: blanks[blankIdx].word,
                                filledWord: blanks[blankIdx].filled,
                                showResult: showResult,
                                isHighlighted: selectedWordForTap != nil && blanks[blankIdx].filled == nil,
                                onDrop: { word in
                                    fillBlank(at: blankIdx, with: word)
                                    selectedWordForTap = nil
                                },
                                onTap: {
                                    if let selected = selectedWordForTap {
                                        fillBlank(at: blankIdx, with: selected.word)
                                        selectedWordForTap = nil
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
                .padding()
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Tappable word bank
                if !showResult {
                    VStack(spacing: 12) {
                        Text("Word Bank")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        FlowLayout(spacing: 10) {
                            ForEach(availableWords) { word in
                                if !word.isUsed {
                                    DraggableWordTile(word: word, isSelected: selectedWordForTap?.id == word.id)
                                        .onTapGesture {
                                            HapticManager.shared.lightImpact()
                                            if selectedWordForTap?.id == word.id {
                                                selectedWordForTap = nil
                                            } else {
                                                selectedWordForTap = word
                                            }
                                        }
                                        .onDrag {
                                            draggedWord = word
                                            return NSItemProvider(object: word.word as NSString)
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.adaptiveBorder(colorScheme).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                if showResult {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: score == blanks.count ? "star.fill" : "checkmark.circle")
                                .foregroundStyle(score == blanks.count ? Color.reforgedGold : Color.green)
                            Text("Score: \(score)/\(blanks.count)")
                                .font(.headline)
                        }

                        HStack(spacing: 10) {
                            RatingButton(label: "Again", color: .red, quality: 1, onRate: onComplete)
                            RatingButton(label: "Hard", color: .orange, quality: 2, onRate: onComplete)
                            RatingButton(label: "Good", color: .green, quality: 4, onRate: onComplete)
                            RatingButton(label: "Easy", color: .blue, quality: 5, onRate: onComplete)
                        }
                    }
                    .padding()
                } else {
                    Button("Check Answers") {
                        checkAnswers()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(allBlanksFilled ? Color.reforgedNavy : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .disabled(!allBlanksFilled)
                }
            }
            .padding(.bottom)
        }
        .onAppear {
            setupBlanks()
        }
    }

    var allBlanksFilled: Bool {
        blanks.allSatisfy { $0.filled != nil }
    }

    func setupBlanks() {
        let words = verse.text.components(separatedBy: " ")
        displayWords = words

        // Select significant words to blank (not short words like "the", "a", etc.)
        let significantIndices = words.indices.filter { index in
            let word = words[index].trimmingCharacters(in: .punctuationCharacters).lowercased()
            return word.count > 3 && !["that", "this", "with", "from", "they", "have", "been", "were", "will"].contains(word)
        }

        let blankCount = min(max(3, significantIndices.count / 2), 6)
        let selectedIndices = Array(significantIndices.shuffled().prefix(blankCount)).sorted()

        blanks = selectedIndices.map { index in
            (index: index, word: words[index].trimmingCharacters(in: .punctuationCharacters), filled: nil)
        }

        // Shuffle words for word bank
        availableWords = blanks.map { DraggableWord(word: $0.word) }.shuffled()
    }

    func fillBlank(at index: Int, with word: String) {
        // Haptic feedback for drop
        HapticManager.shared.lightImpact()

        // Remove word from previous blank if it was used
        for i in blanks.indices {
            if blanks[i].filled == word {
                blanks[i].filled = nil
            }
        }

        blanks[index].filled = word

        // Mark word as used
        if let wordIndex = availableWords.firstIndex(where: { $0.word == word && !$0.isUsed }) {
            availableWords[wordIndex].isUsed = true
        }
    }

    func checkAnswers() {
        score = blanks.filter { $0.filled?.lowercased() == $0.word.lowercased() }.count

        // Haptic feedback based on score
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(word.word)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : Color.adaptiveNavyText(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.reforgedNavy : Color.reforgedGold.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.reforgedNavy : Color.reforgedGold, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct DropZone: View {
    let correctWord: String
    let filledWord: String?
    let showResult: Bool
    var isHighlighted: Bool = false
    let onDrop: (String) -> Void
    var onTap: (() -> Void)? = nil
    @State private var isTargeted = false
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
                    .foregroundStyle(showResult ? (isCorrect ? .green : .red) : Color.adaptiveNavyText(colorScheme))
            } else {
                Text(String(repeating: "_", count: max(correctWord.count, 4)))
                    .font(.body)
            }
        }
        .frame(minWidth: CGFloat(max(correctWord.count, 5)) * 10)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            showResult
                ? (isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                : (isTargeted || isHighlighted ? Color.reforgedGold.opacity(0.3) : Color.reforgedNavy.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    showResult
                        ? (isCorrect ? Color.green : Color.red)
                        : (isTargeted || isHighlighted ? Color.reforgedGold : Color.reforgedNavy.opacity(0.3)),
                    lineWidth: (isTargeted || isHighlighted) ? 2 : 1
                )
        )
        .onTapGesture {
            onTap?()
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let word = object as? String {
                    DispatchQueue.main.async {
                        onDrop(word)
                    }
                }
            }
            return true
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(verse.reference)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.top)

                Text("Type the missing words")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

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
                .padding()
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if showResult {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: score == blanks.count ? "star.fill" : "checkmark.circle")
                                .foregroundStyle(score == blanks.count ? Color.reforgedGold : Color.green)
                            Text("Score: \(score)/\(blanks.count)")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }

                        HStack(spacing: 10) {
                            RatingButton(label: "Again", color: .red, quality: 1, onRate: onComplete)
                            RatingButton(label: "Hard", color: .orange, quality: 2, onRate: onComplete)
                            RatingButton(label: "Good", color: .green, quality: 4, onRate: onComplete)
                            RatingButton(label: "Easy", color: .blue, quality: 5, onRate: onComplete)
                        }
                    }
                    .padding()
                } else {
                    Button("Check Answers") {
                        checkAnswers()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .onAppear {
            setupBlanks()
        }
    }

    func setupBlanks() {
        let words = verse.text.components(separatedBy: " ")
        displayWords = words

        let blankCount = max(2, words.count / 4)
        let indices = Array(0..<words.count).shuffled().prefix(blankCount)

        blanks = indices.sorted().map { index in
            (index: index, word: words[index].trimmingCharacters(in: .punctuationCharacters))
        }

        userInputs = Array(repeating: "", count: blanks.count)
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
                    ? (isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    : Color.adaptiveBorder(colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(showResult ? (isCorrect ? Color.green : Color.red) : Color.reforgedNavy, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .disabled(showResult)
    }
}

// MARK: - First Letter View

struct FirstLetterView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var userText = ""
    @State private var showResult = false
    @Environment(\.colorScheme) var colorScheme

    var firstLetters: String {
        verse.text.components(separatedBy: " ")
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(verse.reference)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.top)

                VStack(spacing: 8) {
                    Text("First letters hint:")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(firstLetters)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.reforgedGold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.reforgedNavy.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                TextEditor(text: $userText)
                    .frame(minHeight: 150)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                    .disabled(showResult)
                    .padding(.horizontal)

                if showResult {
                    VStack(spacing: 12) {
                        Text("Correct verse:")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        Text("\"\(verse.text)\"")
                            .font(.body)
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        RatingButton(label: "Again", color: .red, quality: 1, onRate: onComplete)
                        RatingButton(label: "Hard", color: .orange, quality: 2, onRate: onComplete)
                        RatingButton(label: "Good", color: .green, quality: 4, onRate: onComplete)
                        RatingButton(label: "Easy", color: .blue, quality: 5, onRate: onComplete)
                    }
                    .padding()
                } else {
                    Button("Check Answer") {
                        withAnimation {
                            showResult = true
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(userText.isEmpty ? Color.gray : Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .disabled(userText.isEmpty)
                }
            }
            .padding(.bottom)
        }
    }
}

// MARK: - Typing Practice View

struct TypingPracticeView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void
    @State private var userText = ""
    @State private var showResult = false
    @State private var accuracy: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(verse.reference)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.top)

                Text("Type the verse from memory")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                TextEditor(text: $userText)
                    .frame(minHeight: 180)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                    .disabled(showResult)
                    .padding(.horizontal)

                if showResult {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: accuracy >= 0.9 ? "star.fill" : "checkmark.circle")
                                .foregroundStyle(accuracy >= 0.9 ? Color.reforgedGold : (accuracy >= 0.7 ? Color.green : Color.orange))
                            Text("Accuracy: \(Int(accuracy * 100))%")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }

                        VStack(spacing: 8) {
                            Text("Correct verse:")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                            Text("\"\(verse.text)\"")
                                .font(.body)
                                .italic()
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        RatingButton(label: "Again", color: .red, quality: 1, onRate: onComplete)
                        RatingButton(label: "Hard", color: .orange, quality: 2, onRate: onComplete)
                        RatingButton(label: "Good", color: .green, quality: 4, onRate: onComplete)
                        RatingButton(label: "Easy", color: .blue, quality: 5, onRate: onComplete)
                    }
                    .padding()
                } else {
                    Button("Check Answer") {
                        calculateAccuracy()
                        withAnimation {
                            showResult = true
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(userText.isEmpty ? Color.gray : Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .disabled(userText.isEmpty)
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

// MARK: - Rating Button

struct RatingButton: View {
    let label: String
    let color: Color
    let quality: Int
    let onRate: (Int) -> Void

    var body: some View {
        Button(action: { onRate(quality) }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// FlowLayout is defined in Views/Components/FlowLayout.swift

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
