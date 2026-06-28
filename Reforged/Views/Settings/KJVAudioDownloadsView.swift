import SwiftUI

// MARK: - KJV Audio Downloads
//
// Lets the user cache KJV chapter audio on device — the whole Bible at once or a
// book at a time. Downloaded chapters are played from disk automatically.

struct KJVAudioDownloadsView: View {
    @StateObject private var manager = KJVAudioDownloadManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteAllConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                SettingsDivider()

                ForEach(BibleData.books, id: \.name) { book in
                    bookRow(book.name)
                    if book.name != BibleData.books.last?.name { SettingsDivider() }
                }
            }
            .padding()
        }
        .navigationTitle("KJV Audio")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .onAppear { manager.refreshState() }
        .confirmationDialog("Delete all downloaded KJV audio?",
                            isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { manager.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every cached KJV chapter. You can re-download anytime.")
        }
    }

    // MARK: - Header (whole-Bible)

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Download KJV audio for offline listening. Chapters you download play from your device — no connection needed.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entire KJV Audio Bible")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(manager.isDownloadingAll
                         ? "Downloading… \(Int(manager.allProgress * 100))%"
                         : "1,189 chapters · about 2–4 GB")
                        .font(.caption)
                        .foregroundStyle(manager.isDownloadingAll ? Color.reforgedNavy : Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                if manager.isDownloadingAll {
                    Button { manager.cancelAll() } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { manager.downloadAll() } label: {
                        Label("Download All", systemImage: "arrow.down.circle")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(Color.reforgedNavy)
                    }
                    .buttonStyle(.plain)
                }
            }

            if manager.isDownloadingAll {
                ProgressView(value: manager.allProgress).tint(Color.reforgedNavy)
            }

            if manager.downloadedBytes > 0 {
                HStack {
                    Text("\(KJVAudioDownloadManager.formatBytes(manager.downloadedBytes)) on device")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                    Button { showDeleteAllConfirm = true } label: {
                        Text("Delete All").font(.caption2).fontWeight(.semibold).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Per-book row

    @ViewBuilder
    private func bookRow(_ book: String) -> some View {
        let total = KJVAudioService.shared.chapterCount(book: book)
        let isDownloaded = manager.downloadedBooks.contains(book)
        let progress = manager.bookProgress[book]

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(statusText(total: total, isDownloaded: isDownloaded, progress: progress))
                        .font(.caption)
                        .foregroundStyle(statusColor(isDownloaded: isDownloaded, progress: progress))
                }

                Spacer()

                if progress != nil {
                    Button { manager.cancel(book: book) } label: {
                        Image(systemName: "xmark.circle").font(.callout).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else if isDownloaded {
                    Button { manager.deleteBook(book) } label: {
                        Image(systemName: "trash").font(.callout).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { manager.downloadBook(book) } label: {
                        Image(systemName: "arrow.down.circle").font(.callout).foregroundStyle(Color.reforgedNavy)
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isDownloadingAll)
                    .opacity(manager.isDownloadingAll ? 0.4 : 1)
                }
            }

            if let progress {
                ProgressView(value: progress).tint(Color.reforgedNavy)
            }
        }
        .padding(.vertical, 10)
    }

    private func statusText(total: Int, isDownloaded: Bool, progress: Double?) -> String {
        if let progress { return "Downloading… \(Int(progress * 100))%" }
        if isDownloaded { return "Downloaded · \(total) chapters" }
        return "\(total) chapters"
    }

    private func statusColor(isDownloaded: Bool, progress: Double?) -> Color {
        if progress != nil { return Color.reforgedNavy }
        if isDownloaded { return .green }
        return Color.adaptiveTextSecondary(colorScheme)
    }
}
