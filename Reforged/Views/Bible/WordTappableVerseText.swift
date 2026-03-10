import SwiftUI

// MARK: - Word Long-Press Verse Text (verse-by-verse mode)

/// Looks identical to plain text but allows long-pressing individual words for Strong's lookup.
/// Each word is an individual view within a FlowLayout, styled to match normal verse text.
struct WordLongPressVerseText: View {
    let verse: ParsedVerse
    let settings: BibleReadingSettings
    let highlight: VerseHighlight?
    let isSelected: Bool
    var highlightedWord: (verseID: String, word: String)? = nil
    let colorScheme: ColorScheme
    let onWordLongPress: (String, ParsedVerse) -> Void

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: settings.lineSpacing.spacing) {
            ForEach(tokenizeVerseText(verse.text, verseId: verse.id)) { token in
                let isWordHighlighted = highlightedWord?.verseID == verse.id
                    && highlightedWord?.word == token.cleanWord.lowercased()

                Text(token.displayText)
                    .font(.system(size: settings.effectiveFontSize, weight: .regular, design: settings.fontType.design))
                    .foregroundStyle(textColor)
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

    private var textColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
        }
        return Color.adaptiveText(colorScheme)
    }
}

// MARK: - Word Long-Press Paragraph Text (paragraph mode)

/// Looks identical to normal paragraph text but allows long-pressing individual words for Strong's lookup.
/// Uses FlowLayout with individual word views across all verses in a paragraph.
/// Each word is also tappable (single tap) to select its parent verse.
/// Selection highlight uses a seamless Rectangle per word (no rounded corners, no gaps).
struct WordLongPressParagraphText: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let settings: BibleReadingSettings
    let colorScheme: ColorScheme
    var highlightedWord: (verseID: String, word: String)? = nil
    let onVerseTap: (ParsedVerse) -> Void
    let onWordLongPress: (String, ParsedVerse) -> Void

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: settings.lineSpacing.spacing) {
            ForEach(verses) { verse in
                let isSelected = readingState.isSelected(verse.reference)
                let highlight = readingState.getHighlight(for: verse.reference)

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
                ForEach(tokenizeVerseText(verse.text, verseId: verse.id)) { token in
                    let isWordHighlighted = highlightedWord?.verseID == verse.id
                        && highlightedWord?.word == token.cleanWord.lowercased()

                    Text(token.displayText)
                        .font(.system(size: settings.effectiveFontSize, weight: .regular, design: settings.fontType.design))
                        .foregroundStyle(wordColor(isSelected: isSelected, highlight: highlight))
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

    private func wordColor(isSelected: Bool, highlight: VerseHighlight?) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.reforgedGold : Color.reforgedNavy
        }
        return Color.adaptiveText(colorScheme)
    }
}
