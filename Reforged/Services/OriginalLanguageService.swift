import Foundation
import Combine

// MARK: - Original Language Service

/// Provides original-language word lookup from:
/// - Textus Receptus (trparsed.json) for Greek New Testament
/// - Westminster Leningrad Codex (wlc.json) for Hebrew Old Testament
///
/// The TR file format: verse text is a flat string of `word GNNNN morph` triples.
/// The WLC file format: verse text is pure Hebrew with vowel points and cantillation.
class OriginalLanguageService: ObservableObject {
    static let shared = OriginalLanguageService()
    private init() {}

    /// Published so SwiftUI views re-render when data finishes loading.
    @Published private(set) var trReady = false
    @Published private(set) var wlcReady = false

    // MARK: - Parsed token type

    struct TRToken {
        let word: String        // Greek word as it appears in TR (unaccented lowercase)
        let strongs: String     // Primary Strong's number, e.g. "G976"
        let morph: String       // Morphology code, e.g. "N-NSF"

        /// Human-readable morphology description
        var morphDescription: String {
            OriginalLanguageService.expandMorph(morph)
        }
    }

    // MARK: - Lazy-loaded indexes

    // Key: "bookNumber-chapter-verse", value: array of tokens
    private var trIndex: [String: [TRToken]]?
    private var wlcIndex: [String: [String]]?
    private var trChapterIndex: [String: [(verse: Int, tokens: [TRToken])]]?
    private var wlcChapterIndex: [String: [(verse: Int, words: [String])]]?

    private var trLoaded = false
    private var wlcLoaded = false
    private let loadQueue = DispatchQueue(label: "com.reforged.originallanguage", qos: .utility)

    // MARK: - Public API

    /// Initiates loading of the Textus Receptus (Greek NT) data if not yet loaded.
    func preloadTR() { ensureTRLoaded() }

    /// Initiates loading of the Westminster Leningrad Codex (Hebrew OT) data if not yet loaded.
    func preloadWLC() { ensureWLCLoaded() }

    /// Returns the TR token for a NT verse that matches the given Strong's number.
    func trToken(bookNumber: Int, chapter: Int, verse: Int, strongsNumber: String) -> TRToken? {
        ensureTRLoaded()
        let key = "\(bookNumber)-\(chapter)-\(verse)"
        let normalized = strongsNumber.uppercased()
        return trIndex?[key]?.first { $0.strongs == normalized }
    }

    /// Returns all TR tokens for a NT verse.
    func trTokens(bookNumber: Int, chapter: Int, verse: Int) -> [TRToken] {
        ensureTRLoaded()
        return trIndex?["\(bookNumber)-\(chapter)-\(verse)"] ?? []
    }

    /// Returns the vocalized Hebrew words for an OT verse from the WLC.
    func wlcWords(bookNumber: Int, chapter: Int, verse: Int) -> [String] {
        ensureWLCLoaded()
        return wlcIndex?["\(bookNumber)-\(chapter)-\(verse)"] ?? []
    }

    /// Returns all TR token arrays for a NT chapter, sorted by verse number.
    func trChapter(bookNumber: Int, chapter: Int) -> [(verse: Int, tokens: [TRToken])] {
        ensureTRLoaded()
        return trChapterIndex?["\(bookNumber)-\(chapter)"] ?? []
    }

    /// Returns all WLC word arrays for an OT chapter, sorted by verse number.
    func wlcChapter(bookNumber: Int, chapter: Int) -> [(verse: Int, words: [String])] {
        ensureWLCLoaded()
        return wlcChapterIndex?["\(bookNumber)-\(chapter)"] ?? []
    }

    /// Maps a Bible book name (English) to its standard book number (1–66).
    static func bookNumber(for name: String) -> Int? {
        bookNumberMap[name.lowercased()]
    }

