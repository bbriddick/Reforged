import UIKit
import SwiftUI

// MARK: - Scripture Text Metadata Attributes
//
// TextKit 2 renders one flat `NSAttributedString` per chapter instead of a tree of
// per-word SwiftUI views. To keep every interaction the FlowLayout reader supported —
// verse selection, word lookup, notes, accessibility — each character run carries the
// same domain identity the old per-word views held, attached as custom attributes.
// `ScriptureTextView` resolves a tap back to these attributes and hands the caller the
// exact same domain objects the old `onVerseTap` / `onWordLongPress` closures received.
//
// iOS port of the macOS TextKit 2 reader (see "Reforged Mac"). AppKit → UIKit: `NSColor`
// → `UIColor`, `NSFont` → `UIFont`, `NSImage` → `UIImage`. Colors bridge the existing
// SwiftUI `Color` palette (Theme.swift) via `UIColor(_:)` so the two readers are
// pixel-comparable and share one source of truth for theming.

extension NSAttributedString.Key {
    /// Canonical verse reference for the run, e.g. "John 3:16". Present on verse numbers,
    /// verse text, note indicators — everything belonging to a verse.
    static let scriptureVerseReference = NSAttributedString.Key("reforged.verseReference")
    /// Integer verse number for the run's verse.
    static let scriptureVerseNumber = NSAttributedString.Key("reforged.verseNumber")
    /// Owning book name (canonical, e.g. "1 Corinthians").
    static let scriptureBook = NSAttributedString.Key("reforged.book")
    /// Owning chapter number.
    static let scriptureChapter = NSAttributedString.Key("reforged.chapter")
    /// Normalized lookup word for a text run (lowercased/punctuation-stripped for English,
    /// original form for Greek/Hebrew). Absent on non-word runs (numbers, headings).
    static let scriptureWord = NSAttributedString.Key("reforged.word")
    /// Semantic role of the run — drives hit-testing precedence and accessibility.
    static let scriptureRole = NSAttributedString.Key("reforged.role")
}

/// The semantic role of a character run, mirroring the old view hierarchy's element kinds.
enum ScriptureRole: String {
    case chapterBook        // "JOHN" eyebrow above the chapter title
    case chapterTitle       // "Chapter 3"
    case sectionHeading     // ESV/psalm section heading
    case verseNumber        // superscript verse number
    case verseText          // body words
    case noteIndicator      // the sticky-note marker after a noted verse
}

/// A resolved hit — what a tap at a character index maps back to. Exactly the domain
/// data the SwiftUI reader's per-word closures received, so callers reuse existing actions.
struct ScriptureHit {
    let role: ScriptureRole
    let reference: String?
    let verseNumber: Int?
    let book: String?
    let chapter: Int?
    let word: String?
}

// MARK: - Reader Palette (UIKit)
//
// The builder bakes concrete colors into the attributed string (TextKit draws its own,
// unlike SwiftUI's environment-driven colors). Values bridge the SwiftUI `Color` helpers
// in Theme.swift exactly, so the TextKit reader and the FlowLayout reader are
// pixel-comparable. On a theme change the reader rebuilds the string.
struct ReaderPalette {
    let isDark: Bool
    private let scheme: ColorScheme

    init(colorScheme: ColorScheme) {
        self.scheme = colorScheme
        self.isDark = colorScheme == .dark
    }

    /// Words-of-Christ red — matches `WordLongPressVerseText.wocColor`.
    static let redLetter = UIColor(red: 0.75, green: 0.1, blue: 0.1, alpha: 1)
    /// Adaptive red-letter: in dark mode, a higher-contrast warm coral for readability.
    var redLetter: UIColor {
        isDark ? UIColor(red: 0.95, green: 0.40, blue: 0.40, alpha: 1) : Self.redLetter
    }

    /// Active brand / accent color — matches `Color.reforgedGold`.
    var gold: UIColor { UIColor(Color.reforgedGold) }
    static var gold: UIColor { UIColor(Color.reforgedGold) }
    /// Brand charcoal — matches `Color.reforgedNavy` (#333333).
    static let navy = UIColor(Color.reforgedNavy)

    /// Canvas background for the TextKit view — matches `Color.adaptiveBackground`.
    var canvasBackground: UIColor { UIColor(Color.adaptiveBackground(scheme)) }

    /// Primary verse text — matches `Color.adaptiveText`.
    var text: UIColor { UIColor(Color.adaptiveText(scheme)) }

