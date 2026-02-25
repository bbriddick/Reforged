import Foundation
import CloudKit

// MARK: - CloudKit Sync Service

@MainActor
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isCloudAvailable = false

    private let container = CKContainer(identifier: "iCloud.com.reforged.app")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    // Record type names
    private enum RecordType {
        static let userProfile = "UserProfile"
        static let memoryVerse = "MemoryVerse"
        static let verseHighlight = "VerseHighlight"
        static let verseNote = "VerseNote"
        static let trackProgress = "TrackProgress"
    }

    private init() {
        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Account Status

    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            isCloudAvailable = (status == .available)
            if !isCloudAvailable {
                print("CloudKit: iCloud account not available (status: \(status.rawValue))")
            }
        } catch {
            isCloudAvailable = false
            print("CloudKit: Error checking account status: \(error)")
        }
    }

    // MARK: - Profile

    func saveProfile(_ profile: UserProfile) async throws {
        guard isCloudAvailable else { return }

        let recordID = CKRecord.ID(recordName: "profile")
        let record: CKRecord

        // Try to fetch existing record to preserve system fields
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: RecordType.userProfile, recordID: recordID)
        }

        record["firstName"] = profile.firstName as CKRecordValue
        record["lastName"] = profile.lastName as CKRecordValue
        record["displayName"] = profile.displayName as CKRecordValue
        record["avatar"] = profile.avatar as CKRecordValue
        record["goals"] = profile.goals as CKRecordValue
        record["xp"] = profile.xp as CKRecordValue
        record["level"] = profile.currentLevel as CKRecordValue
        record["streak"] = profile.streak as CKRecordValue
        record["longestStreak"] = profile.longestStreak as CKRecordValue
        record["lastActiveDate"] = profile.lastActiveDate as CKRecordValue
        record["completedLessons"] = profile.completedLessons as CKRecordValue
        record["streakFreezes"] = profile.streakFreezes as CKRecordValue
        record["freezeUsedDates"] = profile.freezeUsedDates as CKRecordValue
        record["activeDates"] = profile.activeDates as CKRecordValue
        record["chaptersRead"] = profile.chaptersRead as CKRecordValue

        // Store complex objects as JSON strings
        if let badgesData = try? JSONEncoder().encode(profile.badges),
           let badgesJSON = String(data: badgesData, encoding: .utf8) {
            record["badges"] = badgesJSON as CKRecordValue
        }

        if let activityData = try? JSONEncoder().encode(profile.weeklyActivity),
           let activityJSON = String(data: activityData, encoding: .utf8) {
            record["weeklyActivity"] = activityJSON as CKRecordValue
        }

        record["modifiedAt"] = Date() as CKRecordValue

        try await privateDatabase.save(record)
    }

    func fetchProfile() async throws -> UserProfile? {
        guard isCloudAvailable else { return nil }

        let recordID = CKRecord.ID(recordName: "profile")
        do {
            let record = try await privateDatabase.record(for: recordID)
            return profileFromRecord(record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw error
        }
    }

    private func profileFromRecord(_ record: CKRecord) -> UserProfile {
        let badges: [Badge] = {
            if let json = record["badges"] as? String,
               let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Badge].self, from: data) {
                return decoded
            }
            return []
        }()

        let weeklyActivity: WeeklyActivity = {
            if let json = record["weeklyActivity"] as? String,
               let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(WeeklyActivity.self, from: data) {
                return decoded
            }
            return WeeklyActivity()
        }()

        return UserProfile(
            id: record.recordID.recordName,
            firstName: record["firstName"] as? String ?? "",
            lastName: record["lastName"] as? String ?? "",
            displayName: record["displayName"] as? String ?? "",
            email: nil,
            avatar: record["avatar"] as? String ?? "🦁",
            goals: record["goals"] as? [String] ?? [],
            xp: record["xp"] as? Int ?? 0,
            level: record["level"] as? Int ?? 1,
            streak: record["streak"] as? Int ?? 0,
            longestStreak: record["longestStreak"] as? Int ?? 0,
            lastActiveDate: record["lastActiveDate"] as? String ?? ISO8601DateFormatter().string(from: Date()),
            badges: badges,
            completedLessons: record["completedLessons"] as? [String] ?? [],
            memoryVerses: [],
            onboardingCompleted: true,
            loggedIn: true,
            streakFreezes: record["streakFreezes"] as? Int ?? 0,
            freezeUsedDates: record["freezeUsedDates"] as? [String] ?? [],
            activeDates: record["activeDates"] as? [String] ?? [],
            chaptersRead: record["chaptersRead"] as? [String] ?? [],
            weeklyActivity: weeklyActivity
        )
    }

    // MARK: - Memory Verses

    func saveMemoryVerses(_ verses: [MemoryVerse]) async throws {
        guard isCloudAvailable, !verses.isEmpty else { return }

        // Chunk into batches of 400 (CloudKit limit)
        let chunks = verses.chunked(into: 400)
        for chunk in chunks {
            var recordsToSave: [CKRecord] = []

            for verse in chunk {
                let recordID = CKRecord.ID(recordName: "verse-\(verse.id)")
                let record = CKRecord(recordType: RecordType.memoryVerse, recordID: recordID)

                record["verseID"] = verse.id as CKRecordValue
                record["reference"] = verse.reference as CKRecordValue
                record["text"] = verse.text as CKRecordValue
                record["esvText"] = (verse.esvText ?? "") as CKRecordValue
                record["category"] = verse.category as CKRecordValue
                record["translation"] = (verse.translation ?? "ESV") as CKRecordValue
                record["lastFetched"] = (verse.lastFetched ?? "") as CKRecordValue
                record["nextReviewDate"] = verse.nextReviewDate as CKRecordValue
                record["reviewCount"] = verse.reviewCount as CKRecordValue
                record["easeFactor"] = verse.easeFactor as CKRecordValue
                record["interval"] = verse.interval as CKRecordValue
                record["isLearning"] = (verse.isLearning ? 1 : 0) as CKRecordValue
                record["accuracy"] = (verse.accuracy ?? 0.0) as CKRecordValue

                if let modeStats = verse.modeStats,
                   let data = try? JSONEncoder().encode(modeStats),
                   let json = String(data: data, encoding: .utf8) {
                    record["modeStats"] = json as CKRecordValue
                }

                record["modifiedAt"] = Date() as CKRecordValue
                recordsToSave.append(record)
            }

            try await batchSave(records: recordsToSave)
        }
    }

    func fetchMemoryVerses() async throws -> [MemoryVerse] {
        guard isCloudAvailable else { return [] }

        let query = CKQuery(recordType: RecordType.memoryVerse, predicate: NSPredicate(value: true))
        var allVerses: [MemoryVerse] = []

        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)

        for (_, result) in results {
            if case .success(let record) = result {
                if let verse = memoryVerseFromRecord(record) {
                    allVerses.append(verse)
                }
            }
        }

        return allVerses
    }

    func deleteMemoryVerse(id: String) async throws {
        guard isCloudAvailable else { return }

        let recordID = CKRecord.ID(recordName: "verse-\(id)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func memoryVerseFromRecord(_ record: CKRecord) -> MemoryVerse? {
        guard let verseID = record["verseID"] as? String,
              let reference = record["reference"] as? String,
              let text = record["text"] as? String,
              let category = record["category"] as? String else {
            return nil
        }

        let modeStats: MemoryVerseModeStats? = {
            if let json = record["modeStats"] as? String,
               let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(MemoryVerseModeStats.self, from: data) {
                return decoded
            }
            return nil
        }()

        return MemoryVerse(
            id: verseID,
            reference: reference,
            text: text,
            esvText: record["esvText"] as? String,
            category: category,
            translation: record["translation"] as? String,
            lastFetched: record["lastFetched"] as? String,
            nextReviewDate: record["nextReviewDate"] as? Date ?? Date(),
            reviewCount: record["reviewCount"] as? Int ?? 0,
            easeFactor: record["easeFactor"] as? Double ?? 2.5,
            interval: record["interval"] as? Int ?? 1,
            isLearning: (record["isLearning"] as? Int ?? 1) == 1,
            accuracy: record["accuracy"] as? Double,
            modeStats: modeStats
        )
    }

    // MARK: - Verse Highlights

    func saveHighlights(_ highlights: [VerseHighlight]) async throws {
        guard isCloudAvailable, !highlights.isEmpty else { return }

        let chunks = highlights.chunked(into: 400)
        for chunk in chunks {
            var records: [CKRecord] = []

            for highlight in chunk {
                // Sanitize reference for record ID (replace spaces, colons)
                let safeRef = highlight.reference.replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: ":", with: "-")
                let recordID = CKRecord.ID(recordName: "highlight-\(safeRef)")
                let record = CKRecord(recordType: RecordType.verseHighlight, recordID: recordID)

                record["highlightID"] = highlight.id as CKRecordValue
                record["reference"] = highlight.reference as CKRecordValue
                record["book"] = highlight.book as CKRecordValue
                record["chapter"] = highlight.chapter as CKRecordValue
                record["verse"] = highlight.verse as CKRecordValue
                record["color"] = highlight.color as CKRecordValue
                record["createdAt"] = highlight.createdAt as CKRecordValue
                record["modifiedAt"] = Date() as CKRecordValue

                records.append(record)
            }

            try await batchSave(records: records)
        }
    }

    func fetchHighlights() async throws -> [VerseHighlight] {
        guard isCloudAvailable else { return [] }

        let query = CKQuery(recordType: RecordType.verseHighlight, predicate: NSPredicate(value: true))
        var allHighlights: [VerseHighlight] = []

        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)

        for (_, result) in results {
            if case .success(let record) = result {
                if let highlight = highlightFromRecord(record) {
                    allHighlights.append(highlight)
                }
            }
        }

        return allHighlights
    }

    func deleteHighlight(reference: String) async throws {
        guard isCloudAvailable else { return }

        let safeRef = reference.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
        let recordID = CKRecord.ID(recordName: "highlight-\(safeRef)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func highlightFromRecord(_ record: CKRecord) -> VerseHighlight? {
        guard let reference = record["reference"] as? String,
              let book = record["book"] as? String,
              let color = record["color"] as? String else {
            return nil
        }

        return VerseHighlight(
            id: record["highlightID"] as? String ?? UUID().uuidString,
            reference: reference,
            book: book,
            chapter: record["chapter"] as? Int ?? 0,
            verse: record["verse"] as? Int ?? 0,
            color: color,
            createdAt: record["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Verse Notes

    func saveNotes(_ notes: [VerseNote]) async throws {
        guard isCloudAvailable, !notes.isEmpty else { return }

        let chunks = notes.chunked(into: 400)
        for chunk in chunks {
            var records: [CKRecord] = []

            for note in chunk {
                let safeRef = note.reference.replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: ":", with: "-")
                let recordID = CKRecord.ID(recordName: "note-\(safeRef)")
                let record = CKRecord(recordType: RecordType.verseNote, recordID: recordID)

                record["noteID"] = note.id as CKRecordValue
                record["reference"] = note.reference as CKRecordValue
                record["book"] = note.book as CKRecordValue
                record["chapter"] = note.chapter as CKRecordValue
                record["verse"] = note.verse as CKRecordValue
                record["content"] = note.content as CKRecordValue
                record["createdAt"] = note.createdAt as CKRecordValue
                record["updatedAt"] = note.updatedAt as CKRecordValue
                record["modifiedAt"] = Date() as CKRecordValue

                records.append(record)
            }

            try await batchSave(records: records)
        }
    }

    func fetchNotes() async throws -> [VerseNote] {
        guard isCloudAvailable else { return [] }

        let query = CKQuery(recordType: RecordType.verseNote, predicate: NSPredicate(value: true))
        var allNotes: [VerseNote] = []

        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)

        for (_, result) in results {
            if case .success(let record) = result {
                if let note = noteFromRecord(record) {
                    allNotes.append(note)
                }
            }
        }

        return allNotes
    }

    func deleteNote(reference: String) async throws {
        guard isCloudAvailable else { return }

        let safeRef = reference.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
        let recordID = CKRecord.ID(recordName: "note-\(safeRef)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func noteFromRecord(_ record: CKRecord) -> VerseNote? {
        guard let reference = record["reference"] as? String,
              let book = record["book"] as? String,
              let content = record["content"] as? String else {
            return nil
        }

        return VerseNote(
            id: record["noteID"] as? String ?? UUID().uuidString,
            reference: reference,
            book: book,
            chapter: record["chapter"] as? Int ?? 0,
            verse: record["verse"] as? Int ?? 0,
            content: content,
            createdAt: record["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date()),
            updatedAt: record["updatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Track Progress

    func saveTrackProgress(_ tracks: [Track]) async throws {
        guard isCloudAvailable else { return }

        var records: [CKRecord] = []

        for track in tracks where track.completedLessons > 0 {
            let recordID = CKRecord.ID(recordName: "progress-\(track.id)")
            let record = CKRecord(recordType: RecordType.trackProgress, recordID: recordID)

            record["trackId"] = track.id as CKRecordValue
            record["completedLessons"] = track.completedLessons as CKRecordValue

            if let lastLesson = track.lessons.last(where: { $0.isCompleted }) {
                record["lastLessonId"] = lastLesson.id as CKRecordValue
            }

            record["modifiedAt"] = Date() as CKRecordValue
            records.append(record)
        }

        if !records.isEmpty {
            try await batchSave(records: records)
        }
    }

    func fetchTrackProgress() async throws -> [(trackId: String, completedLessons: Int, lastLessonId: String?)] {
        guard isCloudAvailable else { return [] }

        let query = CKQuery(recordType: RecordType.trackProgress, predicate: NSPredicate(value: true))
        var progress: [(trackId: String, completedLessons: Int, lastLessonId: String?)] = []

        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)

        for (_, result) in results {
            if case .success(let record) = result {
                if let trackId = record["trackId"] as? String {
                    progress.append((
                        trackId: trackId,
                        completedLessons: record["completedLessons"] as? Int ?? 0,
                        lastLessonId: record["lastLessonId"] as? String
                    ))
                }
            }
        }

        return progress
    }

    // MARK: - Batch Operations

    private func batchSave(records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.isAtomic = false

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    func batchDelete(recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.isAtomic = false

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    // MARK: - Account Deletion

    /// Delete all user data from CloudKit (profile, verses, highlights, notes, track progress)
    func deleteAllData() async throws {
        // Refresh iCloud status before attempting deletion
        await checkAccountStatus()
        guard isCloudAvailable else {
            throw CKError(.networkUnavailable)
        }

        // Delete profile record
        let profileID = CKRecord.ID(recordName: "profile")
        do {
            try await privateDatabase.deleteRecord(withID: profileID)
        } catch let error as CKError where error.code == .unknownItem {
            // Profile doesn't exist in cloud, that's fine
        }

        // Delete all records of each type
        let recordTypes = [
            RecordType.memoryVerse,
            RecordType.verseHighlight,
            RecordType.verseNote,
            RecordType.trackProgress
        ]

        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)

            let recordIDs = results.compactMap { (id, _) in id }
            if !recordIDs.isEmpty {
                // Batch delete in chunks of 400
                let chunks = recordIDs.chunked(into: 400)
                for chunk in chunks {
                    try await batchDelete(recordIDs: chunk)
                }
            }
        }
    }

    // MARK: - Full Sync Helpers

    /// Push all local data to CloudKit (used for first sync after migration)
    func pushAllData(profile: UserProfile, memoryVerses: [MemoryVerse], highlights: [VerseHighlight], notes: [VerseNote], tracks: [Track]) async throws {
        try await saveProfile(profile)
        try await saveMemoryVerses(memoryVerses)
        try await saveHighlights(highlights)
        try await saveNotes(notes)
        try await saveTrackProgress(tracks)
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
