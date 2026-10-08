import UIKit
import SwiftUI

// MARK: - Bounded Window Reader (TextKit 2 spine)
//
// The bounded-window replacement for the LazyVStack spine, used when the TextKit reader
// feature flag is on. Instead of a 1,189-row spine of placeholders, it keeps at most five
// chapters (current ± two) assembled into a single TextKit 2 document and lets the
// `UITextView` own the scrolling. Fetch/cache reuse `ChapterScrollCoordinator`'s static
// serialized fetch and body derivations, so no chapter is represented as a view until it is
// inside the live window.

@MainActor
final class BibleReaderWindowController: ObservableObject {

    /// The assembled document for the current window; the view renders exactly this.
    @Published private(set) var document = NSAttributedString()
    /// True while the centered chapter is being (re)loaded and the document is empty.
    @Published private(set) var isLoading = true
    /// Non-nil when the centered chapter cannot be loaded (e.g. offline with un-cached content).
    @Published private(set) var loadingError: String?
    /// A request to bring a reference to the top — consumed by the view after each rebuild
    /// (direct navigation and post-reflow re-anchoring both use it).
    @Published private(set) var scrollAnchor: ScrollAnchor?

    struct ScrollAnchor: Equatable {
        let reference: String
        let id: UUID
        let animated: Bool
    }

    /// Reports the top-visible location upward (toolbar sync + debounced persistence).
    var onTopReferenceChanged: ((String?) -> Void)?

    private(set) var centerChapterID: String
    private var translation: BibleTranslation
    private var verseByVerse: Bool
    private var colorScheme: ColorScheme
    private var renderState: ScriptureRenderState = .empty

    private(set) var refs: [ChapterRef] = []
    private var loaded: [String: LoadedChapter] = [:]
    private var cache: [ChapterCacheKey: ChapterCacheEntry] = [:]
    /// Sorted (character offset, verse reference) index into `document`, for navigation.
    private(set) var verseOffsets: [(offset: Int, reference: String)] = []
    private var generation = 0
    /// True from the start of an explicit navigation (jump / translation switch / first load) until
    /// the view has landed the destination on screen. While set, top-reference reports from the
    /// text view are ignored: they describe the OLD offset (layout churn while the new window is
    /// fetched and swapped in) and would otherwise retarget the toolbar chapter, re-center the
    /// window on the old chapter, and even start a competing rebuild that cancels the navigation.
    private(set) var isSettlingNavigation = false

    init(centerChapterID: String,
         translation: BibleTranslation,
         verseByVerse: Bool,
         colorScheme: ColorScheme) {
        self.centerChapterID = centerChapterID
        self.translation = translation
        self.verseByVerse = verseByVerse
        self.colorScheme = colorScheme
    }

    // MARK: Lifecycle / navigation

    /// Reconfigures the window before `start` — used when the shared controller instance adopts
    /// the reader's real location/translation/presentation on appear.
    func reset(centerChapterID: String,
               translation: BibleTranslation,
               verseByVerse: Bool,
               colorScheme: ColorScheme) {
        self.centerChapterID = centerChapterID
        self.translation = translation
        self.verseByVerse = verseByVerse
        self.colorScheme = colorScheme
        loaded.removeAll()
    }

    /// Loads the initial window and positions on `reference` (or the chapter top).
    func start(scrollTo reference: String? = nil) async {
        isSettlingNavigation = true
        await rebuild(around: centerChapterID, scrollTo: reference, animated: false)
    }

    /// Updates the interactive overlay (selection, highlights, notes, word lookup, audio) and
    /// re-renders in place. Offsets are unchanged (style-only), so scroll position is kept.
    func updateRenderState(_ newValue: ScriptureRenderState) {
        renderState = newValue
        guard !loaded.isEmpty else { return }
        assembleDocument()
    }

    /// The parsed verse for a reference, if its chapter is in the live window (for word lookup).
    func verse(forReference reference: String) -> ParsedVerse? {
        guard let parsed = BibleData.parseReference(reference) else { return nil }
        return loaded["\(parsed.book) \(parsed.chapter)"]?.verses.first { $0.reference == reference }
    }

    /// Direct navigation: re-center the window on `chapterID` and scroll to `reference`
    /// (chapter top when nil), loading the destination window first — never traversing the
    /// intermediate chapters.
    func navigate(toChapterID chapterID: String, reference: String?) async {
        centerChapterID = chapterID
        isSettlingNavigation = true
        await rebuild(around: chapterID, scrollTo: reference ?? chapterID, animated: false)
    }

