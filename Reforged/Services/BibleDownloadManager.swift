import Foundation
import Combine

// MARK: - Download State

enum BibleDownloadState: Equatable {
    case notDownloaded
    case partial(downloaded: Int, total: Int)
    case downloading(downloaded: Int, total: Int)
    case downloadingBundle          // Single-file download, indeterminate progress
    case downloaded

    var isDownloading: Bool {
        switch self {
        case .downloading, .downloadingBundle: return true
        default: return false
        }
    }

    /// Returns 0...1 progress fraction. Use `isIndeterminate` to show a spinner instead.
    var progressFraction: Double {
        switch self {
        case .notDownloaded:                    return 0
        case .partial(let d, let t):            return t > 0 ? Double(d) / Double(t) : 0
        case .downloading(let d, let t):        return t > 0 ? Double(d) / Double(t) : 0
        case .downloadingBundle:                return 0
        case .downloaded:                       return 1
        }
    }

    /// True when progress is indeterminate (bundle download in flight).
    var isIndeterminate: Bool {
        if case .downloadingBundle = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .notDownloaded:                    return "Not Downloaded"
        case .partial(let d, let t):            return "\(d) of \(t) chapters"
        case .downloading(let d, let t):        return "Downloading \(d)/\(t)..."
        case .downloadingBundle:                return "Downloading bundle…"
        case .downloaded:                       return "Downloaded"
        }
    }
}

// MARK: - Bundle Configuration

/// Hosts pre-built JSON bundles for each translation.
/// After running Scripts/generate_bible_bundles.py and uploading the files
/// to a GitHub Release, replace the placeholder URL below.
struct BibleBundleConfig {
    // ── Replace with your actual GitHub username and repo ──────────────────
    private static let baseURL =
        "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/bible-bundles-v1"
    // ───────────────────────────────────────────────────────────────────────

    /// Returns nil when the placeholder URL has not been set yet, which causes
    /// the download manager to fall back to chapter-by-chapter fetching.
    static func bundleURL(for translation: BibleTranslation) -> URL? {
        guard !baseURL.contains("YOUR_USERNAME") else { return nil }
        let filename: String
        switch translation {
        case .esv:  filename = "esv.json"
        case .kjv:  filename = "kjv.json"
        case .csb:  filename = "csb.json"
        case .nkjv: filename = "nkjv.json"
        case .nasb: filename = "nasb.json"
        }
        return URL(string: "\(baseURL)/\(filename)")
    }
}

// MARK: - Bible Download Manager

@MainActor
class BibleDownloadManager: ObservableObject {
    static let shared = BibleDownloadManager()

    @Published var states: [BibleTranslation: BibleDownloadState] = [:]

    private var activeTasks: [BibleTranslation: Task<Void, Never>] = [:]

    static let totalChapters = BibleData.books.reduce(0) { $0 + $1.chapters }

    private init() {
        refreshAllStates()
    }

    // MARK: - State Refresh

    func refreshAllStates() {
        for translation in BibleTranslation.allCases {
            states[translation] = computeState(for: translation)
        }
    }

    private func computeState(for translation: BibleTranslation) -> BibleDownloadState {
        let cached = cachedCount(for: translation)
        let total  = Self.totalChapters
        if cached == 0     { return .notDownloaded }
        if cached >= total { return .downloaded }
        return .partial(downloaded: cached, total: total)
    }

    private func cachedCount(for translation: BibleTranslation) -> Int {
        switch translation {
        case .esv:              return ESVService.shared.cachedChapterCount
        case .kjv:              return KJVService.shared.cachedChapterCount
        case .csb, .nkjv, .nasb: return ApiBibleService.shared.cachedChapterCount(for: translation)
        }
    }

    // MARK: - Download

    func download(_ translation: BibleTranslation) {
        guard activeTasks[translation] == nil else { return }

        // Show bundle-download state immediately; fall back to chapter progress if needed
        states[translation] = .downloadingBundle

        let task = Task {
            var bundleSucceeded = false

            if let url = BibleBundleConfig.bundleURL(for: translation) {
                do {
                    try await downloadBundle(translation: translation, from: url)
                    bundleSucceeded = true
                } catch {
                    print("[\(translation.rawValue)] Bundle download failed: \(error). Falling back to chapter-by-chapter.")
                }
            }

            if Task.isCancelled { return }

            if !bundleSucceeded {
                await downloadChapterByChapter(translation)
            }

            activeTasks[translation] = nil

            let count = cachedCount(for: translation)
            let total = Self.totalChapters
            states[translation] = count >= total
                ? .downloaded
                : .partial(downloaded: count, total: total)
        }

        activeTasks[translation] = task
    }

    // MARK: - Bundle Download

    private func downloadBundle(translation: BibleTranslation, from url: URL) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Decode on a detached task so the main thread stays responsive
        switch translation {
        case .esv:
            let bundle = try await Task.detached(priority: .userInitiated) {
                try JSONDecoder().decode([String: ESVCachedChapter].self, from: data)
            }.value
            ESVService.shared.injectBundle(bundle)

        case .kjv:
            let bundle = try await Task.detached(priority: .userInitiated) {
                try JSONDecoder().decode([String: KJVCachedChapter].self, from: data)
            }.value
            KJVService.shared.injectBundle(bundle)

        case .csb, .nkjv, .nasb:
            let bundle = try await Task.detached(priority: .userInitiated) {
                try JSONDecoder().decode([String: ApiBibleCachedChapter].self, from: data)
            }.value
            ApiBibleService.shared.injectBundle(bundle)
        }
    }

    // MARK: - Chapter-by-Chapter Fallback

    private func downloadChapterByChapter(_ translation: BibleTranslation) async {
        let total      = Self.totalChapters
        var downloaded = cachedCount(for: translation)
        states[translation] = .downloading(downloaded: downloaded, total: total)

        for book in BibleData.books {
            for chapter in 1...book.chapters {
                if Task.isCancelled { return }
                do {
                    try await fetchChapter(book: book.name, chapter: chapter, translation: translation)
                    downloaded += 1
                    if !Task.isCancelled {
                        states[translation] = .downloading(downloaded: downloaded, total: total)
                    }
                } catch {
                    // Skip failed chapters; they'll be fetched on demand during reading
                }
            }
            if Task.isCancelled { return }
        }
    }

    private func fetchChapter(book: String, chapter: Int, translation: BibleTranslation) async throws {
        switch translation {
        case .esv:
            _ = try await ESVService.shared.fetchChapterParsed(book: book, chapter: chapter)
        case .kjv:
            _ = try await KJVService.shared.fetchChapterParsed(book: book, chapter: chapter)
        case .csb, .nkjv, .nasb:
            _ = try await ApiBibleService.shared.fetchChapterParsed(book: book, chapter: chapter, translation: translation)
        }
    }

    // MARK: - Cancel

    func cancelDownload(_ translation: BibleTranslation) {
        activeTasks[translation]?.cancel()
        activeTasks[translation] = nil
        let cached = cachedCount(for: translation)
        let total  = Self.totalChapters
        states[translation] = cached == 0
            ? .notDownloaded
            : .partial(downloaded: cached, total: total)
    }

    // MARK: - Clear

    func clearDownload(_ translation: BibleTranslation) {
        cancelDownload(translation)
        switch translation {
        case .esv:              ESVService.shared.clearCache()
        case .kjv:              KJVService.shared.clearCache()
        case .csb, .nkjv, .nasb: ApiBibleService.shared.clearCache(for: translation)
        }
        states[translation] = .notDownloaded
    }
}
