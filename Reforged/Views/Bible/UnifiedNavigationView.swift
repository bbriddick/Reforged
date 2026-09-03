import SwiftUI

// MARK: - Unified Navigation View (3D Sidebar)

struct UnifiedNavigationView: View {
    @Binding var selectedBook: BibleBook
    @Binding var selectedChapter: Int
    var recentPassages: [(book: String, chapter: Int)]
    @Binding var isPresented: Bool
    let onSelect: () -> Void
    var onSelectVerse: ((Int) -> Void)? = nil
    var translation: BibleTranslation = .esv
    var translationOrder: [BibleTranslation] = BibleTranslation.allCases
    var focusSearch: Bool = false
    var onDismiss: (() -> Void)? = nil
    /// When presented as a sheet (iPad/Mac), the system supplies the top safe-area inset,
    /// so we skip the manual status-bar spacer used by the iPhone overlay.
    var usesSheetPresentation: Bool = false
    @ObservedObject private var olService = OriginalLanguageService.shared
    @Environment(\.colorScheme) var colorScheme 
    @FocusState private var searchFieldFocused: Bool

    enum SortOrder { case traditional, alphabetical }

    @State private var searchText = ""
    @State private var selectedTestament: BibleBook.Testament? = nil
    @State private var expandedBookID: String? = nil
    @State private var sortOrder: SortOrder = .traditional
    @State private var showVersePicker = false
    @State private var chapterVerses: [ParsedVerse] = []
    @State private var isLoadingVerses = false

    // Full-text search state
    @State private var navSearchResults: [BibleSearchResult] = []
    @State private var navSearchHistory: [BibleSearchHistoryEntry] = []
    @State private var navIsSearching = false
    @State private var navSelectedVersion: BibleTranslation? = nil
    @State private var navSelectedCategory: BookCategory? = nil
    @State private var navSmartResult: SmartSearchResult? = nil
    @State private var navSmartLoading = false
    @State private var navSmartVerseFilter: String = "All"
    @State private var navCachedFiltered: [BibleSearchResult] = []
    @State private var navCachedCategoryCounts: [BookCategory: Int] = [:]
    @State private var navCachedVersionCounts: [BibleTranslation: Int] = [:]
    @State private var navSelectedBook: String? = nil
    @State private var navCachedBookCounts: [String: Int] = [:]
    @ObservedObject private var settingsMgr = SettingsManager.shared

    private func dismiss() {
        if let d = onDismiss { d() } else { isPresented = false }
    }

    private func isConceptualQuery(_ q: String) -> Bool {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        if q.contains("?") { return true }
        let starters = ["what ", "who ", "how ", "why ", "when ", "where ",
                        "does ", "is ", "are ", "can ", "should ", "will "]
        if starters.contains(where: { q.hasPrefix($0) }) { return true }
        return q.split(separator: " ").count >= 4
    }

    private func extractBookName(from reference: String) -> String {
        for book in BibleData.books.sorted(by: { $0.name.count > $1.name.count }) {
            if reference.hasPrefix(book.name + " ") { return book.name }
        }
        let parts = reference.components(separatedBy: " ")
        return parts.count > 1 ? parts.dropLast().joined(separator: " ") : reference
    }

    private func rebuildNavCaches() {
        var catCounts: [BookCategory: Int] = [:]
        var verCounts: [BibleTranslation: Int] = [:]
        var bookCounts: [String: Int] = [:]
        var filtered: [BibleSearchResult] = []

        for result in navSearchResults {
            let cat = SearchPanelView.bookCategoryStatic(for: result.reference)
            verCounts[result.translation, default: 0] += 1
            let verMatch = navSelectedVersion == nil || result.translation == navSelectedVersion
            if verMatch, let cat { catCounts[cat, default: 0] += 1 }
            let catMatch = navSelectedCategory == nil || cat == navSelectedCategory
            if verMatch && catMatch {
                let bookName = extractBookName(from: result.reference)
                bookCounts[bookName, default: 0] += 1
            }
            let bookMatch = navSelectedBook == nil || extractBookName(from: result.reference) == navSelectedBook
            if verMatch && catMatch && bookMatch { filtered.append(result) }
        }

        navCachedCategoryCounts = catCounts
        navCachedVersionCounts = verCounts
        navCachedBookCounts = bookCounts
        navCachedFiltered = filtered
    }

