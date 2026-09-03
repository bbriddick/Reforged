import SwiftUI

// MARK: - Live-Query SRS Prayer Engine (Requirements §4)
//
// Group prayer cards flow through the memory Spaced-Repetition deck WITHOUT
// their text ever touching local storage. The queue holds only opaque prayer
// ids. When a card is displayed we perform a fresh network read of that id; the
// resulting text lives in `@Published currentPrayer` (in-memory view state) and
// is dropped the moment we advance. Nothing here writes prayer text to
// UserDefaults, the keychain, files, or Core Data.
//
// Deletion / block handling: a live read that returns `nil` (author deleted the
// request, or the author is blocked) causes the id to be purged from the queue
// and the next card loaded automatically — the user never sees a stale card.

@MainActor
final class PrayerReviewEngine: ObservableObject {

    enum Phase: Equatable {
        case loading
        case showing
        case empty
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading
    /// The freshly-fetched prayer for the current card. TRANSIENT — never persisted.
    @Published private(set) var currentPrayer: GroupPrayer?
    @Published private(set) var didPray = false
    /// Preset encouragements already sent for the current card (for chip state).
    @Published private(set) var sentResponses: Set<PrayerResponseKind> = []

    /// Opaque ids only. No prayer text is ever stored here.
    private var queue: [String] = []
    private var index = 0
    private var groupId: String = ""

    // MARK: Lifecycle

