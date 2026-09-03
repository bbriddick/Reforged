import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Reflection Templates
//
// Structured devotional methods (S.O.A.P., H.E.A.R., A.C.T.S.) that scaffold a
// journal entry with guided section prompts. The editor is seeded with a bold
// header per section; the full guidance for each letter is shown alongside the
// editor in the "method guide" so saved entries stay clean.

/// Accent color for a reflection method. Resolved through the theme so navy
/// flips to an off-white glyph in dark mode (see `Color.adaptiveNavyText`).
enum ReflectionAccent {
    case navy, gold, coral

    /// Foreground color for glyphs and labels — adaptive so it stays legible
    /// on dark cards.
    func color(_ scheme: ColorScheme) -> Color {
        switch self {
        case .navy:  return Color.adaptiveNavyText(scheme)
        case .gold:  return .reforgedGold
        case .coral: return .reforgedCoral
        }
    }

    /// Base color for tinted backgrounds (used at low opacity).
    var tint: Color {
        switch self {
        case .navy:  return .reforgedNavy
        case .gold:  return .reforgedGold
        case .coral: return .reforgedCoral
        }
    }
}

/// A single lettered step within a structured reflection method
/// (e.g. the "S" — Scripture — in S.O.A.P.).
struct ReflectionSection: Identifiable {
    let letter: String
    let title: String
    let guidance: String

    var id: String { letter + title }
}

/// A structured reflection method that scaffolds a journal entry with guided prompts.
struct ReflectionTemplate: Identifiable {
    /// Stable lowercase id, e.g. "soap".
    let id: String
    /// Display name with periods, e.g. "S.O.A.P.".
    let name: String
    /// One-line list of the steps, e.g. "Scripture · Observation · Application · Prayer".
    let tagline: String
    /// A short sentence describing the method.
    let summary: String
    /// SF Symbol representing the method.
    let icon: String
    /// Accent used for the method's badge and glyphs.
    let accent: ReflectionAccent
    /// Whether the first section should be seeded with a linked verse reference.
    let seedsScripture: Bool
    /// The ordered steps of the method.
    let sections: [ReflectionSection]

    /// Compact acronym persisted on the journal entry, e.g. "SOAP".
    var acronym: String { sections.map(\.letter).joined() }
}

extension ReflectionTemplate {
    static let soap = ReflectionTemplate(
        id: "soap",
        name: "S.O.A.P.",
        tagline: "Scripture · Observation · Application · Prayer",
        summary: "A classic four-step method for reading Scripture slowly and responding in prayer.",
        icon: "book.pages",
        accent: .navy,
        seedsScripture: true,
        sections: [
            ReflectionSection(letter: "S", title: "Scripture",
                              guidance: "Write out the verse or passage that stood out to you."),
            ReflectionSection(letter: "O", title: "Observation",
                              guidance: "What is happening here? What does the text actually say?"),
            ReflectionSection(letter: "A", title: "Application",
                              guidance: "How does this truth apply to your life today?"),
            ReflectionSection(letter: "P", title: "Prayer",
                              guidance: "Write a short prayer responding to what God showed you.")
        ]
    )

    static let hear = ReflectionTemplate(
        id: "hear",
        name: "H.E.A.R.",
        tagline: "Highlight · Explain · Apply · Respond",
        summary: "A simple way to move from reading Scripture to obedience in four steps.",
        icon: "highlighter",
        accent: .gold,
        seedsScripture: true,
        sections: [
            ReflectionSection(letter: "H", title: "Highlight",
                              guidance: "Which verse or phrase stood out as you read?"),
            ReflectionSection(letter: "E", title: "Explain",
                              guidance: "What does this passage mean? Who wrote it, and why?"),
            ReflectionSection(letter: "A", title: "Apply",
                              guidance: "How does this truth apply to your life right now?"),
            ReflectionSection(letter: "R", title: "Respond",
                              guidance: "What will you do in response? Write a prayer or commitment.")
        ]
    )

    static let acts = ReflectionTemplate(
        id: "acts",
        name: "A.C.T.S.",
        tagline: "Adoration · Confession · Thanksgiving · Supplication",
        summary: "A structured way to pray through four movements of the heart.",
        icon: "hands.and.sparkles",
        accent: .coral,
        seedsScripture: false,
        sections: [
            ReflectionSection(letter: "A", title: "Adoration",
                              guidance: "Praise God for who He is."),
            ReflectionSection(letter: "C", title: "Confession",
                              guidance: "Confess where you've fallen short and receive His grace."),
            ReflectionSection(letter: "T", title: "Thanksgiving",
                              guidance: "Thank God for what He has done."),
            ReflectionSection(letter: "S", title: "Supplication",
                              guidance: "Bring your requests for yourself and others.")
        ]
    )

    /// All templates, in the order shown in the picker.
    static let all: [ReflectionTemplate] = [.soap, .hear, .acts]

    /// Looks up a template by its persisted acronym (case-insensitive).
    static func named(_ acronym: String?) -> ReflectionTemplate? {
        guard let acronym, !acronym.isEmpty else { return nil }
        return all.first { $0.acronym.caseInsensitiveCompare(acronym) == .orderedSame }
    }
}

#if canImport(UIKit)
extension ReflectionTemplate {
    /// Builds an editor scaffold: a bold header for each section with a blank
    /// line beneath to write in. When `scriptureSeed` is supplied and the method
    /// seeds Scripture, the first section is pre-filled with the reference.
    func scaffold(scriptureSeed: String? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let headerFont = UIFont.systemFont(ofSize: 17, weight: .bold)
        let bodyFont   = UIFont.systemFont(ofSize: 17)
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.label]
        let bodyAttrs:   [NSAttributedString.Key: Any] = [.font: bodyFont,   .foregroundColor: UIColor.label]

        for (index, section) in sections.enumerated() {
            result.append(NSAttributedString(string: section.title + "\n", attributes: headerAttrs))

            if index == 0, seedsScripture,
               let seed = scriptureSeed?.trimmingCharacters(in: .whitespacesAndNewlines), !seed.isEmpty {
                result.append(NSAttributedString(string: seed + "\n", attributes: bodyAttrs))
            }

            // Blank writing line, plus spacing before the next header.
            let trailing = index == sections.count - 1 ? "\n" : "\n\n"
            result.append(NSAttributedString(string: trailing, attributes: bodyAttrs))
        }
        return result
    }
}
#endif
