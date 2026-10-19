import UIKit
import SwiftUI

// MARK: - Bible Attributed Text Builder
//
// Pure, testable translation of one `LoadedChapter` into a single `NSAttributedString`
// for the TextKit 2 reader. It reproduces the FlowLayout reader's typography (fonts,
// sizes, line spacing, superscript gold verse numbers, bracket italics, red-letter,
// section headings, chapter header, Greek/Hebrew layout) and attaches the domain
// metadata (`ScriptureRole`, verse reference/number, lookup word) that `ScriptureTextView`
// resolves on tap. Interactive overlays (selection, highlight, note, word-lookup,
// audio-follow) are applied from `ScriptureRenderState`, so a state change re-runs the
// builder rather than rebuilding a view tree.
//
// The horizontal reading gutter is applied by the text view via `textContainerInset`
// (so it can adapt to the size class), NOT baked into paragraph indents — keeping the
// built string a pure function of content that caches cleanly across widths.
struct BibleAttributedTextBuilder {
    let chapter: LoadedChapter
    let settings: BibleReadingSettings
    let translation: BibleTranslation
    let colorScheme: ColorScheme
    let verseByVerse: Bool
    var renderState: ScriptureRenderState = .empty
    /// When false the chapter eyebrow/title are omitted — used when embedding the body
    /// beneath a separate SwiftUI `ChapterHeader`.
    var includeChapterHeader: Bool = true

    private var palette: ReaderPalette { ReaderPalette(colorScheme: colorScheme) }
    private var isRTL: Bool { translation == .wlc }
    private var isOriginalLanguage: Bool { translation.isOriginalLanguage }

    // MARK: Entry point

    func build() -> NSAttributedString {
        let output = NSMutableAttributedString()
        if includeChapterHeader {
            appendChapterHeader(into: output)
        }
        if verseByVerse {
            appendVerseByVerse(into: output)
        } else {
            appendParagraphs(into: output)
        }
        return output
    }

    // MARK: Chapter header

    private func appendChapterHeader(into output: NSMutableAttributedString) {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.paragraphSpacingBefore = 16

        let eyebrow: [NSAttributedString.Key: Any] = [
            .font: ReaderFonts.chapterBookEyebrow(scale: settings.readerHeadingScale),
            .foregroundColor: ReaderPalette.gold,
            .kern: 1.0,
            .paragraphStyle: centered,
            .scriptureRole: ScriptureRole.chapterBook.rawValue,
            .scriptureBook: chapter.book,
            .scriptureChapter: chapter.chapter
        ]
        output.append(NSAttributedString(string: chapter.book.uppercased() + "\n", attributes: eyebrow))

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.paragraphSpacing = 16
        titleStyle.paragraphSpacingBefore = 4

        let title: [NSAttributedString.Key: Any] = [
            .font: ReaderFonts.chapterTitle(scale: settings.readerHeadingScale),
            .foregroundColor: palette.text,
            .paragraphStyle: titleStyle,
            .scriptureRole: ScriptureRole.chapterTitle.rawValue,
            .scriptureBook: chapter.book,
            .scriptureChapter: chapter.chapter
        ]
        output.append(NSAttributedString(string: chapterLabel + "\n", attributes: title))
    }

    /// Psalms read "Psalm N"; everything else "Chapter N" — mirrors `ChapterHeader.chapterLabel`.
    private var chapterLabel: String {
        chapter.book == "Psalms" ? "Psalm \(chapter.chapter)" : "Chapter \(chapter.chapter)"
    }

    // MARK: Section heading

    private func appendSectionHeading(_ heading: String, into output: NSMutableAttributedString) {
        let style = NSMutableParagraphStyle()
        style.alignment = isRTL ? .right : .left
        style.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        style.paragraphSpacingBefore = 20
        style.paragraphSpacing = 4

        let attrs: [NSAttributedString.Key: Any] = [
            .font: ReaderFonts.sectionHeading(scale: settings.readerHeadingScale),
            .foregroundColor: palette.secondaryText,
            .paragraphStyle: style,
            .scriptureRole: ScriptureRole.sectionHeading.rawValue
        ]
        output.append(NSAttributedString(string: heading + "\n", attributes: attrs))
    }

