import Foundation
import SwiftUI
import UIKit
import Combine
import CryptoKit
import Contacts
import Network

// MARK: - Models

/// One friend as returned by `get_friends_activity()`. Metric fields are nil
/// unless that friend opted in to sharing them; the server enforces this.
struct FriendActivity: Codable, Identifiable, Equatable {
    let friendId: String
    let displayName: String
    let avatarPath: String?
    let currentStreak: Int?
    let readToday: Bool?
    let chaptersThisWeek: Int?
    let versesMemorized: Int?
    let isMuted: Bool

    var id: String { friendId }

    enum CodingKeys: String, CodingKey {
        case friendId         = "friend_id"
        case displayName      = "display_name"
        case avatarPath       = "avatar_path"
        case currentStreak    = "current_streak"
        case readToday        = "read_today"
        case chaptersThisWeek = "chapters_this_week"
        case versesMemorized  = "verses_memorized"
        case isMuted          = "is_muted"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friendId         = try c.decode(String.self, forKey: .friendId)
        displayName      = (try? c.decode(String.self, forKey: .displayName)) ?? "Friend"
        avatarPath       = try? c.decodeIfPresent(String.self, forKey: .avatarPath)
        currentStreak    = try? c.decodeIfPresent(Int.self, forKey: .currentStreak)
        readToday        = try? c.decodeIfPresent(Bool.self, forKey: .readToday)
        chaptersThisWeek = try? c.decodeIfPresent(Int.self, forKey: .chaptersThisWeek)
        versesMemorized  = try? c.decodeIfPresent(Int.self, forKey: .versesMemorized)
        isMuted          = (try? c.decode(Bool.self, forKey: .isMuted)) ?? false
    }

    /// True when the friend shares nothing, so the row can say so plainly.
    var sharesNothing: Bool {
        currentStreak == nil && readToday == nil && chaptersThisWeek == nil && versesMemorized == nil
    }
}

/// The caller's own sharing choices. Everything is off until the user opts in.
struct FriendSharingPrefs: Codable, Equatable {
    var shareStreak = false
    var shareWeeklyChapters = false
    var shareVersesMemorized = false
    var allowNudges = false

    var sharesAnything: Bool { shareStreak || shareWeeklyChapters || shareVersesMemorized }

    enum CodingKeys: String, CodingKey {
        case shareStreak          = "share_streak"
        case shareWeeklyChapters  = "share_weekly_chapters"
        case shareVersesMemorized = "share_verses_memorized"
        case allowNudges          = "allow_nudges"
    }
}

/// Closed set of encouragements. Copy lives on the server; the client only
/// ever sends the kind, never free text.
enum FriendNudgeKind: String, CaseIterable, Identifiable {
    case encourage
    case praying
    case readReminder = "read_reminder"
    case celebrate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .encourage:    return "Cheer them on"
        case .praying:      return "Let them know you're praying"
        case .readReminder: return "Nudge to read today"
        case .celebrate:    return "Celebrate their streak"
        }
    }

    var icon: String {
        switch self {
        case .encourage:    return "hands.clap.fill"
        case .praying:      return "hands.sparkles.fill"
        case .readReminder: return "book.fill"
        case .celebrate:    return "flame.fill"
        }
    }
}

struct FriendMatch: Decodable, Identifiable, Equatable {
    let userId: String
    let displayName: String
    var id: String { userId }
    enum CodingKeys: String, CodingKey { case userId = "user_id", displayName = "display_name" }
}

struct FriendRequest: Codable, Identifiable, Equatable {
    let id: String
    let fromUser: String
    let displayName: String
    enum CodingKeys: String, CodingKey { case id, fromUser = "from_user", displayName = "display_name" }
}

/// What the notification server did with a nudge request.
enum NudgeOutcome {
    case delivered
    case noDevice     // the recipient has no registered push token
    case dropped      // held back by a cap or mute (deliberately not specific)
    case rejected     // Apple refused every device token

