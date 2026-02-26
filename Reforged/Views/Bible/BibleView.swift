import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Memory Verses Selection Wrapper

struct MemoryVersesSelection: Identifiable {
    let id = UUID()
    let verses: [ParsedVerse]
    let book: String
    let chapter: Int
}

// MARK: - Bible View (Unified Single View)

struct BibleView: View {
    @ObservedObject private var readingState = BibleReadingState.shared
    @StateObject private var audioPlayer = BibleAudioPlayer()
    @StateObject private var readingSettings = BibleReadingSettings.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation

    // Navigation state
    @State private var selectedBook: BibleBook = BibleData.books.first { $0.name == "John" } ?? BibleData.books[0]
    @State private var selectedChapter: Int = 3
    @State private var showUnifiedNavigation = false
    @State private var showSearchPanel = false
    @State private var showFormattingPanel = false
    @State private var showAudioPlayer = false
    @State private var currentTranslation: BibleTranslation = .esv

    // Content state
    @State private var verses: [ParsedVerse] = []
    @State private var passageText: String = ""
    @State private var canonicalReference = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scrollPosition: CGFloat = 0

    // Chapter transition animation state
    @State private var chapterTransitionOffset: CGFloat = 0
    @State private var chapterTransitionOpacity: Double = 1.0

    // Search state
    @State private var searchQuery = ""
    @State private var searchResults: [BibleSearchResult] = []
    @State private var searchHistory: [String] = []
    @State private var recentPassages: [(book: String, chapter: Int)] = []
    @State private var isSearching = false
    @State private var scrollToVerseID: String? = nil

    // Verse interaction state
    @State private var selectedVerseForAction: ParsedVerse?
    @State private var memoryVersesSelection: MemoryVersesSelection?
    @State private var verseShareSelection: VerseShareSelection?

    // Strong's word study state
    @State private var wordLookupResult: WordLookupResult?
    @State private var isLoadingWordLookup = false
    @State private var highlightedWord: (verseID: String, word: String)? = nil

    // iPad/Mac: Show navigation sidebar
    @State private var showNavigationSidebar = false

    // Reading streak tracking
    @StateObject private var streakManager = ReadingStreakManager.shared
    @State private var showMarkAsReadPrompt = false
    @State private var hasScrolledToBottom = false

    var isChapterRead: Bool {
        appState.user.chaptersRead.contains("\(selectedBook.name) \(selectedChapter)")
    }

    var isChapterReadForStreak: Bool {
        streakManager.wasChapterRead(book: selectedBook.name, chapter: selectedChapter, on: Date())
    }

