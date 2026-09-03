import Foundation

// MARK: - Groups Networking Errors

enum GroupsError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case badResponse(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)
    case notFound
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .notConfigured:    return "Groups isn't configured for this build."
        case .notAuthenticated: return "You need to be signed in to use Groups."
        case .badResponse(let status, let message):
            return message ?? "The server returned an error (status \(status))."
        case .decoding:         return "We couldn't read the response from the server."
        case .transport(let e): return e.localizedDescription
        case .notFound:         return "We couldn't find that."
        case .alreadyMember:    return "You're already a member of this group."
        }
    }
}

// MARK: - GroupsService
//
// REST client for the Groups tab. Deliberately mirrors the request conventions
// already used by `SupabaseAuthService` (apikey + bearer, PostgREST paths under
// `/rest/v1`) but keeps its own thin request builder so the two services stay
// decoupled. Auth tokens are always sourced from
// `SupabaseAuthService.shared.validAccessToken()`, which transparently refreshes.

@MainActor
final class GroupsService {
    static let shared = GroupsService()
    private init() {}

    // MARK: Configuration

    private var baseURL: String {
        SettingsManager.shared.supabaseProjectURL?.absoluteString ?? ""
    }
    private var anonKey: String { SettingsManager.shared.supabaseAnonKey }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Low-level Request

