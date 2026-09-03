import SwiftUI

/// The reusable "Study Library" catalog — a system for adding optional study tools (the large
/// public-domain commentaries) that aren't bundled. Rendered inline; wrap it in
/// `StudyLibrarySheet` for a presentable screen, or embed it in onboarding via
/// `OnboardingStudyLibraryStepView`.
struct StudyLibraryView: View {
    @StateObject private var manager = CommentaryDownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Optional accent for surfaces that theme it (onboarding).
    var accent: Color = .reforgedGold

    private var downloadable: [CommentarySource] {
        CommentarySource.allCases.filter { !$0.isBundled }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(downloadable) { source in
                StudyLibraryRow(source: source, accent: accent)
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.reforgedCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct StudyLibraryRow: View {
    let source: CommentarySource
    let accent: Color
    @StateObject private var manager = CommentaryDownloadManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showRemoveConfirm = false

    private var isDownloaded: Bool { manager.isDownloaded(source) }
    private var isBusy: Bool { manager.isBusy(source) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(source.blurb)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
        .confirmationDialog("Remove \(source.displayName)?",
                            isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { manager.delete(source) }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isBusy {
            ProgressView()
        } else if isDownloaded {
            Button { showRemoveConfirm = true } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        } else {
            Button { manager.download(source) } label: {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(accent)
                    Text(CommentaryDownloadManager.formatBytes(source.approxBytes))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Presentable sheet

/// Study Library as a self-contained screen, for presenting from verse study.
struct StudyLibrarySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add extra commentaries for deeper offline study. Each is a free public-domain work you can remove anytime.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    StudyLibraryView()
                }
                .padding(20)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Study Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Onboarding step

/// Optional onboarding step offering the Study Library downloads.
struct OnboardingStudyLibraryStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var manager = CommentaryDownloadManager.shared

    private var anyDownloaded: Bool { !manager.downloaded.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    ZStack {
                        Circle().fill(Color.reforgedGold.opacity(0.15)).frame(width: 96, height: 96)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.reforgedGold)
                    }

                    VStack(spacing: 10) {
                        Text("Build Your Study Library")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)
                        Text("Scofield's notes, dictionaries, and a Greek lexicon are already built in. Add these classic commentaries for richer verse study — you can also do this later from any verse or in Settings.")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)

                    StudyLibraryView()
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button { onNext() } label: {
                Text(anyDownloaded ? "Continue" : "Skip for Now")
                    .reforgedPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}
