import UIKit
import SwiftUI

// MARK: - Scripture Text View (TextKit 2)
//
// A read-only `UITextView` backed by TextKit 2 (`NSTextLayoutManager` / `NSTextContentStorage`,
// via `UITextView(usingTextLayoutManager: true)`). It renders one flat attributed string
// produced by `BibleAttributedTextBuilder` and maps taps back to the domain via the metadata
// attributes carried on each run — so verse selection, word lookup, and note taps return the
// same objects the old per-word `FlowLayout` views did.
//
// iOS TextKit 2 discipline: accessing `UITextView.textStorage` or `.layoutManager` silently
// drops the view back to TextKit 1. This view never touches either — it keeps its own copy of
// the attributed string (`scriptureString`) for attribute lookup and uses `textLayoutManager`
// for all geometry. Interaction is driven by gesture recognizers (tap = verse/note, long-press
// = word lookup) rather than native text selection, matching the FlowLayout reader.
// MARK: - Edge Swipe Catcher
//
// A thin transparent view pinned over the left reading margin, OUTSIDE the text view's scroll
// view, so its pan recognizer fires cleanly (a pan added to the UITextView is swallowed by the
// scroll view's own pan). A rightward drag beginning here opens the navigation panel.
final class EdgeSwipeCatcher: UIView {
    var onSwipe: (() -> Void)?
    private var fired = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            fired = false
        case .changed:
            guard !fired else { return }
            let t = gesture.translation(in: self)
            if t.x > 40, t.x > abs(t.y) * 1.2 {
                fired = true
                onSwipe?()
            }
        default:
            break
        }
    }
}

final class ScriptureTextView: UITextView {

    /// Quick tap on verse text or a verse number.
    var onVerseTap: ((ScriptureHit) -> Void)?
    /// Long-press on a word.
    var onWordLookup: ((ScriptureHit) -> Void)?
    /// Tap on a verse's note indicator.
    var onNoteTap: ((ScriptureHit) -> Void)?
    /// Tap on empty space / non-verse text (used to toggle reading-mode chrome).
    var onBackgroundTap: (() -> Void)?

    /// Our own copy of the rendered string — read for attribute lookup so we never touch
    /// `textStorage` (which would force TextKit 1 compatibility mode).
    private var scriptureString = NSAttributedString()

    /// Width/length last fully laid out — so `layoutSubviews` re-ensures layout only when the
    /// content or width actually changes, not on every pass.
    private var lastLayoutWidth: CGFloat = -1
    private var lastLayoutLength: Int = -1

    // MARK: Full layout
    //
    // TextKit 2 lays out lazily around the viewport, so a `UITextView`'s `contentSize` only spans
    // the region it has already been scrolled to — scrolling then jams at that high-water mark and
    // can't reach the rest of a multi-chapter window document. Forcing a full layout for the whole
    // (bounded) document range once the bounds are known makes `contentSize` span everything, so the
    // window scrolls end-to-end. `layoutSubviews` is where bounds are valid, and the width/length
    // guard keeps this from re-running every pass.
    /// True while a width-change reflow is being re-anchored, so scroll reporting ignores the
    /// transient offsets (they'd report a drifted verse and could rotate the window).
    private(set) var isReanchoring = false
    /// True from the moment the bounds width differs from the last laid-out width until the
    /// re-anchor lands. Scroll reports in that window pair a new layout with the old offset, so
    /// they name the wrong verse (and can trigger a window rebuild that overrides the re-anchor).
    var isReflowPending: Bool {
        isReanchoring || reanchorIndex != nil || (lastLayoutWidth > 0 && abs(bounds.width - lastLayoutWidth) > 0.5)
    }
    /// Called after a width-change re-anchor so the owner can refresh its verse-position table.
    var onReanchored: (() -> Void)?
    /// Sorted character offsets of each verse's first character, supplied by the owner.
    var verseStartOffsets: (() -> [Int])?
    private var reanchorIndex: Int?
    private var reanchorWork: DispatchWorkItem?

    // A width change (sidebar collapse, rotation, split view) reflows every line, so the unchanged
    // contentOffset would land on different text. By `layoutSubviews` UIKit has already re-laid the
    // text at the new width, so the anchor (the verse at the top of the viewport) must be read when
    // the new size arrives, while the layout is still the old one.
    override var bounds: CGRect {
        get { super.bounds }
        set { captureReanchor(forWidth: newValue.width); super.bounds = newValue }
    }

    override var frame: CGRect {
        get { super.frame }
        set { captureReanchor(forWidth: newValue.width); super.frame = newValue }
    }