    // MARK: Paragraph mode

    /// A paragraph (prose block or one poetic line) that has text but no terminating newline yet.
    private struct OpenParagraph {
        let start: Int
        let style: NSParagraphStyle
        let isPoetry: Bool
        let indent: Int
    }

    private func closeParagraph(_ open: inout OpenParagraph?, into output: NSMutableAttributedString) {
        guard let paragraph = open else { return }
        output.append(NSAttributedString(string: "\n", attributes: [
            .paragraphStyle: paragraph.style,
            .font: baseFont(italic: false)
        ]))
        output.addAttribute(.paragraphStyle, value: paragraph.style,
                            range: NSRange(location: paragraph.start, length: output.length - paragraph.start))
        open = nil
    }

    private func appendParagraphs(into output: NSMutableAttributedString) {
        for section in chapter.sections {
            if let heading = section.heading {
                appendSectionHeading(heading, into: output)
            }
            var open: OpenParagraph? = nil
            let verses = section.verses
            for (index, verse) in verses.enumerated() {
                let next = index + 1 < verses.count ? verses[index + 1] : nil
                if let title = verse.title {
                    closeParagraph(&open, into: output)
                    appendTitle(title, into: output)
                }

                if let lines = poetryLines(for: verse) {
                    let continuing = verse.continuesPreviousLine && open?.isPoetry == true ? open : nil
                    if continuing == nil { closeParagraph(&open, into: output) }
                    let endsRun = next.map { poetryLines(for: $0) == nil } ?? true
                    open = appendVerse(verse, into: output,
                                       trailingSpace: next?.continuesPreviousLine ?? false,
                                       poetry: lines, continuing: continuing,
                                       stanzaBreak: verse.startsNewParagraph && continuing == nil,
                                       endsPoetryRun: endsRun, endSpacing: 8)
                } else {
                    if verse.startsNewParagraph || open?.isPoetry == true {
                        closeParagraph(&open, into: output)
                    }
                    if open == nil {
                        open = OpenParagraph(start: output.length, style: bodyParagraphStyle(), isPoetry: false, indent: 0)
                    }
                    let nextJoins = next.map { !$0.startsNewParagraph && poetryLines(for: $0) == nil } ?? false
                    appendVerse(verse, into: output, trailingSpace: nextJoins)
                }
            }
            closeParagraph(&open, into: output)
        }
    }

    // MARK: Verse-by-verse mode

    private func appendVerseByVerse(into output: NSMutableAttributedString) {
        for verse in chapter.verses {
            if let heading = verse.sectionHeading {
                appendSectionHeading(heading, into: output)
            }
            if let title = verse.title {
                appendTitle(title, into: output)
            }
            let verseStart = output.length
            var open: OpenParagraph?
            if let lines = poetryLines(for: verse) {
                open = appendVerse(verse, into: output, trailingSpace: false,
                                   poetry: lines, continuing: nil, stanzaBreak: false,
                                   endsPoetryRun: true, endSpacing: 12)
            } else {
                appendVerse(verse, into: output, trailingSpace: false)
                open = OpenParagraph(start: verseStart, style: verseByVerseParagraphStyle(), isPoetry: false, indent: 0)
            }
            closeParagraph(&open, into: output)
        }
    }

    // MARK: Poetry + titles

    /// Poetry layout for a verse, or nil to render it as flowing prose (original languages, and
    /// verses with red-letter segments whose run structure doesn't map onto lines).
    private func poetryLines(for verse: ParsedVerse) -> [PoetryLine]? {
        guard settings.showPoetryLayout, !isOriginalLanguage, let lines = verse.poetryLines, !lines.isEmpty,
              chapter.woc[verse.reference] == nil else { return nil }
        return lines
    }