    /// Switch translation, dropping the window and reloading around the same chapter.
    func setTranslation(_ newValue: BibleTranslation, keepingTopReference reference: String?) async {
        guard newValue != translation else { return }
        translation = newValue
        loaded.removeAll()
        isSettlingNavigation = true
        await rebuild(around: centerChapterID, scrollTo: reference ?? centerChapterID, animated: false)
    }

    /// Rebuilds the document for a light/dark change. Colors don't affect layout, so the
    /// character offsets are unchanged and the view preserves scroll position on its own — no
    /// scroll anchor needed. Driven from the reader's `updateUIView` so a live system-appearance
    /// toggle (theme = system) reliably re-renders, which a SwiftUI `.onChange` did not.
    func setColorScheme(_ newValue: ColorScheme) {
        guard newValue != colorScheme else { return }
        colorScheme = newValue
        guard !loaded.isEmpty else { return }
        assembleDocument()
    }

    /// Atomic reflow: rebuild the document for new presentation (mode/theme/typography) while
    /// keeping `reference` at the top, without refetching.
    func applyPresentation(verseByVerse: Bool, colorScheme: ColorScheme, keepingTopReference reference: String?) {
        self.verseByVerse = verseByVerse
        self.colorScheme = colorScheme
        guard !loaded.isEmpty else { return }
        assembleDocument()
        if let reference { requestScroll(to: reference, animated: false) }
    }

    // MARK: Rotation (window recentering)

    /// Called by the view as the top-visible reference changes. Rotates the window when the
    /// reader reaches an edge chapter, re-anchoring the same reference so no content jumps.
    func handleTopReference(_ reference: String?) {
        guard !isSettlingNavigation else { return }
        onTopReferenceChanged?(reference)
        guard let reference, let parsed = BibleData.parseReference(reference) else { return }
        let chapterID = "\(parsed.book) \(parsed.chapter)"
        guard chapterID != centerChapterID else { return }
        centerChapterID = chapterID
        guard BibleReaderWindow.needsRecentering(id: chapterID, in: refs) else { return }
        Task { await rebuild(around: chapterID, scrollTo: reference, animated: false) }
    }

    /// Called by the view once a scroll anchor has been applied. Ends the navigation-settling
    /// window and reports the reference that was navigated to, so the toolbar reflects the
    /// destination rather than whatever stale offset the text view last saw.
    func anchorDidSettle(reference: String) {
        guard isSettlingNavigation else { return }
        isSettlingNavigation = false
        guard let top = topReference(for: reference) else { return }
        if let parsed = BibleData.parseReference(top) {
            centerChapterID = "\(parsed.book) \(parsed.chapter)"
        }
        onTopReferenceChanged?(top)
    }

    /// Normalizes an anchor (chapter id or verse reference) to the verse reference recorded in
    /// `verseOffsets` — the same shape the view's scroll reporting produces.
    private func topReference(for reference: String) -> String? {
        guard let offset = characterOffset(forReference: reference) else { return nil }
        return verseOffsets.first(where: { $0.offset == offset })?.reference
    }

    // MARK: Building

    private func rebuild(around chapterID: String, scrollTo reference: String?, animated: Bool) async {
        generation &+= 1
        let gen = generation
        let center = BibleChapterSpine.indexByID[chapterID] ?? 0
        let window = BibleReaderWindow.refs(aroundIndex: center)
        refs = window

        if loaded[chapterID] == nil { isLoading = document.length == 0 }

        // Load any missing chapters in the window (compatible ones only).
        for ref in window where loaded[ref.id] == nil {
            guard isCompatible(ref) else { continue }
            if let chapter = await load(ref) {
                guard gen == generation else { return }
                loaded[ref.id] = chapter
            }
        }
        guard gen == generation else { return }

        // Drop chapters no longer in the window to stay bounded.
        let liveIDs = Set(window.map(\.id))
        loaded = loaded.filter { liveIDs.contains($0.key) }

        assembleDocument()
        isLoading = false

        if loaded[chapterID] == nil && document.length == 0 {
            loadingError = "Unable to load \(chapterID). Please check your connection or translation download."
        } else {
            loadingError = nil
        }

        if let reference {
            requestScroll(to: reference, animated: animated)
        } else {
            isSettlingNavigation = false
        }
    }

    /// Retries loading the centered window if an error occurred.
    func retryLoading() {
        loadingError = nil
        Task { await rebuild(around: centerChapterID, scrollTo: nil, animated: false) }
    }