    /// Builds and sends an authenticated PostgREST request, returning the raw
    /// body for 2xx responses and throwing a typed `GroupsError` otherwise.
    @discardableResult
    private func send(path: String,
                      method: String,
                      query: String = "",
                      body: Data? = nil,
                      prefer: String? = nil,
                      requiresAuth: Bool = true) async throws -> Data {
        guard !baseURL.isEmpty, !anonKey.isEmpty else { throw GroupsError.notConfigured }

        var token: String? = nil
        if requiresAuth {
            token = await SupabaseAuthService.shared.validAccessToken()
            guard token != nil else { throw GroupsError.notAuthenticated }
        }

        guard let url = URL(string: "\(baseURL)\(path)\(query)") else {
            throw GroupsError.notConfigured
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw GroupsError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GroupsError.badResponse(status: -1, message: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            // PostgREST returns errors as {message, details, hint, code}
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw GroupsError.badResponse(status: http.statusCode, message: message)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw GroupsError.decoding(error) }
    }

    private func currentUserId() throws -> String {
        guard let uid = SupabaseAuthService.shared.userId else { throw GroupsError.notAuthenticated }
        return uid
    }

    // MARK: - Group Join (Requirements §2)

    /// Redeems a 6-character invite code and joins the caller to that group,
    /// returning the joined group.
    ///
    /// Backed by the backend RPC `join_group_by_code(_code)` (SECURITY DEFINER):
    /// it validates the code and inserts the membership server-side, so the
    /// `leader_groups` table stays members-only. Deliberately does NOT depend on
    /// that RPC's return payload (its shape is unverified): after joining, the
    /// authoritative group is fetched via the known-good `leader_groups(*)`
    /// embed on `group_members` and matched on `invite_code`. Re-joining an
    /// already-joined code is idempotent server-side and still resolves.
    ///
    /// Throws `GroupsError.notFound` when the code matches no group.
    func redeemInviteCode(_ code: String) async throws -> GroupSummary {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let bodyData = try JSONSerialization.data(withJSONObject: ["_code": normalized])

        // 1) Join via the server-side RPC. A bad/expired code surfaces as a
        //    function error, which we normalise to `.notFound`.
        do {
            _ = try await send(path: "/rest/v1/rpc/join_group_by_code",
                               method: "POST", body: bodyData, prefer: "return=minimal")
        } catch let GroupsError.badResponse(status, message) {
            let lower = (message ?? "").lowercased()
            let looksNotFound = status == 404
                || lower.contains("invalid") || lower.contains("not found")
                || lower.contains("no_data") || lower.contains("does not exist")
            if looksNotFound { throw GroupsError.notFound }
            throw GroupsError.badResponse(status: status, message: message)
        }

        // 2) Resolve the authoritative group through the verified embed, matched
        //    case-insensitively on the code we just redeemed.
        if let joined = try await myGroups().first(where: {
            $0.inviteCode.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            return joined
        }
        throw GroupsError.notFound
    }

    /// All groups the current user belongs to, via an embedded-resource select.
    /// The membership table embeds `leader_groups` (the real groups table on this
    /// backend); `group_members.group_id` FKs to `leader_groups.id`.
    func myGroups() async throws -> [GroupSummary] {
        let uid = try currentUserId()
        let query = "?user_id=eq.\(uid)&select=leader_groups(*)"
        let data = try await send(path: "/rest/v1/group_members", method: "GET", query: query)
        return try decode([MembershipWithGroup].self, from: data).compactMap { $0.group }
    }

    // MARK: - Tracks

    /// The most recently published track for a group (the "active" track).
    /// Backed by `leader_tracks` (columns id/group_id/title/published_at match
    /// `GroupTrack`).
    func activeTrack(groupId: String) async throws -> GroupTrack? {
        let query = "?group_id=eq.\(groupId)&published_at=not.is.null&order=published_at.desc&limit=1"
        let data = try await send(path: "/rest/v1/leader_tracks", method: "GET", query: query)
        return try decode([GroupTrack].self, from: data).first
    }

    func items(trackId: String) async throws -> [GroupTrackItem] {
        let query = "?track_id=eq.\(trackId)&select=*&order=id.asc"
        let data = try await send(path: "/rest/v1/track_items", method: "GET", query: query)
        return try decode([GroupTrackItem].self, from: data)
    }

    /// Ids of items the current user has already completed in a group, so the
    /// hub can show accurate checkmarks and progress after a relaunch.
    func completedItemIds(groupId: String) async throws -> Set<String> {
        let uid = try currentUserId()
        let query = "?user_id=eq.\(uid)&group_id=eq.\(groupId)&select=item_id"
        let data = try await send(path: "/rest/v1/progress_logs", method: "GET", query: query)
        struct Row: Decodable { let itemId: String
            enum CodingKeys: String, CodingKey { case itemId = "item_id" } }
        return Set(try decode([Row].self, from: data).map { $0.itemId })
    }

    /// Records completion of a track item. Idempotent server-side via a unique
    /// (user_id, item_id) index; a duplicate is swallowed as success.
    func logProgress(groupId: String, itemId: String) async throws {
        let uid = try currentUserId()
        let insert = ProgressLogInsert(userId: uid, groupId: groupId, itemId: itemId,
                                       completedAt: ISO8601DateFormatter().string(from: Date()))
        let bodyData = try JSONEncoder().encode(insert)
        do {
            try await send(path: "/rest/v1/progress_logs", method: "POST",
                           body: bodyData, prefer: "return=minimal")
        } catch let GroupsError.badResponse(status, _) where status == 409 {
            return // already logged today — fine
        }
    }

    /// Removes the current user's completion of an item (un-check). Requires a
    /// `user_id = auth.uid()` DELETE policy on progress_logs.
    func uncompleteItem(itemId: String) async throws {
        let uid = try currentUserId()
        try await send(path: "/rest/v1/progress_logs", method: "DELETE",
                       query: "?user_id=eq.\(uid)&item_id=eq.\(itemId)", prefer: "return=minimal")
    }

    // MARK: - Members

    /// Roster of a group, assembled in two steps (no `group_members`→`profiles`
    /// FK exists): membership user-ids, then their profile display fields.
    /// Members whose profile isn't readable degrade to a generic placeholder so
    /// the list still renders.
    func members(groupId: String) async throws -> [GroupMemberProfile] {
        let mData = try await send(path: "/rest/v1/group_members",
                                   method: "GET", query: "?group_id=eq.\(groupId)&select=user_id")
        struct MRow: Decodable { let userId: String
            enum CodingKeys: String, CodingKey { case userId = "user_id" } }
        let userIds = try decode([MRow].self, from: mData).map { $0.userId }
        guard !userIds.isEmpty else { return [] }

        // Best-effort profile hydration. Fields are optional so one NULL column
        // can't fail the whole decode (which would blank every name/avatar).
        var profiles: [String: (name: String, avatar: String)] = [:]
        let list = userIds.joined(separator: ",")
        if let pData = try? await send(path: "/rest/v1/profiles",
                                       method: "GET",
                                       query: "?user_id=in.(\(list))&select=user_id,display_name,avatar") {
            struct PRow: Decodable { let userId: String; let displayName: String?; let avatar: String?
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"; case displayName = "display_name"; case avatar } }
            for p in (try? decode([PRow].self, from: pData)) ?? [] {
                profiles[p.userId] = (p.displayName ?? "", p.avatar ?? "")
            }
        }

        // The current user's own display data is always known locally, so use it
        // even if the remote profile read is empty or blocked by RLS.
        let me = SupabaseAuthService.shared.userId
        let localUser = AppState.shared.user

        return userIds.map { uid in
            let remote = profiles[uid]
            let isMe = uid == me

            var name = remote?.name ?? ""
            var avatar = remote?.avatar ?? ""
            if isMe {
                if name.isEmpty { name = localUser.displayName }
                if avatar.isEmpty { avatar = localUser.avatar }
            }
            if name.isEmpty { name = "Member" }
            if avatar.isEmpty { avatar = "🙂" }

            return GroupMemberProfile(userId: uid,
                                      displayName: isMe ? "\(name) (You)" : name,
                                      avatar: avatar)
        }.sorted { ($0.userId == me ? 0 : 1, $0.displayName) < ($1.userId == me ? 0 : 1, $1.displayName) }
    }

    /// Removes the current user from a group (direct DELETE on their own
    /// membership row; requires a `user_id = auth.uid()` DELETE policy).
    func leaveGroup(groupId: String) async throws {
        let uid = try currentUserId()
        try await send(path: "/rest/v1/group_members",
                       method: "DELETE",
                       query: "?group_id=eq.\(groupId)&user_id=eq.\(uid)",
                       prefer: "return=minimal")
    }

    // MARK: - Handouts

    /// Published handouts for a group, newest first. Unpublished rows
    /// (`published_at IS NULL`) are excluded server-side so drafts never leak.
    func handouts(groupId: String) async throws -> [Handout] {
        let query = "?group_id=eq.\(groupId)&published_at=not.is.null&select=*&order=created_at.desc"
        let data = try await send(path: "/rest/v1/handouts", method: "GET", query: query)
        return try decode([Handout].self, from: data)
    }

    /// Creates a short-lived signed URL for a private storage object. Sent with
    /// the user's JWT so storage RLS (member-of-the-handout's-group) is enforced.
    /// `path` is the raw `storage_path` (e.g. `{group_id}/{uuid}-{filename}`);
    /// each segment is percent-encoded so spaces in filenames don't break the URL.
    func signedURL(bucket: String, path: String, expiresIn: Int = 3600) async throws -> URL {
        let encodedPath = path.split(separator: "/", omittingEmptySubsequences: false).map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")

        let bodyData = try JSONSerialization.data(withJSONObject: ["expiresIn": expiresIn])
        let data = try await send(path: "/storage/v1/object/sign/\(bucket)/\(encodedPath)",
                                  method: "POST", body: bodyData)

        struct SignResponse: Decodable { let signedURL: String }
        let signed = try decode(SignResponse.self, from: data)

        guard let base = SettingsManager.shared.supabaseProjectURL else { throw GroupsError.notConfigured }
        // `signedURL` is returned relative, e.g. "/object/sign/<bucket>/<path>?token=…"
        guard let url = URL(string: base.absoluteString + "/storage/v1" + signed.signedURL) else {
            throw GroupsError.notFound
        }
        return url
    }

    // MARK: - Moderation (Requirements §3 / Guideline 1.2)

    /// The set of user ids the current user has blocked. Cached by
    /// `BlockListStore`; call that instead of this from the UI.
    func blockedUserIds() async throws -> Set<String> {
        let uid = try currentUserId()
        let query = "?blocker_id=eq.\(uid)&select=blocked_id"
        let data = try await send(path: "/rest/v1/user_blocks", method: "GET", query: query)
        struct Row: Decodable { let blockedId: String
            enum CodingKeys: String, CodingKey { case blockedId = "blocked_id" } }
        return Set(try decode([Row].self, from: data).map { $0.blockedId })
    }

    func report(contentType: ReportableContentType, contentId: String, reason: String) async throws {
        let uid = try currentUserId()
        let insert = ContentReportInsert(reporterId: uid,
                                         contentType: contentType.rawValue,
                                         contentId: contentId,
                                         reason: reason)
        let bodyData = try JSONEncoder().encode(insert)
        try await send(path: "/rest/v1/content_reports", method: "POST",
                       body: bodyData, prefer: "return=minimal")
    }

    func block(userId blockedId: String) async throws {
        let uid = try currentUserId()
        let insert = UserBlockInsert(blockerId: uid, blockedId: blockedId)
        let bodyData = try JSONEncoder().encode(insert)
        do {
            try await send(path: "/rest/v1/user_blocks", method: "POST",
                           body: bodyData, prefer: "return=minimal")
        } catch let GroupsError.badResponse(status, _) where status == 409 {
            return // already blocked
        }
    }

    // MARK: - Feed (ASSUMED TABLE: reflections)

    /// Group reflection feed with blocked authors filtered *server-side* via a
    /// PostgREST `not.in` clause, so hidden content never crosses the network.
    func feed(groupId: String, excluding blocked: Set<String>) async throws -> [GroupFeedPost] {
        var query = "?group_id=eq.\(groupId)&select=*&order=created_at.desc&limit=100"
        if !blocked.isEmpty {
            let list = blocked.joined(separator: ",")
            query += "&author_id=not.in.(\(list))"
        }
        let data = try await send(path: "/rest/v1/reflections", method: "GET", query: query)
        return try decode([GroupFeedPost].self, from: data)
    }

    // MARK: - Prayer (ASSUMED TABLE: prayer_requests) — Requirements §4

    /// Live, fetch-on-display read of a single prayer by id. Returns `nil` when
    /// the request no longer exists (author deleted it) OR the author is in the
    /// caller-supplied blocked set — both of which the SRS engine treats as a
    /// signal to purge the card. The returned value must NOT be persisted.
    func prayer(id: String, excluding blocked: Set<String>) async throws -> GroupPrayer? {
        let query = "?id=eq.\(id)&select=*&limit=1"
        let data = try await send(path: "/rest/v1/prayer_requests", method: "GET", query: query)
        guard let prayer = try decode([GroupPrayer].self, from: data).first else {
            return nil // deleted by author
        }
        if blocked.contains(prayer.authorId) { return nil } // author blocked
        return prayer
    }

    /// Fetches ONLY the ids of a group's active prayer requests to seed the SRS
    /// review queue. Text is deliberately excluded (`select=id`) so nothing but
    /// opaque identifiers is ever held in the queue; each card hydrates its text
    /// live at display time via `prayer(id:excluding:)`. The caller's own
    /// requests are excluded server-side (`author_id=neq`) — you review others'
    /// prayers, not your own.
    func prayerQueueIds(groupId: String) async throws -> [String] {
        let uid = try currentUserId()
        let query = "?group_id=eq.\(groupId)&author_id=neq.\(uid)&select=id&order=created_at.desc&limit=50"
        let data = try await send(path: "/rest/v1/prayer_requests", method: "GET", query: query)
        struct Row: Decodable { let id: String }
        return try decode([Row].self, from: data).map { $0.id }
    }

    /// Posts a new prayer request for the current user into the group. The
    /// author's display name is denormalised so co-members can attribute it.
    func submitPrayer(groupId: String, text: String) async throws {
        let uid = try currentUserId()
        let name = AppState.shared.user.displayName
        let insert = PrayerRequestInsert(groupId: groupId,
                                         authorId: uid,
                                         authorName: name.isEmpty ? nil : name,
                                         text: text)
        let bodyData = try JSONEncoder().encode(insert)
        try await send(path: "/rest/v1/prayer_requests", method: "POST",
                       body: bodyData, prefer: "return=minimal")
    }

    /// The current user's OWN prayer requests in a group, newest first — used by
    /// the "Your requests" view so the author can see who's responding. Unlike
    /// the SRS queue these carry text, but it stays transient view state (never
    /// written to disk), same as `prayer(id:excluding:)`.
    func myPrayerRequests(groupId: String) async throws -> [GroupPrayer] {
        let uid = try currentUserId()
        let query = "?group_id=eq.\(groupId)&author_id=eq.\(uid)&select=*&order=created_at.desc&limit=50"
        let data = try await send(path: "/rest/v1/prayer_requests", method: "GET", query: query)
        return try decode([GroupPrayer].self, from: data)
    }

    /// Deletes one of the current user's own prayer requests. Scoped to
    /// `author_id = auth.uid()` so RLS can only ever remove the caller's row.
    func deletePrayer(id: String) async throws {
        let uid = try currentUserId()
        try await send(path: "/rest/v1/prayer_requests", method: "DELETE",
                       query: "?id=eq.\(id)&author_id=eq.\(uid)", prefer: "return=minimal")
    }

    /// Records a response (prayed / a preset encouragement) to a request, so the
    /// author can be silently notified. ASSUMED TABLE `prayer_interactions`; no
    /// free text. Idempotent via a unique (prayer_id, user_id, kind) index — a
    /// duplicate 409 is swallowed as success.
    func respond(prayerId: String, kind: PrayerResponseKind) async throws {
        let uid = try currentUserId()
        let payload = ["prayer_id": prayerId, "user_id": uid, "kind": kind.rawValue]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        do {
            try await send(path: "/rest/v1/prayer_interactions", method: "POST",
                           body: bodyData, prefer: "return=minimal")
        } catch let GroupsError.badResponse(status, _) where status == 409 {
            return
        }
    }

    /// Convenience for the primary acknowledgement.
    func markPrayed(prayerId: String) async throws {
        try await respond(prayerId: prayerId, kind: .prayed)
    }

    /// Aggregates the responses to a single request by kind, for the author's
    /// "Your requests" tallies. Reads only the `kind` column (no user identities).
    func responseTally(prayerId: String) async throws -> [PrayerResponseKind: Int] {
        let query = "?prayer_id=eq.\(prayerId)&select=kind"
        let data = try await send(path: "/rest/v1/prayer_interactions", method: "GET", query: query)
        struct Row: Decodable { let kind: String }
        var tally: [PrayerResponseKind: Int] = [:]
        for row in try decode([Row].self, from: data) {
            if let k = PrayerResponseKind(rawValue: row.kind) { tally[k, default: 0] += 1 }
        }
        return tally
    }
}

// MARK: - Block List Store
//
// Small observable cache of the current user's block list so every feed/prayer
// query can filter locally *and* server-side without re-fetching each time. A
// block updates this synchronously (optimistic) for instant hiding, then the
// network call reconciles.

@MainActor
final class BlockListStore: ObservableObject {
    static let shared = BlockListStore()
    private init() {}

    @Published private(set) var blockedIds: Set<String> = []

    func refresh() async {
        blockedIds = (try? await GroupsService.shared.blockedUserIds()) ?? blockedIds
    }

    /// Optimistically hides a user, then persists. On failure the id is rolled
    /// back so the UI doesn't silently drop a block that didn't save.
    func block(userId: String) async throws {
        blockedIds.insert(userId)
        do {
            try await GroupsService.shared.block(userId: userId)
        } catch {
            blockedIds.remove(userId)
            throw error
        }
    }

    func isBlocked(_ userId: String) -> Bool { blockedIds.contains(userId) }
}
