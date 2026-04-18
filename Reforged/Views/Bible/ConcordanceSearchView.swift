import SwiftUI

// MARK: - Concordance Search View

enum ConcordanceSearchMode: String, CaseIterable, Identifiable {
    case strongsNumber = "Strong's"
    case originalForm = "Original"
    case lexicalForm = "Lexical"
    case kjvTranslations = "KJV"

    var id: String { rawValue }
}

/// Shows all occurrences of a Hebrew/Greek word across the Bible.
struct ConcordanceSearchView: View {
    let strongsNumber: String
    let originalWord: String
    let lexicalForm: String
    let englishWord: String
    let isHebrew: Bool
    let occurrenceCount: Int
    let translationCounts: [(word: String, count: Int)]
    var initialMode: ConcordanceSearchMode = .strongsNumber
    var onSelectResult: ((BibleSearchResult) -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var results: [BibleSearchResult] = []
    @State private var isSearching = false
    @State private var searchedTerms: [String] = []
    @State private var selectedCategory: BookCategory? = nil
    @State private var errorMessage: String? = nil
    @State private var selectedMode: ConcordanceSearchMode = .strongsNumber

    // Cached derived state — rebuilt only when results or selectedCategory changes
    @State private var cachedFilteredResults: [BibleSearchResult] = []
    @State private var cachedCategoryCounts: [BookCategory: Int] = [:]

    // Sorted once to avoid O(n log n) on every book lookup
    private static let sortedBooks = BibleData.books.sorted { $0.name.count > $1.name.count }

    private func rebuildCaches() {
        var counts: [BookCategory: Int] = [:]
        var filtered: [BibleSearchResult] = []
        for result in results {
            let cat = Self.sortedBooks.first(where: { result.reference.hasPrefix($0.name) })?.category
            if let cat { counts[cat, default: 0] += 1 }
            if selectedCategory == nil || cat == selectedCategory {
                filtered.append(result)
            }
        }
        cachedCategoryCounts = counts
        cachedFilteredResults = filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isSearching {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.reforgedGold)
                    Text(searchingMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else if results.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
            } else {
                resultsList
            }
        }
        .background(Color.adaptiveBackground(colorScheme))
        .navigationTitle("All Occurrences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedMode = availableModes.contains(initialMode) ? initialMode : (availableModes.first ?? .kjvTranslations)
        }
        .task {
            await performConcordanceSearch()
        }
        .onChange(of: selectedMode) { _ in
            Task {
                await performConcordanceSearch()
            }
        }
        .onChange(of: results) { _ in rebuildCaches() }
        .onChange(of: selectedCategory) { _ in rebuildCaches() }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !strongsNumber.isEmpty {
                    Text(strongsNumber)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(0.2))
                        .foregroundStyle(Color.reforgedGold)
                        .clipShape(Capsule())
                }

