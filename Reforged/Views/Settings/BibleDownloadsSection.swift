import SwiftUI

struct BibleDownloadsSection: View {
    @StateObject private var downloadManager = BibleDownloadManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Download Bible translations for offline reading. All \(BibleDownloadManager.totalChapters) chapters will be cached locally.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.bottom, 12)

            ForEach(BibleTranslation.allCases) { translation in
                TranslationDownloadRow(translation: translation)
                if translation != BibleTranslation.allCases.last {
                    SettingsDivider()
                }
            }
        }
    }
}

// MARK: - Translation Download Row

private struct TranslationDownloadRow: View {
    let translation: BibleTranslation
    @StateObject private var downloadManager = BibleDownloadManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showClearConfirm = false

    private var state: BibleDownloadState {
        downloadManager.states[translation] ?? .notDownloaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(translation.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(state.statusText)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }

                Spacer()

                actionButton
            }

            // Progress indicator
            if state.isDownloading || isPartial {
                if state.isIndeterminate {
                    // Bundle download — show animated indeterminate bar
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Color.reforgedNavy)
                } else {
                    ProgressView(value: state.progressFraction)
                        .tint(Color.reforgedNavy)
                }
            }
        }
        .padding(.vertical, 10)
        .confirmationDialog(
            "Clear \(translation.rawValue) Download?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                downloadManager.clearDownload(translation)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached \(translation.rawValue) chapters. You'll need to re-download for offline access.")
        }
    }

    private var isPartial: Bool {
        if case .partial = state { return true }
        return false
    }

    private var stateColor: Color {
        switch state {
        case .notDownloaded:    return Color.adaptiveTextSecondary(colorScheme)
        case .partial:          return .orange
        case .downloading:      return Color.reforgedNavy
        case .downloadingBundle: return Color.reforgedNavy
        case .downloaded:       return .green
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .notDownloaded:
            Button {
                downloadManager.download(translation)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedNavy)
            }
            .buttonStyle(.plain)

        case .partial:
            HStack(spacing: 8) {
                Button {
                    downloadManager.download(translation)
                } label: {
                    Text("Resume")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedNavy)
                }
                .buttonStyle(.plain)

                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

        case .downloading, .downloadingBundle:
            Button {
                downloadManager.cancelDownload(translation)
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

        case .downloaded:
            Button {
                showClearConfirm = true
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