    private func load(_ ref: ChapterRef) async -> LoadedChapter? {
        let key = ChapterCacheKey(book: ref.book, chapter: ref.chapter, translation: translation)
        let entry: ChapterCacheEntry
        if let cached = cache[key] {
            entry = cached
        } else {
            guard let fetched = try? await ChapterScrollCoordinator.performChapterFetch(
                book: ref.book, chapter: ref.chapter, translation: translation
            ), !fetched.verses.isEmpty else { return nil }
            entry = fetched
            cache[key] = entry
        }
        guard !entry.verses.isEmpty else { return nil }
        return LoadedChapter(
            book: ref.book,
            chapter: ref.chapter,
            verses: entry.verses,
            canonical: entry.canonical,
            sections: ChapterScrollCoordinator.sections(from: entry.verses),
            woc: ChapterScrollCoordinator.wordsOfChrist(for: entry.verses, translation: translation)
        )
    }

    /// Concatenates the loaded window chapters into one attributed string and records the
    /// character offset of each verse for navigation.
    private func assembleDocument() {
        let output = NSMutableAttributedString()
        var offsets: [(offset: Int, reference: String)] = []

        for ref in refs {
            guard let chapter = loaded[ref.id] else { continue }
            let chapterStart = output.length
            let attributed = AttributedScriptureCache.shared.attributedText(
                chapter: chapter,
                settings: .shared,
                translation: translation,
                colorScheme: colorScheme,
                verseByVerse: verseByVerse,
                renderState: renderState,
                includeChapterHeader: true
            )
            output.append(attributed)

            // Record the first character offset of each verse within the whole document. The
            // chapter's FIRST verse is anchored to the very top of the chapter (its header),
            // not to verse 1's text — so the toolbar flips to the new chapter as soon as its
            // "Chapter N" header crosses the top, matching what the reader sees.
            let range = NSRange(location: 0, length: attributed.length)
            var seen = Set<String>()
            var isFirstVerseOfChapter = true
            attributed.enumerateAttribute(.scriptureVerseReference, in: range, options: []) { value, subrange, _ in
                guard let reference = value as? String, !seen.contains(reference) else { return }
                seen.insert(reference)
                let offset = isFirstVerseOfChapter ? chapterStart : (chapterStart + subrange.location)
                offsets.append((offset: offset, reference: reference))
                isFirstVerseOfChapter = false
            }
        }

        offsets.sort { $0.offset < $1.offset }
        verseOffsets = offsets
        document = output
    }

    private func isCompatible(_ ref: ChapterRef) -> Bool {
        switch translation {
        case .tr, .sblgnt: return ref.testament == .new
        case .wlc:         return ref.testament == .old
        default:           return true
        }
    }

    // MARK: Offset lookup

    /// Character offset of a verse reference (or the enclosing chapter's first verse) in the
    /// current document — used by the view to scroll precisely.
    func characterOffset(forReference reference: String) -> Int? {
        if let exact = verseOffsets.first(where: { $0.reference == reference })?.offset {
            return exact
        }
        if let parsed = BibleData.parseReference(reference) {
            let normalizedRef = "\(parsed.book) \(parsed.chapter):\(parsed.verseStart)"
            if let exact = verseOffsets.first(where: { $0.reference == normalizedRef })?.offset {
                return exact
            }
            let prefix = "\(parsed.book) \(parsed.chapter):"
            if let first = verseOffsets.first(where: { $0.reference.hasPrefix(prefix) })?.offset {
                return first
            }
        }
        if let parsed = parseChapterID(reference) {
            let prefix = "\(parsed.book) \(parsed.chapter):"
            return verseOffsets.first(where: { $0.reference.hasPrefix(prefix) })?.offset
        }
        return nil
    }

    private func requestScroll(to reference: String, animated: Bool) {
        scrollAnchor = ScrollAnchor(reference: reference, id: UUID(), animated: animated)
    }

    private func parseChapterID(_ id: String) -> (book: String, chapter: Int)? {
        guard id.contains(" "), !id.contains(":") else { return nil }
        guard let lastSpace = id.lastIndex(of: " "),
              let chapter = Int(id[id.index(after: lastSpace)...]) else { return nil }
        return (String(id[..<lastSpace]), chapter)
    }
}

// MARK: - Windowed Reader View

