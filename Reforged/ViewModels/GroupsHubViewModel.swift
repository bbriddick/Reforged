import Foundation
import Combine

// MARK: - Load State

enum GroupsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - GroupsHubViewModel
//
// Owns all hub state: the user's groups, the selected group, its published
// track items, today's progress, and the reflection feed. Every network call is
// funnelled through `GroupsService` and every failure is surfaced as a
// `GroupsLoadState.error` (top-level) or an inline flag (per-action), so no
// error is ever swallowed silently.

@MainActor
final class GroupsHubViewModel: ObservableObject {
    @Published private(set) var loadState: GroupsLoadState = .idle
    @Published private(set) var groups: [GroupSummary] = []
    @Published private(set) var selectedGroup: GroupSummary?

    @Published private(set) var trackItems: [GroupTrackItem] = []
    @Published private(set) var completedItemIds: Set<String> = []
    @Published var completionError: String?
    @Published private(set) var handouts: [Handout] = []
    @Published private(set) var members: [GroupMemberProfile] = []
    @Published private(set) var feed: [GroupFeedPost] = []

    private var didLoad = false

    // Derived "Pulse" numbers.
    var totalItems: Int { trackItems.count }
    var completedToday: Int { completedItemIds.count }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await load()
    }

    func load() async {
        loadState = .loading
        // Ensure this user's display name + avatar exist in Supabase `profiles`
        // so co-members can see them in the roster (fire-and-forget, idempotent).
        Task { await SupabaseAuthService.shared.upsertProfile(AppState.shared.user) }
        await BlockListStore.shared.refresh()
        do {
            let fetched = try await GroupsService.shared.myGroups()
            groups = fetched
            didLoad = true
            if let first = fetched.first {
                await select(first)
            }
            loadState = .loaded
        } catch {
            loadState = .error(message(for: error))
        }
    }

    // MARK: - Selection

    func select(_ group: GroupSummary) async {
        selectedGroup = group
        await loadGroupContent(group)
    }

    /// Redeems an invite code arriving from a deep link / QR scan and selects
    /// the joined group. Silently no-ops on failure (the user can still join
    /// manually); returns whether it succeeded.
    @discardableResult
    func redeem(inviteCode: String) async -> Bool {
        guard loadState == .loaded || loadState == .idle else { return false }
        do {
            let group = try await GroupsService.shared.redeemInviteCode(inviteCode)
            await selectAfterJoining(group)
            HapticManager.shared.success()
            return true
        } catch {
            return false
        }
    }

    /// Called after a successful join: refresh the group list, then select the
    /// freshly-joined group.
    func selectAfterJoining(_ group: GroupSummary) async {
        if !groups.contains(where: { $0.id == group.id }) {
            groups.append(group)
        }
        loadState = .loaded
        await select(group)
    }

    /// Reloads the selected group's track, handouts, and members (pull-to-refresh).
    func refreshCurrent() async {
        guard let group = selectedGroup else { return }
        await loadGroupContent(group)
    }

    private func loadGroupContent(_ group: GroupSummary) async {
        async let handoutTask = loadHandouts(group)
        async let trackTask = loadTrack(group)
        async let memberTask = loadMembers(group)
        _ = await (handoutTask, trackTask, memberTask)
    }

    // MARK: - Handouts

    private func loadHandouts(_ group: GroupSummary) async {
        // A handout failure shouldn't blank the whole hub; leave the list empty.
        handouts = (try? await GroupsService.shared.handouts(groupId: group.id)) ?? []
    }

    func refreshHandouts(group: GroupSummary) async {
        await loadHandouts(group)
    }

    // MARK: - Members

    private func loadMembers(_ group: GroupSummary) async {
        members = (try? await GroupsService.shared.members(groupId: group.id)) ?? []
    }

    /// Removes the current user from `group`, drops it from the local list, and
    /// reselects another group (or clears selection). Throws on failure so the
    /// view can show why (e.g. a missing DELETE policy).
    func leaveGroup(_ group: GroupSummary) async throws {
        try await GroupsService.shared.leaveGroup(groupId: group.id)
        groups.removeAll { $0.id == group.id }
        if selectedGroup?.id == group.id {
            selectedGroup = nil
            members = []; handouts = []; trackItems = []; completedItemIds = []
            if let next = groups.first { await select(next) }
        }
    }

    // MARK: - Track + Progress

    private func loadTrack(_ group: GroupSummary) async {
        do {
            guard let track = try await GroupsService.shared.activeTrack(groupId: group.id) else {
                trackItems = []
                completedItemIds = []
                return
            }
            trackItems = try await GroupsService.shared.items(trackId: track.id)
            completedItemIds = (try? await GroupsService.shared.completedItemIds(groupId: group.id)) ?? []
        } catch {
            // A track failure shouldn't blank the whole hub; leave items empty.
            trackItems = []
            completedItemIds = []
        }
    }

    /// Toggles completion of a track item (check ↔ uncheck), optimistically,
    /// rolling back and surfacing the reason on failure.
    func toggleComplete(item: GroupTrackItem, group: GroupSummary) async {
        completionError = nil
        let wasDone = completedItemIds.contains(item.id)
        if wasDone { completedItemIds.remove(item.id) } else { completedItemIds.insert(item.id) }
        do {
            if wasDone {
                try await GroupsService.shared.uncompleteItem(itemId: item.id)
            } else {
                try await GroupsService.shared.logProgress(groupId: group.id, itemId: item.id)
            }
        } catch {
            // Roll back and surface the cause (often a missing progress_logs
            // INSERT/DELETE RLS policy on the backend).
            if wasDone { completedItemIds.insert(item.id) } else { completedItemIds.remove(item.id) }
            completionError = message(for: error)
        }
    }

    // MARK: - Feed

    private func loadFeed(_ group: GroupSummary) async {
        do {
            feed = try await GroupsService.shared.feed(groupId: group.id,
                                                       excluding: BlockListStore.shared.blockedIds)
        } catch {
            feed = []
        }
    }

    func refreshFeed(group: GroupSummary) async {
        await BlockListStore.shared.refresh()
        await loadFeed(group)
    }

    // MARK: - Errors

    private func message(for error: Error) -> String {
        (error as? GroupsError)?.errorDescription ?? error.localizedDescription
    }
}