    func navPerformSearch() {
        guard !searchText.isEmpty, parsedReference == nil else { return }
        navSelectedCategory = nil
        navSelectedBook = nil
        navIsSearching = true
        navSmartResult = nil
        navSmartLoading = false
        navSmartVerseFilter = "All"
        navSearchResults = []
        navCachedFiltered = []
        let query = searchText
        let versions = navSelectedVersion.map { [$0] } ?? BibleTranslation.searchableTextVersions
        if settingsMgr.aiEnabled && isConceptualQuery(query) {
            navSmartLoading = true
            Task {
                do {
                    let r = try await GeminiService.shared.smartBibleSearch(query: query)
                    await MainActor.run { navSmartResult = r; navSmartLoading = false }
                } catch {
                    await MainActor.run { navSmartLoading = false }
                }
            }
        }
        Task {
            let results = await BibleSearchService.shared.unifiedSearch(query: query, translations: versions)
            await MainActor.run {
                navSearchResults = results
                navIsSearching = false
                AppState.shared.addBibleSearchHistoryEntry(query: query, scope: navSelectedVersion == nil ? .allTextVersions : .textVersion, translation: navSelectedVersion)
                navSearchHistory = AppState.shared.loadBibleSearchHistory()
                rebuildNavCaches()
            }
        }
    }

    struct ParsedBibleRef {
        let book: BibleBook
        let chapter: Int
        let verse: Int?

        var displayString: String {
            if let verse { return "\(book.name) \(chapter):\(verse)" }
            return "\(book.name) \(chapter)"
        }
    }

