import SwiftUI

// MARK: - Recite test

/// The "can you write it out?" test. The member recites the whole verse from memory,
/// either as first letters (fast on a phone) or full words. No hints are offered.
/// A score of `RecitationProgress.passThreshold` or more passes.
struct RecitationTestView: View {
    let verse: MemoryVerse
    /// Scheduled reviews count only the first attempt; a retry after seeing the
    /// answer is practice and is not reported to `onAttempt`.
    var firstAttemptOnly = false
    /// Whether a counted attempt is a scheduled review (affects the mastery preview).
    var scheduled = false
    /// Called for each counted attempt with its score and input method.
    let onAttempt: (Double, RecitationMethod) -> Void
    /// Called when the member leaves the test. `passed` reflects the last attempt.
    let onDone: (_ passed: Bool, _ accuracy: Double) -> Void

    private enum Phase: Equatable { case input, result }

    @AppStorage("memory.reciteMethod") private var methodRaw = RecitationMethod.firstLetters.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase = .input
    @State private var attemptCount = 0
    @State private var accuracy: Double = 0
    @State private var fullWordsResult: RecitationGrader.Result?

    // First-letter state
    @State private var revealed = 0
    @State private var wrongIndices: Set<Int> = []
    @State private var letterField = ""
    @State private var wrongPulse = 0

    // Full-word state
    @State private var typed = ""

    // Mastery preview: where the verse stood before the last counted attempt, and after.
    @State private var masteryBefore: Int?
    @State private var projected: MemoryVerse?

    @FocusState private var focused: Bool

    private var method: RecitationMethod { RecitationMethod(rawValue: methodRaw) ?? .firstLetters }
    private var words: [String] { RecitationGrader.words(verse.text) }
    private var passed: Bool { accuracy >= RecitationProgress.passThreshold }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PracticeHeader(
                    reference: verse.reference,
                    prompt: phase == .input
                        ? "Recite the whole verse from memory. Score \(Int(RecitationProgress.passThreshold * 100))% or higher to pass."
                        : nil
                )