    /// Psalm superscription / acrostic title ("A Psalm of David.", "Aleph"), set below the heading.
    private func appendTitle(_ title: String, into output: NSMutableAttributedString) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.paragraphSpacingBefore = 2
        style.paragraphSpacing = 8
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont(italic: true),
            .foregroundColor: palette.secondaryText,
            .paragraphStyle: style,
            .scriptureRole: ScriptureRole.sectionHeading.rawValue
        ]
        output.append(NSAttributedString(string: title + "\n", attributes: attrs))
    }

    private func poetryParagraphStyle(indent: Int, stanzaBreak: Bool, spacingAfter: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = settings.lineSpacing.spacing * settings.readerHeadingScale
        style.paragraphSpacing = spacingAfter
        style.paragraphSpacingBefore = stanzaBreak ? 14 : 0
        let unit = settings.readerFontSize * 1.1
        style.firstLineHeadIndent = unit * CGFloat(indent)
        // Wrapped lines hang one step further in, the way printed poetry sets long lines.
        style.headIndent = unit * CGFloat(indent + 1)
        style.alignment = .left
        style.baseWritingDirection = .leftToRight
        return style
    }

    // MARK: One verse

    @discardableResult
    private func appendVerse(_ verse: ParsedVerse,
                             into output: NSMutableAttributedString,
                             trailingSpace: Bool,
                             poetry: [PoetryLine]? = nil,
                             continuing: OpenParagraph? = nil,
                             stanzaBreak: Bool = false,
                             endsPoetryRun: Bool = true,
                             endSpacing: CGFloat = 8) -> OpenParagraph? {
        let verseRangeStart = output.length
        let isSelected = renderState.selectedReferences.contains(verse.reference)
        // Illuminated Capitals (crown shop): the chapter opens on a gilded raised
        // initial instead of a "1" verse number.
        let raisedInitial = ReaderCosmetics.illuminatedCapitals && verse.number == 1 && !isOriginalLanguage

        if !raisedInitial {
            appendVerseNumber(verse, into: output)
        }

        if renderState.bookmarkedReferences.contains(verse.reference) {
            appendBookmarkIndicator(verse, into: output)
        }

        var open: OpenParagraph? = nil
        if isOriginalLanguage {
            appendOriginalLanguageWords(verse, into: output, isSelected: isSelected)
        } else if let lines = poetry {
            open = appendPoetryLines(lines, verse: verse, into: output, isSelected: isSelected,
                                     verseStart: verseRangeStart, continuing: continuing,
                                     stanzaBreak: stanzaBreak, endsPoetryRun: endsPoetryRun,
                                     trailingSpace: trailingSpace, raisedInitial: raisedInitial,
                                     endSpacing: endSpacing)
        } else {
            appendEnglishWords(verse, into: output, isSelected: isSelected, trailingSpace: trailingSpace,
                               raisedInitial: raisedInitial)
        }

        if renderState.notedReferences.contains(verse.reference) {
            appendNoteIndicator(verse, into: output)
        }

        // Verse-spanning background washes (selection > audio > highlight), applied over the
        // whole verse (number + text) exactly like the old row's precedence.
        let verseRange = NSRange(location: verseRangeStart, length: output.length - verseRangeStart)
        if isSelected {
            output.addAttribute(.backgroundColor, value: palette.selectionBackground, range: verseRange)
        } else if renderState.audioReference == verse.reference {
            output.addAttribute(.backgroundColor, value: palette.audioBackground, range: verseRange)
        } else if let highlight = renderState.highlightsByReference[verse.reference] {
            output.addAttribute(.backgroundColor, value: highlight.uiHighlightColor(isDark: palette.isDark), range: verseRange)
        }
        return open
    }

    /// Lays a poetic verse out one line per paragraph, with indent levels. The verse number
    /// (already appended) leads the first line. The last line is returned still open so the
    /// next verse can continue it (verses that start mid-line) or the caller can close it.
    private func appendPoetryLines(_ lines: [PoetryLine],
                                   verse: ParsedVerse,
                                   into output: NSMutableAttributedString,
                                   isSelected: Bool,
                                   verseStart: Int,
                                   continuing: OpenParagraph?,
                                   stanzaBreak: Bool,
                                   endsPoetryRun: Bool,
                                   trailingSpace: Bool,
                                   raisedInitial: Bool,
                                   endSpacing: CGFloat) -> OpenParagraph {
        var lineStart = verseStart
        var currentIndent = lines[0].indent
        var openFromEarlier = continuing

        for (i, line) in lines.enumerated() {
            let isLast = i == lines.count - 1
            let tokens = tokenizeVerseText(line.text, verseId: "\(verse.id)_l\(i)").map {
                ColoredToken(display: $0.displayText, clean: $0.cleanWord, italic: $0.isItalic, red: false)
            }
            appendTokens(tokens, verse: verse, into: output, isSelected: isSelected,
                         trailingSpace: isLast && trailingSpace,
                         raisedInitial: raisedInitial && i == 0)

            if !isLast {
                if i == 0, let earlier = openFromEarlier {
                    // The first line finishes a line begun by the previous verse.
                    output.append(NSAttributedString(string: "\n", attributes: [
                        .paragraphStyle: earlier.style, .font: baseFont(italic: false)
                    ]))
                    output.addAttribute(.paragraphStyle, value: earlier.style,
                                        range: NSRange(location: earlier.start, length: output.length - earlier.start))
                    openFromEarlier = nil
                } else {
                    let style = poetryParagraphStyle(indent: line.indent, stanzaBreak: i == 0 && stanzaBreak, spacingAfter: 0)
                    output.append(NSAttributedString(string: "\n", attributes: [
                        .paragraphStyle: style, .font: baseFont(italic: false)
                    ]))
                    output.addAttribute(.paragraphStyle, value: style,
                                        range: NSRange(location: lineStart, length: output.length - lineStart))
                }
                lineStart = output.length
                currentIndent = lines[i + 1].indent
            }
        }

        if let earlier = openFromEarlier {
            // Single-line verse that continues the previous verse's line: keep that line open.
            let style = poetryParagraphStyle(indent: earlier.indent, stanzaBreak: false,
                                             spacingAfter: endsPoetryRun ? endSpacing : 0)
            return OpenParagraph(start: earlier.start, style: style, isPoetry: true, indent: earlier.indent)
        }
        let style = poetryParagraphStyle(indent: currentIndent,
                                         stanzaBreak: lines.count == 1 && stanzaBreak,
                                         spacingAfter: endsPoetryRun ? endSpacing : 0)
        return OpenParagraph(start: lineStart, style: style, isPoetry: true, indent: currentIndent)
    }

    private func appendVerseNumber(_ verse: ParsedVerse, into output: NSMutableAttributedString) {
        let baselineOffset = min(max(3.0, settings.readerVerseNumberSize * 0.45), 8.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: ReaderFonts.verseNumber(size: settings.readerVerseNumberSize),
            .foregroundColor: ReaderPalette.gold,
            .baselineOffset: baselineOffset,
            .scriptureRole: ScriptureRole.verseNumber.rawValue,
            .scriptureVerseReference: verse.reference,
            .scriptureVerseNumber: verse.number,
            .scriptureBook: chapter.book,
            .scriptureChapter: chapter.chapter
        ]
        output.append(NSAttributedString(string: "\(verse.number) ", attributes: attrs))
    }

    // MARK: English word runs (bracket italics + red-letter + word metadata)

    private func appendEnglishWords(_ verse: ParsedVerse,
                                    into output: NSMutableAttributedString,
                                    isSelected: Bool,
                                    trailingSpace: Bool,
                                    raisedInitial: Bool = false) {
        appendTokens(coloredTokens(for: verse), verse: verse, into: output, isSelected: isSelected,
                     trailingSpace: trailingSpace, raisedInitial: raisedInitial)
    }

    private func appendTokens(_ tokens: [ColoredToken],
                              verse: ParsedVerse,
                              into output: NSMutableAttributedString,
                              isSelected: Bool,
                              trailingSpace: Bool,
                              raisedInitial: Bool) {
        for (index, token) in tokens.enumerated() {
            var display = token.display
            if index == tokens.count - 1 && trailingSpace && !display.hasSuffix(" ") {
                display += " "
            }
            let color: UIColor = isSelected ? palette.selectedText
                                            : (token.red ? palette.redLetter : palette.text)
            var attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont(italic: token.italic),
                .foregroundColor: color,
                .scriptureRole: ScriptureRole.verseText.rawValue,
                .scriptureVerseReference: verse.reference,
                .scriptureVerseNumber: verse.number,
                .scriptureBook: chapter.book,
                .scriptureChapter: chapter.chapter
            ]
            if !token.clean.isEmpty {
                attrs[.scriptureWord] = token.clean
            }
            if isWordLookedUp(verseID: verse.id, word: token.clean) {
                attrs[.backgroundColor] = palette.wordLookupBackground
            }
            if index == 0, raisedInitial,
               let letterIndex = display.firstIndex(where: { $0.isLetter }) {
                // Leading punctuation (an opening quote) stays body-sized.
                let prefix = String(display[..<letterIndex])
                let letter = String(display[letterIndex])
                let rest = String(display[display.index(after: letterIndex)...])
                if !prefix.isEmpty { output.append(NSAttributedString(string: prefix, attributes: attrs)) }
                var initialAttrs = attrs
                initialAttrs[.font] = ReaderCosmetics.initialFont(bodySize: settings.readerFontSize)
                initialAttrs[.foregroundColor] = ReaderPalette.gold
                output.append(NSAttributedString(string: letter, attributes: initialAttrs))
                output.append(NSAttributedString(string: rest, attributes: attrs))
                continue
            }
            output.append(NSAttributedString(string: display, attributes: attrs))
        }
    }

    // MARK: Original-language word runs (Greek LTR / Hebrew RTL)

    private func appendOriginalLanguageWords(_ verse: ParsedVerse,
                                             into output: NSMutableAttributedString,
                                             isSelected: Bool) {
        let words = verse.text.components(separatedBy: " ").filter { !$0.isEmpty }
        let font = ReaderFonts.originalLanguage(translation, size: settings.readerFontSize)
        for (index, word) in words.enumerated() {
            let display = index < words.count - 1 ? word + " " : word
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isSelected ? palette.selectedText : palette.text,
                .scriptureRole: ScriptureRole.verseText.rawValue,
                .scriptureVerseReference: verse.reference,
                .scriptureVerseNumber: verse.number,
                .scriptureBook: chapter.book,
                .scriptureChapter: chapter.chapter,
                .scriptureWord: word
            ]
            if isWordLookedUp(verseID: verse.id, word: word) {
                attrs[.backgroundColor] = palette.wordLookupBackground
            }
            output.append(NSAttributedString(string: display, attributes: attrs))
        }
    }

    // MARK: Bookmark indicator

    /// A small coral bookmark ribbon leading the verse text, marking a bookmarked verse.
    /// Tapping it carries the verse metadata so it selects the verse like the verse number does.
    private func appendBookmarkIndicator(_ verse: ParsedVerse, into output: NSMutableAttributedString) {
        let side = settings.readerVerseNumberSize
        let attachment = NSTextAttachment()
        if let image = UIImage(systemName: "bookmark.fill")?
            .withTintColor(UIColor(Color.reforgedCoral), renderingMode: .alwaysOriginal) {
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: 0, width: side * 0.78, height: side)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .scriptureRole: ScriptureRole.verseNumber.rawValue,
            .scriptureVerseReference: verse.reference,
            .scriptureVerseNumber: verse.number,
            .scriptureBook: chapter.book,
            .scriptureChapter: chapter.chapter
        ]
        let marker = NSMutableAttributedString(attachment: attachment)
        marker.append(NSAttributedString(string: " "))
        marker.addAttributes(attrs, range: NSRange(location: 0, length: marker.length))
        output.append(marker)
    }

    // MARK: Note indicator

    private func appendNoteIndicator(_ verse: ParsedVerse, into output: NSMutableAttributedString) {
        let attachment = NSTextAttachment()
        if let image = UIImage(named: "sticky-note")?.withRenderingMode(.alwaysTemplate) {
            let tinted = image.withTintColor(ReaderPalette.gold, renderingMode: .alwaysOriginal)
            attachment.image = tinted
            let side = settings.readerVerseNumberSize
            attachment.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .scriptureRole: ScriptureRole.noteIndicator.rawValue,
            .scriptureVerseReference: verse.reference,
            .scriptureVerseNumber: verse.number,
            .scriptureBook: chapter.book,
            .scriptureChapter: chapter.chapter
        ]
        let marker = NSMutableAttributedString(string: " ")
        marker.append(NSAttributedString(attachment: attachment))
        marker.addAttributes(attrs, range: NSRange(location: 0, length: marker.length))
        output.append(marker)
    }

    // MARK: Tokenization (bracket italics + WOC red-letter)

    private struct ColoredToken {
        let display: String
        let clean: String
        let italic: Bool
        let red: Bool
    }

    /// Reproduces `tokenizeColored` from the FlowLayout reader: bracket italics from
    /// `tokenizeVerseText`, red-letter flags per WOC segment. Uses `chapter.woc`, which the
    /// coordinator already gated on the Words-of-Christ setting.
    private func coloredTokens(for verse: ParsedVerse) -> [ColoredToken] {
        guard let segments = chapter.woc[verse.reference] else {
            return tokenizeVerseText(verse.text, verseId: verse.id).map {
                ColoredToken(display: $0.displayText, clean: $0.cleanWord, italic: $0.isItalic, red: false)
            }
        }

        var result: [ColoredToken] = []
        for (segIdx, segment) in segments.enumerated() {
            let isLastSeg = segIdx == segments.count - 1
            let segTokens = tokenizeVerseText(segment.text, verseId: "\(verse.id)_s\(segIdx)")
            for (tokIdx, token) in segTokens.enumerated() {
                let isLastTok = tokIdx == segTokens.count - 1
                var display = token.displayText
                if isLastTok && !isLastSeg && !display.hasSuffix(" ") {
                    display += " "
                }
                result.append(ColoredToken(display: display,
                                           clean: token.cleanWord,
                                           italic: token.isItalic,
                                           red: segment.isRed))
            }
        }
        return result
    }

    private func isWordLookedUp(verseID: String, word: String) -> Bool {
        guard let lookup = renderState.wordLookup, lookup.verseID == verseID, !word.isEmpty else { return false }
        return isOriginalLanguage ? (lookup.word == word) : (lookup.word == word.lowercased())
    }

    // MARK: Fonts / paragraph styles

    private func baseFont(italic: Bool) -> UIFont {
        if isOriginalLanguage {
            return ReaderFonts.originalLanguage(translation, size: settings.readerFontSize)
        }
        return ReaderFonts.body(settings, italic: italic)
    }

    private func bodyParagraphStyle() -> NSParagraphStyle {
        paragraphStyle(spacingAfter: 8)
    }

    private func verseByVerseParagraphStyle() -> NSParagraphStyle {
        paragraphStyle(spacingAfter: 12)
    }

    private func paragraphStyle(spacingAfter: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let multiplier: CGFloat = translation == .wlc ? 1.4 : 1.0
        style.lineSpacing = settings.lineSpacing.spacing * settings.readerHeadingScale * multiplier
        style.paragraphSpacing = spacingAfter
        style.alignment = isRTL ? .right : .left
        style.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        return style
    }
}

// MARK: - Reader cosmetics (crown shop)

enum ReaderCosmetics {
    static let illuminatedCapitalsKey = "reader_illuminated_capitals"

    static var illuminatedCapitals: Bool {
        UserDefaults.standard.bool(forKey: illuminatedCapitalsKey)
    }

    /// Folded into the attributed-text cache key so toggling an extra or
    /// switching highlighter palettes rebuilds chapters.
    static var cacheKey: String {
        "\(illuminatedCapitals)_\(HighlightPalette.current)"
    }

    static func initialFont(bodySize: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: bodySize * 2.4, weight: .bold)
        let serif = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFont(descriptor: serif, size: bodySize * 2.4)
    }
}
