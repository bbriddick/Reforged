import Foundation
import SQLite3
import CryptoKit

// MARK: - Study Database

/// Read-only access to the bundled Bible study database (`reforged-study.sqlite`).
///
/// The database is built by `tools/study-db` and shipped as `reforged-study.rsdb`, a chunked
/// DEFLATE container (see `tools/study-db/pack.py`). On first launch, or when `data_version`
/// changes, it is expanded into Application Support, its SHA-256 is verified, and it is excluded
/// from iCloud backup. All queries run on one serial queue; callers never block the main thread.
final class StudyDatabase: @unchecked Sendable {
    static let shared = StudyDatabase()

    private let queue = DispatchQueue(label: "com.reforged.studydata", qos: .userInitiated)
    private var handle: OpaquePointer?
    private var attempted = false

    private init() {}

    // MARK: Lifecycle

    /// Starts installing/opening in the background so the first lookup is instant.
    func warmUp() {
        queue.async { [self] in _ = openIfNeeded() }
    }

    /// True when the database is installed and open. Waits for a warm-up already in flight.
    func isReady() async -> Bool {
        await withCheckedContinuation { cont in
            queue.async { [self] in cont.resume(returning: openIfNeeded()) }
        }
    }

    /// Runs `body` against the open database on the serial queue. Returns nil when unavailable.
    func read<T>(_ body: @escaping @Sendable (StudyConnection) -> T) async -> T? {
        await withCheckedContinuation { cont in
            queue.async { [self] in
                guard openIfNeeded(), let handle else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: body(StudyConnection(handle: handle)))
            }
        }
    }

    // MARK: Install + open (serial queue only)

    private func openIfNeeded() -> Bool {
        if handle != nil { return true }
        if attempted { return false }
        attempted = true
        do {
            let url = try Self.installIfNeeded()
            var db: OpaquePointer?
            let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
                if let db { sqlite3_close(db) }
                throw StudyDataError.sqlite("open failed")
            }
            // Cheap sanity check that the file is a real study database of the schema we expect.
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT value FROM meta WHERE key='schema_version'", -1, &stmt, nil) == SQLITE_OK,
                  sqlite3_step(stmt) == SQLITE_ROW else {
                sqlite3_finalize(stmt)
                sqlite3_close(db)
                try? FileManager.default.removeItem(at: url)   // force a clean reinstall next launch
                throw StudyDataError.sqlite("meta table unreadable")
            }
            sqlite3_finalize(stmt)
            handle = db
            // The API-shaped caches are dead weight once the local database serves lookups.
            UserDefaults.standard.removeObject(forKey: "strongs_verse_interlinear_cache")
            UserDefaults.standard.removeObject(forKey: "strongs_detail_cache")
            return true
        } catch {
            debugLog("StudyDatabase: unavailable: \(error)")
            return false
        }
    }

    enum StudyDataError: Error {
        case missingResource
        case corrupt(String)
        case sqlite(String)
    }

    private struct Header: Codable {
        let data_version: String
        let schema_version: Int
        let raw_bytes: Int
        let sha256: String
        let chunk_size: Int
        let chunks: Int
    }

    private static let magic = Data("RSDB1".utf8) + Data([0, 0, 0])

    private static func supportDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("StudyData", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func installIfNeeded() throws -> URL {
        guard let packed = Bundle.main.url(forResource: "reforged-study", withExtension: "rsdb") else {
            throw StudyDataError.missingResource
        }
        let input = try FileHandle(forReadingFrom: packed)
        defer { try? input.close() }

        guard try input.read(upToCount: 8) == magic else { throw StudyDataError.corrupt("bad magic") }
        let headerLength = Int(try readUInt32(input))
        guard let headerData = try input.read(upToCount: headerLength), headerData.count == headerLength else {
            throw StudyDataError.corrupt("short header")
        }
        let header = try JSONDecoder().decode(Header.self, from: headerData)

        let dir = try supportDirectory()
        let dbURL = dir.appendingPathComponent("reforged-study.sqlite")
        let stampURL = dir.appendingPathComponent("installed.json")

        if let stamp = try? Data(contentsOf: stampURL),
           let installed = try? JSONDecoder().decode(Header.self, from: stamp),
           installed.sha256 == header.sha256,
           let size = (try? FileManager.default.attributesOfItem(atPath: dbURL.path)[.size]) as? Int,
           size == header.raw_bytes {
            return dbURL
        }

        // Expand into a partial file, verifying as we go, then move it into place.
        let partial = dir.appendingPathComponent("reforged-study.sqlite.partial")
        try? FileManager.default.removeItem(at: partial)
        FileManager.default.createFile(atPath: partial.path, contents: nil)
        let output = try FileHandle(forWritingTo: partial)
        var hasher = SHA256()
        var written = 0
        do {
            for _ in 0..<header.chunks {
                let compressedLength = Int(try readUInt32(input))
                let rawLength = Int(try readUInt32(input))
                guard let compressed = try input.read(upToCount: compressedLength),
                      compressed.count == compressedLength else { throw StudyDataError.corrupt("short chunk") }
                let expanded = try (compressed as NSData).decompressed(using: .zlib) as Data
                guard expanded.count == rawLength else { throw StudyDataError.corrupt("chunk length") }
                hasher.update(data: expanded)
                try output.write(contentsOf: expanded)
                written += expanded.count
            }
            try output.close()
        } catch {
            try? output.close()
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard written == header.raw_bytes, digest == header.sha256 else {
            try? FileManager.default.removeItem(at: partial)
            throw StudyDataError.corrupt("checksum mismatch")
        }

        try? FileManager.default.removeItem(at: dbURL)
        try FileManager.default.moveItem(at: partial, to: dbURL)
        try JSONEncoder().encode(header).write(to: stampURL, options: .atomic)

        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var mutableURL = dbURL
        try? mutableURL.setResourceValues(excluded)
        return dbURL
    }

    private static func readUInt32(_ handle: FileHandle) throws -> UInt32 {
        guard let data = try handle.read(upToCount: 4), data.count == 4 else {
            throw StudyDataError.corrupt("unexpected end of file")
        }
        return data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }
}

// MARK: - Connection

/// Thin typed view over the open sqlite handle. Only valid inside `StudyDatabase.read`.
struct StudyConnection {
    let handle: OpaquePointer

    enum Arg {
        case int(Int)
        case text(String)
    }

    struct Row {
        fileprivate let stmt: OpaquePointer

        func int(_ i: Int32) -> Int { Int(sqlite3_column_int64(stmt, i)) }
        func isNull(_ i: Int32) -> Bool { sqlite3_column_type(stmt, i) == SQLITE_NULL }
        func text(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: c)
        }
        func optText(_ i: Int32) -> String? { isNull(i) ? nil : text(i) }
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func rows<T>(_ sql: String, _ args: [Arg] = [], _ map: (Row) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            switch arg {
            case .int(let v): sqlite3_bind_int64(stmt, Int32(i + 1), Int64(v))
            case .text(let s): sqlite3_bind_text(stmt, Int32(i + 1), s, -1, Self.transient)
            }
        }
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(map(Row(stmt: stmt)))
        }
        return out
    }
}
