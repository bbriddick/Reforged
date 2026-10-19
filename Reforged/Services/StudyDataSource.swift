import Foundation

// MARK: - Feature flag

/// `useLocalStudyData` (default on) serves Word Study from the bundled database. Turning it off
/// restores the Complete Study Bible API path until that code is removed after cutover.
enum StudyDataFlags {
    static let key = "useLocalStudyData"

    static var useLocal: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

// MARK: - Contract

/// What Word Study needs from a data source. `nil` means "no data for this request", in which
/// case callers fall back to the bundled dictionaries exactly as they did for API failures.
protocol StudyDataSource {
    /// Tapped English word in a verse (any English translation; matched against the KJV tags).
    func lookupWord(_ word: String, verseReference: String, bookName: String,
                    chapter: Int, verseNumber: Int) async -> WordLookupResult?

    /// A Strong's number already known (TR token, study chip).
    func lookupByStrongsNumber(_ strongsNumber: String, tappedWord: String, originalForm: String,
                               verseReference: String, bookName: String,
                               chapter: Int, verseNumber: Int) async -> WordLookupResult?

    /// A tapped word in the Hebrew reader (Hebrew versification).
    func lookupWLCWord(_ hebrewWord: String, verseReference: String, bookName: String,
                       chapter: Int, verseNumber: Int) async -> WordLookupResult?

    /// Verses in the Hebrew Bible that contain a Strong's number, for the concordance.
    func hebrewOccurrences(strongsNumber: String) async -> [BibleSearchResult]?
}

// MARK: - Local (SQLite) implementation

final class LocalStudyDataSource: StudyDataSource {
    static let shared = LocalStudyDataSource()
    private let database = StudyDatabase.shared
    private init() {}

    private static let functionTags: Set<String> = ["G3588", "H853"]
    // The long lexicon entry sits behind "Read the full entry", so it is not cut short.
    private static let detailLimit = 12_000

    // MARK: Lookups

    func lookupWord(_ word: String, verseReference: String, bookName: String,
                    chapter: Int, verseNumber: Int) async -> WordLookupResult? {
        guard let vid = Self.verseID(bookName: bookName, chapter: chapter, verse: verseNumber) else { return nil }
        let target = Self.normalize(word)
        guard !target.isEmpty else { return nil }

        let found: WordLookupResult?? = await database.read { c in
            struct Tok {
                let position: Int
                let word: String
                let strongs: String
                let edition: String?
                let origPosition: Int?
                let quality: StudyMatchQuality
            }
            let toks = c.rows("""
                SELECT position, word, strongs, orig_edition, orig_position, match_quality
                FROM kjv_tokens WHERE verse_id=? AND strongs<>'' AND word<>'' ORDER BY position, strongs
                """, [.int(vid)]) { r in
                Tok(position: r.int(0), word: r.text(1), strongs: r.text(2), edition: r.optText(3),
                    origPosition: r.isNull(4) ? nil : r.int(4),
                    quality: StudyMatchQuality(rawValue: r.optText(5) ?? "") ?? .none)
            }
            // Whole-word match first, then substring (compound phrases such as "only begotten").
            func hit(_ t: Tok, wholeWord: Bool) -> Bool {
                let phrase = Self.normalize(t.word)
                return wholeWord ? phrase.split(separator: " ").contains(Substring(target)) : phrase.contains(target)
            }
            let anchor = toks.first(where: { hit($0, wholeWord: true) }) ?? toks.first(where: { hit($0, wholeWord: false) })
            guard let anchor else { return nil }

            // A phrase can carry several numbers ("the Word" = article + noun); prefer the content word.
            let candidates = toks.filter { $0.position == anchor.position }.sorted { a, b in
                let fa = Self.functionTags.contains(a.strongs), fb = Self.functionTags.contains(b.strongs)
                if fa != fb { return !fa }
                if a.quality.rank != b.quality.rank { return a.quality.rank < b.quality.rank }
                return a.strongs < b.strongs
            }
            guard let pick = candidates.first else { return nil }

            var originalForm = ""
            var grammar: Grammar?
            if let edition = pick.edition, let op = pick.origPosition {
                let row = c.rows("""
                    SELECT COALESCE(o.surface_accented, o.surface), COALESCE(o.morph,''), COALESCE(m.expansion,'')
                    FROM original_tokens o LEFT JOIN morph_codes m ON m.code = o.morph
                    WHERE o.verse_id=? AND o.edition=? AND o.position=?
                    """, [.int(vid), .text(edition), .int(op)]) { ($0.text(0), $0.text(1), $0.text(2)) }.first
                originalForm = row?.0 ?? ""
                if let row, !row.1.isEmpty { grammar = Grammar(code: row.1, expansion: row.2) }
            }
            return Self.assemble(c, strongs: pick.strongs, tappedWord: word, originalForm: originalForm,
                                 verseReference: verseReference, bookName: bookName, chapter: chapter,
                                 verseNumber: verseNumber, quality: pick.quality, grammar: grammar)
        }
        return found ?? nil
    }