                Text(isHebrew ? "Hebrew" : "Greek")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.adaptiveNavyText(colorScheme).opacity(0.12))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .clipShape(Capsule())

                Spacer()

                if occurrenceCount > 0 && selectedMode == .strongsNumber {
                    Text("\(occurrenceCount) tagged")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else if !results.isEmpty {
                    Text("\(results.count) verses found")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            if availableModes.count > 1 {
                Picker("Search Mode", selection: $selectedMode) {
                    ForEach(availableModes) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !originalWord.isEmpty || !lexicalForm.isEmpty {
                HStack(spacing: 6) {
                    Text(displayForm)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    if !englishWord.isEmpty {
                        Text("(\u{201C}\(englishWord)\u{201D})")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            if !searchedTerms.isEmpty {
                HStack(spacing: 4) {
                    Text("Searched:")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    FlowLayout(spacing: 4) {
                        ForEach(searchedTerms, id: \.self) { term in
                            Text(term)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.adaptiveNavyText(colorScheme).opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                    }
                }
            }

            if !results.isEmpty {
                categoryFilterChips
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.adaptiveCardBackground(colorScheme))
    }

    private var displayForm: String {
        switch selectedMode {
        case .lexicalForm:
            return lexicalForm.isEmpty ? originalWord : lexicalForm
        default:
            return originalWord.isEmpty ? lexicalForm : originalWord
        }
    }

    private var availableModes: [ConcordanceSearchMode] {
        var modes: [ConcordanceSearchMode] = []
        if !strongsNumber.isEmpty { modes.append(.strongsNumber) }
        if !originalWord.isEmpty { modes.append(.originalForm) }
        if !lexicalForm.isEmpty && lexicalForm != originalWord { modes.append(.lexicalForm) }
        if !translationCounts.isEmpty || !englishWord.isEmpty { modes.append(.kjvTranslations) }
        return modes.isEmpty ? [.kjvTranslations] : modes
    }

    private var searchingMessage: String {
        switch selectedMode {
        case .strongsNumber:
            return "Searching tagged occurrences…"
        case .originalForm:
            return "Searching original-language text…"
        case .lexicalForm:
            return "Searching lexical form…"
        case .kjvTranslations:
            return "Searching KJV usage…"
        }
    }

    // MARK: - Category Filter

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    selectedCategory = nil
                } label: {
                    Text("All (\(results.count))")
                        .font(.caption2)
                        .fontWeight(selectedCategory == nil ? .bold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedCategory == nil ? Color.reforgedGold.opacity(0.2) : Color.adaptiveNavyText(colorScheme).opacity(0.08))
                        .foregroundStyle(selectedCategory == nil ? Color.reforgedGold : Color.adaptiveText(colorScheme))
                        .clipShape(Capsule())
                }

                ForEach(BookCategory.allCases, id: \.self) { category in
                    let count = cachedCategoryCounts[category] ?? 0
                    if count > 0 {
                        Button {
                            selectedCategory = selectedCategory == category ? nil : category
                        } label: {
                            Text("\(category.rawValue) (\(count))")
                                .font(.caption2)
                                .fontWeight(selectedCategory == category ? .bold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedCategory == category ? Color.reforgedGold.opacity(0.2) : Color.adaptiveNavyText(colorScheme).opacity(0.08))
                                .foregroundStyle(selectedCategory == category ? Color.reforgedGold : Color.adaptiveText(colorScheme))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }


    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(cachedFilteredResults) { result in
                    ConcordanceResultRow(
                        result: result,
                        highlightWords: searchedTerms,
                        colorScheme: colorScheme,
                        onTap: {
                            onSelectResult?(result)
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Search Logic

    private func performConcordanceSearch() async {
        isSearching = true
        errorMessage = nil
        selectedCategory = nil

        let sorted: [BibleSearchResult]

        switch selectedMode {
        case .strongsNumber, .originalForm, .lexicalForm:
            sorted = sortInBibleOrder(await StrongsLexiconService.shared.searchOriginalLanguageOccurrences(
                strongsNumber: strongsNumber,
                originalWord: originalWord,
                lexicalForm: lexicalForm,
                isHebrew: isHebrew,
                mode: selectedMode
            ))
            await MainActor.run {
                searchedTerms = searchLabels(for: selectedMode)
                appState.addBibleSearchHistoryEntry(
                    query: searchLabels(for: selectedMode).first ?? displayForm,
                    scope: historyScope(for: selectedMode),
                    translation: selectedMode == .kjvTranslations ? .kjv : nil
                )
            }

        case .kjvTranslations:
            let terms = buildKJVSearchTerms()
            await MainActor.run {
                searchedTerms = terms
                if let primaryTerm = terms.first {
                    appState.addBibleSearchHistoryEntry(query: primaryTerm, scope: .kjvUsage, translation: .kjv)
                }
            }

            guard !terms.isEmpty else {
                await MainActor.run {
                    isSearching = false
                    errorMessage = "No KJV search terms were available for this study result."
                }
                return
            }

            var allResults: [String: BibleSearchResult] = [:]
            for term in terms {
                let kjvResults = await KJVService.shared.searchPassages(query: term, pageSize: 100)
                for result in kjvResults {
                    allResults[result.id] = result
                }
            }
            sorted = sortInBibleOrder(Array(allResults.values))
        }

        await MainActor.run {
            results = sorted
            isSearching = false
            if results.isEmpty {
                errorMessage = emptyStateMessage
            }
        }
    }

    private var emptyStateMessage: String {
        switch selectedMode {
        case .strongsNumber:
            return "No occurrences were found for this Strong's entry."
        case .originalForm:
            return "No occurrences were found for this original word form."
        case .lexicalForm:
            return "No occurrences were found for this lexical form."
        case .kjvTranslations:
            return "No KJV verses were found for these study terms."
        }
    }

    private func searchLabels(for mode: ConcordanceSearchMode) -> [String] {
        switch mode {
        case .strongsNumber:
            return strongsNumber.isEmpty ? [] : [strongsNumber]
        case .originalForm:
            return originalWord.isEmpty ? [] : [originalWord]
        case .lexicalForm:
            return lexicalForm.isEmpty ? [] : [lexicalForm]
        case .kjvTranslations:
            return buildKJVSearchTerms()
        }
    }

    private func historyScope(for mode: ConcordanceSearchMode) -> BibleSearchHistoryScope {
        switch mode {
        case .strongsNumber: return .strongsNumber
        case .originalForm: return .originalForm
        case .lexicalForm: return .lexicalForm
        case .kjvTranslations: return .kjvUsage
        }
    }

    private func buildKJVSearchTerms() -> [String] {
        var terms: [String] = []

        if !translationCounts.isEmpty {
            terms.append(contentsOf: translationCounts
                .sorted { $0.count > $1.count }
                .prefix(5)
                .map(\.word)
                .map { $0.lowercased() }
                .filter { !$0.isEmpty && $0 != "miscellaneous" && $0.count > 1 })
        }

        if terms.isEmpty && !englishWord.isEmpty {
            terms.append(englishWord.lowercased())
        }

        var uniqueTerms: [String] = []
        for term in terms where !uniqueTerms.contains(term) {
            uniqueTerms.append(term)
        }
        return uniqueTerms
    }

    /// Sorts search results in canonical Bible order.
    /// Pre-computes book metadata for each result before sorting to avoid O(n × 66) inside the comparator.
    private func sortInBibleOrder(_ results: [BibleSearchResult]) -> [BibleSearchResult] {
        let bookOrder = Dictionary(uniqueKeysWithValues: BibleData.books.enumerated().map { ($1.name, $0) })

        struct Annotated {
            let result: BibleSearchResult
            let order: Int
            let chapter: Int
            let verse: Int
        }

        let annotated = results.map { r -> Annotated in
            let bookName = Self.sortedBooks.first(where: { r.reference.hasPrefix($0.name) })?.name ?? ""
            let order = bookOrder[bookName] ?? 99
            let cv = extractChapterVerse(from: r.reference, bookName: bookName)
            return Annotated(result: r, order: order, chapter: cv.chapter, verse: cv.verse)
        }

        return annotated.sorted { a, b in
            if a.order != b.order { return a.order < b.order }
            if a.chapter != b.chapter { return a.chapter < b.chapter }
            return a.verse < b.verse
        }.map(\.result)
    }

    private func extractChapterVerse(from reference: String, bookName: String) -> (chapter: Int, verse: Int) {
        let afterBook = reference.dropFirst(bookName.count).trimmingCharacters(in: .whitespaces)
        let parts = afterBook.components(separatedBy: ":")
        let chapter = Int(parts.first ?? "0") ?? 0
        let verse = parts.count > 1 ? (Int(parts[1].components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "0") ?? 0) : 0
        return (chapter, verse)
    }
}

// MARK: - Concordance Result Row

struct ConcordanceResultRow: View {
    let result: BibleSearchResult
    let highlightWords: [String]
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.reference)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.reforgedGold)

                Spacer()

                Text(result.translation.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.adaptiveNavyText(colorScheme).opacity(0.1))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .clipShape(Capsule())
            }

            if let metadata = result.metadata, !metadata.isEmpty {
                Text(metadata)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            highlightedText
                .font(.caption)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    private var highlightedText: Text {
        let content = result.content
        guard !content.isEmpty, !highlightWords.isEmpty else {
            return Text(content)
        }

        let lowered = content.lowercased()
        var highlights: [(range: Range<String.Index>, word: String)] = []

        for term in highlightWords {
            let searchTerm = term.lowercased()
            var searchStart = lowered.startIndex
            while searchStart < lowered.endIndex {
                guard let range = lowered.range(of: searchTerm, range: searchStart..<lowered.endIndex) else { break }

                let beforeOK = range.lowerBound == lowered.startIndex || !lowered[lowered.index(before: range.lowerBound)].isLetter
                let afterOK = range.upperBound == lowered.endIndex || !lowered[range.upperBound].isLetter

                if beforeOK && afterOK {
                    highlights.append((range: range, word: String(content[range])))
                }

                searchStart = range.upperBound
            }
        }

        highlights.sort { $0.range.lowerBound < $1.range.lowerBound }

        var filtered: [(range: Range<String.Index>, word: String)] = []
        for hl in highlights {
            if let last = filtered.last, hl.range.lowerBound < last.range.upperBound {
                continue
            }
            filtered.append(hl)
        }

        var resultText = Text("")
        var current = content.startIndex

        for hl in filtered {
            if current < hl.range.lowerBound {
                resultText = resultText + Text(String(content[current..<hl.range.lowerBound]))
            }
            resultText = resultText + Text(String(content[hl.range]))
                .foregroundColor(Color.reforgedGold)
            current = hl.range.upperBound
        }

        if current < content.endIndex {
            resultText = resultText + Text(String(content[current..<content.endIndex]))
        }

        return resultText
    }
}
