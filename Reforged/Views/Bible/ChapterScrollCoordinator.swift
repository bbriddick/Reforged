import SwiftUI

// MARK: - Chapter Spine
//
// The reader is built on a STABLE chapter spine: one permanent, ordered `[ChapterRef]` covering every
// chapter in the Bible. The outer `LazyVStack` iterates this list and NOTHING ever inserts, removes, or
// re-identifies its rows while scrolling — that structural churn (prepend/append/trim) was the source of
// the old scroll instability. Instead, each row owns a `ChapterRenderState` and the coordinator hydrates
// nearby chapter bodies and dehydrates distant ones as the reader moves. The rows themselves are eternal;
// only the content inside them is virtualized.

/// A permanent reference to one chapter in the reading spine. Its `id` never changes for the lifetime of
/// the app, so the LazyVStack row it backs keeps a stable identity through every hydrate/dehydrate cycle.
struct ChapterRef: Identifiable, Equatable, Hashable {
    let book: String
    let chapter: Int
    let testament: BibleBook.Testament
    var id: String { "\(book) \(chapter)" }

    static func == (lhs: ChapterRef, rhs: ChapterRef) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The render state a single spine row can be in. A row is never removed from the stack — it simply moves
/// between these states as the coordinator manages chapter-body hydration.
enum ChapterRenderState {
    case unloaded               // row exists, body not fetched (placeholder)
    case loading                // fetch in flight (spinner)
    case loaded(LoadedChapter)  // body ready (full content)
    case error(String)          // fetch failed (retry affordance)
}

/// The whole-Bible spine, built once at launch and shared by the coordinator.
enum BibleChapterSpine {
    /// Every chapter, in canonical order, as a stable ordered list of refs.
    static let all: [ChapterRef] = BibleData.books.flatMap { book in
        (1...book.chapters).map { ChapterRef(book: book.name, chapter: $0, testament: book.testament) }
    }

    /// O(1) id → spine-index lookup, for proximity math.
    static let indexByID: [String: Int] = {
        var map = [String: Int](minimumCapacity: all.count)
        for (idx, ref) in all.enumerated() { map[ref.id] = idx }
        return map
    }()
}

// MARK: - Loaded Chapter Model

/// One fully-rendered chapter body. Self-contained (verses + derived sections + red-letter segments) so a
/// spine row can render entirely from its own state without reaching back into single-chapter view state.
struct LoadedChapter: Identifiable, Equatable {
    let book: String
    let chapter: Int
    let verses: [ParsedVerse]
    let canonical: String
    let sections: [VerseSection]
    let woc: [String: [WOCSegment]]
    var id: String { "\(book) \(chapter)" }
    static func == (lhs: LoadedChapter, rhs: LoadedChapter) -> Bool {
        lhs.id == rhs.id && lhs.verses.count == rhs.verses.count
    }
}

/// A run of consecutive verses under an optional section heading (paragraph-mode grouping).
struct VerseSection {
    let heading: String?
    let verses: [ParsedVerse]
}

// MARK: - Chapter Cache Types

struct ChapterCacheKey: Hashable {
    let book: String
    let chapter: Int
    let translation: BibleTranslation
}

struct ChapterCacheEntry {
    let verses: [ParsedVerse]
    let canonical: String
}

// MARK: - Chapter Scroll Coordinator

/// Owns the stable spine's per-row render state and manages proximity-based chapter-body hydration.
///
/// This object replaces the old shifting `[LoadedChapter]` window. The view renders rows from `refs`
/// (which never changes) and reads each row's body from `state(for:)`. As the visible center chapter
/// changes, the view calls `updateHydration(around:)`, which loads bodies within `hydrateRadius` and
/// unloads bodies beyond `keepRadius` — without ever touching the row collection itself.
@MainActor
final class ChapterScrollCoordinator: ObservableObject {

    /// The stable, never-mutated row spine.
    let refs = BibleChapterSpine.all
    private let indexByID = BibleChapterSpine.indexByID

    /// Per-row render state, keyed by `ChapterRef.id`. Absent keys are treated as `.unloaded`.
    @Published private(set) var states: [String: ChapterRenderState] = [:]

    /// The id of the chapter whose body most recently finished hydrating. The view observes this to know
    /// when a freshly-focused chapter is ready to be scrolled into position (chapter top or restored verse).
    @Published private(set) var lastHydratedID: String?

    /// Translation currently being read — drives both the fetch and the body derivation (red-letter etc.).
    private(set) var translation: BibleTranslation = .kjv

    /// In-memory parsed-chapter cache (formerly the view's `chapterCache`).
    private var cache: [ChapterCacheKey: ChapterCacheEntry] = [:]

    /// Bumped on every reset/translation switch to invalidate in-flight async hydrations.
    private var generation = 0
    /// In-flight hydration tasks, keyed by id, so dehydration can cancel them.
    private var inflight: [String: Task<Void, Never>] = [:]

