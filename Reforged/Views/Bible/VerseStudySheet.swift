import SwiftUI

/// A key noun/verb chip shown in the Word Study section. The label is the word as the reader sees
/// it in the verse (the KJV rendering), with the original-language word beneath. Chips come from
/// the Greek or Hebrew text in the study database with exact Strong's numbers and morphology; the
/// bundled Greek text and a Gemini classification of the English remain as fallbacks.
private struct WordStudyChip: Identifiable {
    let id = UUID()
    let word: String
    let partOfSpeech: String
    let strongsNumber: String?
    let originalWord: String
    let morphDescription: String
    /// How the KJV renders the word in this verse, when known.
    var english: String? = nil

    var isHebrew: Bool { strongsNumber?.hasPrefix("H") ?? false }
}

private struct IdentifiablePrompt: Identifiable {
    let id = UUID()
    let text: String
}

/// Study aids for a single verse, in the order a reader uses them: the verse itself, the words
/// in it (tap to open Word Study), where else Scripture says it, what commentators say, the
/// places and topics it touches, and (with AI on) questions to reflect on.
struct VerseStudySheet: View {
    let verse: ParsedVerse
    let bookName: String
    let chapter: Int
    let translation: BibleTranslation
    @ObservedObject var readingState: BibleReadingState
    /// When hosted in the iPad tools sidebar (not a sheet), the environment dismiss
    /// is a no-op, so the host passes an explicit close. Falls back to `dismiss`.
    var onClose: (() -> Void)? = nil
    /// When hosted in the iPad rail, a tapped word chip hands its study to the host to dock beside
    /// the reader; without it the study opens as a sheet over this one.
    var onOpenWordStudy: ((WordLookupResult) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @State private var wordChips: [WordStudyChip] = []
    @State private var isLoadingWords = false
    @State private var studyQuestions: [String] = []
    @State private var isLoadingQuestions = false
    /// True when `studyQuestions` are the general offline set rather than ones for this verse.
    @State private var usingFallbackQuestions = false
    @State private var expandedCrossRefs: Set<String> = []
    @State private var crossRefPreviewText: [String: String] = [:]
    @State private var crossRefsAsMap = false
    @State private var expandedTopic: String?
    @State private var wordLookupResult: WordLookupResult?
    @State private var studyNotePrompt: IdentifiablePrompt?
    @State private var atlasFocusID: String?
    @State private var showAtlas = false
    @State private var expandedCommentaries: Set<String> = []
    @State private var showDownloadableCommentaries = false
    @ObservedObject private var commentaryDownloads = CommentaryDownloadManager.shared

    private var isNewTestament: Bool {
        BibleData.books.first(where: { $0.name == bookName })?.testament == .new
    }

    private var crossReferences: [CrossReferenceEntry] {
        CrossReferenceService.shared.crossReferences(for: verse.reference)
    }

    private var verseTopics: [String] {
        TopicalBibleService.shared.topics(for: verse.reference)
    }

    private var versePlaces: [BiblePlace] {
        BiblePlaceService.shared.places(forVerse: verse.reference)
    }

    private var commentaryEntries: [CommentaryEntry] {
        CommentaryService.shared.entries(for: verse.reference)
    }

    /// Downloadable commentaries not yet on disk, so the user can fetch more coverage.
    private var downloadableCommentaries: [CommentarySource] {
        CommentarySource.allCases.filter {
            !$0.isBundled && !commentaryDownloads.isDownloaded($0)
                && ($0.coversWholeBible || bookName == "Psalms")
        }
    }

    private var showWordStudySection: Bool { isNewTestament || settings.aiEnabled || StudyDataFlags.useLocal }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    verseHeader

                    if showWordStudySection {
                        wordStudySection
                    }

                    crossReferencesSection

                    commentarySection

                    if !versePlaces.isEmpty {
                        placesSection
                    }

                    if !verseTopics.isEmpty {
                        topicsSection
                    }

                    if settings.aiEnabled {
                        studyQuestionsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Verse Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose?() ?? dismiss() }
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
        .sheet(isPresented: $showAtlas) {
            BibleAtlasView(focusPlaceID: atlasFocusID)
        }
    }