    func lookupByStrongsNumber(_ strongsNumber: String, tappedWord: String, originalForm: String,
                               verseReference: String, bookName: String,
                               chapter: Int, verseNumber: Int) async -> WordLookupResult? {
        guard let strongs = Self.canonical(strongsNumber) else { return nil }
        let vid = Self.verseID(bookName: bookName, chapter: chapter, verse: verseNumber)
        let result: WordLookupResult?? = await database.read { c in
            var form = originalForm
            var grammar: Grammar?
            // The reader shows unaccented TR words; the study sheet shows the accented form and
            // the grammar of that exact word.
            if let vid, !originalForm.isEmpty {
                let row = c.rows("""
                    SELECT COALESCE(o.surface_accented, o.surface), COALESCE(o.morph,''), COALESCE(m.expansion,'')
                    FROM original_tokens o LEFT JOIN morph_codes m ON m.code = o.morph
                    WHERE o.verse_id=? AND o.edition=? AND o.surface=? AND o.strongs=? LIMIT 1
                    """, [.int(vid), .text(strongs.hasPrefix("G") ? "TR" : "WLC"), .text(originalForm), .text(strongs)]) {
                    ($0.text(0), $0.text(1), $0.text(2))
                }.first
                if let row {
                    form = row.0
                    if !row.1.isEmpty { grammar = Grammar(code: row.1, expansion: row.2) }
                }
            }
            return Self.assemble(c, strongs: strongs, tappedWord: tappedWord, originalForm: form,
                                 verseReference: verseReference, bookName: bookName, chapter: chapter,
                                 verseNumber: verseNumber, quality: .exact, grammar: grammar)
        }
        return result ?? nil
    }

    func lookupWLCWord(_ hebrewWord: String, verseReference: String, bookName: String,
                       chapter: Int, verseNumber: Int) async -> WordLookupResult? {
        guard let bookID = Self.bookID(bookName) else { return nil }
        let tapped = OriginalLanguageService.stripCantillation(hebrewWord)
        guard !tapped.isEmpty else { return nil }
        let kjvStyleID = bookID * 1_000_000 + chapter * 1_000 + verseNumber

        let result: WordLookupResult?? = await database.read { c in
            // The reader uses Hebrew versification. Words that moved to another KJV verse carry
            // their Hebrew reference in src_ref; the rest sit under the same number.
            let osis = c.rows("SELECT osis FROM books WHERE book_id=?", [.int(bookID)]) { $0.text(0) }.first ?? ""
            let words = c.rows("""
                SELECT o.surface, o.strongs, COALESCE(o.morph,''), COALESCE(m.expansion,'')
                FROM original_tokens o LEFT JOIN morph_codes m ON m.code = o.morph
                WHERE o.edition='WLC' AND (o.src_ref=? OR (o.src_ref IS NULL AND o.verse_id=?)) AND o.strongs<>''
                ORDER BY o.verse_id, o.position
                """, [.text("\(osis).\(chapter).\(verseNumber)"), .int(kjvStyleID)]) {
                ($0.text(0), $0.text(1), $0.text(2), $0.text(3))
            }

            // Exact consonant match first ("ברא" must not resolve to "בראשית", which contains it).
            let match = words.first { OriginalLanguageService.stripCantillation($0.0) == tapped }
                ?? words.first { w in
                    let s = OriginalLanguageService.stripCantillation(w.0)
                    return s.contains(tapped) || tapped.contains(s)
                }
            guard let match else { return nil }
            return Self.assemble(c, strongs: match.1, tappedWord: hebrewWord, originalForm: match.0,
                                 verseReference: verseReference, bookName: bookName, chapter: chapter,
                                 verseNumber: verseNumber, quality: .exact,
                                 grammar: match.2.isEmpty ? nil : Grammar(code: match.2, expansion: match.3))
        }
        return result ?? nil
    }

