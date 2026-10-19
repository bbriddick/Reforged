import Foundation
import SwiftUI

// MARK: - Models

/// One shared verse (pending or active) between the caller and a friend, as
/// returned by `get_shared_verses`. Only the reference is stored server-side,
/// never Scripture text.
struct SharedVerse: Codable, Identifiable, Equatable {
    let id: String
    let friendId: String
    let friendName: String
    let reference: String
    let translation: String
    let status: String
    let createdByMe: Bool
    let myLevel: Int?
    let myReviewCount: Int?
    let friendLevel: Int?
    let friendReviewCount: Int?
    let friendLastReviewedAt: String?
    let friendReviewedToday: Bool
    let iReviewedToday: Bool
    let pairStreak: Int
    let masteredTogether: Bool

    var isPending: Bool { status == "pending" }
    var isActive: Bool { status == "active" }
    /// A request waiting on ME to accept.
    var needsMyResponse: Bool { isPending && !createdByMe }

    enum CodingKeys: String, CodingKey {
        case id, reference, translation, status
        case friendId = "friend_id", friendName = "friend_name", createdByMe = "created_by_me"
        case myLevel = "my_level", myReviewCount = "my_review_count"
        case friendLevel = "friend_level", friendReviewCount = "friend_review_count"
        case friendLastReviewedAt = "friend_last_reviewed_at"
        case friendReviewedToday = "friend_reviewed_today", iReviewedToday = "i_reviewed_today"
        case pairStreak = "pair_streak", masteredTogether = "mastered_together"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        friendId = try c.decode(String.self, forKey: .friendId)
        friendName = (try? c.decode(String.self, forKey: .friendName)) ?? "Friend"
        reference = try c.decode(String.self, forKey: .reference)
        translation = (try? c.decode(String.self, forKey: .translation)) ?? "ESV"
        status = try c.decode(String.self, forKey: .status)
        createdByMe = (try? c.decode(Bool.self, forKey: .createdByMe)) ?? false
        myLevel = try? c.decodeIfPresent(Int.self, forKey: .myLevel)
        myReviewCount = try? c.decodeIfPresent(Int.self, forKey: .myReviewCount)
        friendLevel = try? c.decodeIfPresent(Int.self, forKey: .friendLevel)
        friendReviewCount = try? c.decodeIfPresent(Int.self, forKey: .friendReviewCount)
        friendLastReviewedAt = try? c.decodeIfPresent(String.self, forKey: .friendLastReviewedAt)
        friendReviewedToday = (try? c.decode(Bool.self, forKey: .friendReviewedToday)) ?? false
        iReviewedToday = (try? c.decode(Bool.self, forKey: .iReviewedToday)) ?? false
        pairStreak = (try? c.decode(Int.self, forKey: .pairStreak)) ?? 0
        masteredTogether = (try? c.decode(Bool.self, forKey: .masteredTogether)) ?? false
    }
}

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var blanks: Int { switch self { case .easy: return 3; case .medium: return 6; case .hard: return 10 } }
    var label: String { rawValue.capitalized }
}

enum QuizReaction: String, CaseIterable, Identifiable {
    case nailedIt = "nailed_it", soClose = "so_close", keepGoing = "keep_going", amen
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nailedIt: return "🙌 Nailed it"
        case .soClose:  return "👏 So close"
        case .keepGoing: return "💪 Keep going"
        case .amen:     return "🙏 Amen"
        }
    }
}

struct VerseQuiz: Codable, Identifiable, Equatable {
    let id: String
    let sharedVerseId: String
    let role: String            // "recipient" (take it) or "sender" (see result)
    let friendName: String
    let reference: String
    let translation: String
    let difficulty: String
    let status: String
    let score: Int?
    let blanksTotal: Int?
    let blanksCorrect: Int?
    let reaction: String?
    let xpClaimable: Bool

    var isToTake: Bool { role == "recipient" && status == "sent" }
    var quizDifficulty: QuizDifficulty { QuizDifficulty(rawValue: difficulty) ?? .easy }

