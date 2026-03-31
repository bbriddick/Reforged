import SwiftUI

// MARK: - Colored Word Token

/// A word token extended with a red-letter flag for WOC rendering.
struct ColoredWordToken: Identifiable {
    let id: String
    let displayText: String  // includes trailing space where needed
    let cleanWord: String    // lowercased, punctuation stripped — for Strongs lookup
    let isItalic: Bool
    let isRed: Bool          // true → Words of Christ, render in wocColor
}

// MARK: - Segment-Aware Tokenizer

/// Converts a verse's text + optional WOC segments into `[ColoredWordToken]`.
///
/// When `wocSegments` is non-nil each segment is tokenized separately so that
/// the red-letter flag is set at the individual word level. When nil, the full
/// verse text is tokenized and every token gets `isRed = false`.
private func tokenizeColored(verseId: String,
                              verseText: String,
                              wocSegments: [WOCSegment]?) -> [ColoredWordToken] {
    // ── No WOC data ─────────────────────────────────────────────────────────
    guard let segments = wocSegments else {
        return tokenizeVerseText(verseText, verseId: verseId)
            .enumerated()
            .map { (i, t) in
                ColoredWordToken(id: "\(verseId)_c\(i)",
                                 displayText: t.displayText,
                                 cleanWord: t.cleanWord,
                                 isItalic: t.isItalic,
                                 isRed: false)
            }
    }

    // ── Per-segment tokenization ─────────────────────────────────────────────
    var result = [ColoredWordToken]()
    var globalIndex = 0

    for (segIdx, seg) in segments.enumerated() {
        let isLastSeg = segIdx == segments.count - 1
        let segTokens = tokenizeVerseText(seg.text, verseId: "\(verseId)_s\(segIdx)")

        for (tokIdx, t) in segTokens.enumerated() {
            // tokenizeVerseText omits the trailing space from the last word of each
            // segment; re-add it for non-final segments so words flow seamlessly
            // across segment boundaries inside FlowLayout.
            let isLastTok = tokIdx == segTokens.count - 1
            let displayText: String
            if isLastTok && !isLastSeg && !t.displayText.hasSuffix(" ") {
                displayText = t.displayText + " "
            } else {
                displayText = t.displayText
            }

            result.append(ColoredWordToken(id: "\(verseId)_c\(globalIndex)",
                                           displayText: displayText,
                                           cleanWord: t.cleanWord,
                                           isItalic: t.isItalic,
                                           isRed: seg.isRed))
            globalIndex += 1
        }
    }
    return result
}

// MARK: - Word Long-Press Verse Text (verse-by-verse mode)

/// Looks identical to plain text but allows long-pressing individual words for Strong's lookup.
/// Each word is an individual view within a FlowLayout, styled to match normal verse text.
/// Supports segment-level red-letter (Words of Christ) colouring via `wocSegments`.
struct WordLongPressVerseText: View {
    let verse: ParsedVerse
    let settings: BibleReadingSettings
    let highlight: VerseHighlight?
    let isSelected: Bool
    var highlightedWord: (verseID: String, word: String)? = nil
    let colorScheme: ColorScheme
    /// Segment-level WOC data. Pass `nil` to disable red-letter for this verse.
    var wocSegments: [WOCSegment]? = nil
    let onWordLongPress: (String, ParsedVerse) -> Void

    private static let wocColor = Color(red: 0.75, green: 0.1, blue: 0.1)

    private var coloredTokens: [ColoredWordToken] {
        tokenizeColored(verseId: verse.id, verseText: verse.text, wocSegments: wocSegments)
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: settings.lineSpacing.spacing) {
            ForEach(coloredTokens) { token in
                let isWordHighlighted = highlightedWord?.verseID == verse.id
                    && highlightedWord?.word == token.cleanWord.lowercased()

                Text(token.displayText)
                    .font(settings.fontType.font(size: settings.effectiveFontSize, italic: token.isItalic))
                    .foregroundStyle(tokenColor(token))
                    .background(
                        Group {
                            if isWordHighlighted {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.reforgedGold.opacity(0.25))
                                    .padding(.horizontal, -2)
                                    .padding(.vertical, -1)
                            }
                        }
                    )
                    .onLongPressGesture(minimumDuration: 0.2) {
                        HapticManager.shared.mediumImpact()
                        onWordLongPress(token.cleanWord, verse)
                    }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, highlight != nil ? 4 : 0)
        .background(
            Group {
                if let hl = highlight {
                    HighlighterBackground(color: hl.baseColor)
                }
            }
        )
    }

    private func tokenColor(_ token: ColoredWordToken) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
        }
        if token.isRed {
            return WordLongPressVerseText.wocColor
        }
        return Color.adaptiveText(colorScheme)
    }
}

// MARK: - Word Long-Press Paragraph Text (paragraph mode)