    /// Section-heading / secondary text — matches `Color.adaptiveTextSecondary`.
    var secondaryText: UIColor { UIColor(Color.adaptiveTextSecondary(scheme)) }

    /// Foreground for a selected verse — matches `wordColor(isSelected:)` in the old reader.
    var selectedText: UIColor { isDark ? gold : Self.navy }

    /// Verse-selection wash — matches accent color at opacity 0.15.
    var selectionBackground: UIColor { gold.withAlphaComponent(0.15) }

    /// Active word-lookup wash — matches the rounded accent background at opacity 0.3.
    var wordLookupBackground: UIColor { gold.withAlphaComponent(0.3) }

    /// Audio-follow wash for the currently spoken verse (slightly stronger than selection).
    var audioBackground: UIColor { gold.withAlphaComponent(0.22) }
}

extension VerseHighlight {
    /// UIKit equivalent of `baseColor`, theme-calibrated for optimal contrast. Bridges the
    /// existing SwiftUI `baseColor` so the two readers highlight identically.
    func uiHighlightColor(isDark: Bool) -> UIColor {
        UIColor(baseColor).withAlphaComponent(isDark ? 0.30 : 0.40)
    }
}

// MARK: - Reader Fonts (UIKit)
//
// Mirrors `BibleReadingSettings.FontType.font(...)` and `VerseRow.verseFont`, translated
// from SwiftUI `Font` to UIKit `UIFont` so TextKit can lay them out.
enum ReaderFonts {
    /// Body verse text for an English translation.
    static func body(_ settings: BibleReadingSettings, italic: Bool) -> UIFont {
        font(for: settings.fontType, size: settings.readerFontSize, italic: italic)
    }

    static func font(for type: BibleReadingSettings.FontType, size: CGFloat, italic: Bool) -> UIFont {
        switch type {
        case .serif:
            let base = UIFont.systemFont(ofSize: size)
            var descriptor = base.fontDescriptor
            if let serif = descriptor.withDesign(.serif) { descriptor = serif }
            if italic {
                let traits = descriptor.symbolicTraits.union(.traitItalic)
                if let italicized = descriptor.withSymbolicTraits(traits) { descriptor = italicized }
            }
            return UIFont(descriptor: descriptor, size: size)
        case .sansSerif:
            let name = italic ? "Roboto-Italic" : "Roboto"
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }

    /// Superscript verse number — bold rounded gold, matching the SwiftUI `.rounded` design.
    static func verseNumber(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }

    /// Verse body font for original-language texts, matching `VerseRow.verseFont`.
    static func originalLanguage(_ translation: BibleTranslation, size: CGFloat) -> UIFont {
        switch translation {
        case .wlc:
            return UIFont(name: "Ezra SIL", size: size * 1.2)
                ?? UIFont(name: "Arial Hebrew", size: size * 1.2)
                ?? UIFont.systemFont(ofSize: size * 1.2)
        case .tr, .sblgnt:
            return UIFont(name: "Roboto", size: size * 1.1) ?? UIFont.systemFont(ofSize: size * 1.1)
        default:
            return UIFont.systemFont(ofSize: size)
        }
    }

    /// `scale` is `BibleReadingSettings.readerHeadingScale` (system text size), 1.0 by default.
    static func sectionHeading(scale: CGFloat = 1) -> UIFont {
        let size = 13 * scale
        return UIFont(name: "LibreBaskerville-Italic", size: size)
            ?? {
                let base = UIFont.systemFont(ofSize: size)
                if let d = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
                    return UIFont(descriptor: d, size: size)
                }
                return base
            }()
    }

    static func chapterBookEyebrow(scale: CGFloat = 1) -> UIFont {
        UIFont.systemFont(ofSize: 12 * scale, weight: .medium)
    }
    static func chapterTitle(scale: CGFloat = 1) -> UIFont {
        UIFont.systemFont(ofSize: 28 * scale, weight: .bold)
    }
}

// MARK: - Interactive Render State

/// The per-chapter interaction overlay applied while building the attributed string —
/// the TextKit equivalent of the state the old per-word views read from `BibleReadingState`.
struct ScriptureRenderState {
    var selectedReferences: Set<String> = []
    var highlightsByReference: [String: VerseHighlight] = [:]
    var notedReferences: Set<String> = []
    var bookmarkedReferences: Set<String> = []
    /// The word currently being looked up, e.g. ("John 3:16", "loved").
    var wordLookup: (verseID: String, word: String)? = nil
    /// The verse the audio player is currently speaking (highlighted only in follow mode).
    var audioReference: String? = nil

    static let empty = ScriptureRenderState()
}