    enum CodingKeys: String, CodingKey {
        case id, role, reference, translation, difficulty, status, score, reaction
        case sharedVerseId = "shared_verse_id", friendName = "friend_name"
        case blanksTotal = "blanks_total", blanksCorrect = "blanks_correct", xpClaimable = "xp_claimable"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sharedVerseId = try c.decode(String.self, forKey: .sharedVerseId)
        role = try c.decode(String.self, forKey: .role)
        friendName = (try? c.decode(String.self, forKey: .friendName)) ?? "Friend"
        reference = try c.decode(String.self, forKey: .reference)
        translation = (try? c.decode(String.self, forKey: .translation)) ?? "ESV"
        difficulty = try c.decode(String.self, forKey: .difficulty)
        status = try c.decode(String.self, forKey: .status)
        score = try? c.decodeIfPresent(Int.self, forKey: .score)
        blanksTotal = try? c.decodeIfPresent(Int.self, forKey: .blanksTotal)
        blanksCorrect = try? c.decodeIfPresent(Int.self, forKey: .blanksCorrect)
        reaction = try? c.decodeIfPresent(String.self, forKey: .reaction)
        xpClaimable = (try? c.decode(Bool.self, forKey: .xpClaimable)) ?? false
    }
}

// MARK: - Verse text (each phone uses its own licensed source)

enum VerseTextFetcher {
    /// Translations that can be fetched for memory verses.
    static var supported: [BibleTranslation] {
        BibleTranslation.allCases.filter { ![.tr, .sblgnt, .wlc].contains($0) }
    }

    static func fetch(reference: String, translation: BibleTranslation) async throws -> (text: String, canonical: String) {
        switch translation {
        case .esv:   return try await ESVService.shared.fetchVerseForMemory(reference: reference)
        case .kjv:   return try await KJVService.shared.fetchVerseForMemory(reference: reference)
        case .net:   return try await NETService.shared.fetchVerseForMemory(reference: reference)
        case .csb, .nkjv, .nasb, .rvr1960, .nlt:
            return try await ApiBibleService.shared.fetchVerseForMemory(reference: reference, translation: translation)
        case .tr, .sblgnt, .wlc:
            throw FriendsError.server("That translation isn't available for shared verses.")
        }
    }
}

// MARK: - Offline queue for "reviewed/read today" marks
//
// The pair streak is built from one "I did it today" mark per person per day, sent at
// the moment of the review or reading. If that call fails (offline), the mark is saved
// here and retried with its ORIGINAL day, so the day still counts once the phone is
// back online. The server only accepts days within one day of its own date, so marks
// older than that are dropped.

struct PendingDailyMark: Codable, Hashable {
    let kind: String   // "verse" or "reading"
    let id: String
    let day: String    // local yyyy-MM-dd
}

enum PendingDailyMarks {
    private static let key = "friends.pendingDailyMarks"

    static func all(kind: String) -> [PendingDailyMark] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let marks = try? JSONDecoder().decode([PendingDailyMark].self, from: data) else { return [] }
        return marks.filter { $0.kind == kind }
    }

    private static func save(_ marks: [PendingDailyMark]) {
        if let data = try? JSONEncoder().encode(marks) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func everything() -> [PendingDailyMark] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let marks = try? JSONDecoder().decode([PendingDailyMark].self, from: data) else { return [] }
        return marks
    }

    static func add(kind: String, id: String, day: String) {
        var marks = everything()
        let mark = PendingDailyMark(kind: kind, id: id, day: day)
        guard !marks.contains(mark) else { return }
        marks.append(mark)
        save(marks)
    }

    static func remove(_ mark: PendingDailyMark) {
        save(everything().filter { $0 != mark })
    }

    /// The server rejects days more than 1 day from its own date, so older marks can never land.
    static func isExpired(_ mark: PendingDailyMark) -> Bool {
        guard let day = SharedVersesService.dayFormatter.date(from: mark.day) else { return true }
        let today = Calendar.current.startOfDay(for: Date())
        let age = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: day), to: today).day ?? 99
        return age > 1
    }
}

// MARK: - Service