    // Maximum content width for readability on large screens
    var maxContentWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
    }

    // Abbreviated book name for toolbar display
    var toolbarDisplayBookName: String {
        let longBookAbbreviations: [String: String] = [
            "Deuteronomy": "Deut",
            "1 Chronicles": "1 Chr",
            "2 Chronicles": "2 Chr",
            "Ecclesiastes": "Eccl",
            "Song of Solomon": "Song",
            "Lamentations": "Lam",
            "1 Thessalonians": "1 Thess",
            "2 Thessalonians": "2 Thess",
            "1 Corinthians": "1 Cor",
            "2 Corinthians": "2 Cor",
            "Philippians": "Phil",
            "Colossians": "Col",
            "Revelation": "Rev"
        ]
        return longBookAbbreviations[selectedBook.name] ?? selectedBook.name
    }

    // Icon color for iPad toolbar buttons
    var toolbarIconColor: Color {
        colorScheme == .dark ? Color(white: 0.9) : Color.reforgedNavy
    }

    // MARK: - Toolbar action closures (shared between BibleTopBar and .toolbar)

    private func onNavigationTap() {
        showUnifiedNavigation = true
    }

    private func onSearchTap() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showSearchPanel = true
        }
    }

    private func onAudioTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showAudioPlayer.toggle()
            if showAudioPlayer && !audioPlayer.isPlaying && audioPlayer.currentTime == 0 {
                audioPlayer.updateFromSettings()
                audioPlayer.play(book: selectedBook.name, chapter: selectedChapter)
            }
        }
    }

    private func onFormatTap() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showFormattingPanel = true
        }
    }

    private func onTranslationSelect(_ newTranslation: BibleTranslation) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            settingsManager.defaultTranslation = newTranslation
            currentTranslation = newTranslation
            loadChapter()
        }
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Top Navigation Bar (iPhone only — iPad uses .toolbar)
                if !isSidebarNavigation {
                    BibleTopBar(
                        book: selectedBook,
                        chapter: selectedChapter,
                        translation: currentTranslation,
                        showAudioPlayer: showAudioPlayer,
                        audioPlayer: audioPlayer,
                        onNavigationTap: onNavigationTap,
                        onSearchTap: onSearchTap,
                        onAudioTap: onAudioTap,
                        onFormatTap: onFormatTap,
                        onTranslationSelect: { newTranslation in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                settingsManager.defaultTranslation = newTranslation
                                currentTranslation = newTranslation
                                loadChapter()
                            }
                        }
                    )
                }

                // Collapsible Audio player bar
                if showAudioPlayer {
                    BibleAudioBar(
                        audioPlayer: audioPlayer,
                        book: selectedBook.name,
                        chapter: selectedChapter,
                        onClose: {
                            withAnimation(.spring(response: 0.3)) {
                                audioPlayer.stop()
                                showAudioPlayer = false
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Chapter content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if isLoading {
                                LoadingView()
                            } else if let error = errorMessage {
                                ErrorView(message: error) {
                                    loadChapter()
                                }
                            } else {
                                // Chapter header
                                ChapterHeader(
                                    book: selectedBook.name,
                                    chapter: selectedChapter,
                                    canonical: canonicalReference
                                )

                                // Content based on verse-by-verse setting
                                if readingSettings.verseByVerse {
                                    // Verse-by-verse display
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(verses) { verse in
                                            VerseRow(
                                                verse: verse,
                                                highlight: readingState.getHighlight(for: verse.reference),
                                                hasNote: readingState.getNote(for: verse.reference) != nil,
                                                isSelected: readingState.isSelected(verse.reference),
                                                settings: readingSettings,
                                                verseByVerse: true,
                                                highlightedWord: highlightedWord,
                                                onTap: {
                                                    withAnimation(.easeInOut(duration: 0.15)) {
                                                        readingState.toggleSelection(verse.reference)
                                                    }
                                                },
                                                onWordLongPress: { word, tappedVerse in
                                                    performWordLookup(word: word, verse: tappedVerse)
                                                },
                                                readingState: readingState
                                            )
                                            .id(verse.id)
                                        }
                                    }
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                } else {
                                    // Paragraph format with long-press word lookup
                                    WordLongPressParagraphText(
                                        verses: verses,
                                        readingState: readingState,
                                        settings: readingSettings,
                                        colorScheme: colorScheme,
                                        highlightedWord: highlightedWord,
                                        onVerseTap: { verse in
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                readingState.toggleSelection(verse.reference)
                                            }
                                        },
                                        onWordLongPress: { word, tappedVerse in
                                            performWordLookup(word: word, verse: tappedVerse)
                                        }
                                    )
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                }

                                // Bible Attribution
                                ESVAttribution(translation: currentTranslation)

                                // Mark as Read section - shown at bottom
                                MarkChapterReadSection(
                                    book: selectedBook.name,
                                    chapter: selectedChapter,
                                    isRead: isChapterReadForStreak,
                                    onMarkAsRead: {
                                        markChapterAsRead()
                                    }
                                )
                                .id("chapter-end")
                            }
                        }
                        .frame(maxWidth: maxContentWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 60) // Space for bottom nav buttons
                        .offset(x: chapterTransitionOffset)
                        .opacity(chapterTransitionOpacity)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).maxY)
                            }
                        )
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { maxY in
                        // Check if user has scrolled near the bottom
                        let screenHeight = UIScreen.main.bounds.height
                        if maxY < screenHeight + 200 && !hasScrolledToBottom && !isChapterReadForStreak && !isLoading {
                            hasScrolledToBottom = true
                            // Show mark as read prompt with slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.spring(response: 0.4)) {
                                    showMarkAsReadPrompt = true
                                }
                            }
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                let horizontalAmount = value.translation.width
                                let verticalAmount = value.translation.height

                                // Only trigger if horizontal swipe is greater than vertical (to avoid interfering with scroll)
                                if abs(horizontalAmount) > abs(verticalAmount) * 1.5 {
                                    if horizontalAmount < -80 {
                                        // Swipe left -> Next chapter
                                        if selectedChapter < selectedBook.chapters {
                                            animateChapterChange(direction: .forward) {
                                                selectedChapter += 1
                                                loadChapter()
                                            }
                                        }
                                    } else if horizontalAmount > 80 {
                                        // Swipe right -> Previous chapter (or open search if at edge)
                                        if value.startLocation.x < 50 {
                                            withAnimation(.spring(response: 0.35)) {
                                                showSearchPanel = true
                                            }
                                        } else if selectedChapter > 1 {
                                            animateChapterChange(direction: .backward) {
                                                selectedChapter -= 1
                                                loadChapter()
                                            }
                                        }
                                    }
                                }
                            }
                    )
                    .onChange(of: scrollToVerseID) { targetID in
                        if let targetID = targetID {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(targetID, anchor: .top)
                                }
                                self.scrollToVerseID = nil
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())

            // Floating chapter navigation buttons
            VStack {
                Spacer()
                FloatingChapterNav(
                    currentChapter: selectedChapter,
                    totalChapters: selectedBook.chapters,
                    onPrevious: {
                        if selectedChapter > 1 {
                            animateChapterChange(direction: .backward) {
                                selectedChapter -= 1
                                loadChapter()
                            }
                        }
                    },
                    onNext: {
                        if selectedChapter < selectedBook.chapters {
                            animateChapterChange(direction: .forward) {
                                selectedChapter += 1
                                loadChapter()
                            }
                        }
                    }
                )
                .padding(.bottom, 16)
            }

            // Selection action bar
            if !readingState.selectedVerses.isEmpty {
                VStack {
                    Spacer()
                    SelectionActionBar(readingState: readingState) { action in
                        handleSelectionAction(action)
                    }
                    .padding(.bottom, 70) // Above nav buttons
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Search Panel Overlay
            if showSearchPanel {
                SearchPanelView(
                    searchQuery: $searchQuery,
                    searchResults: $searchResults,
                    searchHistory: $searchHistory,
                    recentPassages: recentPassages,
                    isSearching: $isSearching,
                    isPresented: $showSearchPanel,
                    onSelectResult: { result in
                        navigateToSearchResult(result)
                        addSearchToHistory(searchQuery)
                    },
                    onSelectRecent: { book, chapter in
                        if let foundBook = BibleData.books.first(where: { $0.name == book }) {
                            selectedBook = foundBook
                            selectedChapter = chapter
                            loadChapter()
                        }
                        showSearchPanel = false
                    },
                    translation: currentTranslation
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Formatting Panel
            if showFormattingPanel {
                FormattingPanelView(
                    settings: readingSettings,
                    isPresented: $showFormattingPanel
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedVerseForAction) { verse in
            TakeNoteView(
                verse: verse,
                readingState: readingState,
                onDismiss: {
                    selectedVerseForAction = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $memoryVersesSelection) { selection in
            AddToMemorySheet(
                verses: selection.verses,
                book: selection.book,
                chapter: selection.chapter,
                translation: currentTranslation,
                onDismiss: {
                    memoryVersesSelection = nil
                    withAnimation { readingState.clearSelection() }
                }
            )
            .environmentObject(appState)
        }
        .sheet(item: $verseShareSelection) { selection in
            VerseShareSheet(selection: selection)
        }
        .sheet(item: $wordLookupResult, onDismiss: {
            withAnimation(.easeInOut(duration: 0.15)) {
                highlightedWord = nil
            }
        }) { result in
            StrongsDefinitionSheet(result: result)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showUnifiedNavigation) {
            UnifiedNavigationView(
                selectedBook: $selectedBook,
                selectedChapter: $selectedChapter,
                recentPassages: recentPassages,
                isPresented: $showUnifiedNavigation,
                onSelect: {
                    loadChapter()
                    addToRecentPassages()
                },
                onSelectVerse: { verseNum in
                    let targetVerseID = "\(selectedBook.name) \(selectedChapter):\(verseNum)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToVerseID = targetVerseID
                    }
                },
                translation: currentTranslation
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            if isSidebarNavigation {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        // Book + Chapter navigation button
                        Button(action: onNavigationTap) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.book.closed.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.reforgedGold)

                                Text("\(toolbarDisplayBookName) \(selectedChapter)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .lineLimit(1)

                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.reforgedGold)
                            }
                        }

                        // Translation dropdown menu
                        Menu {
                            ForEach(BibleTranslation.allCases) { t in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        settingsManager.defaultTranslation = t
                                        currentTranslation = t
                                        loadChapter()
                                    }
                                } label: {
                                    HStack {
                                        Text(t.rawValue)
                                        if t == currentTranslation {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentTranslation.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.reforgedNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSearchTap) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAudioTap) {
                        Label("Audio", systemImage: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "headphones")
                    }
                    .tint(showAudioPlayer || audioPlayer.isPlaying ? Color.reforgedGold : nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onFormatTap) {
                        Label("Display", systemImage: "textformat.size")
                    }
                }
            }
        }
        .toolbarBackground(Color.adaptiveBackground(colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Restore last reading position
            selectedBook = BibleData.books.first(where: { $0.name == readingSettings.lastBook }) ?? selectedBook
            selectedChapter = readingSettings.lastChapter
            currentTranslation = settingsManager.defaultTranslation
            loadSearchHistory()
            loadRecentPassages()
            loadChapter()
            // Update audio player settings
            audioPlayer.updateFromSettings()

            // Wire up audio chapter completion callback
            audioPlayer.onChapterCompleted = { [self] book, chapter in
                // Mark the completed chapter as read
                streakManager.recordChapterRead(book: book, chapter: chapter)
                _ = appState.markChapterRead(book: book, chapter: chapter)

                // If the audio player auto-advances, update the Bible view to follow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !audioPlayer.currentBook.isEmpty && audioPlayer.currentChapter > 0 {
                        if let newBook = BibleData.books.first(where: { $0.name == audioPlayer.currentBook }) {
                            selectedBook = newBook
                            selectedChapter = audioPlayer.currentChapter
                            loadChapter()
                            addToRecentPassages()
                        }
                    }
                }
            }

            // Resume audio if it was playing when the app was backgrounded
            if audioPlayer.savedAudioState() != nil {
                audioPlayer.resumeFromSavedState()
                showAudioPlayer = true
            }
        }
        .onChange(of: settingsManager.defaultTranslation) { newTranslation in
            // Reload chapter when translation changes
            if currentTranslation != newTranslation {
                loadChapter()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToBibleVerse"))) { notification in
            if let reference = notification.userInfo?["reference"] as? String {
                navigateToVerseReference(reference)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save audio state when app loses focus
            if audioPlayer.isPlaying {
                audioPlayer.saveAudioStatePublic()
            }
        }
    }

    // MARK: - Strong's Word Lookup

    func performWordLookup(word: String, verse: ParsedVerse) {
        let isHebrew = selectedBook.testament == .old
        isLoadingWordLookup = true
        // Highlight the tapped word visually
        withAnimation(.easeInOut(duration: 0.15)) {
            highlightedWord = (verseID: verse.id, word: word.lowercased())
        }
        Task {
            let result = await StrongsLexiconService.shared.lookupWord(
                word,
                verseReference: verse.reference,
                bookName: selectedBook.name,
                chapter: selectedChapter,
                verseNumber: verse.number,
                isHebrew: isHebrew
            )
            await MainActor.run {
                isLoadingWordLookup = false
                wordLookupResult = result
            }
        }
    }

    // MARK: - Chapter Transition Animation

    enum ChapterDirection {
        case forward
        case backward
    }

    func animateChapterChange(direction: ChapterDirection, action: @escaping () -> Void) {
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let exitOffset: CGFloat = direction == .forward ? -screenWidth : screenWidth
        let enterOffset: CGFloat = direction == .forward ? screenWidth : -screenWidth

        // Phase 1: Slide out current content
        withAnimation(.easeIn(duration: 0.15)) {
            chapterTransitionOffset = exitOffset * 0.3
            chapterTransitionOpacity = 0
        }

        // Phase 2: Execute action and slide in new content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            chapterTransitionOffset = enterOffset * 0.3
            action()

            withAnimation(.easeOut(duration: 0.2)) {
                chapterTransitionOffset = 0
                chapterTransitionOpacity = 1
            }
        }
    }

    func loadChapter() {
        isLoading = true
        errorMessage = nil
        readingState.clearSelection()

        // Reset scroll tracking for new chapter
        hasScrolledToBottom = false
        showMarkAsReadPrompt = false

        // Update reading state and settings
        readingState.currentBook = selectedBook.name
        readingState.currentChapter = selectedChapter
        readingSettings.lastBook = selectedBook.name
        readingSettings.lastChapter = selectedChapter

        // Get the current translation from settings
        let translation = settingsManager.defaultTranslation
        currentTranslation = translation

        Task {
            do {
                var fetchedVerses: [ParsedVerse] = []
                var fetchedCanonical: String = ""

                switch translation {
                case .esv:
                    let result = try await ESVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                    fetchedCanonical = result.canonical
                case .kjv:
                    let result = try await KJVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                    fetchedCanonical = result.canonical
                case .csb, .nkjv, .nasb:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
                    fetchedCanonical = result.canonical
                }

                await MainActor.run {
                    verses = fetchedVerses
                    canonicalReference = fetchedCanonical
                    isLoading = false
                }

                // Pre-fetch interlinear data for word lookup
                await StrongsLexiconService.shared.prefetchChapter(
                    bookName: selectedBook.name,
                    chapter: selectedChapter,
                    totalVerses: fetchedVerses.count
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func markChapterAsRead() {
        // Record in streak manager
        streakManager.recordChapterRead(book: selectedBook.name, chapter: selectedChapter)

        // Also record in app state for XP
        _ = appState.markChapterRead(book: selectedBook.name, chapter: selectedChapter)

        // Hide the prompt
        withAnimation(.spring(response: 0.3)) {
            showMarkAsReadPrompt = false
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func navigateToSearchResult(_ result: BibleSearchResult) {
        let parts = result.reference.components(separatedBy: " ")
        if parts.count >= 2 {
            var bookName = ""
            var chapterVerse = ""

            for (index, part) in parts.enumerated() {
                if part.contains(":") || Int(part.prefix(while: { $0.isNumber })) != nil && index == parts.count - 1 {
                    chapterVerse = part
                    break
                } else {
                    if !bookName.isEmpty { bookName += " " }
                    bookName += part
                }
            }

            if let book = BibleData.books.first(where: { $0.name == bookName }) {
                selectedBook = book
                let chapterVerseParts = chapterVerse.components(separatedBy: ":")
                if let chapterNum = Int(chapterVerseParts.first ?? "") {
                    selectedChapter = chapterNum
                } else {
                    selectedChapter = 1
                }

                // Parse verse number to scroll to after loading
                if chapterVerseParts.count > 1,
                   let verseNum = Int(chapterVerseParts[1].components(separatedBy: "-").first ?? "") {
                    let targetVerseID = "\(bookName) \(selectedChapter):\(verseNum)"
                    loadChapter()
                    // Set scroll target after a brief delay to let verses render
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToVerseID = targetVerseID
                    }
                } else {
                    loadChapter()
                }
                addToRecentPassages()
            }
        }
        showSearchPanel = false
    }

    func navigateToVerseReference(_ reference: String) {
        // Reuse search result navigation by creating a BibleSearchResult
        let result = BibleSearchResult(reference: reference, content: "")
        navigateToSearchResult(result)
    }

    func handleSelectionAction(_ action: SelectionAction) {
        switch action {
        case .highlight(let color):
            for reference in readingState.selectedVerses {
                if let verse = verses.first(where: { $0.reference == reference }) {
                    readingState.highlight(
                        reference: reference,
                        book: selectedBook.name,
                        chapter: selectedChapter,
                        verse: verse.number,
                        color: color
                    )
                }
            }
            HapticManager.shared.lightImpact()
            withAnimation { readingState.clearSelection() }

        case .removeHighlight:
            for reference in readingState.selectedVerses {
                readingState.removeHighlight(reference: reference)
            }
            withAnimation { readingState.clearSelection() }

        case .addNote:
            if let firstRef = readingState.selectedVerses.first,
               let verse = verses.first(where: { $0.reference == firstRef }) {
                selectedVerseForAction = verse
            }

        case .addToMemory:
            let selectedVerses = verses.filter { readingState.selectedVerses.contains($0.reference) }
            if !selectedVerses.isEmpty {
                memoryVersesSelection = MemoryVersesSelection(
                    verses: selectedVerses,
                    book: selectedBook.name,
                    chapter: selectedChapter
                )
            }

        case .copy:
            let selectedTexts = verses
                .filter { readingState.selectedVerses.contains($0.reference) }
                .map { "[\($0.number)] \($0.text)" }
                .joined(separator: "\n")

            let fullText = "\(selectedBook.name) \(selectedChapter)\n\n\(selectedTexts)\n\n(ESV)"
            UIPasteboard.general.string = fullText
            withAnimation { readingState.clearSelection() }

        case .share:
            let selected = verses.filter { readingState.selectedVerses.contains($0.reference) }
            if !selected.isEmpty {
                verseShareSelection = VerseShareSelection(
                    verses: selected,
                    book: selectedBook.name,
                    chapter: selectedChapter,
                    translation: currentTranslation.rawValue
                )
            }
            withAnimation { readingState.clearSelection() }

        }
    }

    func addToRecentPassages() {
        let passage = (book: selectedBook.name, chapter: selectedChapter)
        recentPassages.removeAll { $0.book == passage.book && $0.chapter == passage.chapter }
        recentPassages.insert(passage, at: 0)
        if recentPassages.count > 10 {
            recentPassages = Array(recentPassages.prefix(10))
        }
        saveRecentPassages()
    }

    func addSearchToHistory(_ query: String) {
        guard !query.isEmpty else { return }
        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        searchHistory.insert(query, at: 0)
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        saveSearchHistory()
    }

    func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "bible_search_history") ?? []
    }

    func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "bible_search_history")
    }

    func loadRecentPassages() {
        let books = UserDefaults.standard.stringArray(forKey: "bible_recent_books") ?? []
        let chapters = UserDefaults.standard.array(forKey: "bible_recent_chapters") as? [Int] ?? []
        recentPassages = zip(books, chapters).map { (book: $0, chapter: $1) }
    }

    func saveRecentPassages() {
        UserDefaults.standard.set(recentPassages.map { $0.book }, forKey: "bible_recent_books")
        UserDefaults.standard.set(recentPassages.map { $0.chapter }, forKey: "bible_recent_chapters")
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Mark Chapter Read Section

struct MarkChapterReadSection: View {
    let book: String
    let chapter: Int
    let isRead: Bool
    let onMarkAsRead: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showSuccessAnimation = false

    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 32)

            if isRead {
                // Already read state
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.reforgedCoral)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chapter Completed")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("You've read \(book) \(chapter) today")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    Spacer()

                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(Color.reforgedCoral)
                }
                .padding()
                .background(Color.reforgedCoral.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                // Prompt to mark as read
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "book.fill")
                            .font(.title3)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finished reading?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("Mark this chapter as read to keep your streak!")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSuccessAnimation = true
                        }
                        onMarkAsRead()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)

                            Text("Mark as Read")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.reforgedCoral)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .scaleEffect(showSuccessAnimation ? 0.95 : 1.0)
                }
                .padding()
                .background(Color.reforgedNavy.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Paragraph View (ESV paragraph format with tappable verses)

struct ParagraphView: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let settings: BibleReadingSettings
    let onVerseTap: (ParsedVerse) -> Void
    let onVerseLongPress: (ParsedVerse) -> Void
    @Environment(\.colorScheme) var colorScheme

    // Group verses into paragraphs based on startsNewParagraph flag
    var paragraphs: [[ParsedVerse]] {
        var result: [[ParsedVerse]] = []
        var currentParagraph: [ParsedVerse] = []

        for verse in verses {
            if verse.startsNewParagraph && !currentParagraph.isEmpty {
                result.append(currentParagraph)
                currentParagraph = []
            }
            currentParagraph.append(verse)
        }

        if !currentParagraph.isEmpty {
            result.append(currentParagraph)
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                TappableParagraphText(
                    verses: paragraph,
                    readingState: readingState,
                    settings: settings,
                    colorScheme: colorScheme,
                    onVerseTap: onVerseTap,
                    onVerseLongPress: onVerseLongPress
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Tappable Paragraph Text (true inline text flow with verse selection)

struct TappableParagraphText: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let settings: BibleReadingSettings
    let colorScheme: ColorScheme
    let onVerseTap: (ParsedVerse) -> Void
    let onVerseLongPress: (ParsedVerse) -> Void

    var body: some View {
        // Build the paragraph as a single Text view for natural text flow
        buildParagraphText()
            .font(.system(size: settings.fontSize.size, weight: .regular, design: settings.fontType.design))
            .lineSpacing(settings.lineSpacing.spacing)
            .overlay(
                // Overlay invisible tap targets for each verse
                GeometryReader { geometry in
                    VerseTapOverlay(
                        verses: verses,
                        readingState: readingState,
                        settings: settings,
                        colorScheme: colorScheme,
                        containerSize: geometry.size,
                        onVerseTap: onVerseTap,
                        onVerseLongPress: onVerseLongPress
                    )
                }
            )
    }

    func buildParagraphText() -> Text {
        var result = Text("")

        for verse in verses {
            let isSelected = readingState.isSelected(verse.reference)
            let highlight = readingState.getHighlight(for: verse.reference)

            // Superscript verse number
            let verseNumber = Text("\(verse.number)")
                .font(.system(size: settings.fontSize.verseNumberSize, weight: .bold, design: .rounded))
                .foregroundColor(Color.reforgedGold)
                .baselineOffset(6)

            // Verse text - use color tinting for selection/highlight since Text can't have backgrounds in concatenation
            let verseText: Text
            if isSelected {
                // Selected verses shown with gold in dark mode, navy in light mode
                let selectionColor = colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
                verseText = Text(" \(verse.text) ")
                    .foregroundColor(selectionColor)
                    .underline(true, color: selectionColor.opacity(0.5))
            } else if let hl = highlight {
                // Highlighted verses shown with highlight color
                verseText = Text(" \(verse.text) ")
                    .foregroundColor(hl.highlightColor.opacity(1.0))
                    .underline(true, color: hl.highlightColor)
            } else {
                verseText = Text(" \(verse.text) ")
                    .foregroundColor(Color.adaptiveText(colorScheme))
            }

            result = result + verseNumber + verseText
        }

        return result
    }
}

// MARK: - Verse Tap Overlay (invisible tap targets positioned over each verse)

struct VerseTapOverlay: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let settings: BibleReadingSettings
    let colorScheme: ColorScheme
    let containerSize: CGSize
    let onVerseTap: (ParsedVerse) -> Void
    let onVerseLongPress: (ParsedVerse) -> Void

    // Calculate proportional heights based on text length
    var verseHeights: [CGFloat] {
        // Calculate total character count (including verse number overhead)
        let verseLengths = verses.map { verse -> CGFloat in
            // Account for verse number (superscript) + space + text + trailing space
            let textLength = CGFloat(verse.text.count + 4)
            // Minimum length to ensure short verses still have a tap target
            return max(textLength, 20)
        }

        let totalLength = verseLengths.reduce(0, +)
        guard totalLength > 0 else { return verses.map { _ in containerSize.height / CGFloat(max(verses.count, 1)) } }

        // Distribute container height proportionally
        return verseLengths.map { length in
            (length / totalLength) * containerSize.height
        }
    }

    var body: some View {
        let heights = verseHeights

        VStack(spacing: 0) {
            ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(height: heights[index])
                    .onTapGesture {
                        onVerseTap(verse)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        onVerseLongPress(verse)
                    }
            }
        }
    }
}

// MARK: - Bible Top Bar

struct BibleTopBar: View {
    let book: BibleBook
    let chapter: Int
    let translation: BibleTranslation
    let showAudioPlayer: Bool
    @ObservedObject var audioPlayer: BibleAudioPlayer
    let onNavigationTap: () -> Void
    let onSearchTap: () -> Void
    let onAudioTap: () -> Void
    let onFormatTap: () -> Void
    let onTranslationSelect: (BibleTranslation) -> Void
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var iconColor: Color {
        colorScheme == .dark ? Color(white: 0.9) : Color.reforgedNavy
    }

    // Abbreviated names for long books
    var displayBookName: String {
        let longBookAbbreviations: [String: String] = [
            "Deuteronomy": "Deut",
            "1 Chronicles": "1 Chr",
            "2 Chronicles": "2 Chr",
            "Ecclesiastes": "Eccl",
            "Song of Solomon": "Song",
            "Lamentations": "Lam",
            "1 Thessalonians": "1 Thess",
            "2 Thessalonians": "2 Thess",
            "1 Corinthians": "1 Cor",
            "2 Corinthians": "2 Cor",
            "Philippians": "Phil",
            "Colossians": "Col",
            "Revelation": "Rev"
        ]
        return longBookAbbreviations[book.name] ?? book.name
    }

    var body: some View {
        HStack(spacing: 8) {
            // Book + Chapter navigation button with integrated translation
            Button(action: onNavigationTap) {
                HStack(spacing: 6) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.reforgedGold)

                    Text("\(displayBookName) \(chapter)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            }

            // Translation dropdown menu
            Menu {
                ForEach(BibleTranslation.allCases) { t in
                    Button {
                        onTranslationSelect(t)
                    } label: {
                        HStack {
                            Text(t.rawValue)
                            if t == translation {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(translation.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(minWidth: 44)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color.reforgedNavy)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            }
            .fixedSize()

            Spacer()

            // Search button
            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            }

            // Audio button
            Button(action: onAudioTap) {
                ZStack {
                    Circle()
                        .fill(showAudioPlayer || audioPlayer.isPlaying ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)

                    Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "headphones")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(showAudioPlayer || audioPlayer.isPlaying ? .white : iconColor)
                }
            }

            // Formatting button
            Button(action: onFormatTap) {
                Image(systemName: "textformat.size")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
        .padding(.vertical, 8)
        .background(Color.adaptiveBackground(colorScheme))
    }
}

// MARK: - Floating Chapter Navigation (Side-positioned Circle Buttons)

struct FloatingChapterNav: View {
    let currentChapter: Int
    let totalChapters: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            // Previous chapter button (left side)
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(currentChapter > 1 ? .white : Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        currentChapter > 1
                            ? Color.reforgedNavy
                            : Color.adaptiveCardBackground(colorScheme)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(currentChapter <= 1)

            Spacer()

            // Next chapter button (right side)
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(currentChapter < totalChapters ? .white : Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        currentChapter < totalChapters
                            ? Color.reforgedNavy
                            : Color.adaptiveCardBackground(colorScheme)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(currentChapter >= totalChapters)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Bible Audio Bar (Collapsible)

class BibleAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var skipInterval: TimeInterval = 10.0
    @Published var currentBook: String = ""
    @Published var currentChapter: Int = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    /// Called when a chapter finishes playing (for marking as read + auto-advance).
    /// Parameters: (book, chapter) of the completed chapter.
    var onChapterCompleted: ((String, Int) -> Void)?

    // Persistence keys for resuming audio across app backgrounding
    private let audioBookKey = "audio_last_book"
    private let audioChapterKey = "audio_last_chapter"
    private let audioWasPlayingKey = "audio_was_playing"
    private let audioTimeKey = "audio_last_time"

    init() {
        setupRemoteCommandCenter()
    }

    /// Update settings from SettingsManager (call from view)
    @MainActor
    func updateFromSettings() {
        playbackRate = SettingsManager.shared.playbackSpeed.rate
        skipInterval = TimeInterval(SettingsManager.shared.skipInterval.seconds)
        if skipInterval == 0 { skipInterval = 10 } // Default for "By Verse" mode
        player?.rate = isPlaying ? playbackRate : 0
    }

    func play(book: String, chapter: Int) {
        guard let url = ESVService.shared.getAudioURL(book: book, chapter: chapter) else { return }

        stop()
        isLoading = true
        currentBook = book
        currentChapter = chapter

        // Persist current audio state for resume
        saveAudioState()

        do {
            // Configure audio session for background playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Token \(ESVConfig.apiKey)"]
        ])

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.rate = playbackRate

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleChapterPlaybackEnded()
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds

            if let duration = self.player?.currentItem?.duration.seconds,
               !duration.isNaN {
                self.duration = duration
            }

            if self.isLoading && time.seconds > 0 {
                self.isLoading = false
            }

            // Update Now Playing info periodically
            self.updateNowPlayingInfo()

            // Periodically save audio position for resume (every ~5 seconds)
            if Int(time.seconds) % 5 == 0 && time.seconds > 0 {
                self.saveAudioState()
            }
        }

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        saveAudioState()
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        clearAudioState()
        clearNowPlayingInfo()
    }

    // MARK: - Chapter Completion & Auto-Advance

    /// Called when AVPlayer finishes playing the current chapter.
    private func handleChapterPlaybackEnded() {
        let finishedBook = currentBook
        let finishedChapter = currentChapter

        // Notify BibleView to mark chapter as read
        onChapterCompleted?(finishedBook, finishedChapter)

        // Auto-advance to next chapter
        if let nextChapter = nextChapterInfo(book: finishedBook, chapter: finishedChapter) {
            play(book: nextChapter.book, chapter: nextChapter.chapter)
        } else {
            // No more chapters (end of Revelation) — just stop
            isPlaying = false
            currentTime = 0
            updateNowPlayingInfo()
        }
    }

    /// Returns the next book/chapter in canonical order, or nil if at end of Bible.
    private func nextChapterInfo(book: String, chapter: Int) -> (book: String, chapter: Int)? {
        guard let bookData = BibleData.books.first(where: { $0.name == book }) else { return nil }

        // If there are more chapters in this book, go to next chapter
        if chapter < bookData.chapters {
            return (book: book, chapter: chapter + 1)
        }

        // Otherwise, go to next book chapter 1
        guard let bookIndex = BibleData.books.firstIndex(where: { $0.name == book }),
              bookIndex + 1 < BibleData.books.count else {
            return nil // End of Bible
        }

        let nextBook = BibleData.books[bookIndex + 1]
        return (book: nextBook.name, chapter: 1)
    }

    // MARK: - Audio State Persistence (for resume on foreground)

    private func saveAudioState() {
        UserDefaults.standard.set(currentBook, forKey: audioBookKey)
        UserDefaults.standard.set(currentChapter, forKey: audioChapterKey)
        UserDefaults.standard.set(isPlaying, forKey: audioWasPlayingKey)
        UserDefaults.standard.set(currentTime, forKey: audioTimeKey)
    }

    /// Public wrapper for saving audio state (called from BibleView on resign active).
    func saveAudioStatePublic() {
        saveAudioState()
    }

    func clearAudioState() {
        UserDefaults.standard.removeObject(forKey: audioBookKey)
        UserDefaults.standard.removeObject(forKey: audioChapterKey)
        UserDefaults.standard.removeObject(forKey: audioWasPlayingKey)
        UserDefaults.standard.removeObject(forKey: audioTimeKey)
    }

    /// Returns saved audio state, or nil if none exists.
    func savedAudioState() -> (book: String, chapter: Int, time: TimeInterval)? {
        guard let book = UserDefaults.standard.string(forKey: audioBookKey),
              !book.isEmpty else { return nil }
        let chapter = UserDefaults.standard.integer(forKey: audioChapterKey)
        let wasPlaying = UserDefaults.standard.bool(forKey: audioWasPlayingKey)
        let time = UserDefaults.standard.double(forKey: audioTimeKey)
        guard chapter > 0, wasPlaying else { return nil }
        return (book: book, chapter: chapter, time: time)
    }

    /// Resumes playback from saved state (call on app foreground / view appear).
    func resumeFromSavedState() {
        guard let saved = savedAudioState() else { return }
        // Only resume if not already playing something
        guard !isPlaying && player == nil else { return }

        play(book: saved.book, chapter: saved.chapter)

        // Seek to the saved position after a short delay to let the player load
        if saved.time > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.seek(to: saved.time)
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updateNowPlayingInfo()
    }

    func skipForward(_ seconds: TimeInterval? = nil) {
        let interval = seconds ?? skipInterval
        let newTime = min(currentTime + interval, duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval? = nil) {
        let interval = seconds ?? skipInterval
        let newTime = max(currentTime - interval, 0)
        seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
        updateNowPlayingInfo()
    }

    // MARK: - Now Playing Info (Lock Screen & Control Center)

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(currentBook) \(currentChapter)"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "ESV Audio Bible"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Reforged"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote Command Center (Headphones, Lock Screen Controls)

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.player?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.player?.pause()
                self.isPlaying = false
                self.updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        // Skip forward/backward
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(15)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(15)
            return .success
        }

        // Seek
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    deinit {
        stop()
    }
}

struct BibleAudioBar: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    let book: String
    let chapter: Int
    var translation: BibleTranslation = .esv
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var timeString: String {
        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(audioPlayer.duration)
        return "\(current) / \(total)"
    }

    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var iconColor: Color {
        colorScheme == .dark ? Color(white: 0.9) : Color.reforgedNavy
    }

    /// Whether the audio is playing a different chapter than the one being read
    var isPlayingDifferentChapter: Bool {
        !audioPlayer.currentBook.isEmpty &&
        (audioPlayer.currentBook != book || audioPlayer.currentChapter != chapter)
    }

    var body: some View {
        VStack(spacing: 8) {
            // "Now playing" label when audio has auto-advanced to a different chapter
            if isPlayingDifferentChapter {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.reforgedGold)
                    Text("Now playing: \(audioPlayer.currentBook) \(audioPlayer.currentChapter)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.reforgedGold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.reforgedNavy.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.reforgedGold)
                        .frame(width: audioPlayer.duration > 0 ? geo.size.width * (audioPlayer.currentTime / audioPlayer.duration) : 0)
                }
            }
            .frame(height: 3)
            .padding(.horizontal)

            HStack(spacing: 16) {
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveBorder(colorScheme))
                        .clipShape(Circle())
                }

                // Skip backward
                Button { audioPlayer.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.callout)
                        .foregroundStyle(iconColor)
                }

                // Play/Pause button
                Button {
                    if audioPlayer.isPlaying || audioPlayer.currentTime > 0 {
                        audioPlayer.togglePlayPause()
                    } else {
                        audioPlayer.play(book: book, chapter: chapter)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.reforgedNavy)
                            .frame(width: 36, height: 36)

                        if audioPlayer.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // Skip forward
                Button { audioPlayer.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.callout)
                        .foregroundStyle(iconColor)
                }

                // Time
                Text(timeString)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 70)

                Spacer()

                // Speed button
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            audioPlayer.setPlaybackRate(Float(rate))
                        } label: {
                            HStack {
                                Text("\(String(format: "%.2g", rate))x")
                                if audioPlayer.playbackRate == Float(rate) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(String(format: "%.1f", audioPlayer.playbackRate))x")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.adaptiveBorder(colorScheme))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Unified Navigation View (YouVersion-style)

struct UnifiedNavigationView: View {
    @Binding var selectedBook: BibleBook
    @Binding var selectedChapter: Int
    var recentPassages: [(book: String, chapter: Int)]
    @Binding var isPresented: Bool
    let onSelect: () -> Void
    var onSelectVerse: ((Int) -> Void)? = nil
    var translation: BibleTranslation = .esv
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

    var filteredBooks: [BibleBook] {
        var books = BibleData.books

        if let testament = selectedTestament {
            books = books.filter { $0.testament == testament }
        }

        if !searchText.isEmpty {
            books = books.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                            ForEach(recentPassages.prefix(5), id: \.book) { passage in
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
                                        .background(colorScheme == .dark ? Color(white: 0.25) : Color.reforgedNavy.opacity(0.1))
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

                TextField("Search books...", text: $searchText)
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
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

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
                                                loadVersesForChapter()
                                                withAnimation(.spring(response: 0.3)) {
                                                    showVersePicker = true
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
                                                        : (colorScheme == .dark ? Color(white: 0.2) : Color(.systemGray6))
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

            if isLoadingVerses {
                Spacer()
                ProgressView("Loading verses...")
                Spacer()
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
                                    .background(colorScheme == .dark ? Color(white: 0.2) : Color(.systemGray6))
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
                        ? (colorScheme == .dark ? Color(white: 0.25) : .white)
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
                        ? (colorScheme == .dark ? Color(white: 0.25) : .white)
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
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
                case .csb, .nkjv, .nasb:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
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
                .background(isSelected ? Color.reforgedNavy : (colorScheme == .dark ? Color(white: 0.25) : Color.reforgedNavy.opacity(0.1)))
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

    /// Filter search results by book category
    var filteredResults: [BibleSearchResult] {
        guard let category = selectedCategory else { return searchResults }
        let booksInCategory = BibleData.books.filter { $0.category == category }.map { $0.name }
        return searchResults.filter { result in
            booksInCategory.contains { bookName in
                result.reference.hasPrefix(bookName)
            }
        }
    }

    /// Count results per book category for the chart
    var categoryCounts: [BookCategory: Int] {
        var counts: [BookCategory: Int] = [:]
        for category in BookCategory.allCases {
            let booksInCategory = BibleData.books.filter { $0.category == category }.map { $0.name }
            let count = searchResults.filter { result in
                booksInCategory.contains { bookName in
                    result.reference.hasPrefix(bookName)
                }
            }.count
            counts[category] = count
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
                case .csb, .nkjv, .nasb:
                    let apiResults = try await ApiBibleService.shared.searchPassages(query: searchQuery, translation: translation, pageSize: 100)
                    results = apiResults.map { BibleSearchResult(reference: $0.reference, content: $0.text) }
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

// MARK: - Formatting Panel View

struct FormattingPanelView: View {
    @ObservedObject var settings: BibleReadingSettings
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            FormattingPanelBackground(isPresented: $isPresented)
            FormattingPanelContent(
                settings: settings,
                isPresented: $isPresented,
                themeManager: themeManager
            )
        }
    }
}

// MARK: - Formatting Panel Background

private struct FormattingPanelBackground: View {
    @Binding var isPresented: Bool

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.35)) {
                    isPresented = false
                }
            }
    }
}

// MARK: - Formatting Panel Content

private struct FormattingPanelContent: View {
    @ObservedObject var settings: BibleReadingSettings
    @Binding var isPresented: Bool
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let panelWidth: CGFloat = horizontalSizeClass == .regular
                ? min(380, availableWidth * 0.55)
                : availableWidth * 0.85
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    FormattingPanelHeader(isPresented: $isPresented)
                    FormattingPanelScrollContent(settings: settings, themeManager: themeManager)
                }
                .frame(width: panelWidth)
                .frame(maxHeight: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: -4, y: 0)
            }
        }
    }
}

// MARK: - Formatting Panel Header

private struct FormattingPanelHeader: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text("Display")
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
    }
}

// MARK: - Formatting Panel Scroll Content

private struct FormattingPanelScrollContent: View {
    @ObservedObject var settings: BibleReadingSettings
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                FormattingThemeSection(themeManager: themeManager)
                FormattingFontSizeSection(settings: settings)
                FormattingFontTypeSection(settings: settings)
                FormattingLineSpacingSection(settings: settings)
                FormattingVerseLayoutSection(settings: settings)
            }
            .padding()
        }
    }
}