    /// Closes verse study and deep-links to the Study Library hub in the Discipleship tab.
    private func openStudyLibrary() {
        onClose?() ?? dismiss()
        NotificationCenter.default.post(
            name: .switchTab, object: nil,
            userInfo: [AppNotificationUserInfoKey.tab: 1]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .openStudyLibrary, object: nil)
        }
    }

    // MARK: - Shared building blocks

    /// Section title with an optional trailing action. The action keeps a 44 pt hit area.
    private func sectionHeader(_ title: String, action: (title: String, icon: String, run: () -> Void)? = nil) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Spacer()

            if let action {
                Button(action: action.run) {
                    Label(action.title, systemImage: action.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 4)
        .frame(minHeight: 28)
    }

    /// One rounded surface lifted off the paper canvas; rows inside separate with hairlines.
    private func surface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Verse header

    /// The verse as Scripture is always set: serif, honouring the reader's font settings, with its
    /// reference and translation.
    private var verseHeader: some View {
        surface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verse.reference)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.reforgedGold)
                    Text(translation.compactCode)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Text(verse.text)
                    .font(settings.scriptureFont)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    // MARK: - Word Study

    private var wordStudySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Words in this verse")

            surface {
                if isLoadingWords {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                } else if wordChips.isEmpty {
                    emptyNote("No key words identified for this verse.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tap a word to see its original language and meaning.")
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(wordChips) { chip in
                                chipButton(chip)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func chipButton(_ chip: WordStudyChip) -> some View {
        let showOriginal = chip.originalWord.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            != chip.word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return Button {
            Task { await lookupChip(chip) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(chip.word)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                if showOriginal {
                    Text(chip.originalWord)
                        .font(chip.isHebrew ? .custom("Ezra SIL", size: 18) : .callout)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44, alignment: .leading)
            .background(Color.adaptiveNavyText(colorScheme).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(chip.word), \(chip.partOfSpeech)")
        .accessibilityHint("Opens word study")
    }

    private func loadWordChips() async {
        isLoadingWords = true
        defer { isLoadingWords = false }

        // Same source for both testaments: the original text with exact Strong's numbers.
        if StudyDataFlags.useLocal {
            let words = await LocalStudyDataSource.shared.keyWords(
                bookName: bookName, chapter: chapter, verse: verse.number)
            if !words.isEmpty {
                wordChips = words.map { w in
                    WordStudyChip(
                        word: w.english ?? (w.transliteration.isEmpty ? w.surface : w.transliteration),
                        partOfSpeech: w.partOfSpeech,
                        strongsNumber: w.strongs,
                        originalWord: w.surface,
                        morphDescription: w.grammar,
                        english: w.english
                    )
                }
                return
            }
        }

        if isNewTestament {
            await loadNTWordChips()
        } else {
            await loadOTWordChips()
        }
    }

    /// Fallback when the study database is unavailable: the bundled Greek text.
    private func loadNTWordChips() async {
        guard let bookNum = OriginalLanguageService.bookNumber(for: bookName) else { return }

        OriginalLanguageService.shared.preloadTR()
        // Bundled Greek data loads on a background queue; wait for it rather than reading an empty index.
        let maxAttempts = 100
        for _ in 0..<maxAttempts {
            if OriginalLanguageService.shared.trReady { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

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

    /// Fallback when the study database is unavailable: a Gemini classification of the English.
    private func loadOTWordChips() async {
        guard settings.aiEnabled else {
            wordChips = []
            return
        }
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
    }

    private func present(_ result: WordLookupResult) {
        if let onOpenWordStudy {
            onOpenWordStudy(result)
        } else {
            wordLookupResult = result
        }
    }

    private func lookupChip(_ chip: WordStudyChip) async {
        if let strongsNumber = chip.strongsNumber {
            present(await StrongsLexiconService.shared.lookupByStrongsNumber(
                strongsNumber,
                tappedWord: chip.english ?? chip.originalWord,
                originalForm: chip.originalWord,
                morphDescription: chip.morphDescription,
                verseReference: verse.reference,
                bookName: bookName,
                chapter: chapter,
                verseNumber: verse.number,
                isHebrew: strongsNumber.hasPrefix("H")
            ))
        } else {
            present(await StrongsLexiconService.shared.lookupWord(
                chip.word,
                verseReference: verse.reference,
                bookName: bookName,
                chapter: chapter,
                verseNumber: verse.number,
                isHebrew: true
            ))
        }
    }

    // MARK: - Cross References

    private var crossReferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Cross references",
                action: crossReferences.isEmpty ? nil : (
                    title: crossRefsAsMap ? "List" : "Map",
                    icon: crossRefsAsMap ? "list.bullet" : "point.3.connected.trianglepath.dotted",
                    run: { withAnimation(.easeInOut(duration: 0.2)) { crossRefsAsMap.toggle() } }
                )
            )

            if crossReferences.isEmpty {
                surface { emptyNote("No cross references found for this verse.") }
            } else if crossRefsAsMap {
                CrossReferenceMapView(
                    sourceReference: verse.reference,
                    entries: crossReferences,
                    onSelect: navigateToReference
                )
            } else {
                surface {
                    ForEach(Array(crossReferences.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { rowDivider }
                        crossReferenceRow(entry)
                    }
                }
            }
        }
    }

    /// Opens the reader at a cross reference (in the current translation) and closes this sheet.
    private func navigateToReference(_ reference: String) {
        NotificationCenter.default.post(
            name: .navigateToBibleVerse,
            object: nil,
            userInfo: [
                AppNotificationUserInfoKey.reference: reference,
                AppNotificationUserInfoKey.translation: translation.rawValue
            ]
        )
        onClose?() ?? dismiss()
    }

    private func crossReferenceRow(_ entry: CrossReferenceEntry) -> some View {
        let isExpanded = expandedCrossRefs.contains(entry.reference)

        return VStack(alignment: .leading, spacing: 8) {
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
                    Text(entry.reference)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let text = crossRefPreviewText[entry.reference] {
                        Text(text.isEmpty ? "Verse text unavailable." : text)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if !text.isEmpty {
                            Button {
                                navigateToReference(entry.reference)
                            } label: {
                                Text("Open in the reader")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                    .frame(minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ProgressView()
                            .task { await loadVersePreview(entry.reference) }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 16)
    }

    private func loadVersePreview(_ reference: String) async {
        guard crossRefPreviewText[reference] == nil else { return }
        guard let parsed = BibleData.parseReference(reference) else {
            crossRefPreviewText[reference] = ""
            return
        }

        do {
            let chapterEntry = try await ChapterScrollCoordinator.performChapterFetch(
                book: parsed.book,
                chapter: parsed.chapter,
                translation: translation
            )
            crossRefPreviewText[reference] = chapterEntry.verses.first(where: { $0.number == parsed.verseStart })?.text ?? ""
        } catch {
            crossRefPreviewText[reference] = ""
        }
    }

    // MARK: - Commentary

    private var commentarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Commentary",
                action: (title: "Library", icon: "books.vertical", run: { openStudyLibrary() })
            )

            surface {
                if commentaryEntries.isEmpty && downloadableCommentaries.isEmpty {
                    emptyNote("No commentary available for this verse.")
                } else {
                    ForEach(Array(commentaryEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { rowDivider }
                        commentaryRow(entry)
                    }

                    if !downloadableCommentaries.isEmpty {
                        if !commentaryEntries.isEmpty { rowDivider }
                        downloadableCommentariesBlock
                    }
                }
            }
        }
    }

    /// The not-yet-downloaded commentaries live behind one row instead of one row each, so a verse
    /// that already has commentary is not topped up with a stack of download prompts.
    private var downloadableCommentariesBlock: some View {
        let open = showDownloadableCommentaries || commentaryEntries.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDownloadableCommentaries.toggle() }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .frame(width: 24)
                    Text(commentaryEntries.isEmpty
                         ? "Download a commentary"
                         : "\(downloadableCommentaries.count) more to download")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    if !commentaryEntries.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(commentaryEntries.isEmpty)

            if open {
                ForEach(downloadableCommentaries) { source in
                    rowDivider
                    commentaryDownloadRow(source)
                }
            }
        }
    }

    private func commentaryRow(_ entry: CommentaryEntry) -> some View {
        let isExpanded = expandedCommentaries.contains(entry.source.rawValue)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedCommentaries.remove(entry.source.rawValue) }
                    else { expandedCommentaries.insert(entry.source.rawValue) }
                }
            } label: {
                HStack {
                    Text(entry.source.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                LinkedScriptureText(text: entry.text,
                                    font: .callout,
                                    baseColor: Color.adaptiveText(colorScheme))
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 16)
    }

    private func commentaryDownloadRow(_ source: CommentarySource) -> some View {
        Button {
            if !commentaryDownloads.isBusy(source) { commentaryDownloads.download(source) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Download \u{00B7} \(CommentaryDownloadManager.formatBytes(source.approxBytes))")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                if commentaryDownloads.isBusy(source) {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Places",
                action: (title: "Atlas", icon: "map", run: {
                    atlasFocusID = nil
                    showAtlas = true
                })
            )

            surface {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(versePlaces) { place in
                        Button {
                            atlasFocusID = place.id
                            showAtlas = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.footnote)
                                Text(place.name)
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color.adaptiveNavyText(colorScheme).opacity(0.08))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Topics

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Topics")

            surface {
                VStack(alignment: .leading, spacing: 12) {
                    // Wrapped, not scrolled sideways, so every topic is visible at once,
                    // especially in the narrow iPad tools panel.
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(verseTopics, id: \.self) { topic in
                            let isExpanded = expandedTopic == topic
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedTopic = isExpanded ? nil : topic
                                }
                            } label: {
                                Text(topic.capitalized)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .background(isExpanded
                                        ? Color.adaptiveNavyText(colorScheme)
                                        : Color.adaptiveNavyText(colorScheme).opacity(0.08))
                                    .foregroundStyle(isExpanded
                                        ? Color.adaptiveCardBackground(colorScheme)
                                        : Color.adaptiveNavyText(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isExpanded ? .isSelected : [])
                        }
                    }

                    if let topic = expandedTopic {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(TopicalBibleService.shared.verses(for: topic).prefix(5).enumerated()),
                                    id: \.element.id) { index, entry in
                                if index > 0 { Divider() }
                                topicVerseRow(entry)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func topicVerseRow(_ entry: TopicalVerseEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.reference)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.reforgedGold)

            if let text = crossRefPreviewText[entry.reference] {
                Text(text.isEmpty ? "Verse text unavailable." : text)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView()
                    .task { await loadVersePreview(entry.reference) }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Study Questions

    private var studyQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Questions to reflect on")

            surface {
                if isLoadingQuestions {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                } else if studyQuestions.isEmpty {
                    emptyNote("No study questions available.")
                } else {
                    ForEach(Array(studyQuestions.enumerated()), id: \.offset) { index, question in
                        if index > 0 { rowDivider }
                        Button {
                            studyNotePrompt = IdentifiablePrompt(text: question)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "square.and.pencil")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if usingFallbackQuestions {
                        rowDivider
                        Button {
                            Task { await loadStudyQuestions() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("General questions. Tap to load ones for this verse.")
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
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
        do {
            studyQuestions = try await GeminiService.shared.generateJournalPrompts(
                reference: verse.reference,
                verseText: verse.text
            )
            usingFallbackQuestions = false
        } catch {
            // Offline or the service is down: general questions still give the reader a start.
            debugLog("[VerseStudy] questions failed: \(error)")
            studyQuestions = GeminiService.fallbackJournalPrompts
            usingFallbackQuestions = true
        }
        isLoadingQuestions = false
    }
}