    /// A key word of a verse for the verse sheet's Word Study chips, from the original-language
    /// text with exact morphology: Greek for the New Testament, Hebrew/Aramaic for the Old.
    struct StudyKeyWord {
        let surface: String          // Greek accented / Hebrew pointed, as used in the verse
        let strongs: String
        let transliteration: String
        let partOfSpeech: String     // "verb" | "infinitive" | "noun" | "name"
        let english: String?         // how the KJV renders it in this verse
        let grammar: String
    }

    /// Nouns and verbs of the verse in reading order, one per Strong's number. `verse` uses the
    /// KJV numbering the reader's English text uses.
    func keyWords(bookName: String, chapter: Int, verse: Int, limit: Int = 10) async -> [StudyKeyWord] {
        guard let vid = Self.verseID(bookName: bookName, chapter: chapter, verse: verse),
              let bookID = Self.bookID(bookName) else { return [] }
        let greek = bookID >= 40
        struct Row {
            let surface, strongs, morph, expansion, translit: String
            let english: String?
            let usageTop: String?
            let inTitle: Bool
        }
        let rows: [Row] = await database.read { c in
            c.rows("""
                SELECT COALESCE(o.surface_accented, o.surface), o.strongs, COALESCE(o.morph,''),
                       COALESCE(m.expansion,''), COALESCE(e.translit,''), k.word, COALESCE(k.in_title, 0),
                       (SELECT english_word FROM strongs_usage u WHERE u.strongs = o.strongs
                        ORDER BY count DESC, english_word LIMIT 1)
                FROM original_tokens o
                LEFT JOIN morph_codes m ON m.code = o.morph
                LEFT JOIN strongs_entries e ON e.strongs = o.strongs
                LEFT JOIN kjv_tokens k ON k.verse_id = o.verse_id AND k.orig_edition = o.edition
                                      AND k.orig_position = o.position AND k.strongs = o.strongs
                WHERE o.verse_id=? AND o.edition=? AND o.strongs<>''
                ORDER BY o.position
                """, [.int(vid), .text(greek ? "TR" : "WLC")]) {
                Row(surface: $0.text(0), strongs: $0.text(1), morph: $0.text(2), expansion: $0.text(3),
                    translit: $0.text(4), english: $0.optText(5), usageTop: $0.optText(7),
                    inTitle: $0.int(6) == 1)
            }
        } ?? []

        var seen = Set<String>()
        var out: [StudyKeyWord] = []
        for r in rows {
            // Psalm titles ("A Psalm of David") are not the verse's own words.
            guard !r.inTitle,
                  let pos = Self.contentPartOfSpeech(morph: r.morph, greek: greek),
                  seen.insert(r.strongs).inserted else { continue }
            out.append(StudyKeyWord(surface: r.surface, strongs: r.strongs, transliteration: r.translit,
                                    partOfSpeech: pos,
                                    // The verse's own wording; else the lexicon's most common rendering.
                                    english: r.english.flatMap(Self.tidyRendering) ?? r.usageTop,
                                    grammar: r.expansion))
            if out.count >= limit { break }
        }
        return out
    }

    /// A KJV phrase reduced to a label: "the heaven" -> "heaven", "For, behold, the day" -> nil
    /// (too long to read as one word's rendering).
    static func tidyRendering(_ phrase: String) -> String? {
        let leading: Set<String> = [
            "the", "a", "an", "and", "of", "to", "in", "unto", "for", "his", "my", "thy", "their", "her",
            "our", "then", "but", "that", "which", "he", "she", "it", "they", "we", "i", "ye", "thou",
            "you", "not", "no", "should", "shall", "will", "would", "may", "might", "can", "could",
            "have", "hath", "had", "has", "do", "doth", "did", "is", "are", "was", "were", "be", "been",
        ]
        var words = phrase
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        while words.count > 1, let first = words.first, leading.contains(first.lowercased()) { words.removeFirst() }
        // A lone auxiliary ("should", "shall") says nothing about the word; let the caller fall back.
        if words.count == 1, let only = words.first, leading.contains(only.lowercased()),
           !["are", "is", "was", "were", "be", "been"].contains(only.lowercased()) { return nil }
        guard !words.isEmpty, words.count <= 3, !phrase.contains(",") else { return nil }
        return words.joined(separator: " ")
    }