/// Looks identical to normal paragraph text but allows long-pressing individual words for Strong's lookup.
/// Uses FlowLayout with individual word views across all verses in a paragraph.
/// Each word is also tappable (single tap) to select its parent verse.
/// Selection highlight uses a seamless Rectangle per word (no rounded corners, no gaps).
/// Supports segment-level red-letter (Words of Christ) colouring via `wocSegmentsMap`.
struct WordLongPressParagraphText: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let settings: BibleReadingSettings
    let colorScheme: ColorScheme
    var highlightedWord: (verseID: String, word: String)? = nil
    /// Maps verse reference → ordered WOC segments. Empty dict disables red-letter.
    var wocSegmentsMap: [String: [WOCSegment]] = [:]
    let onVerseTap: (ParsedVerse) -> Void
    let onWordLongPress: (String, ParsedVerse) -> Void

    private static let wocColor = Color(red: 0.75, green: 0.1, blue: 0.1)

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: settings.lineSpacing.spacing) {
            ForEach(verses) { verse in
                let isSelected = readingState.isSelected(verse.reference)
                let highlight = readingState.getHighlight(for: verse.reference)
                let coloredTokens = tokenizeColored(verseId: verse.id,
                                                    verseText: verse.text,
                                                    wocSegments: wocSegmentsMap[verse.reference])

                // Superscript verse number — tap to select verse
                Text("\(verse.number) ")
                    .font(.system(size: settings.effectiveVerseNumberSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color.reforgedGold)
                    .baselineOffset(6)
                    .background(
                        Group {
                            if isSelected {
                                // Seamless flat fill — no rounded corners so it tiles with adjacent words
                                Color.reforgedGold.opacity(0.15)
                                    .padding(.vertical, -2)
                            }
                        }
                    )
                    .onTapGesture { onVerseTap(verse) }

                // Individual words for this verse — tap selects verse, long-press looks up word
                ForEach(coloredTokens) { token in
                    let isWordHighlighted = highlightedWord?.verseID == verse.id
                        && highlightedWord?.word == token.cleanWord.lowercased()

                    Text(token.displayText)
                        .font(token.isItalic
                            ? settings.fontType.font(size: settings.effectiveFontSize).italic()
                            : settings.fontType.font(size: settings.effectiveFontSize))
                        .foregroundStyle(wordColor(token: token,
                                                   isSelected: isSelected,
                                                   highlight: highlight))
                        .background(
                            Group {
                                if isWordHighlighted {
                                    // Distinct rounded highlight for word lookup — stands out from verse selection
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.reforgedGold.opacity(0.3))
                                        .padding(.horizontal, -2)
                                        .padding(.vertical, -1)
                                } else if isSelected {
                                    // Seamless flat fill — tiles perfectly with neighboring words
                                    Color.reforgedGold.opacity(0.15)
                                        .padding(.vertical, -2)
                                } else if let hl = highlight {
                                    HighlighterBackground(color: hl.baseColor)
                                }
                            }
                        )
                        .onTapGesture {
                            onVerseTap(verse)
                        }
                        .onLongPressGesture(minimumDuration: 0.3) {
                            HapticManager.shared.lightImpact()
                            onWordLongPress(token.cleanWord, verse)
                        }
                }
            }
        }
    }

    private func wordColor(token: ColoredWordToken,
                           isSelected: Bool,
                           highlight: VerseHighlight?) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
        }
        if token.isRed {
            return WordLongPressParagraphText.wocColor
        }
        return Color.adaptiveText(colorScheme)
    }
}

// MARK: - Original Language Tappable Verse Text (TR Greek / WLC Hebrew)

/// Per-word long-press for Textus Receptus (Greek) and Westminster Leningrad Codex (Hebrew).
///
/// Uses `FlowLayout(isRTL: isWLC)` so Hebrew words wrap right-to-left while Greek wraps LTR.
/// Unlike `WordLongPressVerseText`, words are split directly from `verse.text` (already Greek/Hebrew)
/// rather than tokenised via the English KJV tokeniser.
struct OriginalLanguageTappableVerseText: View {
    let verse: ParsedVerse
    let isWLC: Bool                  // false = TR Greek, true = WLC Hebrew
    let font: Font
    let lineSpacing: CGFloat
    let isSelected: Bool
    var highlightedWord: (verseID: String, word: String)? = nil
    let colorScheme: ColorScheme
    var highlight: VerseHighlight? = nil
    let onWordLongPress: (String, ParsedVerse) -> Void
    var onTap: (() -> Void)? = nil

    /// Split the verse text into individual displayable words.
    private var words: [String] {
        verse.text.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: lineSpacing, isRTL: isWLC) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let isHighlighted = highlightedWord?.verseID == verse.id
                    && highlightedWord?.word == word

                // Append a space so words don't run together inside FlowLayout.
                let displayWord = index < words.count - 1 ? word + " " : word

                Text(displayWord)
                    .font(font)
                    .foregroundStyle(wordColor)
                    .background(
                        Group {
                            if isHighlighted {
                                // Rounded gold highlight for the word being looked up
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.reforgedGold.opacity(0.3))
                                    .padding(.horizontal, -2)
                                    .padding(.vertical, -1)
                            } else if isSelected {
                                Color.reforgedGold.opacity(0.15)
                                    .padding(.vertical, -2)
                            } else if let hl = highlight {
                                HighlighterBackground(color: hl.baseColor)
                            }
                        }
                    )
                    .onTapGesture { onTap?() }
                    .onLongPressGesture(minimumDuration: 0.3) {
                        HapticManager.shared.mediumImpact()
                        onWordLongPress(word, verse)
                    }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, highlight != nil ? 4 : 0)
        .background(
            Group {
                if let hl = highlight {
                    HighlighterBackground(color: hl.baseColor)
                }
            }
        )
    }

    private var wordColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
        }
        return Color.adaptiveText(colorScheme)
    }
}