@MainActor
final class SharedVersesService {
    static let shared = SharedVersesService()
    private init() {}
    private var api: FriendsService { FriendsService.shared }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"     // local day, matching the streak convention
        return f
    }()
    static var today: String { dayFormatter.string(from: Date()) }

    func list() async throws -> [SharedVerse] {
        let data = try await api.rpc("get_shared_verses", ["_today": Self.today])
        return (try? JSONDecoder().decode([SharedVerse].self, from: data)) ?? []
    }

    func propose(friendId: String, reference: String, translation: String) async throws -> String {
        let data = try await api.rpc("propose_shared_verse",
                                     ["_friend_id": friendId, "_reference": reference, "_translation": translation])
        guard let id = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String
        else { throw FriendsError.server(nil) }
        return id
    }

    func respond(_ id: String, accept: Bool) async throws {
        try await api.rpc("respond_shared_verse", ["_id": id, "_accept": accept])
    }

    func end(_ id: String) async throws { try await api.rpc("end_shared_verse", ["_id": id]) }

    func reportProgress(id: String, level: Int, reviewCount: Int, reviewed: Bool, day: String? = nil) async throws {
        try await api.rpc("report_verse_progress", [
            "_shared_verse_id": id, "_level": level, "_review_count": reviewCount,
            "_reviewed": reviewed, "_today": day ?? Self.today])
    }

    func quizzes() async throws -> [VerseQuiz] {
        let data = try await api.rpc("get_my_quizzes")
        return (try? JSONDecoder().decode([VerseQuiz].self, from: data)) ?? []
    }

    func sendQuiz(sharedVerseId: String, difficulty: QuizDifficulty) async throws {
        try await api.rpc("send_verse_quiz", ["_shared_verse_id": sharedVerseId, "_difficulty": difficulty.rawValue])
    }

    func completeQuiz(id: String, total: Int, correct: Int) async throws -> Int {
        let data = try await api.rpc("complete_verse_quiz",
                                     ["_quiz_id": id, "_blanks_total": total, "_blanks_correct": correct])
        return ((try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? Int) ?? 0
    }

    func react(quizId: String, reaction: QuizReaction) async throws {
        try await api.rpc("react_to_quiz", ["_quiz_id": quizId, "_reaction": reaction.rawValue])
    }

    func claimXP(quizId: String) async throws -> Int {
        let data = try await api.rpc("claim_quiz_xp", ["_quiz_id": quizId])
        return ((try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? Int) ?? 0
    }

    func quizNudge(to friendId: String, kind: String, quizId: String) async {
        do { _ = try await api.sendQuizNudge(to: friendId, kind: kind, quizId: quizId) }
        catch { debugLog("Quiz nudge \(kind) failed: \(error.localizedDescription)") }
    }

    /// Returns the outcome so user-initiated reminders can say what really happened.
    @discardableResult
    func nudge(to friendId: String, kind: String, sharedVerseId: String) async -> Result<NudgeOutcome, Error> {
        do { return .success(try await api.sendVerseNudge(to: friendId, kind: kind, sharedVerseId: sharedVerseId)) }
        catch { debugLog("Verse nudge \(kind) failed: \(error.localizedDescription)"); return .failure(error) }
    }
}

// MARK: - Quiz log (finished quizzes leave the feed and live under the friend)

struct QuizLogEntry: Codable, Identifiable, Equatable {
    let id: String
    let friendName: String
    let reference: String
    let score: Int
    let reaction: String?
    let date: Date
}

// MARK: - Store

@MainActor
final class SharedVersesStore: ObservableObject {
    static let shared = SharedVersesStore()

    @Published var verses: [SharedVerse] = [] { didSet { persistCache() } }
    @Published var quizzes: [VerseQuiz] = [] { didSet { persistCache() } }
    @Published var errorMessage: String? {
        didSet { if FriendsError.isCancellation(errorMessage) { errorMessage = nil } }
    }
    @Published var infoMessage: String?

    private let service = SharedVersesService.shared
    private let linksKey = "sharedVerses.links"          // sharedVerseId -> MemoryVerse.id
    private let celebratedKey = "sharedVerses.celebrated"
    private var lastReported: [String: String] = [:]     // sharedVerseId -> "level-count"

    @Published private(set) var quizLog: [QuizLogEntry] = []
    private let quizLogKey = "sharedVerses.quizLog"

    private init() {
        if let data = UserDefaults.standard.data(forKey: quizLogKey),
           let log = try? JSONDecoder().decode([QuizLogEntry].self, from: data) { quizLog = log }
        hydrateFromCache()
    }

    // MARK: Last-known cache (shown instantly, refreshed behind it)

    private struct Snapshot: Codable { var verses: [SharedVerse]; var quizzes: [VerseQuiz] }
    private var cachedFor: String?

    private func hydrateFromCache() {
        guard let uid = SupabaseAuthService.shared.userId, cachedFor != uid else { return }
        cachedFor = uid
        guard let snap = FriendsDiskCache.load(Snapshot.self, name: "verses", uid: uid) else { return }
        verses = snap.verses
        quizzes = snap.quizzes
    }

    private func persistCache() {
        guard let uid = SupabaseAuthService.shared.userId, cachedFor == uid, hasRefreshed else { return }
        FriendsDiskCache.save(Snapshot(verses: verses, quizzes: quizzes), name: "verses", uid: uid)
    }

    /// Set once a network refresh has succeeded, so a half-loaded state never overwrites the cache.
    private var hasRefreshed = false

    func clearCache() {
        verses = []
        quizzes = []
        if let uid = SupabaseAuthService.shared.userId { FriendsDiskCache.clear(name: "verses", uid: uid) }
    }

    func isLogged(_ quiz: VerseQuiz) -> Bool { quizLog.contains { $0.id == quiz.id } }

    func log(for friendName: String) -> [QuizLogEntry] {
        quizLog.filter { $0.friendName == friendName }.sorted { $0.date > $1.date }
    }

    private func archive(_ quiz: VerseQuiz, reaction: String) {
        guard !isLogged(quiz) else { return }
        quizLog.append(QuizLogEntry(id: quiz.id, friendName: quiz.friendName, reference: quiz.reference,
                                    score: quiz.score ?? 0, reaction: reaction, date: Date()))
        if let data = try? JSONEncoder().encode(quizLog) { UserDefaults.standard.set(data, forKey: quizLogKey) }
    }

    /// Taker side: once the friend's reaction has been shown, move the score into the log.
    func archiveSeenResults() {
        for quiz in quizzes where quiz.role == "recipient" && quiz.status == "completed" {
            if let r = quiz.reaction { archive(quiz, reaction: r) }
        }
    }

    private var appState: AppState { AppState.shared }
    private var canUse: Bool {
        SupabaseAuthService.shared.isSignedIn && AgeGateManager.shared.status == .allowed
    }

    // MARK: Links to the Memory deck

    private var links: [String: String] {
        get { (UserDefaults.standard.dictionary(forKey: linksKey) as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: linksKey) }
    }

    func memoryVerse(for sharedId: String) -> MemoryVerse? {
        guard let mid = links[sharedId] else { return nil }
        return appState.memoryVerses.first { $0.id == mid }
    }

    private func sharedId(forMemoryVerse id: String) -> String? {
        links.first(where: { $0.value == id })?.key
    }

    /// Adds the verse to the Memory deck (or links to the copy the user already has).
    private func addToDeck(sharedId: String, text: String, canonical: String, translation: String) {
        if let existing = appState.memoryVerses.first(where: { $0.reference == canonical }) {
            links[sharedId] = existing.id
            return
        }
        let verse = MemoryVerse(
            id: "shared-\(sharedId)", reference: canonical, text: text, esvText: nil,
            category: "Together", translation: translation,
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(), reviewCount: 0, easeFactor: 2.5, interval: 1,
            isLearning: true, accuracy: nil, modeStats: nil)
        appState.addMemoryVerse(verse)
        links[sharedId] = verse.id
    }

    // MARK: Refresh

    func refresh() async {
        guard canUse else { return }
        hydrateFromCache()
        do {
            async let v = service.list()
            async let q = service.quizzes()
            let newVerses = try await v
            let newQuizzes = try await q
            hasRefreshed = true
            verses = newVerses
            quizzes = newQuizzes
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

    /// Reports level/review count for every linked active verse that changed.
    private func syncProgress() async {
        await flushPendingMarks()
        for sv in verses where sv.isActive {
            guard let mv = memoryVerse(for: sv.id) else { continue }
            let key = "\(mv.level)-\(mv.reviewCount)"
            guard lastReported[sv.id] != key else { continue }
            if (try? await service.reportProgress(id: sv.id, level: mv.level, reviewCount: mv.reviewCount, reviewed: false)) != nil {
                lastReported[sv.id] = key
            }
        }
    }

    /// Retries "reviewed today" marks that couldn't be sent earlier, using their original day.
    private func flushPendingMarks() async {
        for mark in PendingDailyMarks.all(kind: "verse") {
            guard !PendingDailyMarks.isExpired(mark),
                  verses.contains(where: { $0.id == mark.id && $0.isActive }) else {
                PendingDailyMarks.remove(mark)   // expired, or the shared verse ended
                continue
            }
            guard let mv = memoryVerse(for: mark.id) else { PendingDailyMarks.remove(mark); continue }
            if (try? await service.reportProgress(id: mark.id, level: mv.level, reviewCount: mv.reviewCount,
                                                  reviewed: true, day: mark.day)) != nil {
                PendingDailyMarks.remove(mark)
                lastReported[mark.id] = "\(mv.level)-\(mv.reviewCount)"
            }
        }
    }

    /// Called from `AppState.updateVerseReview` after any review.
    func didReview(memoryVerseId: String) {
        guard canUse, let sid = sharedId(forMemoryVerse: memoryVerseId),
              let mv = appState.memoryVerses.first(where: { $0.id == memoryVerseId }) else { return }
        let day = SharedVersesService.today
        Task {
            if (try? await service.reportProgress(id: sid, level: mv.level, reviewCount: mv.reviewCount,
                                                  reviewed: true, day: day)) != nil {
                lastReported[sid] = "\(mv.level)-\(mv.reviewCount)"
                await refresh()
            } else {
                // Offline or failed: remember today's review and retry when we can.
                PendingDailyMarks.add(kind: "verse", id: sid, day: day)
            }
        }
    }

    private func celebrateIfNeeded() async {
        var done = Set(UserDefaults.standard.stringArray(forKey: celebratedKey) ?? [])
        for sv in verses where sv.masteredTogether && sv.createdByMe && !done.contains(sv.id) {
            done.insert(sv.id)
            infoMessage = "You and \(sv.friendName) mastered \(sv.reference)!"
            await service.nudge(to: sv.friendId, kind: "verse_celebrate", sharedVerseId: sv.id)
        }
        UserDefaults.standard.set(Array(done), forKey: celebratedKey)
    }

    // MARK: Proposals

    /// Verifies the reference by fetching its text, then proposes it and adds it to my deck.
    func propose(to friend: FriendActivity, reference: String, translation: BibleTranslation,
                 prefetched: (text: String, canonical: String)? = nil) async -> Bool {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let fetched: (text: String, canonical: String)
            if let prefetched, !prefetched.text.isEmpty { fetched = prefetched }
            else { fetched = try await VerseTextFetcher.fetch(reference: trimmed, translation: translation) }
            guard !fetched.text.isEmpty else { throw FriendsError.server("We couldn't find that verse.") }
            let canonical = fetched.canonical.isEmpty ? trimmed : fetched.canonical
            let id = try await service.propose(friendId: friend.friendId, reference: canonical, translation: translation.rawValue)
            addToDeck(sharedId: id, text: fetched.text, canonical: canonical, translation: translation.rawValue)
            await service.nudge(to: friend.friendId, kind: "verse_request", sharedVerseId: id)
            infoMessage = "Sent \(canonical) to \(friend.displayName)."
            errorMessage = nil
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func accept(_ sv: SharedVerse) async {
        do {
            let tr = BibleTranslation(rawValue: sv.translation) ?? .esv
            let fetched = try await VerseTextFetcher.fetch(reference: sv.reference, translation: tr)
            try await service.respond(sv.id, accept: true)
            addToDeck(sharedId: sv.id, text: fetched.text,
                      canonical: fetched.canonical.isEmpty ? sv.reference : fetched.canonical,
                      translation: tr.rawValue)
            infoMessage = "\(sv.reference) added to your Memory deck."
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func decline(_ sv: SharedVerse) async {
        do { try await service.respond(sv.id, accept: false); verses.removeAll { $0.id == sv.id } }
        catch { errorMessage = error.localizedDescription }
    }

    func end(_ sv: SharedVerse) async {
        do {
            try await service.end(sv.id)
            var l = links; l.removeValue(forKey: sv.id); links = l
            verses.removeAll { $0.id == sv.id }
        } catch { errorMessage = error.localizedDescription }
    }

    func remind(_ sv: SharedVerse) async {
        switch await service.nudge(to: sv.friendId, kind: "verse_nudge", sharedVerseId: sv.id) {
        case .success(let outcome):
            if let problem = outcome.failureMessage(for: sv.friendName) { infoMessage = nil; errorMessage = problem }
            else { errorMessage = nil; infoMessage = "Reminder sent to \(sv.friendName)." }
        case .failure(let error):
            infoMessage = nil; errorMessage = error.localizedDescription
        }
    }

    // MARK: Quizzes

    /// Difficulties this verse has enough words for.
    func availableDifficulties(for sv: SharedVerse) -> [QuizDifficulty] {
        guard let text = memoryVerse(for: sv.id)?.text else { return [.easy] }
        let eligible = QuizBuilder.eligibleCount(in: text)
        return QuizDifficulty.allCases.filter { eligible >= $0.blanks + 2 }
    }

    func sendQuiz(_ sv: SharedVerse, difficulty: QuizDifficulty) async -> Bool {
        do {
            try await service.sendQuiz(sharedVerseId: sv.id, difficulty: difficulty)
            await service.nudge(to: sv.friendId, kind: "verse_quiz", sharedVerseId: sv.id)
            infoMessage = "Quiz sent to \(sv.friendName)."
            await refresh()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func text(for quiz: VerseQuiz) async -> String? {
        if let t = memoryVerse(for: quiz.sharedVerseId)?.text, !t.isEmpty { return t }
        let tr = BibleTranslation(rawValue: quiz.translation) ?? .esv
        return try? await VerseTextFetcher.fetch(reference: quiz.reference, translation: tr).text
    }

    func complete(_ quiz: VerseQuiz, total: Int, correct: Int) async -> Int? {
        do {
            let score = try await service.completeQuiz(id: quiz.id, total: total, correct: correct)
            if let friendId = verses.first(where: { $0.id == quiz.sharedVerseId })?.friendId {
                await service.quizNudge(to: friendId, kind: "quiz_result", quizId: quiz.id)
            }
            await claimXP(quiz)
            await refresh()
            return score
        } catch { errorMessage = error.localizedDescription; return nil }
    }

    func claimXP(_ quiz: VerseQuiz) async {
        guard let xp = try? await service.claimXP(quizId: quiz.id) else { return }
        if xp > 0 {
            appState.addXP(xp, source: "verse-quiz")
            infoMessage = "+\(xp) XP"
        }
        await refresh()
    }

    func react(_ quiz: VerseQuiz, _ reaction: QuizReaction) async {
        do {
            try await service.react(quizId: quiz.id, reaction: reaction)
            if let friendId = verses.first(where: { $0.id == quiz.sharedVerseId })?.friendId {
                await service.quizNudge(to: friendId, kind: "quiz_reaction", quizId: quiz.id)
            }
            if quiz.xpClaimable { await claimXP(quiz) }
            archive(quiz, reaction: reaction.rawValue)
            await refresh()
        }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Quiz construction (done on-device from the user's own text)

struct QuizToken: Identifiable {
    let id: Int
    let leading: String
    let core: String
    let trailing: String
    var blankIndex: Int?
}

enum QuizBuilder {
    private static func split(_ word: String) -> (String, String, String) {
        var chars = Array(word)
        var lead = "", trail = ""
        while let f = chars.first, !(f.isLetter || f.isNumber) { lead.append(f); chars.removeFirst() }
        while let l = chars.last, !(l.isLetter || l.isNumber) { trail = String(l) + trail; chars.removeLast() }
        return (lead, String(chars), trail)
    }

    static func eligibleCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).filter { split(String($0)).1.count >= 4 }.count
    }

    /// Builds tokens with `count` blanked words (prefers longer words).
    static func make(text: String, count: Int) -> (tokens: [QuizToken], answers: [String]) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var tokens: [QuizToken] = words.enumerated().map { i, w in
            let (l, c, t) = split(w)
            return QuizToken(id: i, leading: l, core: c, trailing: t, blankIndex: nil)
        }
        var candidates = tokens.indices.filter { tokens[$0].core.count >= 4 }
        if candidates.count < count { candidates = tokens.indices.filter { tokens[$0].core.count >= 3 } }
        let chosen = Array(candidates.shuffled().prefix(count)).sorted()
        var answers: [String] = []
        for (n, idx) in chosen.enumerated() {
            tokens[idx].blankIndex = n
            answers.append(tokens[idx].core)
        }
        return (tokens, answers)
    }
}
