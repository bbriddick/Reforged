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
            // Progress Bar
            ProgressView(value: progress)
                .tint(Color.reforgedGold)
                .padding(.horizontal)
                .padding(.top, 8)
            
            if lessonComplete {
                LessonCompleteView(lesson: lesson, onDismiss: { dismiss() })
            } else if let content = currentContent {
                ScrollView {
                    VStack(spacing: 24) {
                        contentView(for: content)
                    }
                    .padding()
                }
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentContentIndex > 0 {
                        Button(action: previousContent) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button(action: nextContent) {
                        HStack {
                            Text(currentContentIndex == lesson.content.count - 1 ? "Complete" : "Continue")
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canProceed)
                }
                .padding()
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let entry = JournalEntry(
            id: UUID().uuidString,
            date: dateFormatter.string(from: Date()),
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
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.reforgedGold)

            Text(content.reference)
                .font(.headline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            ZStack {
                Text("\"\(displayText)\"")
                    .font(.title3)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme).opacity(isFetching ? 0.4 : 1))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if isFetching {
                    ProgressView()
                        .tint(Color.reforgedGold)
                }
            }

            Text(settings.defaultTranslation.rawValue)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding()
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
            case .csb, .nkjv, .nasb:
                result = try await ApiBibleService.shared.fetchVerseForMemory(
                    reference: content.reference,
                    translation: translation
                )
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
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        VStack(alignment: .leading, spacing: 20) {
            Text(content.question)
                .font(.title3)
                .fontWeight(.semibold)
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
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showExplanation = true
                                }
                            }
                        }
                    }
                }
            }

            if showExplanation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isCorrect ? Color.green : Color.red)
                        Text(isCorrect ? "Correct!" : "Not quite")
                            .fontWeight(.semibold)
                            .foregroundStyle(isCorrect ? Color.green : Color.red)
                    }

                    Text(content.explanation)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding()
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

struct AnswerButton: View {
    let option: AnswerChoice
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        if !showResult {
            return isSelected ? Color.reforgedNavy.opacity(0.1) : Color.adaptiveCardBackground(colorScheme)
        }
        if isCorrect {
            return Color.green.opacity(0.1)
        }
        if isSelected && !isCorrect {
            return Color.red.opacity(0.1)
        }
        return Color.adaptiveCardBackground(colorScheme)
    }

    var borderColor: Color {
        if !showResult {
            return isSelected ? Color.reforgedNavy : .clear
        }
        if isCorrect {
            return .green
        }
        if isSelected && !isCorrect {
            return .red
        }
        return .clear
    }

    var radioIcon: String {
        if showResult {
            if isCorrect {
                return "checkmark.circle.fill"
            }
            if isSelected {
                return "xmark.circle.fill"
            }
            return "circle"
        }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    var radioColor: Color {
        if showResult {
            if isCorrect { return .green }
            if isSelected { return .red }
            return Color.adaptiveTextSecondary(colorScheme)
        }
        return isSelected ? Color.reforgedNavy : Color.adaptiveTextSecondary(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: radioIcon)
                    .font(.title3)
                    .foregroundStyle(radioColor)

                Text(option.text)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding()
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundStyle(Color.reforgedGold)
                Text("Reflection")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Text(content.prompt)
                .font(.body)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            TextEditor(text: $text)
                .frame(minHeight: 150)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Lesson Complete View

struct LessonCompleteView: View {
    let lesson: Lesson
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.reforgedGold)

            Text("Lesson Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("You've completed \"\(lesson.title)\"")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack {
                    Text("+\(lesson.xpReward)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedGold)
                    Text("XP Earned")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding()
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.reforgedNavy)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        LessonView(lesson: LearningTracks.allTracks[0].lessons[0])
            .environmentObject(AppState.shared)
            .environmentObject(SettingsManager.shared)
    }
}
