import Foundation
import AuthenticationServices
import UIKit
import YouVersionPlatform

// MARK: - Configuration

/// NASB is licensed by The Lockman Foundation through the YouVersion Platform, which requires
/// access via the YouVersion Platform SDK. Fill these in from platform.youversion.com
/// (Apps → your app → App Key) and the `/bibles` listing. Until both are set, NASB keeps
/// using the legacy API.Bible path (see `ApiBibleService`).
struct YouVersionConfig {
    static let appKey = "tD38GfroKUA8aHLjRep2KXRSQDmCv3XS31KrY1g5gpHK40lQ"
    /// YouVersion Bible version ID for the licensed NASB edition (1995 or 2020).
    static let nasbVersionId = 100

    static var isConfigured: Bool { !appKey.isEmpty && nasbVersionId > 0 }

    /// MASTER SWITCH for the full-NASB offline download. Leave `false` until YouVersion and
    /// Lockman confirm a whole-Bible download is acceptable for this app (the license requires
    /// bulk extraction to be "difficult or impractical" outside the app). While `false`, NASB is
    /// only cached chapter-by-chapter as the user reads.
    /// Off for now: the sign-in this download requires isn't working yet, so the NASB row in
    /// Manage Bibles shows no sign-in or download. NASB still reads online and caches chapters.
    static let offlineDownloadEnabled = false
    /// When the download is on, require the user to sign in with YouVersion first (mirrors the
    /// SDK's own download flow).
    static let requireSignInForDownload = true

    static var downloadsOffered: Bool { isConfigured && offlineDownloadEnabled }

    static func versionId(for translation: BibleTranslation) -> Int? {
        guard isConfigured, translation == .nasb else { return nil }
        return nasbVersionId
    }

    @MainActor
    static func configureSDK() {
        guard isConfigured else { return }
        // One-time: drop NASB text previously cached from API.Bible.
        let flag = "youversion_nasb_legacy_cache_purged"
        if !UserDefaults.standard.bool(forKey: flag) {
            ApiBibleService.shared.clearLegacyCache(for: .nasb)
            UserDefaults.standard.set(true, forKey: flag)
        }
        YouVersionPlatformConfiguration.configure(
            appKey: appKey,
            appName: "Reforged",
            isSignInEnabled: downloadsOffered && requireSignInForDownload,
            permittedVersionIds: [nasbVersionId]
        )
    }
}

enum YouVersionServiceError: LocalizedError {
    case notConfigured
    case badReference
    case emptyChapter

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "NASB is not configured."
        case .badReference:  return "Could not understand that Bible reference."
        case .emptyChapter:  return "No text was returned for that chapter."
        }
    }
}

// MARK: - Service

/// Chapter text for licensed YouVersion versions. Chapters are fetched and cached by the SDK's
/// `BibleChapterRepository`, so anything the user has read stays available offline.
/// Deliberately no bulk "download everything" here: the Lockman agreement requires that
/// bulk extraction of the text be difficult outside the app.
final class YouVersionService {
    static let shared = YouVersionService()
    private init() {}

    // MARK: Chapters

    func fetchChapterParsed(book: String, chapter: Int, translation: BibleTranslation) async throws -> (verses: [ParsedVerse], canonical: String) {
        guard let versionId = YouVersionConfig.versionId(for: translation) else {
            throw YouVersionServiceError.notConfigured
        }
        guard let usfm = ApiBibleService.bookIdMap[book] else {
            throw YouVersionServiceError.badReference
        }
        let reference = BibleReference(versionId: versionId, bookUSFM: usfm, chapter: chapter)
        let html: String
        if let saved = YouVersionOfflineStore.shared.html(for: reference) {
            html = saved
        } else {
            html = try await BibleChapterRepository.shared.chapter(withReference: reference)
        }
        let verses = YouVersionHTMLParser.parse(html, book: book, chapter: chapter)
        guard !verses.isEmpty else { throw YouVersionServiceError.emptyChapter }
        return (verses, "\(book) \(chapter)")
    }

    // MARK: Memory verses

