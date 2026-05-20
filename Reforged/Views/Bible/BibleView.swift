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
    @ObservedObject private var olService = OriginalLanguageService.shared
    @StateObject private var audioPlayer = BibleAudioPlayer()
    @StateObject private var readingSettings = BibleReadingSettings.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation

    // Navigation state
    @State private var selectedBook: BibleBook = BibleData.defaultBook
    @State private var selectedChapter: Int = 3
    @State private var showUnifiedNavigation = false
    @State private var showSearchPanel = false
    @State private var showFormattingPanel = false
    @State private var showAudioPlayer = false
    @State private var showNowPlaying = false
    @State private var currentTranslation: BibleTranslation = .kjv

    // Reading mode
    @State private var readingModeOverride = false          // shows bars when reading mode is on
    @State private var readingModeHideTask: Task<Void, Never>? = nil
    /// True when bars were manually toggled visible by a tap — prevents scroll-away from hiding them
    @State private var barsPinnedByTap = false

    // Pinch-to-resize
    @State private var fontSizeIndicator: String? = nil     // brief HUD label shown after snap
    @State private var fontSizeIndicatorTask: Task<Void, Never>? = nil

    // Content state
    @State private var verses: [ParsedVerse] = []
    @State private var passageText: String = ""
    @State private var canonicalReference = ""
    @State private var chapterSections: [VerseSection] = []
    @State private var wordsOfChristSegmentsByReference: [String: [WOCSegment]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>? = nil   // tracks in-flight chapter fetch
    @State private var scrollPosition: CGFloat = 0

    // Chapter cache: pre-fetched neighbor chapters for instant swipe transitions
    @State private var chapterCache: [ChapterCacheKey: ChapterCacheEntry] = [:]
    @State private var prefetchTasks: [ChapterCacheKey: Task<Void, Never>] = [:]

    // Chapter transition animation state
    @State private var chapterTransitionOffset: CGFloat = 0
    @State private var chapterTransitionOpacity: Double = 1.0
    /// Direction-lock for the horizontal swipe gesture. nil = undecided, true = horizontal, false = vertical.
    @State private var isHorizontalDrag: Bool? = nil
    /// True while animateChapterChange is running. Blocks the swipe gesture from interfering.
    @State private var isChapterTransitioning = false

    // Search state
    @State private var searchQuery = ""
    @State private var searchResults: [BibleSearchResult] = []
    @State private var searchHistory: [BibleSearchHistoryEntry] = []
    @State private var recentPassages: [(book: String, chapter: Int)] = []
    @State private var isSearching = false
    @State private var scrollToVerseID: String? = nil
    @State private var immediateScrollToVerseID: String? = nil  // no-animation restore scroll
    @State private var firstVisibleVerseNumber: Int = 1
    @State private var hasAppeared = false
    @State private var isRestoringPosition = false
    /// Per-chapter last-read verse: "Book Chapter" → verse number. Used to restore position on backward navigation.
    @State private var chapterScrollPositions: [String: Int] = [:]
    /// Verse number to scroll to on the next loadChapter() call. nil = scroll to top.
    @State private var pendingScrollVerse: Int? = nil
    @State private var pendingNavigationVerse: Int? = nil
    private let chapterTopScrollID = "chapter-top"

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

    // Translation compatibility alerts (TR = NT only, WLC = OT only)
    @State private var showTRTestamentAlert = false
    @State private var showWLCTestamentAlert = false

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

    // Reading mode: bars are visible when reading mode is off, OR when temporarily overridden by a tap
    private var barsVisible: Bool {
        !settingsManager.readingMode || readingModeOverride
    }

    private func revealBarsTemporarily() {
        readingModeHideTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            readingModeOverride = true
        }
        readingModeHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    readingModeOverride = false
                }
                readingModeHideTask = nil
            }
        }
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
        Color.adaptivePrimaryIcon(colorScheme)
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
        // Start audio if not already loaded
        if !audioPlayer.isPlaying && audioPlayer.currentTime == 0 && audioPlayer.currentBook.isEmpty {
            audioPlayer.updateFromSettings()
            audioPlayer.play(book: selectedBook.name, chapter: selectedChapter, translation: currentTranslation)
            showAudioPlayer = true
        }
        showNowPlaying = true
    }

    private func onFormatTap() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showFormattingPanel = true
        }
    }

    private func onTranslationSelect(_ newTranslation: BibleTranslation) {
        // TR only covers the NT — prompt before switching if user is in an OT passage.
        if newTranslation == .tr && selectedBook.testament == .old {
            showTRTestamentAlert = true
            return
        }
        // WLC only covers the OT — prompt before switching if user is in an NT passage.
        if newTranslation == .wlc && selectedBook.testament == .new {
            showWLCTestamentAlert = true
            return
        }
        applyTranslationSwitch(newTranslation)
    }

    /// Commits a translation change, optionally redirecting to a different book/chapter first.
    private func applyTranslationSwitch(_ newTranslation: BibleTranslation,
                                        redirectTo book: BibleBook? = nil,
                                        chapter: Int = 1) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            settingsManager.defaultTranslation = newTranslation
            currentTranslation = newTranslation

            // Clear the chapter cache so no stale data bleeds through.
            chapterCache.removeAll()
            prefetchTasks.values.forEach { $0.cancel() }
            prefetchTasks.removeAll()

            if let redirectBook = book {
                selectedBook = redirectBook
                selectedChapter = chapter
            }

            loadChapter()
        }
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Top Navigation Bar (iPhone only — iPad uses .toolbar)
                if barsVisible && !isSidebarNavigation {
                    BibleTopBar(
                        book: selectedBook,
                        chapter: selectedChapter,
                        translation: currentTranslation,
                        translationOrder: settingsManager.translationOrder,
                        showOriginalLanguagesInSwitcher: settingsManager.showOriginalLanguagesInSwitcher,
                        showAudioPlayer: showAudioPlayer,
                        audioPlayer: audioPlayer,
                        onNavigationTap: onNavigationTap,
                        onSearchTap: onSearchTap,
                        onAudioTap: onAudioTap,
                        onFormatTap: onFormatTap,
                        onTranslationSelect: { newTranslation in
                            onTranslationSelect(newTranslation)
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Chapter content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            chapterContentView
                        }
                        // contentShape makes the entire column (including empty margins) hittable.
                        // SwiftUI's gesture priority means child verse-text views consume their own
                        // taps first; this handler only fires when empty space is tapped.
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard settingsManager.readingMode else { return }
                            readingModeHideTask?.cancel()
                            readingModeHideTask = nil
                            let showing = !readingModeOverride
                            barsPinnedByTap = showing
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                readingModeOverride = showing
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
                                    .preference(key: ScrollTopPreferenceKey.self, value: geo.frame(in: .named("bibleScroll")).minY)
                            }
                        )
                    }
                    .scrollIndicators(.hidden)
                    .coordinateSpace(name: "bibleScroll")
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
                    .onPreferenceChange(ScrollTopPreferenceKey.self) { minY in
                        // Show bars when scrolled to top; hide when scrolled away (unless pinned by tap)
                        guard settingsManager.readingMode && !isLoading else { return }
                        let atTop = minY > -60
                        if atTop {
                            // Scroll-to-top always shows bars and releases any tap-pin
                            readingModeHideTask?.cancel()
                            readingModeHideTask = nil
                            barsPinnedByTap = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                readingModeOverride = true
                            }
                        } else if !barsPinnedByTap {
                            // Only auto-hide when the user hasn't manually pinned bars via tap
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                readingModeOverride = false
                            }
                        }
                    }
                    .onPreferenceChange(VerseMinYKey.self) { positions in
                        // Find the topmost visible verse (smallest minY >= -20 in scroll space)
                        if let top = positions.filter({ $0.value >= -20 }).min(by: { $0.value < $1.value }),
                           let colonIdx = top.key.lastIndex(of: ":"),
                           let verseNum = Int(String(top.key[top.key.index(after: colonIdx)...])) {
                            firstVisibleVerseNumber = verseNum
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                // Do not interfere with a programmatic chapter transition
                                guard !isChapterTransitioning else { return }

                                let h = value.translation.width
                                let v = value.translation.height

                                // Lock drag direction on the first definitive movement
                                if isHorizontalDrag == nil {
                                    if abs(h) > abs(v) * 1.5 {
                                        isHorizontalDrag = true
                                    } else if abs(v) > 12 {
                                        isHorizontalDrag = false
                                    }
                                }

                                // Track finger position in real time for horizontal swipes
                                guard isHorizontalDrag == true else { return }
                                chapterTransitionOffset = h
                            }
                            .onEnded { value in
                                // Do not interfere with a programmatic chapter transition
                                guard !isChapterTransitioning else {
                                    isHorizontalDrag = nil
                                    return
                                }

                                let wasHorizontal = isHorizontalDrag == true
                                isHorizontalDrag = nil

                                guard wasHorizontal else {
                                    // Not a horizontal drag — snap content back if it moved at all
                                    if chapterTransitionOffset != 0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            chapterTransitionOffset = 0
                                        }
                                    }
                                    return
                                }

                                let h = value.translation.width
                                let predictedH = value.predictedEndTranslation.width
                                // Commit if dragged past threshold or finger velocity is high enough
                                let commitForward  = h < -60 || predictedH < -200
                                let commitBackward = h >  60 || predictedH >  200

                                if commitForward {
                                    // Swipe left → next chapter / first chapter of next book
                                    animateChapterChange(direction: .forward, fromDrag: true) {
                                        // Save current position, then go to top of new chapter
                                        chapterScrollPositions["\(selectedBook.name) \(selectedChapter)"] = firstVisibleVerseNumber
                                        pendingScrollVerse = nil
                                        if selectedChapter < selectedBook.chapters {
                                            selectedChapter += 1
                                        } else if let idx = BibleData.books.firstIndex(where: { $0.name == selectedBook.name }),
                                                  idx + 1 < BibleData.books.count {
                                            selectedBook = BibleData.books[idx + 1]
                                            selectedChapter = 1
                                        }
                                        loadChapter()
                                    }
                                } else if commitBackward {
                                    // Swipe right → previous chapter / last chapter of previous book
                                    if value.startLocation.x < 50 {
                                        withAnimation(.spring(response: 0.35)) {
                                            showSearchPanel = true
                                        }
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            chapterTransitionOffset = 0
                                        }
                                    } else {
                                        animateChapterChange(direction: .backward, fromDrag: true) {
                                            // Save current position and restore last-read position of previous chapter
                                            chapterScrollPositions["\(selectedBook.name) \(selectedChapter)"] = firstVisibleVerseNumber
                                            if selectedChapter > 1 {
                                                pendingScrollVerse = chapterScrollPositions["\(selectedBook.name) \(selectedChapter - 1)"]
                                                selectedChapter -= 1
                                            } else if let idx = BibleData.books.firstIndex(where: { $0.name == selectedBook.name }),
                                                      idx > 0 {
                                                let prevBook = BibleData.books[idx - 1]
                                                pendingScrollVerse = chapterScrollPositions["\(prevBook.name) \(prevBook.chapters)"]
                                                selectedBook = prevBook
                                                selectedChapter = selectedBook.chapters
                                            }
                                            loadChapter()
                                        }
                                    }
                                } else {
                                    // Didn't reach threshold — spring back to rest
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        chapterTransitionOffset = 0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                // Apply live scale so the text scales smoothly between snap points
                                let clamped = min(max(value, 0.7), 1.65)
                                readingSettings.temporaryScale = clamped

                                // Also snap the persistent fontSize during the gesture so the
                                // slider tracks the pinch in real-time.
                                let liveSize = readingSettings.fontSize.size * clamped
                                let nearest = BibleReadingSettings.FontSize.nearest(to: liveSize)
                                if nearest != readingSettings.fontSize {
                                    readingSettings.fontSize = nearest
                                    HapticManager.shared.lightImpact()
                                }
                            }
                            .onEnded { value in
                                // Finalise: clear temporary scale (fontSize already updated above)
                                let finalSize = readingSettings.fontSize.size * min(max(value, 0.7), 1.65)
                                let nearest = BibleReadingSettings.FontSize.nearest(to: finalSize)
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                                    readingSettings.fontSize = nearest
                                    readingSettings.temporaryScale = 1.0
                                }
                                // Show a brief font size indicator HUD
                                fontSizeIndicatorTask?.cancel()
                                fontSizeIndicator = nearest.displayName
                                fontSizeIndicatorTask = Task {
                                    try? await Task.sleep(for: .seconds(1.5))
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run {
                                        withAnimation(.easeOut(duration: 0.3)) { fontSizeIndicator = nil }
                                        fontSizeIndicatorTask = nil
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
                    .onChange(of: immediateScrollToVerseID) { targetID in
                        if let targetID = targetID {
                            // Jump directly with no animation (used for position restore on open)
                            proxy.scrollTo(targetID, anchor: .top)
                            self.immediateScrollToVerseID = nil
                            withAnimation(.easeIn(duration: 0.15)) {
                                chapterTransitionOpacity = 1.0
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())

            // Floating chapter navigation buttons
            let miniPlayerVisible = !audioPlayer.currentBook.isEmpty
            if barsVisible {
                VStack {
                    Spacer()
                    FloatingChapterNav(
                        hasPrevious: selectedChapter > 1
                            || (BibleData.books.firstIndex(where: { $0.name == selectedBook.name }) ?? 0) > 0,
                        hasNext: selectedChapter < selectedBook.chapters
                            || (BibleData.books.firstIndex(where: { $0.name == selectedBook.name }) ?? BibleData.books.count - 1) < BibleData.books.count - 1,
                        onPrevious: {
                            animateChapterChange(direction: .backward, fromDrag: true) {
                                chapterScrollPositions["\(selectedBook.name) \(selectedChapter)"] = firstVisibleVerseNumber
                                if selectedChapter > 1 {
                                    pendingScrollVerse = chapterScrollPositions["\(selectedBook.name) \(selectedChapter - 1)"]
                                    selectedChapter -= 1
                                } else if let idx = BibleData.books.firstIndex(where: { $0.name == selectedBook.name }), idx > 0 {
                                    let prevBook = BibleData.books[idx - 1]
                                    pendingScrollVerse = chapterScrollPositions["\(prevBook.name) \(prevBook.chapters)"]
                                    selectedBook = prevBook
                                    selectedChapter = selectedBook.chapters
                                }
                                loadChapter()
                            }
                        },
                        onNext: {
                            animateChapterChange(direction: .forward, fromDrag: true) {
                                chapterScrollPositions["\(selectedBook.name) \(selectedChapter)"] = firstVisibleVerseNumber
                                pendingScrollVerse = nil
                                if selectedChapter < selectedBook.chapters {
                                    selectedChapter += 1
                                } else if let idx = BibleData.books.firstIndex(where: { $0.name == selectedBook.name }), idx + 1 < BibleData.books.count {
                                    selectedBook = BibleData.books[idx + 1]
                                    selectedChapter = 1
                                }
                                loadChapter()
                            }
                        }
                    )
                    .padding(.bottom, miniPlayerVisible ? 80 : 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Selection action bar
            if !readingState.selectedVerses.isEmpty {
                VStack {
                    Spacer()
                    SelectionActionBar(readingState: readingState) { action in
                        handleSelectionAction(action)
                    }
                    .padding(.bottom, miniPlayerVisible ? 144 : 70) // Above nav buttons + mini player
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Mini audio player (shown when audio is loaded)
            if miniPlayerVisible {
                VStack {
                    Spacer()
                    AudioMiniPlayerBar(
                        audioPlayer: audioPlayer,
                        onTap: { showNowPlaying = true },
                        onClose: {
                            audioPlayer.stop()
                            showAudioPlayer = false
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Pinch font-size indicator HUD
            if let label = fontSizeIndicator {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "textformat.size")
                            .font(.caption.weight(.semibold))
                        Text(label)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.reforgedNavy.opacity(0.88), in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    Spacer()
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .allowsHitTesting(false)
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
                        addSearchToHistory(searchQuery, translation: result.translation)
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
            let allSelected = verses.filter { readingState.selectedVerses.contains($0.reference) }
            let sheetVerses = allSelected.isEmpty ? [verse] : allSelected
            TakeNoteView(
                verses: sheetVerses,
                readingState: readingState,
                onDismiss: {
                    selectedVerseForAction = nil
                    withAnimation { readingState.clearSelection() }
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
                    let targetVerseID = verseNum <= 1
                        ? chapterTopScrollID
                        : "\(selectedBook.name) \(selectedChapter):\(verseNum)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToVerseID = targetVerseID
                    }
                },
                translation: currentTranslation,
                translationOrder: settingsManager.translationOrder
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioPlayer: audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        // TR is the Greek New Testament — alert when user is in an OT passage
        .alert("New Testament Only", isPresented: $showTRTestamentAlert) {
            Button("Go to Matthew 1") {
                if let matthew = BibleData.books.first(where: { $0.name == "Matthew" }) {
                    applyTranslationSwitch(.tr, redirectTo: matthew, chapter: 1)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Textus Receptus (TR) is the Greek New Testament and only covers Matthew through Revelation. Would you like to go to Matthew 1?")
        }
        // WLC is the Hebrew Old Testament — alert when user is in an NT passage
        .alert("Old Testament Only", isPresented: $showWLCTestamentAlert) {
            Button("Go to Genesis 1") {
                if let genesis = BibleData.books.first(where: { $0.name == "Genesis" }) {
                    applyTranslationSwitch(.wlc, redirectTo: genesis, chapter: 1)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Westminster Leningrad Codex (WLC) is the Hebrew Old Testament and only covers Genesis through Malachi. Would you like to go to Genesis 1?")
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
                            ForEach(settingsManager.translationOrder) { t in
                                Button { onTranslationSelect(t) } label: {
                                    HStack {
                                        Text(t.rawValue)
                                        if t == currentTranslation {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            if settingsManager.showOriginalLanguagesInSwitcher {
                                Divider()
                                Button { onTranslationSelect(.tr) } label: {
                                    HStack {
                                        Text("TR — Greek NT")
                                        if currentTranslation == .tr { Image(systemName: "checkmark") }
                                    }
                                }
                                Button { onTranslationSelect(.wlc) } label: {
                                    HStack {
                                        Text("WLC — Hebrew OT")
                                        if currentTranslation == .wlc { Image(systemName: "checkmark") }
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

                if currentTranslation.supportsAudio {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onAudioTap) {
                            Label("Audio", systemImage: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "headphones")
                        }
                        .tint(!audioPlayer.currentBook.isEmpty || audioPlayer.isPlaying ? Color.reforgedGold : nil)
                    }
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
        .toolbar(barsVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar(barsVisible ? .visible : .hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settingsManager.readingMode) { isOn in
            if !isOn {
                readingModeHideTask?.cancel()
                readingModeOverride = false
                barsPinnedByTap = false
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = settingsManager.keepScreenOn
            guard !hasAppeared else {
                // Tab switch back — do NOT reload; scroll position is already preserved
                audioPlayer.updateFromSettings()
                consumePendingBibleNavigationIfNeeded()
                return
            }
            hasAppeared = true

            // First appearance: restore last reading position
            selectedBook = BibleData.books.first(where: { $0.name == readingSettings.lastBook }) ?? selectedBook
            selectedChapter = readingSettings.lastChapter
            currentTranslation = settingsManager.defaultTranslation
            isRestoringPosition = readingSettings.lastVerse > 1

            loadSearchHistory()
            loadRecentPassages()
            loadChapter()
            consumePendingBibleNavigationIfNeeded()
            audioPlayer.updateFromSettings()

            // Wire up audio chapter completion callback (once)
            audioPlayer.onChapterCompleted = { [self] book, chapter in
                // All state mutations must happen on the main actor regardless of
                // which thread the audio player fires this callback on.
                Task { @MainActor in
                    streakManager.recordChapterRead(book: book, chapter: chapter)
                    _ = appState.markChapterRead(book: book, chapter: chapter)
                    // Brief delay so the audio player's currentBook/currentChapter
                    // have advanced to the next chapter before we read them.
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
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
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: settingsManager.keepScreenOn) { enabled in
            UIApplication.shared.isIdleTimerDisabled = enabled
        }
        .onChange(of: settingsManager.defaultTranslation) { newTranslation in
            // Reload chapter when translation changes
            if currentTranslation != newTranslation {
                loadChapter()
            }
        }
        .onChange(of: settingsManager.showRedLetterText) { _ in
            refreshChapterDerivedState()
        }
        .onChange(of: olService.trReady) { isReady in
            if isReady && currentTranslation == .tr {
                // Cancel any in-flight prefetch tasks so they don't block the retry
                prefetchTasks.values.forEach { $0.cancel() }
                prefetchTasks.removeAll()
                loadChapter()
            }
        }
        .onChange(of: olService.wlcReady) { isReady in
            if isReady && currentTranslation == .wlc {
                prefetchTasks.values.forEach { $0.cancel() }
                prefetchTasks.removeAll()
                loadChapter()
            }
        }
        // Sync FormattingPanel changes back to SettingsManager so they persist across restarts
        .onChange(of: readingSettings.fontSize) { newValue in
            switch newValue {
            case .tiny:       settingsManager.fontSize = .tiny
            case .extraSmall: settingsManager.fontSize = .extraSmall
            case .small:      settingsManager.fontSize = .small
            case .medium:     settingsManager.fontSize = .medium
            case .large:      settingsManager.fontSize = .large
            case .extraLarge: settingsManager.fontSize = .extraLarge
            case .huge:       settingsManager.fontSize = .huge
            case .massive:    settingsManager.fontSize = .massive
            }
        }
        .onChange(of: readingSettings.fontType) { newValue in
            switch newValue {
            case .serif: settingsManager.fontType = .serif
            case .sansSerif: settingsManager.fontType = .sansSerif
            }
        }
        .onChange(of: readingSettings.lineSpacing) { newValue in
            switch newValue {
            case .tight: settingsManager.lineSpacing = .tight
            case .normal: settingsManager.lineSpacing = .normal
            case .relaxed: settingsManager.lineSpacing = .relaxed
            case .wide: settingsManager.lineSpacing = .wide
            }
        }
        .onChange(of: readingSettings.verseByVerse) { newValue in
            settingsManager.verseFormatting = newValue ? .verseByVerse : .paragraph
        }
        .onChange(of: themeManager.currentMode) { newMode in
            settingsManager.themeMode = newMode
        }
        .onChange(of: appState.pendingBibleVerseReference) { _ in
            consumePendingBibleNavigationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save audio state when app loses focus
            if audioPlayer.isPlaying {
                audioPlayer.saveAudioStatePublic()
            }
            // Save current verse position
            readingSettings.lastVerse = firstVisibleVerseNumber
        }
    }

    // MARK: - Chapter Content View

    @ViewBuilder
    private var chapterContentView: some View {
        // Show loading spinner while the chapter is fetching OR while original-language
        // data is still being parsed in the background (WLC/TR load lazily on first use).
        let waitingForOL = (currentTranslation == .wlc && !olService.wlcReady)
                        || (currentTranslation == .tr  && !olService.trReady)
        if isLoading || waitingForOL {
            LoadingView()
        } else if let error = errorMessage {
            ErrorView(message: error) {
                loadChapter()
            }
        } else if currentTranslation == .wlc && selectedBook.testament == .new {
            // WLC (Westminster Leningrad Codex) covers only the Old Testament.
            VStack(spacing: 16) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.reforgedGold)
                Text("Old Testament Only")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("The Westminster Leningrad Codex contains the Hebrew Old Testament. Switch to an Old Testament book to read the original Hebrew.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        } else {
            ChapterHeader(
                book: selectedBook.name,
                chapter: selectedChapter,
                canonical: canonicalReference
            )
            .id(chapterTopScrollID)
            if readingSettings.verseByVerse {
                verseByVerseContent
            } else {
                paragraphContent
            }
            ESVAttribution(translation: currentTranslation)
            MarkChapterReadSection(
                book: selectedBook.name,
                chapter: selectedChapter,
                isRead: isChapterReadForStreak,
                onMarkAsRead: { markChapterAsRead() }
            )
            .id("chapter-end")
        }
    }

    @ViewBuilder
    private var verseByVerseContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(verses) { verse in
                VerseRow(
                    verse: verse,
                    highlight: readingState.getHighlight(for: verse.reference),
                    hasNote: readingState.getNote(for: verse.reference) != nil,
                    isSelected: readingState.isSelected(verse.reference),
                    settings: readingSettings,
                    verseByVerse: true,
                    translation: currentTranslation,
                    highlightedWord: highlightedWord,
                    wocSegments: wordsOfChristSegmentsByReference[verse.reference],
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            readingState.toggleSelection(verse.reference)
                        }
                    },
                    onNoteTap: {
                        readingState.selectedVerses = [verse.reference]
                        selectedVerseForAction = verse
                    },
                    onWordLongPress: { word, tappedVerse in
                        performWordLookup(word: word, verse: tappedVerse)
                    }
                )
                .id(verse.id)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: VerseMinYKey.self,
                            value: [verse.id: geo.frame(in: .named("bibleScroll")).minY]
                        )
                    }
                )
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
    }

    @ViewBuilder
    private var paragraphContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chapterSections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 0) {
                    if let heading = section.heading {
                        SectionHeadingView(heading: heading)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                    }
                    paragraphSectionBody(section: section)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        .padding(.bottom, section.heading != nil ? 8 : 0)
                }
                // Suppress the default .opacity fade-in/out that SwiftUI applies when
                // a new chapter has a different number of sections than the previous one.
                // Without this, extra headings fade in at their destination while the rest
                // of the content slides in from the side — the parent's offset animation
                // is the only movement that should apply to all content including headings.
                .transition(.identity)
            }
        }
    }

    // MARK: - Paragraph Section Body

    /// Returns the verse content for one paragraph section.
    /// Original-language translations (TR/WLC) bypass FlowLayout — which is LTR-only
    /// and crashes / mis-renders Hebrew RTL BiDi text — and use plain SwiftUI Text instead.
    @ViewBuilder
    private func paragraphSectionBody(section: VerseSection) -> some View {
        if currentTranslation.isOriginalLanguage {
            let isWLC = currentTranslation == .wlc
            VStack(alignment: isWLC ? .trailing : .leading, spacing: readingSettings.lineSpacing.spacing) {
                ForEach(section.verses) { verse in
                    OriginalLanguageVerseRow(
                        verse: verse,
                        isWLC: isWLC,
                        settings: readingSettings,
                        readingState: readingState,
                        colorScheme: colorScheme,
                        highlightedWord: highlightedWord,
                        onWordLongPress: { word, v in performWordLookup(word: word, verse: v) }
                    )
                }
            }
        } else {
            WordLongPressParagraphText(
                verses: section.verses,
                readingState: readingState,
                settings: readingSettings,
                colorScheme: colorScheme,
                highlightedWord: highlightedWord,
                wocSegmentsMap: wordsOfChristSegmentsByReference,
                onVerseTap: { verse in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        readingState.toggleSelection(verse.reference)
                    }
                },
                onWordLongPress: { word, tappedVerse in
                    performWordLookup(word: word, verse: tappedVerse)
                }
            )
        }
    }

    // MARK: - Strong's Word Lookup

    func performWordLookup(word: String, verse: ParsedVerse) {
        isLoadingWordLookup = true
        // Highlight the tapped word. For English, normalize to lowercase; for Greek/Hebrew
        // keep the original form since matching is done by exact word string.
        withAnimation(.easeInOut(duration: 0.15)) {
            highlightedWord = (verseID: verse.id,
                               word: currentTranslation.isOriginalLanguage ? word : word.lowercased())
        }

        Task {
            let result: WordLookupResult

            switch currentTranslation {
            case .tr:
                // TR (Greek NT): TRToken has the Strong's number — look it up directly
                // without going through the KJV English interlinear matching.
                let bookNum = OriginalLanguageService.bookNumber(for: selectedBook.name) ?? 0
                let tokens = OriginalLanguageService.shared.trTokens(
                    bookNumber: bookNum, chapter: selectedChapter, verse: verse.number
                )
                // Find the token whose displayed word matches (first occurrence wins)
                if let token = tokens.first(where: { $0.word == word }) {
                    result = await StrongsLexiconService.shared.lookupByStrongsNumber(
                        token.strongs,
                        tappedWord: word,
                        originalForm: token.word,
                        morphDescription: token.morphDescription,
                        verseReference: verse.reference,
                        bookName: selectedBook.name,
                        chapter: selectedChapter,
                        verseNumber: verse.number,
                        isHebrew: false
                    )
                } else {
                    // Token not found (data not yet loaded) — fall back to standard path
                    result = await StrongsLexiconService.shared.lookupWord(
                        word,
                        verseReference: verse.reference,
                        bookName: selectedBook.name,
                        chapter: selectedChapter,
                        verseNumber: verse.number,
                        isHebrew: false
                    )
                }

            case .wlc:
                // WLC (Hebrew OT): look up by stripping cantillation and matching ORIG data
                result = await StrongsLexiconService.shared.lookupWLCWord(
                    word,
                    verseReference: verse.reference,
                    bookName: selectedBook.name,
                    chapter: selectedChapter,
                    verseNumber: verse.number
                )

            default:
                // Standard English translation — use existing KJV interlinear path
                let isHebrew = selectedBook.testament == .old
                result = await StrongsLexiconService.shared.lookupWord(
                    word,
                    verseReference: verse.reference,
                    bookName: selectedBook.name,
                    chapter: selectedChapter,
                    verseNumber: verse.number,
                    isHebrew: isHebrew
                )
            }

            await MainActor.run {
                isLoadingWordLookup = false
                wordLookupResult = result
            }
        }
    }

    // MARK: - Chapter Cache Types

    private struct ChapterCacheKey: Hashable {
        let book: String
        let chapter: Int
        let translation: BibleTranslation
    }

    private struct ChapterCacheEntry {
        let verses: [ParsedVerse]
        let canonical: String
    }

    // MARK: - Chapter Transition Animation

    enum ChapterDirection {
        case forward
        case backward
    }

    func animateChapterChange(direction: ChapterDirection,
                              fromDrag: Bool = false,
                              action: @escaping () -> Void) {
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let exitOffset: CGFloat  = direction == .forward ? -screenWidth : screenWidth
        let enterOffset: CGFloat = direction == .forward ?  screenWidth : -screenWidth

        // Lock out the swipe gesture for the duration of this transition.
        isChapterTransitioning = true
        isHorizontalDrag = nil

        // Scale exit duration by the fraction of screen still left to travel.
        // For drag commits the content is already partway off screen so the exit is very short.
        let remaining = abs(exitOffset - chapterTransitionOffset)
        let ratio = min(1.0, remaining / screenWidth)
        // 0.12 s at full screen — noticeably snappier than 0.18 s and short enough that
        // the easeIn ramp-up is imperceptible.
        let exitDuration = max(0.03, 0.12 * ratio)

        // Phase 1: Exit with an aggressive accelerating curve.
        // timingCurve(0.55, 0, 1, 1) reaches ~50 % travel by the 60 % time mark, so the
        // content visibly moves from the first frame instead of easing up slowly.
        withAnimation(Animation.timingCurve(0.55, 0, 1, 1, duration: exitDuration)) {
            chapterTransitionOffset = exitOffset
        }

        // Phase 2: Trigger just before the exit visually completes (one frame early) so
        // there is no blank frame between the exit ending and the enter spring starting.
        let phase2Delay = max(0.02, exitDuration - 0.016)
        DispatchQueue.main.asyncAfter(deadline: .now() + phase2Delay) {
            self.chapterTransitionOffset = enterOffset  // no animation — instant reposition
            action()                                    // swap chapter content

            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                self.chapterTransitionOffset = 0
            }

            // Release the gesture lock after the enter animation would finish.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isChapterTransitioning = false
            }
        }
    }

    // MARK: - Section Grouping

    private struct VerseSection {
        let heading: String?
        let verses: [ParsedVerse]
    }

    private func refreshChapterDerivedState() {
        chapterSections = groupVersesBySection(verses)

        guard settingsManager.showRedLetterText else {
            wordsOfChristSegmentsByReference = [:]
            return
        }

        var segmentsByReference: [String: [WOCSegment]] = [:]
        segmentsByReference.reserveCapacity(verses.count)

        for verse in verses {
            guard let segments = WordsOfChristData.shared.segments(for: verse.reference) else { continue }
            if currentTranslation == .kjv {
                // KJV: segment text matches the WOC JSON exactly — use as-is
                segmentsByReference[verse.reference] = segments
            } else {
                // Non-KJV: WOC data uses KJV English text which would show instead of the
                // translated verse. Fall back to whole-verse red when any segment is Christ's words.
                if segments.contains(where: { $0.isRed }) {
                    segmentsByReference[verse.reference] = [WOCSegment(text: verse.text, isRed: true)]
                }
            }
        }

        wordsOfChristSegmentsByReference = segmentsByReference
    }

    private func groupVersesBySection(_ verses: [ParsedVerse]) -> [VerseSection] {
        var sections: [VerseSection] = []
        var currentHeading: String? = nil
        var currentVerses: [ParsedVerse] = []

        for verse in verses {
            if let h = verse.sectionHeading, !currentVerses.isEmpty {
                sections.append(VerseSection(heading: currentHeading, verses: currentVerses))
                currentHeading = h
                currentVerses = []
            } else if verse.sectionHeading != nil && currentVerses.isEmpty {
                currentHeading = verse.sectionHeading
            }
            currentVerses.append(verse)
        }

        if !currentVerses.isEmpty {
            sections.append(VerseSection(heading: currentHeading, verses: currentVerses))
        }

        return sections.isEmpty ? [VerseSection(heading: nil, verses: verses)] : sections
    }

    func loadChapter() {
        // Cancel any in-flight fetch so stale results never overwrite fresh ones
        loadTask?.cancel()

        readingState.clearSelection()
        hasScrolledToBottom = false
        showMarkAsReadPrompt = false
        errorMessage = nil

        // Update reading state and settings
        readingState.currentBook = selectedBook.name
        readingState.currentChapter = selectedChapter
        readingSettings.lastBook = selectedBook.name
        readingSettings.lastChapter = selectedChapter

        // Capture intent at call-site so checks inside the Task are reliable
        let translation = settingsManager.defaultTranslation
        let book        = selectedBook.name
        let chapter     = selectedChapter
        currentTranslation = translation

        // Capture restore intent: cold-start restore OR backward navigation position restore
        let coldRestore  = isRestoringPosition && readingSettings.lastVerse > 1
        let pendingVerse = pendingScrollVerse
        let explicitNavigationVerse = pendingNavigationVerse
        pendingScrollVerse = nil  // consume
        pendingNavigationVerse = nil

        let shouldScrollToSpecificVerse = coldRestore
            || ((pendingVerse ?? 0) > 1)
            || ((explicitNavigationVerse ?? 0) > 1)
        let savedVerse   = explicitNavigationVerse ?? (coldRestore ? readingSettings.lastVerse : (pendingVerse ?? 1))
        if coldRestore { isRestoringPosition = false }
        let chapterTopTargetID = chapterTopScrollID
        if !shouldScrollToSpecificVerse {
            firstVisibleVerseNumber = 1
            immediateScrollToVerseID = chapterTopTargetID
        }

        // ── Cache hit: apply instantly so the swipe animation plays with content ──
        let cacheKey = ChapterCacheKey(book: book, chapter: chapter, translation: translation)
        if let cached = chapterCache[cacheKey] {
            if shouldScrollToSpecificVerse { chapterTransitionOpacity = 0 }
            verses = cached.verses
            canonicalReference = cached.canonical
            refreshChapterDerivedState()
            isLoading = false
            if shouldScrollToSpecificVerse {
                let verseID = "\(book) \(chapter):\(savedVerse)"
                // Defer scroll assignment to the next run-loop cycle so SwiftUI
                // has finished processing the verse state update above.
                Task { @MainActor in immediateScrollToVerseID = verseID }
            } else {
                Task { @MainActor in immediateScrollToVerseID = chapterTopTargetID }
            }
            // Kick off neighbour pre-fetch so next swipe is also instant
            prefetchNeighborChapters(book: book, chapter: chapter, translation: translation)
            return
        }

        // ── Cache miss: fetch normally and store result ──
        isLoading = true

        loadTask = Task {
            do {
                let entry = try await fetchChapterEntry(book: book, chapter: chapter, translation: translation)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if shouldScrollToSpecificVerse { chapterTransitionOpacity = 0 }
                    verses = entry.verses
                    canonicalReference = entry.canonical
                    refreshChapterDerivedState()
                    isLoading = false
                    // Don't cache an empty OL result — it means the JSON wasn't ready yet.
                    // The trReady/wlcReady onChange observer will call loadChapter() again
                    // once the data is loaded, and that call needs a cache miss to re-fetch.
                    let isStaleOLResult = translation.isOriginalLanguage && entry.verses.isEmpty
                    if !isStaleOLResult {
                        chapterCache[cacheKey] = entry
                    }
                    if shouldScrollToSpecificVerse {
                        let verseID = "\(book) \(chapter):\(savedVerse)"
                        Task { @MainActor in immediateScrollToVerseID = verseID }
                    } else {
                        Task { @MainActor in immediateScrollToVerseID = chapterTopTargetID }
                    }
                }

                // Pre-fetch Strongs interlinear (English translations only)
                if !translation.isOriginalLanguage {
                    await StrongsLexiconService.shared.prefetchChapter(
                        bookName: book,
                        chapter: chapter,
                        totalVerses: entry.verses.count
                    )
                }

                // Pre-fetch neighbouring chapters in the background
                await MainActor.run {
                    prefetchNeighborChapters(book: book, chapter: chapter, translation: translation)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Chapter Cache Helpers

    /// Fetches one chapter and returns a cacheable entry. Shared by loadChapter and prefetch.
    private func fetchChapterEntry(book: String, chapter: Int, translation: BibleTranslation) async throws -> ChapterCacheEntry {
        var fetchedVerses: [ParsedVerse] = []
        var fetchedCanonical: String = ""

        switch translation {
        case .esv:
            let result = try await ESVService.shared.fetchChapterParsed(book: book, chapter: chapter)
            fetchedVerses = result.verses
            fetchedCanonical = result.canonical
        case .kjv:
            let result = try await KJVService.shared.fetchChapterParsed(book: book, chapter: chapter)
            fetchedVerses = result.verses
            fetchedCanonical = result.canonical
        case .net:
            let result = try await NETService.shared.fetchChapterParsed(book: book, chapter: chapter)
            fetchedVerses = result.verses
            fetchedCanonical = result.canonical
        case .csb, .nkjv, .nasb, .rvr1960:
            let result = try await ApiBibleService.shared.fetchChapterParsed(book: book, chapter: chapter, translation: translation)
            fetchedVerses = result.verses
            fetchedCanonical = result.canonical
        case .tr:
            let bookNum = OriginalLanguageService.bookNumber(for: book) ?? 0
            OriginalLanguageService.shared.preloadTR()
            let trVerses = OriginalLanguageService.shared.trChapter(bookNumber: bookNum, chapter: chapter)
            fetchedVerses = trVerses.map { v in
                let text = v.tokens.map { $0.word }.joined(separator: " ")
                let ref = "\(book) \(chapter):\(v.verse)"
                return ParsedVerse(id: ref, number: v.verse, text: text, reference: ref)
            }
            fetchedCanonical = "\(book) \(chapter)"
        case .wlc:
            let bookNum = OriginalLanguageService.bookNumber(for: book) ?? 0
            OriginalLanguageService.shared.preloadWLC()
            let wlcVerses = OriginalLanguageService.shared.wlcChapter(bookNumber: bookNum, chapter: chapter)
            fetchedVerses = wlcVerses.map { v in
                let text = v.words.joined(separator: " ")
                let ref = "\(book) \(chapter):\(v.verse)"
                return ParsedVerse(id: ref, number: v.verse, text: text, reference: ref)
            }
            fetchedCanonical = "\(book) \(chapter)"
        }

        return ChapterCacheEntry(verses: fetchedVerses, canonical: fetchedCanonical)
    }

    /// Silently pre-fetches 1 chapter behind and 3 chapters ahead into the
    /// in-memory cache, crossing book boundaries when needed so that swipe
    /// animations at chapter/book edges are always instant.
    private func prefetchNeighborChapters(book: String, chapter: Int, translation: BibleTranslation) {
        /// Returns the (book, chapter) that is `offset` chapters away from the
        /// current position, crossing book boundaries automatically.
        /// Returns nil when the offset goes out of Bible bounds.
        func chapterAt(offset: Int) -> (String, Int)? {
            guard let startIdx = BibleData.books.firstIndex(where: { $0.name == book }) else { return nil }
            var idx = startIdx
            var ch  = chapter + offset
            if offset > 0 {
                while ch > BibleData.books[idx].chapters {
                    ch -= BibleData.books[idx].chapters
                    idx += 1
                    guard idx < BibleData.books.count else { return nil }
                }
            } else if offset < 0 {
                while ch < 1 {
                    idx -= 1
                    guard idx >= 0 else { return nil }
                    ch += BibleData.books[idx].chapters
                }
            }
            return (BibleData.books[idx].name, ch)
        }

        // 1 chapter behind, then 3 chapters ahead (cross-book aware)
        let neighbors = [-1, 1, 2, 3].compactMap { chapterAt(offset: $0) }

        for (neighborBook, neighborChapter) in neighbors {
            let key = ChapterCacheKey(book: neighborBook, chapter: neighborChapter, translation: translation)
            guard chapterCache[key] == nil, prefetchTasks[key] == nil else { continue }

            prefetchTasks[key] = Task {
                guard let entry = try? await fetchChapterEntry(
                    book: neighborBook, chapter: neighborChapter, translation: translation
                ) else {
                    prefetchTasks[key] = nil
                    return
                }
                guard !Task.isCancelled else { return }
                // Mirror the isStaleOLResult guard from loadChapter(): never cache an empty
                // OL chapter — the JSON data may not be loaded yet, and an empty cache entry
                // causes the next navigation to show a blank chapter with no retry path.
                let isStaleOL = translation.isOriginalLanguage && entry.verses.isEmpty
                if !isStaleOL {
                    chapterCache[key] = entry
                }
                prefetchTasks[key] = nil
            }
        }
    }

    func markChapterAsRead() {
        // Record in streak manager
        streakManager.recordChapterRead(book: selectedBook.name, chapter: selectedChapter)

        // Auto-complete any reading plan day whose chapters are now all read
        ReadingPlanService.shared.notifyChapterRead(bookName: selectedBook.name, chapter: selectedChapter)

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
            if result.translation != currentTranslation {
                settingsManager.defaultTranslation = result.translation
                currentTranslation = result.translation
            }

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
                    pendingNavigationVerse = verseNum
                    loadChapter()
                } else {
                    loadChapter()
                }
                addToRecentPassages()
            }
        }
        showSearchPanel = false
    }

    func navigateToVerseReference(_ reference: String, translation: BibleTranslation? = nil) {
        // Reuse search result navigation by creating a BibleSearchResult
        let result = BibleSearchResult(reference: reference, content: "", translation: translation ?? currentTranslation)
        navigateToSearchResult(result)
    }

    private func consumePendingBibleNavigationIfNeeded() {
        guard let pending = appState.consumePendingBibleVerseNavigation() else { return }
        navigateToVerseReference(pending.reference, translation: pending.translation)
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
            // Use the first selected verse as the sheet trigger; the sheet reads
            // all selectedVerses from readingState to build the range.
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
            let selected = verses
                .filter { readingState.selectedVerses.contains($0.reference) }
                .sorted { $0.number < $1.number }

            let verseText = selected.map { $0.text }.joined(separator: " ")

            let reference: String
            if let first = selected.first, let last = selected.last {
                if first.number == last.number {
                    reference = first.reference
                } else {
                    reference = "\(selectedBook.name) \(selectedChapter):\(first.number)-\(last.number)"
                }
            } else {
                reference = "\(selectedBook.name) \(selectedChapter)"
            }

            let fullText = "\(reference)\n\(verseText)\n(\(currentTranslation.rawValue))"
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

    func addSearchToHistory(_ query: String, translation: BibleTranslation? = nil) {
        guard !query.isEmpty else { return }
        let scope: BibleSearchHistoryScope = translation == nil ? .allTextVersions : .textVersion
        appState.addBibleSearchHistoryEntry(query: query, scope: scope, translation: translation)
        loadSearchHistory()
    }

    func loadSearchHistory() {
        searchHistory = appState.loadBibleSearchHistory()
    }

    func loadRecentPassages() {
        let books = UserDefaults.standard.stringArray(forKey: "bible_recent_books") ?? []
        let chapters = UserDefaults.standard.array(forKey: "bible_recent_chapters") as? [Int] ?? []
        // Deduplicate on load in case stored data has duplicates
        var seen = Set<String>()
        recentPassages = zip(books, chapters).compactMap { book, chapter in
            let key = "\(book):\(chapter)"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return (book: book, chapter: chapter)
        }
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

private struct ScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Verse Visibility Preference Key

private struct VerseMinYKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
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
            .font(settings.fontType.font(size: settings.effectiveFontSize))
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
            let hasNote = readingState.getNote(for: verse.reference) != nil

            // Superscript verse number
            let verseNumber = Text("\(verse.number)")
                .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
                .foregroundColor(Color.reforgedGold)
                .baselineOffset(6)

            // Note indicator icon (inline, gold, template-rendered)
            let noteIcon = hasNote
                ? Text(Image("sticky-note"))
                    .foregroundColor(Color.reforgedGold)
                    .baselineOffset(4)
                + Text(" ").font(.system(size: settings.effectiveVerseNumberSize))
                : Text("")

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

            result = result + verseNumber + noteIcon + verseText
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
    var translationOrder: [BibleTranslation] = BibleTranslation.allCases.filter { !$0.isOriginalLanguage }
    var showOriginalLanguagesInSwitcher: Bool = false
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
        Color.adaptivePrimaryIcon(colorScheme)
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
            // Book + Chapter navigation button — truncates if space is tight
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
            .buttonStyle(NoBlobButtonStyle())
            .fixedSize()                          // ← never shrinks or clips

            // Translation menu — full label when space allows, compact pill otherwise
            translationMenu

            Spacer(minLength: 4)

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
            .buttonStyle(NoBlobButtonStyle())
            .layoutPriority(1)

            // Audio button
            Button(action: onAudioTap) {
                ZStack {
                    Circle()
                        .fill(!audioPlayer.currentBook.isEmpty || audioPlayer.isPlaying ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)

                    Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "headphones")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(!audioPlayer.currentBook.isEmpty || audioPlayer.isPlaying ? .white : iconColor)
                }
            }
            .buttonStyle(NoBlobButtonStyle())
            .layoutPriority(1)

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
            .buttonStyle(NoBlobButtonStyle())
            .layoutPriority(1)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme))
    }

    /// Translation menu that automatically collapses to a compact pill when space is tight.
    /// ViewThatFits tries the full label first; if it overflows it uses the short code with no chevron.
    @ViewBuilder
    private var translationMenu: some View {
        ViewThatFits(in: .horizontal) {
            // Full version: "RVR1960 ▾"
            translationMenuLabel(compact: false)
            // Compact version: "RVR" (no chevron, tighter padding)
            translationMenuLabel(compact: true)
        }
    }

    @ViewBuilder
    private func translationMenuLabel(compact: Bool) -> some View {
        Menu {
            ForEach(translationOrder) { t in
                Button {
                    onTranslationSelect(t)
                } label: {
                    HStack {
                        Text(t.rawValue)
                        if t == translation { Image(systemName: "checkmark") }
                    }
                }
            }
            if showOriginalLanguagesInSwitcher {
                Divider()
                Button {
                    onTranslationSelect(.tr)
                } label: {
                    HStack {
                        Text("TR — Greek NT")
                        if translation == .tr { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    onTranslationSelect(.wlc)
                } label: {
                    HStack {
                        Text("WLC — Hebrew OT")
                        if translation == .wlc { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            if compact {
                Text(translation.compactCode)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            } else {
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
        }
        .fixedSize()
    }
}

// MARK: - Floating Chapter Navigation (Side-positioned Circle Buttons)

struct FloatingChapterNav: View {
    let hasPrevious: Bool
    let hasNext: Bool
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
                    .foregroundStyle(hasPrevious ? .white : Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        hasPrevious
                            ? Color.reforgedNavy
                            : Color.adaptiveCardBackground(colorScheme)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(!hasPrevious)

            Spacer()

            // Next chapter button (right side)
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(hasNext ? .white : Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        hasNext
                            ? Color.reforgedNavy
                            : Color.adaptiveCardBackground(colorScheme)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(!hasNext)
        }
        .padding(.horizontal, 16)
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
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                FormattingThemeSection(themeManager: themeManager)
                FormattingFontSizeSection(settings: settings)
                FormattingFontTypeSection(settings: settings)
                FormattingLineSpacingSection(settings: settings)
                FormattingVerseLayoutSection(settings: settings)
                FormattingReadingModeSection(isOn: $settingsManager.readingMode)
                FormattingRedLetterSection(isOn: $settingsManager.showRedLetterText)
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
            .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Font Size Section

private struct FormattingFontSizeSection: View {
    @ObservedObject var settings: BibleReadingSettings
    @Environment(\.colorScheme) var colorScheme

    private let allSizes = BibleReadingSettings.FontSize.allCases

    /// Slider binding: maps Double index ↔ FontSize enum case.
    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(allSizes.firstIndex(of: settings.fontSize) ?? 3) },
            set: { newIndex in
                let clamped = max(0, min(allSizes.count - 1, Int(newIndex.rounded())))
                let newSize = allSizes[clamped]
                guard newSize != settings.fontSize else { return }
                settings.fontSize = newSize
                HapticManager.shared.lightImpact()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label row: title on left, current size name on right
            HStack {
                Text("Font Size")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text(settings.fontSize.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.reforgedGold)
                    .animation(.easeInOut(duration: 0.15), value: settings.fontSize)
            }

            // Slider row: small "A" — slider — large "A"
            HStack(spacing: 10) {
                Text("A")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Slider(
                    value: sliderBinding,
                    in: 0...Double(allSizes.count - 1),
                    step: 1
                )
                .tint(Color.reforgedGold)

                Text("A")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
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

// MARK: - Reading Mode Section

private struct FormattingReadingModeSection: View {
    @Binding var isOn: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Mode")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Screen")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Hide navigation bars. Tap or scroll to top to reveal.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .tint(Color.reforgedNavy)
        }
    }
}

// MARK: - Red Letter Section

private struct FormattingRedLetterSection: View {
    @Binding var isOn: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Red Letter")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Words of Christ")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Display the words of Jesus in red throughout the Gospels.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .tint(Color(red: 0.75, green: 0.1, blue: 0.1))
        }
    }
}

// MARK: - Section Heading View

struct SectionHeadingView: View {
    let heading: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(heading)
            .font(Font.custom("LibreBaskerville-Italic", size: 13))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.bottom, 4)
    }
}

// MARK: - Chapter Header

struct ChapterHeader: View {
    let book: String
    let chapter: Int
    let canonical: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    /// For Psalms display "Psalm N"; for all other books display "Chapter N"
    var chapterLabel: String {
        book == "Psalms" ? "Psalm \(chapter)" : "Chapter \(chapter)"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(book)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.reforgedGold)
                .textCase(.uppercase)
                .tracking(1)

            Text(chapterLabel)
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
    var translation: BibleTranslation = .esv
    var highlightedWord: (verseID: String, word: String)? = nil
    var wocSegments: [WOCSegment]? = nil
    let onTap: () -> Void
    var onNoteTap: (() -> Void)? = nil
    var onWordLongPress: ((String, ParsedVerse) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private static let wocColor = Color(red: 0.75, green: 0.1, blue: 0.1)

    /// Font to use for the verse body text. Overridden for Greek (TR) and Hebrew (WLC).
    private var verseFont: Font {
        switch translation {
        case .tr:  return Font.custom("Roboto", size: settings.effectiveFontSize * 1.1)
        case .wlc: return Font.custom("Ezra SIL", size: settings.effectiveFontSize * 1.2)
        default:   return settings.fontType.font(size: settings.effectiveFontSize)
        }
    }

    var body: some View {
        VStack(alignment: translation == .wlc ? .trailing : .leading, spacing: 0) {
            // Section heading (psalm title or ESV section heading)
            if let heading = verse.sectionHeading {
                SectionHeadingView(heading: heading)
            }

            HStack(alignment: .top, spacing: 4) {
                // Superscript verse number — leads in reading direction
                // (left for LTR, right for RTL Hebrew: HStack is flipped below)
                Text("\(verse.number)")
                    .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.reforgedGold)
                    .baselineOffset(6)
                    .padding(.leading, translation == .wlc ? 0 : 2)
                    .padding(.trailing, translation == .wlc ? 2 : 0)

                // Verse text with highlighter effect
                HStack(alignment: .top, spacing: 0) {
                    if let wordLookup = onWordLongPress {
                        if translation.isOriginalLanguage {
                            // TR (Greek) / WLC (Hebrew): per-word long-press using
                            // OriginalLanguageTappableVerseText with RTL FlowLayout for Hebrew.
                            OriginalLanguageTappableVerseText(
                                verse: verse,
                                isWLC: translation == .wlc,
                                font: verseFont,
                                lineSpacing: settings.lineSpacing.spacing * (translation == .wlc ? 1.4 : 1.0),
                                isSelected: isSelected,
                                highlightedWord: highlightedWord,
                                colorScheme: colorScheme,
                                highlight: highlight,
                                onWordLongPress: wordLookup,
                                onTap: onTap
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            // English translations: clean text with long-press word lookup.
                            WordLongPressVerseText(
                                verse: verse,
                                settings: settings,
                                highlight: highlight,
                                isSelected: isSelected,
                                highlightedWord: highlightedWord,
                                colorScheme: colorScheme,
                                wocSegments: wocSegments,
                                onWordLongPress: wordLookup
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        // No word-lookup callback — plain text fallback with bracket italics.
                        segmentedItalicizedVerseText(
                            verse.text,
                            wocSegments: wocSegments,
                            font: verseFont,
                            defaultColor: Color.adaptiveText(colorScheme),
                            wocColor: VerseRow.wocColor
                        )
                        .lineSpacing(settings.lineSpacing.spacing * (translation == .wlc ? 1.4 : 1.0))
                        .multilineTextAlignment(translation == .wlc ? .trailing : .leading)
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

                    // Note indicator — tappable icon to open the saved note
                    if hasNote {
                        Button {
                            onNoteTap?()
                        } label: {
                            Image("sticky-note")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(Color.reforgedGold)
                                .padding(4)
                                .background(Color.reforgedGold.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 6)
                    }
                }
                .padding(.vertical, verseByVerse ? 6 : 2)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: translation == .wlc ? .trailing : .leading)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.reforgedGold.opacity(0.15))
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            // Apply RTL to the entire HStack for Hebrew — this flips child order so the
            // verse number appears on the right (the "start" in RTL) and text flows left.
            .environment(\.layoutDirection, translation == .wlc ? .rightToLeft : .leftToRight)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
}

// MARK: - Bracket-Italic Text Helper

/// Parses KJV supplied-word brackets [like this] in a verse string and renders the
/// bracketed spans in italic while leaving the rest at normal weight.
/// Handles both single-word `[it]` and multi-word `[shall be]` spans correctly.
/// Returns a SwiftUI `Text` built by concatenating styled segments, so all standard
/// Text modifiers (lineSpacing, multilineTextAlignment, etc.) still apply.
private func italicizedVerseText(_ raw: String, font: Font, color: Color) -> Text {
    var result = Text("")
    var remaining = raw[...]

    while let openIdx = remaining.firstIndex(of: "[") {
        // Normal (non-italic) text before the opening bracket
        let before = remaining[remaining.startIndex..<openIdx]
        if !before.isEmpty {
            result = result + Text(before).font(font).foregroundColor(color)
        }
        // Advance past [
        remaining = remaining[remaining.index(after: openIdx)...]

        // Find the matching closing bracket
        if let closeIdx = remaining.firstIndex(of: "]") {
            let span = remaining[remaining.startIndex..<closeIdx]
            result = result + Text(span).font(font.italic()).foregroundColor(color)
            remaining = remaining[remaining.index(after: closeIdx)...]
        } else {
            // No closing bracket — render the rest as italic and stop
            result = result + Text(remaining).font(font.italic()).foregroundColor(color)
            return result
        }
    }

    // Any trailing normal text after the last bracket span
    if !remaining.isEmpty {
        result = result + Text(remaining).font(font).foregroundColor(color)
    }

    return result
}

// MARK: - Segment-Aware Italic Text Helper

/// Renders verse text with per-segment red-letter colouring.
///
/// When `wocSegments` is non-nil each segment is rendered through `italicizedVerseText`
/// with the appropriate colour (red for Christ's words, `defaultColor` otherwise).
/// When nil the whole verse is rendered in `defaultColor`.
private func segmentedItalicizedVerseText(_ raw: String,
                                          wocSegments: [WOCSegment]?,
                                          font: Font,
                                          defaultColor: Color,
                                          wocColor: Color) -> Text {
    guard let segments = wocSegments else {
        return italicizedVerseText(raw, font: font, color: defaultColor)
    }
    return segments.reduce(Text("")) { acc, seg in
        acc + italicizedVerseText(seg.text, font: font,
                                  color: seg.isRed ? wocColor : defaultColor)
    }
}

// Note: Word-level text selection uses iOS native text selection.
// Users can long-press on verse text to select specific words using the native iOS selection handles,
// then copy the selected text. The verse highlighting feature applies to the entire verse.

// MARK: - Original Language Verse Row (paragraph mode)

/// Lightweight verse row used in paragraph mode for TR (Greek) and WLC (Hebrew).
/// Uses plain SwiftUI Text to avoid FlowLayout's LTR-only rendering, which crashes
/// and mis-orders Hebrew RTL BiDi text.
private struct OriginalLanguageVerseRow: View {
    let verse: ParsedVerse
    let isWLC: Bool
    let settings: BibleReadingSettings
    @ObservedObject var readingState: BibleReadingState
    let colorScheme: ColorScheme
    var highlightedWord: (verseID: String, word: String)? = nil
    var onWordLongPress: ((String, ParsedVerse) -> Void)? = nil

    private var verseFont: Font {
        isWLC
            ? Font.custom("Ezra SIL", size: settings.effectiveFontSize * 1.2)
            : Font.custom("Roboto", size: settings.effectiveFontSize * 1.1)
    }

    var body: some View {
        let isSelected = readingState.isSelected(verse.reference)
        HStack(alignment: .top, spacing: 4) {
            // Verse number leads in reading direction.
            // With RTL environment below, this appears on the right for Hebrew.
            Text("\(verse.number)")
                .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.reforgedGold)
                .baselineOffset(6)
                .padding(.trailing, isWLC ? 2 : 0)
                .padding(.leading, isWLC ? 0 : 2)

            if let wordLookup = onWordLongPress {
                // Per-word long-press with RTL FlowLayout for Hebrew
                OriginalLanguageTappableVerseText(
                    verse: verse,
                    isWLC: isWLC,
                    font: verseFont,
                    lineSpacing: settings.lineSpacing.spacing * (isWLC ? 1.4 : 1.0),
                    isSelected: isSelected,
                    highlightedWord: highlightedWord,
                    colorScheme: colorScheme,
                    onWordLongPress: wordLookup,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            readingState.toggleSelection(verse.reference)
                        }
                    }
                )
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(verse.text)
                    .font(verseFont)
                    .foregroundStyle(
                        isSelected
                            ? (colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                            : Color.adaptiveText(colorScheme)
                    )
                    .lineSpacing(settings.lineSpacing.spacing * (isWLC ? 1.4 : 1.0))
                    .multilineTextAlignment(isWLC ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            readingState.toggleSelection(verse.reference)
                        }
                    }
            }
        }
        // RTL environment flips the HStack child order: number on right, text flows left.
        .environment(\.layoutDirection, isWLC ? .rightToLeft : .leftToRight)
        .frame(maxWidth: .infinity, alignment: isWLC ? .trailing : .leading)
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