                if phase == .input {
                    methodPicker
                    if method == .firstLetters { firstLetterInput } else { fullWordsInput }
                } else {
                    resultView
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.2), value: phase)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: revealed)
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: wrongPulse)
    }

    // MARK: Input

    private var methodPicker: some View {
        Picker("Input", selection: $methodRaw) {
            ForEach(RecitationMethod.allCases, id: \.rawValue) { m in
                Text(m.displayName).tag(m.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .disabled(revealed > 0 || !typed.isEmpty)
    }

    private var firstLetterInput: some View {
        VStack(spacing: 14) {
            Text("\(revealed) / \(words.count) words")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.reforgedGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())

            FlowLayout(spacing: 6) {
                ForEach(words.indices, id: \.self) { i in
                    RecitedWordChip(word: words[i], state: chipState(i))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .practiceCard()
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .foregroundStyle(Color.reforgedCoral)
                TextField("First letter of the next word", text: $letterField)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .onChange(of: letterField) { handleLetter($0) }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .rotationEffect(.degrees(wrongPulse.isMultiple(of: 2) ? 0 : 1.2))
            .padding(.horizontal)
            .onAppear { DispatchQueue.main.async { focused = true } }

            Text("A wrong letter shows that word in red and moves on. No hints in a test.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var fullWordsInput: some View {
        VStack(spacing: 14) {
            TextEditor(text: $typed)
                .focused($focused)
                .autocorrectionDisabled(true)   // also turns off next-word suggestions
                .textInputAutocapitalization(.sentences)
                .frame(minHeight: 180)
                .padding(14)
                .scrollContentBackground(.hidden)
                .practiceCard(radius: 18)
                .padding(.horizontal)
                .onAppear { DispatchQueue.main.async { focused = true } }

            PracticeButton(title: "Check", enabled: !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                let result = RecitationGrader.grade(expected: verse.text, typed: typed)
                fullWordsResult = result
                finish(accuracy: result.accuracy)
            }
        }
    }

    private func chipState(_ i: Int) -> RecitedWordChip.State {
        if i < revealed { return wrongIndices.contains(i) ? .wrong : .right }
        return i == revealed ? .current : .hidden
    }

    private func handleLetter(_ raw: String) {
        guard phase == .input, revealed < words.count else { return }
        guard let ch = raw.lowercased().first(where: { $0.isLetter || $0.isNumber }) else {
            if !raw.isEmpty { letterField = "" }
            return
        }
        letterField = ""
        let target = RecitationGrader.key(words[revealed]).first
        if ch == target {
            HapticManager.shared.correctAnswer()
        } else {
            wrongIndices.insert(revealed)
            wrongPulse += 1
            HapticManager.shared.incorrectAnswer()
        }
        revealed += 1
        if revealed >= words.count {
            let correct = words.count - wrongIndices.count
            finish(accuracy: RecitationGrader.gradeFirstLetters(wordCount: words.count, correct: correct))
        }
    }

    private func finish(accuracy: Double) {
        self.accuracy = accuracy
        attemptCount += 1
        if !firstAttemptOnly || attemptCount == 1 {
            let current = projected ?? verse
            masteryBefore = current.mastery.percent
            projected = current.applyingRecitation(accuracy: accuracy, method: method, scheduled: scheduled)
            onAttempt(accuracy, method)
        }
        focused = false
        if accuracy >= RecitationProgress.passThreshold {
            HapticManager.shared.lessonStageComplete()
        }
        withAnimation { phase = .result }
    }

    private func retry() {
        revealed = 0
        wrongIndices = []
        letterField = ""
        typed = ""
        fullWordsResult = nil
        withAnimation { phase = .input }
    }

    // MARK: Result

    private var resultTitle: String {
        if passed { return accuracy >= 0.999 ? "Perfect recall" : "Passed" }
        return accuracy >= 0.8 ? "So close" : "Not yet"
    }

    private var resultSubtitle: String {
        let pct = Int((accuracy * 100).rounded())
        if passed { return "\(pct)% from memory" }
        let needed = Int(RecitationProgress.passThreshold * 100)
        return "\(pct)%. \(needed)% passes."
    }

    private var resultTint: Color {
        passed ? .reforgedGold : (accuracy >= 0.8 ? .orange : .reforgedCoral)
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            PracticeResultBanner(
                icon: passed ? "checkmark.seal.fill" : "arrow.counterclockwise",
                tint: resultTint,
                title: resultTitle,
                subtitle: resultSubtitle
            )

            if let projected, let before = masteryBefore {
                masteryGain(projected.mastery, before: before)
            }

            VStack(alignment: .leading, spacing: 10) {
                PracticeSectionLabel(text: passed ? "Your recitation" : "Where it slipped")
                FlowLayout(spacing: 6) {
                    if let result = fullWordsResult {
                        ForEach(result.marks.indices, id: \.self) { i in
                            DiffWordChip(mark: result.marks[i])
                        }
                    } else {
                        ForEach(words.indices, id: \.self) { i in
                            RecitedWordChip(word: words[i], state: wrongIndices.contains(i) ? .wrong : .right)
                        }
                    }
                }
                if !passed { diffLegend }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .practiceCard(radius: 16)
            .padding(.horizontal)

            if passed {
                PracticeButton(title: "Continue", tint: .practiceGreen) { onDone(true, accuracy) }
            } else {
                PracticeButton(title: "Try again", tint: .reforgedGold) { retry() }
                Button("Continue for now") { onDone(false, accuracy) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                if firstAttemptOnly && attemptCount > 1 {
                    Text("Your first try counts for this review. Retries are practice.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }

    /// "+N% toward Mastered": the bar fills from the old score so the gain is felt.
    private func masteryGain(_ score: MasteryScore, before: Int) -> some View {
        let gain = score.percent - before
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PracticeSectionLabel(text: "Toward mastered")
                Spacer()
                if gain > 0 {
                    Text("+\(gain)%")
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            MasteryMeter(score: score, from: before)
            Text(score.nextStep)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceCard(radius: 16)
        .padding(.horizontal)
    }

    private var diffLegend: some View {
        HStack(spacing: 14) {
            if fullWordsResult != nil {
                legendItem(color: .practiceGreen, text: "Missing word")
                legendItem(color: .red, text: "You typed")
            } else {
                legendItem(color: .red, text: "Wrong letter")
            }
        }
        .font(.caption)
        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

/// One word in a first-letter recitation: hidden behind a uniform blank (so word
/// length gives nothing away) until the member types its first letter.
struct RecitedWordChip: View {
    enum State { case hidden, current, right, wrong }
    let word: String
    let state: State
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(state == .right || state == .wrong ? word : "\u{2007}\u{2007}\u{2007}\u{2007}")
            .font(.body.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(state == .current ? Color.reforgedCoral : .clear, lineWidth: 2)
            )
    }

    private var fg: Color {
        switch state {
        case .hidden, .current: return .clear
        case .right: return Color.adaptiveText(colorScheme)
        case .wrong: return .red
        }
    }

    private var bg: Color {
        switch state {
        case .hidden: return Color.adaptiveBorder(colorScheme).opacity(0.6)
        case .current: return Color.reforgedCoral.opacity(0.12)
        case .right: return .clear
        case .wrong: return Color.red.opacity(0.12)
        }
    }
}

/// One aligned word in a full-word recitation result.
struct DiffWordChip: View {
    let mark: RecitationGrader.Mark
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch mark {
        case .correct(let w):
            plain(w)
        case .typo(let expected, _):
            plain(expected).underline(pattern: .dot, color: .orange)
        case .wrong(let expected, let typed):
            HStack(spacing: 3) {
                struck(typed)
                added(expected)
            }
        case .missing(let w):
            added(w)
        case .extra(let w):
            struck(w)
        }
    }

    private func plain(_ w: String) -> Text {
        Text(w).foregroundColor(Color.adaptiveText(colorScheme))
    }

    private func struck(_ w: String) -> some View {
        Text(w)
            .strikethrough(true, color: .red)
            .foregroundStyle(Color.red)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func added(_ w: String) -> some View {
        Text(w)
            .fontWeight(.semibold)
            .foregroundStyle(Color.practiceGreen)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.practiceGreen.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Recite test sheet ("Test me")

/// Stand-alone Recite test for any verse in the library. Counts toward Memorized
/// (and can mark a verse Needs work) but never changes the review schedule.
struct RecitationTestSheet: View {
    let verse: MemoryVerse
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            RecitationTestView(
                verse: verse,
                onAttempt: { accuracy, method in
                    appState.recordRecitation(verseId: verse.id, accuracy: accuracy,
                                              method: method, scheduled: false)
                },
                onDone: { _, _ in dismiss() }
            )
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Recite test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Status badge

struct VerseStatusBadge: View {
    let status: VerseMemoryStatus
    var compact = false
    @Environment(\.colorScheme) private var colorScheme

    static func tint(_ status: VerseMemoryStatus, _ scheme: ColorScheme?) -> Color {
        switch status {
        case .notYetTested: return Color.adaptiveTextSecondary(scheme)
        case .learning: return Color.adaptiveNavyText(scheme)
        case .memorized, .mastered: return .reforgedGold
        case .needsWork: return .reforgedCoral
        }
    }

    var body: some View {
        let tint = Self.tint(status, colorScheme)
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            if !compact { Text(status.displayName) }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())
        .accessibilityLabel(status.displayName)
    }
}

// MARK: - Lesson drills

/// Lesson warm-ups modelled on the classic first-letter method:
/// - `hideEveryOther == false`: the verse is shown faded; type each word's first letter.
/// - `hideEveryOther == true`: every other word is hidden; recall those from memory.
/// A wrong letter shakes and lets you try again; after two misses the word is shown.
struct LetterDrillView: View {
    let verse: MemoryVerse
    let hideEveryOther: Bool
    let onComplete: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var index = 0
    @State private var missesOnWord = 0
    @State private var firstTryCorrect = 0
    @State private var missedWords: Set<Int> = []
    @State private var field = ""
    @State private var pulse = 0
    @FocusState private var focused: Bool

    private var words: [String] { RecitationGrader.words(verse.text) }

    private func isHidden(_ i: Int) -> Bool { hideEveryOther && i % 2 == 1 }

    private var quality: Int {
        let acc = words.isEmpty ? 0 : Double(firstTryCorrect) / Double(words.count)
        switch acc {
        case 0.95...: return 5
        case 0.85..<0.95: return 4
        case 0.65..<0.85: return 3
        case 0.4..<0.65: return 2
        default: return 1
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PracticeHeader(
                    reference: verse.reference,
                    prompt: hideEveryOther
                        ? "Every other word is hidden. Type the first letter of each word."
                        : "Type the first letter of each word as you read."
                )

                FlowLayout(spacing: 6) {
                    ForEach(words.indices, id: \.self) { i in
                        drillChip(i)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .practiceCard()
                .padding(.horizontal)
                .contentShape(Rectangle())
                .onTapGesture { focused = true }

                if index < words.count {
                    TextField("Next first letter", text: $field)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .onChange(of: field) { handle($0) }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                        .rotationEffect(.degrees(pulse.isMultiple(of: 2) ? 0 : 1.2))
                        .padding(.horizontal)
                        .onAppear { DispatchQueue.main.async { focused = true } }
                } else {
                    PracticeButton(title: "Continue", tint: .practiceGreen) { onComplete(quality) }
                }
            }
            .padding(.bottom, 24)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: index)
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: pulse)
    }

    @ViewBuilder
    private func drillChip(_ i: Int) -> some View {
        let done = i < index
        let current = i == index
        let hidden = isHidden(i) && !done
        Text(hidden ? "\u{2007}\u{2007}\u{2007}\u{2007}" : words[i])
            .font(.body.weight(.semibold))
            .foregroundStyle(
                done ? (missedWords.contains(i) ? Color.red : Color.adaptiveText(colorScheme))
                     : Color.adaptiveTextSecondary(colorScheme).opacity(hidden ? 0 : 0.45)
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                hidden ? Color.adaptiveBorder(colorScheme).opacity(0.6)
                       : (current ? Color.reforgedCoral.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(current ? Color.reforgedCoral : .clear, lineWidth: 2)
            )
    }

    private func handle(_ raw: String) {
        guard index < words.count else { return }
        guard let ch = raw.lowercased().first(where: { $0.isLetter || $0.isNumber }) else {
            if !raw.isEmpty { field = "" }
            return
        }
        field = ""
        if ch == RecitationGrader.key(words[index]).first {
            if missesOnWord == 0 { firstTryCorrect += 1 }
            HapticManager.shared.correctAnswer()
            advance()
        } else {
            missesOnWord += 1
            pulse += 1
            HapticManager.shared.incorrectAnswer()
            if missesOnWord >= 2 {
                missedWords.insert(index)
                advance()
            }
        }
    }

    private func advance() {
        missesOnWord = 0
        index += 1
        if index >= words.count { focused = false }
    }
}

// MARK: - Mastery meter

/// Horizontal mastery bar with a dot at each milestone. When `from` is set, the bar
/// starts there and fills to the current score (with a counting label) so the member
/// sees exactly how much a recite moved them.
struct MasteryMeter: View {
    let score: MasteryScore
    var from: Int? = nil
    var showLabel = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = -1

    private var target: Double { Double(score.percent) }
    private var fillTint: Color { score.percent >= 100 ? Color(red: 0.20, green: 0.65, blue: 0.40) : .reforgedGold }

    var body: some View {
        let value = shown < 0 ? target : shown
        HStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.adaptiveBorder(colorScheme))
                    Capsule().fill(fillTint)
                        .frame(width: max(8, w * value / 100))
                    ForEach(score.milestones.dropFirst()) { m in
                        let on = Double(m.points) <= value + 0.5
                        Circle()
                            .fill(on ? Color.white : Color.adaptiveCardBackground(colorScheme))
                            .overlay(Circle().stroke(on ? fillTint : Color.adaptiveTextSecondary(colorScheme).opacity(0.35), lineWidth: 1.5))
                            .frame(width: 7, height: 7)
                            .position(x: min(w - 4, w * Double(m.points) / 100 - 4), y: 5)
                    }
                }
            }
            .frame(height: 10)

            if showLabel {
                Text("\(Int(value.rounded()))%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(score.percent >= 100 ? fillTint : Color.adaptiveText(colorScheme))
                    .frame(minWidth: 42, alignment: .trailing)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.percent)% to mastered")
        .onAppear {
            guard let from, from < score.percent, !reduceMotion else { return }
            shown = Double(from)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { shown = target }
            }
        }
        .onChange(of: score.percent) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { shown = target }
        }
    }
}

/// Circular mastery gauge for the verse detail header.
struct MasteryRing: View {
    let score: MasteryScore
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = score.percent >= 100 ? Color(red: 0.20, green: 0.65, blue: 0.40) : Color.reforgedGold
        ZStack {
            Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 10)
            Circle()
                .trim(from: 0, to: score.fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score.percent)%")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.percent)% to mastered, \(label)")
    }
}

// MARK: - Verse page

/// A verse's page, laid out like the classic Bible memory apps: the verse, three
/// numbered steps to memorize it, then spaced reviews toward Mastered. Each step opens
/// right here (pushed), and one button at the bottom always runs the next thing to do.
struct VerseDetailSheet: View {
    let verseId: String
    let onPractice: (MemoryVerse) -> Void
    let onRemove: (MemoryVerse) -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private enum Activity: Equatable { case step(MemoryVerse.Step), review }
    @State private var activity: Activity?

    private var verse: MemoryVerse? { appState.memoryVerses.first { $0.id == verseId } }

    var body: some View {
        NavigationStack {
            Group {
                if let verse {
                    page(verse)
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { activity != nil },
                set: { if !$0 { activity = nil } }
            )) {
                if let verse, let activity { activityView(activity, verse) }
            }
        }
    }

    // MARK: Page

    /// The single next action: the next step, else a due review, else an optional recite.
    private func nextAction(_ verse: MemoryVerse) -> (Activity, String) {
        if let step = verse.currentStep {
            return (.step(step), "Start Step \(step.rawValue): \(step.title)")
        }
        return (.review, verse.isDueForReview ? "Review now" : "Recite it again")
    }

    private func page(_ verse: MemoryVerse) -> some View {
        let score = verse.mastery
        let (next, nextTitle) = nextAction(verse)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(verse.text)
                    .font(.title3)
                    .lineSpacing(5)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(verse.statusLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Text("Toward mastered")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    MasteryMeter(score: score)
                }

                section("Memorize") {
                    ForEach(MemoryVerse.Step.allCases) { step in
                        stepRow(step, verse: verse)
                        if step != .recite { Divider().padding(.leading, 52) }
                    }
                }

                section("Review") { reviewRow(verse) }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PracticeButton(title: nextTitle, tint: .reforgedGold) { activity = next }
                Button("Practice modes") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onPractice(verse) }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(verse.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onRemove(verse) }
                    } label: { Label("Remove verse", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PracticeSectionLabel(text: title)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .background(Color.adaptiveCardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// A numbered step: number (or check when done), title, one-line description.
    /// Any step can be tapped; the next one is marked.
    private func stepRow(_ step: MemoryVerse.Step, verse: MemoryVerse) -> some View {
        let done = verse.isStepDone(step)
        let isNext = verse.currentStep == step
        return Button { activity = .step(step) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? Color.reforgedGold : (isNext ? Color.reforgedGold.opacity(0.15) : Color.clear))
                        .overlay(Circle().stroke(done || isNext ? Color.reforgedGold : Color.adaptiveBorder(colorScheme), lineWidth: 2))
                        .frame(width: 32, height: 32)
                    if done {
                        Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.black)
                    } else {
                        Text("\(step.rawValue)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isNext ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.body.weight(isNext ? .bold : .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(stepDetail(step, verse: verse))
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer(minLength: 8)
                if isNext {
                    Text("Next")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.reforgedGold, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(step.rawValue), \(step.title)\(done ? ", done" : (isNext ? ", next" : ""))")
    }

    private func stepDetail(_ step: MemoryVerse.Step, verse: MemoryVerse) -> String {
        if step == .recite, verse.status == .learning, let last = verse.recitation?.last {
            return "Last try \(Int((last.accuracy * 100).rounded()))%. 95% passes"
        }
        return step.detail
    }

    /// After memorizing: when the next review is, and progress toward Mastered.
    private func reviewRow(_ verse: MemoryVerse) -> some View {
        let memorized = verse.recitation?.memorizedAt != nil
        let passes = min(verse.recitation?.passStreak ?? 0, RecitationProgress.masteryReviewPasses)
        let text: String = {
            if !memorized { return "Unlocks after Step 3" }
            if verse.status == .mastered { return "Mastered. Keep reviewing to keep it" }
            if verse.isDueForReview { return "Due now" }
            let d = max(1, Calendar.current.dateComponents([.day], from: Date(), to: verse.nextReviewDate).day ?? 1)
            return d == 1 ? "Next review tomorrow" : "Next review in \(d) days"
        }()
        return HStack(spacing: 14) {
            Image(systemName: verse.status == .mastered ? "crown.fill" : "calendar")
                .font(.body.weight(.semibold))
                .foregroundStyle(memorized ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(verse.isDueForReview ? Color.reforgedCoral
                                     : (memorized ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme)))
                HStack(spacing: 6) {
                    ForEach(0..<RecitationProgress.masteryReviewPasses, id: \.self) { i in
                        Circle()
                            .fill(i < passes || verse.status == .mastered ? Color.reforgedGold : Color.adaptiveBorder(colorScheme))
                            .frame(width: 9, height: 9)
                    }
                    Text("Pass 3 reviews over \(RecitationProgress.masteryDays) days to master it")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Activities

    @ViewBuilder
    private func activityView(_ activity: Activity, _ verse: MemoryVerse) -> some View {
        switch activity {
        case .step(.type):
            LetterDrillView(verse: verse, hideEveryOther: false) { _ in
                appState.markVerseStep(verseId: verse.id, .type)
                appState.addXP(MemoryVerse.Step.type.xp, source: "verse-step")
                self.activity = nil
            }
            .navigationTitle("Step 1: Type it")
            .navigationBarTitleDisplayMode(.inline)
        case .step(.gaps):
            LetterDrillView(verse: verse, hideEveryOther: true) { _ in
                appState.markVerseStep(verseId: verse.id, .gaps)
                appState.addXP(MemoryVerse.Step.gaps.xp, source: "verse-step")
                self.activity = nil
            }
            .navigationTitle("Step 2: Fill the gaps")
            .navigationBarTitleDisplayMode(.inline)
        case .step(.recite), .review:
            let scheduled = activity == .review && verse.isDueForReview
            RecitationTestView(
                verse: verse,
                firstAttemptOnly: scheduled,
                scheduled: scheduled,
                onAttempt: { accuracy, method in
                    appState.recordRecitation(verseId: verse.id, accuracy: accuracy,
                                              method: method, scheduled: scheduled)
                    appState.addXP(accuracy >= RecitationProgress.passThreshold ? 15 : 5, source: "verse-step")
                },
                onDone: { _, _ in self.activity = nil }
            )
            .navigationTitle(activity == .review ? "Review" : "Step 3: Recite it")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
