import SwiftUI

// MARK: - Unified Navigation View (YouVersion-style)

struct UnifiedNavigationView: View {
    @Binding var selectedBook: BibleBook
    @Binding var selectedChapter: Int
    var recentPassages: [(book: String, chapter: Int)]
    @Binding var isPresented: Bool
    let onSelect: () -> Void
    var onSelectVerse: ((Int) -> Void)? = nil
    var translation: BibleTranslation = .esv
    var translationOrder: [BibleTranslation] = BibleTranslation.allCases
    @ObservedObject private var olService = OriginalLanguageService.shared
    @Environment(\.colorScheme) var colorScheme

    enum ActiveTab { case books, history }
    enum SortOrder { case traditional, alphabetical }

    @State private var activeTab: ActiveTab = .books
    @State private var searchText = ""
    @State private var selectedTestament: BibleBook.Testament? = nil
    @State private var expandedBookID: String? = nil
    @State private var sortOrder: SortOrder = .traditional
    @State private var showVersePicker = false
    @State private var chapterVerses: [ParsedVerse] = []
    @State private var isLoadingVerses = false

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

        // Try longer names first so "1 John" beats "John" for "1 john 3"
        let sorted = BibleData.books.sorted { $0.name.count > $1.name.count }

        for book in sorted {
            for candidate in [book.name.lowercased(), book.abbreviation.lowercased()] {
                guard lower.hasPrefix(candidate) else { continue }
                let afterBook = lower.dropFirst(candidate.count)
                // Candidate must be followed by whitespace (or end — but end means no chapter)
                guard let first = afterBook.first, first.isWhitespace else { continue }
                let rest = afterBook.trimmingCharacters(in: .whitespaces)
                guard !rest.isEmpty else { break }

                // Parse chapter[:verse]
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
                // Show only the matched book when a reference is detected
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showVersePicker {
                    versePickerView
                } else if activeTab == .history {
                    historyView
                } else {
                    booksView
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .navigationTitle(showVersePicker ? "\(selectedBook.name) \(selectedChapter)" : "Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if showVersePicker {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showVersePicker = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.subheadline)
                                Text("Back")
                            }
                            .foregroundStyle(Color.reforgedGold)
                        }
                    } else {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !showVersePicker {
                        Button(activeTab == .books ? "History" : "Books") {
                            withAnimation(.spring(response: 0.3)) {
                                activeTab = activeTab == .books ? .history : .books
                            }
                        }
                        .foregroundStyle(Color.reforgedGold)
                    }
                }
            }
        }
    }

    // MARK: - Books View

    @ViewBuilder
    private var booksView: some View {
        VStack(spacing: 0) {
            // Recent passages
            if !recentPassages.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(recentPassages.prefix(5).enumerated()), id: \.offset) { _, passage in
                                Button {
                                    if let book = BibleData.books.first(where: { $0.name == passage.book }) {
                                        selectedBook = book
                                        selectedChapter = passage.chapter
                                        isPresented = false
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
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                TextField("Search or go to reference...", text: $searchText)
                    .font(.subheadline)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.adaptiveSecondaryBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            // Reference jump row
            if let ref = parsedReference {
                Button {
                    selectedBook = ref.book
                    selectedChapter = ref.chapter
                    if let verse = ref.verse, let selectVerse = onSelectVerse {
                        isPresented = false
                        onSelect()
                        selectVerse(verse)
                    } else {
                        isPresented = false
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Testament filter
            HStack(spacing: 10) {
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
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Book list with expandable chapter grids
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredBooks) { book in
                            VStack(spacing: 0) {
                                // Book row
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        if expandedBookID == book.id {
                                            expandedBookID = nil
                                        } else {
                                            expandedBookID = book.id
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(book.name)
                                            .font(.body)
                                            .fontWeight(book.id == selectedBook.id ? .bold : .regular)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))

                                        Spacer()

                                        // Audio icon (ESV only)
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(translation == .esv ? Color.adaptiveTextSecondary(colorScheme) : Color.adaptiveTextSecondary(colorScheme).opacity(0.3))

                                        // Expand/collapse chevron
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
                                                // TR is NT-only and WLC is OT-only.
                                                // Skip the verse picker when the selected book
                                                // is incompatible with the current translation
                                                // and navigate directly instead.
                                                let incompatible =
                                                    (translation == .tr  && book.testament == .old) ||
                                                    (translation == .wlc && book.testament == .new)
                                                if incompatible {
                                                    isPresented = false
                                                    onSelect()
                                                } else {
                                                    loadVersesForChapter()
                                                    withAnimation(.spring(response: 0.3)) {
                                                        showVersePicker = true
                                                    }
                                                }
                                            } label: {
                                                Text("\(chapter)")
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(
                                                        (book.id == selectedBook.id && chapter == selectedChapter)
                                                        ? .white
                                                        : Color.adaptiveText(colorScheme)
                                                    )
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 52)
                                                    .background(
                                                        (book.id == selectedBook.id && chapter == selectedChapter)
                                                        ? Color.reforgedNavy
                                                        : Color.adaptiveTertiaryBackground(colorScheme)
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                // Separator
                                if filteredBooks.last?.id != book.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    // Auto-expand and scroll to the currently active book
                    let bookID = selectedBook.id
                    expandedBookID = bookID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(bookID, anchor: .center)
                        }
                    }
                }
                .onChange(of: expandedBookID) { newID in
                    if let newID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .top)
                            }
                        }
                    }
                }
            }

            // Bottom sort toggle
            sortToggle
        }
    }

    // MARK: - Verse Picker View

    @ViewBuilder
    private var versePickerView: some View {
        VStack(spacing: 12) {
            // "Go to Chapter Start" button
            Button {
                isPresented = false
                onSelect()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                    Text("Go to Chapter Start")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.reforgedNavy)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text("Or select a verse:")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            // If TR/WLC data is still being parsed in the background, show a spinner
            // and retry automatically once it's ready.
            let waitingForOL = (translation == .tr  && !olService.trReady  && selectedBook.testament == .new)
                            || (translation == .wlc && !olService.wlcReady && selectedBook.testament == .old)
            if isLoadingVerses || waitingForOL {
                Spacer()
                ProgressView("Loading verses...")
                Spacer()
                    .onChange(of: olService.trReady) { isReady in
                        if isReady && translation == .tr { loadVersesForChapter() }
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
                                isPresented = false
                                onSelect()
                                onSelectVerse?(verse.number)
                            } label: {
                                Text("\(verse.number)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.adaptiveTertiaryBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }

    // MARK: - History View

    @ViewBuilder
    private var historyView: some View {
        if recentPassages.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "clock")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Text("No reading history yet")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Text("Your recently viewed passages will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(recentPassages.enumerated()), id: \.offset) { index, passage in
                        Button {
                            if let book = BibleData.books.first(where: { $0.name == passage.book }) {
                                selectedBook = book
                                selectedChapter = passage.chapter
                                isPresented = false
                                onSelect()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    .frame(width: 28)

                                Text("\(passage.book) \(passage.chapter)")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }

                        if index < recentPassages.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sort Toggle

    @ViewBuilder
    private var sortToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    sortOrder = .traditional
                }
            } label: {
                Text("Traditional")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(sortOrder == .traditional ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(sortOrder == .traditional
                        ? (colorScheme == .dark ? Color.adaptiveChipBackground(colorScheme) : .white)
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    sortOrder = .alphabetical
                }
            } label: {
                Text("Alphabetical")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(sortOrder == .alphabetical ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(sortOrder == .alphabetical
                        ? (colorScheme == .dark ? Color.adaptiveChipBackground(colorScheme) : .white)
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(Color.adaptiveSecondaryBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 10)
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
                case .csb, .nkjv, .nasb, .rvr1960:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
                case .tr:
                    // TR covers the NT only. Preload and read verse numbers from the index.
                    if selectedBook.testament == .new {
                        OriginalLanguageService.shared.preloadTR()
                        let bookNum = OriginalLanguageService.bookNumber(for: selectedBook.name) ?? 0
                        let trVerses = OriginalLanguageService.shared.trChapter(bookNumber: bookNum, chapter: selectedChapter)
                        fetchedVerses = trVerses.map { v in
                            let ref = "\(selectedBook.name) \(selectedChapter):\(v.verse)"
                            return ParsedVerse(id: ref, number: v.verse, text: "", reference: ref)
                        }
                    }
                case .wlc:
                    // WLC covers the OT only. Preload and read verse numbers from the index.
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
                await MainActor.run {
                    isLoadingVerses = false
                }
            }
        }
    }
}