    /// Strips cantillation marks and vowel points from a Hebrew word, returning only consonants.
    ///
    /// Unicode ranges removed:
    ///   U+0591–U+05AF  Hebrew cantillation (trope) marks
    ///   U+05B0–U+05BD  Hebrew vowel points (niqqud)
    ///   U+05BF          Hebrew point rafe
    ///   U+05C1–U+05C7  Hebrew shin/sin dots and other combining marks
    ///
    /// Hebrew consonants (U+05D0–U+05EA) and all non-Hebrew characters are preserved.
    static func stripCantillation(_ word: String) -> String {
        word.unicodeScalars.filter { scalar in
            let v = scalar.value
            // Keep: Hebrew consonants (alef–tav) and anything outside the Hebrew combining block
            let isHebrewConsonant = (v >= 0x05D0 && v <= 0x05EA)
            let isHebrewCombining = (v >= 0x0591 && v <= 0x05C7)
            return isHebrewConsonant || !isHebrewCombining
        }
        .map { String($0) }
        .joined()
    }

    // MARK: - Loading

    private func ensureTRLoaded() {
        guard !trLoaded else { return }
        trLoaded = true
        guard let url = Bundle.main.url(forResource: "trparsed", withExtension: "json") else { return }
        loadQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: url) else { return }
            struct TRFile: Decodable {
                struct Verse: Decodable {
                    let book: Int
                    let chapter: Int
                    let verse: Int
                    let text: String
                }
                let verses: [Verse]
            }
            guard let file = try? JSONDecoder().decode(TRFile.self, from: data) else { return }
            var index: [String: [TRToken]] = [:]
            var chapterIndex: [String: [(verse: Int, tokens: [TRToken])]] = [:]
            for v in file.verses {
                let tokens = self.parseTRText(v.text)
                guard !tokens.isEmpty else { continue }
                index["\(v.book)-\(v.chapter)-\(v.verse)"] = tokens
                chapterIndex["\(v.book)-\(v.chapter)", default: []].append((verse: v.verse, tokens: tokens))
            }
            for key in chapterIndex.keys {
                chapterIndex[key]?.sort { $0.verse < $1.verse }
            }
            DispatchQueue.main.async {
                self.trIndex = index
                self.trChapterIndex = chapterIndex
                self.trReady = true
            }
        }
    }

    private func ensureWLCLoaded() {
        guard !wlcLoaded else { return }
        wlcLoaded = true
        guard let url = Bundle.main.url(forResource: "wlc", withExtension: "json") else { return }
        loadQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: url) else { return }
            struct WLCFile: Decodable {
                struct Verse: Decodable {
                    let book: Int
                    let chapter: Int
                    let verse: Int
                    let text: String
                }
                let verses: [Verse]
            }
            guard let file = try? JSONDecoder().decode(WLCFile.self, from: data) else { return }
            var index: [String: [String]] = [:]
            var chapterIndex: [String: [(verse: Int, words: [String])]] = [:]
            for v in file.verses {
                let words = self.parseWLCWords(v.text)
                guard !words.isEmpty else { continue }
                index["\(v.book)-\(v.chapter)-\(v.verse)"] = words
                chapterIndex["\(v.book)-\(v.chapter)", default: []].append((verse: v.verse, words: words))
            }
            for key in chapterIndex.keys {
                chapterIndex[key]?.sort { $0.verse < $1.verse }
            }
            DispatchQueue.main.async {
                self.wlcIndex = index
                self.wlcChapterIndex = chapterIndex
                self.wlcReady = true
            }
        }
    }

    // MARK: - TR Parser

    /// Parses TR text: space-separated groups of `greekWord [G/H-number]+ morphCode`
    private func parseTRText(_ text: String) -> [TRToken] {
        let parts = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var tokens: [TRToken] = []
        var i = 0
        while i < parts.count {
            let part = parts[i]
            guard isGreekWord(part) else { i += 1; continue }
            // Collect Strong's number(s) immediately after the word
            var strongs = ""
            var j = i + 1
            while j < parts.count && isStrongsNumber(parts[j]) {
                if strongs.isEmpty { strongs = parts[j] }
                j += 1
            }
            // Morphology code follows the Strongs number(s)
            var morph = ""
            if j < parts.count && isMorphCode(parts[j]) {
                morph = parts[j]
                j += 1
            }
            tokens.append(TRToken(word: part, strongs: strongs, morph: morph))
            i = j
        }
        return tokens
    }

    private func isGreekWord(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first else { return false }
        // Greek characters: U+0370–U+03FF (Greek and Coptic block)
        return first.value >= 0x0370 && first.value <= 0x03FF
    }

    private func isStrongsNumber(_ s: String) -> Bool {
        guard s.count >= 2, let first = s.first, (first == "G" || first == "H") else { return false }
        return s.dropFirst().allSatisfy { $0.isNumber }
    }

    private func isMorphCode(_ s: String) -> Bool {
        let prefixes = ["N-", "V-", "T-", "A-", "P-", "R-", "C-", "D-", "I-", "X-", "F-", "K-"]
        let keywords = ["CONJ", "PREP", "ADV", "PRT", "INJ"]
        return prefixes.contains(where: { s.hasPrefix($0) }) || keywords.contains(s)
    }

    // MARK: - WLC Parser

    /// Splits Hebrew text into vocalized words, stripping sof pasuq and paragraph marks.
    private func parseWLCWords(_ text: String) -> [String] {
        text.components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "׃׀")) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Morphology Expansion

    // Expands TR morphology codes into human-readable descriptions.
    // Format: POS-CASE(Noun)/TENSE-VOICE-MOOD-PERSON-NUMBER(Verb)-NUMBER-GENDER
    static func expandMorph(_ code: String) -> String {
        guard !code.isEmpty else { return "" }
        // Simple keyword codes
        switch code {
        case "CONJ":  return "Conjunction"
        case "PREP":  return "Preposition"
        case "ADV":   return "Adverb"
        case "PRT":   return "Particle"
        case "INJ":   return "Interjection"
        default: break
        }
        let parts = code.components(separatedBy: "-")
        guard let posCode = parts.first else { return code }

        var components: [String] = []

        switch posCode {
        case "N": components.append("Noun")
        case "V": components.append("Verb")
        case "T": components.append("Article")
        case "A": components.append("Adjective")
        case "P": components.append("Pronoun")
        case "R": components.append("Relative Pronoun")
        case "C": components.append("Reciprocal Pronoun")
        case "D": components.append("Demonstrative Pronoun")
        case "I": components.append("Interrogative Pronoun")
        case "X": components.append("Indefinite Pronoun")
        case "F": components.append("Reflexive Pronoun")
        case "K": components.append("Correlative Pronoun")
        default: components.append(posCode)
        }

        if posCode == "V" && parts.count >= 2 {
            // Verb: TENSE-VOICE-MOOD then optional -PERSON-NUMBER or -NUMBER-GENDER
            let tvmRaw = parts.count > 1 ? parts[1] : ""
            // Tense (1st char), Voice (2nd), Mood (3rd)
            if tvmRaw.count >= 1 {
                switch tvmRaw.prefix(1) {
                case "P": components.append("Present")
                case "I": components.append("Imperfect")
                case "F": components.append("Future")
                case "A": components.append("Aorist")
                case "X": components.append("Perfect")
                case "Y": components.append("Pluperfect")
                default: break
                }
            }
            if tvmRaw.count >= 2 {
                switch tvmRaw.dropFirst().prefix(1) {
                case "A": components.append("Active")
                case "M": components.append("Middle")
                case "P": components.append("Passive")
                case "E": components.append("Middle/Passive")
                case "D": components.append("Middle Deponent")
                case "O": components.append("Passive Deponent")
                case "N": components.append("Middle or Passive Deponent")
                default: break
                }
            }
            if tvmRaw.count >= 3 {
                switch tvmRaw.dropFirst(2).prefix(1) {
                case "I": components.append("Indicative")
                case "S": components.append("Subjunctive")
                case "O": components.append("Optative")
                case "M": components.append("Imperative")
                case "N": components.append("Infinitive")
                case "P": components.append("Participle")
                default: break
                }
            }
            // Person-Number (e.g. 3S)
            if parts.count >= 3 {
                let pn = parts[2]
                if pn.count >= 1 {
                    switch pn.prefix(1) {
                    case "1": components.append("1st Person")
                    case "2": components.append("2nd Person")
                    case "3": components.append("3rd Person")
                    default: break
                    }
                }
                if pn.count >= 2 {
                    switch pn.dropFirst().prefix(1) {
                    case "S": components.append("Singular")
                    case "P": components.append("Plural")
                    default: break
                    }
                }
            }
        } else {
            // Noun/Article/Pronoun etc.: parse case, number, gender from remaining part
            let rest = parts.dropFirst().joined()
            expandCaseNumberGender(rest, into: &components)
        }

        return components.joined(separator: " · ")
    }

    private static func expandCaseNumberGender(_ s: String, into components: inout [String]) {
        guard !s.isEmpty else { return }
        // PRI = Proper Name Indeclinable
        if s == "PRI" { components.append("Proper Name"); return }
        if s.contains("PRI") { components.append("Proper Name"); return }

        // Case (1st char)
        switch s.prefix(1) {
        case "N": components.append("Nominative")
        case "G": components.append("Genitive")
        case "D": components.append("Dative")
        case "A": components.append("Accusative")
        case "V": components.append("Vocative")
        default: break
        }
        // Number (2nd char)
        if s.count >= 2 {
            switch s.dropFirst().prefix(1) {
            case "S": components.append("Singular")
            case "P": components.append("Plural")
            default: break
            }
        }
        // Gender (3rd char)
        if s.count >= 3 {
            switch s.dropFirst(2).prefix(1) {
            case "M": components.append("Masculine")
            case "F": components.append("Feminine")
            case "N": components.append("Neuter")
            default: break
            }
        }
    }

    // MARK: - Book Number Map

    /// Standard Bible book numbers (1–66). NT starts at 40 (Matthew).
    private static let bookNumberMap: [String: Int] = [
        // Old Testament
        "genesis": 1, "exodus": 2, "leviticus": 3, "numbers": 4, "deuteronomy": 5,
        "joshua": 6, "judges": 7, "ruth": 8, "1 samuel": 9, "2 samuel": 10,
        "1 kings": 11, "2 kings": 12, "1 chronicles": 13, "2 chronicles": 14,
        "ezra": 15, "nehemiah": 16, "esther": 17, "job": 18, "psalms": 19, "psalm": 19,
        "proverbs": 20, "ecclesiastes": 21, "song of solomon": 22, "song of songs": 22,
        "isaiah": 23, "jeremiah": 24, "lamentations": 25, "ezekiel": 26, "daniel": 27,
        "hosea": 28, "joel": 29, "amos": 30, "obadiah": 31, "jonah": 32, "micah": 33,
        "nahum": 34, "habakkuk": 35, "zephaniah": 36, "haggai": 37, "zechariah": 38,
        "malachi": 39,
        // New Testament
        "matthew": 40, "mark": 41, "luke": 42, "john": 43, "acts": 44,
        "romans": 45, "1 corinthians": 46, "2 corinthians": 47, "galatians": 48,
        "ephesians": 49, "philippians": 50, "colossians": 51,
        "1 thessalonians": 52, "2 thessalonians": 53,
        "1 timothy": 54, "2 timothy": 55, "titus": 56, "philemon": 57,
        "hebrews": 58, "james": 59, "1 peter": 60, "2 peter": 61,
        "1 john": 62, "2 john": 63, "3 john": 64, "jude": 65, "revelation": 66
    ]
}