    /// Accepts "John 3:16", "1 Corinthians 13:4-7" or "Psalm 23".
    func fetchVerseForMemory(reference: String, translation: BibleTranslation) async throws -> (text: String, canonical: String) {
        guard let parsed = Self.parseReference(reference) else { throw YouVersionServiceError.badReference }
        let (verses, _) = try await fetchChapterParsed(book: parsed.book, chapter: parsed.chapter, translation: translation)
        let selected = verses.filter { v in
            guard let start = parsed.verseStart else { return true }
            return v.number >= start && v.number <= (parsed.verseEnd ?? start)
        }
        guard !selected.isEmpty else { throw YouVersionServiceError.emptyChapter }
        let text = selected.map(\.text).joined(separator: " ")
        return (text, reference)
    }

    static func parseReference(_ reference: String) -> (book: String, chapter: Int, verseStart: Int?, verseEnd: Int?)? {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        guard let lastSpace = trimmed.lastIndex(of: " ") else { return nil }
        let book = String(trimmed[..<lastSpace])
        let cv = trimmed[trimmed.index(after: lastSpace)...].split(separator: ":", maxSplits: 1)
        guard ApiBibleService.bookIdMap[book] != nil, let chapter = cv.first.flatMap({ Int($0) }) else { return nil }
        guard cv.count == 2 else { return (book, chapter, nil, nil) }
        let range = cv[1].split(separator: "-").compactMap { Int($0) }
        guard let start = range.first else { return nil }
        return (book, chapter, start, range.count > 1 ? range[1] : nil)
    }

    // MARK: Cache state

    func clearCache(for translation: BibleTranslation) async {
        guard let versionId = YouVersionConfig.versionId(for: translation) else { return }
        await BibleChapterRepository.shared.removeVersion(withId: versionId)
        YouVersionOfflineStore.shared.clear(versionId: versionId)
    }

    // MARK: Full offline download (behind YouVersionConfig.offlineDownloadEnabled)