/// Hosts the controller's document in a scrolling TextKit 2 text view, wires interactions,
/// reports the top-visible reference, and consumes scroll-anchor requests (navigation + reflow
/// re-anchor).
struct BibleWindowedReader: UIViewRepresentable {
    @ObservedObject var controller: BibleReaderWindowController
    var onVerseTap: ((ScriptureHit) -> Void)?
    var onWordLookup: ((ScriptureHit) -> Void)?
    var onNoteTap: ((ScriptureHit) -> Void)?
    /// Tap on empty space / a heading — used to toggle the reading-mode chrome.
    var onBackgroundTap: (() -> Void)?
    /// Left-edge swipe — opens the navigation panel.
    var onEdgeSwipe: (() -> Void)?
    /// Scroll delta report: `dy` > 0 scrolling down (reading forward), < 0 scrolling up; `atTop`
    /// is true near the very top. Drives reading-mode reveal/hide.
    var onScroll: ((_ dy: CGFloat, _ atTop: Bool) -> Void)?
    /// Top inset that clears the floating toolbar (larger when the chrome is showing).
    var topInset: CGFloat = 12
    /// Bottom inset that clears the bottom bar so the last line isn't hidden under it.
    var bottomInset: CGFloat = 96
    /// Current light/dark scheme — a change here re-renders the document with the right colors.
    var colorScheme: ColorScheme = .light

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        // Container holds the scrolling text view plus a thin edge-swipe catcher that lives
        // OUTSIDE the scroll view, so the nav swipe fires without the scroll pan blocking it.
        let container = UIView()

