import SwiftUI

// MARK: - Complete the Verse Quiz

/// An 8-question quiz where the player picks the word/phrase that completes a verse.
/// XP = 75 + (correct × 30) × streak multiplier.
struct CompleteTheVerseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private let totalQuestions = 8

    // MARK: - State
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex = 0
    @State private var selectedOption: String? = nil
    @State private var lockedAnswer: String? = nil     // nil until user picks
    @State private var correctCount = 0
    @State private var isComplete = false
    @State private var xpEarned = 0
    @State private var optionShake: String? = nil

    // MARK: - XP

    var streakMultiplier: Double {
        if appState.user.streak >= 30 { return 2.0 }
        if appState.user.streak >= 7  { return 1.5 }
        return 1.0
    }

    var baseXP: Int { 75 + correctCount * 30 }

    var displayMultiplier: String {
        streakMultiplier == 1.0 ? "" : "×\(streakMultiplier == 2.0 ? "2" : "1.5")"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if isComplete {
                    completionView
                } else if questions.isEmpty {
                    ProgressView("Building quiz…")
                        .tint(Color.reforgedGold)
                } else {
                    quizView
                }
            }
            .navigationTitle("Complete the Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { buildQuiz() }
    }

    // MARK: - Quiz View

    private var quizView: some View {
        let q = questions[currentIndex]

        return VStack(spacing: 0) {
            // Progress bar
            quizProgressBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 24) {
                    // Reference badge
                    Text(q.reference)
                        .font(Font.custom("Roboto", size: 13).bold())
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.reforgedGold.opacity(0.12))
                        .clipShape(Capsule())

                    // Verse with blank
                    verseWithBlankView(q)
                        .padding(.horizontal, 24)

                    // Options
                    VStack(spacing: 10) {
                        ForEach(q.options, id: \.self) { option in
                            optionButton(option, question: q)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Next / finish button — only shown after answering
                    if lockedAnswer != nil {
                        Button {
                            advance()
                        } label: {
                            Text(currentIndex + 1 < totalQuestions ? "Next →" : "See Results")
                                .font(Font.custom("Roboto", size: 16).bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 20)
                }
            }
        }
    }

    private var quizProgressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(currentIndex + 1) of \(totalQuestions)")
                    .font(Font.custom("Roboto", size: 13))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text("\(correctCount) correct")
                    .font(Font.custom("Roboto", size: 13).bold())
                    .foregroundStyle(Color.reforgedGold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.adaptiveBorder(colorScheme)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.reforgedGold)
                        .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(totalQuestions), height: 6)
                        .animation(.spring(response: 0.4), value: currentIndex)
                }
            }
            .frame(height: 6)
        }
    }

    private func blankAnswerText(_ q: QuizQuestion) -> Text {
        let filled = lockedAnswer != nil
        let blankText = filled ? (lockedAnswer ?? "___") : "___"
        let blankColor: Color = filled
            ? (lockedAnswer == q.answer ? .green : .red)
            : .reforgedGold
        let bodyColor = Color.adaptiveText(colorScheme)
        let parts = q.verseWithBlank.components(separatedBy: "___")
        guard parts.count == 2 else {
            return Text(q.verseWithBlank)
                .font(Font.custom("LibreBaskerville-Regular", size: 17))
                .foregroundColor(bodyColor)
        }
        let t1 = Text(parts[0]).font(Font.custom("LibreBaskerville-Regular", size: 17)).foregroundColor(bodyColor)
        let t2 = Text(blankText).font(Font.custom("LibreBaskerville-Regular", size: 17).bold()).foregroundColor(blankColor)
        let t3 = Text(parts[1]).font(Font.custom("LibreBaskerville-Regular", size: 17)).foregroundColor(bodyColor)
        return t1 + t2 + t3
    }

    @ViewBuilder
    private func verseWithBlankView(_ q: QuizQuestion) -> some View {
        blankAnswerText(q)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
    }

    @ViewBuilder
    private func optionButton(_ option: String, question: QuizQuestion) -> some View {
        let isLocked = lockedAnswer != nil
        let isCorrect = option == question.answer
        let wasChosen = lockedAnswer == option

        Button {
            guard lockedAnswer == nil else { return }
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.3)) {
                lockedAnswer = option
                if isCorrect { correctCount += 1; HapticManager.shared.mediumImpact() }
                else { HapticManager.shared.errorFeedback() }
            }
        } label: {
            HStack(spacing: 12) {
                // Leading icon
                ZStack {
                    Circle()
                        .fill(optionIconBackground(isLocked: isLocked, isCorrect: isCorrect, wasChosen: wasChosen))
                        .frame(width: 30, height: 30)
                    if isLocked {
                        Image(systemName: isCorrect ? "checkmark" : (wasChosen ? "xmark" : ""))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }

                Text(option)
                    .font(Font.custom("LibreBaskerville-Regular", size: 15))
                    .foregroundStyle(optionTextColor(isLocked: isLocked, isCorrect: isCorrect, wasChosen: wasChosen))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(optionBackground(isLocked: isLocked, isCorrect: isCorrect, wasChosen: wasChosen))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(optionBorderColor(isLocked: isLocked, isCorrect: isCorrect, wasChosen: wasChosen), lineWidth: 1.5)
            )
        }
        .disabled(isLocked)
        .modifier(ShakeEffect(trigger: optionShake == option && !isCorrect))
    }

    // MARK: - Option Styling

    private func optionIconBackground(isLocked: Bool, isCorrect: Bool, wasChosen: Bool) -> Color {
        guard isLocked else { return Color.adaptiveBorder(colorScheme) }
        if isCorrect { return .green }
        if wasChosen { return .red }
        return Color.adaptiveBorder(colorScheme)
    }

    private func optionTextColor(isLocked: Bool, isCorrect: Bool, wasChosen: Bool) -> Color {
        guard isLocked else { return Color.adaptiveText(colorScheme) }
        if isCorrect { return .green }
        if wasChosen { return .red }
        return Color.adaptiveTextSecondary(colorScheme)
    }

    private func optionBackground(isLocked: Bool, isCorrect: Bool, wasChosen: Bool) -> Color {
        guard isLocked else { return Color.adaptiveCardBackground(colorScheme) }
        if isCorrect { return Color.green.opacity(0.08) }
        if wasChosen { return Color.red.opacity(0.08) }
        return Color.adaptiveCardBackground(colorScheme)
    }

    private func optionBorderColor(isLocked: Bool, isCorrect: Bool, wasChosen: Bool) -> Color {
        guard isLocked else { return Color.adaptiveBorder(colorScheme) }
        if isCorrect { return .green.opacity(0.6) }
        if wasChosen { return .red.opacity(0.6) }
        return Color.adaptiveBorder(colorScheme)
    }

    // MARK: - Completion

    private var completionView: some View {
        let perfect = correctCount == totalQuestions

        return VStack(spacing: 28) {
            Spacer()

            Image(systemName: perfect ? "crown.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(perfect ? Color.reforgedGold : Color.green)

            VStack(spacing: 8) {
                Text(perfect ? "Perfect Score!" : "Quiz Complete")
                    .font(Font.custom("LibreBaskerville-Regular", size: 28).bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("\(correctCount) of \(totalQuestions) correct")
                    .font(Font.custom("Roboto", size: 15))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            // XP card
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(Color.reforgedGold)
                    Text("+\(xpEarned) XP earned")
                        .font(Font.custom("Roboto", size: 20).bold())
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                Text("75 base + \(correctCount) × 30 XP\(displayMultiplier.isEmpty ? "" : " · \(displayMultiplier) streak bonus")")
                    .font(Font.custom("Roboto", size: 12))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                if streakMultiplier > 1.0 {
                    Text("\(appState.user.streak)-day streak · \(displayMultiplier) multiplier")
                        .font(Font.custom("Roboto", size: 13))
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Font.custom("Roboto", size: 16).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button("Try Again") {
                buildQuiz()
                isComplete = false
            }
            .font(Font.custom("Roboto", size: 15))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Spacer()
        }
    }

    // MARK: - Navigation

    private func advance() {
        if currentIndex + 1 < totalQuestions {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
                lockedAnswer = nil
                selectedOption = nil
            }
        } else {
            finalizeQuiz()
        }
    }

    private func finalizeQuiz() {
        let raw = 75 + correctCount * 30
        xpEarned = Int(Double(raw) * streakMultiplier)
        appState.addXP(raw, source: "complete_verse_quiz")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            isComplete = true
        }
    }

    // MARK: - Quiz Builder

    private func buildQuiz() {
        currentIndex = 0
        correctCount = 0
        lockedAnswer = nil
        selectedOption = nil
        isComplete = false

        let pool = buildVersePool()
        guard pool.count >= 4 else { questions = []; return }

        var builtQuestions: [QuizQuestion] = []
        let shuffled = pool.shuffled()

        for verse in shuffled {
            if builtQuestions.count == totalQuestions { break }
            guard let q = makeQuestion(from: verse, allVerses: pool) else { continue }
            builtQuestions.append(q)
        }

        questions = builtQuestions
    }

    private func buildVersePool() -> [VerseItem] {
        var pool: [VerseItem] = []
        for mv in appState.memoryVerses where !mv.text.isEmpty {
            pool.append(VerseItem(id: mv.reference, reference: mv.reference, text: mv.text))
        }
        if pool.count < totalQuestions {
            let suggested = SuggestedVersesData.allVerses
                .filter { sv in !pool.contains { $0.reference == sv.reference } }
                .shuffled()
            for sv in suggested {
                pool.append(VerseItem(id: sv.reference, reference: sv.reference, text: sv.text))
            }
        }
        return pool
    }

    /// Creates a fill-in-the-blank question by blanking a meaningful phrase from the verse.
    private func makeQuestion(from verse: VerseItem, allVerses: [VerseItem]) -> QuizQuestion? {
        let words = verse.text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard words.count >= 6 else { return nil }

        // Pick a 1-3 word phrase to blank (skip the first 2 words)
        let phraseLen = words.count > 10 ? Int.random(in: 1...3) : 1
        let maxStart = words.count - phraseLen - 1
        guard maxStart >= 2 else { return nil }
        let startIdx = Int.random(in: 2...maxStart)

        let answer = words[startIdx..<(startIdx + phraseLen)]
            .joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters)

        guard answer.count >= 2 else { return nil }

        // Build the verse with the blank
        var modified = words
        for i in startIdx..<(startIdx + phraseLen) {
            modified[i] = i == startIdx ? "___" : ""
        }
        let verseWithBlank = modified.filter { !$0.isEmpty }.joined(separator: " ")

        // Collect distractors from other verses
        let otherAnswers = allVerses
            .filter { $0.id != verse.id }
            .compactMap { v -> String? in
                let ws = v.text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard ws.count > phraseLen + 2 else { return nil }
                let si = Int.random(in: 2...(ws.count - phraseLen - 1))
                let phrase = ws[si..<(si + phraseLen)]
                    .joined(separator: " ")
                    .trimmingCharacters(in: .punctuationCharacters)
                return phrase.count >= 2 && phrase.lowercased() != answer.lowercased() ? phrase : nil
            }

        var options = Array(Set(otherAnswers).prefix(3))
        guard options.count >= 3 else { return nil }
        options.append(answer)
        options = options.shuffled()

        return QuizQuestion(
            reference: verse.reference,
            verseWithBlank: verseWithBlank,
            answer: answer,
            options: options
        )
    }
}

// MARK: - Data Models

private struct QuizQuestion {
    let reference: String
    let verseWithBlank: String
    let answer: String
    let options: [String]
}

private struct VerseItem {
    let id: String
    let reference: String
    let text: String
}

// ShakeEffect is defined in MatchingGameView.swift
