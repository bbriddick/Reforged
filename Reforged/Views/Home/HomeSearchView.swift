import SwiftUI

// MARK: - Result wrappers

struct LessonSearchHit: Identifiable {
    let id: String
    let trackName: String
    let lesson: Lesson
}

struct TopicSearchHit: Identifiable {
    var id: String { topic }
    let topic: String
    let entries: [TopicalVerseEntry]
}

// MARK: - Model

/// Backs the pull-down search bar on Home.
///
/// Local sections (memory verses, notes, journal, lessons, topics) filter on every
/// keystroke — they're plain string matches over data already in memory. Scripture
/// text search, the Strong's dictionary scan, and the AI overview only run on submit:
/// the first two are network/CPU heavy and the third costs a Gemini call.
@MainActor
final class HomeSearchModel: ObservableObject {
    @Published private(set) var referenceMatch: String?
    @Published private(set) var memoryVerses: [MemoryVerse] = []
    @Published private(set) var notes: [VerseNote] = []
    @Published private(set) var journal: [JournalEntry] = []
    @Published private(set) var lessons: [LessonSearchHit] = []
    @Published private(set) var topics: [TopicSearchHit] = []
    @Published private(set) var references: [ReferenceEntry] = []
    @Published private(set) var places: [BiblePlace] = []
    @Published private(set) var definitions: [StrongsEntry] = []
    @Published private(set) var verses: [BibleSearchResult] = []
    @Published private(set) var aiOverview: SmartSearchResult?
    @Published private(set) var isSearchingScripture = false
    @Published private(set) var isLoadingAI = false
    @Published private(set) var deepSearchQuery: String?

    private var journalCache: [JournalEntry]?
    private var scriptureTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?

    var hasLocalResults: Bool {
        referenceMatch != nil || !memoryVerses.isEmpty || !notes.isEmpty ||
        !journal.isEmpty || !lessons.isEmpty || !topics.isEmpty ||
        !references.isEmpty || !places.isEmpty
    }

    func updateLocal(query rawQuery: String, appState: AppState) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= 2 else {
            clear()
            return
        }

        // A submitted deep search stays on screen only while its query is still typed.
        if let deep = deepSearchQuery, deep != query {
            clearDeepResults()
        }

        referenceMatch = BibleData.parseReference(query) != nil ? query : nil

        memoryVerses = appState.memoryVerses.filter {
            $0.reference.localizedCaseInsensitiveContains(query) ||
            $0.text.localizedCaseInsensitiveContains(query)
        }

