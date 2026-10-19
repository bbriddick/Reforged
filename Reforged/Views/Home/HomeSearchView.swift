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

/// Something in the app itself the user can jump to by name ("shield", "settings", "tour"…).
struct AppShortcut: Identifiable {
    enum Target { case tab(Int), journal, settings, readingPlans, podcast, disciplines, studyLibrary, tour }

    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let keywords: [String]
    let target: Target

    static let all: [AppShortcut] = [
        AppShortcut(id: "bible", title: "Bible", subtitle: "Read and study Scripture", icon: "book.fill",
                    keywords: ["bible", "read", "reader", "scripture", "chapter"], target: .tab(2)),
        AppShortcut(id: "memory", title: "Memory", subtitle: "Memorize and review verses", icon: "brain.head.profile",
                    keywords: ["memory", "memorize", "memorise", "flashcard", "review", "verse practice", "spaced"], target: .tab(3)),
        AppShortcut(id: "discipleship", title: "Discipleship", subtitle: "Shield, learning path, disciplines", icon: "shield.lefthalf.filled",
                    keywords: ["discipleship", "learning path", "lesson", "track", "learn"], target: .tab(1)),
        AppShortcut(id: "shield", title: "Focus Shield", subtitle: "Block distracting or harmful apps and sites", icon: "shield.fill",
                    keywords: ["shield", "focus", "block", "screen time", "purity", "porn", "distraction", "social media", "accountability"], target: .tab(1)),
        AppShortcut(id: "tempted", title: "I'm Being Tempted", subtitle: "Pause, breathe, take hold of Scripture", icon: "hand.raised.fill",
                    keywords: ["tempted", "temptation", "panic", "sos", "urge", "struggle"], target: .tab(1)),
        AppShortcut(id: "disciplines", title: "My Disciplines", subtitle: "Your daily habits checklist", icon: "calendar.badge.clock",
                    keywords: ["discipline", "habit", "checklist", "routine", "daily"], target: .disciplines),
        AppShortcut(id: "plans", title: "Reading Plans", subtitle: "Follow or build a plan", icon: "list.bullet.rectangle.fill",
                    keywords: ["reading plan", "plan", "bible in a year", "schedule"], target: .readingPlans),
        AppShortcut(id: "journal", title: "Notes", subtitle: "Your reflections and Bible notes", icon: "square.and.pencil",
                    keywords: ["journal", "notes", "diary", "reflect", "write"], target: .journal),
        AppShortcut(id: "podcast", title: "Walk Talks", subtitle: "Podcast episodes", icon: "headphones",
                    keywords: ["podcast", "walk talk", "walk talks", "episode", "listen", "sermon"], target: .podcast),
        AppShortcut(id: "library", title: "Study Library", subtitle: "Commentaries, dictionaries and tools", icon: "books.vertical.fill",
                    keywords: ["library", "commentary", "commentaries", "dictionary", "study", "download"], target: .studyLibrary),
        AppShortcut(id: "settings", title: "Settings", subtitle: "Translations, notifications, display, AI", icon: "gearshape.fill",
                    keywords: ["settings", "preferences", "notification", "translation", "font", "theme", "dark mode", "account", "sign in", "ai"], target: .settings),
        AppShortcut(id: "tour", title: "Take the app tour", subtitle: "A quick walkthrough of what Reforged can do", icon: "lightbulb.fill",
                    keywords: ["tour", "help", "tutorial", "how to", "walkthrough", "guide", "tips", "features"], target: .tour),
    ]

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        if title.lowercased().contains(q) { return true }
        return keywords.contains { k in
            k == q || (q.count >= 3 && k.hasPrefix(q)) || (k.contains(" ") && q.contains(k))
        }
    }
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
    @Published private(set) var books: [BibleBook] = []
    @Published private(set) var bookmarks: [VerseBookmark] = []
    @Published private(set) var plans: [BibleReadingPlan] = []
    @Published private(set) var habits: [RhythmItem] = []
    @Published private(set) var episodes: [PodcastEpisode] = []
    @Published private(set) var devotionals: [SpurgeonSearchHit] = []
    @Published private(set) var shortcuts: [AppShortcut] = []
    @Published private(set) var commentary: [CommentarySearchHit] = []
    @Published private(set) var aiOverview: SmartSearchResult?
    @Published private(set) var aiFailed = false
    @Published private(set) var isSearchingScripture = false
    @Published private(set) var isLoadingAI = false
    @Published private(set) var deepSearchQuery: String?

    private var journalCache: [JournalEntry]?
    private var scriptureTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var autoSearchTask: Task<Void, Never>?
    private var autoAITask: Task<Void, Never>?

    var hasLocalResults: Bool {
        referenceMatch != nil || !memoryVerses.isEmpty || !notes.isEmpty ||
        !journal.isEmpty || !lessons.isEmpty || !topics.isEmpty ||
        !references.isEmpty || !places.isEmpty || !books.isEmpty || !bookmarks.isEmpty ||
        !plans.isEmpty || !habits.isEmpty || !episodes.isEmpty || !devotionals.isEmpty ||
        !shortcuts.isEmpty
    }

    func updateLocal(query rawQuery: String, appState: AppState) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= 2 else {
            clear()
            return
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

        books = Array(BibleData.books.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(4))

        bookmarks = Array(BibleReadingState.shared.bookmarks.values.filter {
            $0.reference.localizedCaseInsensitiveContains(query) ||
            $0.previewText.localizedCaseInsensitiveContains(query)
        }.prefix(5))

        plans = BibleReadingPlans.everything.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }

        habits = RhythmStorageManager.shared.items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.note.localizedCaseInsensitiveContains(query)
        }

        episodes = Array((PodcastService.shared.feed?.episodes ?? []).filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }.prefix(4))

        devotionals = SpurgeonDevotionalService.shared.search(query, limit: 3)

        shortcuts = AppShortcut.all.filter { $0.matches(query) }

        scheduleAutoSearch(query: query)
    }

    /// Scripture + commentary search follows the typing (after a pause) instead of waiting for
    /// return; a conceptual question also earns an AI overview a little later. Pressing return
    /// runs everything immediately, AI included, for any query.
    private func scheduleAutoSearch(query: String) {
        autoSearchTask?.cancel()
        autoAITask?.cancel()
        guard query.count >= 3, deepSearchQuery != query else { return }

        autoSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.runDeepSearch(query: query, explicit: false)
        }
    }

    /// Scripture text, Strong's definitions, commentary and (when enabled) an AI overview.
    /// `explicit` = the user pressed return / tapped the prompt, so AI runs for any query.
    func runDeepSearch(query rawQuery: String, explicit: Bool = true) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        autoSearchTask?.cancel()
        autoAITask?.cancel()

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
            let commentary = CommentaryService.shared.search(query)
            guard !Task.isCancelled else { return }
            self?.verses = results
            self?.definitions = definitions
            self?.commentary = commentary
            self?.isSearchingScripture = false
            if explicit {
                AppState.shared.addBibleSearchHistoryEntry(query: query, scope: .allTextVersions, translation: nil)
            }
        }

        guard SettingsManager.shared.aiEnabled else { return }
        if explicit || Self.isConceptualQuery(query) {
            // Explicit → now; conceptual → give typing a beat so we don't spend a call per pause.
            if explicit {
                askAI(query: query)
            } else {
                autoAITask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    self?.askAI(query: query)
                }
            }
        }
    }

    /// Gemini overview for the query. Also reachable from the "Ask AI" row.
    func askAI(query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, SettingsManager.shared.aiEnabled else { return }
        isLoadingAI = true
        aiFailed = false
        aiTask?.cancel()
        aiTask = Task { [weak self] in
            defer { self?.isLoadingAI = false }
            do {
                let result = try await GeminiService.shared.smartBibleSearch(query: query)
                guard !Task.isCancelled else { return }
                self?.aiOverview = result
            } catch {
                guard !Task.isCancelled else { return }
                self?.aiFailed = true
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
        books = []
        bookmarks = []
        plans = []
        habits = []
        episodes = []
        devotionals = []
        shortcuts = []
        autoSearchTask?.cancel()
        autoAITask?.cancel()
        deepSearchQuery = nil
        clearDeepResults()
    }

    /// Journal is read from disk; drop the cache so an entry written elsewhere shows up.
    func invalidateJournalCache() {
        journalCache = nil
    }

    private func clearDeepResults(keepQuery: Bool = false) {
        verses = []
        definitions = []
        commentary = []
        aiOverview = nil
        aiFailed = false
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
    /// Sections the user has expanded past their first few results.
    @State private var expandedSections: Set<String> = []

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAnything: Bool {
        model.hasLocalResults || !model.verses.isEmpty || !model.definitions.isEmpty ||
        !model.commentary.isEmpty || model.aiOverview != nil || model.isSearchingScripture || model.isLoadingAI
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
                        loadingRow("Asking Gemini…")
                    } else if let overview = model.aiOverview {
                        section("AI Overview") { aiOverviewCard(overview) }
                    } else if !settings.aiEnabled {
                        hint("Turn on AI in Settings → AI to get a Gemini overview with every search.")
                    } else if model.aiFailed {
                        askAIButton(title: "Couldn't reach Gemini — try again")
                    } else {
                        askAIButton(title: "Ask AI about “\(trimmedQuery)”")
                    }

                    if !model.shortcuts.isEmpty {
                        section("In Reforged") {
                            expandable("shortcuts", model.shortcuts) { shortcut in
                                shortcutRow(shortcut)
                            }
                        }
                    }

                    if !model.books.isEmpty {
                        section("Books of the Bible") {
                            expandable("books", model.books) { book in
                                resultCard {
                                    navigate(to: "\(book.name) 1")
                                } content: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundStyle(Color.reforgedGold)
                                        Text(book.name)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                        Spacer()
                                        Text("\(book.chapters) chapters")
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        chevron
                                    }
                                }
                            }
                        }
                    }

                    if model.isSearchingScripture {
                        loadingRow("Searching Scripture…")
                    } else if !model.verses.isEmpty {
                        section("Scripture (\(model.verses.count))") {
                            expandable("verses", Array(model.verses.prefix(30)), limit: 4) { result in
                                verseRow(result)
                            }
                        }
                    }

                    if !model.definitions.isEmpty {
                        section("Word Definitions") {
                            expandable("definitions", model.definitions) { entry in
                                definitionCard(entry)
                            }
                        }
                    }

                    ForEach(model.topics) { hit in
                        section("Topic · \(hit.topic.capitalized)") {
                            expandable("topic-\(hit.topic)", hit.entries) { entry in
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
                            expandable("references", model.references) { entry in
                                DictionaryResultRow(entry: entry)
                            }
                        }
                    }

                    if !model.places.isEmpty {
                        section("Places") {
                            expandable("places", model.places) { place in
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
                            expandable("memory", model.memoryVerses) { verse in
                                resultCard {
                                    switchTab(3)
                                    // Memory may not have been opened yet this session — give it a beat to mount.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        NotificationCenter.default.post(
                                            name: .openMemoryVerse,
                                            object: nil,
                                            userInfo: [AppNotificationUserInfoKey.reference: verse.reference]
                                        )
                                    }
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
                            expandable("notes", model.notes) { note in
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
                            expandable("lessons", model.lessons) { hit in
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
                        section("Notes") {
                            expandable("journal", model.journal) { entry in
                                NavigationLink {
                                    JournalView(initialEntry: entry)
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

                    if !model.commentary.isEmpty {
                        section("Commentary") {
                            expandable("commentary", model.commentary) { hit in
                                resultCard {
                                    navigate(to: hit.reference)
                                } content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(hit.reference)
                                                .font(.subheadline).fontWeight(.bold)
                                                .foregroundStyle(Color.reforgedGold)
                                            Text(hit.source.displayName)
                                                .font(.caption2).fontWeight(.semibold)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(Color.adaptiveChipBackground(colorScheme))
                                                .clipShape(Capsule())
                                            Spacer()
                                            chevron
                                        }
                                        Text(hit.snippet)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                    }

                    if !model.devotionals.isEmpty, let plan = BibleReadingPlans.everything.first(where: { $0.id == BibleReadingPlans.spurgeonId }) {
                        section("Spurgeon · Morning & Evening") {
                            expandable("devotionals", model.devotionals) { hit in
                                NavigationLink {
                                    SpurgeonDevotionalView(plan: plan, initialDay: hit.day)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(hit.title)
                                                .font(.subheadline).fontWeight(.bold)
                                                .foregroundStyle(Color.reforgedGold)
                                            Spacer()
                                            chevron
                                        }
                                        Text(hit.snippet)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(3)
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

                    if !model.plans.isEmpty {
                        section("Reading Plans") {
                            expandable("plans", model.plans) { plan in
                                NavigationLink {
                                    if plan.isDevotional {
                                        SpurgeonDevotionalView(plan: plan)
                                    } else {
                                        ReadingPlanDetailView(plan: plan)
                                    }
                                } label: {
                                    linkLabel(icon: plan.iconName, title: plan.name, subtitle: plan.description)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !model.bookmarks.isEmpty {
                        section("Bookmarks") {
                            expandable("bookmarks", model.bookmarks) { bookmark in
                                resultCard {
                                    navigate(to: bookmark.reference)
                                } content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "bookmark.fill")
                                                .font(.caption)
                                                .foregroundStyle(Color.reforgedGold)
                                            Text(bookmark.reference)
                                                .font(.subheadline).fontWeight(.bold)
                                                .foregroundStyle(Color.reforgedGold)
                                            Spacer()
                                            chevron
                                        }
                                        Text(bookmark.previewText)
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                    }

                    if !model.habits.isEmpty {
                        section("My Disciplines") {
                            expandable("habits", model.habits) { item in
                                NavigationLink {
                                    RhythmHubView()
                                } label: {
                                    linkLabel(icon: item.iconName, title: item.title, subtitle: item.note.isEmpty ? nil : item.note)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !model.episodes.isEmpty {
                        section("Walk Talks") {
                            expandable("episodes", model.episodes) { episode in
                                NavigationLink {
                                    PodcastView(initialEpisodeID: episode.id)
                                } label: {
                                    linkLabel(icon: "headphones", title: episode.title, subtitle: episode.duration)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !hasAnything {
                        hint("Nothing matches “\(trimmedQuery)” yet.")
                    }
                }
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    // MARK: Pieces

    /// A result list that shows only its first few rows, with a control to reveal the rest —
    /// so a broad query doesn't bury everything else under one long section.
    @ViewBuilder
    private func expandable<Item: Identifiable, Row: View>(
        _ key: String,
        _ items: [Item],
        limit: Int = 3,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        let isOpen = expandedSections.contains(key)
        let shown = isOpen ? items : Array(items.prefix(limit))
        ForEach(shown) { item in row(item) }

        if items.count > limit {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isOpen { expandedSections.remove(key) } else { expandedSections.insert(key) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isOpen ? "Show less" : "Show \(items.count - limit) more")
                        .font(.caption.weight(.semibold))
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Color.reforgedGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private func askAIButton(title: String) -> some View {
        Button {
            model.askAI(query: trimmedQuery)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.reforgedGold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                chevron
            }
            .padding()
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    private func linkLabel(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
            chevron
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
    }

    @ViewBuilder
    private func shortcutRow(_ shortcut: AppShortcut) -> some View {
        switch shortcut.target {
        case .journal:
            NavigationLink { JournalView() } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .settings:
            NavigationLink { SettingsView().environmentObject(appState) } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .readingPlans:
            NavigationLink { ReadingPlansView() } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .podcast:
            NavigationLink { PodcastView() } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .disciplines:
            NavigationLink { RhythmHubView() } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .tab(let tab):
            Button { switchTab(tab) } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .studyLibrary:
            Button {
                switchTab(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .openStudyLibrary, object: nil)
                }
            } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        case .tour:
            Button { AppTour.shared.start() } label: { shortcutLabel(shortcut) }.buttonStyle(.plain)
        }
    }

    private func shortcutLabel(_ shortcut: AppShortcut) -> some View {
        linkLabel(icon: shortcut.icon, title: shortcut.title, subtitle: shortcut.subtitle)
    }

    private func switchTab(_ tab: Int) {
        NotificationCenter.default.post(
            name: .switchTab,
            object: nil,
            userInfo: [AppNotificationUserInfoKey.tab: tab]
        )
    }

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
                expandable("aiVerses", Array(result.verses.prefix(5)), limit: 3) { verse in
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