    private func captureReanchor(forWidth width: CGFloat) {
        guard reanchorIndex == nil, width > 0, lastLayoutWidth > 0,
              abs(width - lastLayoutWidth) > 0.5, abs(width - super.bounds.width) > 0.5,
              scriptureString.length == lastLayoutLength,
              contentOffset.y > textContainerInset.top + 2,
              !isTracking, !isDragging, !isDecelerating,
              let starts = verseStartOffsets?(), !starts.isEmpty else { return }
        let threshold = contentOffset.y + textContainerInset.top + 1
        var lo = 0, hi = starts.count - 1, best = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if let y = contentY(forCharacterIndex: starts[mid]), y <= threshold {
                best = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        reanchorIndex = starts[best]
        isReanchoring = true
    }

    override func layoutSubviews() {
        let widthChangedNow = lastLayoutWidth > 0 && abs(bounds.width - lastLayoutWidth) > 0.5
        super.layoutSubviews()
        guard bounds.width > 0, let lm = textLayoutManager else { return }
        if bounds.width != lastLayoutWidth || scriptureString.length != lastLayoutLength {
            lastLayoutWidth = bounds.width
            lastLayoutLength = scriptureString.length
            lm.ensureLayout(for: lm.documentRange)
        }
        if reanchorIndex != nil {
            scheduleReanchor(attempt: 0)
        } else if widthChangedNow {
            DispatchQueue.main.async { [weak self] in self?.onReanchored?() }
        }
    }

    /// TextKit 2 hasn't re-laid the text at the new width inside the layout pass that noticed the
    /// change (positions still reflect the old width), so the scroll-back is applied a beat later
    /// and re-checked until the anchor character really is at the top.
    private func scheduleReanchor(attempt: Int) {
        reanchorWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let index = self.reanchorIndex else { return }
            guard !self.isTracking, !self.isDragging else { self.finishReanchor(); return }
            self.layoutIfNeeded()
            self.ensureFullLayout()
            self.scrollCharacterToTop(index, animated: false)
            if attempt < 3, !self.isScrolledToCharacter(index) {
                self.scheduleReanchor(attempt: attempt + 1)
            } else {
                self.finishReanchor()
            }
        }
        reanchorWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func finishReanchor() {
        reanchorIndex = nil
        onReanchored?()
        isReanchoring = false
    }

    // MARK: Factory

    /// Builds a configured read-only TextKit 2 text view that owns its own scrolling.
    static func makeReadOnly() -> ScriptureTextView {
        let textView = ScriptureTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        textView.contentInsetAdjustmentBehavior = .never
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 120, right: 16)

        let tap = UITapGestureRecognizer(target: textView, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        textView.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: textView, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.35
        longPress.cancelsTouchesInView = false
        textView.addGestureRecognizer(longPress)

        // NOTE: the left-edge nav swipe is handled by a separate `EdgeSwipeCatcher` view placed
        // OUTSIDE this scroll view (see BibleWindowedReader) — a gesture added to the text view
        // itself never fires because the scroll view's own pan blocks it.
        return textView
    }

    /// Applies the reading gutter (horizontal) and the top/bottom insets that keep the first
    /// and last lines clear of the floating toolbar and bottom bar while the text scrolls
    /// behind them. Preserves scroll position across an inset change.
    func setReadingInsets(top: CGFloat, bottom: CGFloat, horizontal: CGFloat) {
        let new = UIEdgeInsets(top: top, left: horizontal, bottom: bottom, right: horizontal)
        guard textContainerInset != new else { return }
        let previousTop = textContainerInset.top
        let offset = contentOffset
        textContainerInset = new
        // A change in the top inset shifts all content down/up by the delta; counter it so the
        // reader stays put instead of jumping when the chrome shows/hides.
        let dTop = top - previousTop
        if abs(dTop) > 0.5 {
            setContentOffset(CGPoint(x: offset.x, y: max(-top, offset.y + dTop)), animated: false)
        }
    }

    // MARK: Content

    /// Replaces the rendered content, keeping our attribute-lookup copy in sync.
    func setScriptureText(_ attributed: NSAttributedString) {
        cachedAccessibilityElements = nil
        scriptureString = attributed
        // Setting `attributedText` stays in TextKit 2; setting `textStorage` would not.
        attributedText = attributed
    }

    var scriptureLength: Int { scriptureString.length }

    // MARK: Tap resolution

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let hit = hit(at: point) else {
            // Empty margin / heading / gap — treat as a background tap (reading-mode toggle).
            onBackgroundTap?()
            return
        }
        switch hit.role {
        case .noteIndicator:
            onNoteTap?(hit)
        case .verseText, .verseNumber:
            onVerseTap?(hit)
        case .chapterBook, .chapterTitle, .sectionHeading:
            onBackgroundTap?()
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: self)
        guard let hit = hit(at: point) else { return }
        if hit.word != nil {
            onWordLookup?(hit)
        } else if hit.role == .verseText || hit.role == .verseNumber {
            onVerseTap?(hit)
        }
    }

