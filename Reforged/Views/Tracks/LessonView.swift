import SwiftUI

struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var currentContentIndex = 0
    @State private var selectedAnswer: String?
    @State private var showExplanation = false
    @State private var reflectionText = ""
    @State private var lessonComplete = false
    
    var currentContent: LessonContent? {
        guard currentContentIndex < lesson.content.count else { return nil }
        return lesson.content[currentContentIndex]
    }
    
    var progress: Double {
        guard !lesson.content.isEmpty else { return 1 }
        return Double(currentContentIndex + 1) / Double(lesson.content.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if lessonComplete {
                LessonCompleteView(lesson: lesson, onDismiss: { dismiss() })
            } else if let content = currentContent {
            // Progress bar: the same thick gold bar as the daily memory lesson.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.adaptiveBorder(colorScheme)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.reforgedGold, Color.orange],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 12)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
                ScrollView {
                    VStack(spacing: 24) {
                        contentView(for: content)
                    }
                    .padding()
                }
                
                // Navigation buttons: chunky 3D, like the rest of Memory.
                HStack(spacing: 12) {
                    if currentContentIndex > 0 {
                        Button {
                            HapticManager.shared.buttonTap()
                            previousContent()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline.bold())
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .padding(.vertical, 16)
                                .padding(.horizontal, 22)
                        }
                        .buttonStyle(PracticeLipButtonStyle(
                            face: Color.adaptiveCardBackground(colorScheme),
                            lip: Color.adaptiveBorder(colorScheme),
                            stroke: Color.adaptiveBorder(colorScheme),
                            cornerRadius: 16, depth: 5))
                        .accessibilityLabel("Back")
                    }

                    Button {
                        HapticManager.shared.buttonTap()
                        nextContent()
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentContentIndex == lesson.content.count - 1 ? "Complete" : "Continue")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(Chunky3DButtonStyle(
                        backgroundColor: canProceed ? Color.reforgedCoral : Color.adaptiveBorder(colorScheme),
                        bevelColor: canProceed ? Color.reforgedCoral.practiceBevel()
                            : Color.adaptiveBorder(colorScheme).practiceBevel(),
                        textColor: canProceed ? .white : Color.adaptiveTextSecondary(colorScheme)))
                    .disabled(!canProceed)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(Color.adaptiveBackground(colorScheme))
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var canProceed: Bool {
        guard let content = currentContent else { return true }
        switch content.data {
        case .question:
            return showExplanation
        case .reflection:
            return !reflectionText.isEmpty
        default:
            return true
        }
    }
    
    @ViewBuilder
    func contentView(for content: LessonContent) -> some View {
        switch content.data {
        case .scripture(let data):
            ScriptureContentView(content: data)
        case .explanation(let data):
            ExplanationContentView(content: data)
        case .question(let data):
            QuestionContentView(
                content: data,
                selectedAnswer: $selectedAnswer,
                showExplanation: $showExplanation
            )
            .id(content.id)
        case .reflection(let data):
            ReflectionContentView(content: data, text: $reflectionText)
        }
    }
    
    func previousContent() {
        if currentContentIndex > 0 {
            currentContentIndex -= 1
            resetState()
        }
    }
    
    func nextContent() {
        if currentContentIndex < lesson.content.count - 1 {
            currentContentIndex += 1
            resetState()
        } else {
            completeLesson()
        }
    }
    
    func resetState() {
        selectedAnswer = nil
        showExplanation = false
        reflectionText = ""
    }
    
    func completeLesson() {
        // Save reflection to journal if user wrote one
        if !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveReflectionToJournal()
        }
        appState.completeLesson(lesson.id)
        appState.addXP(lesson.xpReward, source: "lesson")
        lessonComplete = true
    }

    func saveReflectionToJournal() {
        // Find the reflection prompt from the lesson content
        let reflectionPrompt = lesson.content.compactMap { content -> String? in
            if case .reflection(let data) = content.data {
                return data.prompt
            }
            return nil
        }.last

        let entry = JournalEntry(
            id: UUID().uuidString,
            date: AppDateFormatters.yearMonthDay.string(from: Date()),
            content: reflectionText,
            tags: ["Lesson Reflection"],
            linkedVerse: nil,
            linkedLesson: lesson.title,
            linkedInsight: nil,
            prompt: reflectionPrompt
        )

        JournalStorageManager.shared.addEntry(entry)
    }
}

// MARK: - Scripture Content View

struct ScriptureContentView: View {
    let content: ScriptureContent
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var colorScheme
    @State private var fetchedText: String? = nil
    @State private var isFetching = false

    private var displayText: String { fetchedText ?? content.text }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.reforgedCoral.opacity(colorScheme == .dark ? 0.22 : 0.13))
                    .frame(width: 60, height: 60)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.reforgedCoral)
            }

            Text(content.reference)
                .font(.title3.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))

            ZStack {
                Text("\u{201C}\(displayText)\u{201D}")
                    .font(Font.custom("LibreBaskerville-Italic", size: 19))
                    .lineSpacing(9)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme).opacity(isFetching ? 0.4 : 1))
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .practiceCard(radius: 22)

                if isFetching {
                    ProgressView()
                        .tint(Color.reforgedGold)
                }
            }

            Text(settings.defaultTranslation.rawValue)
                .font(.caption.bold())
                .tracking(0.6)
                .foregroundStyle(Color.reforgedGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.reforgedGold.opacity(0.12), in: Capsule())
        }
        .padding(.vertical)
        .task(id: settings.defaultTranslation) {
            await fetchVerse(translation: settings.defaultTranslation)
        }
    }

    private func fetchVerse(translation: BibleTranslation) async {
        isFetching = true
        defer { isFetching = false }
        do {
            let result: (text: String, canonical: String)
            switch translation {
            case .esv:
                result = try await ESVService.shared.fetchVerseForMemory(reference: content.reference)
            case .kjv:
                result = try await KJVService.shared.fetchVerseForMemory(reference: content.reference)
            case .net:
                result = try await NETService.shared.fetchVerseForMemory(reference: content.reference)
            case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                result = try await ApiBibleService.shared.fetchVerseForMemory(
                    reference: content.reference,
                    translation: translation
                )
            case .tr, .sblgnt, .wlc:
                fetchedText = nil; return  // not applicable for lesson verses
            }
            fetchedText = result.text
        } catch {
            fetchedText = nil // fall back to static text
        }
    }
}