    /// Robinson ('V-PAN', 'N-PRI') or OSHB ('HR/Ncfsa', 'HVqp3ms/Sp3fs') code to a content part of
    /// speech; prefixes, suffixes and everything that is not a noun or verb return nil.
    static func contentPartOfSpeech(morph: String, greek: Bool) -> String? {
        if greek {
            let parts = morph.split(separator: "-")
            guard let head = parts.first else { return nil }
            switch head {
            case "V":
                return parts.count > 1 && parts[1].last == "N" && parts[1].count == 3 ? "infinitive" : "verb"
            case "N":
                return parts.count > 1 && parts[1] == "PRI" ? "name" : "noun"
            default:
                return nil
            }
        }
        guard morph.count > 1 else { return nil }
        for segment in morph.dropFirst().split(separator: "/") {
            switch segment.first {
            case "V": return "verb"
            case "N": return segment.dropFirst().first == "p" ? "name" : "noun"
            default: continue
            }
        }
        return nil
    }

    func hebrewOccurrences(strongsNumber: String) async -> [BibleSearchResult]? {
        guard let strongs = Self.canonical(strongsNumber), strongs.hasPrefix("H") else { return nil }
        let results: [BibleSearchResult]? = await database.read { c in
            struct W { let verseID: Int; let ref: String?; let surface: String; let strongs: String; let alt: String }
            let words = c.rows("""
                SELECT o.verse_id, o.src_ref, o.surface, o.strongs, COALESCE(o.alt_strongs, '')
                FROM original_tokens o
                WHERE o.edition='WLC'
                  AND o.verse_id IN (SELECT verse_id FROM strongs_occurrences WHERE strongs=?)
                ORDER BY o.verse_id, o.position
                """, [.text(strongs)]) { W(verseID: $0.int(0), ref: $0.optText(1), surface: $0.text(2),
                                           strongs: $0.text(3), alt: $0.text(4)) }

            var order: [Int] = []
            var byVerse: [Int: [W]] = [:]
            for w in words {
                if byVerse[w.verseID] == nil { order.append(w.verseID) }
                byVerse[w.verseID, default: []].append(w)
            }
            return order.compactMap { vid -> BibleSearchResult? in
                guard let verseWords = byVerse[vid] else { return nil }
                let bookNumber = vid / 1_000_000
                guard bookNumber >= 1, bookNumber <= BibleData.books.count else { return nil }
                // Report the Hebrew reference of the word itself (it can differ from the KJV verse).
                var chapter = (vid / 1_000) % 1_000, verse = vid % 1_000
                if let hit = verseWords.first(where: { $0.strongs == strongs || $0.alt.split(separator: " ").contains(Substring(strongs)) }),
                   let ref = hit.ref {
                    let parts = ref.split(separator: ".")
                    if parts.count >= 3, let c = Int(parts[parts.count - 2]), let v = Int(parts[parts.count - 1]) {
                        chapter = c; verse = v
                    }
                }
                return BibleSearchResult(
                    reference: "\(BibleData.books[bookNumber - 1].name) \(chapter):\(verse)",
                    content: verseWords.map(\.surface).joined(separator: " "),
                    translation: .wlc,
                    metadata: strongs
                )
            }
        }
        return results
    }

    // MARK: Assembly

    /// Builds the same `WordLookupResult` the API used to produce, from one Strong's number.
    private struct Grammar { let code: String; let expansion: String }

