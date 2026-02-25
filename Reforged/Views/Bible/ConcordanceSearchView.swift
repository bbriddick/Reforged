import SwiftUI

// MARK: - Concordance Search View

/// Shows all occurrences of a Hebrew/Greek word across the Bible.
/// Searches by Strong's number English translations or by the word itself.
struct ConcordanceSearchView: View {
    let strongsNumber: String
    let originalWord: String
    let lexicalForm: String
    let englishWord: String
    let isHebrew: Bool
    let occurrenceCount: Int
    let translationCounts: [(word: String, count: Int)]

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var results: [BibleSearchResult] = []
    @State private var isSearching = false
    @State private var searchedTerms: [String] = []
    @State private var selectedCategory: BookCategory? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header info
            headerBar

            if isSearching {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.reforgedGold)
                    Text("Searching the Bible…")
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
        .task {
            await performConcordanceSearch()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Strong's badge
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

                // Language badge
                Text(isHebrew ? "Hebrew" : "Greek")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.adaptiveNavyText(colorScheme).opacity(0.12))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .clipShape(Capsule())

                Spacer()

                if !results.isEmpty {
                    Text("\(results.count) verses found")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            // Original word + definition context
            if !originalWord.isEmpty || !lexicalForm.isEmpty {
                HStack(spacing: 6) {
                    Text(lexicalForm.isEmpty ? originalWord : lexicalForm)
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

            // Search terms used
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

            // Category filter chips (when results available)
            if !results.isEmpty {
                categoryFilterChips
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.adaptiveCardBackground(colorScheme))
    }

    // MARK: - Category Filter

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" chip
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
                    let count = countForCategory(category)
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

    private func countForCategory(_ category: BookCategory) -> Int {
        let booksInCategory = BibleData.books.filter { $0.category == category }.map { $0.name }
        return results.filter { result in
            booksInCategory.contains { bookName in
                result.reference.hasPrefix(bookName)
            }
        }.count
    }

    private var filteredResults: [BibleSearchResult] {
        guard let category = selectedCategory else { return results }
        let booksInCategory = BibleData.books.filter { $0.category == category }.map { $0.name }
        return results.filter { result in
            booksInCategory.contains { bookName in
                result.reference.hasPrefix(bookName)
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(filteredResults) { result in
                    ConcordanceResultRow(
                        result: result,
                        highlightWords: searchedTerms,
                        colorScheme: colorScheme
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

        // Build search terms from translation counts (most common English words for this Strong's number)
        var terms: [String] = []

        // Use the top translation words if available
        if !translationCounts.isEmpty {
            // Take the top 3-5 most frequent translations
            let topTranslations = translationCounts
                .sorted { $0.count > $1.count }
                .prefix(5)
                .map { $0.word.lowercased() }
                .filter { !$0.isEmpty && $0 != "miscellaneous" && $0.count > 1 }

            terms.append(contentsOf: topTranslations)
        }

        // If no translation counts, use the English word itself
        if terms.isEmpty && !englishWord.isEmpty {
            terms.append(englishWord.lowercased())
        }

        // Deduplicate
        var uniqueTerms: [String] = []
        for term in terms {
            if !uniqueTerms.contains(term) {
                uniqueTerms.append(term)
            }
        }

        guard !uniqueTerms.isEmpty else {
            await MainActor.run {
                isSearching = false
                errorMessage = "No English translations available to search."
            }
            return
        }

        await MainActor.run {
            searchedTerms = uniqueTerms
        }

        // Search for each term and merge results (deduplicating by reference)
        var allResults: [String: BibleSearchResult] = [:]

        for term in uniqueTerms {
            do {
                let esvResults = try await ESVService.shared.searchPassages(query: term, pageSize: 100)
                for esvResult in esvResults {
                    if allResults[esvResult.reference] == nil {
                        allResults[esvResult.reference] = BibleSearchResult(
                            reference: esvResult.reference,
                            content: esvResult.content
                        )
                    }
                }
            } catch {
                print("ConcordanceSearch: Failed to search for '\(term)': \(error)")
            }
        }

        // Sort results in Bible order
        let sorted = sortInBibleOrder(Array(allResults.values))

        await MainActor.run {
            results = sorted
            isSearching = false
            if results.isEmpty {
                errorMessage = "No verses found containing these words."
            }
        }
    }

    /// Sorts search results in canonical Bible order.
    private func sortInBibleOrder(_ results: [BibleSearchResult]) -> [BibleSearchResult] {
        let bookOrder = Dictionary(uniqueKeysWithValues: BibleData.books.enumerated().map { ($1.name, $0) })

        return results.sorted { a, b in
            let aBook = BibleData.books.first { a.reference.hasPrefix($0.name) }?.name ?? ""
            let bBook = BibleData.books.first { b.reference.hasPrefix($0.name) }?.name ?? ""

            let aOrder = bookOrder[aBook] ?? 99
            let bOrder = bookOrder[bBook] ?? 99

            if aOrder != bOrder { return aOrder < bOrder }

            // Same book — compare chapter:verse numerically
            let aNumbers = extractChapterVerse(from: a.reference, bookName: aBook)
            let bNumbers = extractChapterVerse(from: b.reference, bookName: bBook)

            if aNumbers.chapter != bNumbers.chapter { return aNumbers.chapter < bNumbers.chapter }
            return aNumbers.verse < bNumbers.verse
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.reference)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.reforgedGold)

            highlightedText
                .font(.caption)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    /// Renders verse text with search terms highlighted in gold.
    private var highlightedText: Text {
        let content = result.content
        guard !content.isEmpty, !highlightWords.isEmpty else {
            return Text(content)
        }

        // Find all ranges of highlight words (case-insensitive)
        let lowered = content.lowercased()
        var highlights: [(range: Range<String.Index>, word: String)] = []

        for term in highlightWords {
            let searchTerm = term.lowercased()
            var searchStart = lowered.startIndex
            while searchStart < lowered.endIndex {
                guard let range = lowered.range(of: searchTerm, range: searchStart..<lowered.endIndex) else { break }

                // Check word boundaries — don't highlight partial words
                let beforeOK = range.lowerBound == lowered.startIndex || !lowered[lowered.index(before: range.lowerBound)].isLetter
                let afterOK = range.upperBound == lowered.endIndex || !lowered[range.upperBound].isLetter

                if beforeOK && afterOK {
                    highlights.append((range: range, word: String(content[range])))
                }

                searchStart = range.upperBound
            }
        }

        // Sort by position
        highlights.sort { $0.range.lowerBound < $1.range.lowerBound }

        // Remove overlapping highlights
        var filtered: [(range: Range<String.Index>, word: String)] = []
        for hl in highlights {
            if let last = filtered.last, hl.range.lowerBound < last.range.upperBound {
                continue // Skip overlap
            }
            filtered.append(hl)
        }

        // Build attributed Text
        var result = Text("")
        var current = content.startIndex

        for hl in filtered {
            // Text before highlight
            if current < hl.range.lowerBound {
                result = result + Text(content[current..<hl.range.lowerBound])
            }
            // Highlighted text
            result = result + Text(content[hl.range])
                .fontWeight(.bold)
                .foregroundColor(Color.reforgedGold)
            current = hl.range.upperBound
        }

        // Remaining text
        if current < content.endIndex {
            result = result + Text(content[current..<content.endIndex])
        }

        return result
    }
}