    /// Resolves the character under `point` (view coordinates) to its Scripture metadata.
    func hit(at point: CGPoint) -> ScriptureHit? {
        guard scriptureString.length > 0 else { return nil }
        // Ignore taps that don't land on any glyph run (empty margins / trailing space).
        guard characterRange(at: point) != nil,
              let position = closestPosition(to: point) else { return nil }
        let index = offset(from: beginningOfDocument, to: position)
        guard index >= 0, index < scriptureString.length else { return nil }

        let attrs = scriptureString.attributes(at: index, effectiveRange: nil)
        guard let roleRaw = attrs[.scriptureRole] as? String,
              let role = ScriptureRole(rawValue: roleRaw) else { return nil }

        return ScriptureHit(
            role: role,
            reference: attrs[.scriptureVerseReference] as? String,
            verseNumber: attrs[.scriptureVerseNumber] as? Int,
            book: attrs[.scriptureBook] as? String,
            chapter: attrs[.scriptureChapter] as? Int,
            word: attrs[.scriptureWord] as? String
        )
    }

    // MARK: Geometry (TextKit 2)

    /// Ensures the whole document is laid out (the window is bounded, so this is cheap).
    func ensureFullLayout() {
        guard let lm = textLayoutManager else { return }
        lm.ensureLayout(for: lm.documentRange)
    }

    /// The content-space Y (including the top text-container inset) of the character at `index`.
    func contentY(forCharacterIndex index: Int) -> CGFloat? {
        guard let lm = textLayoutManager, let cm = lm.textContentManager else { return nil }
        guard index >= 0, index <= scriptureString.length,
              let location = cm.location(cm.documentRange.location, offsetBy: index) else { return nil }
        lm.ensureLayout(for: lm.documentRange)
        guard let fragment = lm.textLayoutFragment(for: location) else { return nil }
        // A layout fragment is a whole paragraph, so a verse in the middle of a long paragraph would
        // resolve to the paragraph's top. Descend to the line that actually holds the character.
        var y = fragment.layoutFragmentFrame.minY
        let fragmentStart = cm.offset(from: cm.documentRange.location, to: fragment.rangeInElement.location)
        let local = index - fragmentStart
        if let line = fragment.textLineFragments.first(where: { NSLocationInRange(local, $0.characterRange) }) {
            y += line.typographicBounds.minY
        }
        return y + textContainerInset.top
    }

    /// Height of the laid-out text. `contentSize` can lag behind a freshly assembled document, which
    /// would clamp a deep scroll target short of the verse; the layout manager's usage bounds don't.
    private var laidOutContentHeight: CGFloat {
        guard let lm = textLayoutManager else { return contentSize.height }
        lm.ensureLayout(for: lm.documentRange)
        let used = lm.usageBoundsForTextContainer.height + textContainerInset.top + textContainerInset.bottom
        return max(contentSize.height, used)
    }