// MARK: - Theme Section

private struct FormattingThemeSection: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            HStack(spacing: 10) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    FormattingThemeButton(mode: mode, isSelected: themeManager.currentMode == mode) {
                        themeManager.currentMode = mode
                    }
                }
            }
        }
    }
}

private struct FormattingThemeButton: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                Text(mode.rawValue)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.reforgedNavy : Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Font Size Section

private struct FormattingFontSizeSection: View {
    @ObservedObject var settings: BibleReadingSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Size")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            HStack(spacing: 8) {
                ForEach(BibleReadingSettings.FontSize.allCases, id: \.self) { size in
                    FormattingFontSizeButton(size: size, isSelected: settings.fontSize == size) {
                        settings.fontSize = size
                    }
                }
            }
        }
    }
}

private struct FormattingFontSizeButton: View {
    let size: BibleReadingSettings.FontSize
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var displaySize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 18
        }
    }

    var body: some View {
        Button(action: action) {
            Text("Aa")
                .font(.system(size: displaySize))
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Font Type Section

private struct FormattingFontTypeSection: View {
    @ObservedObject var settings: BibleReadingSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Type")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            ForEach(BibleReadingSettings.FontType.allCases, id: \.self) { fontType in
                FormattingFontTypeRow(fontType: fontType, isSelected: settings.fontType == fontType) {
                    settings.fontType = fontType
                }
            }
        }
    }
}