    /// Fetches every NASB chapter into `YouVersionOfflineStore`. Resumable (skips chapters already
    /// saved) and cancellable. `progress` receives the number of chapters now saved.
    func downloadAll(translation: BibleTranslation, progress: @escaping @MainActor (Int) -> Void) async throws {
        guard YouVersionConfig.downloadsOffered, let versionId = YouVersionConfig.versionId(for: translation) else {
            throw YouVersionServiceError.notConfigured
        }
        let store = YouVersionOfflineStore.shared
        var done = store.count(versionId: versionId)
        await progress(done)

        for book in BibleData.books {
            guard let usfm = ApiBibleService.bookIdMap[book.name] else { continue }
            let pending = (1...book.chapters)
                .map { BibleReference(versionId: versionId, bookUSFM: usfm, chapter: $0) }
                .filter { !store.has($0) }
            // Small batches keep us well inside rate limits.
            for batch in stride(from: 0, to: pending.count, by: 4).map({ Array(pending[$0..<min($0 + 4, pending.count)]) }) {
                try Task.checkCancellation()
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for ref in batch {
                        group.addTask {
                            var lastError: Error?
                            for attempt in 0..<3 {
                                do {
                                    let html = try await YouVersionAPI.Bible.chapter(reference: ref)
                                    store.save(html, for: ref)
                                    return
                                } catch YouVersionAPIError.notPermitted {
                                    throw YouVersionAPIError.notPermitted
                                } catch {
                                    lastError = error
                                    try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 500_000_000)
                                }
                            }
                            throw lastError ?? YouVersionAPIError.cannotDownload
                        }
                    }
                    try await group.waitForAll()
                }
                done += batch.count
                await progress(done)
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}

// MARK: - HTML → ParsedVerse

/// Converts YouVersion chapter HTML (`div.p/q/s/ms/d/qa…`, `span.yv-v[v]`, `span.yv-vlbl`,
/// `span.yv-n` footnotes) into the reader's `ParsedVerse` model: prose paragraphs, poetry lines
/// (`q`, `q1`, `q2`… → indent levels), section headings and psalm/acrostic titles.
enum YouVersionHTMLParser {
    private static let tagRegex = try! NSRegularExpression(pattern: #"<(/?)([A-Za-z][A-Za-z0-9]*)([^>]*?)(/?)>"#)
    private static let classRegex = try! NSRegularExpression(pattern: #"class\s*=\s*"([^"]*)""#)
    private static let verseAttrRegex = try! NSRegularExpression(pattern: #"\bv\s*=\s*"(\d+)""#)
    private static let voidTags: Set<String> = ["br", "img", "hr", "wbr"]
    private static let suppressedClasses: Set<String> = ["yv-vlbl", "vlbl", "va", "vp", "yv-n", "fr", "fq", "ft", "fk", "fqa", "xo", "xt", "label", "note", "r", "mr", "sr", "rq"]
    private static let headingClasses: Set<String> = ["s", "s1", "s2", "s3", "sp"]
    private static let majorSectionClasses: Set<String> = ["ms", "ms1", "ms2", "ms3"]
    private static let titleClasses: Set<String> = ["d", "qa"]

    private enum Capture { case heading, title, majorSection }

    private struct Frame {
        let tag: String
        let classes: Set<String>
        let suppress: Bool
        let capture: Capture?
        let poetryIndent: Int?
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

    /// `q`, `q1` → 0; `q2` → 1; `q3` → 2 (also `qm…`, `qr`, `qc`). `qa` is a title, not poetry.
    private static func poetryIndent(for classes: Set<String>) -> Int? {
        for c in classes where c.hasPrefix("q") && c != "qa" {
            let digits = c.drop(while: { !$0.isNumber })
            let level = Int(digits) ?? 1
            return max(0, level - 1)
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
        var pendingStanzaBreak = false
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
            var text = decode(raw)
            guard !text.isEmpty else { return }
            // Small caps (e.g. LORD) arrive as `L<span class="sc">ord</span>`; render as capitals.
            if stack.contains(where: { $0.classes.contains("sc") }) {
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

        func finishCapture(_ kind: Capture) {
            let text = captureBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            captureBuffer = ""
            guard !text.isEmpty else { return }
            switch kind {
            case .heading:
                append(text, &pendingHeading)
            case .title:
                append(text, &pendingTitle)
            case .majorSection:
                let upper = text.uppercased()
                // "PSALM 3" repeats the chapter title; "BOOK ONE" is a Psalter division.
                if upper.range(of: #"^(PSALM|CHAPTER)\s*\d+$"#, options: .regularExpression) != nil { return }
                if upper.range(of: #"^BOOK\s+\w+$"#, options: .regularExpression) != nil { return }
                append(text, &pendingTitle)
            }
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
                    let frame = stack[idx]
                    stack.removeSubrange(idx...)
                    if frame.tag == "span", frame.classes.contains("sc") { spaceAfterSmallCaps = true }
                    if frame.tag == "div" {
                        if let kind = frame.capture {
                            finishCapture(kind)
                        } else if frame.poetryIndent != nil {
                            flushLine()
                            activePoetryIndent = nil
                            previousBlockWasPoetry = true
                        } else if !frame.classes.isEmpty {
                            previousBlockWasPoetry = false
                        }
                        if frame.capture == nil { emit(" ") }
                    }
                }
                continue
            }

            var classes = Set<String>()
            if let m = classRegex.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)) {
                classes = Set((attrs as NSString).substring(with: m.range(at: 1)).split(separator: " ").map(String.init))
            }
            let suppress = !classes.isDisjoint(with: suppressedClasses)

            var capture: Capture? = nil
            var indent: Int? = nil
            if tag == "div" {
                if !classes.isDisjoint(with: titleClasses) {
                    capture = .title
                } else if !classes.isDisjoint(with: majorSectionClasses) {
                    capture = .majorSection
                } else if !classes.isDisjoint(with: headingClasses) {
                    capture = .heading
                } else if classes.contains("b") {
                    pendingStanzaBreak = true
                } else if let level = poetryIndent(for: classes) {
                    indent = level
                    activePoetryIndent = level
                    lineBuffer = ""
                    if !previousBlockWasPoetry || pendingStanzaBreak { pendingParagraph = true }
                    pendingStanzaBreak = false
                } else {
                    let isParagraph = classes.contains { $0.hasPrefix("p") && $0 != "pc" }
                    if isParagraph { pendingParagraph = true }
                }
            }

            if classes.contains("yv-v"), !stack.contains(where: \.suppress) {
                if let m = verseAttrRegex.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)),
                   let n = Int((attrs as NSString).substring(with: m.range(at: 1))) {
                    // A marker partway through a poetic line ends the previous verse's line there.
                    let midLine = activePoetryIndent != nil && !lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if midLine { flushLine() }
                    let heading = pendingHeading.trimmingCharacters(in: .whitespacesAndNewlines)
                    let title = pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let startsParagraph = drafts.isEmpty || pendingParagraph
                    drafts.append(Draft(number: n, text: "", newParagraph: startsParagraph,
                                        heading: heading.isEmpty ? nil : heading,
                                        title: title.isEmpty ? nil : title,
                                        continuesLine: midLine))
                    pendingHeading = ""
                    pendingTitle = ""
                    pendingParagraph = false
                }
            }

            if !selfClosing {
                stack.append(Frame(tag: tag, classes: classes, suppress: suppress, capture: capture, poetryIndent: indent))
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

    static func decode(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
        let named = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
                     "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&lsquo;": "‘", "&rsquo;": "’",
                     "&ldquo;": "“", "&rdquo;": "”"]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        let numeric = try! NSRegularExpression(pattern: #"&#(x?)([0-9A-Fa-f]+);"#)
        let ns = out as NSString
        var result = ""
        var last = 0
        for m in numeric.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let isHex = ns.substring(with: m.range(at: 1)) == "x"
            if let code = UInt32(ns.substring(with: m.range(at: 2)), radix: isHex ? 16 : 10), let u = Unicode.Scalar(code) {
                result.unicodeScalars.append(u)
            }
            last = m.range.upperBound
        }
        result += ns.substring(from: last)
        return result
    }
}


// MARK: - Offline store

/// Chapter HTML saved for offline NASB reading. Lives in Application Support (not Documents),
/// excluded from iCloud/device backups, and has no export path.
final class YouVersionOfflineStore: @unchecked Sendable {
    static let shared = YouVersionOfflineStore()

    private let root: URL
    private let fm = FileManager.default

    private init() {
        var base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        base.appendPathComponent("YouVersionOffline", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? base.setResourceValues(values)
        root = base
    }

    private func directory(_ versionId: Int) -> URL {
        root.appendingPathComponent(String(versionId), isDirectory: true)
    }

    private func file(for ref: BibleReference) -> URL {
        directory(ref.versionId).appendingPathComponent("\(ref.bookUSFM).\(ref.chapter).html")
    }

    func has(_ ref: BibleReference) -> Bool { fm.fileExists(atPath: file(for: ref).path) }

    func html(for ref: BibleReference) -> String? {
        try? String(contentsOf: file(for: ref), encoding: .utf8)
    }

    func save(_ html: String, for ref: BibleReference) {
        try? fm.createDirectory(at: directory(ref.versionId), withIntermediateDirectories: true)
        try? Data(html.utf8).write(to: file(for: ref), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func count(versionId: Int) -> Int {
        (try? fm.contentsOfDirectory(atPath: directory(versionId).path))?.count ?? 0
    }

    func clear(versionId: Int) {
        try? fm.removeItem(at: directory(versionId))
    }
}

// MARK: - YouVersion sign-in

@MainActor
final class YouVersionSignIn: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = YouVersionSignIn()

    @Published private(set) var isSignedIn = YouVersionAPI.isSignedIn
    @Published var errorMessage: String?

    func signIn() async {
        errorMessage = nil
        do {
            _ = try await YouVersionAPI.Users.signIn(permissions: ["openid"], contextProvider: self)
            isSignedIn = YouVersionAPI.isSignedIn
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User dismissed the sheet.
        } catch {
            errorMessage = "Couldn't sign in to YouVersion. Please try again."
        }
    }

    func signOut() {
        YouVersionAPI.Users.signOut()
        isSignedIn = false
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
