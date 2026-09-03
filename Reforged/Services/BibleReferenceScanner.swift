import SwiftUI

/// A Scripture reference detected inside a run of free text.
struct DetectedReference: Equatable {
    /// Range of the matched text in the original string (e.g. "Rom 8:28").
    let range: Range<String.Index>
    /// Canonical "Book Chapter:Verse" string (e.g. "Romans 8:28"), matching the
    /// conventions used by `BibleData.parseReference` and the bundled datasets.
    let reference: String
}

/// Detects Bible references embedded in free text (journal entries, lesson prose, group
/// posts) and turns them into tappable links. This is the free-text counterpart to
/// `BibleData.parseReference`, which only parses an already-isolated reference string.
///
/// Ported in spirit from openbible.info's open-source Bible-Passage-Reference-Parser
/// (CC-BY): a pragmatic subset covering the formats users actually type — full names and
/// common abbreviations, `Chapter:Verse` and `Chapter:VerseStart-VerseEnd`.
enum BibleReferenceScanner {

    /// Lowercased book token (spaces stripped) -> canonical `BibleData` book name.
    private static let bookLookup: [String: String] = {
        var map: [String: String] = [:]
        func add(_ token: String, _ canonical: String) {
            map[token.lowercased().replacingOccurrences(of: " ", with: "")] = canonical
        }
        for book in BibleData.books {
            add(book.name, book.name)
            add(book.abbreviation, book.name)
        }
        // Common alternates the built-in abbreviation list doesn't cover.
        let aliases: [(String, String)] = [
            ("psalm", "Psalms"), ("song of songs", "Song of Solomon"),
            ("canticles", "Song of Solomon"), ("gn", "Genesis"), ("mt", "Matthew"),
            ("mk", "Mark"), ("lk", "Luke"), ("jn", "John"), ("rm", "Romans"),
            ("philem", "Philemon"), ("apoc", "Revelation"), ("qoh", "Ecclesiastes"),
        ]
        for (token, canonical) in aliases { add(token, canonical) }
        return map
    }()

    /// One regex matching `<book> <chapter>:<verse>[-<verseEnd>]`. The book alternation is
    /// ordered longest-first so "1 John" wins over "John" at the same position (NSRegex
    /// alternation is leftmost-match, PCRE-style).
    private static let regex: NSRegularExpression = {
        var variants = Set<String>()
        for book in BibleData.books {
            variants.insert(book.name)
            variants.insert(book.abbreviation)
        }
        for alias in ["Psalm", "Song of Songs", "Canticles", "Gn", "Mt", "Mk", "Lk",
                      "Jn", "Rm", "Philem", "Apoc", "Qoh"] {
            variants.insert(alias)
        }
        let alternation = variants
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0)
                    .replacingOccurrences(of: " ", with: "\\s+") }
            .joined(separator: "|")
        // book, optional period, space(s), chapter, colon, verse, optional -verseEnd
        let pattern = "\\b(\(alternation))\\.?\\s+(\\d{1,3}):(\\d{1,3})(?:\\s*[-\u{2013}\u{2014}]\\s*(\\d{1,3}))?"
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Finds every valid reference in `text`, in order of appearance.
    static func detectReferences(in text: String) -> [DetectedReference] {
        guard !text.isEmpty else { return [] }
        let full = NSRange(text.startIndex..., in: text)
        var results: [DetectedReference] = []
        regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match,
                  let bookRange = Range(match.range(at: 1), in: text),
                  let chapterRange = Range(match.range(at: 2), in: text),
                  let verseRange = Range(match.range(at: 3), in: text),
                  let matchRange = Range(match.range, in: text) else { return }

            let bookToken = text[bookRange]
                .lowercased().replacingOccurrences(of: " ", with: "")
            guard let canonicalBook = bookLookup[bookToken],
                  let book = BibleData.book(named: canonicalBook),
                  let chapter = Int(text[chapterRange]), chapter >= 1, chapter <= book.chapters,
                  let verse = Int(text[verseRange]), verse >= 1 else { return }

            var canonical = "\(canonicalBook) \(chapter):\(verse)"
            if match.range(at: 4).location != NSNotFound,
               let endRange = Range(match.range(at: 4), in: text),
               let verseEnd = Int(text[endRange]), verseEnd > verse {
                canonical += "-\(verseEnd)"
            }
            results.append(DetectedReference(range: matchRange, reference: canonical))
        }
        return results
    }

    /// Builds an `AttributedString` for `text` with each detected reference turned into a
    /// `bibleverse://` link (the scheme already handled elsewhere in the app). `LinkedScriptureText`
    /// wires the tap to navigation; callers that render the string themselves must install their
    /// own `OpenURLAction`.
    static func attributedString(from text: String,
                                 linkColor: Color = .reforgedGold,
                                 baseColor: Color? = nil) -> AttributedString {
        var attributed = AttributedString(text)
        if let baseColor { attributed.foregroundColor = baseColor }

        for detected in detectReferences(in: text) {
            let start = text.distance(from: text.startIndex, to: detected.range.lowerBound)
            let length = text.distance(from: detected.range.lowerBound, to: detected.range.upperBound)
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: start)
            let upper = attributed.index(lower, offsetByCharacters: length)
            let encoded = detected.reference
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? detected.reference
            attributed[lower..<upper].link = URL(string: "bibleverse://\(encoded)")
            attributed[lower..<upper].foregroundColor = linkColor
        }
        return attributed
    }

    /// Adds reference links to an already-built `AttributedString` (e.g. rendered markdown),
    /// leaving any existing links (markdown hyperlinks) untouched.
    static func addingLinks(to attributed: AttributedString,
                            linkColor: Color = .reforgedGold) -> AttributedString {
        let plain = String(attributed.characters)
        var result = attributed
        for detected in detectReferences(in: plain) {
            let start = plain.distance(from: plain.startIndex, to: detected.range.lowerBound)
            let length = plain.distance(from: detected.range.lowerBound, to: detected.range.upperBound)
            let lower = result.index(result.startIndex, offsetByCharacters: start)
            let upper = result.index(lower, offsetByCharacters: length)
            if result[lower..<upper].link != nil { continue }
            let encoded = detected.reference
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? detected.reference
            result[lower..<upper].link = URL(string: "bibleverse://\(encoded)")
            result[lower..<upper].foregroundColor = linkColor
        }
        return result
    }
}

/// Renders free text with any Scripture references as tappable links that open the reader
/// at that verse (via the `.navigateToBibleVerse` notification, in the user's default
/// translation). Drop-in replacement for a plain `Text(someProse)`.
struct LinkedScriptureText: View {
    let text: String
    var font: Font = .body
    var baseColor: Color? = nil
    var linkColor: Color = .reforgedGold

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Text(BibleReferenceScanner.attributedString(from: text, linkColor: linkColor, baseColor: baseColor))
            .font(font)
            .tint(linkColor)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "bibleverse",
                      let encoded = url.host,
                      let reference = encoded.removingPercentEncoding else { return .systemAction }
                NotificationCenter.default.post(
                    name: .navigateToBibleVerse,
                    object: nil,
                    userInfo: [
                        AppNotificationUserInfoKey.reference: reference,
                        AppNotificationUserInfoKey.translation: settings.defaultTranslation.rawValue
                    ]
                )
                return .handled
            })
    }
}
