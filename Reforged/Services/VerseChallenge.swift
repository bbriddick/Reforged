import Foundation

// MARK: - Verse challenge links
//
// "Challenge a friend" shares a verse as a memorize-together invitation. The link opens
// Reforged on the Memory tab with a sheet offering to start that verse. Everything in the
// link is untrusted input: the reference must parse to a real verse and the name is clipped.

struct VerseChallengeInvite: Identifiable, Equatable {
    let id = UUID()
    let reference: String
    let from: String
}

enum VerseChallenge {
    static let host = "memorize"
    static let siteURL = "https://reforgedapp.org"

    static func link(reference: String, from name: String) -> URL? {
        var components = URLComponents()
        components.scheme = "reforged"
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "ref", value: reference),
            URLQueryItem(name: "from", value: name),
        ]
        return components.url
    }

    static func message(reference: String, from name: String) -> String {
        let who = name.trimmingCharacters(in: .whitespaces).isEmpty ? "A friend" : name
        let link = link(reference: reference, from: name)?.absoluteString ?? siteURL
        return """
        \(who) challenged you to memorize \(reference) with Reforged.

        Tap to take the challenge (opens the app): \(link)

        New to Reforged? Get it at \(siteURL)
        """
    }

    /// Accepts reforged://memorize?ref=...&from=... (and the same query on the website's
    /// /memorize path). Returns nil unless the reference is a real, canonical verse.
    static func invite(from url: URL) -> VerseChallengeInvite? {
        let isAppLink = url.scheme?.lowercased() == "reforged" && url.host?.lowercased() == host
        let isWebLink = url.host?.lowercased().hasSuffix("reforgedapp.org") == true
            && url.pathComponents.contains(host)
        guard isAppLink || isWebLink,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let raw = items.first(where: { $0.name == "ref" })?.value,
              let reference = BibleReferenceScanner.detectReferences(in: raw).first?.reference else {
            return nil
        }
        let from = (items.first(where: { $0.name == "from" })?.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return VerseChallengeInvite(reference: memoryReference(reference), from: String(from.prefix(30)))
    }

    /// Memory verses use "Psalm 23:1", the Bible reader's canonical name is "Psalms".
    static func memoryReference(_ reference: String) -> String {
        reference.hasPrefix("Psalms ") ? "Psalm " + reference.dropFirst("Psalms ".count) : reference
    }
}

// MARK: - KJV text for a reference

extension VerseTextFetcher {
    /// Public-domain KJV text for a reference like "John 3:16" or "Psalm 61:1-2".
    static func kjv(reference: String) async throws -> String {
        try await fetch(reference: reference, translation: .kjv).text
    }
}

// MARK: - Finding verses in text copied from another Bible app

enum YouVersionReferenceParser {
    /// USFM book codes used in bible.com links (e.g. JHN.3.16) mapped to Reforged's book names.
    private static let usfm: [String: String] = [
        "GEN": "Genesis", "EXO": "Exodus", "LEV": "Leviticus", "NUM": "Numbers", "DEU": "Deuteronomy",
        "JOS": "Joshua", "JDG": "Judges", "RUT": "Ruth", "1SA": "1 Samuel", "2SA": "2 Samuel",
        "1KI": "1 Kings", "2KI": "2 Kings", "1CH": "1 Chronicles", "2CH": "2 Chronicles", "EZR": "Ezra",
        "NEH": "Nehemiah", "EST": "Esther", "JOB": "Job", "PSA": "Psalms", "PRO": "Proverbs",
        "ECC": "Ecclesiastes", "SNG": "Song of Solomon", "ISA": "Isaiah", "JER": "Jeremiah",
        "LAM": "Lamentations", "EZK": "Ezekiel", "DAN": "Daniel", "HOS": "Hosea", "JOL": "Joel",
        "AMO": "Amos", "OBA": "Obadiah", "JON": "Jonah", "MIC": "Micah", "NAM": "Nahum",
        "HAB": "Habakkuk", "ZEP": "Zephaniah", "HAG": "Haggai", "ZEC": "Zechariah", "MAL": "Malachi",
        "MAT": "Matthew", "MRK": "Mark", "LUK": "Luke", "JHN": "John", "ACT": "Acts", "ROM": "Romans",
        "1CO": "1 Corinthians", "2CO": "2 Corinthians", "GAL": "Galatians", "EPH": "Ephesians",
        "PHP": "Philippians", "COL": "Colossians", "1TH": "1 Thessalonians", "2TH": "2 Thessalonians",
        "1TI": "1 Timothy", "2TI": "2 Timothy", "TIT": "Titus", "PHM": "Philemon", "HEB": "Hebrews",
        "JAS": "James", "1PE": "1 Peter", "2PE": "2 Peter", "1JN": "1 John", "2JN": "2 John",
        "3JN": "3 John", "JUD": "Jude", "REV": "Revelation",
    ]

    private static let usfmRegex = try! NSRegularExpression(
        pattern: #"\b([1-3A-Z][A-Z0-9]{2})\.(\d{1,3})\.(\d{1,3})(?:-(\d{1,3}))?"#)

    /// Every distinct verse found in `text`: written references ("John 3:16") and
    /// bible.com style links ("…/JHN.3.16.NIV"), in the order they appear.
    static func references(in text: String) -> [String] {
        var found: [(position: Int, reference: String)] = []

        for detected in BibleReferenceScanner.detectReferences(in: text) {
            found.append((text.distance(from: text.startIndex, to: detected.range.lowerBound), detected.reference))
        }

        let full = NSRange(text.startIndex..., in: text)
        usfmRegex.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match,
                  let codeRange = Range(match.range(at: 1), in: text),
                  let book = usfm[String(text[codeRange])],
                  let info = BibleData.book(named: book),
                  let chapterRange = Range(match.range(at: 2), in: text),
                  let verseRange = Range(match.range(at: 3), in: text),
                  let chapter = Int(text[chapterRange]), chapter >= 1, chapter <= info.chapters,
                  let verse = Int(text[verseRange]), verse >= 1,
                  let whole = Range(match.range, in: text) else { return }
            var reference = "\(book) \(chapter):\(verse)"
            if match.range(at: 4).location != NSNotFound,
               let endRange = Range(match.range(at: 4), in: text),
               let end = Int(text[endRange]), end > verse {
                reference += "-\(end)"
            }
            found.append((text.distance(from: text.startIndex, to: whole.lowerBound), reference))
        }

        var seen = Set<String>()
        return found.sorted { $0.position < $1.position }
            .map { VerseChallenge.memoryReference($0.reference) }
            .filter { seen.insert($0).inserted }
    }
}
