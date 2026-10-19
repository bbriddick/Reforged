import Foundation
import SwiftUI

// MARK: - Model

/// A plan or passage two friends read together, as returned by `get_shared_readings`.
/// The server stores only a built-in plan ID or a passage reference plus counts.
struct SharedReading: Codable, Identifiable, Equatable {
    let id: String
    let friendId: String
    let friendName: String
    let kind: String            // "plan" or "passage"
    let planId: String?
    let reference: String?
    let totalDays: Int
    let status: String
    let createdByMe: Bool
    let myDays: Int?
    let friendDays: Int?
    let iReadToday: Bool
    let friendReadToday: Bool
    let pairStreak: Int
    let finishedTogether: Bool

    var isPlan: Bool { kind == "plan" }
    var isPending: Bool { status == "pending" }
    var isActive: Bool { status == "active" }
    var needsMyResponse: Bool { isPending && !createdByMe }

    enum CodingKeys: String, CodingKey {
        case id, kind, reference, status
        case friendId = "friend_id", friendName = "friend_name", planId = "plan_id"
        case totalDays = "total_days", createdByMe = "created_by_me"
        case myDays = "my_days", friendDays = "friend_days"
        case iReadToday = "i_read_today", friendReadToday = "friend_read_today"
        case pairStreak = "pair_streak", finishedTogether = "finished_together"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        friendId = try c.decode(String.self, forKey: .friendId)
        friendName = (try? c.decode(String.self, forKey: .friendName)) ?? "Friend"
        kind = try c.decode(String.self, forKey: .kind)
        planId = try? c.decodeIfPresent(String.self, forKey: .planId)
        reference = try? c.decodeIfPresent(String.self, forKey: .reference)
        totalDays = (try? c.decode(Int.self, forKey: .totalDays)) ?? 1
        status = try c.decode(String.self, forKey: .status)
        createdByMe = (try? c.decode(Bool.self, forKey: .createdByMe)) ?? false
        myDays = try? c.decodeIfPresent(Int.self, forKey: .myDays)
        friendDays = try? c.decodeIfPresent(Int.self, forKey: .friendDays)
        iReadToday = (try? c.decode(Bool.self, forKey: .iReadToday)) ?? false
        friendReadToday = (try? c.decode(Bool.self, forKey: .friendReadToday)) ?? false
        pairStreak = (try? c.decode(Int.self, forKey: .pairStreak)) ?? 0
        finishedTogether = (try? c.decode(Bool.self, forKey: .finishedTogether)) ?? false
    }
}

// MARK: - Service

@MainActor
final class SharedReadingsService {
    static let shared = SharedReadingsService()
    private init() {}
    private var api: FriendsService { FriendsService.shared }

    func list() async throws -> [SharedReading] {
        let data = try await api.rpc("get_shared_readings", ["_today": SharedVersesService.today])
        return (try? JSONDecoder().decode([SharedReading].self, from: data)) ?? []
    }

    func propose(friendId: String, kind: String, planId: String?, reference: String?, totalDays: Int) async throws -> String {
        var params: [String: Any] = ["_friend_id": friendId, "_kind": kind, "_total_days": totalDays]
        params["_plan_id"] = planId ?? NSNull()
        params["_reference"] = reference ?? NSNull()
        let data = try await api.rpc("propose_shared_reading", params)
        guard let id = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String
        else { throw FriendsError.server(nil) }
        return id
    }

    func respond(_ id: String, accept: Bool) async throws {
        try await api.rpc("respond_shared_reading", ["_id": id, "_accept": accept])
    }

    func end(_ id: String) async throws { try await api.rpc("end_shared_reading", ["_id": id]) }

    func report(id: String, days: Int, readToday: Bool, day: String? = nil) async throws {
        try await api.rpc("report_reading_progress", [
            "_id": id, "_days_completed": days, "_read_today": readToday, "_today": day ?? SharedVersesService.today])
    }

    @discardableResult
    func nudge(to friendId: String, kind: String, sharedReadingId: String) async -> Result<NudgeOutcome, Error> {
        do { return .success(try await api.sendReadingNudge(to: friendId, kind: kind, sharedReadingId: sharedReadingId)) }
        catch { debugLog("Reading nudge \(kind) failed: \(error.localizedDescription)"); return .failure(error) }
    }
}