    func start(groupId: String) async {
        self.groupId = groupId
        phase = .loading
        do {
            queue = try await GroupsService.shared.prayerQueueIds(groupId: groupId)
            index = 0
            await loadCurrent()
        } catch {
            phase = .error((error as? GroupsError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: Card Loading (fetch-on-display)

    private func loadCurrent() async {
        didPray = false
        sentResponses = []
        currentPrayer = nil

        guard index < queue.count else {
            phase = .empty
            return
        }

        phase = .loading
        let id = queue[index]
        do {
            if let prayer = try await GroupsService.shared.prayer(
                id: id, excluding: BlockListStore.shared.blockedIds) {
                currentPrayer = prayer
                phase = .showing
            } else {
                // Deleted or blocked → purge this id and try the next one.
                purgeCurrent()
                await loadCurrent()
            }
        } catch {
            phase = .error((error as? GroupsError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Removes the id at `index` without advancing, so the next id shifts into
    /// place for the following `loadCurrent()`.
    private func purgeCurrent() {
        guard index < queue.count else { return }
        queue.remove(at: index)
    }

    // MARK: Actions

    func markPrayed() async {
        guard let prayer = currentPrayer else { return }
        didPray = true
        // Best-effort silent notification to the author; failure doesn't block
        // moving on, but is not persisted for retry (no text stored anywhere).
        try? await GroupsService.shared.markPrayed(prayerId: prayer.id)
        HapticManager.shared.success()
        await advance()
    }

    /// Sends a preset encouragement for the current card. Additive — it does NOT
    /// advance, so a member can send an encouragement and still mark prayed.
    /// Optimistic: the chip lights up immediately, rolling back on failure.
    func send(_ kind: PrayerResponseKind) async {
        guard let prayer = currentPrayer, !sentResponses.contains(kind) else { return }
        sentResponses.insert(kind)
        HapticManager.shared.buttonTap()
        do {
            try await GroupsService.shared.respond(prayerId: prayer.id, kind: kind)
        } catch {
            sentResponses.remove(kind)
        }
    }

    func skip() async { await advance() }

    private func advance() async {
        index += 1
        await loadCurrent()
    }

    func retry() async { await start(groupId: groupId) }
}

// MARK: - Prayer Review View

struct GroupPrayerReviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engine = PrayerReviewEngine()
    let group: GroupSummary
    /// Bumped by the hub after composing/refresh so the deck reloads its queue.
    let reloadToken: UUID

    var body: some View {
        Group {
            switch engine.phase {
            case .loading:
                GroupsLoadingView(message: "Loading prayer…")
            case .error(let message):
                GroupsErrorView(message: message) { Task { await engine.retry() } }
            case .empty:
                GroupsMessageScaffold(
                    systemImage: "hands.and.sparkles.fill",
                    title: "You're all caught up",
                    message: "There are no group prayer requests to review right now. They'll appear in your memory deck as they come in."
                )
            case .showing:
                if let prayer = engine.currentPrayer {
                    prayerCard(prayer)
                } else {
                    GroupsLoadingView(message: "Loading prayer…")
                }
            }
        }
        .padding(.top, 8)
        .task(id: "\(group.id)|\(reloadToken)") { await engine.start(groupId: group.id) }
    }

    private func prayerCard(_ prayer: GroupPrayer) -> some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Group Prayer", systemImage: "hands.and.sparkles.fill")
                        .font(.caption).bold()
                        .foregroundStyle(Color.reforgedGold)
                    Spacer()
                    PrayerModerationMenu(prayer: prayer) { Task { await engine.skip() } }
                }
                Text(prayer.authorName ?? "A group member")
                    .font(.subheadline).bold()
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                // Live-fetched text — held only in view state, never stored.
                Text(prayer.text)
                    .font(.title3)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Preset encouragements — a closed set, no free text (Groups is
            // no-chat / minor-safe). Additive taps the author sees tallied.
            VStack(alignment: .leading, spacing: 8) {
                Text("Send an encouragement")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                HStack(spacing: 10) {
                    ForEach(PrayerResponseKind.encouragements) { kind in
                        let sent = engine.sentResponses.contains(kind)
                        Button {
                            Task { await engine.send(kind) }
                        } label: {
                            HStack(spacing: 5) {
                                Text(kind.emoji)
                                Text(kind.label)
                                    .font(.caption).fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(sent ? Color.reforgedGold.opacity(0.18)
                                             : Color.adaptiveSecondaryBackground(colorScheme))
                            .foregroundStyle(sent ? Color.reforgedGold
                                                  : Color.adaptiveText(colorScheme))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(sent ? Color.reforgedGold : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(sent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    Task { await engine.skip() }
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.adaptiveSecondaryBackground(colorScheme))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    Task { await engine.markPrayed() }
                } label: {
                    Label("I prayed for this", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.reforgedGold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Prayer Moderation Menu (Requirements §3)

private struct PrayerModerationMenu: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var blocks = BlockListStore.shared
    let prayer: GroupPrayer
    /// Called after a block so the engine advances past the now-hidden card.
    let onBlocked: () -> Void

    @State private var showReport = false

    var body: some View {
        Menu {
            Button(role: .destructive) { showReport = true } label: {
                Label("Flag Content", systemImage: "flag")
            }
            Button(role: .destructive) { Task { await block() } } label: {
                Label("Block \(prayer.authorName ?? "User")", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .confirmationDialog("Report this prayer?",
                            isPresented: $showReport, titleVisibility: .visible) {
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.label, role: .destructive) {
                    Task {
                        try? await GroupsService.shared.report(
                            contentType: .prayer, contentId: prayer.id, reason: reason.rawValue)
                        HapticManager.shared.success()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func block() async {
        try? await blocks.block(userId: prayer.authorId)
        HapticManager.shared.success()
        onBlocked()
    }
}

// MARK: - Prayer Hub Section
//
// The "Prayer" tab of a group hub. Hosts three things: a compose entry point,
// the SRS review deck (pray for *others*), and the member's own requests with
// live response tallies. Composing bumps `reloadToken`, which restarts both the
// deck and the requests list so a new request appears immediately.

struct GroupPrayerHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    let group: GroupSummary

    @State private var showCompose = false
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(spacing: 20) {
            Button {
                HapticManager.shared.buttonTap()
                showCompose = true
            } label: {
                Label("Share a prayer request", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.reforgedGold)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)

            sectionHeader("Pray for your group")
            GroupPrayerReviewView(group: group, reloadToken: reloadToken)

            Divider().padding(.horizontal, 16)

            sectionHeader("Your requests")
            MyPrayerRequestsView(group: group, reloadToken: reloadToken)
                .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showCompose) {
            ComposePrayerSheet(group: group) { reloadToken = UUID() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption).fontWeight(.bold)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
}

// MARK: - Compose a Prayer Request

struct ComposePrayerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let group: GroupSummary
    /// Called after a successful submit so the hub can refresh.
    let onSubmitted: () -> Void

    @State private var text = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private let maxChars = 500
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { !trimmed.isEmpty && trimmed.count <= maxChars && !isSubmitting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Share what you'd like your group to pray for. Only members of \(group.name) can see this.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Your prayer request…")
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                                .padding(.top, 10).padding(.leading, 6)
                        }
                        TextEditor(text: $text)
                            .frame(minHeight: 150)
                            .focused($focused)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    .padding(8)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )

                    HStack {
                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(Color.reforgedCoral)
                        }
                        Spacer()
                        Text("\(trimmed.count)/\(maxChars)")
                            .font(.caption)
                            .foregroundStyle(trimmed.count > maxChars ? Color.reforgedCoral
                                                                      : Color.adaptiveTextSecondary(colorScheme))
                    }

                    Text("Please don't include full names, contact details, or private information about someone else.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(20)
            }
            .navigationTitle("New Prayer Request")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().tint(Color.reforgedGold)
                    } else {
                        Button("Share") { Task { await submit() } }
                            .disabled(!canSubmit)
                    }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await GroupsService.shared.submitPrayer(groupId: group.id, text: trimmed)
            HapticManager.shared.success()
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = (error as? GroupsError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Your Requests (author view with response tallies)

struct MyPrayerRequestsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let group: GroupSummary
    let reloadToken: UUID

    @State private var requests: [GroupPrayer] = []
    @State private var tallies: [String: [PrayerResponseKind: Int]] = [:]
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView().tint(Color.reforgedGold).padding(.vertical, 12)
            } else if let loadError {
                Text(loadError)
                    .font(.caption).foregroundStyle(Color.reforgedCoral)
                    .frame(maxWidth: .infinity)
            } else if requests.isEmpty {
                Text("You haven't shared a request yet. When you do, you'll see who's praying for you here.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(requests) { req in
                    MyPrayerRequestCard(prayer: req, tally: tallies[req.id] ?? [:]) {
                        await delete(req)
                    }
                }
            }
        }
        .task(id: reloadToken) { await load() }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            let reqs = try await GroupsService.shared.myPrayerRequests(groupId: group.id)
            requests = reqs
            // Best-effort tallies; a failure just leaves a request's counts at zero.
            var collected: [String: [PrayerResponseKind: Int]] = [:]
            for r in reqs {
                collected[r.id] = (try? await GroupsService.shared.responseTally(prayerId: r.id)) ?? [:]
            }
            tallies = collected
        } catch {
            loadError = (error as? GroupsError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func delete(_ req: GroupPrayer) async {
        do {
            try await GroupsService.shared.deletePrayer(id: req.id)
            requests.removeAll { $0.id == req.id }
            HapticManager.shared.success()
        } catch {
            loadError = "Couldn't remove that request. Please try again."
        }
    }
}

private struct MyPrayerRequestCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let prayer: GroupPrayer
    let tally: [PrayerResponseKind: Int]
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    private var prayedCount: Int { tally[.prayed] ?? 0 }
    private var hasAnyResponse: Bool { tally.values.reduce(0, +) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(prayer.text)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Menu {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete request", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }

            if hasAnyResponse {
                HStack(spacing: 14) {
                    if prayedCount > 0 {
                        Label("\(prayedCount) prayed", systemImage: "hands.and.sparkles.fill")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                    }
                    ForEach(PrayerResponseKind.encouragements) { kind in
                        let count = tally[kind] ?? 0
                        if count > 0 {
                            Text("\(kind.emoji) \(count)")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                    }
                }
            } else {
                Text("No responses yet")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("Delete this prayer request?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await onDelete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed for everyone in the group.")
        }
    }
}