    /// Scrolls the character at `index` to (near) the top of the viewport.
    func scrollCharacterToTop(_ index: Int, animated: Bool) {
        guard let y = contentY(forCharacterIndex: index) else { return }
        let maxOffset = max(0, laidOutContentHeight - bounds.height + adjustedContentInset.bottom)
        let target = min(max(0, y - textContainerInset.top), maxOffset)
        setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    /// True when the view is still where `scrollCharacterToTop(index)` would put it — used to
    /// re-apply a navigation once layout has settled, without fighting a user who has scrolled.
    func isScrolledToCharacter(_ index: Int) -> Bool {
        guard let y = contentY(forCharacterIndex: index) else { return true }
        let maxOffset = max(0, laidOutContentHeight - bounds.height + adjustedContentInset.bottom)
        let target = min(max(0, y - textContainerInset.top), maxOffset)
        return abs(contentOffset.y - target) < 2
    }

    // MARK: Accessibility

    private var cachedAccessibilityElements: [UIAccessibilityElement]?

    override var accessibilityElements: [Any]? {
        get {
            if let cached = cachedAccessibilityElements { return cached }
            guard scriptureString.length > 0 else { return nil }

            var elements: [UIAccessibilityElement] = []
            let full = NSRange(location: 0, length: scriptureString.length)
            let nsString = scriptureString.string as NSString

            scriptureString.enumerateAttribute(.scriptureRole, in: full, options: []) { [weak self] value, range, _ in
                guard let self,
                      let roleRaw = value as? String,
                      let role = ScriptureRole(rawValue: roleRaw) else { return }
                let attrs = scriptureString.attributes(at: range.location, effectiveRange: nil)
                let text = nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty || role == .noteIndicator else { return }

                let elem = UIAccessibilityElement(accessibilityContainer: self)
                switch role {
                case .chapterBook, .chapterTitle:
                    elem.accessibilityTraits = .header
                    elem.accessibilityLabel = text
                case .sectionHeading:
                    elem.accessibilityTraits = .header
                    elem.accessibilityLabel = text
                case .verseNumber:
                    if let num = attrs[.scriptureVerseNumber] as? Int {
                        elem.accessibilityLabel = "Verse \(num)"
                    } else {
                        elem.accessibilityLabel = "Verse \(text)"
                    }
                case .verseText:
                    let ref = attrs[.scriptureVerseReference] as? String ?? ""
                    elem.accessibilityLabel = ref.isEmpty ? text : "\(ref): \(text)"
                case .noteIndicator:
                    elem.accessibilityTraits = .button
                    elem.accessibilityLabel = "Study Note"
                }
                if let y = self.contentY(forCharacterIndex: range.location) {
                    elem.accessibilityFrameInContainerSpace = CGRect(x: self.textContainerInset.left,
                                                                     y: y,
                                                                     width: self.bounds.width - self.textContainerInset.left - self.textContainerInset.right,
                                                                     height: 20)
                }
                elements.append(elem)
            }
            cachedAccessibilityElements = elements
            return elements
        }
        set { cachedAccessibilityElements = newValue as? [UIAccessibilityElement] }
    }
}

// MARK: - Attributed Scripture Cache
//
// Caches built NSAttributedString instances by chapter and presentation state.
// Avoids re-building and re-tokenizing large chapter documents on every layout/render tick.
final class AttributedScriptureCache {
    static let shared = AttributedScriptureCache()
    private let cache = NSCache<NSString, NSAttributedString>()

    init() {
        cache.countLimit = 40
    }

    func attributedText(
        chapter: LoadedChapter,
        settings: BibleReadingSettings,
        translation: BibleTranslation,
        colorScheme: ColorScheme,
        verseByVerse: Bool,
        renderState: ScriptureRenderState,
        includeChapterHeader: Bool
    ) -> NSAttributedString {
        let key = cacheKey(
            chapter: chapter,
            settings: settings,
            translation: translation,
            colorScheme: colorScheme,
            verseByVerse: verseByVerse,
            renderState: renderState,
            includeChapterHeader: includeChapterHeader
        )
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        let built = BibleAttributedTextBuilder(
            chapter: chapter,
            settings: settings,
            translation: translation,
            colorScheme: colorScheme,
            verseByVerse: verseByVerse,
            renderState: renderState,
            includeChapterHeader: includeChapterHeader
        ).build()
        cache.setObject(built, forKey: key as NSString)
        return built
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func cacheKey(
        chapter: LoadedChapter,
        settings: BibleReadingSettings,
        translation: BibleTranslation,
        colorScheme: ColorScheme,
        verseByVerse: Bool,
        renderState: ScriptureRenderState,
        includeChapterHeader: Bool
    ) -> String {
        let sel = renderState.selectedReferences.sorted().joined(separator: ",")
        let lookup = renderState.wordLookup.map { "\($0.verseID):\($0.word)" } ?? ""
        let highlights = renderState.highlightsByReference.map { "\($0.key):\($0.value.color)" }.sorted().joined(separator: ",")
        let notes = renderState.notedReferences.sorted().joined(separator: ",")
        let bookmarks = renderState.bookmarkedReferences.sorted().joined(separator: ",")
        let audio = renderState.audioReference ?? ""
        return "\(chapter.id)_\(chapter.verses.count)_\(translation.rawValue)_\(settings.fontType.rawValue)_\(settings.readerFontSize)_\(settings.systemTextScale)_\(settings.lineSpacing.rawValue)_\(colorScheme == .dark)_\(verseByVerse)_\(settings.showPoetryLayout)_\(includeChapterHeader)_\(sel)_\(lookup)_\(highlights)_\(notes)_\(bookmarks)_\(audio)_\(ReaderCosmetics.cacheKey)"
    }
}
