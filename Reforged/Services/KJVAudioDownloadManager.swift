import Foundation
import SwiftUI

// MARK: - KJV Audio Download Manager
//
// Downloads KJV chapter MP3s to disk for offline listening, either a whole book
// or the entire audio Bible. Files land in KJVAudioService.audioDirectory() and
// are picked up automatically by KJVAudioService.getAudioURL once present.

@MainActor
final class KJVAudioDownloadManager: ObservableObject {
    static let shared = KJVAudioDownloadManager()

    /// Per-book download progress (0...1) while a book is actively downloading.
    @Published var bookProgress: [String: Double] = [:]
    /// Books whose every chapter is present on disk.
    @Published var downloadedBooks: Set<String> = []
    /// Whole-Bible download progress (0...1); only meaningful while `isDownloadingAll`.
    @Published var isDownloadingAll = false
    @Published var allProgress: Double = 0
    /// Bytes currently stored on disk.
    @Published var downloadedBytes: Int64 = 0

    private var cancelled: Set<String> = []
    private let allKey = "__all__"

    private init() {
        refreshState()
    }

    private var allBooks: [String] { BibleData.books.map(\.name) }

    // MARK: - State

    /// Recompute which books are fully downloaded + total bytes on disk.
    func refreshState() {
        var done = Set<String>()
        for book in allBooks {
            let total = KJVAudioService.shared.chapterCount(book: book)
            guard total > 0 else { continue }
            if (1...total).allSatisfy({ KJVAudioService.shared.isDownloaded(book: book, chapter: $0) }) {
                done.insert(book)
            }
        }
        downloadedBooks = done
        downloadedBytes = Self.directorySize(KJVAudioService.audioDirectory())
    }

    func isBusy(book: String) -> Bool { bookProgress[book] != nil }

    // MARK: - Book download

    func downloadBook(_ book: String) {
        guard bookProgress[book] == nil else { return }
        let total = KJVAudioService.shared.chapterCount(book: book)
        guard total > 0 else { return }
        cancelled.remove(book)
        bookProgress[book] = 0

        Task {
            var completed = 0
            for chapter in 1...total {
                if cancelled.contains(book) { break }
                try? await Self.downloadChapter(book: book, chapter: chapter)
                completed += 1
                bookProgress[book] = Double(completed) / Double(total)
            }
            bookProgress[book] = nil
            cancelled.remove(book)
            refreshState()
        }
    }

    func cancel(book: String) {
        guard bookProgress[book] != nil else { return }
        cancelled.insert(book)
    }

    func deleteBook(_ book: String) {
        let dir = KJVAudioService.shared.localFileURL(book: book, chapter: 1).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
        refreshState()
    }

    // MARK: - Whole-Bible download

    func downloadAll() {
        guard !isDownloadingAll else { return }
        cancelled.remove(allKey)
        isDownloadingAll = true
        allProgress = 0

        Task {
            let total = allBooks.reduce(0) { $0 + KJVAudioService.shared.chapterCount(book: $1) }
            var completed = 0
            outer: for book in allBooks {
                let count = KJVAudioService.shared.chapterCount(book: book)
                guard count > 0 else { continue }
                for chapter in 1...count {
                    if cancelled.contains(allKey) { break outer }
                    try? await Self.downloadChapter(book: book, chapter: chapter)
                    completed += 1
                    if total > 0 { allProgress = Double(completed) / Double(total) }
                }
                refreshState()
            }
            isDownloadingAll = false
            cancelled.remove(allKey)
            refreshState()
        }
    }

    func cancelAll() {
        guard isDownloadingAll else { return }
        cancelled.insert(allKey)
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: KJVAudioService.audioDirectory())
        refreshState()
    }

    // MARK: - Helpers

    /// Downloads one chapter to its on-disk location. No-op if already present.
    private static func downloadChapter(book: String, chapter: Int) async throws {
        let dest = KJVAudioService.shared.localFileURL(book: book, chapter: chapter)
        if FileManager.default.fileExists(atPath: dest.path) { return }
        guard let remote = KJVAudioService.shared.remoteURL(book: book, chapter: chapter) else {
            throw KJVAudioError.noAudioFound
        }

        let (tmp, response) = try await URLSession.shared.download(from: remote)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw KJVAudioError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tmp, to: dest)
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    /// Human-readable size string for display.
    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
