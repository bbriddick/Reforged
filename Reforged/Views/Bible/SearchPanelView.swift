import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.adaptiveNavyText(colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Search Panel View

struct SearchPanelView: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [BibleSearchResult]
    @Binding var searchHistory: [BibleSearchHistoryEntry]
    var recentPassages: [(book: String, chapter: Int)]
    @Binding var isSearching: Bool
    @Binding var isPresented: Bool
    let onSelectResult: (BibleSearchResult) -> Void
    let onSelectRecent: (String, Int) -> Void
    var translation: BibleTranslation = .esv
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var settings = SettingsManager.shared
    @FocusState private var isSearchFocused: Bool
    @State private var selectedCategory: BookCategory? = nil
    @State private var selectedVersion: BibleTranslation? = nil

    // Cached computed results — rebuilt only when inputs change, not on every render
    @State private var cachedFilteredResults: [BibleSearchResult] = []
    @State private var cachedCategoryCounts: [BookCategory: Int] = [:]
    @State private var cachedVersionCounts: [BibleTranslation: Int] = [:]

    // Smart Search (AI)
    private enum SearchMode { case text, smart }
    @State private var searchMode: SearchMode = .text
    @State private var smartSearchResult: SmartSearchResult? = nil
    @State private var smartSearchLoading = false
    @State private var smartVerseFilter: String = "All"   // "All", "OT", "NT"

    // Sorted once at struct level to avoid O(n log n) per lookup
    private static let sortedBooks = BibleData.books.sorted { $0.name.count > $1.name.count }

    /// Determine which BookCategory a verse reference belongs to.
    ///
    /// Books are checked longest-name-first so that e.g. "1 John" matches before
    /// the plain "John" entry.  A space is appended to every prefix to guarantee
    /// a word-boundary match ("John " won't accidentally absorb "Johnny…").
    /// Known API spelling variants (e.g. ESV returns "Psalm" not "Psalms",
    /// "Song of Songs" vs "Song of Solomon") are handled explicitly.
    private func bookCategory(for reference: String) -> BookCategory? {
        for book in Self.sortedBooks {
            if reference.hasPrefix(book.name + " ") ||
               reference.hasPrefix(book.abbreviation + " ") {
                return book.category
            }
        }
        if reference.hasPrefix("Psalm ") { return .poetryWisdom }
        if reference.hasPrefix("Song of Songs ") { return .poetryWisdom }
        return nil
    }

    /// Rebuilds all derived caches in a single O(n) pass over searchResults.
    /// Call whenever searchResults, selectedCategory, or selectedVersion changes.
    private func rebuildCaches() {
        var catCounts: [BookCategory: Int] = [:]
        var verCounts: [BibleTranslation: Int] = [:]
        var filtered: [BibleSearchResult] = []

        for result in searchResults {
            let cat = bookCategory(for: result.reference)

            // versionCounts: unfiltered count per translation
            verCounts[result.translation, default: 0] += 1

            // categoryCounts: grouped by category, filtered by selectedVersion only
            let versionMatch = selectedVersion == nil || result.translation == selectedVersion
            if versionMatch, let cat {
                catCounts[cat, default: 0] += 1
            }

            // filteredResults: filtered by both selectedVersion and selectedCategory
            let catMatch = selectedCategory == nil || cat == selectedCategory
            if versionMatch && catMatch {
                filtered.append(result)
            }
        }

        cachedCategoryCounts = catCounts
        cachedVersionCounts = verCounts
        cachedFilteredResults = filtered
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent tap-to-dismiss area
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35)) {
                            isPresented = false
                        }
                    }

                // Panel
                let availableWidth = geometry.size.width
                let panelWidth: CGFloat = horizontalSizeClass == .regular
                    ? min(380, availableWidth * 0.55)
                    : availableWidth * 0.85
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Search")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                    .padding()

                    // Search mode picker — AI Smart Search toggle
                    if settings.aiEnabled {
                        Picker("Search Mode", selection: $searchMode) {
                            Text("Text").tag(SearchMode.text)
                            Label("Smart", systemImage: "sparkles").tag(SearchMode.smart)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .onChange(of: searchMode) { _ in
                            smartSearchResult = nil
                            searchResults = []
                        }
                    }

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: searchMode == .smart ? "sparkles" : "magnifyingglass")
                            .foregroundStyle(searchMode == .smart ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))

                        TextField(searchMode == .smart ? "Ask anything biblical..." : "Search verses...", text: $searchQuery)
                            .font(.subheadline)
                            .focused($isSearchFocused)
                            .onSubmit {
                                performSearch()
                            }

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.adaptiveBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Search button
                    if !searchQuery.isEmpty {
                        Button {
                            performSearch()
                        } label: {
                            HStack(spacing: 6) {
                                if searchMode == .smart {
                                    Image(systemName: "sparkles")
                                }
                                Text(searchMode == .smart
                                     ? "Smart Search"
                                     : (selectedVersion == nil ? "Search All Versions" : "Search \(selectedVersion?.rawValue ?? translation.rawValue)"))
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(searchMode == .smart ? Color.reforgedGold : Color.reforgedNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding()
                    }

                    // Category summary + filter chips
                    if !searchResults.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                FilterChip(title: "All Versions", isSelected: selectedVersion == nil) {
                                    selectedVersion = nil
                                    selectedCategory = nil
                                }
                                ForEach(BibleTranslation.searchableTextVersions) { version in
                                    let count = cachedVersionCounts[version] ?? 0
                                    if count > 0 {
                                        FilterChip(title: "\(version.rawValue) (\(count))", isSelected: selectedVersion == version) {
                                            selectedVersion = version
                                            selectedCategory = nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 4)

                        // Result count summary
                        Text(selectedVersion == nil
                             ? "\(searchResults.count) verses across \(cachedVersionCounts.filter { $0.value > 0 }.count) versions. Tap chart to filter."
                             : "\(cachedFilteredResults.count) verses in \(selectedVersion?.rawValue ?? translation.rawValue). Tap chart to filter.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.horizontal)
                            .padding(.top, 4)

                        // Category breakdown chart
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(cachedCategoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                                if count > 0 {
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCategory = selectedCategory == category ? nil : category
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(category.rawValue)
                                                .font(.caption2)
                                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                                .frame(width: 100, alignment: .trailing)

                                            GeometryReader { geo in
                                                let maxCount = cachedCategoryCounts.values.max() ?? 1
                                                let barWidth = max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(selectedCategory == category ? Color.reforgedGold : Color.reforgedNavy)
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
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.adaptiveBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Book category filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                                    selectedCategory = nil
                                }
                                ForEach(BookCategory.allCases) { cat in
                                    let count = cachedCategoryCounts[cat] ?? 0
                                    if count > 0 {
                                        FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                            selectedCategory = cat
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 4)
                    }

                    // Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if smartSearchLoading {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("Thinking...")
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    Spacer()
                                }
                                .padding(.top, 40)
                            } else if let smartResult = smartSearchResult {
                                smartSearchResultCard(smartResult)
                            }

                            if isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView("Searching...")
                                    Spacer()
                                }
                                .padding(.top, 40)
                            } else if !searchResults.isEmpty {
                                // Results
                                if cachedFilteredResults.isEmpty {
                                    Text("No results in this category")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        .padding(.top, 20)
                                        .frame(maxWidth: .infinity)
                                }
                                ForEach(cachedFilteredResults) { result in
                                    Button {
                                        onSelectResult(result)
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
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
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
                                        .background(Color.adaptiveBackground(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            } else {
                                // Search history
                                if !searchHistory.isEmpty {
                                    Text("Recent Searches")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                                    ForEach(searchHistory.prefix(5)) { entry in
                                        Button {
                                            searchQuery = entry.query
                                            selectedVersion = entry.scope == .textVersion ? entry.translation : nil
                                            performSearch()
                                        } label: {
                                            HStack(alignment: .center) {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .font(.caption)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(entry.query)
                                                        .font(.subheadline)
                                                    Text(entry.subtitle)
                                                        .font(.caption2)
                                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                                }
                                                Spacer()
                                            }
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }

                                // Recent passages
                                if !recentPassages.isEmpty {
                                    Text("Recent Passages")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        .padding(.top, 8)

                                    ForEach(recentPassages.prefix(5), id: \.book) { passage in
                                        Button {
                                            onSelectRecent(passage.book, passage.chapter)
                                        } label: {
                                            HStack {
                                                Image(systemName: "book")
                                                    .font(.caption)
                                                Text("\(passage.book) \(passage.chapter)")
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(width: panelWidth)
                .frame(maxHeight: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 4, y: 0)

                Spacer()
            }
        }
        }
        .onAppear {
            isSearchFocused = true
            selectedVersion = translation.isTextSearchable ? translation : nil
            rebuildCaches()
        }
        .onChange(of: searchResults) { _ in rebuildCaches() }
        .onChange(of: selectedCategory) { _ in rebuildCaches() }
        .onChange(of: selectedVersion) { _ in rebuildCaches() }
    }

    @ViewBuilder
    func smartSearchResultCard(_ result: SmartSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(Color.reforgedGold)
                Text("AI Overview")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text("Gemini")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            // ── Explanation ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Label("Explanation", systemImage: "text.alignleft")
                    .font(.caption.bold())
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Text(result.explanation.isEmpty ? result.summary : result.explanation)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 14)

            // ── Word Usage ──────────────────────────────────────────
            if !result.wordUsage.isEmpty || !result.strongsNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Word Usage", systemImage: "character.book.closed")
                        .font(.caption.bold())
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    if !result.wordUsage.isEmpty {
                        Text(result.wordUsage)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !result.strongsNumbers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(result.strongsNumbers, id: \.self) { number in
                                    Text(number)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.reforgedNavy.opacity(0.1))
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 14)
            }

            // ── Example Verses ──────────────────────────────────────
            if !result.verses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Example Verses", systemImage: "book.closed")
                            .font(.caption.bold())
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Spacer()
                        // OT / NT filter
                        HStack(spacing: 4) {
                            ForEach(["All", "OT", "NT"], id: \.self) { filter in
                                Button {
                                    smartVerseFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(smartVerseFilter == filter
                                                    ? Color.reforgedNavy
                                                    : Color.adaptiveBackground(colorScheme))
                                        .foregroundStyle(smartVerseFilter == filter
                                                         ? Color.white
                                                         : Color.adaptiveTextSecondary(colorScheme))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    let filtered = result.verses.filter {
                        smartVerseFilter == "All" || $0.testament == smartVerseFilter
                    }

                    if filtered.isEmpty {
                        Text("No \(smartVerseFilter) verses for this topic.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    } else {
                        ForEach(filtered) { verse in
                            Button {
                                onSelectResult(BibleSearchResult(
                                    reference: verse.reference,
                                    content: verse.text,
                                    translation: translation
                                ))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(verse.reference)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.reforgedGold)
                                        Text(verse.testament)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.adaptiveBackground(colorScheme))
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                            .clipShape(Capsule())
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    Text(verse.text)
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.adaptiveBackground(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 14)
            }

            // ── Also Try ────────────────────────────────────────────
            if !result.relatedTerms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Also try:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(result.relatedTerms, id: \.self) { term in
                                Button {
                                    searchQuery = term
                                    searchMode = .text
                                    performSearch()
                                } label: {
                                    Text(term)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.reforgedGold.opacity(0.12))
                                        .foregroundStyle(Color.reforgedGold)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
        )
    }

    func performSearch() {
        guard !searchQuery.isEmpty else { return }
        selectedCategory = nil

        if searchMode == .smart {
            performSmartSearch()
            return
        }

        isSearching = true
        let versions = selectedVersion.map { [$0] } ?? BibleTranslation.searchableTextVersions

        Task {
            let results = await BibleSearchService.shared.search(query: searchQuery, translations: versions, pageSizePerTranslation: 100)
            await MainActor.run {
                searchResults = results
                isSearching = false
                let scope: BibleSearchHistoryScope = selectedVersion == nil ? .allTextVersions : .textVersion
                AppState.shared.addBibleSearchHistoryEntry(query: searchQuery, scope: scope, translation: selectedVersion)
                searchHistory = AppState.shared.loadBibleSearchHistory()
            }
        }
    }

    private func performSmartSearch() {
        smartSearchLoading = true
        smartSearchResult = nil
        smartVerseFilter = "All"
        searchResults = []

        Task {
            do {
                let aiResult = try await GeminiService.shared.smartBibleSearch(query: searchQuery)
                await MainActor.run { smartSearchResult = aiResult }
            } catch {
                print("[SmartSearch] ❌ Error: \(error)")
            }
            await MainActor.run { smartSearchLoading = false }
        }
    }
}
