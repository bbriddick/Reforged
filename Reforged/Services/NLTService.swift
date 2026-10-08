import Foundation

// MARK: - Configuration

/// The New Living Translation is served by Tyndale's own API (api.nlt.to) under its own key.
/// Tyndale's license allows no more than 500 verses of NLT text to be stored on the device,
/// so chapters are read online and only the most recently read ones are kept.
struct NLTConfig {
    static let baseURL = "https://api.nlt.to/api/passages"
    static var apiKey: String { ApiBibleConfig.apiKeyOverrides[.nlt] ?? "" }
    /// Maximum verses of NLT text kept on disk. Least recently read chapters go first.
    static let maxStoredVerses = 500
}

enum NLTServiceError: LocalizedError {
    case notConfigured
    case badReference
    case httpError(Int)
    case emptyChapter

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "NLT is not configured."
        case .badReference: return "Could not understand that Bible reference."
        case .httpError(let code): return "NLT request failed (HTTP \(code))."
        case .emptyChapter: return "No text was returned for that chapter."
        }
    }
}

// MARK: - Service

final class NLTService {
    static let shared = NLTService()

    private init() {
        // One-time: NLT used to be cached chapter-by-chapter through API.Bible with no cap.
        let flag = "nlt_legacy_apibible_cache_purged"
        if !UserDefaults.standard.bool(forKey: flag) {
            ApiBibleService.shared.clearLegacyCache(for: .nlt)
            UserDefaults.standard.set(true, forKey: flag)
        }
    }

    private static func apiBookName(_ book: String) -> String {
        switch book {
        case "Psalms": return "Psalm"
        case "Song of Solomon": return "Song of Songs"
        default: return book
        }
    }

    func fetchChapterParsed(book: String, chapter: Int) async throws -> (verses: [ParsedVerse], canonical: String) {
        let html: String
        if let cached = NLTChapterStore.shared.html(book: book, chapter: chapter) {
            html = cached
        } else {
            html = try await fetchHTML(book: book, chapter: chapter)
        }
        let verses = NLTHTMLParser.parse(html, book: book, chapter: chapter)
        guard !verses.isEmpty else { throw NLTServiceError.emptyChapter }
        NLTChapterStore.shared.store(html: html, book: book, chapter: chapter, verseCount: verses.count)
        return (verses, "\(book) \(chapter)")
    }

    /// Accepts "John 3:16", "1 Corinthians 13:4-7" or "Psalm 23".
    func fetchVerseForMemory(reference: String) async throws -> (text: String, canonical: String) {
        guard let parsed = YouVersionService.parseReference(reference) else { throw NLTServiceError.badReference }
        let (verses, _) = try await fetchChapterParsed(book: parsed.book, chapter: parsed.chapter)
        let selected = verses.filter { v in
            guard let start = parsed.verseStart else { return true }
            return v.number >= start && v.number <= (parsed.verseEnd ?? start)
        }
        guard !selected.isEmpty else { throw NLTServiceError.emptyChapter }
        return (selected.map(\.text).joined(separator: " "), reference)
    }

    private func fetchHTML(book: String, chapter: Int) async throws -> String {
        guard !NLTConfig.apiKey.isEmpty else { throw NLTServiceError.notConfigured }
        var components = URLComponents(string: NLTConfig.baseURL)
        components?.queryItems = [
            URLQueryItem(name: "ref", value: "\(Self.apiBookName(book)).\(chapter)"),
            URLQueryItem(name: "key", value: NLTConfig.apiKey)
        ]
        guard let url = components?.url else { throw NLTServiceError.badReference }

        var lastError: Error = NLTServiceError.emptyChapter
        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                guard http.statusCode == 200 else { throw NLTServiceError.httpError(http.statusCode) }
                guard let html = String(data: data, encoding: .utf8) else { throw NLTServiceError.emptyChapter }
                return html
            } catch {
                lastError = error
                if case NLTServiceError.httpError(let code) = error, (400..<500).contains(code) { throw error }
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 400_000_000)
            }
        }
        throw lastError
    }

    func cachedChapterCount() -> Int { NLTChapterStore.shared.chapterCount }
    func clearCache() { NLTChapterStore.shared.clear() }
}

// MARK: - Capped on-disk store

/// Keeps recently read NLT chapters (raw API HTML) on disk, never exceeding
/// `NLTConfig.maxStoredVerses` verses in total. Least recently read chapters are evicted first.
/// Lives in Application Support and is excluded from backups.
final class NLTChapterStore: @unchecked Sendable {
    static let shared = NLTChapterStore()

    private struct Entry: Codable {
        var html: String
        var verseCount: Int
        var lastRead: Date
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private let fileURL: URL
    private let maxAge: TimeInterval = 30 * 24 * 3600

    private init() {
        let fm = FileManager.default
        var dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        dir.appendPathComponent("NLTCache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        fileURL = dir.appendingPathComponent("chapters.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            let cutoff = Date().addingTimeInterval(-maxAge)
            entries = decoded.filter { $0.value.lastRead > cutoff }
            enforceLimit()
        }
    }