// MARK: - Explanation Content View

struct ExplanationContentView: View {
    let content: ExplanationContent
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = content.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Text(content.text)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceCard(radius: 20)
    }
}

// MARK: - Question Content View

struct QuestionContentView: View {
    let content: QuestionContent
    @Binding var selectedAnswer: String?
    @Binding var showExplanation: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var shuffledOptions: [AnswerChoice] = []

    var isCorrect: Bool {
        selectedAnswer == content.correctAnswer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(content.question)
                .font(.title3.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))

            if !shuffledOptions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(shuffledOptions) { option in
                        AnswerButton(
                            option: option,
                            isSelected: selectedAnswer == option.id,
                            isCorrect: option.id == content.correctAnswer,
                            showResult: showExplanation
                        ) {
                            if !showExplanation {
                                selectedAnswer = option.id
                                if option.id == content.correctAnswer {
                                    HapticManager.shared.correctAnswer()
                                } else {
                                    HapticManager.shared.incorrectAnswer()
                                }
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showExplanation = true
                                }
                            }
                        }
                    }
                }
            }

            if showExplanation {
                let tint = isCorrect ? Color.practiceGreen : Color.red
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(tint, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCorrect ? "Correct!" : "Not quite")
                            .font(.headline.bold())
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(content.explanation)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            if shuffledOptions.isEmpty, let options = content.options {
                shuffledOptions = options.shuffled()
            }
        }
        .onChange(of: content.question) { _ in
            if let options = content.options {
                shuffledOptions = options.shuffled()
            }
        }
    }
}

/// An answer choice: a card on a lip that presses down, tinted green or red once answered.
struct AnswerButton: View {
    let option: AnswerChoice
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var tint: Color? {
        if showResult {
            if isCorrect { return Color.practiceGreen }
            if isSelected { return Color.red }
            return nil
        }
        return isSelected ? Color.reforgedCoral : nil
    }

    var radioIcon: String {
        if showResult {
            if isCorrect { return "checkmark.circle.fill" }
            if isSelected { return "xmark.circle.fill" }
            return "circle"
        }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: radioIcon)
                    .font(.title3)
                    .foregroundStyle(tint ?? Color.adaptiveTextSecondary(colorScheme))

                Text(option.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background((tint ?? .clear).opacity(colorScheme == .dark ? 0.20 : 0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint ?? .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PracticeLipButtonStyle(
            face: Color.adaptiveCardBackground(colorScheme),
            lip: tint?.opacity(0.55) ?? Color.adaptiveBorder(colorScheme),
            stroke: tint == nil ? Color.adaptiveBorder(colorScheme) : nil,
            cornerRadius: 16, depth: 4))
        .disabled(showResult)
    }
}

// MARK: - Reflection Content View

struct ReflectionContentView: View {
    let content: ReflectionContent
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.reforgedCoral, in: Circle())
                Text("Reflection")
                    .font(.title3.bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Text(content.prompt)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            TextEditor(text: $text)
                .frame(minHeight: 150)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
        }
        .padding(20)
        .practiceCard(radius: 20)
    }
}

// MARK: - Lesson Complete View
//
// The same full-screen reward stage the daily memory lesson ends on.

struct LessonCompleteView: View {
    let lesson: Lesson
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        JackpotStage(
            config: JackpotConfig(
                hero: .symbol("checkmark.seal.fill"),
                headline: "Lesson complete",
                title: "You finished \u{201C}\(lesson.title)\u{201D}.",
                accent: .gold,
                reels: [
                    JackpotReel(icon: "star.fill", label: "XP earned", value: lesson.xpReward, tint: .reforgedGold),
                    JackpotReel(icon: "flame.fill", label: "Day streak", value: appState.user.streak,
                                prefix: "", tint: .reforgedCoral),
                ],
                cta: "Continue",
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
        LessonView(lesson: LearningTracks.allTracks[0].lessons[0])
            .environmentObject(AppState.shared)
            .environmentObject(SettingsManager.shared)
    }
}
#endif