    private static func assemble(_ c: StudyConnection, strongs: String, tappedWord: String, originalForm: String,
                                 verseReference: String, bookName: String, chapter: Int, verseNumber: Int,
                                 quality: StudyMatchQuality, grammar: Grammar? = nil) -> WordLookupResult? {
        struct Entry { let language: String; let lemma: String; let translit: String; let pron: String
                       let definition: String; let kjvDef: String; let derivation: String; let occurrences: Int }
        guard let e = c.rows("""
            SELECT language, lemma, COALESCE(translit,''), COALESCE(pron,''), COALESCE(definition,''),
                   COALESCE(kjv_def,''), COALESCE(derivation,''), occurrences
            FROM strongs_entries WHERE strongs=?
            """, [.text(strongs)], { Entry(language: $0.text(0), lemma: $0.text(1), translit: $0.text(2),
                                           pron: $0.text(3), definition: $0.text(4), kjvDef: $0.text(5),
                                           derivation: $0.text(6), occurrences: $0.int(7)) }).first else { return nil }

        let isGreek = strongs.hasPrefix("G")
        // Long-form lexicon: Abbott-Smith for Greek, BDB for Hebrew and Aramaic.
        let longForm = c.rows("""
            SELECT body_text FROM lexicon_entries WHERE strongs=? AND source=? ORDER BY rowid
            """, [.text(strongs), .text(isGreek ? "abbott-smith" : "bdb")]) { $0.text(0) }
            .joined(separator: "\n\n")

        let usage = c.rows("""
            SELECT english_word, count FROM strongs_usage WHERE strongs=? ORDER BY count DESC, english_word LIMIT 10
            """, [.text(strongs)]) { (word: $0.text(0), count: $0.int(1)) }

        var result = WordLookupResult(
            tappedWord: tappedWord,
            verseReference: verseReference,
            bookName: bookName,
            chapterNumber: chapter,
            verseNumber: verseNumber,
            isHebrew: !isGreek,
            isFromAPI: true,
            originalWord: originalForm.isEmpty ? e.lemma : originalForm,
            lexicalForm: e.lemma,
            strongsNumber: strongs,
            transliteration: e.translit,
            pronunciation: e.pron,
            strongsDefinition: e.definition,
            detailedDefinition: truncated(longForm, to: detailLimit),
            mounceDefinition: "",
            kjvUsage: e.kjvDef,
            derivation: e.derivation,
            occurrenceCount: e.occurrences,
            translationCounts: usage,
            strongsEntries: []
        )
        result.matchQuality = quality
        result.isAramaic = e.language == "arc"
        result.detailedSourceLabel = isGreek ? "Abbott-Smith Lexicon" : "Brown-Driver-Briggs"
        result.morphCode = grammar?.code
        result.morphExpansion = (grammar?.expansion.isEmpty ?? true) ? nil : grammar?.expansion
        return result
    }

    // MARK: Helpers

    private static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        if let space = cut.lastIndex(of: " ") { return String(cut[..<space]) + "…" }
        return String(cut) + "…"
    }

    /// 'G0976' / 'g976' / 'H430a' -> 'G976' / 'H430'. nil if it is not a Strong's number.
    static func canonical(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard let prefix = s.first, prefix == "G" || prefix == "H" else { return nil }
        let digits = s.dropFirst().prefix(while: \.isNumber)
        guard let n = Int(digits), n > 0 else { return nil }
        return "\(prefix)\(n)"
    }

    static func bookID(_ name: String) -> Int? {
        if let n = OriginalLanguageService.bookNumber(for: name) { return n }
        if let i = BibleData.books.firstIndex(where: { $0.name == name }) { return i + 1 }
        return nil
    }

    static func verseID(bookName: String, chapter: Int, verse: Int) -> Int? {
        guard let book = bookID(bookName), chapter > 0, verse > 0 else { return nil }
        return book * 1_000_000 + chapter * 1_000 + verse
    }

    /// Lowercase, strips punctuation and possessives so "God's," matches "God".
    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: "’s", with: "").replacingOccurrences(of: "'s", with: "")
        let kept = t.unicodeScalars.map { CharacterSet.letters.contains($0) || $0 == "-" || $0 == "'" || $0 == "’" || $0 == " " ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }
}

private extension StudyMatchQuality {
    var rank: Int {
        switch self {
        case .exact: return 0
        case .strongsOnly: return 1
        case .none: return 2
        }
    }
}
