import SwiftUI

/// A key verb/infinitive/noun chip shown in the Word Study section.
/// NT chips carry an exact Strong's number from bundled Greek morphology (offline);
/// OT chips come from a Gemini classification of the English text (no interlinear alignment).
private struct WordStudyChip: Identifiable {
    let id = UUID()
    let word: String
    let partOfSpeech: String
    let strongsNumber: String?
    let originalWord: String
    let morphDescription: String
}

private struct IdentifiablePrompt: Identifiable {
    let id = UUID()
    let text: String
}

/// Consolidates three study aids for a single verse: a verb/noun/infinitive breakdown
/// (tap to open Word Study), Gemini study questions (tap to open the note editor), and
/// offline cross references (tap to expand an inline preview).
struct VerseStudySheet: View {
    let verse: ParsedVerse
    let bookName: String
    let chapter: Int
    let translation: BibleTranslation
    @ObservedObject var readingState: BibleReadingState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @State private var wordChips: [WordStudyChip] = []
    @State private var isLoadingWords = false
    @State private var studyQuestions: [String] = []
    @State private var isLoadingQuestions = false
    @State private var expandedCrossRefs: Set<String> = []
    @State private var crossRefPreviewText: [String: String] = [:]
    @State private var wordLookupResult: WordLookupResult?
    @State private var studyNotePrompt: IdentifiablePrompt?

    private var isNewTestament: Bool {
        BibleData.books.first(where: { $0.name == bookName })?.testament == .new
    }

    private var crossReferences: [CrossReferenceEntry] {
        CrossReferenceService.shared.crossReferences(for: verse.reference)
    }

    private var showWordStudySection: Bool { isNewTestament || settings.aiEnabled }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    verseHeader

                    if showWordStudySection {
                        wordStudySection
                    }

                    if settings.aiEnabled {
                        studyQuestionsSection
                    }

