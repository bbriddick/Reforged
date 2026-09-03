import Foundation
import SwiftUI

/// Downloads the large public-domain commentaries (Matthew Henry, Barnes, Treasury of David,
/// Calvin) on demand, caching each as a single JSON file in Application Support. These are too
/// large to bundle (~100 MB combined), so they are hosted as zipped JSON on a jsDelivr-backed
/// GitHub repo and fetched only when the user opts in — the same CDN pattern as `KJVAudioService`.
/// Each `.json.zip` is downloaded, inflated on device (`MinimalZip`), and cached as plain JSON.
@MainActor
final class CommentaryDownloadManager: ObservableObject {
    static let shared = CommentaryDownloadManager()

    /// Per-source download progress (0...1) while actively downloading.
    @Published var progress: [CommentarySource: Double] = [:]
    /// Sources present on disk.
    @Published var downloaded: Set<CommentarySource> = []
    /// Last error message, surfaced by the downloads UI.
    @Published var lastError: String?

    /// Files live at the repo root. `@main` follows the branch; jsDelivr caches for ~12h.
    private let repoRef = "main"
    private var cdnBase: String {
        "https://cdn.jsdelivr.net/gh/bbriddick/Reforged@\(repoRef)/"
    }

    private init() {
        refreshState()
    }

    // MARK: - Storage

    nonisolated static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Commentaries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for source: CommentarySource) -> URL? {
        source.remoteFile.map { Self.directory().appendingPathComponent($0) }
    }

    func isDownloaded(_ source: CommentarySource) -> Bool {
        guard let url = fileURL(for: source) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func isBusy(_ source: CommentarySource) -> Bool { progress[source] != nil }

    func refreshState() {
        downloaded = Set(CommentarySource.allCases.filter { !$0.isBundled && isDownloaded($0) })
    }

    var downloadedBytes: Int64 {
        CommentarySource.allCases.reduce(0) { total, source in
            guard let url = fileURL(for: source),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return total }
            return total + Int64(size)
        }
    }

    // MARK: - Download / delete

    func download(_ source: CommentarySource) {
        guard let file = source.remoteFile, progress[source] == nil, !isDownloaded(source) else { return }
        guard let remote = URL(string: cdnBase + file + ".zip") else { return }
        progress[source] = 0
        lastError = nil

        Task {
            do {
                try await downloadFile(from: remote, for: source)
                CommentaryService.shared.reload(source)
            } catch {
                lastError = "Couldn't download \(source.displayName): \(error.localizedDescription)"
            }
            progress[source] = nil
            refreshState()
        }
    }

    func delete(_ source: CommentarySource) {
        guard let url = fileURL(for: source) else { return }
        try? FileManager.default.removeItem(at: url)
        CommentaryService.shared.reload(source)
        refreshState()
    }

    /// Downloads the zipped JSON, inflates it off the main thread, and writes the plain JSON to
    /// disk. Progress is coarse (busy vs done) — single large files, so the UI shows a spinner.
    private func downloadFile(from remote: URL, for source: CommentarySource) async throws {
        guard let dest = fileURL(for: source) else { return }
        let (tmp, response) = try await URLSession.shared.download(from: remote)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try await Task.detached(priority: .userInitiated) { () throws -> Data in
            let zipData = try Data(contentsOf: tmp)
            guard let json = MinimalZip.extractJSON(from: zipData) else {
                throw URLError(.cannotDecodeContentData)
            }
            return json
        }.value

        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try json.write(to: dest, options: .atomic)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
