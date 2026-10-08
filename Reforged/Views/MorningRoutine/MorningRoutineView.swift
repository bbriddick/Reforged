import SwiftUI

// MARK: - Morning Routine Flow
//
// A guided, once-a-day devotional flow, presented full-screen from the Home CTA:
//   Scripture → Prayer → Gratitude (verse-themed questions) → Memory review → Completion
//
// It reuses existing services throughout: today's `dailyInsight` / Spurgeon morning
// reading for Scripture, `GeminiService` for the gratitude questions, the memory
// SRS store (`AppState.getVersesForReview`) with `SuggestedVersesData` as the fallback
// bank, and `AppState.addXP` — which credits the reading streak and drives the root
// `.celebrationOverlay()`. Completion is persisted via `MorningRoutineStorageManager`,
// and the prayer + gratitude prose is also saved to the encrypted journal.

struct MorningRoutineView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    enum Step: Int, CaseIterable {
        case scripture, prayer, gratitude, memory, complete

        /// Steps that show in the progress bar (completion is not a step).
        static var progressSteps: [Step] { [.scripture, .prayer, .gratitude, .memory] }
    }

    @State private var step: Step = .scripture

    // Scripture (resolved on appear)
    @State private var scriptureRef = ""
    @State private var scriptureText = ""
    @State private var scriptureReflection = ""
    @State private var spurgeonBody = ""

    // Prayer
    @State private var prayerText = ""
    @State private var selectedFocuses: Set<String> = []

    // Gratitude — seeded with the offline fallback so there is never an empty state.
    @State private var gratitudeQuestions = GeminiService.fallbackGratitudePrompts
    @State private var gratitudeAnswers = ["", "", ""]
    @State private var gratitudeLoading = false

    // Memory
    @State private var reviewVerse: MemoryVerse?
    @State private var reviewIsReal = false

    private let prayerFocusOptions = [
        "My family", "My work", "Someone hurting", "Wisdom today",
        "The lost", "Thanksgiving", "My church", "A decision"
    ]

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if step != .complete {
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                switch step {
                case .scripture: scriptureStep
                case .prayer:    prayerStep
                case .gratitude: gratitudeStep
                case .memory:    memoryStep
                case .complete:  completeStep
                }
            }
        }
        .onAppear(perform: prepare)
    }

    // MARK: - Header & progress

    private var header: some View {
        HStack {
            if step != .complete && step != .scripture {
                Button {
                    HapticManager.shared.buttonTap()
                    back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .accessibilityLabel("Back")
            }
            Spacer()
            if step != .complete {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.progressSteps, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue
                          ? Color.reforgedGold
                          : Color.adaptiveTextSecondary(colorScheme).opacity(0.18))
                    .frame(height: 5)
            }
        }
    }

    // MARK: - Step 1: Scripture

    private var scriptureStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepHeading("Scripture", subtitle: "Sit with today's Word before you speak.")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("\u{201C}\(scriptureText)\u{201D}")
                            .font(.system(.title3, design: .serif))
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineSpacing(6)
                        if !scriptureRef.isEmpty {
                            LinkedScriptureText(text: scriptureRef,
                                                font: .subheadline.weight(.semibold),
                                                baseColor: Color.reforgedGold,
                                                linkColor: Color.reforgedGold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.reforgedGold.opacity(0.30), lineWidth: 1.5))

                    if !scriptureReflection.isEmpty {
                        reflectionBlock(title: "Reflection", body: scriptureReflection)
                    }
                    if !spurgeonBody.isEmpty {
                        reflectionBlock(title: "Spurgeon's Morning Devotion", body: spurgeonBody, linked: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            primaryButton("Begin Prayer") { advance(to: .prayer) }
        }
    }

    private func reflectionBlock(title: String, body: String, linked: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .tracking(0.5)
            if linked {
                LinkedScriptureText(text: body, font: .body, baseColor: Color.adaptiveText(colorScheme))
                    .lineSpacing(4)
            } else {
                Text(body)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 2: Prayer

    private var prayerStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepHeading("Prayer", subtitle: "Bring today to God. Tap what's on your heart.")

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                        ForEach(prayerFocusOptions, id: \.self) { focus in
                            focusChip(focus)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR PRAYER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .tracking(0.5)
                        TextEditor(text: $prayerText)
                            .frame(minHeight: 140)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topLeading) {
                                if prayerText.isEmpty {
                                    Text("Write a few words to the Lord…")
                                        .font(.body)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            primaryButton("Continue to Gratitude") { advance(to: .gratitude) }
        }
    }

    private func focusChip(_ focus: String) -> some View {
        let isOn = selectedFocuses.contains(focus)
        return Button {
            HapticManager.shared.lightImpact()
            if isOn { selectedFocuses.remove(focus) } else { selectedFocuses.insert(focus) }
        } label: {
            Text(focus)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? .white : Color.adaptiveNavyText(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn ? Color.reforgedGold : Color.reforgedGold.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Gratitude

    private var gratitudeStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepHeading("Gratitude", subtitle: "Give thanks, shaped by what you just read.")

                    ForEach(Array(gratitudeQuestions.prefix(3).enumerated()), id: \.offset) { index, question in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.reforgedGold))
                                Text(question)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            TextField("I'm thankful for…", text: binding(for: index), axis: .vertical)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.adaptiveCardBackground(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if gratitudeLoading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Tailoring questions to today's verse…")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            primaryButton("Review a Verse") { advance(to: .memory) }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < gratitudeAnswers.count ? gratitudeAnswers[index] : "" },
            set: { newValue in
                while gratitudeAnswers.count <= index { gratitudeAnswers.append("") }
                gratitudeAnswers[index] = newValue
            }
        )
    }

    // MARK: - Step 4: Memory review

    private var memoryStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                stepHeading(
                    "Memory",
                    subtitle: reviewIsReal
                        ? "One verse due for review. Tap to reveal, swipe to rate."
                        : "Nothing due — here's one worth hiding in your heart."
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer(minLength: 0)

            if let verse = reviewVerse {
                SwipeableFlashcard(verse: verse, onSwipe: { swipe in
                    gradeAndFinish(swipe)
                })
                .frame(maxHeight: 420)
            } else {
                ProgressView()
            }

            Spacer(minLength: 0)

            Text("Swipe right if you knew it, left to keep learning")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.bottom, 24)
        }
    }

    // MARK: - Step 5: Completion

    private var completeStep: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.reforgedGold, Color.reforgedCoral],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.reforgedGold.opacity(0.4), radius: 20)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Morning complete")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("You met with God, prayed, gave thanks, and hid the Word in your heart. Your streak is counted.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }

            Spacer()

            primaryButton("Done") { dismiss() }
        }
    }

    // MARK: - Shared UI

    private func stepHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.reforgedNavy)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    // MARK: - Flow control

    private func advance(to next: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) { step = prev }
    }

    // MARK: - Setup

    private func prepare() {
        resolveScripture()
        resolveReviewVerse()
        loadGratitudeQuestions()
    }

    private func resolveScripture() {
        appState.refreshDailyInsightIfNeeded()

        if let insight = appState.dailyInsight {
            scriptureRef = insight.verse
            scriptureText = insight.verseText
            scriptureReflection = insight.reflection
        }

        // Always offer today's Spurgeon morning reading as the classic devotion,
        // and use it as the scripture fallback when there's no daily insight yet.
        let today = SpurgeonDevotionalService.shared.todayDayNumber()
        if let day = SpurgeonDevotionalService.shared.day(today) {
            spurgeonBody = day.morning.body
            if scriptureText.isEmpty {
                scriptureText = day.morning.verse
                scriptureRef = day.morning.reference
            }
        }

        // Last-resort default so the step is never blank.
        if scriptureText.isEmpty {
            scriptureText = "This is the day that the Lord has made; let us rejoice and be glad in it."
            scriptureRef = "Psalm 118:24"
        }
    }

    private func resolveReviewVerse() {
        let due = appState.getVersesForReview()
        if let picked = due.randomElement() {
            reviewVerse = picked
            reviewIsReal = true
        } else if let suggestion = SuggestedVersesData.allVerses.randomElement() {
            reviewVerse = MemoryVerse(
                id: UUID().uuidString,
                reference: suggestion.reference,
                text: suggestion.text,
                esvText: suggestion.text,
                category: suggestion.category,
                translation: "ESV",
                lastFetched: AppDateFormatters.iso8601.string(from: Date()),
                nextReviewDate: Date(),
                reviewCount: 0,
                easeFactor: 2.5,
                interval: 1,
                isLearning: true,
                accuracy: nil,
                modeStats: nil
            )
            reviewIsReal = false
        }
    }

    private func loadGratitudeQuestions() {
        // Fallback questions are already shown; swap in verse-themed ones if AI is on.
        gratitudeLoading = true
        let ref = scriptureRef
        let text = scriptureText
        Task {
            defer { gratitudeLoading = false }
            guard !ref.isEmpty, !text.isEmpty else { return }
            if let generated = try? await GeminiService.shared.generateGratitudePrompts(reference: ref, verseText: text),
               generated.count >= 3 {
                await MainActor.run {
                    gratitudeQuestions = generated
                }
            }
        }
    }

    // MARK: - Completion wiring

    private func gradeAndFinish(_ swipe: FlashcardSwipe) {
        // Update SRS only for a real due verse; a suggested-bank verse has no record.
        if reviewIsReal, let verse = reviewVerse {
            appState.updateVerseReview(verseId: verse.id, quality: swipe == .known ? 4 : 2)
        }
        finishRoutine()
    }

    private func finishRoutine() {
        // A single XP event — maps to `.memory`, so it credits the reading streak
        // and fires the root celebration overlay exactly once.
        appState.addXP(25, source: "review-complete")

        MorningRoutineStorageManager.shared.completeToday(
            scriptureReference: scriptureRef,
            scriptureText: scriptureText,
            prayerText: prayerText,
            prayerFocuses: Array(selectedFocuses),
            gratitudeQuestions: Array(gratitudeQuestions.prefix(3)),
            gratitudeAnswers: gratitudeAnswers,
            reviewedVerseReference: reviewVerse?.reference
        )
        saveReflectionToJournal()

        HapticManager.shared.success()
        advance(to: .complete)
    }

    /// Writes the prayer + gratitude as one journal entry so the reflection lives
    /// in the encrypted journal alongside the user's other notes.
    private func saveReflectionToJournal() {
        var lines: [String] = []
        let trimmedPrayer = prayerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrayer.isEmpty {
            lines.append("Prayer:\n\(trimmedPrayer)")
        }
        if !selectedFocuses.isEmpty {
            lines.append("Prayed for: \(selectedFocuses.sorted().joined(separator: ", "))")
        }
        let gratitude = zip(gratitudeQuestions, gratitudeAnswers)
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "• \($0.0)\n  \($0.1.trimmingCharacters(in: .whitespacesAndNewlines))" }
        if !gratitude.isEmpty {
            lines.append("Gratitude:\n" + gratitude.joined(separator: "\n"))
        }

        guard !lines.isEmpty else { return }

        let content = lines.joined(separator: "\n\n")
        let entry = JournalEntry(
            id: UUID().uuidString,
            date: AppDateFormatters.iso8601.string(from: Date()),
            content: content,
            tags: ["Morning Routine"],
            linkedVerses: scriptureRef.isEmpty ? [] : [scriptureRef],
            prompt: "Morning Routine"
        )
        JournalStorageManager.shared.addEntry(entry)
    }
}

