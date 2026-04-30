import Foundation

struct FCBHConfig {
    static let apiKey = "YOUR_FCBH_API_KEY"
    static let otFileset = "ENGKJVO2DA"
    static let ntFileset = "ENGKJVN2DA"
    static let baseURL = "https://4.dbt.io/api/bibles/filesets"
}

class KJVAudioService {
    static let shared = KJVAudioService()
    private init() {}

    private let usfmMap: [String: String] = [
        // Old Testament
        "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV", "Numbers": "NUM",
        "Deuteronomy": "DEU", "Joshua": "JOS", "Judges": "JDG", "Ruth": "RUT",
        "1 Samuel": "1SA", "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
        "1 Chronicles": "1CH", "2 Chronicles": "2CH", "Ezra": "EZR", "Nehemiah": "NEH",
        "Esther": "EST", "Job": "JOB", "Psalms": "PSA", "Proverbs": "PRO",
        "Ecclesiastes": "ECC", "Song of Solomon": "SNG", "Isaiah": "ISA",
        "Jeremiah": "JER", "Lamentations": "LAM", "Ezekiel": "EZK", "Daniel": "DAN",
        "Hosea": "HOS", "Joel": "JOL", "Amos": "AMO", "Obadiah": "OBA",
        "Jonah": "JON", "Micah": "MIC", "Nahum": "NAM", "Habakkuk": "HAB",
        "Zephaniah": "ZEP", "Haggai": "HAG", "Zechariah": "ZEC", "Malachi": "MAL",
        // New Testament
        "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN",
        "Acts": "ACT", "Romans": "ROM", "1 Corinthians": "1CO", "2 Corinthians": "2CO",
        "Galatians": "GAL", "Ephesians": "EPH", "Philippians": "PHP", "Colossians": "COL",
        "1 Thessalonians": "1TH", "2 Thessalonians": "2TH", "1 Timothy": "1TI",
        "2 Timothy": "2TI", "Titus": "TIT", "Philemon": "PHM", "Hebrews": "HEB",
        "James": "JAS", "1 Peter": "1PE", "2 Peter": "2PE", "1 John": "1JN",
        "2 John": "2JN", "3 John": "3JN", "Jude": "JUD", "Revelation": "REV"
    ]

    private let ntBooks: Set<String> = [
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
        "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians",
        "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
        "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
        "1 John", "2 John", "3 John", "Jude", "Revelation"
    ]

    func getAudioURL(book: String, chapter: Int) async throws -> URL {
        guard let usfm = usfmMap[book] else {
            throw KJVAudioError.unknownBook(book)
        }

        let fileset = ntBooks.contains(book) ? FCBHConfig.ntFileset : FCBHConfig.otFileset
        let urlString = "\(FCBHConfig.baseURL)/\(fileset)/\(usfm)/\(chapter)?v=4&key=\(FCBHConfig.apiKey)"

        guard let url = URL(string: urlString) else {
            throw KJVAudioError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw KJVAudioError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoded = try JSONDecoder().decode(FCBHResponse.self, from: data)

        guard let path = decoded.data.first?.path, let audioURL = URL(string: path) else {
            throw KJVAudioError.noAudioFound
        }

        return audioURL
    }
}

enum KJVAudioError: LocalizedError {
    case unknownBook(String)
    case invalidURL
    case httpError(Int)
    case noAudioFound

    var errorDescription: String? {
        switch self {
        case .unknownBook(let b): return "Unknown book: \(b)"
        case .invalidURL: return "Invalid audio URL"
        case .httpError(let code): return "FCBH API error \(code)"
        case .noAudioFound: return "No KJV audio found for this chapter"
        }
    }
}

private struct FCBHResponse: Decodable {
    let data: [FCBHAudioFile]
}

private struct FCBHAudioFile: Decodable {
    let path: String
}
