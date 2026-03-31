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
    @Binding var searchHistory: [String]
    var recentPassages: [(book: String, chapter: Int)]
    @Binding var isSearching: Bool
    @Binding var isPresented: Bool
    let onSelectResult: (BibleSearchResult) -> Void
    let onSelectRecent: (String, Int) -> Void
    var translation: BibleTranslation = .esv
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FocusState private var isSearchFocused: Bool
    @State private var selectedCategory: BookCategory? = nil

    /// Determine which BookCategory a verse reference belongs to.
    ///
    /// Books are checked longest-name-first so that e.g. "1 John" matches before
    /// the plain "John" entry.  A space is appended to every prefix to guarantee
    /// a word-boundary match ("John " won't accidentally absorb "Johnny…").
    /// Known API spelling variants (e.g. ESV returns "Psalm" not "Psalms",
    /// "Song of Songs" vs "Song of Solomon") are handled explicitly.
    private func bookCategory(for reference: String) -> BookCategory? {
        // Sort longest name first to prevent short names swallowing longer ones
        let sortedBooks = BibleData.books.sorted { $0.name.count > $1.name.count }
        for book in sortedBooks {
            // Match on full name or abbreviation, both with a trailing space guard
            if reference.hasPrefix(book.name + " ") ||
               reference.hasPrefix(book.abbreviation + " ") {
                return book.category
            }
        }
        // ESV (and most APIs) use "Psalm" (singular); our data has "Psalms"
        if reference.hasPrefix("Psalm ") { return .poetryWisdom }
        // Some translations use "Song of Songs" instead of "Song of Solomon"
        if reference.hasPrefix("Song of Songs ") { return .poetryWisdom }
        return nil
    }

    /// Filter search results by book category
    var filteredResults: [BibleSearchResult] {
        guard let category = selectedCategory else { return searchResults }
        return searchResults.filter { bookCategory(for: $0.reference) == category }
    }

    /// Count results per book category for the chart
    var categoryCounts: [BookCategory: Int] {
        var counts: [BookCategory: Int] = [:]
        for cat in BookCategory.allCases {
            counts[cat] = searchResults.filter { bookCategory(for: $0.reference) == cat }.count
        }
        return counts
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

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        TextField("Search verses...", text: $searchQuery)
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
                            Text("Search \(translation.rawValue)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding()
                    }

                    // Category summary + filter chips
                    if !searchResults.isEmpty {
                        // Result count summary
                        Text("\(searchResults.count) verses in \(translation.rawValue). Tap chart to filter.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.horizontal)
                            .padding(.top, 4)

                        // Category breakdown chart
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(categoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
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
                                                let maxCount = categoryCounts.values.max() ?? 1
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
                                    let count = categoryCounts[cat] ?? 0
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
                            if isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView("Searching...")
                                    Spacer()
                                }
                                .padding(.top, 40)
                            } else if !searchResults.isEmpty {
                                // Results
                                if filteredResults.isEmpty {
                                    Text("No results in this category")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        .padding(.top, 20)
                                        .frame(maxWidth: .infinity)
                                }
                                ForEach(filteredResults) { result in
                                    Button {
                                        onSelectResult(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(result.reference)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(Color.reforgedGold)
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

                                    ForEach(searchHistory.prefix(5), id: \.self) { query in
                                        Button {
                                            searchQuery = query
                                            performSearch()
                                        } label: {
                                            HStack {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .font(.caption)
                                                Text(query)
                                                    .font(.subheadline)
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
        }
    }

    func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        selectedCategory = nil

        Task {
            do {
                var results: [BibleSearchResult] = []
                switch translation {
                case .esv:
                    let esvResults = try await ESVService.shared.searchPassages(query: searchQuery, pageSize: 100)
                    results = esvResults.map { BibleSearchResult(reference: $0.reference, content: $0.content) }
                case .kjv:
                    // KJV doesn't have a search API - fall back to ESV search
                    let esvResults = try await ESVService.shared.searchPassages(query: searchQuery, pageSize: 100)
                    results = esvResults.map { BibleSearchResult(reference: $0.reference, content: $0.content) }
                case .csb, .nkjv, .nasb, .rvr1960:
                    let apiResults = try await ApiBibleService.shared.searchPassages(query: searchQuery, translation: translation, pageSize: 100)
                    results = apiResults.map { BibleSearchResult(reference: $0.reference, content: $0.text) }
                case .tr, .wlc:
                    break  // search not supported for original languages
                }
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
}