    private func key(_ book: String, _ chapter: Int) -> String { "\(book)_\(chapter)" }

    var chapterCount: Int { lock.withLock { entries.count } }

    func html(book: String, chapter: Int) -> String? {
        lock.withLock {
            let k = key(book, chapter)
            guard var entry = entries[k] else { return nil }
            entry.lastRead = Date()
            entries[k] = entry
            return entry.html
        }
    }

    func store(html: String, book: String, chapter: Int, verseCount: Int) {
        guard verseCount <= NLTConfig.maxStoredVerses else { return }
        lock.withLock {
            entries[key(book, chapter)] = Entry(html: html, verseCount: verseCount, lastRead: Date())
            enforceLimit()
            persist()
        }
    }

    func clear() {
        lock.withLock {
            entries.removeAll()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Caller holds the lock (or is in init).
    private func enforceLimit() {
        var total = entries.values.reduce(0) { $0 + $1.verseCount }
        guard total > NLTConfig.maxStoredVerses else { return }
        for (k, entry) in entries.sorted(by: { $0.value.lastRead < $1.value.lastRead }) {
            if total <= NLTConfig.maxStoredVerses { break }
            entries[k] = nil
            total -= entry.verseCount
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

// MARK: - HTML → ParsedVerse

/// Converts NLT API HTML into the reader's `ParsedVerse` model. Poetry is `poet1`/`poet2`/`poet3`
/// paragraphs (→ indent 0/1/2; a `-sp` suffix is a stanza break), prose is `body…`/`ext-body…`,
/// headings are `subhead`, psalm titles are `psa-title`/`psa-hebrew`, and `<span class="vn">`
/// marks each verse.
enum NLTHTMLParser {
    private static let tagRegex = try! NSRegularExpression(pattern: #"<(/?)([A-Za-z][A-Za-z0-9_]*)([^>]*?)(/?)>"#)
    private static let classRegex = try! NSRegularExpression(pattern: #"class\s*=\s*"([^"]*)""#)
    private static let blockTags: Set<String> = ["p", "h2", "h3", "h4", "h5", "h6"]
    private static let voidTags: Set<String> = ["br", "img", "hr", "link", "meta"]
    private static let suppressedClasses: Set<String> = ["tn", "a-tn", "tn-ref", "cw", "cw_ch", "bk_ch_vs_header", "chapter-number"]
    private static let headingClasses: Set<String> = ["subhead", "sos-speaker"]
    private static let titleClasses: Set<String> = ["psa-title", "psa-hebrew"]

    private enum Capture { case heading, title, verseNumber }

    private struct Frame {
        let tag: String
        let classes: Set<String>
        let suppress: Bool
        let capture: Capture?
        let poetryIndent: Int?
        let isProse: Bool
    }

    private struct Draft {
        var number: Int
        var text: String
        var lines: [PoetryLine] = []
        var newParagraph: Bool
        var heading: String?
        var title: String?
        var continuesLine: Bool = false
    }

    /// `poet1` → 0, `poet2` → 1, `poet3` → 2 (suffixes like `-vn`, `-sp`, `-hd` ignored).
    private static func poetryIndent(_ classes: Set<String>) -> Int? {
        for c in classes where c.hasPrefix("poet") {
            let digits = c.dropFirst(4).prefix(while: { $0.isNumber })
            return max(0, (Int(digits) ?? 1) - 1)
        }
        return nil
    }

    static func parse(_ html: String, book: String, chapter: Int) -> [ParsedVerse] {
        var drafts: [Draft] = []
        var stack: [Frame] = []
        var pendingHeading = ""
        var pendingTitle = ""
        var captureBuffer = ""
        var pendingParagraph = false
        var previousBlockWasPoetry = false
        var lineBuffer = ""
        var activePoetryIndent: Int? = nil
        var spaceAfterSmallCaps = false

        func append(_ part: String, _ target: inout String) {
            let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            target += (target.isEmpty ? "" : " ") + t
        }

        func flushLine() {
            guard let indent = activePoetryIndent, !drafts.isEmpty else { lineBuffer = ""; return }
            let t = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { drafts[drafts.count - 1].lines.append(PoetryLine(text: t, indent: indent)) }
            lineBuffer = ""
        }

        func emit(_ raw: String) {
            var text = YouVersionHTMLParser.decode(raw)
            guard !text.isEmpty else { return }
            // Small caps (e.g. LORD) arrive as `<span class="sc">Lord</span>`.
            if stack.contains(where: { $0.classes.contains("sc") || $0.classes.contains("subhead-sc") || $0.classes.contains("red-sc") }) {
                text = text.uppercased()
            } else if spaceAfterSmallCaps, let first = text.first, first.isLetter {
                text = " " + text
            }
            spaceAfterSmallCaps = false

            if stack.contains(where: { $0.capture != nil }) {
                captureBuffer += text
            } else if !drafts.isEmpty {
                if drafts[drafts.count - 1].text.isEmpty {
                    drafts[drafts.count - 1].text = String(text.drop(while: { $0.isWhitespace }))
                } else {
                    drafts[drafts.count - 1].text += text
                }
                if activePoetryIndent != nil { lineBuffer += text }
            }
        }

        func startVerse(_ number: Int) {
            // A verse number partway through a poetic line ends the previous verse's line there.
            let midLine = activePoetryIndent != nil && !lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if midLine { flushLine() }
            let heading = pendingHeading.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            drafts.append(Draft(number: number, text: "", newParagraph: drafts.isEmpty || pendingParagraph,
                                heading: heading.isEmpty ? nil : heading,
                                title: title.isEmpty ? nil : title,
                                continuesLine: midLine))
            pendingHeading = ""
            pendingTitle = ""
            pendingParagraph = false
        }

        func close(_ frame: Frame) {
            if let kind = frame.capture {
                let text = captureBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                captureBuffer = ""
                switch kind {
                case .heading: append(text, &pendingHeading)
                case .title: append(text, &pendingTitle)
                case .verseNumber:
                    let digits = text.prefix(while: { $0.isNumber })
                    if let n = Int(digits) { startVerse(n) }
                }
            } else if frame.poetryIndent != nil {
                flushLine()
                activePoetryIndent = nil
                previousBlockWasPoetry = true
            } else if frame.isProse {
                previousBlockWasPoetry = false
            }
            if blockTags.contains(frame.tag) && frame.capture == nil { emit(" ") }
            if frame.tag == "span", frame.classes.contains("sc") { spaceAfterSmallCaps = true }
        }

        let ns = html as NSString
        var cursor = 0
        for match in tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor, !stack.contains(where: \.suppress) {
                emit(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }
            cursor = match.range.upperBound

            let closing = ns.substring(with: match.range(at: 1)) == "/"
            let tag = ns.substring(with: match.range(at: 2)).lowercased()
            let attrs = ns.substring(with: match.range(at: 3))
            let selfClosing = !ns.substring(with: match.range(at: 4)).isEmpty

            if tag == "br" {
                if !stack.contains(where: \.suppress), !stack.contains(where: { $0.capture != nil }) { emit(" ") }
                continue
            }
            if voidTags.contains(tag) { continue }

            if closing {
                if let idx = stack.lastIndex(where: { $0.tag == tag }) {
                    let frames = Array(stack[idx...])
                    stack.removeSubrange(idx...)
                    for frame in frames.reversed() { close(frame) }
                }
                continue
            }

            // HTML closes an open <p>/<h?> when another block starts.
            if blockTags.contains(tag) {
                while let idx = stack.lastIndex(where: { blockTags.contains($0.tag) }) {
                    let frames = Array(stack[idx...])
                    stack.removeSubrange(idx...)
                    for frame in frames.reversed() { close(frame) }
                }
            }

            var classes = Set<String>()
            if let m = classRegex.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)) {
                classes = Set((attrs as NSString).substring(with: m.range(at: 1)).split(separator: " ").map(String.init))
            }
            let suppress = !classes.isDisjoint(with: suppressedClasses)

            var capture: Capture? = nil
            var indent: Int? = nil
            var isProse = false
            if tag == "span", classes.contains("vn"), !stack.contains(where: \.suppress) {
                capture = .verseNumber
                captureBuffer = ""
            } else if blockTags.contains(tag), !suppress {
                if !classes.isDisjoint(with: titleClasses) {
                    capture = .title
                } else if !classes.isDisjoint(with: headingClasses) {
                    capture = .heading
                } else if let level = poetryIndent(classes) {
                    indent = level
                    activePoetryIndent = level
                    lineBuffer = ""
                    let stanzaBreak = classes.contains { $0.contains("-sp") }
                    if !previousBlockWasPoetry || stanzaBreak { pendingParagraph = true }
                } else if !classes.isEmpty {
                    isProse = true
                    pendingParagraph = true
                }
            }

            if !selfClosing {
                stack.append(Frame(tag: tag, classes: classes, suppress: suppress, capture: capture,
                                   poetryIndent: indent, isProse: isProse))
            }
        }
        if cursor < ns.length, !stack.contains(where: \.suppress) {
            emit(ns.substring(from: cursor))
        }
        flushLine()

        return drafts.compactMap { d in
            var text = d.text
            if !d.lines.isEmpty { text = d.lines.map(\.text).joined(separator: " ") }
            while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let ref = "\(book) \(chapter):\(d.number)"
            return ParsedVerse(id: ref, number: d.number, text: text, reference: ref,
                               startsNewParagraph: d.newParagraph, sectionHeading: d.heading,
                               poetryLines: d.lines.isEmpty ? nil : d.lines,
                               continuesPreviousLine: d.continuesLine && !d.lines.isEmpty,
                               title: d.title)
        }
    }
}