        let textView = ScriptureTextView.makeReadOnly()
        textView.onVerseTap = onVerseTap
        textView.onWordLookup = onWordLookup
        textView.onNoteTap = onNoteTap
        textView.onBackgroundTap = onBackgroundTap
        textView.delegate = context.coordinator
        textView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textView)

        let catcher = EdgeSwipeCatcher()
        catcher.onSwipe = onEdgeSwipe
        catcher.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(catcher)   // added last → on top of the text view

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            catcher.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            catcher.topAnchor.constraint(equalTo: container.topAnchor),
            catcher.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            catcher.widthAnchor.constraint(equalToConstant: 24)
        ])

        context.coordinator.textView = textView
        context.coordinator.catcher = catcher

        textView.setReadingInsets(top: topInset,
                                  bottom: bottomInset,
                                  horizontal: context.environment.horizontalSizeClass == .regular ? 24 : 16)
        textView.setScriptureText(controller.document)
        context.coordinator.lastDocument = controller.document
        context.coordinator.lastColorScheme = colorScheme
        context.coordinator.rebuildVerseYs()
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        textView.onVerseTap = onVerseTap
        textView.onWordLookup = onWordLookup
        textView.onNoteTap = onNoteTap
        textView.onBackgroundTap = onBackgroundTap
        context.coordinator.catcher?.onSwipe = onEdgeSwipe
        context.coordinator.parent = self

        let inset: CGFloat = context.environment.horizontalSizeClass == .regular ? 24 : 16
        let widthChanged = abs(context.coordinator.lastWidth - textView.bounds.width) > 0.5
        textView.setReadingInsets(top: topInset, bottom: bottomInset, horizontal: inset)

        // Live light/dark change — rebuild the document with the right colors. Deferred so we
        // don't mutate published state during the SwiftUI update pass.
        if context.coordinator.lastColorScheme != colorScheme {
            context.coordinator.lastColorScheme = colorScheme
            let cs = colorScheme
            let controller = controller
            DispatchQueue.main.async { controller.setColorScheme(cs) }
        }

        // Re-render only when the document actually changed (rebuild/reflow/state), preserving
        // scroll position otherwise. Setting `attributedText` resets the text view to the top, so
        // for an in-place restyle (selection / highlight / word-lookup — no pending scroll anchor)
        // we capture and restore the content offset. Navigation and reflow set a scroll anchor
        // (consumed below), which repositions instead.
        if context.coordinator.lastDocument !== controller.document {
            let hadContent = (context.coordinator.lastDocument?.length ?? 0) > 0
            let savedOffset = textView.contentOffset
            let anchorPending = controller.scrollAnchor.map { $0.id != context.coordinator.lastAnchorID } ?? false

            context.coordinator.suppressReporting = true
            context.coordinator.lastDocument = controller.document
            textView.setScriptureText(controller.document)
            textView.ensureFullLayout()
            context.coordinator.rebuildVerseYs()
            if hadContent && !anchorPending {
                textView.setContentOffset(savedOffset, animated: false)
            }
            context.coordinator.suppressReporting = false
        } else if widthChanged {
            context.coordinator.rebuildVerseYs()
        }
        context.coordinator.lastWidth = textView.bounds.width

        // Consume a pending scroll anchor (navigation / reflow re-anchor). Reporting stays
        // suppressed from here until the deferred scroll has landed — otherwise a layout-driven
        // `scrollViewDidScroll` in between reports the stale pre-navigation offset.
        if let anchor = controller.scrollAnchor, anchor.id != context.coordinator.lastAnchorID {
            context.coordinator.lastAnchorID = anchor.id
            context.coordinator.anchorsInFlight += 1
            let animated = anchor.animated
            let reference = anchor.reference
            let controller = controller
            DispatchQueue.main.async {
                let coordinator = context.coordinator
                coordinator.suppressReporting = true
                // Resolve against the CURRENT document (a newer rebuild may have landed since).
                if let offset = controller.characterOffset(forReference: reference) {
                    textView.layoutIfNeeded()
                    textView.ensureFullLayout()
                    textView.scrollCharacterToTop(offset, animated: animated)
                    coordinator.rebuildVerseYs()
                    coordinator.syncLastReported()
                    // TextKit finishes sizing the document a beat later; if that moved the target,
                    // land on it again — but never once the reader has started scrolling.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak textView] in
                        guard let textView, !animated,
                              !textView.isTracking, !textView.isDragging, !textView.isDecelerating,
                              coordinator.lastAnchorID == anchor.id,
                              let current = controller.characterOffset(forReference: reference),
                              !textView.isScrolledToCharacter(current) else { return }
                        coordinator.suppressReporting = true
                        textView.scrollCharacterToTop(current, animated: false)
                        coordinator.rebuildVerseYs()
                        coordinator.syncLastReported()
                        coordinator.suppressReporting = false
                    }
                }
                coordinator.suppressReporting = false
                coordinator.anchorsInFlight -= 1
                controller.anchorDidSettle(reference: reference)
            }
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: Coordinator) {
        coordinator.textView?.delegate = nil
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BibleWindowedReader
        weak var textView: ScriptureTextView?
        weak var catcher: EdgeSwipeCatcher?
        var lastAnchorID: UUID?
        var lastDocument: NSAttributedString?
        var lastColorScheme: ColorScheme?
        var lastWidth: CGFloat = 0
        var suppressReporting = false
        /// Scroll anchors consumed but not yet applied (the scroll is deferred a runloop turn).
        var anchorsInFlight = 0
        private var lastReported: String?
        private var lastScrollY: CGFloat = 0
        /// Sorted content-space Y for the first character of each verse, for top-visible detection.
        private var verseYs: [(y: CGFloat, reference: String)] = []

        init(_ parent: BibleWindowedReader) { self.parent = parent }

        /// Recomputes the per-verse content-space Y positions from the current layout.
        func rebuildVerseYs() {
            guard let textView, textView.bounds.width > 0 else { return }
            textView.ensureFullLayout()
            let offsets = parent.controller.verseOffsets
            verseYs = offsets.compactMap { entry in
                guard let y = textView.contentY(forCharacterIndex: entry.offset) else { return nil }
                return (y, entry.reference)
            }
            .sorted { $0.y < $1.y }
        }

        /// Records the reference now at the top without reporting it, so the next user scroll
        /// only reports once the top verse actually changes from where an anchor landed.
        func syncLastReported() {
            guard let textView else { return }
            let threshold = textView.contentOffset.y + textView.textContainerInset.top + 1
            lastReported = (verseYs.last(where: { $0.y <= threshold }) ?? verseYs.first)?.reference
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !suppressReporting, anchorsInFlight == 0, let textView else { return }

            // Report scroll direction for reading-mode chrome reveal/hide.
            let offsetY = scrollView.contentOffset.y
            let dy = offsetY - lastScrollY
            lastScrollY = offsetY
            let atTop = offsetY <= textView.textContainerInset.top + 2
            if abs(dy) > 1 || atTop {
                parent.onScroll?(dy, atTop)
            }

            if verseYs.isEmpty { rebuildVerseYs() }
            let threshold = offsetY + textView.textContainerInset.top + 1
            guard let top = verseYs.last(where: { $0.y <= threshold }) ?? verseYs.first else { return }
            guard top.reference != lastReported else { return }
            lastReported = top.reference
            let controller = parent.controller
            let reference = top.reference
            Task { @MainActor in controller.handleTopReference(reference) }
        }
    }
}