                    crossReferencesSection
                }
                .padding()
            }
            .background(Color.adaptiveCardBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Verse Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await loadWordChips() }
        .task { await loadStudyQuestions() }
        .sheet(item: $wordLookupResult) { result in
            StrongsDefinitionSheet(result: result)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $studyNotePrompt) { prompt in
            TakeNoteView(
                verses: [verse],
                readingState: readingState,
                onDismiss: { studyNotePrompt = nil },
                prefilledPrompt: prompt.text
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Verse header

    private var verseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verse.reference)
                .font(.headline)
                .foregroundStyle(Color.reforgedGold)
            Text(verse.text)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
    }

    // MARK: - Word Study

    private var wordStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Word Study")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            if isLoadingWords {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if wordChips.isEmpty {
                Text("No key words identified for this verse.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            } else {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(wordChips) { chip in
                        Button {
                            Task { await lookupChip(chip) }
                        } label: {
                            VStack(spacing: 2) {
                                Text(chip.word)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(chip.partOfSpeech)
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.reforgedGold.opacity(0.12))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadWordChips() async {
        if isNewTestament {
            await loadNTWordChips()
        } else {
            await loadOTWordChips()
        }
    }

    private func loadNTWordChips() async {
        guard let bookNum = OriginalLanguageService.bookNumber(for: bookName) else { return }

        isLoadingWords = true
        OriginalLanguageService.shared.preloadTR()
        // Bundled Greek data loads on a background queue — wait for it rather than reading an empty index.
        let maxAttempts = 100
        for _ in 0..<maxAttempts {
            if OriginalLanguageService.shared.trReady { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        isLoadingWords = false

        let tokens = OriginalLanguageService.shared.trTokens(bookNumber: bookNum, chapter: chapter, verse: verse.number)

        var seen = Set<String>()
        var chips: [WordStudyChip] = []
        for token in tokens {
            let isVerb = token.morph.hasPrefix("V")
            let isNoun = token.morph.hasPrefix("N")
            guard isVerb || isNoun else { continue }
            guard seen.insert(token.word).inserted else { continue }

            let pos = token.morphDescription.contains("Infinitive") ? "infinitive" : (isVerb ? "verb" : "noun")
            let bundled = StrongsLexiconService.shared.lookupBundledEntry(token.strongs)
            let displayWord = bundled?.transliteration.isEmpty == false ? bundled!.transliteration : token.word

            chips.append(WordStudyChip(
                word: displayWord,
                partOfSpeech: pos,
                strongsNumber: token.strongs,
                originalWord: token.word,
                morphDescription: token.morphDescription
            ))
            if chips.count >= 10 { break }
        }
        wordChips = chips
    }

    private func loadOTWordChips() async {
        isLoadingWords = true
        let tags = (try? await GeminiService.shared.classifyKeyWords(reference: verse.reference, verseText: verse.text)) ?? []
        wordChips = tags.map { tag in
            WordStudyChip(
                word: tag.word,
                partOfSpeech: tag.partOfSpeech,
                strongsNumber: nil,
                originalWord: tag.word,
                morphDescription: ""
            )
        }
        isLoadingWords = false
    }

    private func lookupChip(_ chip: WordStudyChip) async {
        if let strongsNumber = chip.strongsNumber {
            wordLookupResult = await StrongsLexiconService.shared.lookupByStrongsNumber(
                strongsNumber,
                tappedWord: chip.originalWord,
                originalForm: chip.originalWord,
                morphDescription: chip.morphDescription,
                verseReference: verse.reference,
                bookName: bookName,
                chapter: chapter,
                verseNumber: verse.number,
                isHebrew: false
            )
        } else {
            wordLookupResult = await StrongsLexiconService.shared.lookupWord(
                chip.word,
                verseReference: verse.reference,
                bookName: bookName,
                chapter: chapter,
                verseNumber: verse.number,
                isHebrew: true
            )
        }
    }

    // MARK: - Study Questions

    private var studyQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Questions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            if isLoadingQuestions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if studyQuestions.isEmpty {
                Text("No study questions available.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(studyQuestions, id: \.self) { question in
                        Button {
                            studyNotePrompt = IdentifiablePrompt(text: question)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                Image(systemName: "square.and.pencil")
                                    .font(.caption)
                                    .foregroundStyle(Color.reforgedGold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadStudyQuestions() async {
        guard settings.aiEnabled else { return }
        isLoadingQuestions = true
        studyQuestions = (try? await GeminiService.shared.generateJournalPrompts(
            reference: verse.reference,
            verseText: verse.text
        )) ?? []
        isLoadingQuestions = false
    }

    // MARK: - Cross References

    private var crossReferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cross References")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            if crossReferences.isEmpty {
                Text("No cross references found for this verse.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(crossReferences) { entry in
                        crossReferenceRow(entry)
                    }
                }
            }
        }
    }

    private func crossReferenceRow(_ entry: CrossReferenceEntry) -> some View {
        let isExpanded = expandedCrossRefs.contains(entry.reference)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCrossRefs.remove(entry.reference)
                    } else {
                        expandedCrossRefs.insert(entry.reference)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    Text(entry.reference)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.adaptiveNavyText(colorScheme).opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Group {
                    if let text = crossRefPreviewText[entry.reference] {
                        Text(text.isEmpty ? "Verse text unavailable." : text)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    } else {
                        ProgressView()
                            .task { await loadCrossRefPreview(entry) }
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadCrossRefPreview(_ entry: CrossReferenceEntry) async {
        guard crossRefPreviewText[entry.reference] == nil else { return }
        guard let parsed = parseCrossReference(entry.reference) else {
            crossRefPreviewText[entry.reference] = ""
            return
        }

        do {
            let chapterEntry = try await ChapterScrollCoordinator.performChapterFetch(
                book: parsed.book,
                chapter: parsed.chapter,
                translation: translation
            )
            crossRefPreviewText[entry.reference] = chapterEntry.verses.first(where: { $0.number == parsed.verseStart })?.text ?? ""
        } catch {
            crossRefPreviewText[entry.reference] = ""
        }
    }

    /// Parses "Book Chapter:VerseStart" or "Book Chapter:VerseStart-VerseEnd" into its parts.
    private func parseCrossReference(_ reference: String) -> (book: String, chapter: Int, verseStart: Int)? {
        guard let colon = reference.lastIndex(of: ":") else { return nil }
        let afterColon = reference[reference.index(after: colon)...]
        let verseStartString = afterColon.split(separator: "-").first.map(String.init) ?? String(afterColon)
        guard let verseStart = Int(verseStartString) else { return nil }

        let beforeColon = reference[..<colon]
        guard let lastSpace = beforeColon.lastIndex(of: " "),
              let chapter = Int(beforeColon[beforeColon.index(after: lastSpace)...]) else { return nil }

        return (String(beforeColon[..<lastSpace]), chapter, verseStart)
    }
}