    /// Plain-language reason shown to the sender, or nil when it was delivered.
    func failureMessage(for name: String) -> String? {
        switch self {
        case .delivered: return nil
        case .noDevice:  return "\(name)'s phone isn't registered for notifications yet. Ask them to open Reforged once."
        case .dropped:   return "That wasn't delivered. \(name) may have reached today's limit."
        case .rejected:  return "Couldn't reach \(name)'s device right now. Try again in a bit."
        }
    }
}

// MARK: - Connectivity

extension Error {
    /// True when the work was simply cancelled (a view went away, a task was replaced).
    /// Never a real failure, so callers should drop it without flagging offline or an error.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if (self as? URLError)?.code == .cancelled { return true }
        if let friends = self as? FriendsError {
            switch friends {
            case .cancelled: return true
            case .transport(let inner): return inner.isCancellation
            default: return false
            }
        }
        return false
    }

    /// True for "no network" style failures (and cancellations), which background
    /// refreshes should absorb quietly instead of showing as errors.
    var isConnectivityError: Bool {
        if let friends = self as? FriendsError {
            switch friends {
            case .transport(let inner): return inner.isConnectivityError
            case .cancelled: return true
            default: return false
            }
        }
        if self is CancellationError { return true }
        if let url = self as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                    .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
                    .cancelled].contains(url.code)
        }
        return false
    }
}

/// Connectivity as the Friends tab sees it.
///  - `isOffline`: the last refresh failed for lack of a connection (or timed out).
///  - `hasNetwork`: the system reports a usable network path right now. Lets the UI say
///    "You're offline" when that's true and "Can't reach Reforged" when it's a slow or failing server.
@MainActor
final class ConnectivityState: ObservableObject {
    static let shared = ConnectivityState()
    @Published var isOffline = false
    @Published private(set) var hasNetwork = true

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.hasNetwork = satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "reforged.connectivity"))
    }
}

// MARK: - Errors

enum FriendsError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case ageRequired
    case cancelled
    case notAllowed
    case invalidInvite
    case tooManyInvites
    case friendLimit
    case rateLimited
    case nudgesOff
    case notDelivered
    case emailUnverified
    case relayEmail
    case tooMany
    case notAvailable
    case server(String?)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:    return "Friends isn't configured for this build."
        case .notAuthenticated: return "Sign in to use Friends."
        case .ageRequired:      return "Confirm your age first. Friends is for ages 13 and up."
        case .cancelled:        return FriendsError.cancelledMarker
        case .notAllowed:       return "You can't connect with this person."
        case .invalidInvite:    return "That invite code isn't valid or has expired."
        case .tooManyInvites:   return "You have too many open invites. Use or wait for an existing one to expire."
        case .friendLimit:      return "You've reached the friend limit."
        case .rateLimited:      return "You've already sent that today (or hit the daily limit). Try again tomorrow."
        case .nudgesOff:        return "This friend isn't accepting nudges."
        case .notDelivered:     return "They can't receive this right now. They may have encouragement turned off, or have muted you."
        case .emailUnverified:  return "Verify your email address before turning this on."
        case .relayEmail:       return "Your email is hidden by Sign in with Apple, so contacts can't match it."
        case .tooMany:          return "That's too many contacts to check at once."
        case .notAvailable:     return "That person isn't available."
        case .server(let m):    return m ?? "Something went wrong. Please try again."
        case .transport(let e): return e.localizedDescription
        }
    }

    /// Stores drop any message equal to this (a cancelled request isn't an error).
    static let cancelledMarker = "__cancelled__"

    static func isCancellation(_ message: String?) -> Bool {
        guard let m = message?.lowercased() else { return false }
        return m == cancelledMarker || m == "cancelled" || m == "canceled"
    }

    /// Maps the raw error codes the backend functions raise.
    static func from(message: String?) -> FriendsError {
        let m = (message ?? "").lowercased()
        if m.contains("age_required")    { return .ageRequired }
        if m.contains("not_allowed")     { return .notAllowed }
        if m.contains("invalid_invite")  { return .invalidInvite }
        if m.contains("too_many_invites") { return .tooManyInvites }
        if m.contains("friend_limit")    { return .friendLimit }
        if m.contains("rate_limited")    { return .rateLimited }
        if m.contains("nudges_off")      { return .nudgesOff }
        if m.contains("email_unverified") { return .emailUnverified }
        if m.contains("relay_email")     { return .relayEmail }
        if m.contains("too_many") && !m.contains("invites") { return .tooMany }
        if m.contains("not_available")   { return .notAvailable }
        return .server(nil)
    }
}