    /// Load bodies within ±`hydrateRadius` of the center; keep bodies within ±`keepRadius`, dehydrate
    /// anything farther. The gap gives hysteresis so small back-and-forth scrolling near the band edge
    /// doesn't thrash the same chapter between loaded and unloaded.
    private let hydrateRadius = 3
    private let keepRadius = 5

    // MARK: Lookups

    func state(for id: String) -> ChapterRenderState { states[id] ?? .unloaded }
    func index(of id: String) -> Int? { indexByID[id] }

    func isLoaded(_ id: String) -> Bool {
        if case .loaded = state(for: id) { return true }
        return false
    }

    /// True when `id` is an OT chapter under a NT-only Greek text, or vice-versa — used by the view to show
    /// the "this text only covers …" message instead of an endless placeholder.
    func isIncompatible(_ id: String) -> Bool {
        guard let idx = indexByID[id] else { return false }
        return !isCompatible(refs[idx])
    }

    /// Loaded chapter bodies in canonical order — for selection actions that may span chapters.
    var orderedLoadedChapters: [LoadedChapter] {
        states.compactMap { (id, st) -> (Int, LoadedChapter)? in
            guard case .loaded(let loaded) = st, let idx = indexByID[id] else { return nil }
            return (idx, loaded)
        }
        .sorted { $0.0 < $1.0 }
        .map { $0.1 }
    }

    // MARK: Translation / reset

    /// Switches translation, dropping the visible render state so nothing stale shows. The parsed-chapter
    /// `cache` is intentionally KEPT — its keys include the translation, so entries for both the old and the
    /// new translation stay valid. Reading then reuses any already-parsed chapter for either translation,
    /// which (together with each service's on-device disk cache) is what makes the app quicker over time.
    /// The caller re-establishes focus afterward via `updateHydration(around:)`.
    func setTranslation(_ newValue: BibleTranslation) {
        guard newValue != translation else { return }
        translation = newValue
        invalidateState()
    }

    /// Ensures the coordinator's translation matches `newValue` without forcing a reset when unchanged.
    /// (Used on first appear, where the view simply adopts the persisted default.)
    func adoptTranslation(_ newValue: BibleTranslation) {
        guard newValue != translation else { return }
        translation = newValue
        invalidateState()
    }

    private func invalidateState() {
        generation &+= 1
        inflight.values.forEach { $0.cancel() }
        inflight.removeAll()
        states.removeAll()
        lastHydratedID = nil
    }

    /// Re-derives the body (sections + red-letter segments) of every currently-loaded chapter in place —
    /// e.g. when the Words-of-Christ setting toggles. Does not refetch; reuses the cached verses.
    func reapplyDerivations() {
        for (id, st) in states {
            guard case .loaded(let loaded) = st else { continue }
            let entry = ChapterCacheEntry(verses: loaded.verses, canonical: loaded.canonical)
            states[id] = .loaded(makeLoadedChapter(book: loaded.book, chapter: loaded.chapter, entry: entry))
        }
    }

    // MARK: Proximity hydration

    /// THE scroll-pipeline core. Given the currently-centered chapter id, hydrate nearby chapter bodies and
    /// dehydrate distant ones. Rows are never added or removed — only their `ChapterRenderState` changes.
    func updateHydration(around centerID: String) {
        guard let center = indexByID[centerID] else { return }

        // Hydrate the proximity band.
        let lo = max(0, center - hydrateRadius)
        let hi = min(refs.count - 1, center + hydrateRadius)
        for i in lo...hi { hydrate(refs[i]) }

        // Dehydrate everything outside the (wider) keep band. The rows stay; only bodies drop.
        let keepLo = max(0, center - keepRadius)
        let keepHi = min(refs.count - 1, center + keepRadius)
        for id in Array(states.keys) {
            guard let idx = indexByID[id], idx < keepLo || idx > keepHi else { continue }
            inflight[id]?.cancel()
            inflight[id] = nil
            states.removeValue(forKey: id)   // absent == .unloaded; remembered height keeps the footprint
        }
    }

    /// Forces a retry of one chapter (used by the row's error-state retry button).
    func retry(_ id: String) {
        guard let idx = indexByID[id] else { return }
        states.removeValue(forKey: id)
        hydrate(refs[idx])
    }

    private func hydrate(_ ref: ChapterRef) {
        switch state(for: ref.id) {
        case .loaded, .loading: return       // already present or in flight
        case .unloaded, .error: break
        }
        // Original-language texts are testament-specific; never attempt an incompatible chapter (it would
        // fetch empty forever). Leave it `.unloaded`; the view surfaces the explanatory message at focus.
        guard isCompatible(ref) else { return }

        let gen = generation
        let t = translation
        states[ref.id] = .loading
        inflight[ref.id] = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.fetchBody(book: ref.book, chapter: ref.chapter, translation: t)
            guard self.generation == gen else { return }     // stale (translation switched / reset)
            self.inflight[ref.id] = nil
            switch outcome {
            case .loaded(let loaded):
                self.states[ref.id] = .loaded(loaded)
                self.lastHydratedID = ref.id
            case .empty:
                self.states.removeValue(forKey: ref.id)   // OL JSON not ready yet
            case .error(let message):
                self.states[ref.id] = .error(message)
            }
        }
    }

