import Foundation

// MARK: - TracksRepository
//
// Read-side data access for published tracks/lessons/blocks. Talks to Supabase
// PostgREST with the current user's JWT; RLS enforces visibility server-side and
// this layer mirrors the same filters (published_at, assignment via
// group_members) client-side. Cover/handout files use short-TTL signed URLs
// (never public URLs). Lesson bodies are held in memory only, never persisted.

@MainActor
final class TracksRepository {
    static let shared = TracksRepository()
    private init() {}

    private let decoder = JSONDecoder()
    private var baseURL: String { SettingsManager.shared.supabaseProjectURL?.absoluteString ?? "" }
    private var anonKey: String { SettingsManager.shared.supabaseAnonKey }

    // MARK: - Low-level GET (auth + one 429 backoff)

    private func get(_ table: String, _ query: String, attempt: Int = 0) async throws -> Data {
        guard !baseURL.isEmpty, !anonKey.isEmpty else { throw GroupsError.notConfigured }
        guard let token = await SupabaseAuthService.shared.validAccessToken() else { throw GroupsError.notAuthenticated }
        guard let url = URL(string: "\(baseURL)/rest/v1/\(table)\(query)") else { throw GroupsError.notConfigured }

        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GroupsError.badResponse(status: -1, message: nil) }

        // Exponential backoff on rate limiting (max 2 retries).
        if http.statusCode == 429, attempt < 2 {
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 0.5 * 1_000_000_000))
            return try await get(table, query, attempt: attempt + 1)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw GroupsError.badResponse(status: http.statusCode, message: msg)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw GroupsError.decoding(error) }
    }

    // MARK: - Tracks

    /// Published tracks assigned to any group the user belongs to, plus tracks
    /// the user owns (owners see their own drafts). Deduped by track id.
    func fetchTracksForCurrentUser() async throws -> [LearnTrack] {
        guard let uid = SupabaseAuthService.shared.userId else { throw GroupsError.notAuthenticated }

        // 1) Groups I'm in.
        let gmData = try await get("group_members", "?user_id=eq.\(uid)&select=group_id")
        struct GRow: Decodable { let groupId: String
            enum CodingKeys: String, CodingKey { case groupId = "group_id" } }
        let groupIds = try decode([GRow].self, from: gmData).map { $0.groupId }

        // 2) Track ids assigned to those groups.
        var trackIds = Set<String>()
        if !groupIds.isEmpty {
            let aData = try await get("track_group_assignments",
                                      "?group_id=in.(\(groupIds.joined(separator: ",")))&select=track_id")
            struct ARow: Decodable { let trackId: String
                enum CodingKeys: String, CodingKey { case trackId = "track_id" } }
            trackIds.formUnion(try decode([ARow].self, from: aData).map { $0.trackId })
        }

        // 3) Fetch published assigned tracks, plus everything I own (incl. drafts).
        var byId: [String: LearnTrack] = [:]
        if !trackIds.isEmpty {
            let tData = try await get("leader_tracks",
                                      "?id=in.(\(trackIds.joined(separator: ",")))&published_at=not.is.null&select=*")
            for t in try decode([LearnTrack].self, from: tData) { byId[t.id] = t }
        }
        // Legacy direct-assignment path (leader_tracks.group_id) for tracks not
        // yet migrated to track_group_assignments — so nothing disappears mid-migration.
        if !groupIds.isEmpty {
            let lData = try await get("leader_tracks",
                                      "?group_id=in.(\(groupIds.joined(separator: ",")))&published_at=not.is.null&select=*")
            for t in try decode([LearnTrack].self, from: lData) { byId[t.id] = t }
        }

        let oData = try await get("leader_tracks", "?owner_id=eq.\(uid)&select=*")
        for t in try decode([LearnTrack].self, from: oData) { byId[t.id] = t }

        return byId.values.sorted {
            (LearnDate.parse($0.publishedAt) ?? .distantPast) > (LearnDate.parse($1.publishedAt) ?? .distantPast)
        }
    }

    // MARK: - Lessons

    /// Lessons for a track, ordered by position. Non-owners see only published
    /// lessons; owners also see drafts.
    func fetchLessons(trackId: String, includeDrafts: Bool) async throws -> [TrackLesson] {
        var query = "?track_id=eq.\(trackId)&select=*&order=position.asc,created_at.asc"
        if !includeDrafts { query += "&published_at=not.is.null" }
        let data = try await get("track_lessons", query)
        return try decode([TrackLesson].self, from: data)
    }

    // MARK: - Blocks

    func fetchItems(lessonId: String) async throws -> [LessonBlock] {
        let data = try await get("track_items",
                                 "?lesson_id=eq.\(lessonId)&select=*&order=position.asc,created_at.asc")
        return try decode([TrackItemRow].self, from: data).map { $0.toBlock() }
    }

    // MARK: - Referenced handout

    func handout(id: String) async throws -> Handout? {
        let data = try await get("handouts", "?id=eq.\(id)&select=*&limit=1")
        return try decode([Handout].self, from: data).first
    }

    // MARK: - Signed cover URL

    func coverURL(path: String?) async -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return try? await GroupsService.shared.signedURL(bucket: "group-covers", path: path)
    }
}