    var parsedReference: ParsedBibleRef? {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        let sorted = BibleData.books.sorted { $0.name.count > $1.name.count }

        for book in sorted {
            for candidate in [book.name.lowercased(), book.abbreviation.lowercased()] {
                guard lower.hasPrefix(candidate) else { continue }
                let afterBook = lower.dropFirst(candidate.count)
                guard let first = afterBook.first, first.isWhitespace else { continue }
                let rest = afterBook.trimmingCharacters(in: .whitespaces)
                guard !rest.isEmpty else { break }

                let colonIdx = rest.firstIndex(of: ":")
                let chapterPart: String
                let versePart: String?
                if let colon = colonIdx {
                    chapterPart = String(rest[rest.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                    versePart = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    chapterPart = rest
                    versePart = nil
                }

                guard let chapter = Int(chapterPart), chapter >= 1, chapter <= book.chapters else { break }
                let verse = versePart.flatMap { Int($0) }
                return ParsedBibleRef(book: book, chapter: chapter, verse: verse)
            }
        }
        return nil
    }

    var filteredBooks: [BibleBook] {
        var books = BibleData.books

        if let testament = selectedTestament {
            books = books.filter { $0.testament == testament }
        }

        if !searchText.isEmpty {
            if let ref = parsedReference {
                books = books.filter { $0.id == ref.book.id }
            } else {
                books = books.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if sortOrder == .alphabetical {
            books = books.sorted { $0.name < $1.name }
        }

        return books
    }

    // MARK: - Body

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.statusBarManager?.statusBarFrame.height ?? 54
    }

    /// The iPhone overlay ignores the safe area, so it doesn't inherit the floating
    /// tab bar's bottom inset the way regular tab content does. Reserve the home-indicator
    /// inset plus the tab bar height so the last list rows clear the tab bar.
    private var bottomListInset: CGFloat {
        guard !usesSheetPresentation else { return 0 }
        let safeBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 34
        return safeBottom + 56
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // iPhone overlay ignores the safe area, so reserve the status-bar height
                // ourselves. The sheet presentation (iPad/Mac) gets this from the system.
                if !usesSheetPresentation {
                    Color.adaptiveCardBackground(colorScheme)
                        .frame(height: statusBarHeight)
                }

                // ── Minimal floating close — replaces the former title bar ──
                closeButtonRow

                // ── Search bar + recents + reference jump ───────────────
                searchSection

                // ── Content ─────────────────────────────────────────────
                if navIsSearching || !navSearchResults.isEmpty || navSmartLoading || navSmartResult != nil {
                    navSearchResultsView
                } else {
                    booksView
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                if searchFieldFocused { searchFieldFocused = false }
                            }
                        )
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))

            // ── Verse picker bottom sheet ────────────────────────────────
            if showVersePicker {
                versePickerSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onAppear {
            navSearchHistory = AppState.shared.loadBibleSearchHistory()
            navSelectedVersion = translation.isTextSearchable ? translation : nil
            if focusSearch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    searchFieldFocused = true
                }
            }
        }
        .onChange(of: navSearchResults) { _ in rebuildNavCaches() }
        .onChange(of: navSelectedCategory) { _ in navSelectedBook = nil; rebuildNavCaches() }
        .onChange(of: navSelectedVersion) { _ in navSelectedBook = nil; navSelectedCategory = nil; rebuildNavCaches() }
        .onChange(of: navSelectedBook) { _ in rebuildNavCaches() }
    }

    // MARK: - Close Button

    /// A small, unobtrusive close affordance that replaces the old title bar.
    /// No background fill or divider — just a hairline-stroked glyph.
    private var closeButtonRow: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, usesSheetPresentation ? 4 : 8)
        .padding(.bottom, 2)
    }

    // MARK: - Search Section

    @ViewBuilder
    private var searchSection: some View {
        VStack(spacing: 0) {
            // Recent passages — collapses when search is focused
            if !recentPassages.isEmpty && searchText.isEmpty && navSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(recentPassages.prefix(5).enumerated()), id: \.offset) { _, passage in
                                Button {
                                    if let book = BibleData.books.first(where: { $0.name == passage.book }) {
                                        selectedBook = book
                                        selectedChapter = passage.chapter
                                        dismiss()
                                        onSelect()
                                    }
                                } label: {
                                    Text("\(passage.book) \(passage.chapter)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.adaptiveChipBackground(colorScheme))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 10)
                .opacity(searchFieldFocused ? 0 : 1)
                .frame(height: searchFieldFocused ? 0 : nil)
                .clipped()
                .animation(.spring(response: 0.3), value: searchFieldFocused)
            }

            // Search bar
            let showAI = settingsMgr.aiEnabled && isConceptualQuery(searchText)
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: showAI ? "sparkles" : "magnifyingglass")
                        .foregroundStyle(showAI ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
                        .animation(.easeInOut(duration: 0.2), value: showAI)

                    TextField("Search verses, books, or references…", text: $searchText)
                        .font(.subheadline)
                        .focused($searchFieldFocused)
                        .onSubmit {
                            searchFieldFocused = false
                            navPerformSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            navSearchResults = []
                            navSmartResult = nil
                            navIsSearching = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.adaptiveTertiaryBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if searchFieldFocused || !navSearchResults.isEmpty || navIsSearching {
                    Button("Cancel") {
                        searchText = ""
                        navSearchResults = []
                        navSmartResult = nil
                        navIsSearching = false
                        navSmartLoading = false
                        searchFieldFocused = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.reforgedGold)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .animation(.spring(response: 0.3), value: searchFieldFocused)

            // Reference jump row
            if let ref = parsedReference {
                Button {
                    selectedBook = ref.book
                    selectedChapter = ref.chapter
                    if let verse = ref.verse, let selectVerse = onSelectVerse {
                        // Verse target: route ONLY through the verse handler so it establishes the focused
                        // chapter and lets hydration complete before scrolling. Calling onSelect() first
                        // would fire a competing chapter-top loadChapter().
                        dismiss()
                        selectVerse(verse)
                    } else {
                        dismiss()
                        onSelect()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.reforgedGold)
                        Text("Go to \(ref.displayString)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(colorScheme == .dark ? Color.adaptiveTertiaryBackground(colorScheme) : Color.reforgedGold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Full-text search button
            if !searchText.isEmpty && parsedReference == nil {
                Button {
                    searchFieldFocused = false
                    navPerformSearch()
                } label: {
                    HStack(spacing: 6) {
                        if showAI { Image(systemName: "sparkles").font(.subheadline) }
                        Text(navSelectedVersion == nil ? "Search All Versions" : "Search \(navSelectedVersion!.rawValue)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(showAI ? Color.reforgedGold : Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .animation(.easeInOut(duration: 0.15), value: showAI)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Recent searches — when field focused and empty
            if searchFieldFocused && searchText.isEmpty && navSearchResults.isEmpty && !navSearchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent Searches")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 4)

                    ForEach(navSearchHistory.prefix(5)) { entry in
                        Button {
                            searchText = entry.query
                            navSelectedVersion = entry.scope == .textVersion ? entry.translation : nil
                            navPerformSearch()
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.query).font(.subheadline)
                                    Text(entry.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                        }
                    }

                    Divider().padding(.top, 6)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3), value: searchText.isEmpty)
    }

    // MARK: - Search Results

    private func collapseSearch() {
        withAnimation(.spring(response: 0.3)) {
            searchText = ""
            navSearchResults = []
            navSmartResult = nil
            navIsSearching = false
            navSmartLoading = false
            searchFieldFocused = false
        }
    }

    @ViewBuilder
    private var navSearchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if navSmartLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                    }
                    .padding(.top, 30)
                }

                if navIsSearching && navSearchResults.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Searching…")
                        Spacer()
                    }
                    .padding(.top, navSmartLoading ? 16 : 30)
                }

                if let smart = navSmartResult {
                    navSmartCard(smart)
                }

                if !navSearchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(title: "All", isSelected: navSelectedVersion == nil) {
                                navSelectedVersion = nil; navSelectedCategory = nil
                            }
                            ForEach(BibleTranslation.searchableTextVersions) { ver in
                                let cnt = navCachedVersionCounts[ver] ?? 0
                                if cnt > 0 {
                                    FilterChip(title: "\(ver.rawValue) (\(cnt))", isSelected: navSelectedVersion == ver) {
                                        navSelectedVersion = ver; navSelectedCategory = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 4)

                    if !navCachedCategoryCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(navCachedCategoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        navSelectedCategory = navSelectedCategory == category ? nil : category
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(category.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .frame(width: 100, alignment: .trailing)
                                        GeometryReader { geo in
                                            let maxCount = navCachedCategoryCounts.values.max() ?? 1
                                            let barWidth = max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(navSelectedCategory == category
                                                    ? Color.reforgedGold
                                                    : (colorScheme == .dark ? Color.adaptiveChipBackground(colorScheme) : Color.reforgedNavy))
                                                .frame(width: barWidth)
                                        }
                                        .frame(height: 14)
                                        Text("\(count)")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.adaptiveBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                FilterChip(title: "All", isSelected: navSelectedCategory == nil) {
                                    navSelectedCategory = nil
                                }
                                ForEach(BookCategory.allCases) { cat in
                                    let count = navCachedCategoryCounts[cat] ?? 0
                                    if count > 0 {
                                        FilterChip(title: cat.rawValue, isSelected: navSelectedCategory == cat) {
                                            navSelectedCategory = cat
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 4)

                        if navSelectedCategory != nil && navCachedBookCounts.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    FilterChip(title: "All Books", isSelected: navSelectedBook == nil) {
                                        navSelectedBook = nil
                                    }
                                    ForEach(navCachedBookCounts.sorted(by: { $0.value > $1.value }), id: \.key) { bookName, count in
                                        FilterChip(title: "\(bookName) (\(count))", isSelected: navSelectedBook == bookName) {
                                            navSelectedBook = bookName
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 4)
                        }
                    }

                    let countLabel = navSelectedBook.map { "\(navCachedFiltered.count) verses in \($0)" }
                        ?? navSelectedCategory.map { "\(navCachedFiltered.count) verses in \($0.rawValue)" }
                        ?? "\(navSearchResults.count) verses across \(navCachedVersionCounts.filter { $0.value > 0 }.count) versions"
                    Text(countLabel)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 16)

                    if navCachedFiltered.isEmpty {
                        Text("No results in this category")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(navCachedFiltered) { result in
                            Button {
                                navigateToResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
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
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .background(Color.reforgedGold.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    Text(result.content)
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.adaptiveTertiaryBackground(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, bottomListInset)
        }
    }

    private func navSmartCard(_ result: SmartSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption.bold()).foregroundStyle(Color.reforgedGold)
                Text("AI Overview").font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text("Gemini").font(.caption2).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 14)
            Text(result.explanation.isEmpty ? result.summary : result.explanation)
                .font(.subheadline).foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(3).padding(14)
            if !result.verses.isEmpty {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Verses").font(.caption).fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    ForEach(result.verses.prefix(3)) { verse in
                        Button {
                            navigateToResult(BibleSearchResult(reference: verse.reference, content: verse.text, translation: translation))
                        } label: {
                            HStack {
                                Text(verse.reference).font(.caption).fontWeight(.bold).foregroundStyle(Color.reforgedGold)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .background(Color.adaptiveTertiaryBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func navigateToResult(_ result: BibleSearchResult) {
        let parts = result.reference.components(separatedBy: " ")
        var bookName = ""
        var chapterVerse = ""
        for (i, part) in parts.enumerated() {
            if part.contains(":") || (Int(part.prefix(while: { $0.isNumber })) != nil && i == parts.count - 1) {
                chapterVerse = part; break
            } else {
                if !bookName.isEmpty { bookName += " " }
                bookName += part
            }
        }
        guard let book = BibleData.books.first(where: { $0.name == bookName }) else { return }
        selectedBook = book
        let cvParts = chapterVerse.components(separatedBy: ":")
        selectedChapter = Int(cvParts.first ?? "") ?? 1
        dismiss()
        // Verse target → verse handler alone (it focuses the chapter and scrolls after hydration); a bare
        // chapter (or no verse handler) → chapter-top onSelect(). Never both, to avoid racing loadChapters.
        if cvParts.count > 1,
           let verseNum = Int(cvParts[1].components(separatedBy: "-").first ?? ""),
           let selectVerse = onSelectVerse {
            selectVerse(verseNum)
        } else {
            onSelect()
        }
    }

    // MARK: - Books View

    @ViewBuilder
    private var booksView: some View {
        VStack(spacing: 0) {
            // Testament filter + sort — compact inline row
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedTestament == nil) {
                    selectedTestament = nil
                }
                FilterChip(title: "OT", isSelected: selectedTestament == .old) {
                    selectedTestament = .old
                }
                FilterChip(title: "NT", isSelected: selectedTestament == .new) {
                    selectedTestament = .new
                }
                Spacer()
                Menu {
                    Picker("Sort order", selection: $sortOrder) {
                        Text("Traditional").tag(SortOrder.traditional)
                        Text("A–Z").tag(SortOrder.alphabetical)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        Text(sortOrder == .alphabetical ? "A–Z" : "Order")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.adaptiveChipBackground(colorScheme))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Book list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredBooks) { book in
                            VStack(spacing: 0) {
                                // Book row
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        expandedBookID = expandedBookID == book.id ? nil : book.id
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(book.name)
                                            .font(.body)
                                            .fontWeight(book.id == selectedBook.id ? .bold : .regular)
                                            .foregroundStyle(book.id == selectedBook.id ? Color.reforgedGold : Color.adaptiveText(colorScheme))

                                        Spacer()

                                        if translation == .esv {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        }

                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                            .rotationEffect(.degrees(expandedBookID == book.id ? 180 : 0))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .id(book.id)

                                // Expanded chapter grid
                                if expandedBookID == book.id {
                                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(1...book.chapters, id: \.self) { chapter in
                                            Button {
                                                selectedBook = book
                                                selectedChapter = chapter
                                                let incompatible =
                                                    ((translation == .tr || translation == .sblgnt) && book.testament == .old) ||
                                                    (translation == .wlc && book.testament == .new)
                                                if incompatible {
                                                    dismiss()
                                                    onSelect()
                                                } else {
                                                    loadVersesForChapter()
                                                    withAnimation(.spring(response: 0.3)) {
                                                        showVersePicker = true
                                                    }
                                                }
                                            } label: {
                                                let isActive = book.id == selectedBook.id && chapter == selectedChapter
                                                Text("\(chapter)")
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(isActive ? .white : Color.adaptiveText(colorScheme))
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 44)
                                                    .background(isActive ? Color.reforgedGold : Color.adaptiveTertiaryBackground(colorScheme))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(isActive ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)), lineWidth: 0.5)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                if filteredBooks.last?.id != book.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }

                        // Clear the floating tab bar so the last books (Jude, Revelation) aren't hidden.
                        Color.clear.frame(height: bottomListInset)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .onAppear {
                    let bookID = selectedBook.id
                    expandedBookID = bookID
                    // Jump straight to the current book — no scroll animation.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(bookID, anchor: .center)
                    }
                }
                .onChange(of: expandedBookID) { newID in
                    if let newID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { proxy.scrollTo(newID, anchor: .top) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Verse Picker (bottom sheet overlay inside sidebar)

    @ViewBuilder
    private var versePickerSheet: some View {
        VStack(spacing: 0) {
            // Drag handle + back button
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showVersePicker = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                        Text("Back")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.reforgedGold)
                }

                Spacer()

                Text("\(selectedBook.name) \(selectedChapter)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                // Go to chapter start
                Button {
                    dismiss()
                    onSelect()
                } label: {
                    Text("Go")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.reforgedGold)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Verse grid
            let waitingForOL = (translation == .tr     && !olService.trReady  && selectedBook.testament == .new)
                            || (translation == .sblgnt && !olService.sblReady && selectedBook.testament == .new)
                            || (translation == .wlc    && !olService.wlcReady && selectedBook.testament == .old)

            if isLoadingVerses || waitingForOL {
                Spacer()
                ProgressView("Loading verses…")
                Spacer()
                    .onChange(of: olService.trReady) { isReady in
                        if isReady && translation == .tr { loadVersesForChapter() }
                    }
                    .onChange(of: olService.sblReady) { isReady in
                        if isReady && translation == .sblgnt { loadVersesForChapter() }
                    }
                    .onChange(of: olService.wlcReady) { isReady in
                        if isReady && translation == .wlc { loadVersesForChapter() }
                    }
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(chapterVerses) { verse in
                            Button {
                                dismiss()
                                // Verse handler alone — it focuses the chapter and scrolls after hydration.
                                // onSelect() would fire a competing chapter-top loadChapter().
                                if let selectVerse = onSelectVerse {
                                    selectVerse(verse.number)
                                } else {
                                    onSelect()
                                }
                            } label: {
                                Text("\(verse.number)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.adaptiveTertiaryBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.clear, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxHeight: AppWindow.height * 0.55)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
        // Soft elevation shadow cast upward, matching the app's bottom-sheet style
        // (see TakeNoteView). Opacity adapts so it stays visible in dark mode.
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15), radius: 20, y: -5)
    }

    // MARK: - Load Verses

    func loadVersesForChapter() {
        isLoadingVerses = true
        chapterVerses = []
        Task {
            do {
                var fetchedVerses: [ParsedVerse] = []
                switch translation {
                case .esv:
                    let result = try await ESVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .kjv:
                    let result = try await KJVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .net:
                    let result = try await NETService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
                case .tr:
                    if selectedBook.testament == .new {
                        OriginalLanguageService.shared.preloadTR()
                        let bookNum = OriginalLanguageService.bookNumber(for: selectedBook.name) ?? 0
                        let trVerses = OriginalLanguageService.shared.trChapter(bookNumber: bookNum, chapter: selectedChapter)
                        fetchedVerses = trVerses.map { v in
                            let ref = "\(selectedBook.name) \(selectedChapter):\(v.verse)"
                            return ParsedVerse(id: ref, number: v.verse, text: "", reference: ref)
                        }
                    }
                case .sblgnt:
                    if selectedBook.testament == .new {
                        OriginalLanguageService.shared.preloadSBLGNT()
                        let bookNum = OriginalLanguageService.bookNumber(for: selectedBook.name) ?? 0
                        let sblVerses = OriginalLanguageService.shared.sblChapter(bookNumber: bookNum, chapter: selectedChapter)
                        fetchedVerses = sblVerses.map { v in
                            let ref = "\(selectedBook.name) \(selectedChapter):\(v.verse)"
                            return ParsedVerse(id: ref, number: v.verse, text: v.text, reference: ref)
                        }
                    }
                case .wlc:
                    if selectedBook.testament == .old {
                        OriginalLanguageService.shared.preloadWLC()
                        let bookNum = OriginalLanguageService.bookNumber(for: selectedBook.name) ?? 0
                        let wlcVerses = OriginalLanguageService.shared.wlcChapter(bookNumber: bookNum, chapter: selectedChapter)
                        fetchedVerses = wlcVerses.map { v in
                            let ref = "\(selectedBook.name) \(selectedChapter):\(v.verse)"
                            return ParsedVerse(id: ref, number: v.verse, text: "", reference: ref)
                        }
                    }
                }
                await MainActor.run {
                    chapterVerses = fetchedVerses
                    isLoadingVerses = false
                }
            } catch {
                await MainActor.run { isLoadingVerses = false }
            }
        }
    }
}