    private func isCompatible(_ ref: ChapterRef) -> Bool {
        switch translation {
        case .tr, .sblgnt: return ref.testament == .new
        case .wlc:         return ref.testament == .old
        default:           return true
        }
    }

    // MARK: Fetch + body derivation

    private enum FetchOutcome {
        case loaded(LoadedChapter)
        case empty
        case error(String)
    }

    private func fetchBody(book: String, chapter: Int, translation t: BibleTranslation) async -> FetchOutcome {
        let key = ChapterCacheKey(book: book, chapter: chapter, translation: t)
        do {
            let entry: ChapterCacheEntry
            if let cached = cache[key] {
                entry = cached
            } else {
                entry = try await ChapterFetchSerializer.shared.run {
                    try await Self.performChapterFetch(book: book, chapter: chapter, translation: t)
                }
            }
            if Task.isCancelled { return .empty }
            // Don't cache/apply an empty OL result — the JSON wasn't loaded yet; a re-ready event retries.
            if t.isOriginalLanguage && entry.verses.isEmpty { return .empty }
            cache[key] = entry
            let loaded = makeLoadedChapter(book: book, chapter: chapter, entry: entry)
            // Word-study interlinear prefetch (English translations only), fire-and-forget.
            if !t.isOriginalLanguage {
                let verseCount = entry.verses.count
                Task {
                    await StrongsLexiconService.shared.prefetchChapter(
                        bookName: book, chapter: chapter, totalVerses: verseCount
                    )
                }
            }
            return .loaded(loaded)
        } catch {
            if Task.isCancelled { return .empty }
            return .error(error.localizedDescription)
        }
    }

    /// Builds a fully-derived `LoadedChapter` (sections + red-letter segments) from a fetched entry.
    private func makeLoadedChapter(book: String, chapter: Int, entry: ChapterCacheEntry) -> LoadedChapter {
        LoadedChapter(
            book: book,
            chapter: chapter,
            verses: entry.verses,
            canonical: entry.canonical,
            sections: groupVersesBySection(entry.verses),
            woc: computeWordsOfChrist(for: entry.verses)
        )
    }

    /// Computes the Words-of-Christ (red-letter) segments for a chapter's verses.
    private func computeWordsOfChrist(for verses: [ParsedVerse]) -> [String: [WOCSegment]] {
        guard SettingsManager.shared.showRedLetterText else { return [:] }

        var segmentsByReference: [String: [WOCSegment]] = [:]
        segmentsByReference.reserveCapacity(verses.count)

        for verse in verses {
            guard let segments = WordsOfChristData.shared.segments(for: verse.reference) else { continue }
            if translation == .kjv {
                // KJV: segment text matches the WOC JSON exactly — use as-is.
                segmentsByReference[verse.reference] = segments
            } else {
                // Non-KJV: WOC data uses KJV English text which would show instead of the translated
                // verse. Fall back to whole-verse red when any segment is Christ's words.
                if segments.contains(where: { $0.isRed }) {
                    segmentsByReference[verse.reference] = [WOCSegment(text: verse.text, isRed: true)]
                }
            }
        }
        return segmentsByReference
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

    // MARK: Raw fetch

    /// Fetches one chapter's verses for a translation. Mirrors the old `performChapterFetch`; routed
    /// through `ChapterFetchSerializer` (above) so concurrent service-cache writes can't corrupt.
    static func performChapterFetch(book: String, chapter: Int, translation: BibleTranslation) async throws -> ChapterCacheEntry {
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
        case .csb, .nkjv, .nasb, .rvr1960, .nlt:
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
        case .sblgnt:
            let bookNum = OriginalLanguageService.bookNumber(for: book) ?? 0
            OriginalLanguageService.shared.preloadSBLGNT()
            let sblVerses = OriginalLanguageService.shared.sblChapter(bookNumber: bookNum, chapter: chapter)
            fetchedVerses = sblVerses.map { v in
                let ref = "\(book) \(chapter):\(v.verse)"
                return ParsedVerse(id: ref, number: v.verse, text: v.text, reference: ref)
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
}

// MARK: - Chapter Fetch Serializer

/// Serializes chapter fetches end-to-end. The per-translation services cache into plain (non
/// thread-safe) dictionaries; whole-book loading fetches many chapters at once, so without this the
/// concurrent cache writes corrupt the dictionary and crash (SIGABRT in `Dictionary.subscript`).
/// Each queued fetch — including its service-side cache write — fully completes before the next runs.
actor ChapterFetchSerializer {
    static let shared = ChapterFetchSerializer()
    private var tail: Task<Void, Never> = Task {}

    func run<T>(_ work: @escaping () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task { () async throws -> T in
            await previous.value
            return try await work()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
