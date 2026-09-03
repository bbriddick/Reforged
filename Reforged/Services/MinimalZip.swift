import Foundation
import Compression

/// A tiny, dependency-free reader for the single-file ZIP archives that host the downloadable
/// commentaries (see `CommentaryDownloadManager`). It reads the central directory (the macOS
/// "Compress" zips use data descriptors, so local-header sizes are zero) and inflates the raw
/// DEFLATE payload with the system `Compression` framework. Only what we need — no general ZIP
/// support, no encryption, no ZIP64.
enum MinimalZip {

    /// Extracts the first `.json` member (ignoring macOS `__MACOSX/` resource forks) and returns
    /// its decompressed bytes, or nil if the archive can't be read.
    static func extractJSON(from data: Data) -> Data? {
        guard let eocd = findEOCD(in: data) else { return nil }
        let bytes = [UInt8](data)

        var offset = eocd.centralDirectoryOffset
        for _ in 0..<eocd.entryCount {
            guard offset + 46 <= bytes.count,
                  readU32(bytes, offset) == 0x02014b50 else { return nil }

            let method = Int(readU16(bytes, offset + 10))
            let compressedSize = Int(readU32(bytes, offset + 20))
            let uncompressedSize = Int(readU32(bytes, offset + 24))
            let nameLen = Int(readU16(bytes, offset + 28))
            let extraLen = Int(readU16(bytes, offset + 30))
            let commentLen = Int(readU16(bytes, offset + 32))
            let localOffset = Int(readU32(bytes, offset + 42))

            let nameStart = offset + 46
            guard nameStart + nameLen <= bytes.count else { return nil }
            let name = String(decoding: bytes[nameStart..<nameStart + nameLen], as: UTF8.self)

            if name.hasSuffix(".json") && !name.hasPrefix("__MACOSX/") {
                return payload(bytes, localOffset: localOffset, method: method,
                               compressedSize: compressedSize, uncompressedSize: uncompressedSize)
            }
            offset = nameStart + nameLen + extraLen + commentLen
        }
        return nil
    }

    // MARK: - Central directory

    private struct EOCD { let entryCount: Int; let centralDirectoryOffset: Int }

    /// Scans backward for the End Of Central Directory record (signature PK\05\06).
    private static func findEOCD(in data: Data) -> EOCD? {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { return nil }
        // The EOCD is at least 22 bytes; its comment (usually empty) can be up to 65535.
        let minStart = max(0, bytes.count - 22 - 65_535)
        var i = bytes.count - 22
        while i >= minStart {
            if readU32(bytes, i) == 0x06054b50 {
                return EOCD(entryCount: Int(readU16(bytes, i + 10)),
                            centralDirectoryOffset: Int(readU32(bytes, i + 16)))
            }
            i -= 1
        }
        return nil
    }

    /// Reads the entry's compressed bytes from its local header and inflates them.
    private static func payload(_ bytes: [UInt8], localOffset: Int, method: Int,
                                compressedSize: Int, uncompressedSize: Int) -> Data? {
        guard localOffset + 30 <= bytes.count, readU32(bytes, localOffset) == 0x04034b50 else { return nil }
        // The local header's own name/extra lengths (may differ from the central copy).
        let nameLen = Int(readU16(bytes, localOffset + 26))
        let extraLen = Int(readU16(bytes, localOffset + 28))
        let dataStart = localOffset + 30 + nameLen + extraLen
        guard dataStart + compressedSize <= bytes.count else { return nil }

        let compressed = Array(bytes[dataStart..<dataStart + compressedSize])
        if method == 0 {                       // stored
            return Data(compressed)
        }
        guard method == 8 else { return nil }  // only DEFLATE supported

        var dest = [UInt8](repeating: 0, count: uncompressedSize)
        let written = compressed.withUnsafeBufferPointer { src in
            dest.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, uncompressedSize,
                                          src.baseAddress!, compressedSize,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == uncompressedSize else { return nil }
        return Data(dest)
    }

    // MARK: - Little-endian readers

    private static func readU16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
    }

    private static func readU32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }
}