private struct FormattingFontTypeRow: View {
    let fontType: BibleReadingSettings.FontType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack {
                Text(fontType.displayName)
                    .font(.system(size: 15, design: fontType.design))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .foregroundStyle(Color.adaptiveText(colorScheme))
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Line Spacing Section

private struct FormattingLineSpacingSection: View {
    @ObservedObject var settings: BibleReadingSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line Spacing")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            HStack(spacing: 8) {
                ForEach(BibleReadingSettings.LineSpacingOption.allCases, id: \.self) { spacing in
                    FormattingLineSpacingButton(spacing: spacing, isSelected: settings.lineSpacing == spacing) {
                        settings.lineSpacing = spacing
                    }
                }
            }
        }
    }
}

private struct FormattingLineSpacingButton: View {
    let spacing: BibleReadingSettings.LineSpacingOption
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(spacing.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveBackground(colorScheme))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Verse Layout Section

private struct FormattingVerseLayoutSection: View {
    @ObservedObject var settings: BibleReadingSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verse Layout")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Toggle(isOn: $settings.verseByVerse) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verse-by-Verse")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Each verse on its own line")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .tint(Color.reforgedGold)
        }
    }
}

// MARK: - Chapter Header

struct ChapterHeader: View {
    let book: String
    let chapter: Int
    let canonical: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        VStack(spacing: 6) {
            Text(book)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.reforgedGold)
                .textCase(.uppercase)
                .tracking(1)