        notes = BibleReadingState.shared.allNotes.filter {
            $0.reference.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query)
        }

        if journalCache == nil {
            journalCache = JournalStorageManager.shared.loadEntries()
        }
        journal = (journalCache ?? []).filter {
            $0.renderedContentText.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }

        lessons = appState.tracks.flatMap { track in
            track.lessons
                .filter {
                    $0.title.localizedCaseInsensitiveContains(query) ||
                    $0.description.localizedCaseInsensitiveContains(query)
                }
                .map { LessonSearchHit(id: $0.id, trackName: track.name, lesson: $0) }
        }

        topics = TopicalBibleService.shared.matchingTopics(for: query, limit: 3).map {
            TopicSearchHit(topic: $0, entries: Array(TopicalBibleService.shared.verses(for: $0).prefix(6)))
        }

        references = ReferenceWorkService.shared.search(query, limit: 4)
        places = BiblePlaceService.shared.search(query, limit: 4)
    }

    /// Scripture text + Strong's definitions + AI overview. Submit-only.
    func runDeepSearch(query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }

        deepSearchQuery = query
        clearDeepResults(keepQuery: true)

        isSearchingScripture = true
        scriptureTask?.cancel()
        scriptureTask = Task { [weak self] in
            let results = await BibleSearchService.shared.unifiedSearch(
                query: query,
                translations: BibleTranslation.searchableTextVersions
            )
            let definitions = Self.lookUpDefinitions(for: query)
            guard !Task.isCancelled else { return }
            self?.verses = results
            self?.definitions = definitions
            self?.isSearchingScripture = false
            AppState.shared.addBibleSearchHistoryEntry(query: query, scope: .allTextVersions, translation: nil)
        }

        guard SettingsManager.shared.aiEnabled, Self.isConceptualQuery(query) else { return }
        isLoadingAI = true
        aiTask?.cancel()
        aiTask = Task { [weak self] in
            defer { self?.isLoadingAI = false }
            do {
                let result = try await GeminiService.shared.smartBibleSearch(query: query)
                guard !Task.isCancelled else { return }
                self?.aiOverview = result
            } catch {
                debugLog("[HomeSearch] AI overview failed: \(error)")
            }
        }
    }

    func clear() {
        scriptureTask?.cancel()
        aiTask?.cancel()
        referenceMatch = nil
        memoryVerses = []
        notes = []
        journal = []
        lessons = []
        topics = []
        references = []
        places = []
        clearDeepResults()
    }

    /// Journal is read from disk; drop the cache so an entry written elsewhere shows up.
    func invalidateJournalCache() {
        journalCache = nil
    }

    private func clearDeepResults(keepQuery: Bool = false) {
        verses = []
        definitions = []
        aiOverview = nil
        isSearchingScripture = false
        isLoadingAI = false
        if !keepQuery { deepSearchQuery = nil }
    }

    /// Single-word queries get a lexicon lookup; anything longer isn't a word study.
    private static func lookUpDefinitions(for query: String) -> [StrongsEntry] {
        let word = query.trimmingCharacters(in: .whitespaces)
        guard word.count >= 3, !word.contains(" ") else { return [] }
        let hebrew = StrongsLexiconService.shared.searchByEnglishWord(word, isHebrew: true)
        let greek = StrongsLexiconService.shared.searchByEnglishWord(word, isHebrew: false)
        return Array(greek.prefix(3)) + Array(hebrew.prefix(3))
    }

    private static func isConceptualQuery(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.contains("?") { return true }
        let starters = ["what ", "who ", "how ", "why ", "when ", "where ",
                        "does ", "is ", "are ", "can ", "should ", "will "]
        if starters.contains(where: { q.hasPrefix($0) }) { return true }
        return q.split(separator: " ").count >= 4
    }
}

// MARK: - Results

struct HomeSearchResultsView: View {
    let query: String
    @ObservedObject var model: HomeSearchModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @ObservedObject private var settings = SettingsManager.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAnything: Bool {
        model.hasLocalResults || !model.verses.isEmpty || !model.definitions.isEmpty ||
        model.aiOverview != nil || model.isSearchingScripture || model.isLoadingAI
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingM) {
                if trimmedQuery.count < 2 {
                    hint("Keep typing to search.")
                } else {
                    if model.deepSearchQuery != trimmedQuery {
                        scriptureSearchPrompt
                    }

                    if let reference = model.referenceMatch {
                        section("Go To") {
                            resultCard {
                                navigate(to: reference)
                            } content: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                    Text(reference)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Spacer()
                                    chevron
                                }
                            }
                        }
                    }

                    if model.isLoadingAI {
                        loadingRow("Thinking…")
                    } else if let overview = model.aiOverview {
                        section("AI Overview") { aiOverviewCard(overview) }
                    }

                    if model.isSearchingScripture {
                        loadingRow("Searching Scripture…")
                    } else if !model.verses.isEmpty {
                        section("Scripture (\(model.verses.count))") {
                            ForEach(model.verses.prefix(30)) { result in
                                verseRow(result)
                            }
                        }
                    }

                    if !model.definitions.isEmpty {
                        section("Word Definitions") {
                            ForEach(model.definitions) { entry in
                                definitionCard(entry)
                            }
                        }
                    }