// MARK: - FriendsService (network)

@MainActor
final class FriendsService {
    static let shared = FriendsService()
    private init() {}

    /// A bad connection should fail fast into the offline state instead of leaving the tab
    /// spinning for URLSession's default 60 seconds. `timeoutIntervalForRequest` is the idle
    /// gap between packets; `timeoutIntervalForResource` caps the whole request.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private var baseURL: String { SettingsManager.shared.supabaseProjectURL?.absoluteString ?? "" }
    private var anonKey: String { SettingsManager.shared.supabaseAnonKey }

    @discardableResult
    func send(path: String,
                      method: String = "POST",
                      query: String = "",
                      body: [String: Any]? = nil) async throws -> (Data, Int) {
        guard !baseURL.isEmpty, !anonKey.isEmpty else { throw FriendsError.notConfigured }
        guard let token = await SupabaseAuthService.shared.validAccessToken() else {
            // A failed token refresh keeps the session (only a definitive rejection signs the
            // user out), so a still-signed-in user here means the refresh couldn't connect.
            // That's a connectivity problem, not "sign in again".
            if SupabaseAuthService.shared.isSignedIn { throw FriendsError.transport(URLError(.timedOut)) }
            throw FriendsError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)\(path)\(query)") else { throw FriendsError.notConfigured }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError { throw FriendsError.cancelled }
            throw FriendsError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw FriendsError.server(nil) }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            debugLog("\(path) failed: HTTP \(http.statusCode) \(message ?? "")")
            let mapped = FriendsError.from(message: message)
            // The notification function returns deliberately generic errors, so fall
            // back to the HTTP status to say something useful.
            if path.hasPrefix("/functions/") {
                // Notification errors read better in notification terms ("can't connect with
                // this person" makes no sense for a reminder).
                if case .notAllowed = mapped { throw FriendsError.notDelivered }
                if case .server = mapped {
                    if http.statusCode == 429 { throw FriendsError.rateLimited }
                    if http.statusCode == 403 { throw FriendsError.notDelivered }
                }
            }
            throw mapped
        }
        return (data, http.statusCode)
    }

    @discardableResult
    func rpc(_ name: String, _ params: [String: Any] = [:]) async throws -> Data {
        try await send(path: "/rest/v1/rpc/\(name)", body: params).0
    }

    private func scalarString(_ data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String
    }

    // MARK: Invites and friendships

    func createInvite() async throws -> String {
        let data = try await rpc("create_friend_invite")
        guard let code = scalarString(data) else { throw FriendsError.server(nil) }
        return code
    }

    func redeemInvite(_ code: String) async throws {
        try await rpc("redeem_friend_invite", ["_code": code.trimmingCharacters(in: .whitespaces).uppercased()])
    }

    func removeFriend(_ id: String) async throws {
        try await rpc("remove_friend", ["_friend_id": id])
    }

    func muteFriend(_ id: String, muted: Bool) async throws {
        try await rpc("mute_friend", ["_friend_id": id, "_muted": muted])
    }

    func friends() async throws -> [FriendActivity] {
        let data = try await rpc("get_friends_activity")
        return (try? JSONDecoder().decode([FriendActivity].self, from: data)) ?? []
    }

    // MARK: Sharing

    func loadPrefs() async throws -> FriendSharingPrefs {
        guard let uid = SupabaseAuthService.shared.userId else { throw FriendsError.notAuthenticated }
        let (data, _) = try await send(path: "/rest/v1/friend_sharing_prefs", method: "GET",
                                       query: "?user_id=eq.\(uid)&select=*")
        let rows = (try? JSONDecoder().decode([FriendSharingPrefs].self, from: data)) ?? []
        return rows.first ?? FriendSharingPrefs()
    }

    func savePrefs(_ p: FriendSharingPrefs, consentVersion: String) async throws {
        try await rpc("set_friend_sharing", [
            "_streak": p.shareStreak,
            "_chapters": p.shareWeeklyChapters,
            "_verses": p.shareVersesMemorized,
            "_allow_nudges": p.allowNudges,
            "_consent_version": consentVersion
        ])
    }

    func upsertActivity(streak: Int, readToday: Bool, chaptersThisWeek: Int,
                        versesMemorized: Int, weekStart: String) async throws {
        try await rpc("upsert_my_activity", [
            "_streak": streak,
            "_read_today": readToday,
            "_chapters_week": chaptersThisWeek,
            "_verses_memorized": versesMemorized,
            "_week_start": weekStart
        ])
    }

    // MARK: Push tokens and nudges

    func registerPushToken(_ token: String, environment: String) async throws {
        try await rpc("register_push_token", ["_token": token, "_environment": environment])
    }

    func unregisterPushToken(_ token: String) async throws {
        try await rpc("unregister_push_token", ["_token": token])
    }

    /// Nudge tied to a shared verse (`verse_request`, `verse_quiz`, `verse_nudge`,
    /// `verse_celebrate`). The server reads the reference from its own row.
    func sendVerseNudge(to friendId: String, kind: String, sharedVerseId: String) async throws -> NudgeOutcome {
        try await postNudge(["recipient_id": friendId, "kind": kind, "shared_verse_id": sharedVerseId])
    }

    /// Read Together push (`reading_request`, `reading_nudge`, `reading_celebrate`).
    func sendReadingNudge(to friendId: String, kind: String, sharedReadingId: String) async throws -> NudgeOutcome {
        try await postNudge(["recipient_id": friendId, "kind": kind, "shared_reading_id": sharedReadingId])
    }

    /// Quiz result / reaction push. The server reads score, reference and reaction itself.
    func sendQuizNudge(to friendId: String, kind: String, quizId: String) async throws -> NudgeOutcome {
        try await postNudge(["recipient_id": friendId, "kind": kind, "quiz_id": quizId])
    }

    func sendNudge(to friendId: String, kind: FriendNudgeKind) async throws -> NudgeOutcome {
        try await postNudge(["recipient_id": friendId, "kind": kind.rawValue])
    }

    /// Posts to the notification function. `.noDevice` means the server accepted the
    /// request but had no push token to deliver to (the friend hasn't enabled
    /// notifications, or their phone never registered).
    private func postNudge(_ body: [String: Any]) async throws -> NudgeOutcome {
        let (data, _) = try await send(path: "/functions/v1/send-friend-nudge", body: body)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let sent = json["sent"] as? Int
        let attempted = json["attempted"] as? Int
        if (json["dropped"] as? Bool) == true { return .dropped }
        if (sent ?? 1) > 0 { return .delivered }
        if let attempted, attempted > 0 { return .rejected }   // had tokens, Apple refused them
        return .noDevice
    }

    // MARK: Discovery (opt-in, email, 18+)

    func setDiscoverable(_ on: Bool) async throws {
        try await rpc("set_discoverable", ["_enabled": on])
    }

    func myDiscoverability() async throws -> Bool {
        let data = try await rpc("get_my_discoverability")
        return ((try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? Bool) ?? false
    }

    func findFriends(hashes: [String]) async throws -> [FriendMatch] {
        let data = try await rpc("find_friends_by_hashes", ["_hashes": hashes])
        return (try? JSONDecoder().decode([FriendMatch].self, from: data)) ?? []
    }

    func sendFriendRequest(to id: String) async throws {
        try await rpc("send_friend_request", ["_to": id])
    }

    func friendRequests() async throws -> [FriendRequest] {
        let data = try await rpc("get_friend_requests")
        return (try? JSONDecoder().decode([FriendRequest].self, from: data)) ?? []
    }

    func respond(toRequest id: String, accept: Bool) async throws {
        try await rpc("respond_friend_request", ["_id": id, "_accept": accept])
    }

    func deleteMyFriendData() async throws {
        try await rpc("delete_my_friend_data")
    }
}