            Text("Chapter \(chapter)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, horizontalSizeClass == .regular ? 16 : 20)
    }
}

// MARK: - Verse Row

struct VerseRow: View {
    let verse: ParsedVerse
    let highlight: VerseHighlight?
    let hasNote: Bool
    let isSelected: Bool
    let settings: BibleReadingSettings
    let verseByVerse: Bool
    var highlightedWord: (verseID: String, word: String)? = nil
    let onTap: () -> Void
    var onWordLongPress: ((String, ParsedVerse) -> Void)? = nil
    @ObservedObject var readingState: BibleReadingState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Superscript verse number
            Text("\(verse.number)")
                .font(.system(size: settings.fontSize.verseNumberSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.reforgedGold)
                .baselineOffset(6)
                .padding(.leading, 2)

            // Verse text with highlighter effect
            HStack(alignment: .top, spacing: 0) {
                if let wordLookup = onWordLongPress {
                    // Clean text with long-press word lookup
                    WordLongPressVerseText(
                        verse: verse,
                        settings: settings,
                        highlight: highlight,
                        isSelected: isSelected,
                        highlightedWord: highlightedWord,
                        colorScheme: colorScheme,
                        onWordLongPress: wordLookup
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Plain text (fallback)
                    Text(verse.text)
                        .font(.system(size: settings.fontSize.size, weight: .regular, design: settings.fontType.design))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineSpacing(settings.lineSpacing.spacing)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                        .padding(.horizontal, highlight != nil ? 4 : 0)
                        .background(
                            Group {
                                if let hl = highlight {
                                    HighlighterBackground(color: hl.baseColor)
                                }
                            }
                        )
                }

                // Note indicator - small icon next to the verse
                if hasNote {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.reforgedGold)
                        .padding(4)
                        .background(Color.reforgedGold.opacity(0.15))
                        .clipShape(Circle())
                        .padding(.leading, 6)
                }
            }
            .padding(.vertical, verseByVerse ? 6 : 2)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        // Subtle gold selection background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.reforgedGold.opacity(0.15))
                    }
                }
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// Note: Word-level text selection uses iOS native text selection.
// Users can long-press on verse text to select specific words using the native iOS selection handles,
// then copy the selected text. The verse highlighting feature applies to the entire verse.