                    ForEach(model.topics) { hit in
                        section("Topic · \(hit.topic.capitalized)") {
                            ForEach(hit.entries) { entry in
                                resultCard {
                                    navigate(to: entry.reference)
                                } content: {
                                    HStack(spacing: 8) {
                                        Text(entry.reference)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.reforgedGold)
                                        Text("\(entry.votes) votes")
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        Spacer()
                                        chevron
                                    }
                                }
                            }
                            Text("Ranked by community votes · openbible.info (CC BY)")
                                .font(.caption2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }

                    if !model.references.isEmpty {
                        section("Dictionary & Topics") {
                            ForEach(model.references) { entry in
                                DictionaryResultRow(entry: entry)
                            }
                        }
                    }

                    if !model.places.isEmpty {
                        section("Places") {
                            ForEach(model.places) { place in
                                resultCard {
                                    if let first = place.verses.first { navigate(to: first) }
                                } content: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.5))
                                        Text(place.name)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                        Spacer()
                                        Text("\(place.verses.count) verse\(place.verses.count == 1 ? "" : "s")")
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        chevron
                                    }
                                }
                            }
                        }
                    }

                    if !model.memoryVerses.isEmpty {
                        section("Memory Verses") {
                            ForEach(model.memoryVerses) { verse in
                                resultCard {
                                    NotificationCenter.default.post(
                                        name: .switchTab,
                                        object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 3]
                                    )
                                } content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(verse.reference)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.reforgedGold)
                                            Text(verse.levelName)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.adaptiveChipBackground(colorScheme))
                                                .clipShape(Capsule())
                                            Spacer()
                                            chevron
                                        }
                                        Text(verse.text)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                    }

                    if !model.notes.isEmpty {
                        section("My Notes") {
                            ForEach(model.notes) { note in
                                resultCard {
                                    navigate(to: note.reference)
                                } content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(note.reference)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.reforgedGold)
                                            Spacer()
                                            chevron
                                        }
                                        Text(note.content)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                    }

                    if !model.lessons.isEmpty {
                        section("Lessons") {
                            ForEach(model.lessons) { hit in
                                NavigationLink {
                                    LessonView(lesson: hit.lesson)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(hit.lesson.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                            Spacer()
                                            chevron
                                        }
                                        Text(hit.trackName)
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !model.journal.isEmpty {
                        section("Journal") {
                            ForEach(model.journal) { entry in
                                NavigationLink {
                                    JournalView()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(entry.date)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                            Spacer()
                                            chevron
                                        }
                                        Text(entry.renderedContentText)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !hasAnything {
                        hint("Nothing saved matches “\(trimmedQuery)”. Press return to search all Bible versions.")
                    }
                }
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    // MARK: Pieces

    private var scriptureSearchPrompt: some View {
        Button {
            model.runDeepSearch(query: trimmedQuery)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: settings.aiEnabled ? "sparkles" : "magnifyingglass")
                    .foregroundStyle(Color.reforgedGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search Scripture for “\(trimmedQuery)”")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("All versions, related verses, and word meanings")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                chevron
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func verseRow(_ result: BibleSearchResult) -> some View {
        resultCard {
            navigate(to: result.reference, translation: result.translation)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(result.reference)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedGold)
                    Text(result.translation.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Capsule())
                    if result.isSemantic {
                        Label("Related", systemImage: "wand.and.stars")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.reforgedGold.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    chevron
                }
                Text(result.content)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func definitionCard(_ entry: StrongsEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.lemma)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(entry.transliteration)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text("\(entry.languageLabel) · \(entry.number)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.adaptiveChipBackground(colorScheme))
                    .clipShape(Capsule())
            }
            Text(entry.shortDefinition.isEmpty ? entry.definition : entry.shortDefinition)
                .font(.caption)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            if !entry.usage.isEmpty {
                Text("KJV: \(entry.usage)")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
    }

    @ViewBuilder
    private func aiOverviewCard(_ result: SmartSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.explanation.isEmpty ? result.summary : result.explanation)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !result.verses.isEmpty {
                ForEach(result.verses.prefix(5)) { verse in
                    Button {
                        navigate(to: verse.reference)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(verse.reference)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.reforgedGold)
                                Spacer()
                                chevron
                            }
                            Text(verse.text)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.adaptiveBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Gemini")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
        )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            content()
        }
    }

    private func resultCard<Content: View>(action: @escaping () -> Void,
                                           @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    private func loadingRow(_ label: String) -> some View {
        HStack {
            Spacer()
            ProgressView(label)
                .font(.caption)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
    }

    private func navigate(to reference: String, translation: BibleTranslation? = nil) {
        NotificationCenter.default.post(
            name: .navigateToBibleVerse,
            object: nil,
            userInfo: [
                AppNotificationUserInfoKey.reference: reference,
                AppNotificationUserInfoKey.translation: (translation ?? settings.defaultTranslation).rawValue
            ]
        )
    }
}

// MARK: - Dictionary result row

/// A dictionary/lexicon/topical hit in the Home search results. Tapping opens the full entry.
private struct DictionaryResultRow: View {
    let entry: ReferenceEntry
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.15))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.headword)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(entry.work.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }

                Text(entry.text)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ReferenceEntryDetailView(entry: entry)
        }
    }
}
