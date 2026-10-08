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
            .font: ReaderFonts.chapterBookEyebrow(),
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
            .font: ReaderFonts.chapterTitle(),
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
            .font: ReaderFonts.sectionHeading(),
            .foregroundColor: palette.secondaryText,
            .paragraphStyle: style,
            .scriptureRole: ScriptureRole.sectionHeading.rawValue
        ]
        output.append(NSAttributedString(string: heading + "\n", attributes: attrs))
    }

    // MARK: Paragraph mode

    private func appendParagraphs(into output: NSMutableAttributedString) {
        for section in chapter.sections {
            if let heading = section.heading {
                appendSectionHeading(heading, into: output)
            }
            let paragraphStart = output.length
            for (index, verse) in section.verses.enumerated() {
                appendVerse(verse, into: output, trailingSpace: index < section.verses.count - 1)
            }
            output.append(NSAttributedString(string: "\n", attributes: [
                .paragraphStyle: bodyParagraphStyle(),
                .font: baseFont(italic: false)
            ]))
            let paragraphRange = NSRange(location: paragraphStart, length: output.length - paragraphStart)
            output.addAttribute(.paragraphStyle, value: bodyParagraphStyle(), range: paragraphRange)
        }
    }

    // MARK: Verse-by-verse mode

    private func appendVerseByVerse(into output: NSMutableAttributedString) {
        for verse in chapter.verses {
            if let heading = verse.sectionHeading {
                appendSectionHeading(heading, into: output)
            }
            let verseStart = output.length
            appendVerse(verse, into: output, trailingSpace: false)
            output.append(NSAttributedString(string: "\n", attributes: [
                .paragraphStyle: verseByVerseParagraphStyle(),
                .font: baseFont(italic: false)
            ]))
            let range = NSRange(location: verseStart, length: output.length - verseStart)
            output.addAttribute(.paragraphStyle, value: verseByVerseParagraphStyle(), range: range)
        }
    }

    // MARK: One verse

    private func appendVerse(_ verse: ParsedVerse,
                             into output: NSMutableAttributedString,
                             trailingSpace: Bool) {
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

        if isOriginalLanguage {
            appendOriginalLanguageWords(verse, into: output, isSelected: isSelected)
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
    }

    private func appendVerseNumber(_ verse: ParsedVerse, into output: NSMutableAttributedString) {
        let baselineOffset = min(max(3.0, settings.effectiveVerseNumberSize * 0.45), 8.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: ReaderFonts.verseNumber(size: settings.effectiveVerseNumberSize),
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
        let tokens = coloredTokens(for: verse)
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
                initialAttrs[.font] = ReaderCosmetics.initialFont(bodySize: settings.effectiveFontSize)
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
        let font = ReaderFonts.originalLanguage(translation, size: settings.effectiveFontSize)
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
        let side = settings.effectiveVerseNumberSize
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
            let side = settings.effectiveVerseNumberSize
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
            return ReaderFonts.originalLanguage(translation, size: settings.effectiveFontSize)
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
        style.lineSpacing = settings.lineSpacing.spacing * multiplier
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
