import Foundation

// MARK: - KJV Audio Service
//
// Sources KJV chapter audio from the free, public-domain repository
// github.com/jeesusonherraturku/kjv_audio_free. The repo's filenames carry an
// unpredictable leading counter, so chapter→file resolution is driven by a
// bundled manifest (kjv_audio_manifest.json, generated from the repo tree).
//
// Streaming is served over the jsDelivr CDN, pinned to an immutable commit so
// URLs never change. Chapters the user has downloaded are played from disk
// instead (see KJVAudioDownloadManager).

class KJVAudioService {
    static let shared = KJVAudioService()
    private init() {}

    /// Immutable pin of jeesusonherraturku/kjv_audio_free so CDN URLs are stable.
    private let repoSHA = "ba38d9e35c17bc73317796c6526328232c4e9914"
    private var cdnBase: String {
        "https://cdn.jsdelivr.net/gh/jeesusonherraturku/kjv_audio_free@\(repoSHA)/"
    }

    /// book name → [repo-relative path], index 0 = chapter 1.
    private lazy var manifest: [String: [String]] = loadManifest()

    private func loadManifest() -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "kjv_audio_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    // MARK: - Manifest lookups

    /// Number of chapters with audio for a book (0 if unknown).
    func chapterCount(book: String) -> Int { manifest[book]?.count ?? 0 }

    /// Repo-relative path for a chapter, or nil if unknown/out of range.
    func relativePath(book: String, chapter: Int) -> String? {
        guard let chapters = manifest[book], chapter >= 1, chapter <= chapters.count else { return nil }
        return chapters[chapter - 1]
    }

    /// Remote streaming URL on the CDN.
    func remoteURL(book: String, chapter: Int) -> URL? {
        guard let path = relativePath(book: book, chapter: chapter),
              let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: cdnBase + encoded)
    }

    // MARK: - Local cache

    /// Root directory for downloaded KJV audio.
    static func audioDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KJVAudio", isDirectory: true)
    }

    /// On-disk location for a downloaded chapter (stable, independent of repo naming).
    func localFileURL(book: String, chapter: Int) -> URL {
        let safeBook = book.replacingOccurrences(of: " ", with: "_")
        return Self.audioDirectory()
            .appendingPathComponent(safeBook, isDirectory: true)
            .appendingPathComponent("\(chapter).mp3")
    }

    func isDownloaded(book: String, chapter: Int) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(book: book, chapter: chapter).path)
    }

    // MARK: - Playback resolution

    /// Best URL to play: the downloaded file if present, otherwise the CDN stream.
    func getAudioURL(book: String, chapter: Int) async throws -> URL {
        if isDownloaded(book: book, chapter: chapter) {
            return localFileURL(book: book, chapter: chapter)
        }
        guard let url = remoteURL(book: book, chapter: chapter) else {
            throw KJVAudioError.noAudioFound
        }
        return url
    }
}

// MARK: - Errors

enum KJVAudioError: LocalizedError {
    case unknownBook(String)
    case invalidURL
    case httpError(Int)
    case noAudioFound

    var errorDescription: String? {
        switch self {
        case .unknownBook(let b): return "Unknown book: \(b)"
        case .invalidURL:        return "Invalid audio URL"
        case .httpError(let c):  return "KJV audio error \(c)"
        case .noAudioFound:      return "No audio available for this chapter"
        }
    }
}