// MARK: - Selection Action Bar

enum SelectionAction {
    case highlight(HighlightColor)
    case removeHighlight
    case addNote
    case addToMemory
    case copy
    case share
}

struct SelectionActionBar: View {
    @ObservedObject var readingState: BibleReadingState
    let onAction: (SelectionAction) -> Void
    @State private var showColorPicker = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Color picker
            if showColorPicker {
                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases) { color in
                        Button {
                            onAction(.highlight(color))
                            withAnimation { showColorPicker = false }
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: color.color.opacity(0.4), radius: 4, y: 2)
                        }
                    }

                    // Clear highlight
                    Button {
                        onAction(.removeHighlight)
                        withAnimation { showColorPicker = false }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.adaptiveCardBackground(colorScheme))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }

            // Action buttons
            HStack(spacing: 16) {
                ActionBarButton(icon: "highlighter", label: "Highlight") {
                    withAnimation(.spring(response: 0.3)) {
                        showColorPicker.toggle()
                    }
                }

                ActionBarButton(icon: "note.text", label: "Note") {
                    onAction(.addNote)
                }

                ActionBarButton(icon: "brain.head.profile", label: "Memory") {
                    onAction(.addToMemory)
                }

                ActionBarButton(icon: "doc.on.doc", label: "Copy") {
                    onAction(.copy)
                }

                ActionBarButton(icon: "square.and.arrow.up", label: "Share") {
                    onAction(.share)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.15), radius: 20, y: -5)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct ActionBarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var iconColor: Color {
        if isActive {
            return Color.reforgedGold
        }
        return colorScheme == .dark ? Color(white: 0.9) : Color.reforgedNavy
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(iconColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                isActive ? Color.reforgedGold.opacity(0.15) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Take Note View (Improved Verse Action Sheet)

struct TakeNoteView: View {
    let verse: ParsedVerse
    @ObservedObject var readingState: BibleReadingState
    let onDismiss: () -> Void

    @State private var noteText: String = ""
    @FocusState private var isNoteFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var existingNote: VerseNote? {
        readingState.getNote(for: verse.reference)
    }

    var existingHighlight: VerseHighlight? {
        readingState.getHighlight(for: verse.reference)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header spacing
                Spacer().frame(height: 16)

                // Verse preview
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.reference)
                        .font(.headline)
                        .foregroundStyle(Color.reforgedGold)

                    Text(verse.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                .padding(.horizontal)

                // Spacer between verse and highlight
                Spacer().frame(height: 24)

                // Highlight section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Highlight")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    HStack(spacing: 12) {
                        ForEach(HighlightColor.allCases) { color in
                            Button {
                                // Haptic feedback for highlighting
                                HapticManager.shared.verseHighlighted()

                                readingState.highlight(
                                    reference: verse.reference,
                                    book: readingState.currentBook,
                                    chapter: readingState.currentChapter,
                                    verse: verse.number,
                                    color: color
                                )
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                existingHighlight?.color == color.rawValue ? Color.reforgedNavy : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                            }
                        }

                        Spacer()

                        if existingHighlight != nil {
                            Button {
                                HapticManager.shared.lightImpact()
                                readingState.removeHighlight(reference: verse.reference)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Spacer
                Spacer().frame(height: 24)

                // Note section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Note")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        Spacer()

                        if existingNote != nil {
                            Button {
                                readingState.removeNote(reference: verse.reference)
                                noteText = ""
                            } label: {
                                Text("Delete")
                                    .font(.caption)
                                    .foregroundStyle(Color.reforgedCoral)
                            }
                        }
                    }

                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                        )
                        .focused($isNoteFocused)

                    Button {
                        // Haptic feedback for saving note
                        HapticManager.shared.noteSaved()

                        if existingNote != nil {
                            readingState.updateNote(reference: verse.reference, content: noteText)
                        } else {
                            readingState.addNote(
                                reference: verse.reference,
                                book: readingState.currentBook,
                                chapter: readingState.currentChapter,
                                verse: verse.number,
                                content: noteText
                            )
                        }
                        onDismiss()
                    } label: {
                        Text(existingNote != nil ? "Update Note" : "Save Note")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(noteText.isEmpty ? Color.gray : Color.reforgedNavy)
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    }
                    .disabled(noteText.isEmpty)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Take Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                noteText = existingNote?.content ?? ""
            }
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.reforgedGold)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.reforgedCoral)

            Text("Error Loading Chapter")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onRetry()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.reforgedNavy)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
}

