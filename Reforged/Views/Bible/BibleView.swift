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

/// A one-shot request to scroll the spine to a focused chapter. `chapterID` is the row id ("Book Chapter")
/// used for the `.scrollPosition` anchor; `target` is the actual scroll destination — a chapter-start
/// anchor id for chapter navigation, or a "Book Chapter:Verse" id for verse navigation. The UUID makes each
/// request unique so SwiftUI's `onChange` fires even for a repeat target. `alreadyLoaded` is true for a
/// re-focus whose body is already present (prev/next) — an immediate, non-animated jump with no overlay —
/// and false for a fresh load, which positions under the overlay with a corrective second pass.
private struct FocusScrollRequest: Equatable {
    let id = UUID()
    let chapterID: String
    let target: String
    let alreadyLoaded: Bool
}

/// Tools shown in the iPad/Mac study-tools rail. The first four are "action"
/// tools that reuse the reader's existing sheets/panels; `notes`, `highlights`,
/// and `info` expand an inline content panel beside the rail.
enum BibleToolPanelKind: String, Identifiable {
    case navigation, search, audio, display
    case notes, highlights, info
    case study, noteEditor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .navigation: return "Navigate"
        case .search:     return "Search"
        case .audio:      return "Audio"
        case .display:    return "Display"
        case .notes:      return "Notes"
        case .highlights: return "Highlights"
        case .info:       return "Passage Info"
        case .study:      return "Verse Study"
        case .noteEditor: return "Take Note"
        }
    }

    /// Whether this panel supports the pin toggle (the reference/results panels).
    var isPinnable: Bool {
        switch self {
        case .notes, .highlights, .info, .display: return true
        default: return false
        }
    }
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
    @State private var navRevealProgress: CGFloat = 0   // 0 = hidden, 1 = fully open
    @State private var navPanelVisible = false
    @State private var navFocusSearch = false
    // Phases of the left-edge nav-reveal drag. `deciding` = the gesture began at the edge but
    // hasn't yet proven itself primarily horizontal (the ScrollView still owns the pan);
    // `revealingNav` = it has claimed the drag, so the ScrollView is locked out for its duration
    // (see `.scrollDisabled` below). This directional lock is what stops navRevealProgress from
    // wiggling as the horizontal edge drag and the vertical scroll fight over the same touch.
    private enum EdgeDragPhase { case idle, deciding, revealingNav }
    @State private var edgeDragPhase: EdgeDragPhase = .idle
    /// True only while the edge drag is actively revealing the nav — drives `.scrollDisabled`.
    private var isRevealingNavFromEdge: Bool { edgeDragPhase == .revealingNav }
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

    // Content state — STABLE CHAPTER SPINE.
    //
    // The reader renders a fixed, whole-Bible `[ChapterRef]` spine (see ChapterScrollCoordinator). The
    // outer LazyVStack iterates that spine and its rows are NEVER inserted, removed, or re-identified
    // while scrolling. Each row owns a `ChapterRenderState`; the coordinator hydrates nearby chapter
    // bodies and dehydrates distant ones as the visible center moves. There is no shifting window.
    @StateObject private var coordinator = ChapterScrollCoordinator()

    /// The chapter we last explicitly navigated to (cold-start restore, nav panel, search, prev/next).
    /// Drives the full-screen loading/error/incompatible overlay and the post-load scroll positioning.
    @State private var focusChapterID: String?
    /// The scroll target ("Book Chapter" row id, or "Book Chapter:Verse") to jump to once the focused
    /// chapter's body finishes hydrating. Cleared after the jump fires.
    @State private var pendingScrollTarget: String?
    /// False until the focused chapter has been scrolled into position — keeps the overlay up so the
    /// reader never sees the spine momentarily resting at Genesis 1 before the jump lands.
    @State private var focusPositioned = false
    /// A unique scroll request consumed inside the ScrollViewReader. Carries the target id; the UUID makes
    /// every request distinct so `onChange` fires even when re-focusing the same chapter.
    @State private var focusScrollRequest: FocusScrollRequest?
    /// True while a programmatic prev/next scroll is animating. Suppresses the `visibleChapterID` scroll
    /// tracker so intermediate chapters passing through the viewport mid-animation can't re-drive
    /// `updateCurrentChapter`/hydration and fight the scroll — which is what made prev/next land unreliably.
    @State private var isProgrammaticScroll = false

    /// Top-most chapter id, written back by `.scrollPosition` (iOS 17+). Load-bearing: it anchors the
    /// viewport so hydration/dehydration height changes elsewhere in the spine never shift the reader.
    /// We never set it for navigation (we use `ScrollViewReader` for that) — it is write-back only.
    @State private var topChapterID: String?
    /// The most-visible chapter ("Book Chapter"), from the read-only ChapterMinYKey tracker. Drives the
    /// toolbar / prev-next bounds AND the proximity-hydration center as the reader scrolls.
    @State private var visibleChapterID: String?

    // Search state
    @State private var recentPassages: [(book: String, chapter: Int)] = []
    @State private var firstVisibleVerseNumber: Int = 1
    @State private var hasAppeared = false
    @State private var isRestoringPosition = false
    @State private var pendingNavigationVerse: Int? = nil

    // Verse interaction state
    @State private var selectedVerseForAction: ParsedVerse?
    @State private var memoryVersesSelection: MemoryVersesSelection?
    @State private var verseShareSelection: VerseShareSelection?
    @State private var selectedVerseForStudy: ParsedVerse?

    // Strong's word study state
    @State private var wordLookupResult: WordLookupResult?
    @State private var isLoadingWordLookup = false
    @State private var highlightedWord: (verseID: String, word: String)? = nil

    // iPad/Mac: Show navigation sidebar
    @State private var showNavigationSidebar = false

    // iPad/Mac: which study-tools-rail panel is expanded (nil = rail collapsed to icons)
    @State private var activeToolPanel: BibleToolPanelKind?
    /// Binding to the NavigationSplitView column visibility (iPad/Mac only; nil on
    /// iPhone). `setToolPanel` collapses this in the SAME action that opens a panel so
    /// the nav-out and panel-in land in one frame — the reader shifts over, keeps its
    /// width, and the whole-Bible spine never reflows.
    var navColumnVisibility: Binding<NavigationSplitViewVisibility>? = nil
    /// Full-screen reading: hides the entire tools sidebar (rail + any panel) so the
    /// reader takes the whole width. Persisted so the choice sticks across launches.
    @AppStorage("bible.readerFullScreen") private var readerFullScreen = false
    @State private var toolPanelTransitionID = UUID()
    /// When pinned, the panel stays put while the user works in the Bible —
    /// verse Study/Note actions fall back to sheets instead of replacing it.
    @State private var toolPanelPinned = false
    /// The verse a sidebar-hosted study / note panel is acting on.
    @State private var panelVerse: ParsedVerse?
    /// Previous verse selection, so the study panel can follow the verse the user JUST
    /// selected (selection is additive, so "first in book order" would otherwise win).
    @State private var lastStudySelection: Set<String> = []

    // Reading streak tracking
    @StateObject private var streakManager = ReadingStreakManager.shared

    // Translation compatibility alerts (TR = NT only, WLC = OT only)
    @State private var showTRTestamentAlert = false
    @State private var showWLCTestamentAlert = false
    @State private var pendingGreekRedirectTranslation: BibleTranslation?

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

    /// True when the iPad/Mac study-tools rail is active, so verse actions and
    /// Display route into the trailing sidebar instead of modal sheets.
    private var usesToolSidebar: Bool {
        isSidebarNavigation && settingsManager.showBibleToolsRail
    }

    // MARK: - Continuous-scroll helpers

    /// All verses across every loaded chapter — used by selection actions that may span chapters.
    private var allLoadedVerses: [ParsedVerse] {
        coordinator.orderedLoadedChapters.flatMap { $0.verses }
    }

    /// Stable scroll-target id for a chapter's header (present in both reading modes).
    private func headerID(_ book: String, _ chapter: Int) -> String {
        "header-\(book)-\(chapter)"
    }

    /// Parses a verse reference like "1 Corinthians 13:4" into its book / chapter / verse parts.
    private func parseReference(_ reference: String) -> (book: String, chapter: Int, verse: Int)? {
        guard let colon = reference.lastIndex(of: ":") else { return nil }
        guard let verse = Int(reference[reference.index(after: colon)...]) else { return nil }
        let beforeColon = reference[..<colon]                       // e.g. "1 Corinthians 13"
        guard let lastSpace = beforeColon.lastIndex(of: " "),
              let chapter = Int(beforeColon[beforeColon.index(after: lastSpace)...]) else { return nil }
        return (String(beforeColon[..<lastSpace]), chapter, verse)
    }

    /// Parses a LoadedChapter id ("Book Chapter") into its book / chapter parts.
    private func parseChapterID(_ id: String) -> (book: String, chapter: Int)? {
        guard let lastSpace = id.lastIndex(of: " "),
              let chapter = Int(id[id.index(after: lastSpace)...]) else { return nil }
        return (String(id[..<lastSpace]), chapter)
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

    private func openNav(focusSearch: Bool = false) {
        navFocusSearch = focusSearch
        // iPad / Mac (split-view detail): present as a native sheet rather than the
        // iPhone-only 3D edge-reveal, which assumes full-screen geometry.
        if isSidebarNavigation {
            showNavigationSidebar = true
            return
        }
        if navPanelVisible {
            // Panel already in the tree (edge-drag pre-rendered it) — animate straight to open
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                navRevealProgress = 1
            }
        } else {
            // Panel not yet rendered — insert it at 0, then animate on the next tick
            navPanelVisible = true
            navRevealProgress = 0
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.42, dampingFraction: 1.0)) {
                    self.navRevealProgress = 1
                }
            }
        }
    }

    private func closeNav() {
        if isSidebarNavigation {
            showNavigationSidebar = false
            navFocusSearch = false
            return
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 1.0)) {
            navRevealProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            navPanelVisible = false
            navFocusSearch = false
        }
    }

    /// Builds the navigation view shared by the iPhone reveal panel, the iPad/Mac
    /// sheet, and the iPad tools sidebar. `dismiss` closes whichever container hosts
    /// it (defaults to the iPhone/sheet `closeNav`; the sidebar passes its own).
    private func makeNavigationView(usesSheetPresentation: Bool,
                                    focusSearch: Bool? = nil,
                                    dismiss: (() -> Void)? = nil) -> some View {
        let close = dismiss ?? closeNav
        return UnifiedNavigationView(
            selectedBook: $selectedBook,
            selectedChapter: $selectedChapter,
            recentPassages: recentPassages,
            isPresented: .constant(true),
            onSelect: {
                loadChapter()
                addToRecentPassages()
                close()
            },
            onSelectVerse: { verseNum in
                // Route verse-level taps (search results, AI key verses, verse picker) through the SAME
                // explicit focus pipeline as chapter navigation: set the verse as the pending nav target and
                // re-run loadChapter, which makes `pendingScrollTarget` the exact verse id and lets
                // `performFocusScroll()` position it. The old `scrollToVerseID` path fought the stable
                // spine's `topChapterID` anchor and snapped the reader back to the chapter top.
                //
                // This is the SOLE handler for verse navigation — callers must NOT also invoke `onSelect()`
                // (which targets the chapter top), or its chapter-top loadChapter would race this verse one.
                // So it fully establishes the passage itself: focus + scroll target via loadChapter (which
                // sets `focusChapterID`/`pendingScrollTarget` and lets hydration complete before the scroll),
                // then records it in recents just like the chapter-top `onSelect` path does.
                close()
                pendingNavigationVerse = verseNum
                loadChapter()
                addToRecentPassages()
            },
            translation: currentTranslation,
            translationOrder: settingsManager.translationOrder,
            focusSearch: focusSearch ?? navFocusSearch,
            onDismiss: close,
            usesSheetPresentation: usesSheetPresentation
        )
    }

    private func onNavigationTap() {
        if usesToolSidebar {
            openToolPanel(.navigation)
        } else {
            openNav()
        }
    }

    private func onSearchTap() {
        if usesToolSidebar {
            openToolPanel(.search)
        } else {
            openNav(focusSearch: true)
        }
    }

    /// Single choke point for changing the active tool panel. Sets `activeToolPanel`
    /// AND collapses/restores the left nav sidebar in the SAME synchronous step, so
    /// SwiftUI lays out the reader once with both the panel inset applied and the nav
    /// gone — net-zero reading width, no intermediate squeeze, no spine reflow/jump.
    /// The nav change is instant (its own animation would gradually resize the reader).
    private func setToolPanel(_ kind: BibleToolPanelKind?) {
        let transitionID = UUID()
        toolPanelTransitionID = transitionID
        // Freeze the reader at its CURRENT width across the transition. The nav collapse
        // momentarily changes the available width, and a flexible reader would reflow the
        // whole-Bible spine and jump the scroll; pinned, it can't. The width is held
        // constant, so the panel-in / nav-out can ANIMATE smoothly and the reader just
        // glides in place. It returns to flexible afterward, so rotation still resizes it.
        // Hold the reader's measured width constant across the transition (the nav
        // collapse changes the pane, and we must not let that reflow the spine).
        suppressPaneMeasure = true
        // Snap the panel + nav in ONE animation-disabled step. Animating the nav
        // collapse re-lays-out the detail pane every frame, which the whole-Bible spine
        // can't survive (the scroll drifts a chapter). Snapping avoids that.
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            activeToolPanel = kind
            if isSidebarNavigation, let nav = navColumnVisibility {
                nav.wrappedValue = navVisibility(forToolPanel: kind)
            }
        }
        // Resume measuring once the layout has settled (so rotations resize the reader).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard toolPanelTransitionID == transitionID else { return }
            suppressPaneMeasure = false
            if let width = deferredPaneMeasureWidth {
                deferredPaneMeasureWidth = nil
                measurePane(width)
            }
        }
    }

    private func navVisibility(forToolPanel kind: BibleToolPanelKind?) -> NavigationSplitViewVisibility {
        (kind != nil && usesToolSidebar && !readerFullScreen) ? .detailOnly : .doubleColumn
    }

    /// Clears Bible-only sidebar state when the system sidebar needs to come back.
    private func resetToolPanelAndRestoreNavSidebar() {
        toolPanelTransitionID = UUID()
        suppressPaneMeasure = false
        deferredPaneMeasureWidth = nil
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            activeToolPanel = nil
            if let nav = navColumnVisibility {
                nav.wrappedValue = .doubleColumn
            }
        }
        toolPanelPinned = false
        panelVerse = nil
    }

    /// Opens a tools-sidebar panel, resetting transient state. Toggles closed if
    /// the same panel is already showing.
    private func openToolPanel(_ kind: BibleToolPanelKind) {
        if activeToolPanel == kind {
            closeToolPanel()
            return
        }
        panelVerse = nil
        toolPanelPinned = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            setToolPanel(kind)
        }
    }

    /// Starts playback of the current chapter if nothing is loaded yet.
    private func startAudioIfNeeded() {
        if !audioPlayer.isPlaying && audioPlayer.currentTime == 0 && audioPlayer.currentBook.isEmpty {
            audioPlayer.updateFromSettings()
            audioPlayer.play(book: selectedBook.name, chapter: selectedChapter, translation: currentTranslation)
            showAudioPlayer = true
        }
    }

    private func onAudioTap() {
        startAudioIfNeeded()
        // iPad/Mac with the rail: dock the player as a side panel. Otherwise the sheet.
        if usesToolSidebar {
            panelVerse = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                setToolPanel(.audio)
            }
        } else {
            showNowPlaying = true
        }
    }

    private func onFormatTap() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showFormattingPanel = true
        }
    }

    // MARK: - Nearest-verse helpers (sidebar Study / Note tools)

    /// Verses of the chapter the reader is currently focused on.
    private func currentChapterVerses() -> [ParsedVerse] {
        let prefix = "\(selectedBook.name) \(selectedChapter):"
        return allLoadedVerses.filter { $0.reference.hasPrefix(prefix) }
    }

    /// The verse nearest the top of the viewport, for auto-selecting when the user
    /// opens a verse tool without having tapped a verse first.
    private func nearestVisibleVerse() -> ParsedVerse? {
        let verses = currentChapterVerses()
        return verses.first { $0.number == firstVisibleVerseNumber } ?? verses.first
    }

    /// The first currently-selected verse, if any.
    private func firstSelectedVerse() -> ParsedVerse? {
        allLoadedVerses.first { readingState.selectedVerses.contains($0.reference) }
    }

    /// Study rail tool: shows study info for the selected verse, auto-selecting the
    /// nearest visible verse first when nothing is selected.
    private func onStudyTap() {
        if activeToolPanel == .study {
            closeToolPanel()
            return
        }
        if readingState.selectedVerses.isEmpty, let v = nearestVisibleVerse() {
            readingState.selectedVerses.insert(v.reference)
        }
        panelVerse = firstSelectedVerse() ?? nearestVisibleVerse()
        toolPanelPinned = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            setToolPanel(.study)
        }
    }

    /// Note rail tool: auto-selects the nearest visible verse (so the note tools are
    /// ready) and opens the notes panel, which also lists nearby notes.
    private func onNoteTap() {
        if activeToolPanel == .notes {
            closeToolPanel()
            return
        }
        if readingState.selectedVerses.isEmpty, let v = nearestVisibleVerse() {
            readingState.selectedVerses.insert(v.reference)
        }
        panelVerse = nil
        toolPanelPinned = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            setToolPanel(.notes)
        }
    }

    /// Opens the note editor for a specific verse reference. Works even when the
    /// verse's chapter isn't currently loaded (e.g. tapping a note from another
    /// chapter) by synthesising a minimal verse from the reference / saved note.
    private func openNoteEditor(for reference: String) {
        let verse = allLoadedVerses.first(where: { $0.reference == reference })
            ?? synthesizedVerse(for: reference)
        guard let verse else { return }
        // The editor loads by reference, so clear any lingering multi-verse
        // selection that would otherwise widen the range it edits.
        readingState.selectedVerses = [verse.reference]
        panelVerse = verse
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            setToolPanel(.noteEditor)
        }
    }

    /// Builds a minimal `ParsedVerse` from a reference (e.g. "John 3:16"), using the
    /// saved note's verse text isn't stored, so text is left blank — the editor keys
    /// off the reference and loads the existing note content itself.
    private func synthesizedVerse(for reference: String) -> ParsedVerse? {
        guard let parsed = parseReference(reference) else { return nil }
        return ParsedVerse(id: reference, number: parsed.verse, text: "", reference: reference)
    }

    private func onTranslationSelect(_ newTranslation: BibleTranslation) {
        // Greek NT texts only cover the NT — prompt before switching if user is in an OT passage.
        if (newTranslation == .tr || newTranslation == .sblgnt) && selectedBook.testament == .old {
            pendingGreekRedirectTranslation = newTranslation
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

            // Drop all cached/derived bodies so nothing stale bleeds through; the coordinator re-hydrates
            // around the focus chapter on the next loadChapter().
            coordinator.setTranslation(newTranslation)

            if let redirectBook = book {
                selectedBook = redirectBook
                selectedChapter = chapter
            }

            loadChapter()
        }
    }

    /// Book/chapter navigation button + translation switcher used in the
    /// navigation toolbar (centered on iPad, leading on Mac Catalyst).
    @ViewBuilder
    private var bibleNavigationToolbarControls: some View {
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
                    Button { onTranslationSelect(.sblgnt) } label: {
                        HStack {
                            Text("SBLGNT — Greek NT")
                            if currentTranslation == .sblgnt { Image(systemName: "checkmark") }
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

    // MARK: - Study Tools Sidebar (iPad/Mac)

    /// Panel width. Collapsed is a comfortable reading column (audio gets a touch
    /// more for the player); widened caps at half the window so the reader keeps
    /// enough room. 0 when no panel is open.
    private var toolPanelWidth: CGFloat {
        guard activeToolPanel != nil else { return 0 }
        // Uniform width so the nav-sidebar collapse (AdaptiveLayout.bibleNavSidebarWidth)
        // frees exactly this footprint on the left — the reader keeps its width.
        return AdaptiveLayout.bibleToolPanelWidth
    }

    /// The trailing study-tools region: a floating, rounded panel (when a tool is
    /// open) beside the floating icon rail. Sized by `safeAreaInset`, so the reader
    /// reflows to the space that's left.
    /// The trailing RAIL column only (icons + optional audio pill), kept a CONSTANT
    /// width — the sole thing the reader's `safeAreaInset` reserves, so opening a panel
    /// never resizes the reader (which would re-lay-out the whole-Bible spine and jump
    /// the scroll). The panel floats as `bibleToolPanelOverlay`.
    @ViewBuilder
    private var bibleToolsSidebar: some View {
        VStack(spacing: 10) {
            if !audioPlayer.currentBook.isEmpty && activeToolPanel != .audio {
                bibleAudioPill
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            bibleToolsRail
        }
        .frame(maxHeight: .infinity)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }

    /// The docked study-tools panel, floated as a trailing overlay so opening/closing it
    /// leaves the reader's frame untouched — no reflow, no scroll jump.
    @ViewBuilder
    private var bibleToolPanelOverlay: some View {
        if let panel = activeToolPanel {
            bibleToolPanel(panel)
                .frame(width: toolPanelWidth)
                .frame(maxHeight: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 20, x: -4, y: 8)
                .padding(.vertical, 12)
                .padding(.trailing, 78)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    /// Collapsed-audio control pill that sits above the rail while a chapter is
    /// loaded but the full audio panel is closed. Tapping the artwork re-expands
    /// the player; the play/pause and skip stay reachable while reading.
    private var bibleAudioPill: some View {
        VStack(spacing: 6) {
            Button {
                startAudioIfNeeded()
                panelVerse = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    setToolPanel(.audio)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.reforgedNavy)
                        .frame(width: 36, height: 36)
                    Image(systemName: "cross.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open audio player")

            Button { audioPlayer.togglePlayPause() } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

            Button { audioPlayer.skipForward(15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip forward")
        }
        .padding(.vertical, 8)
        .frame(width: 56)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.reforgedGold.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: -2, y: 5)
    }

    /// The always-visible floating column of tool icons. Compact — it hugs its
    /// icons and is centred vertically by the enclosing HStack.
    private var bibleToolsRail: some View {
        VStack(spacing: 6) {
            // Navigation tools — hosted in the sidebar on iPad.
            toolRailPanelButton(.navigation, systemImage: "text.book.closed.fill")
            toolRailPanelButton(.search, systemImage: "magnifyingglass")

            Divider().frame(width: 24).padding(.vertical, 4)

            // Study & content tools.
            if currentTranslation.supportsAudio {
                toolRailAudioButton
            }
            toolRailButton(.study, systemImage: "sparkles.rectangle.stack") { onStudyTap() }
            toolRailButton(.notes, systemImage: "note.text") { onNoteTap() }
            toolRailPanelButton(.highlights, systemImage: "highlighter")
            toolRailPanelButton(.display, systemImage: "textformat.size")
            toolRailPanelButton(.info, systemImage: "info.circle")

            // Pin / close appear for whatever panel is open; full-screen is always
            // available. Bottom of the tools bar, so every panel shares them.
            Divider().frame(width: 24).padding(.vertical, 4)
            if activeToolPanel != nil {
                toolRailPinButton
                toolRailCloseButton
            }
            toolRailFullScreenButton
        }
        .padding(.vertical, 12)
        .frame(width: 56)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 14, x: -2, y: 6)
    }

    /// Audio rail button: opens the audio player as a side panel, starting playback
    /// first if nothing is loaded.
    private var toolRailAudioButton: some View {
        let isActive = activeToolPanel == .audio
        let playing = !audioPlayer.currentBook.isEmpty || audioPlayer.isPlaying
        return Button {
            HapticManager.shared.lightImpact()
            if isActive {
                closeToolPanel()
            } else {
                startAudioIfNeeded()
                panelVerse = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    setToolPanel(.audio)
                }
            }
        } label: {
            Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "headphones")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? .white : (playing ? Color.reforgedGold : Color.adaptiveNavyText(colorScheme)))
                .frame(width: 40, height: 40)
                .background(isActive ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Audio")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    /// Bottom-of-rail pin — locks the open panel so working in the Bible (verse
    /// Study/Note) won't replace it. Applies to whichever panel is open.
    private var toolRailPinButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            toolPanelPinned.toggle()
        } label: {
            Image(systemName: toolPanelPinned ? "pin.fill" : "pin")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toolPanelPinned ? .white : Color.adaptiveNavyText(colorScheme))
                .frame(width: 40, height: 40)
                .background(toolPanelPinned ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toolPanelPinned ? "Unpin panel" : "Pin panel open")
    }

    /// Full-screen reading: hides the whole tools sidebar and collapses any open
    /// panel so the reader takes the full width. A floating tab restores it.
    private var toolRailFullScreenButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                setToolPanel(nil)
                readerFullScreen = true
            }
            toolPanelPinned = false
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                .frame(width: 40, height: 40)
                .background(Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Full-screen reading")
    }

    /// Floating tab shown while in full-screen reading, to bring the tools back.
    private var fullScreenExitTab: some View {
        Button {
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                readerFullScreen = false
            }
        } label: {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                .frame(width: 40, height: 44)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: -2, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show study tools")
    }

    /// Bottom-of-rail close for the open panel.
    private var toolRailCloseButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            closeToolPanel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                .frame(width: 40, height: 40)
                .background(Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close panel")
    }

    /// A rail button that fires a custom action. Highlights when its panel is open.
    private func toolRailButton(_ tool: BibleToolPanelKind,
                                systemImage: String,
                                tint: Color? = nil,
                                action: @escaping () -> Void) -> some View {
        let isActive = activeToolPanel == tool
        return Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? .white : (tint ?? Color.adaptiveNavyText(colorScheme)))
                .frame(width: 40, height: 40)
                .background(isActive ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    /// A rail button that toggles an inline content panel.
    private func toolRailPanelButton(_ tool: BibleToolPanelKind, systemImage: String) -> some View {
        let isActive = activeToolPanel == tool
        return Button {
            HapticManager.shared.lightImpact()
            if isActive {
                closeToolPanel()
            } else {
                panelVerse = nil
                toolPanelPinned = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    setToolPanel(tool)
                }
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? .white : Color.adaptiveNavyText(colorScheme))
                .frame(width: 40, height: 40)
                .background(isActive ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    /// Closes the tools panel and resets its transient state. `readerFullScreen`
    /// is a separate, persisted mode and is not touched here.
    private func closeToolPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            setToolPanel(nil)
        }
        toolPanelPinned = false
        panelVerse = nil
    }

    /// The content for an open panel tool. Study and note-taking host their own
    /// self-contained views (with their own navigation chrome); the rest use the
    /// shared header + scroll wrapper.
    @ViewBuilder
    private func bibleToolPanel(_ kind: BibleToolPanelKind) -> some View {
        switch kind {
        case .navigation:
            makeNavigationView(usesSheetPresentation: false, focusSearch: false,
                               dismiss: { closeToolPanel() })
        case .search:
            makeNavigationView(usesSheetPresentation: false, focusSearch: true,
                               dismiss: { closeToolPanel() })

        case .study:
            if let verse = panelVerse {
                VerseStudySheet(
                    verse: verse,
                    bookName: selectedBook.name,
                    chapter: selectedChapter,
                    translation: currentTranslation,
                    readingState: readingState,
                    onClose: { closeToolPanel() }
                )
                // Rebuild the study view when the selected verse changes so ALL of its
                // data reloads — the async word study and study questions (loaded in
                // `.task`) would otherwise stay on the previous verse while the
                // computed cross-refs/topics updated, leaving the panel inconsistent.
                .id(verse.reference)
            } else {
                toolPanelChrome(title: kind.title) {
                    toolPanelEmptyState(icon: "sparkles.rectangle.stack",
                                        message: "Select a verse, then tap Study to explore it here.")
                }
            }

        case .noteEditor:
            let selected = allLoadedVerses.filter { readingState.selectedVerses.contains($0.reference) }
            let verses = selected.isEmpty ? (panelVerse.map { [$0] } ?? []) : selected
            if !verses.isEmpty {
                TakeNoteView(
                    verses: verses,
                    readingState: readingState,
                    onDismiss: {
                        closeToolPanel()
                        withAnimation { readingState.clearSelection() }
                    }
                )
            } else {
                toolPanelChrome(title: kind.title) {
                    toolPanelEmptyState(icon: "square.and.pencil",
                                        message: "Select a verse, then tap Note to write here.")
                }
            }

        case .audio:
            BibleAudioSidebarPanel(audioPlayer: audioPlayer,
                                   onCollapse: { closeToolPanel() },
                                   onClose: { closeToolPanel() })

        case .display:
            toolPanelChrome(title: kind.title) {
                FormattingPreviewCard(settings: readingSettings)
                    .padding(.bottom, 4)
                FormattingPanelScrollContent(settings: readingSettings, themeManager: themeManager)
            }

        case .notes:
            toolPanelChrome(title: kind.title) { bibleNotesPanelContent }
        case .highlights:
            toolPanelChrome(title: kind.title) { bibleHighlightsPanelContent }
        case .info:
            toolPanelChrome(title: kind.title) { bibleInfoPanelContent }

        default:
            EmptyView()
        }
    }

    /// Shared header (title + pin + close) and scroll wrapper for the list panels.
    @ViewBuilder
    private func toolPanelChrome<Content: View>(title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()

                Button {
                    closeToolPanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(title)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(16)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Notes for the chapter in view. Leads with a "write a note" action for the
    /// selected (or nearest) verse — the note tool auto-selects one on open — then
    /// lists the notes already placed on nearby verses.
    @ViewBuilder
    private var bibleNotesPanelContent: some View {
        let targetRef = firstSelectedVerse()?.reference ?? nearestVisibleVerse()?.reference
        let chapterNotes = readingState.notes.values
            .filter { $0.book == selectedBook.name && $0.chapter == selectedChapter }
            .sorted { $0.verse < $1.verse }

        if let ref = targetRef {
            Button {
                HapticManager.shared.lightImpact()
                openNoteEditor(for: ref)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.reforgedCoral)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Write a note")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(ref)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.reforgedCoral.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        Text("Notes in \(selectedBook.name) \(selectedChapter)")
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.top, 4)

        if chapterNotes.isEmpty {
            toolPanelEmptyState(icon: "note.text",
                                message: "No notes here yet. Write one on the verse above.")
        } else {
            ForEach(chapterNotes) { note in
                Button {
                    openNoteEditor(for: note.reference)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verse \(note.verse)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                        Text(note.content)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Highlights recorded in the chapter currently in view.
    @ViewBuilder
    private var bibleHighlightsPanelContent: some View {
        let chapterHighlights = readingState.highlights.values
            .filter { $0.book == selectedBook.name && $0.chapter == selectedChapter }
            .sorted { $0.verse < $1.verse }

        if chapterHighlights.isEmpty {
            toolPanelEmptyState(icon: "highlighter",
                                message: "No highlights in \(selectedBook.name) \(selectedChapter) yet. Select a verse and choose a highlight color.")
        } else {
            ForEach(chapterHighlights) { highlight in
                HStack(spacing: 10) {
                    Circle()
                        .fill(highlight.baseColor)
                        .frame(width: 12, height: 12)
                    Text("Verse \(highlight.verse)")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    /// Passage / translation reference info.
    @ViewBuilder
    private var bibleInfoPanelContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow(label: "Passage", value: "\(selectedBook.name) \(selectedChapter)")
            infoRow(label: "Translation", value: currentTranslation.fullName)
            infoRow(label: "Testament", value: selectedBook.testament == .old ? "Old Testament" : "New Testament")
            infoRow(label: "Chapters read", value: "\(appState.user.chaptersRead.count) of 1189")

            Divider()

            Text(currentTranslation.copyright)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolPanelEmptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    /// The reader is ALWAYS given an explicit fixed width (never switched between
    /// flexible and fixed — that switch alone disturbs the whole-Bible spine and jumps
    /// the scroll). The width is measured from the actual detail pane so it's correct in
    /// Split View / Slide Over, and recomputed on rotation. It is held constant ONLY
    /// across a panel open/close (`suppressPaneMeasure`), when the nav collapse
    /// momentarily changes the pane, so the reader can't reflow during the toggle.
    @State private var readerPaneWidth: CGFloat = 0
    @State private var suppressPaneMeasure = false
    @State private var deferredPaneMeasureWidth: CGFloat?

    private var readerColumnWidth: CGFloat? {
        guard usesToolSidebar, !readerFullScreen, readerPaneWidth > 0 else { return nil }
        return readerPaneWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            // The docked panel takes the LEFT slot — the space the nav sidebar frees
            // when it collapses (setToolPanel). The reader keeps its fixed measured
            // width and screen position, so it never reflows: true side-by-side, no jump.
            bibleToolPanelLeft
            readerBody
                .frame(width: readerColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { measurePane(geo.size.width) }
                    .onChange(of: geo.size.width) { measurePane($0) }
            }
        )
    }

    /// Recompute the reader's fixed width from the CURRENT pane. With a panel open the
    /// nav is collapsed, so the pane is the full width and the reader is that minus the
    /// panel slot; with no panel the reader is the whole pane. Computing from the live
    /// pane keeps it correct across rotations and multitasking resizes — even with a
    /// panel open. Suppressed only during a panel open/close so the reader width stays
    /// constant across that transition (no reflow/jump).
    private func measurePane(_ width: CGFloat) {
        guard width > 0 else { return }
        guard !suppressPaneMeasure else {
            deferredPaneMeasureWidth = width
            return
        }
        let target = (activeToolPanel == nil)
            ? width
            : max(320, width - AdaptiveLayout.bibleNavSidebarWidth)
        if abs(target - readerPaneWidth) > 0.5 {
            readerPaneWidth = target
        }
    }

    /// The docked study-tools panel in the left slot (iPad/Mac). It fills the slot
    /// edge-to-edge — no floating-card rounding/shadow/inset — with a hairline trailing
    /// divider, so it reads as PART of the sidebar (replacing the nav) rather than a
    /// card overlaid on it. Its width equals the nav sidebar's, so opening it (with the
    /// nav collapsing) leaves the reader put.
    @ViewBuilder
    private var bibleToolPanelLeft: some View {
        if usesToolSidebar, !readerFullScreen, let panel = activeToolPanel {
            bibleToolPanel(panel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.adaptiveCardBackground(colorScheme))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.adaptiveBorder(colorScheme))
                        .frame(width: 0.5)
                        .ignoresSafeArea()
                }
                .frame(width: AdaptiveLayout.bibleNavSidebarWidth)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    private var readerBody: some View {
        ZStack {
            // Fill background so 3D rotation gaps don't show as pure black
            Color.adaptiveBackground(colorScheme).ignoresSafeArea()

            // Inner ZStack: everything that rotates during the nav reveal
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
                        LazyVStack(alignment: .leading, spacing: 0) {
                            chapterScrollContent
                        }
                        .chapterScrollTargets()
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
                        .frame(maxWidth: maxContentWidth, alignment: .leading)
                        // Leading-anchor the reading column: when a side panel docks
                        // and narrows the reader, the text shrinks from the RIGHT only —
                        // its left edge and every line's start stay put, so the column
                        // never slides sideways ("jumps") the way a centered column does.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, readingState.selectedVerses.isEmpty ? 60 : 140)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollTopPreferenceKey.self, value: geo.frame(in: .named("bibleScroll")).minY)
                            }
                        )
                    }
                    .scrollIndicators(.hidden)
                    // NOTE: we deliberately do NOT toggle `.scrollDisabled` while the edge drag is in
                    // flight. Flipping scrollDisabled mid-gesture reconfigures the ScrollView and CANCELS
                    // the live simultaneous drag — its translation resets to ~0, so `navRevealProgress`
                    // snaps back toward 0 then climbs again, producing the visible "fights back and forth"
                    // glitch on open. The reveal is only claimed once the drag is clearly horizontal
                    // (`h > v * 1.5` in the gesture below), so the vertical scroll no longer fights it and
                    // no lockout is needed.
                    .coordinateSpace(name: "bibleScroll")
                    // Opt the reader out of the sidebar's open/close animation. Without
                    // this, the panel's spring animates the reader's WIDTH over ~0.35s,
                    // so its per-word text relayout and chapter hydration run on every
                    // frame of the resize — which looked like the chapters reloading.
                    // The panel still animates; the reader just snaps to its new width
                    // and reflows once.
                    .animation(nil, value: activeToolPanel)
                    .animation(nil, value: readerFullScreen)
                    .animation(nil, value: settingsManager.showBibleToolsRail)
                    // `topChapterID` is the stable `.scrollPosition` anchor (iOS 17+). It is write-back
                    // ONLY — SwiftUI keeps it pinned to the top row, which holds the viewport steady when
                    // chapter bodies hydrate/dehydrate elsewhere in the spine. Navigation positioning uses
                    // ScrollViewReader instead; hydration is driven off `visibleChapterID` below.
                    .chapterScrollAnchor($topChapterID)
                    .onPreferenceChange(ChapterMinYKey.self) { positions in
                        // Track the most-visible chapter (top-most whose top has crossed near the viewport
                        // top). This drives BOTH the toolbar and the proximity-hydration center.
                        let sorted = positions.sorted { $0.value < $1.value }
                        guard let current = sorted.last(where: { $0.value <= 120 }) ?? sorted.first else { return }
                        visibleChapterID = current.key
                    }
                    .onChange(of: visibleChapterID) { id in
                        // Until the focused chapter is scrolled into place, the spine is still resting at
                        // its natural top (Genesis 1) — ignore scroll-tracking so it can't clobber the
                        // toolbar/reading state or hydrate the wrong region. Also ignore while a prev/next
                        // animation is in flight, so intermediate chapters can't fight the programmatic scroll.
                        guard focusPositioned, !isProgrammaticScroll, let id, let parsed = parseChapterID(id) else {
                            return
                        }
                        // Update the current chapter (toolbar / prev-next bounds) AND hydrate around the new
                        // center — load nearby chapter bodies, unload distant ones. The spine row collection
                        // is never touched, so this can never shift the viewport.
                        updateCurrentChapter(book: parsed.book, chapter: parsed.chapter)
                        coordinator.updateHydration(around: id)
                    }
                    .onPreferenceChange(ScrollTopPreferenceKey.self) { minY in
                        // Reading-mode bars: show when scrolled to top, hide when scrolled away (unless pinned).
                        guard settingsManager.readingMode && focusPositioned else { return }
                        let atTop = minY > -60
                        if atTop {
                            readingModeHideTask?.cancel()
                            readingModeHideTask = nil
                            barsPinnedByTap = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                readingModeOverride = true
                            }
                        } else if !barsPinnedByTap {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                readingModeOverride = false
                            }
                        }
                    }
                    .onPreferenceChange(VerseMinYKey.self) { positions in
                        // Topmost visible verse (verse-by-verse mode) drives the saved verse number.
                        if let top = positions.filter({ $0.value >= -20 }).min(by: { $0.value < $1.value }),
                           let parsed = parseReference(top.key) {
                            firstVisibleVerseNumber = parsed.verse
                        }
                    }
                    .simultaneousGesture(
                        // Left-edge swipe reveals the navigation panel. A small state machine
                        // (idle → deciding → revealingNav) only claims the drag when it clearly
                        // starts at the left edge AND is primarily horizontal; until then the
                        // vertical ScrollView keeps the pan. Chapter changes are handled by
                        // vertical scrolling + the floating prev/next buttons.
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                guard !isSidebarNavigation else { return }
                                let h = value.translation.width
                                let v = abs(value.translation.height)

                                switch edgeDragPhase {
                                case .idle:
                                    // Begin deciding for any rightward gesture (anywhere on screen),
                                    // as long as the panel isn't already open. The horizontal/vertical
                                    // discrimination below still hands vertical scrolls back to the
                                    // ScrollView, so reading isn't disrupted.
                                    guard !navPanelVisible else { return }
                                    edgeDragPhase = .deciding
                                    fallthrough
                                case .deciding:
                                    // Abandon the moment the gesture reveals itself as a scroll
                                    // (downward/upward movement out-pacing horizontal) — hand it
                                    // back to the ScrollView for the rest of the touch.
                                    if v > 10 && v >= h {
                                        edgeDragPhase = .idle
                                        return
                                    }
                                    // Claim the drag once it's clearly horizontal: rightward, past a
                                    // threshold, and out-pacing vertical movement by 1.5×.
                                    guard h > 12, h > v * 1.5 else { return }
                                    edgeDragPhase = .revealingNav
                                    navPanelVisible = true
                                    navRevealProgress = 0
                                    fallthrough
                                case .revealingNav:
                                    // Width tracks the finger directly, clamped to [0,1].
                                    let screenW = AppWindow.width
                                    let target = min(max(h / (screenW * 0.82), 0), 1)
                                    // A slow swipe lets the ScrollView intermittently steal the touch;
                                    // when it does, the DragGesture's translation snaps back toward 0
                                    // for a frame, which used to yank the panel left then right again
                                    // — the visible jitter. Advance immediately on forward motion, but
                                    // ignore small backward blips via a deadband, so only a deliberate
                                    // pull-back (past ~6%) actually retreats the panel.
                                    if target >= navRevealProgress || navRevealProgress - target > 0.06 {
                                        navRevealProgress = target
                                    }
                                }
                            }
                            .onEnded { value in
                                defer { edgeDragPhase = .idle }
                                guard edgeDragPhase == .revealingNav else { return }
                                // Open on a short flick: a quick rightward gesture (high predicted
                                // travel from finger velocity) OR any modest deliberate drag. No
                                // need to drag most of the way across the screen anymore.
                                let flick = value.predictedEndTranslation.width > 80
                                if flick || navRevealProgress > 0.15 {
                                    openNav()
                                } else {
                                    closeNav()
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
                    // Once the focused chapter's body finishes hydrating, request the jump to it. This is
                    // the ONLY place navigation positioning is initiated on a fresh load — verse restore
                    // never drives chapter buffering; it just rides on top of the stable spine.
                    .onChange(of: coordinator.lastHydratedID) { hydratedID in
                        guard let hydratedID, hydratedID == focusChapterID else { return }
                        requestFocusScroll(alreadyLoaded: false)   // fresh load — positioned under the overlay
                    }
                    // Consume scroll requests (fresh-load OR already-loaded re-focus) — the single place
                    // with `proxy` access. Positions the spine and re-points the `.scrollPosition` anchor.
                    .onChange(of: focusScrollRequest) { request in
                        guard let request else { return }
                        performFocusScroll(proxy, chapterID: request.chapterID, target: request.target, alreadyLoaded: request.alreadyLoaded)
                    }
                    // Full-screen state for the focused chapter (cold start / navigation / search). Covers
                    // the spine until the focus chapter is loaded AND scrolled into position, so the reader
                    // never glimpses the spine resting at its natural top (Genesis 1) before the jump lands.
                    .overlay { focusOverlay }
                }

                Spacer(minLength: 0)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())

            // Floating chapter navigation buttons.
            // Hide the mini player when the full audio panel is docked in the
            // sidebar — otherwise it duplicates the panel and overlaps the text.
            // On iPad with the rail, the collapsed-audio control pill lives in the
            // sidebar, so the bottom bar is suppressed there — except in full-screen
            // reading, where the sidebar (and its pill) is hidden. iPhone keeps it.
            let miniPlayerVisible = !audioPlayer.currentBook.isEmpty
                && activeToolPanel != .audio
                && (!usesToolSidebar || readerFullScreen)
            if barsVisible && readingState.selectedVerses.isEmpty {
                VStack {
                    Spacer()
                    FloatingChapterNav(
                        hasPrevious: selectedChapter > 1
                            || (BibleData.books.firstIndex(where: { $0.name == selectedBook.name }) ?? 0) > 0,
                        hasNext: selectedChapter < selectedBook.chapters
                            || (BibleData.books.firstIndex(where: { $0.name == selectedBook.name }) ?? BibleData.books.count - 1) < BibleData.books.count - 1,
                        onPrevious: { navigateToAdjacentChapter(offset: -1) },
                        onNext: { navigateToAdjacentChapter(offset: 1) }
                    )
                    // Match the reading column (same leading anchor) so the prev/next
                    // buttons frame the text and don't slide when a side panel opens.
                    .frame(maxWidth: maxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, miniPlayerVisible ? 80 : 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Selection action bar
            if !readingState.selectedVerses.isEmpty {
                VStack {
                    Spacer()
                    SelectionActionBar(readingState: readingState, onDismiss: {
                        withAnimation { readingState.clearSelection() }
                    }) { action in
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

            } // end inner ZStack
            // Flat drawer: the reading content stays fixed and only dims as the panel
            // slides in over it. No 3D tilt / scale / content-shift — driving several
            // transforms off the live drag progress amplified every frame of jitter on
            // a slow swipe. iPhone only — iPad/Mac use a sheet.
            .overlay(
                Color.black
                    .opacity(navRevealProgress * 0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .allowsHitTesting(!navPanelVisible)

            // Nav panel overlay — not inside the rotating ZStack.
            // Uses AppWindow.width (same as content offset on line above) to avoid
            // a GeometryReader layout-pass jitter when the panel first appears during a drag.
            if navPanelVisible {
                let panelW = AppWindow.width * 0.82
                HStack(spacing: 0) {
                    makeNavigationView(usesSheetPresentation: false)
                    .frame(width: panelW)
                    .frame(maxHeight: .infinity)
                    // Minimal: a hairline trailing edge stroke instead of a heavy drop shadow.
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.adaptiveBorder(colorScheme))
                            .frame(width: 0.5)
                            .ignoresSafeArea()
                    }
                    // Flat slide-in: a single horizontal translate tracking the drag.
                    .offset(x: -panelW + navRevealProgress * panelW)

                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { closeNav() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.identity)
            }

        }
        // iPad/Mac study-tools RAIL lives in the trailing margin, reserved (constant
        // width) by safeAreaInset. Opening a panel does not change this inset — the
        // panel floats over the reader via `.overlay` below — so the reader's frame,
        // and the whole-Bible spine's scroll position, never change.
        .safeAreaInset(edge: .trailing, spacing: 0) {
            if isSidebarNavigation && settingsManager.showBibleToolsRail && barsVisible {
                if readerFullScreen {
                    // Full-screen reading: sidebar hidden, a slim tab restores it.
                    VStack {
                        Spacer()
                        fullScreenExitTab
                        Spacer()
                    }
                    .padding(.trailing, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    bibleToolsSidebar
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        // Animate only the sidebar itself (its own withAnimation calls). The body-level
        // implicit animation is intentionally omitted so it can't animate the reader's
        // width — the reader opts out explicitly above.
        // Keep the study panel in step with the reader's selection — selecting a new
        // verse pulls up its study info without reopening the panel. Follow the verse
        // the user JUST selected (the newly-added one), since selection is additive.
        .onChange(of: readingState.selectedVerses) { newSelection in
            let added = newSelection.subtracting(lastStudySelection)
            lastStudySelection = newSelection
            guard activeToolPanel == .study else { return }
            let targetRef = added.first(where: { ref in allLoadedVerses.contains { $0.reference == ref } })
                ?? newSelection.first(where: { ref in allLoadedVerses.contains { $0.reference == ref } })
            if let ref = targetRef, let verse = allLoadedVerses.first(where: { $0.reference == ref }) {
                panelVerse = verse
            }
        }
        .sheet(isPresented: $showNavigationSidebar) {
            makeNavigationView(usesSheetPresentation: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedVerseForAction) { verse in
            let allSelected = allLoadedVerses.filter { readingState.selectedVerses.contains($0.reference) }
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
        .sheet(item: $selectedVerseForStudy, onDismiss: {
            withAnimation { readingState.clearSelection() }
        }) { verse in
            VerseStudySheet(
                verse: verse,
                bookName: selectedBook.name,
                chapter: selectedChapter,
                translation: currentTranslation,
                readingState: readingState
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
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioPlayer: audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showFormattingPanel) {
            FormattingPanelView(settings: readingSettings, isPresented: $showFormattingPanel)
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Greek NT texts — alert when user is in an OT passage
        .alert("New Testament Only", isPresented: $showTRTestamentAlert) {
            Button("Go to Matthew 1") {
                if let matthew = BibleData.books.first(where: { $0.name == "Matthew" }) {
                    applyTranslationSwitch(pendingGreekRedirectTranslation ?? .tr,
                                           redirectTo: matthew,
                                           chapter: 1)
                    pendingGreekRedirectTranslation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingGreekRedirectTranslation = nil
            }
        } message: {
            Text("Greek New Testament texts cover Matthew through Revelation. Would you like to go to Matthew 1?")
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
                // Mac Catalyst does not render `.principal` toolbar items in the
                // NSToolbar, so place the book/chapter navigation controls on the
                // leading edge there. iPad keeps the centered principal placement.
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarLeading) {
                    bibleNavigationToolbarControls
                }
                #else
                ToolbarItem(placement: .principal) {
                    bibleNavigationToolbarControls
                }
                #endif

                // Search / Audio / Display live in the trailing tools rail when it's
                // shown; only fall back to the toolbar when the rail is turned off,
                // so the two never duplicate each other.
                if !settingsManager.showBibleToolsRail {
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
        .onChange(of: settingsManager.showBibleToolsRail) { isEnabled in
            guard isSidebarNavigation, !isEnabled else { return }
            resetToolPanelAndRestoreNavSidebar()
        }
        .onChange(of: readerFullScreen) { isFullScreen in
            guard isSidebarNavigation, isFullScreen else { return }
            resetToolPanelAndRestoreNavSidebar()
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

            loadRecentPassages()
            loadChapter()
            consumePendingBibleNavigationIfNeeded()
            audioPlayer.updateFromSettings()

            // Wire up audio chapter completion callback (once)
            audioPlayer.onChapterCompleted = { [self] book, chapter in
                // All state mutations must happen on the main actor regardless of
                // which thread the audio player fires this callback on.
                Task { @MainActor in
                    // Single funnel — see AppState.markChapterRead. Safe on the
                    // re-reads that audio playback frequently produces.
                    appState.markChapterRead(book: book, chapter: chapter)
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
            resetToolPanelAndRestoreNavSidebar()
        }
        .onChange(of: settingsManager.keepScreenOn) { enabled in
            UIApplication.shared.isIdleTimerDisabled = enabled
        }
        .onChange(of: settingsManager.defaultTranslation) { newTranslation in
            // A translation change from OUTSIDE the in-reader switcher (Settings, search-result navigation,
            // etc.) lands here. Mirror `applyTranslationSwitch`: do a TRUE coordinator reset for the new
            // translation BEFORE loadChapter, so no stale hydrated body from the old translation can satisfy
            // `isLoaded(focusID)` and short-circuit the new focus cycle (the "switch doesn't load" bug). The
            // in-reader switch already reset + synced `currentTranslation`, so its re-entry here is a no-op.
            guard currentTranslation != newTranslation else { return }
            currentTranslation = newTranslation
            coordinator.setTranslation(newTranslation)   // drop stale state for the new translation
            loadChapter()                                 // re-focus the same passage; fallback guarantees the scroll
        }
        .onChange(of: settingsManager.showRedLetterText) { _ in
            // Recompute red-letter segments for every loaded chapter body in place (no refetch).
            coordinator.reapplyDerivations()
        }
        .onChange(of: olService.trReady) { isReady in
            if isReady && currentTranslation == .tr {
                // Greek JSON finished parsing — re-focus so the empty placeholder hydrates for real.
                loadChapter()
            }
        }
        .onChange(of: olService.sblReady) { isReady in
            if isReady && currentTranslation == .sblgnt {
                loadChapter()
            }
        }
        .onChange(of: olService.wlcReady) { isReady in
            if isReady && currentTranslation == .wlc {
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

    /// Top-level scroll content: the STABLE chapter spine. The LazyVStack iterates `coordinator.refs`
    /// (every chapter in the Bible, in canonical order) and these rows are NEVER inserted, removed, or
    /// re-identified. Each row renders its own state — placeholder, loading, content, or error — so the
    /// reader virtualizes the body inside a fixed row rather than mutating the row collection while
    /// scrolling. The full-screen loading/error/incompatible states for the focused chapter are handled
    /// by `focusOverlay` (layered over the whole reader), not here.
    @ViewBuilder
    private var chapterScrollContent: some View {
        ForEach(coordinator.refs) { ref in
            chapterRow(for: ref)
                .id(ref.id)   // permanent spine-row identity — stable across every hydrate/dehydrate
        }
    }

    /// Stable scroll target marking the exact top of a chapter — what prev/next navigate to. Kept separate
    /// from the row's `.id(ref.id)` (whose internal layout swaps between placeholder/loaded) so the landing
    /// point is always precisely the chapter start, independent of the row's render state.
    private func chapterAnchorID(_ book: String, _ chapter: Int) -> String { "chapter-start-\(book) \(chapter)" }

    /// One spine row. Renders content when the body is hydrated, otherwise a fixed-height placeholder
    /// (skeleton header + optional spinner) or an inline error. The row itself always exists.
    @ViewBuilder
    private func chapterRow(for ref: ChapterRef) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zero-height chapter-start anchor — the precise, content-independent target for prev/next.
            Color.clear
                .frame(height: 0)
                .id(chapterAnchorID(ref.book, ref.chapter))

            Group {
                switch coordinator.state(for: ref.id) {
                case .loaded(let chapter):
                    chapterView(for: chapter)
                case .loading:
                    chapterPlaceholder(ref, showSpinner: true)
                case .error(let message):
                    chapterRowError(ref, message: message)
                case .unloaded:
                    chapterPlaceholder(ref, showSpinner: false)
                }
            }
        }
        // Read-only visibility tracking — reported by EVERY row (loaded or not) so the most-visible
        // chapter is known even before its body hydrates. Drives the toolbar AND proximity hydration.
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ChapterMinYKey.self,
                    value: [ref.id: geo.frame(in: .named("bibleScroll")).minY]
                )
            }
        )
    }

    /// Fixed-height skeleton for an unloaded/loading spine row. Keeps the stack's height estimate stable
    /// and gives the chapter title as a scroll target before the body arrives.
    @ViewBuilder
    private func chapterPlaceholder(_ ref: ChapterRef, showSpinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ChapterHeader(book: ref.book, chapter: ref.chapter, canonical: "\(ref.book) \(ref.chapter)")
                .id(headerID(ref.book, ref.chapter))
            if showSpinner {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 480, alignment: .top)
    }

    /// Inline error for a single spine row's failed body fetch, with a retry that re-hydrates just that row.
    @ViewBuilder
    private func chapterRowError(_ ref: ChapterRef, message: String) -> some View {
        VStack(spacing: 12) {
            ChapterHeader(book: ref.book, chapter: ref.chapter, canonical: "\(ref.book) \(ref.chapter)")
                .id(headerID(ref.book, ref.chapter))
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.reforgedGold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { coordinator.retry(ref.id) }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, minHeight: 480, alignment: .top)
    }

    /// Renders one loaded chapter — header, verse content, and mark-as-read footer.
    @ViewBuilder
    private func chapterView(for chapter: LoadedChapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ChapterHeader(
                book: chapter.book,
                chapter: chapter.chapter,
                canonical: chapter.canonical
            )
            .id(headerID(chapter.book, chapter.chapter))

            if readingSettings.verseByVerse {
                verseByVerseContent(chapter)
            } else {
                paragraphContent(chapter)
            }

            MarkChapterReadSection(
                book: chapter.book,
                chapter: chapter.chapter,
                isRead: streakManager.wasChapterRead(book: chapter.book, chapter: chapter.chapter, on: Date()),
                onMarkAsRead: { markChapterAsRead(book: chapter.book, chapter: chapter.chapter) }
            )
        }
    }

    // MARK: - Focus Overlay

    /// The full-screen state for the chapter we last navigated to. While the focus chapter is loading (or
    /// its original-language data is still parsing), or hasn't been scrolled into position yet, this covers
    /// the spine. On error it offers a retry; for an incompatible translation/testament it explains. Once
    /// the focus chapter is loaded and positioned, this collapses to nothing and the spine shows through.
    @ViewBuilder
    private var focusOverlay: some View {
        let waitingForGreek = (currentTranslation == .tr && !olService.trReady)
                           || (currentTranslation == .sblgnt && !olService.sblReady)
        let waitingForOL = (currentTranslation == .wlc && !olService.wlcReady) || waitingForGreek

        if let id = focusChapterID, coordinator.isIncompatible(id) {
            incompatibleTranslationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground(colorScheme))
        } else if let id = focusChapterID, case .error(let message) = coordinator.state(for: id) {
            ErrorView(message: message) { loadChapter() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground(colorScheme))
        } else if !focusPositioned || waitingForOL {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground(colorScheme))
        }
    }

    /// Explains that the active original-language text only covers one testament (TR/SBLGNT = NT, WLC = OT).
    @ViewBuilder
    private var incompatibleTranslationView: some View {
        let isWLC = currentTranslation == .wlc
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Color.reforgedGold)
            Text(isWLC ? "Old Testament Only" : "New Testament Only")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(isWLC
                 ? "The Westminster Leningrad Codex contains the Hebrew Old Testament. Switch to an Old Testament book to read the original Hebrew."
                 : "This Greek text contains the New Testament. Switch to a New Testament book to read the original Greek.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    /// Scrolls the spine to the focused chapter (chapter top, or a restored/explicit verse), then drops the
    /// overlay. This is the sole bridge between explicit navigation and the stable spine — it positions the
    /// viewport but never touches chapter buffering, which the coordinator owns.
    ///
    /// CRITICAL: it also re-points the `.scrollPosition` anchor (`topChapterID`). That anchor is otherwise
    /// write-back only and would still hold the PREVIOUS chapter — on the next layout pass `.scrollPosition`
    /// would yank the reader straight back to it (the "prev/next jumps back" bug). For a chapter-top target
    /// we set the anchor to the target so the two agree; for a mid-chapter verse we release the anchor (nil)
    /// so it can't fight the verse scroll, and let write-back repopulate it once the reader settles.
    private func performFocusScroll(_ proxy: ScrollViewProxy, chapterID: String, target: String, alreadyLoaded: Bool) {
        pendingScrollTarget = nil
        let isVerseTarget = target.contains(":")

        // The chapter-start anchor — a zero-height target at the exact top of the chapter row. For a
        // chapter-top jump this IS `target`; for a verse jump it's the landing spot for stage 1 below.
        let chapterAnchor: String = {
            guard let p = parseChapterID(chapterID) else { return target }
            return chapterAnchorID(p.book, p.chapter)
        }()

        // STAGE 1 — reach the CHAPTER. `.scrollPosition` (`topChapterID`) is the ONLY mechanism that
        // reliably traverses a far distance across the lazy spine: it computes the offset from the spine's
        // height estimates, so it lands even on a row that has never been realized. `proxy.scrollTo` to such
        // a far, never-built row silently no-ops — which is why a cold/far VERSE restore used to park on
        // Genesis 1 with the focus chapter hydrated off-screen (the "doesn't populate" bug). So we always
        // anchor the chapter row via scrollPosition first and let it do the long haul.
        func reachChapter() {
            topChapterID = chapterID
            proxy.scrollTo(chapterAnchor, anchor: .top)
        }
        // STAGE 2 — fine-position to the verse INSIDE the now-realized chapter. Release the anchor (nil) so
        // `.scrollPosition` can't fight the mid-chapter scroll, then `proxy.scrollTo` the verse. This is now
        // a SHORT jump within content stage 1 already brought on-screen, so scrollTo resolves it precisely.
        func fineToVerse() {
            topChapterID = nil
            proxy.scrollTo(target, anchor: .top)
        }
        // Re-assert the chapter-top landing (absorbs late neighbour hydration without snapping back).
        func secondPass() { isVerseTarget ? fineToVerse() : reachChapter() }

        if alreadyLoaded {
            // prev/next: content is present, so jump INSTANTLY to the chapter-start anchor. Suppress the
            // scroll tracker across the jump so chapters passing through can't re-drive current-chapter,
            // then resume from the chapter we landed on.
            isProgrammaticScroll = true
            reachChapter()
            focusPositioned = true
            updateCurrentChapter(forChapterID: chapterID)   // sync toolbar immediately to this chapter

            // Verse-by-verse renders one row (with its own GeometryReader + word-tap FlowLayout) per verse,
            // so `.scrollPosition`'s offset estimate for a chapter that's never actually been laid out on
            // screen (only data-hydrated) is far less reliable than in paragraph mode — a single `scrollTo`
            // can silently land short of the target. `ChapterMinYKey`'s preference handler keeps updating
            // `visibleChapterID` with the TRUE on-screen chapter throughout (only its downstream side effects
            // are suppressed by `isProgrammaticScroll`), so we use it here to verify the jump actually landed
            // and re-assert it if not, instead of trusting a single blind `reachChapter()` call.
            func verifyLanded(attempt: Int) {
                let delay = readingSettings.verseByVerse ? 0.2 : 0.08
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Only act if this is still the current focus. With rapid taps, an older tap's deferred
                    // block can fire after a newer nav — without this guard it would fight the newer jump.
                    guard focusChapterID == chapterID else { return }
                    if visibleChapterID != chapterID, attempt < 4 {
                        if isVerseTarget {
                            secondPass()
                        } else {
                            // `topChapterID` already equals `chapterID` from the previous attempt, so simply
                            // re-assigning the same value is a no-op for `.scrollPosition` — SwiftUI only
                            // reacts to an actual change. Force a real nil -> chapterID transition (with a
                            // runloop hop so it isn't coalesced away) so the scroll genuinely re-triggers.
                            topChapterID = nil
                            DispatchQueue.main.async { reachChapter() }
                        }
                        verifyLanded(attempt: attempt + 1)
                        return
                    }
                    updateCurrentChapter(forChapterID: chapterID)
                    // Grace window: even once landed, verse-by-verse's per-verse rows can still be mid-layout
                    // for a beat longer, producing a LATE/stale ChapterMinYKey read for the chapter we just
                    // navigated away from — which would otherwise be treated as trusted scroll-tracking and
                    // revert selectedChapter right back. Keep suppression up a bit longer to absorb that.
                    let graceDelay = readingSettings.verseByVerse ? 0.25 : 0.05
                    DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay) {
                        guard focusChapterID == chapterID else { return }  // a newer nav owns the flag now
                        isProgrammaticScroll = false
                    }
                }
            }
            verifyLanded(attempt: 0)
        } else {
            // Fresh load (overlay covering): reach the chapter instantly, then on the second pass fine-tune
            // to the verse (or re-assert the chapter top) once layout has built the body, then reveal.
            reachChapter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                secondPass()
                withAnimation(.easeOut(duration: 0.2)) { focusPositioned = true }
            }
        }
    }

    /// Fires a fresh scroll request for the focused chapter once it is loaded — used by BOTH the
    /// fresh-load path (`onChange(lastHydratedID)`) and the already-loaded re-focus path (prev/next to a
    /// chapter still hydrated nearby), where the coordinator's `lastHydratedID` won't change.
    private func requestFocusScroll(alreadyLoaded: Bool) {
        guard let id = focusChapterID, coordinator.isLoaded(id), let target = pendingScrollTarget else { return }
        focusScrollRequest = FocusScrollRequest(chapterID: id, target: target, alreadyLoaded: alreadyLoaded)
    }

    @ViewBuilder
    private func verseByVerseContent(_ chapter: LoadedChapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(chapter.verses) { verse in
                VerseRow(
                    verse: verse,
                    highlight: readingState.getHighlight(for: verse.reference),
                    hasNote: readingState.getNote(for: verse.reference) != nil,
                    isSelected: readingState.isSelected(verse.reference),
                    settings: readingSettings,
                    verseByVerse: true,
                    translation: currentTranslation,
                    highlightedWord: highlightedWord,
                    wocSegments: chapter.woc[verse.reference],
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
    private func paragraphContent(_ chapter: LoadedChapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chapter.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 0) {
                    if let heading = section.heading {
                        SectionHeadingView(heading: heading)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                    }
                    paragraphSectionBody(section: section, woc: chapter.woc)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        .padding(.bottom, section.heading != nil ? 8 : 0)
                }
            }
        }
    }

    // MARK: - Paragraph Section Body

    /// Returns the verse content for one paragraph section.
    /// Original-language translations (TR/WLC) bypass FlowLayout — which is LTR-only
    /// and crashes / mis-renders Hebrew RTL BiDi text — and use plain SwiftUI Text instead.
    @ViewBuilder
    private func paragraphSectionBody(section: VerseSection, woc: [String: [WOCSegment]]) -> some View {
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
                wocSegmentsMap: woc,
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

    // MARK: - Chapter navigation helpers

    /// Returns the (book, chapter) that is `offset` chapters away, crossing book boundaries.
    /// Returns nil when the offset goes out of Bible bounds.
    private func adjacentChapter(book: String, chapter: Int, offset: Int) -> (book: String, chapter: Int)? {
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

    private func clampedChapter(_ chapter: Int, for book: BibleBook) -> Int {
        min(max(chapter, 1), book.chapters)
    }

    /// Navigates the floating prev/next buttons one chapter in either direction (across book boundaries)
    /// by re-focusing the spine on the target chapter. The spine itself never changes — this just moves
    /// the reading focus, and the coordinator hydrates around the new center.
    private func navigateToAdjacentChapter(offset: Int) {
        guard let adj = adjacentChapter(book: selectedBook.name, chapter: selectedChapter, offset: offset),
              let bookData = BibleData.books.first(where: { $0.name == adj.book }) else {
            return
        }
        selectedBook = bookData
        selectedChapter = adj.chapter
        loadChapter()
    }

    /// Updates the "current" chapter (toolbar title, prev/next bounds, saved position) as the
    /// user scrolls a different chapter to the top. Does not reload — content is already loaded.
    private func updateCurrentChapter(book: String, chapter: Int) {
        guard selectedBook.name != book || selectedChapter != chapter else { return }
        guard let bookData = BibleData.books.first(where: { $0.name == book }) else { return }
        readingState.clearSelection()
        selectedBook = bookData
        selectedChapter = chapter
        readingState.currentBook = book
        readingState.currentChapter = chapter
        readingSettings.lastBook = book
        readingSettings.lastChapter = chapter
    }

    /// Convenience: update the current chapter from a "Book Chapter" row id.
    private func updateCurrentChapter(forChapterID id: String) {
        guard let parsed = parseChapterID(id) else { return }
        updateCurrentChapter(book: parsed.book, chapter: parsed.chapter)
    }

    /// Establishes the reading focus on `selectedBook`/`selectedChapter` and asks the coordinator to
    /// hydrate around it. The stable spine never changes — this only moves the focus and primes the
    /// post-load scroll positioning (chapter top, or a restored/explicit verse). Called on first appear,
    /// nav-panel selection, translation change, prev/next, search, and deep-link.
    func loadChapter() {
        readingState.clearSelection()
        selectedChapter = clampedChapter(selectedChapter, for: selectedBook)

        // Update reading state and settings
        readingState.currentBook = selectedBook.name
        readingState.currentChapter = selectedChapter
        readingSettings.lastBook = selectedBook.name
        readingSettings.lastChapter = selectedChapter

        let translation = settingsManager.defaultTranslation
        currentTranslation = translation
        coordinator.adoptTranslation(translation)

        let book    = selectedBook.name
        let chapter = selectedChapter
        let focusID = "\(book) \(chapter)"

        // Capture restore intent: cold-start restore OR explicit search/deep-link navigation.
        let coldRestore = isRestoringPosition && readingSettings.lastVerse > 1
        let explicitNavigationVerse = pendingNavigationVerse
        pendingNavigationVerse = nil

        let shouldScrollToSpecificVerse = coldRestore || ((explicitNavigationVerse ?? 0) > 1)
        let savedVerse = explicitNavigationVerse ?? (coldRestore ? readingSettings.lastVerse : 1)
        if coldRestore { isRestoringPosition = false }
        firstVisibleVerseNumber = shouldScrollToSpecificVerse ? savedVerse : 1

        // The scroll target is the chapter row (chapter top) or a specific verse — verse restore rides on
        // top of the stable spine and never influences chapter buffering.
        focusChapterID = focusID
        pendingScrollTarget = shouldScrollToSpecificVerse
            ? "\(focusID):\(savedVerse)"
            : chapterAnchorID(book, chapter)

        // Hydrate around the focus immediately (both paths) so the loaded band always stays ahead of the
        // reader — this is what keeps rapid prev/next taps from outrunning the band into a loading state.
        // The instant (non-animated) jump plus the `.scrollPosition` anchor absorb any neighbour height
        // change, so hydrating now can't jolt the scroll.
        let alreadyLoaded = coordinator.isLoaded(focusID)
        focusPositioned = alreadyLoaded
        coordinator.updateHydration(around: focusID)
        if alreadyLoaded {
            // Content is here — request the instant scroll synchronously (no runloop hop) so prev/next feels
            // immediate. `lastHydratedID` won't fire for an already-loaded chapter, so this is its trigger.
            requestFocusScroll(alreadyLoaded: true)
        } else {
            // Fresh load: the primary trigger is `.onChange(of: coordinator.lastHydratedID)`. But that
            // callback can be MISSED on first open and translation switches — the observer may not be live
            // when the hydration publish lands, or a cached body can hydrate before it's observed — which
            // leaves the reader parked on an unrelated chapter until a manual scroll / Prev-Next (the bug).
            // Drive a guaranteed fallback that polls until the focus body is loaded, then issues the scroll.
            // It's idempotent with the callback: `requestFocusScroll` no-ops once `performFocusScroll` has
            // consumed `pendingScrollTarget`, so whichever path fires first wins and the other does nothing.
            scheduleFocusScrollRetry(for: focusID, attempt: 0)
        }
    }

    /// Guaranteed fresh-load focus-scroll driver. Retries `requestFocusScroll()` on short runloop delays
    /// until the focused chapter's body is loaded (then issues the scroll once and stops), or until a small
    /// attempt ceiling. This makes first-open and translation-switch always land on the saved passage
    /// without depending on the `lastHydratedID` visibility callback. It bails immediately if the focus has
    /// moved on or the chapter is already positioned, so it can never fight a newer navigation.
    private func scheduleFocusScrollRetry(for focusID: String, attempt: Int) {
        guard focusChapterID == focusID, !focusPositioned else { return }
        if coordinator.isLoaded(focusID) {
            requestFocusScroll(alreadyLoaded: false)   // body ready — position it (overlay still covering)
            return
        }
        guard attempt < 30 else { return }   // ~3s ceiling; incompatible/failed chapter — let the view surface it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            scheduleFocusScrollRetry(for: focusID, attempt: attempt + 1)
        }
    }

    func markChapterAsRead(book: String, chapter: Int) {
        // One funnel: the streak, widget, reading-plan auto-complete, XP, progress,
        // badges, and the synced streak mirror all update together inside
        // AppState.markChapterRead. The +15 XP, any badge, and any level-up celebrate
        // right here in the reader — ContentView hosts the overlay.
        appState.markChapterRead(book: book, chapter: chapter)

        HapticManager.shared.success()
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
            // Parse book/chapter/verse from each reference so highlights remain correct even
            // when the selection spans more than one loaded chapter.
            for reference in readingState.selectedVerses {
                if let parsed = parseReference(reference) {
                    readingState.highlight(
                        reference: reference,
                        book: parsed.book,
                        chapter: parsed.chapter,
                        verse: parsed.verse,
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
            // Use the first selected verse as the trigger; the editor reads all
            // selectedVerses from readingState to build the range. On iPad with the
            // tools rail, host it in the sidebar instead of a modal sheet.
            if let firstRef = readingState.selectedVerses.first,
               let verse = allLoadedVerses.first(where: { $0.reference == firstRef }) {
                // A pinned panel stays put; the editor opens as a sheet instead.
                if usesToolSidebar && !toolPanelPinned {
                    panelVerse = verse
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        setToolPanel(.noteEditor)
                    }
                } else {
                    selectedVerseForAction = verse
                }
            }

        case .addToMemory:
            let selectedVerses = allLoadedVerses.filter { readingState.selectedVerses.contains($0.reference) }
            if !selectedVerses.isEmpty {
                memoryVersesSelection = MemoryVersesSelection(
                    verses: selectedVerses,
                    book: selectedBook.name,
                    chapter: selectedChapter
                )
            }

        case .copy:
            let selected = allLoadedVerses
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
            let selected = allLoadedVerses.filter { readingState.selectedVerses.contains($0.reference) }
            if !selected.isEmpty {
                verseShareSelection = VerseShareSelection(
                    verses: selected,
                    book: selectedBook.name,
                    chapter: selectedChapter,
                    translation: currentTranslation.rawValue
                )
            }
            withAnimation { readingState.clearSelection() }

        case .verseStudy:
            if let firstRef = readingState.selectedVerses.first,
               let verse = allLoadedVerses.first(where: { $0.reference == firstRef }) {
                // A pinned panel stays put; the study opens as a sheet instead.
                if usesToolSidebar && !toolPanelPinned {
                    panelVerse = verse
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        setToolPanel(.study)
                    }
                } else {
                    selectedVerseForStudy = verse
                }
            }

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

// MARK: - Scroll position helpers (iOS 17+ keeps content stable when chapters load above)

extension View {
    /// Marks the scroll content's subviews as scroll targets (iOS 17+); no-op on iOS 16.
    @ViewBuilder
    func chapterScrollTargets() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTargetLayout()
        } else {
            self
        }
    }

    /// Anchors the top chapter id so inserting chapters above never shifts the viewport (iOS 17+);
    /// no-op on iOS 16, where `prependPreviousChapter` re-pins manually instead.
    @ViewBuilder
    func chapterScrollAnchor(_ id: Binding<String?>) -> some View {
        if #available(iOS 17.0, *) {
            self.scrollPosition(id: id, anchor: .top)
        } else {
            self
        }
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

/// Reports each loaded chapter's top position (keyed by "Book Chapter") so the reader can tell which
/// chapter is currently most visible. Read-only tracking — it never triggers window mutation.
private struct ChapterMinYKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Verse Visibility Preference Key

/// Reports each visible verse's top position (keyed by verse id "Book Chapter:Verse") so the reader
/// can tell which verse is at the top of the viewport — emitted in both paragraph and verse-by-verse
/// modes, which is what lets reading position be saved and restored.
struct VerseMinYKey: PreferenceKey {
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
        Group {
            if isRead {
                // Completed — soft filled pill, clearly "done" but quiet.
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                    Text("Read")
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(Color.reforgedCoral)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.reforgedCoral.opacity(0.12), in: Capsule())
            } else {
                // A real button, but understated — outlined pill, muted, no fill.
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSuccessAnimation = true
                    }
                    onMarkAsRead()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.footnote)
                        Text("Mark as read")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule().stroke(Color.adaptiveTextSecondary(colorScheme).opacity(0.35), lineWidth: 1)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .scaleEffect(showSuccessAnimation ? 0.95 : 1.0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 28)
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
            .accessibilityLabel("\(displayBookName) \(chapter)")
            .accessibilityHint("Choose a book and chapter")

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
            .accessibilityLabel("Search")
            .accessibilityHint("Search the Bible")

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
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause audio" : "Play audio")
            .accessibilityHint("Listen to this chapter")

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
            .accessibilityLabel("Text options")
            .accessibilityHint("Change font, size, and reading layout")
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
                    onTranslationSelect(.sblgnt)
                } label: {
                    HStack {
                        Text("SBLGNT — Greek NT")
                        if translation == .sblgnt { Image(systemName: "checkmark") }
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

// MARK: - Compact Audio Sidebar Panel (iPad tools rail)

/// A slim, sidebar-friendly audio player: album artwork, transport, an audio-version
/// switcher, plus collapse-to-pill and stop-and-close controls.
struct BibleAudioSidebarPanel: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    /// Collapses the panel to the sidebar audio pill (audio keeps playing).
    var onCollapse: (() -> Void)? = nil
    /// Dismisses the panel entirely (paired with `audioPlayer.stop()`).
    var onClose: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    /// Translations that have real audio (not TTS).
    private var audioVersions: [BibleTranslation] {
        BibleTranslation.allCases.filter { $0.supportsAudio }
    }

    private var progressFraction: CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        let t = isScrubbing ? scrubPosition : audioPlayer.currentTime
        return CGFloat(max(0, min(1, t / audioPlayer.duration)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header: collapse-to-pill + label + stop/close
            HStack(spacing: 10) {
                Button {
                    onCollapse?()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse audio player")

                Text("NOW PLAYING")
                    .font(.caption2).fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Spacer()

                // Stop playback and dismiss the player entirely.
                Button {
                    audioPlayer.stop()
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and close audio")
            }

            // Album artwork
            AudioAlbumArtwork(book: audioPlayer.currentBook,
                              chapter: audioPlayer.currentChapter,
                              translation: audioPlayer.currentTranslation)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Title + version switcher
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayer.currentBook.isEmpty
                         ? "Audio Bible"
                         : "\(audioPlayer.currentBook) \(audioPlayer.currentChapter)")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(audioSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                versionMenu
            }

            // Scrubber
            if !audioPlayer.isTTSMode {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.2)).frame(height: 4)
                            Capsule().fill(Color.reforgedCoral).frame(width: geo.size.width * progressFraction, height: 4)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    isScrubbing = true
                                    scrubPosition = Double(max(0, min(1, v.location.x / geo.size.width))) * audioPlayer.duration
                                }
                                .onEnded { v in
                                    let f = max(0, min(1, v.location.x / geo.size.width))
                                    audioPlayer.seek(to: Double(f) * audioPlayer.duration)
                                    isScrubbing = false
                                }
                        )
                    }
                    .frame(height: 16)
                    HStack {
                        Text(timeString(isScrubbing ? scrubPosition : audioPlayer.currentTime))
                        Spacer()
                        Text("-" + timeString(max(0, audioPlayer.duration - (isScrubbing ? scrubPosition : audioPlayer.currentTime))))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            // Transport controls
            HStack {
                controlButton("backward.fill", size: 18) { audioPlayer.playPreviousChapter() }
                Spacer()
                controlButton("gobackward.15", size: 20) { audioPlayer.skipBackward(15) }
                Spacer()
                Button { audioPlayer.togglePlayPause() } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(width: 56, height: 56)
                        .background(Color.adaptiveText(colorScheme))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                controlButton("goforward.15", size: 20) { audioPlayer.skipForward(15) }
                Spacer()
                controlButton("forward.fill", size: 18) { audioPlayer.playNextChapter() }
            }
            .padding(.top, 4)

            // Footer: speed + sleep
            HStack {
                speedMenu
                Spacer()
                SleepTimerButtonView(audioPlayer: audioPlayer).equatable()
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { scrubPosition = audioPlayer.currentTime }
    }

    private var audioSubtitle: String {
        audioPlayer.isTTSMode
            ? "\(audioPlayer.currentTranslation.rawValue.uppercased()) · Text-to-Speech"
            : "\(audioPlayer.currentTranslation.rawValue.uppercased()) Audio Bible"
    }

    private var versionMenu: some View {
        Menu {
            ForEach(audioVersions) { version in
                Button {
                    guard version != audioPlayer.currentTranslation else { return }
                    audioPlayer.updateFromSettings()
                    audioPlayer.play(book: audioPlayer.currentBook.isEmpty ? "John" : audioPlayer.currentBook,
                                     chapter: max(1, audioPlayer.currentChapter),
                                     translation: version)
                } label: {
                    HStack {
                        Text(version.rawValue)
                        if version == audioPlayer.currentTranslation { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(audioPlayer.currentTranslation.rawValue)
                    .font(.subheadline).fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.reforgedNavy)
            .clipShape(Capsule())
        }
    }

    private func controlButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private var speedMenu: some View {
        Menu {
            ForEach([0.75, 1.0, 1.25, 1.5, 2.0] as [Float], id: \.self) { rate in
                Button {
                    audioPlayer.setPlaybackRate(rate)
                } label: {
                    HStack {
                        Text(rate == 1.0 ? "1×" : "\(String(format: "%g", rate))×")
                        if audioPlayer.playbackRate == rate { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 13))
                Text(audioPlayer.playbackRate == 1.0 ? "1×" : "\(String(format: "%g", audioPlayer.playbackRate))×")
                    .font(.caption).fontWeight(.semibold).monospacedDigit()
            }
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Color.adaptiveChipBackground(colorScheme))
            .clipShape(Capsule())
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasPrevious ? .white : Color.gray.opacity(0.4))
                    .frame(width: 40, height: 40)
                    .background(
                        hasPrevious
                            ? Color.reforgedNavy.opacity(0.85)
                            : Color.adaptiveCardBackground(colorScheme).opacity(0.7)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            }
            .disabled(!hasPrevious)
            .accessibilityLabel("Previous chapter")

            Spacer()

            // Next chapter button (right side)
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasNext ? .white : Color.gray.opacity(0.4))
                    .frame(width: 40, height: 40)
                    .background(
                        hasNext
                            ? Color.reforgedNavy.opacity(0.85)
                            : Color.adaptiveCardBackground(colorScheme).opacity(0.7)
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            }
            .disabled(!hasNext)
            .accessibilityLabel("Next chapter")
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
        FormattingPanelScrollContent(settings: settings, themeManager: themeManager)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    FormattingPanelHeader(isPresented: $isPresented)
                    FormattingPreviewCard(settings: settings)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                .background(Color.adaptiveCardBackground(colorScheme))
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Live Preview

/// Pinned sample passage that re-renders as the reader settings change, so the
/// effect of every control is visible without dismissing the panel.
/// John 3:16–17 is used because it is words of Christ — it doubles as the
/// red-letter preview.
private struct FormattingPreviewCard: View {
    @ObservedObject var settings: BibleReadingSettings
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    private static let wocColor = Color(red: 0.75, green: 0.1, blue: 0.1)

    private static let samples: [(number: Int, text: String)] = [
        (16, "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."),
        (17, "For God did not send his Son into the world to condemn the world, but in order that the world might be saved through him.")
    ]

    private var textColor: Color {
        settingsManager.showRedLetterText ? Self.wocColor : Color.adaptiveText(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if settings.verseByVerse {
                    VStack(alignment: .leading, spacing: settings.lineSpacing.spacing + 6) {
                        ForEach(Self.samples, id: \.number) { sample in
                            HStack(alignment: .top, spacing: 4) {
                                verseNumber(sample.number)
                                verseText(sample.text)
                            }
                        }
                    }
                } else {
                    Self.samples.reduce(Text("")) { partial, sample in
                        partial + inlineVerseNumber(sample.number) + inlineVerseText(sample.text) + Text(" ")
                    }
                    .lineSpacing(settings.lineSpacing.spacing)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: settings.verseByVerse)

            Text("John 3:16–17")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.reforgedGold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.adaptiveBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of John 3 verses 16 to 17 in the current display settings")
    }

    private func verseNumber(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
            .foregroundStyle(Color.reforgedGold)
            .baselineOffset(6)
    }

    private func verseText(_ text: String) -> some View {
        Text(text)
            .font(settings.fontType.font(size: settings.effectiveFontSize))
            .foregroundStyle(textColor)
            .lineSpacing(settings.lineSpacing.spacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func inlineVerseNumber(_ number: Int) -> Text {
        Text("\(number) ")
            .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
            .foregroundColor(Color.reforgedGold)
            .baselineOffset(6)
    }

    private func inlineVerseText(_ text: String) -> Text {
        Text(text)
            .font(settings.fontType.font(size: settings.effectiveFontSize))
            .foregroundColor(textColor)
    }
}

// MARK: - Formatting Panel Scroll Content

private struct FormattingPanelScrollContent: View {
    @ObservedObject var settings: BibleReadingSettings
    @ObservedObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Text: the controls the preview above responds to most directly
                FormattingCard {
                    FormattingFontSizeSection(settings: settings)
                    Divider()
                    FormattingFontTypeSection(settings: settings)
                    Divider()
                    FormattingLineSpacingSection(settings: settings)
                }

                // Layout + red letter — also reflected in the preview
                FormattingCard {
                    FormattingVerseLayoutSection(settings: settings)
                    Divider()
                    FormattingRedLetterSection(isOn: $settingsManager.showRedLetterText)
                }

                // Theme
                FormattingCard {
                    FormattingThemeSection(themeManager: themeManager)
                }

                // Reading mode — affects the reader chrome, not the text
                FormattingCard {
                    FormattingReadingModeSection(isOn: $settingsManager.readingMode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
}

private struct FormattingCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .background(Color.adaptiveBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        HapticManager.shared.lightImpact()
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
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected
                ? (colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.adaptiveTextSecondary(colorScheme).opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel("\(mode.rawValue) theme")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
                .accessibilityLabel("Font size")
                .accessibilityValue(settings.fontSize.displayName)

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

            HStack(spacing: 10) {
                ForEach(BibleReadingSettings.FontType.allCases, id: \.self) { fontType in
                    Button {
                        settings.fontType = fontType
                        HapticManager.shared.lightImpact()
                    } label: {
                        Text(fontType.displayName)
                            .font(.system(size: 15, design: fontType.design))
                            .fontWeight(.medium)
                            .foregroundStyle(settings.fontType == fontType ? .white : Color.adaptiveText(colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(settings.fontType == fontType
                                ? (colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                                : Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(settings.fontType == fontType ? Color.clear : Color.adaptiveTextSecondary(colorScheme).opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
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

            HStack(spacing: 6) {
                ForEach(BibleReadingSettings.LineSpacingOption.allCases, id: \.self) { spacing in
                    FormattingLineSpacingButton(spacing: spacing, isSelected: settings.lineSpacing == spacing) {
                        settings.lineSpacing = spacing
                        HapticManager.shared.lightImpact()
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

    /// Gap between the glyph's lines — a scaled-down stand-in for the real spacing.
    private var glyphGap: CGFloat {
        switch spacing {
        case .tight:   return 2
        case .normal:  return 4
        case .relaxed: return 6
        case .wide:    return 8
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                VStack(spacing: glyphGap) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(foreground)
                            .frame(height: 2)
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 6)

                Text(spacing.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected
                ? (colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy)
                : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.adaptiveTextSecondary(colorScheme).opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel(spacing.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var foreground: Color {
        isSelected ? .white : Color.adaptiveText(colorScheme)
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
            .onChange(of: settings.verseByVerse) { _ in HapticManager.shared.lightImpact() }
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
            .tint(Color.reforgedGold)
            .onChange(of: isOn) { _ in HapticManager.shared.lightImpact() }
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
            .onChange(of: isOn) { _ in HapticManager.shared.lightImpact() }
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

    /// Font to use for the verse body text. Overridden for Greek NT texts and Hebrew (WLC).
    private var verseFont: Font {
        switch translation {
        case .tr, .sblgnt:
            return Font.custom("Roboto", size: settings.effectiveFontSize * 1.1)
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
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
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