// MARK: - Home CTA Card

/// The Home entry point into the morning routine. Shows the four steps and their
/// order before starting, and collapses to a "completed" state once the day's
/// routine is done. Presentation is owned by the caller via `onBegin`.
struct MorningRoutineCard: View {
    @ObservedObject private var store = MorningRoutineStorageManager.shared
    @Environment(\.colorScheme) var colorScheme
    let onBegin: () -> Void

    private let steps = ["Scripture", "Prayer", "Gratitude", "Memory verse"]

    var body: some View {
        Group {
            if store.isCompletedToday {
                completedCard
            } else {
                beginCard
            }
        }
    }

    private var beginCard: some View {
        Button(action: onBegin) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: timeOfDay.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                    Text(timeOfDay.greeting)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                }

                Text("A guided time in the Word, prayer, gratitude, and memory — about five minutes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.reforgedGold.opacity(0.12))
                            .clipShape(Capsule())
                        if index < steps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                        }
                    }
                }

                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text(timeOfDay.beginLabel)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.reforgedNavy)
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }

    private var completedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.reforgedGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Morning routine complete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Well done. See you tomorrow morning.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer(minLength: 8)

            // Clears only today's routine entry (never the streak) and reopens the
            // flow, so the routine can be walked again without waiting for tomorrow.
            Button {
                HapticManager.shared.lightImpact()
                store.resetToday()
                onBegin()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Do it again")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.reforgedGold.opacity(0.14))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: ReforgedTheme.cardShadow, radius: ReforgedTheme.cardShadowRadius, y: ReforgedTheme.cardShadowY)
    }

    /// Greeting, button label and icon all come from one hour check, so the
    /// card can never say "Good evening" over "Begin this morning".
    private var timeOfDay: (greeting: String, beginLabel: String, icon: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return ("Good morning", "Begin this morning", "sunrise.fill")
        case 12..<17: return ("Good afternoon", "Begin this afternoon", "sun.max.fill")
        default:      return ("Good evening", "Begin this evening", "moon.stars.fill")
        }
    }
}