struct ESVAttribution: View {
    var translation: BibleTranslation = .esv
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal)

            Text(translation.attribution)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ReforgedTheme.spacingL)
        }
        .padding(.vertical, ReforgedTheme.spacingL)
    }
}

// MARK: - Add to Memory Sheet

struct AddToMemorySheet: View {
    let verses: [ParsedVerse]
    let book: String
    let chapter: Int
    var translation: BibleTranslation = .esv
    let onDismiss: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedCategory = "General"

    let categories = ["Salvation", "Trust", "Strength", "Hope", "Guidance", "Love", "Faith", "Peace", "General"]

    var combinedReference: String {
        if verses.count == 1 {
            return verses[0].reference
        } else {
            let firstVerse = verses.first?.number ?? 1
            let lastVerse = verses.last?.number ?? 1
            return "\(book) \(chapter):\(firstVerse)-\(lastVerse)"
        }
    }

    var combinedText: String {
        verses.map { $0.text }.joined(separator: " ")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Reference
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reference")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(combinedReference)
                        .font(.headline)
                        .foregroundStyle(Color.reforgedGold)
                }

                // Text preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verse Text")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(combinedText)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.adaptiveBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(selectedCategory == category ? .white : Color.adaptiveText(colorScheme))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.reforgedNavy : Color.adaptiveBackground(colorScheme))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Add button
                Button {
                    addToMemory()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                        Text("Add to Memory")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Add to Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }

    func addToMemory() {
        let verse = MemoryVerse(
            id: UUID().uuidString,
            reference: combinedReference,
            text: combinedText,
            esvText: combinedText,
            category: selectedCategory,
            translation: translation.rawValue,
            lastFetched: ISO8601DateFormatter().string(from: Date()),
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
        appState.addMemoryVerse(verse)
        onDismiss()
    }
}

#Preview {
    BibleView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