// MARK: - Disk cache

/// Last-known Friends data, kept per account so the tab can paint instantly on launch and
/// refresh quietly behind it (stale-while-revalidate). Only written after a successful load.
enum FriendsDiskCache {
    private static func key(_ name: String, _ uid: String) -> String { "friends.cache.v1.\(name).\(uid)" }

    static func load<T: Decodable>(_ type: T.Type, name: String, uid: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key(name, uid)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, name: String, uid: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key(name, uid))
    }

    static func clear(name: String, uid: String) {
        UserDefaults.standard.removeObject(forKey: key(name, uid))
    }
}

/// The part of the Friends tab that is worth showing before the network answers.
private struct FriendsSnapshot: Codable {
    var friends: [FriendActivity]
    var requests: [FriendRequest]
    var prefs: FriendSharingPrefs
    var discoverable: Bool
}

// MARK: - FriendsStore (UI state)

@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    /// Bump when the consent wording changes so consent is re-recorded.
    static let consentVersion = "v1"

    @Published var friends: [FriendActivity] = [] { didSet { persistSnapshot() } }
    /// True once real data is on screen: a refresh has succeeded, or the last-known snapshot
    /// was restored from disk. Until then the UI shows a skeleton, never "no friends".
    @Published var hasLoadedOnce = false
    @Published var prefs = FriendSharingPrefs() { didSet { persistSnapshot() } }
    @Published var isLoading = false
    /// The very first load failed (offline, timed out, or a server error). Cleared on success
    /// or when the user retries. Only meaningful while `hasLoadedOnce` is false.
    @Published var loadFailed = false
    @Published var errorMessage: String? {
        didSet { if FriendsError.isCancellation(errorMessage) { errorMessage = nil } }
    }
    @Published var infoMessage: String?
    @Published var myInviteCode: String?
    @Published var discoverable = false { didSet { persistSnapshot() } }
    @Published var requests: [FriendRequest] = [] { didSet { persistSnapshot() } }
    @Published var matches: [FriendMatch] = []
    @Published var requestedIds: Set<String> = []
    @Published var isSearchingContacts = false
    @Published var contactSearchDone = false

    /// Set by the `reforged://friend?code=` deep link; FriendsView consumes it.
    @Published var pendingInviteCode: String?

    private let service = FriendsService.shared
    private var lastActivitySync: Date?

    private var cancellables = Set<AnyCancellable>()
    private var profilePushed = false
    /// Account the in-memory data belongs to, so a different sign-in never shows someone else's friends.
    private var hydratedUserId: String?

    private init() {
        hydrateFromCache()
        // Keep friends' view of me fresh: push aggregates shortly after streak,
        // reading or memory changes (debounced, and skipped unless sharing is on).
        let streak = ReadingStreakManager.shared.objectWillChange.map { _ in () }
        let verses = AppState.shared.$memoryVerses.map { _ in () }
        streak.merge(with: verses)
            .debounce(for: .seconds(8), scheduler: DispatchQueue.main)
            .sink { [weak self] in Task { @MainActor in await self?.syncActivity() } }
            .store(in: &cancellables)
    }

    var isSignedIn: Bool { SupabaseAuthService.shared.isSignedIn }
    var isAgeAllowed: Bool { AgeGateManager.shared.status == .allowed }

    /// Finding people by contacts is limited to adults (also enforced server-side).
    var isAdult: Bool {
        guard let dob = AgeGateManager.shared.storedBirthDate else { return false }
        return AgeGateManager.age(from: dob) >= 18
    }

    var inviteLink: URL? {
        guard let code = myInviteCode else { return nil }
        return URL(string: "https://reforgedapp.org/friend/\(code)")
    }

    func handleDeepLink(code: String) {
        pendingInviteCode = code.uppercased()
        NotificationCenter.default.post(name: .switchTab, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 7])
    }

    // MARK: Loading

    /// Restores the last successful snapshot for the signed-in account so the tab can paint
    /// real content on the first frame. Safe to call repeatedly; it only acts once per account.
    func hydrateFromCache() {
        guard let uid = SupabaseAuthService.shared.userId, hydratedUserId != uid else { return }
        if hydratedUserId != nil {
            // A different account signed in: never show the previous one's friends.
            hasLoadedOnce = false
            loadFailed = false
            friends = []
            requests = []
            prefs = FriendSharingPrefs()
            discoverable = false
        }
        hydratedUserId = uid
        guard let snap = FriendsDiskCache.load(FriendsSnapshot.self, name: "main", uid: uid) else { return }
        friends = snap.friends
        requests = snap.requests
        prefs = snap.prefs
        discoverable = snap.discoverable
        hasLoadedOnce = true
    }

    /// Debounced by nature (a handful of tiny values); skipped until real data exists so a
    /// half-loaded state is never written over a good snapshot.
    private func persistSnapshot() {
        guard hasLoadedOnce, let uid = SupabaseAuthService.shared.userId, hydratedUserId == uid else { return }
        FriendsDiskCache.save(
            FriendsSnapshot(friends: friends, requests: requests, prefs: prefs, discoverable: discoverable),
            name: "main", uid: uid)
    }

    /// Called by the Try again button so the skeleton returns while the retry runs.
    func beginRetry() { loadFailed = false }

    func refresh() async {
        guard isSignedIn, isAgeAllowed else { return }
        hydrateFromCache()
        await AgeGateManager.shared.syncPendingBirthDate()
        if !profilePushed {
            profilePushed = true
            if hasLoadedOnce {
                // Known account with data on screen: don't make the load wait on this.
                Task { await SupabaseAuthService.shared.upsertProfile(AppState.shared.user) }
            } else {
                await SupabaseAuthService.shared.upsertProfile(AppState.shared.user)
            }
        }
        isLoading = true
        defer { isLoading = false }
        do {
            // All four requests go out together; the slowest one sets the pace, not the sum.
            async let p = service.loadPrefs()
            async let f = service.friends()
            async let r = loadRequestsIfAdult()
            async let d = loadDiscoverabilityIfAdult()
            let newPrefs = try await p
            let newFriends = try await f
            let newRequests = await r
            let newDiscoverable = await d

            // Mark loaded first so the snapshot observers below are allowed to write.
            hasLoadedOnce = true
            loadFailed = false
            prefs = newPrefs
            friends = newFriends
            if let newRequests { requests = newRequests }
            if let newDiscoverable { discoverable = newDiscoverable }
            errorMessage = nil
            ConnectivityState.shared.isOffline = false
        } catch {
            if error.isCancellation { return }
            if !hasLoadedOnce { loadFailed = true }
            if error.isConnectivityError { ConnectivityState.shared.isOffline = true }
            else { errorMessage = error.localizedDescription }
        }
    }

    /// Optional pieces: a failure here keeps what's already shown instead of blanking it.
    private func loadRequestsIfAdult() async -> [FriendRequest]? {
        guard isAdult else { return nil }
        return try? await service.friendRequests()
    }

    private func loadDiscoverabilityIfAdult() async -> Bool? {
        guard isAdult else { return nil }
        return try? await service.myDiscoverability()
    }

    // MARK: Sharing

    /// Saves choices, syncs activity if anything is shared, and wires push for nudges.
    func updatePrefs(_ new: FriendSharingPrefs) async {
        let old = prefs
        prefs = new
        do {
            try await service.savePrefs(new, consentVersion: Self.consentVersion)
            if new.sharesAnything { await syncActivity(force: true) }
            if new.allowNudges != old.allowNudges { await applyNudgePreference(new.allowNudges) }
            errorMessage = nil
        } catch {
            prefs = old
            errorMessage = error.localizedDescription
        }
    }

    private func applyNudgePreference(_ on: Bool) async {
        if on {
            NotificationManager.shared.requestAuthorization()
            if let token = NotificationManager.shared.deviceToken { await registerToken(token) }
        } else if let token = NotificationManager.shared.deviceToken {
            try? await service.unregisterPushToken(token)
        }
    }

    // MARK: Activity sync (aggregates only)

    /// Pushes the user's current aggregates. No-op unless they opted in to share.
    func syncActivity(force: Bool = false) async {
        guard isSignedIn, isAgeAllowed, prefs.sharesAnything else { return }
        if !force, let last = lastActivitySync, Date().timeIntervalSince(last) < 300 { return }

        let streak = ReadingStreakManager.shared
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let chapters = streak.currentWeekDates().reduce(0) { $0 + streak.chaptersRead(on: $1).count }

        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"

        do {
            try await service.upsertActivity(
                streak: streak.currentStreak,
                readToday: streak.hasReadToday,
                chaptersThisWeek: chapters,
                versesMemorized: AppState.shared.memoryVerses.count,
                weekStart: f.string(from: weekStart))
            lastActivitySync = Date()
        } catch {
            debugLog("Friends activity sync failed: \(error.localizedDescription)")
            if force { errorMessage = "Couldn't share your activity: \(error.localizedDescription)" }
        }
    }

    /// Called when the app foregrounds: loads prefs, syncs aggregates, and keeps
    /// the push token registered if the user allows nudges.
    func syncOnForeground() async {
        guard isSignedIn, isAgeAllowed else { return }
        await AgeGateManager.shared.syncPendingBirthDate()
        if let p = try? await service.loadPrefs() { prefs = p }
        await syncActivity()
        await SharedVersesStore.shared.refresh()
        await SharedReadingsStore.shared.refresh()
        if prefs.allowNudges {
            // Ask iOS for the current token every launch; `deviceTokenReceived` then
            // uploads it. Without this the token was only ever sent in the session
            // where the toggle was switched on, so any later change was never picked up.
            NotificationManager.shared.refreshRemoteRegistrationIfAuthorized()
            if let token = NotificationManager.shared.deviceToken { await registerToken(token) }
        }
    }

    // MARK: Push token

    func deviceTokenReceived(_ token: String) {
        NSLog("[Push] deviceTokenReceived signedIn=%d allowNudges=%d", isSignedIn ? 1 : 0, prefs.allowNudges ? 1 : 0)
        guard isSignedIn, prefs.allowNudges else { return }
        Task { await registerToken(token) }
    }

    private func registerToken(_ token: String) async {
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        do {
            try await service.registerPushToken(token, environment: env)
            NSLog("[Push] token uploaded to server (%@)", env)
        } catch {
            NSLog("[Push] token upload FAILED: %@", error.localizedDescription)
        }
    }

    // MARK: Friend actions

    func createInvite() async {
        do {
            myInviteCode = try await service.createInvite()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Discovery

    func setDiscoverable(_ on: Bool) async {
        let old = discoverable
        discoverable = on
        do {
            try await service.setDiscoverable(on)
            if !on { matches = []; contactSearchDone = false }
            errorMessage = nil
        } catch {
            discoverable = old
            errorMessage = error.localizedDescription
        }
    }

    /// Reads emails from Contacts, hashes them on-device, and asks the server
    /// which opted-in members match. Only hashes leave the phone; the contact
    /// list itself is never stored or uploaded.
    func findFriendsInContacts() async {
        isSearchingContacts = true
        contactSearchDone = false
        defer { isSearchingContacts = false }

        let contactStore = CNContactStore()
        do {
            guard try await contactStore.requestAccess(for: .contacts) else {
                errorMessage = "Contacts access is off. You can allow it in Settings."
                return
            }
        } catch { errorMessage = error.localizedDescription; return }

        var hashes = Set<String>()
        let request = CNContactFetchRequest(keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
        try? contactStore.enumerateContacts(with: request) { contact, _ in
            for address in contact.emailAddresses {
                let email = (address.value as String).lowercased().trimmingCharacters(in: .whitespaces)
                guard email.contains("@") else { continue }
                let digest = SHA256.hash(data: Data(email.utf8))
                hashes.insert(digest.map { String(format: "%02x", $0) }.joined())
            }
        }

        // Server accepts 500 per call; cap at 4 calls per search.
        let all = Array(hashes.prefix(2000))
        var found: [FriendMatch] = []
        do {
            var i = 0
            while i < all.count {
                found += try await service.findFriends(hashes: Array(all[i..<min(i + 500, all.count)]))
                i += 500
            }
            var seen = Set<String>()
            matches = found.filter { seen.insert($0.userId).inserted }
            contactSearchDone = true
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func sendRequest(to match: FriendMatch) async {
        do {
            try await service.sendFriendRequest(to: match.userId)
            requestedIds.insert(match.userId)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        do {
            try await service.respond(toRequest: request.id, accept: accept)
            requests.removeAll { $0.id == request.id }
            if accept { infoMessage = "You're now friends with \(request.displayName)."; await refresh() }
        } catch { errorMessage = error.localizedDescription }
    }

    /// A fresh single-use code for one recipient (doesn't touch the shown invite).
    func newInviteCode() async -> String? {
        do {
            let code = try await service.createInvite()
            errorMessage = nil
            return code
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func redeem(_ code: String) async -> Bool {
        do {
            try await service.redeemInvite(code)
            infoMessage = "You're now friends!"
            errorMessage = nil
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func remove(_ friend: FriendActivity) async {
        do {
            try await service.removeFriend(friend.friendId)
            friends.removeAll { $0.friendId == friend.friendId }
        } catch { errorMessage = error.localizedDescription }
    }

    func block(_ friend: FriendActivity) async {
        do {
            try await GroupsService.shared.block(userId: friend.friendId)
            friends.removeAll { $0.friendId == friend.friendId }
            infoMessage = "\(friend.displayName) was blocked."
        } catch { errorMessage = error.localizedDescription }
    }

    func setMuted(_ friend: FriendActivity, muted: Bool) async {
        do {
            try await service.muteFriend(friend.friendId, muted: muted)
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func nudge(_ friend: FriendActivity, kind: FriendNudgeKind) async {
        do {
            let outcome = try await service.sendNudge(to: friend.friendId, kind: kind)
            if let problem = outcome.failureMessage(for: friend.displayName) {
                infoMessage = nil
                errorMessage = problem
            } else {
                errorMessage = nil
                infoMessage = "Sent to \(friend.displayName)."
            }
        } catch { infoMessage = nil; errorMessage = error.localizedDescription }
    }

    func deleteAllMyFriendData() async {
        do {
            try await service.deleteMyFriendData()
            friends = []
            requests = []
            prefs = FriendSharingPrefs()
            myInviteCode = nil
            SharedVersesStore.shared.clearCache()
            SharedReadingsStore.shared.clearCache()
            infoMessage = "Your Friends data was deleted."
        } catch { errorMessage = error.localizedDescription }
    }
}
