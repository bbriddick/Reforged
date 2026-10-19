import SwiftUI
import YouVersionPlatform

/// One place to see what each Bible needs to be read offline, manage downloads,
/// sign in to YouVersion (NASB only) and show/hide the Greek and Hebrew texts.
struct ManageBiblesView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var downloads = BibleDownloadManager.shared
    @StateObject private var yvSignIn = YouVersionSignIn.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var clearTarget: BibleTranslation?
    /// Reorder mode: drag to set the switcher order, tap the eye to show or hide a Bible.
    @State private var editMode: EditMode = .inactive

    private var englishAndModern: [BibleTranslation] {
        settings.translationOrder.filter { !$0.isOriginalLanguage }
    }

    private let originalLanguages: [BibleTranslation] = [.tr, .sblgnt, .wlc]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(englishAndModern) { translation in
                        BibleManageRow(translation: translation, clearTarget: $clearTarget)
                    }
                    .onMove { source, destination in
                        settings.translationOrder.move(fromOffsets: source, toOffset: destination)
                        HapticManager.shared.selectionChanged()
                    }
                } header: {
                    Text("Bibles")
                } footer: {
                    if editMode.isEditing {
                        Text("Drag to set the order in the switcher. Tap the eye to show or hide a Bible there. Your default Bible always stays.")
                    } else {
                        Text("Chapters you read are kept on your device for offline use. Some translations can't be bulk-downloaded because of their publishers' licenses.")
                    }
                }

                Section {
                    ForEach(originalLanguages) { translation in
                        OriginalLanguageRow(translation: translation)
                    }
                } header: {
                    Text("Greek & Hebrew")
                } footer: {
                    Text("Turn on the texts you want in the translation menu. They're built into Reforged and always work offline.")
                }

                if YouVersionConfig.downloadsOffered, YouVersionConfig.requireSignInForDownload, yvSignIn.isSignedIn {
                    Section {
                        Button("Sign out of YouVersion", role: .destructive) { yvSignIn.signOut() }
                    } footer: {
                        Text("Signing out keeps NASB chapters already on your device.")
                    }
                }
            }
            .navigationTitle("Manage Bibles")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(editMode.isEditing ? "Finish" : "Reorder") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { downloads.refreshAllStates() }
            .confirmationDialog(
                "Remove saved \(clearTarget?.rawValue ?? "") chapters?",
                isPresented: Binding(get: { clearTarget != nil }, set: { if !$0 { clearTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let target = clearTarget { downloads.clearDownload(target) }
                    clearTarget = nil
                }
                Button("Cancel", role: .cancel) { clearTarget = nil }
            } message: {
                Text("They'll be fetched again the next time you read them online.")
            }
        }
    }
}

// MARK: - Original-language row

private struct OriginalLanguageRow: View {
    let translation: BibleTranslation
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.isInSwitcher(translation) },
            set: { settings.setInSwitcher(translation, $0) }
        )) {
            HStack(spacing: 12) {
                Text(translation.compactCode)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 32)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(translation.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Included · works offline")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .tint(Color.reforgedGold)
        .padding(.vertical, 4)
    }
}

// MARK: - Row

private struct BibleManageRow: View {
    let translation: BibleTranslation
    @Binding var clearTarget: BibleTranslation?

    @StateObject private var downloads = BibleDownloadManager.shared
    @StateObject private var yvSignIn = YouVersionSignIn.shared
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.editMode) private var editMode

    private var isReordering: Bool { editMode?.wrappedValue.isEditing == true }
    private var isShown: Bool { settings.isInSwitcher(translation) }

    private enum Kind {
        case included      // ships with the app
        case cachedOnRead  // fetched online, kept as you read
        case downloadable  // explicit whole-Bible download
    }

    private var kind: Kind {
        switch translation {
        case .kjv, .tr, .sblgnt, .wlc:
            return .included
        case .nasb where YouVersionConfig.downloadsOffered:
            return .downloadable
        default:
            return .cachedOnRead
        }
    }

    private var state: BibleDownloadState { downloads.states[translation] ?? .notDownloaded }

    private var savedCount: Int {
        switch state {
        case .partial(let d, _), .downloading(let d, _): return d
        case .downloaded: return BibleDownloadManager.totalChapters
        default: return 0
        }
    }

    private var needsSignIn: Bool {
        translation == .nasb && YouVersionConfig.requireSignInForDownload && !yvSignIn.isSignedIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if isReordering {
                    Button {
                        HapticManager.shared.selectionChanged()
                        settings.setInSwitcher(translation, !isShown)
                    } label: {
                        Image(systemName: isShown ? "eye.fill" : "eye.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isShown ? Color.reforgedCoral : Color.adaptiveTextSecondary(colorScheme))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isShown && !settings.canHideFromSwitcher(translation))
                    .opacity(isShown && !settings.canHideFromSwitcher(translation) ? 0.35 : 1)
                    .accessibilityLabel(isShown ? "Hide \(translation.rawValue) from the switcher"
                                                : "Show \(translation.rawValue) in the switcher")
                }

                Text(translation.compactCode)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 32)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(translation.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(isReordering && !isShown ? "Hidden from the switcher" : statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer(minLength: 8)

                if !isReordering { trailingControl }
            }
            .opacity(isReordering && !isShown ? 0.55 : 1)

            if kind == .downloadable, state.isDownloading {
                ProgressView(value: state.progressFraction)
                    .tint(Color.reforgedGold)
            }

            if kind == .downloadable, translation == .nasb, let message = yvSignIn.errorMessage {
                Text(message).font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch kind {
        case .included:
            return "Included · works offline"
        case .cachedOnRead:
            return savedCount > 0 ? "Online · \(savedCount) chapters saved" : "Online"
        case .downloadable:
            if needsSignIn, !state.isDownloading, state != .downloaded { return "Sign in with YouVersion to download" }
            return state.statusText
        }
    }

    private var statusColor: Color {
        switch kind {
        case .included: return .green
        case .cachedOnRead: return Color.adaptiveTextSecondary(colorScheme)
        case .downloadable: return state == .downloaded ? .green : Color.adaptiveTextSecondary(colorScheme)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch kind {
        case .included:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)

        case .cachedOnRead:
            if savedCount > 0 { trashButton }

        case .downloadable:
            if state.isDownloading {
                Button("Cancel") { downloads.cancelDownload(translation) }
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                    .buttonStyle(.plain)
            } else if state == .downloaded {
                trashButton
            } else if needsSignIn {
                SignInWithYouVersionButton(mode: .compact) {
                    Task { await yvSignIn.signIn() }
                }
                .font(.footnote)
                .fixedSize(horizontal: true, vertical: true)
                .layoutPriority(1)
            } else {
                HStack(spacing: 10) {
                    Button {
                        downloads.download(translation)
                    } label: {
                        Label(savedCount > 0 ? "Resume" : "Download", systemImage: "arrow.down.circle")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    }
                    .buttonStyle(.plain)
                    if savedCount > 0 { trashButton }
                }
            }
        }
    }

    private var trashButton: some View {
        Button { clearTarget = translation } label: {
            Image(systemName: "trash").font(.caption).foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove saved \(translation.rawValue) chapters")
    }
}
