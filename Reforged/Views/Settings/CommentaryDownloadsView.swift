import SwiftUI

/// Manages the optional large public-domain commentaries (download / delete / progress).
/// Embedded in the Bible Reading settings; the primary download prompt also appears inline
/// in the verse-study Commentary section.
struct CommentaryDownloadsView: View {
    @StateObject private var manager = CommentaryDownloadManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var downloadable: [CommentarySource] {
        CommentarySource.allCases.filter { !$0.isBundled }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Scofield's notes are built in. Download these larger public-domain commentaries for offline verse study.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            ForEach(downloadable) { source in
                CommentaryDownloadRow(source: source)
                if source != downloadable.last { SettingsDivider() }
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.reforgedCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

private struct CommentaryDownloadRow: View {
    let source: CommentarySource
    @StateObject private var manager = CommentaryDownloadManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showClearConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            actionButton
        }
        .padding(.vertical, 10)
        .confirmationDialog("Remove \(source.displayName)?",
                            isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { manager.delete(source) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusText: String {
        if manager.isBusy(source) { return "Downloading…" }
        if manager.isDownloaded(source) { return "Downloaded" }
        return CommentaryDownloadManager.formatBytes(source.approxBytes)
    }

    private var statusColor: Color {
        if manager.isDownloaded(source) { return .green }
        return Color.adaptiveTextSecondary(colorScheme)
    }

    @ViewBuilder
    private var actionButton: some View {
        if manager.isBusy(source) {
            ProgressView()
        } else if manager.isDownloaded(source) {
            Button { showClearConfirm = true } label: {
                Label("Remove", systemImage: "trash")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else {
            Button { manager.download(source) } label: {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedNavy)
            }
            .buttonStyle(.plain)
        }
    }
}