// MARK: - Per-reading local progress
//
// A shared reading has its OWN progress, independent of the Reading Plans screen:
// it starts at Day 1 for both people the moment they start together, and only
// chapters read AFTER that count. This keeps a pair fair even if one of them has
// already read part of the plan before.

struct SharedReadingLocalState: Codable, Equatable {
    var chapters: Set<String> = []   // "Book N" keys read since starting together
    var days: Set<Int> = []          // plan days (or 1 for a passage) completed since then
    /// Local calendar day (yyyy-MM-dd) a plan day was last completed. A manual "Mark done"
    /// is allowed once per calendar day, so the plan can't be ticked through in one sitting.
    var lastCompletedOn: String?
}

// MARK: - Store

@MainActor
final class SharedReadingsStore: ObservableObject {
    static let shared = SharedReadingsStore()

    @Published var readings: [SharedReading] = [] { didSet { persistCache() } }
    @Published private(set) var local: [String: SharedReadingLocalState] = [:]
    @Published var errorMessage: String? {
        didSet { if FriendsError.isCancellation(errorMessage) { errorMessage = nil } }
    }
    @Published var infoMessage: String?

    private let service = SharedReadingsService.shared
    private let localKey = "sharedReadings.local"
    private let celebratedKey = "sharedReadings.celebrated"
    private var lastReported: [String: Int] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: localKey),
           let decoded = try? JSONDecoder().decode([String: SharedReadingLocalState].self, from: data) {
            local = decoded
        }
        hydrateFromCache()
    }

    // MARK: Last-known cache (shown instantly, refreshed behind it)

    private var cachedFor: String?
    /// Set once a network refresh has succeeded, so a half-loaded state never overwrites the cache.
    private var hasRefreshed = false

    private func hydrateFromCache() {
        guard let uid = SupabaseAuthService.shared.userId, cachedFor != uid else { return }
        cachedFor = uid
        if let cached = FriendsDiskCache.load([SharedReading].self, name: "readings", uid: uid) { readings = cached }
    }

    private func persistCache() {
        guard let uid = SupabaseAuthService.shared.userId, cachedFor == uid, hasRefreshed else { return }
        FriendsDiskCache.save(readings, name: "readings", uid: uid)
    }

    func clearCache() {
        readings = []
        if let uid = SupabaseAuthService.shared.userId { FriendsDiskCache.clear(name: "readings", uid: uid) }
    }

    private var canUse: Bool {
        SupabaseAuthService.shared.isSignedIn && AgeGateManager.shared.status == .allowed
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(local) { UserDefaults.standard.set(data, forKey: localKey) }
    }

    /// Starts tracking from zero if this reading has no local state yet.
    private func ensureLocal(_ id: String) {
        guard local[id] == nil else { return }
        local[id] = SharedReadingLocalState()
        saveLocal()
    }

    /// Built-in plans only: custom plans exist on one device, so they can't be shared.
    static var sharablePlans: [BibleReadingPlan] { BibleReadingPlans.all }

    func plan(for reading: SharedReading) -> BibleReadingPlan? {
        guard let id = reading.planId else { return nil }
        return BibleReadingPlans.all.first { $0.id == id }
    }

    func title(for reading: SharedReading) -> String {
        reading.isPlan ? (plan(for: reading)?.name ?? "Reading plan") : (reading.reference ?? "Passage")
    }

    // MARK: Progress

    /// Days I've completed since starting this reading together.
    func myDays(for reading: SharedReading) -> Int {
        min(local[reading.id]?.days.count ?? 0, reading.totalDays)
    }

    /// The next shared-plan day I haven't completed (1-based), or nil when finished.
    func nextDay(for reading: SharedReading) -> Int? {
        let done = local[reading.id]?.days ?? []
        return (1...max(reading.totalDays, 1)).first { !done.contains($0) }
    }

    /// Whether the manual "Mark done" is available right now. One manual tick per calendar day,
    /// and not on a day the reader already completed a day by actually reading it (the server's
    /// `iReadToday` covers reads made on another device).
    func canMarkDone(_ reading: SharedReading) -> Bool {
        guard nextDay(for: reading) != nil else { return false }
        if reading.iReadToday { return false }
        return local[reading.id]?.lastCompletedOn != SharedVersesService.today
    }

    func entry(for reading: SharedReading) -> BiblePlanEntry? {
        guard reading.isPlan, let plan = plan(for: reading), let day = nextDay(for: reading) else { return nil }
        return plan.entries.first { $0.day == day }
    }

    /// Chapter progress for the next day of a shared plan, e.g. "Genesis 1-2", 1 of 2 read.
    func nextDayProgress(for reading: SharedReading) -> (label: String, read: Int, total: Int)? {
        guard let entry = entry(for: reading) else { return nil }
        let required = entry.requiredChapters
        let chapters = local[reading.id]?.chapters ?? []
        let read = required.filter { chapters.contains("\($0.book) \($0.chapter)") }.count
        return (entry.scriptureReference, read, required.count)
    }

    func refresh() async {
        guard canUse else { return }
        hydrateFromCache()
        do {
            let fresh = try await service.list()
            hasRefreshed = true
            readings = fresh
            for r in readings where r.isActive { ensureLocal(r.id) }
            errorMessage = nil
            ConnectivityState.shared.isOffline = false
            await syncProgress()
            await celebrateIfNeeded()
        } catch {
            if error.isCancellation { return }
            if error.isConnectivityError { ConnectivityState.shared.isOffline = true }
            else { errorMessage = error.localizedDescription }
        }
    }

    private func syncProgress() async {
        await flushPendingMarks()
        for r in readings where r.isActive {
            let days = myDays(for: r)
            guard lastReported[r.id] != days else { continue }
            if (try? await service.report(id: r.id, days: days, readToday: false)) != nil {
                lastReported[r.id] = days
            }
        }
    }

    private func report(_ r: SharedReading, readToday: Bool) async {
        let days = myDays(for: r)
        let day = SharedVersesService.today
        if (try? await service.report(id: r.id, days: days, readToday: readToday, day: day)) != nil {
            lastReported[r.id] = days
        } else if readToday {
            // Offline or failed: remember today's reading and retry when we can.
            PendingDailyMarks.add(kind: "reading", id: r.id, day: day)
        }
    }

    /// Retries "read today" marks that couldn't be sent earlier, using their original day.
    private func flushPendingMarks() async {
        for mark in PendingDailyMarks.all(kind: "reading") {
            guard !PendingDailyMarks.isExpired(mark),
                  let r = readings.first(where: { $0.id == mark.id && $0.isActive }) else {
                PendingDailyMarks.remove(mark)   // expired, or the shared reading ended
                continue
            }
            let days = myDays(for: r)
            if (try? await service.report(id: r.id, days: days, readToday: true, day: mark.day)) != nil {
                PendingDailyMarks.remove(mark)
                lastReported[r.id] = days
            }
        }
    }

    /// Called by `ReadingPlanService.notifyChapterRead` whenever a chapter is marked
    /// read. Only chapters read from now on count toward shared plans.
    func chapterRead(book: String, chapter: Int) {
        guard canUse else { return }
        let key = "\(book) \(chapter)"
        var changed: [SharedReading] = []

        for r in readings where r.isActive && r.isPlan {
            guard let plan = plan(for: r) else { continue }
            var state = local[r.id] ?? SharedReadingLocalState()
            state.chapters.insert(key)
            var completedNow = false
            for entry in plan.entries where !state.days.contains(entry.day) && !entry.isReflectionDay {
                let required = entry.requiredChapters
                guard !required.isEmpty else { continue }   // verse ranges: mark done by hand
                if required.allSatisfy({ state.chapters.contains("\($0.book) \($0.chapter)") }) {
                    state.days.insert(entry.day)
                    state.lastCompletedOn = SharedVersesService.today
                    completedNow = true
                }
            }
            local[r.id] = state
            if completedNow { changed.append(r) }
        }
        saveLocal()
        guard !changed.isEmpty else { return }
        Task {
            for r in changed { await report(r, readToday: true) }
            await refresh()
        }
    }

    /// Manual tick for the next day (reflection days, verse ranges, or reading on paper).
    func markNextDayDone(_ r: SharedReading) async {
        // The gate and the write happen before the first await, so a rapid second tap
        // sees today's mark and is refused.
        guard canMarkDone(r), let day = nextDay(for: r) else { return }
        var state = local[r.id] ?? SharedReadingLocalState()
        state.days.insert(day)
        state.lastCompletedOn = SharedVersesService.today
        local[r.id] = state
        saveLocal()
        AppState.shared.recordActivity(.reading)
        await report(r, readToday: true)
        await refresh()
    }

    func markPassageRead(_ reading: SharedReading) async {
        var state = local[reading.id] ?? SharedReadingLocalState()
        guard !state.days.contains(1) else { return }   // already read; no repeat credit
        state.days.insert(1)
        local[reading.id] = state
        saveLocal()
        AppState.shared.recordActivity(.reading)
        await report(reading, readToday: true)
        await refresh()
    }

    private func celebrateIfNeeded() async {
        var done = Set(UserDefaults.standard.stringArray(forKey: celebratedKey) ?? [])
        for r in readings where r.finishedTogether && r.createdByMe && !done.contains(r.id) {
            done.insert(r.id)
            infoMessage = "You and \(r.friendName) finished \(title(for: r))!"
            await service.nudge(to: r.friendId, kind: "reading_celebrate", sharedReadingId: r.id)
        }
        UserDefaults.standard.set(Array(done), forKey: celebratedKey)
    }

    // MARK: Actions

    func propose(to friend: FriendActivity, plan: BibleReadingPlan) async -> Bool {
        await propose(to: friend, kind: "plan", planId: plan.id, reference: nil, totalDays: plan.totalDays)
    }

    func propose(to friend: FriendActivity, passage: String) async -> Bool {
        await propose(to: friend, kind: "passage", planId: nil, reference: passage, totalDays: 1)
    }

    private func propose(to friend: FriendActivity, kind: String, planId: String?, reference: String?, totalDays: Int) async -> Bool {
        do {
            let id = try await service.propose(friendId: friend.friendId, kind: kind, planId: planId,
                                               reference: reference, totalDays: totalDays)
            ensureLocal(id)    // start from Day 1 together
            await service.nudge(to: friend.friendId, kind: "reading_request", sharedReadingId: id)
            infoMessage = "Invited \(friend.displayName) to read together."
            errorMessage = nil
            await refresh()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func accept(_ r: SharedReading) async {
        do {
            ensureLocal(r.id)  // start from Day 1 together
            try await service.respond(r.id, accept: true)
            infoMessage = "You're reading \(title(for: r)) with \(r.friendName)."
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func decline(_ r: SharedReading) async {
        do { try await service.respond(r.id, accept: false); readings.removeAll { $0.id == r.id } }
        catch { errorMessage = error.localizedDescription }
    }

    func end(_ r: SharedReading) async {
        do {
            try await service.end(r.id)
            readings.removeAll { $0.id == r.id }
            local.removeValue(forKey: r.id)
            saveLocal()
        } catch { errorMessage = error.localizedDescription }
    }

    func remind(_ r: SharedReading) async {
        switch await service.nudge(to: r.friendId, kind: "reading_nudge", sharedReadingId: r.id) {
        case .success(let outcome):
            if let problem = outcome.failureMessage(for: r.friendName) { infoMessage = nil; errorMessage = problem }
            else { errorMessage = nil; infoMessage = "Reminder sent to \(r.friendName)." }
        case .failure(let error):
            infoMessage = nil; errorMessage = error.localizedDescription
        }
    }

    /// Opens the next reading in the Bible reader. For a plan, that's the next day of the
    /// SHARED plan (not the global plan position), resuming at the first unread chapter.
    func openToday(_ r: SharedReading) {
        var reference: String?
        if r.isPlan, let entry = entry(for: r) {
            let read = local[r.id]?.chapters ?? []
            if let next = entry.requiredChapters.first(where: { !read.contains("\($0.book) \($0.chapter)") }) {
                reference = "\(next.book) \(next.chapter)"
            } else {
                reference = entry.navRef
            }
        } else if let ref = r.reference {
            reference = BiblePlanEntry.navigationRef(for: ref) ?? ref
        }
        guard let reference else { return }
        NotificationCenter.default.post(name: .switchTab, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 2])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .navigateToBibleVerse, object: nil,
                                            userInfo: [AppNotificationUserInfoKey.reference: reference])
        }
    }
}
