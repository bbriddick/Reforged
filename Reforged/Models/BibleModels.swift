import Foundation
import SwiftUI

// MARK: - Parsed Verse Model

struct ParsedVerse: Identifiable, Equatable {
    let id: String
    let number: Int
    let text: String
    let reference: String // e.g., "John 3:16"
    var startsNewParagraph: Bool = false // Indicates if this verse starts a new paragraph
    var sectionHeading: String? = nil // Section heading that appears before this verse (e.g., "The Word Became Flesh")

    static func == (lhs: ParsedVerse, rhs: ParsedVerse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Bible Search Result (Unified)

struct BibleSearchResult: Identifiable {
    let reference: String
    let content: String

    var id: String { reference }
}

// MARK: - Verse Highlight

struct VerseHighlight: Codable, Identifiable {
    let id: String
    let reference: String // e.g., "John 3:16"
    let book: String
    let chapter: Int
    let verse: Int
    let color: String // hex color
    let createdAt: String

    /// Returns the base color for this highlight
    var baseColor: Color {
        switch color {
        case "yellow": return Color(red: 1.0, green: 0.95, blue: 0.0) // Bright highlighter yellow
        case "green": return Color(red: 0.0, green: 0.9, blue: 0.4) // Bright highlighter green
        case "blue": return Color(red: 0.4, green: 0.8, blue: 1.0) // Light highlighter blue
        case "pink": return Color(red: 1.0, green: 0.6, blue: 0.8) // Soft highlighter pink
        case "orange": return Color(red: 1.0, green: 0.7, blue: 0.2) // Bright highlighter orange
        case "purple": return Color(red: 0.8, green: 0.6, blue: 1.0) // Soft highlighter purple
        default: return Color(red: 1.0, green: 0.95, blue: 0.0)
        }
    }

    /// Deprecated - use baseColor with HighlighterBackground view instead
    var highlightColor: Color {
        baseColor.opacity(0.5)
    }
}

// MARK: - Verse Note

struct VerseNote: Codable, Identifiable {
    let id: String
    let reference: String // e.g., "John 3:16"
    let book: String
    let chapter: Int
    let verse: Int
    let content: String
    let createdAt: String
    var updatedAt: String
    var crossReferences: [String]   // e.g., ["Romans 8:28", "Genesis 1:1"]

    enum CodingKeys: String, CodingKey {
        case id, reference, book, chapter, verse, content, createdAt, updatedAt, crossReferences
    }

    init(id: String, reference: String, book: String, chapter: Int, verse: Int,
         content: String, createdAt: String, updatedAt: String, crossReferences: [String] = []) {
        self.id = id
        self.reference = reference
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.crossReferences = crossReferences
    }

    // Custom decoder for backward-compatibility with notes saved before this field existed
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        reference      = try c.decode(String.self, forKey: .reference)
        book           = try c.decode(String.self, forKey: .book)
        chapter        = try c.decode(Int.self,    forKey: .chapter)
        verse          = try c.decode(Int.self,    forKey: .verse)
        content        = try c.decode(String.self, forKey: .content)
        createdAt      = try c.decode(String.self, forKey: .createdAt)
        updatedAt      = try c.decode(String.self, forKey: .updatedAt)
        crossReferences = (try? c.decode([String].self, forKey: .crossReferences)) ?? []
    }
}

// MARK: - Highlight Colors

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case orange
    case purple

    var id: String { rawValue }

    /// The solid color for color picker display
    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.0)
        case .green: return Color(red: 0.0, green: 0.9, blue: 0.4)
        case .blue: return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.6, blue: 0.8)
        case .orange: return Color(red: 1.0, green: 0.7, blue: 0.2)
        case .purple: return Color(red: 0.8, green: 0.6, blue: 1.0)
        }
    }

    /// The semi-transparent highlighter color for backgrounds
    var highlightColor: Color {
        color.opacity(0.5)
    }
}

// MARK: - Highlighter Background Shape

/// Creates a natural highlighter stroke effect — one smooth swoop per edge
struct HighlighterShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top edge: single gentle arc, lifts slightly in the first third
        // then eases back down — like a marker drawn left-to-right in one stroke
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 1.0))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 0.5),
            control1: CGPoint(x: rect.width * 0.28, y: rect.minY - 1.2),
            control2: CGPoint(x: rect.width * 0.72, y: rect.minY + 0.8)
        )

        // Right edge: straight drop
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 0.5))

        // Bottom edge: single gentle swoop going right-to-left,
        // bowing slightly outward in the latter half
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - 1.0),
            control1: CGPoint(x: rect.width * 0.72, y: rect.maxY + 1.5),
            control2: CGPoint(x: rect.width * 0.28, y: rect.maxY + 0.5)
        )

        path.closeSubpath()
        return path
    }
}

/// A view that displays a realistic highlighter effect behind content
struct HighlighterBackground: View {
    let color: Color
    var isActive: Bool = true

    var body: some View {
        if isActive {
            ZStack {
                // Main highlighter layer
                HighlighterShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.55),
                                color.opacity(0.45),
                                color.opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Subtle edge darkening for depth
                HighlighterShape()
                    .stroke(color.opacity(0.15), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Book Categories

enum BookCategory: String, CaseIterable, Identifiable {
    case law = "Law"
    case history = "History"
    case poetryWisdom = "Poetry"
    case prophets = "Prophets"
    case gospels = "Gospels"
    case acts = "History (NT)"
    case letters = "Letters"
    case prophecy = "Prophecy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .law: return "scroll"
        case .history, .acts: return "clock"
        case .poetryWisdom: return "music.note"
        case .prophets: return "megaphone"
        case .gospels: return "book"
        case .letters: return "envelope"
        case .prophecy: return "eye"
        }
    }
}

// MARK: - Bible Book Data

struct BibleBook: Identifiable {
    let id: String
    let name: String
    let abbreviation: String
    let chapters: Int
    let testament: Testament

    enum Testament {
        case old
        case new
    }

    var category: BookCategory {
        switch id {
        // Law/Pentateuch
        case "gen", "exo", "lev", "num", "deu": return .law
        // OT History
        case "jos", "jdg", "rut", "1sa", "2sa", "1ki", "2ki", "1ch", "2ch", "ezr", "neh", "est": return .history
        // Poetry/Wisdom
        case "job", "psa", "pro", "ecc", "sng": return .poetryWisdom
        // Prophets (Major + Minor)
        case "isa", "jer", "lam", "ezk", "dan",
             "hos", "jol", "amo", "oba", "jon", "mic",
             "nam", "hab", "zep", "hag", "zec", "mal": return .prophets
        // Gospels
        case "mat", "mrk", "luk", "jhn": return .gospels
        // Acts
        case "act": return .acts
        // Letters/Epistles
        case "rom", "1co", "2co", "gal", "eph", "php", "col",
             "1th", "2th", "1ti", "2ti", "tit", "phm",
             "heb", "jas", "1pe", "2pe", "1jn", "2jn", "3jn", "jud": return .letters
        // Prophecy/Apocalyptic
        case "rev": return .prophecy
        default: return .history
        }
    }
}

// MARK: - Bible Data

struct BibleData {
    static let books: [BibleBook] = [
        // Old Testament
        BibleBook(id: "gen", name: "Genesis", abbreviation: "Gen", chapters: 50, testament: .old),
        BibleBook(id: "exo", name: "Exodus", abbreviation: "Exod", chapters: 40, testament: .old),
        BibleBook(id: "lev", name: "Leviticus", abbreviation: "Lev", chapters: 27, testament: .old),
        BibleBook(id: "num", name: "Numbers", abbreviation: "Num", chapters: 36, testament: .old),
        BibleBook(id: "deu", name: "Deuteronomy", abbreviation: "Deut", chapters: 34, testament: .old),
        BibleBook(id: "jos", name: "Joshua", abbreviation: "Josh", chapters: 24, testament: .old),
        BibleBook(id: "jdg", name: "Judges", abbreviation: "Judg", chapters: 21, testament: .old),
        BibleBook(id: "rut", name: "Ruth", abbreviation: "Ruth", chapters: 4, testament: .old),
        BibleBook(id: "1sa", name: "1 Samuel", abbreviation: "1 Sam", chapters: 31, testament: .old),
        BibleBook(id: "2sa", name: "2 Samuel", abbreviation: "2 Sam", chapters: 24, testament: .old),
        BibleBook(id: "1ki", name: "1 Kings", abbreviation: "1 Kgs", chapters: 22, testament: .old),
        BibleBook(id: "2ki", name: "2 Kings", abbreviation: "2 Kgs", chapters: 25, testament: .old),
        BibleBook(id: "1ch", name: "1 Chronicles", abbreviation: "1 Chr", chapters: 29, testament: .old),
        BibleBook(id: "2ch", name: "2 Chronicles", abbreviation: "2 Chr", chapters: 36, testament: .old),
        BibleBook(id: "ezr", name: "Ezra", abbreviation: "Ezra", chapters: 10, testament: .old),
        BibleBook(id: "neh", name: "Nehemiah", abbreviation: "Neh", chapters: 13, testament: .old),
        BibleBook(id: "est", name: "Esther", abbreviation: "Esth", chapters: 10, testament: .old),
        BibleBook(id: "job", name: "Job", abbreviation: "Job", chapters: 42, testament: .old),
        BibleBook(id: "psa", name: "Psalms", abbreviation: "Ps", chapters: 150, testament: .old),
        BibleBook(id: "pro", name: "Proverbs", abbreviation: "Prov", chapters: 31, testament: .old),
        BibleBook(id: "ecc", name: "Ecclesiastes", abbreviation: "Eccl", chapters: 12, testament: .old),
        BibleBook(id: "sng", name: "Song of Solomon", abbreviation: "Song", chapters: 8, testament: .old),
        BibleBook(id: "isa", name: "Isaiah", abbreviation: "Isa", chapters: 66, testament: .old),
        BibleBook(id: "jer", name: "Jeremiah", abbreviation: "Jer", chapters: 52, testament: .old),
        BibleBook(id: "lam", name: "Lamentations", abbreviation: "Lam", chapters: 5, testament: .old),
        BibleBook(id: "ezk", name: "Ezekiel", abbreviation: "Ezek", chapters: 48, testament: .old),
        BibleBook(id: "dan", name: "Daniel", abbreviation: "Dan", chapters: 12, testament: .old),
        BibleBook(id: "hos", name: "Hosea", abbreviation: "Hos", chapters: 14, testament: .old),
        BibleBook(id: "jol", name: "Joel", abbreviation: "Joel", chapters: 3, testament: .old),
        BibleBook(id: "amo", name: "Amos", abbreviation: "Amos", chapters: 9, testament: .old),
        BibleBook(id: "oba", name: "Obadiah", abbreviation: "Obad", chapters: 1, testament: .old),
        BibleBook(id: "jon", name: "Jonah", abbreviation: "Jonah", chapters: 4, testament: .old),
        BibleBook(id: "mic", name: "Micah", abbreviation: "Mic", chapters: 7, testament: .old),
        BibleBook(id: "nam", name: "Nahum", abbreviation: "Nah", chapters: 3, testament: .old),
        BibleBook(id: "hab", name: "Habakkuk", abbreviation: "Hab", chapters: 3, testament: .old),
        BibleBook(id: "zep", name: "Zephaniah", abbreviation: "Zeph", chapters: 3, testament: .old),
        BibleBook(id: "hag", name: "Haggai", abbreviation: "Hag", chapters: 2, testament: .old),
        BibleBook(id: "zec", name: "Zechariah", abbreviation: "Zech", chapters: 14, testament: .old),
        BibleBook(id: "mal", name: "Malachi", abbreviation: "Mal", chapters: 4, testament: .old),
        // New Testament
        BibleBook(id: "mat", name: "Matthew", abbreviation: "Matt", chapters: 28, testament: .new),
        BibleBook(id: "mrk", name: "Mark", abbreviation: "Mark", chapters: 16, testament: .new),
        BibleBook(id: "luk", name: "Luke", abbreviation: "Luke", chapters: 24, testament: .new),
        BibleBook(id: "jhn", name: "John", abbreviation: "John", chapters: 21, testament: .new),
        BibleBook(id: "act", name: "Acts", abbreviation: "Acts", chapters: 28, testament: .new),
        BibleBook(id: "rom", name: "Romans", abbreviation: "Rom", chapters: 16, testament: .new),
        BibleBook(id: "1co", name: "1 Corinthians", abbreviation: "1 Cor", chapters: 16, testament: .new),
        BibleBook(id: "2co", name: "2 Corinthians", abbreviation: "2 Cor", chapters: 13, testament: .new),
        BibleBook(id: "gal", name: "Galatians", abbreviation: "Gal", chapters: 6, testament: .new),
        BibleBook(id: "eph", name: "Ephesians", abbreviation: "Eph", chapters: 6, testament: .new),
        BibleBook(id: "php", name: "Philippians", abbreviation: "Phil", chapters: 4, testament: .new),
        BibleBook(id: "col", name: "Colossians", abbreviation: "Col", chapters: 4, testament: .new),
        BibleBook(id: "1th", name: "1 Thessalonians", abbreviation: "1 Thess", chapters: 5, testament: .new),
        BibleBook(id: "2th", name: "2 Thessalonians", abbreviation: "2 Thess", chapters: 3, testament: .new),
        BibleBook(id: "1ti", name: "1 Timothy", abbreviation: "1 Tim", chapters: 6, testament: .new),
        BibleBook(id: "2ti", name: "2 Timothy", abbreviation: "2 Tim", chapters: 4, testament: .new),
        BibleBook(id: "tit", name: "Titus", abbreviation: "Titus", chapters: 3, testament: .new),
        BibleBook(id: "phm", name: "Philemon", abbreviation: "Phlm", chapters: 1, testament: .new),
        BibleBook(id: "heb", name: "Hebrews", abbreviation: "Heb", chapters: 13, testament: .new),
        BibleBook(id: "jas", name: "James", abbreviation: "Jas", chapters: 5, testament: .new),
        BibleBook(id: "1pe", name: "1 Peter", abbreviation: "1 Pet", chapters: 5, testament: .new),
        BibleBook(id: "2pe", name: "2 Peter", abbreviation: "2 Pet", chapters: 3, testament: .new),
        BibleBook(id: "1jn", name: "1 John", abbreviation: "1 John", chapters: 5, testament: .new),
        BibleBook(id: "2jn", name: "2 John", abbreviation: "2 John", chapters: 1, testament: .new),
        BibleBook(id: "3jn", name: "3 John", abbreviation: "3 John", chapters: 1, testament: .new),
        BibleBook(id: "jud", name: "Jude", abbreviation: "Jude", chapters: 1, testament: .new),
        BibleBook(id: "rev", name: "Revelation", abbreviation: "Rev", chapters: 22, testament: .new)
    ]

    static var oldTestament: [BibleBook] {
        books.filter { $0.testament == .old }
    }

    static var newTestament: [BibleBook] {
        books.filter { $0.testament == .new }
    }

    static func book(named name: String) -> BibleBook? {
        books.first { $0.name == name }
    }

    static func chaptersIn(book: String) -> Int {
        books.first { $0.name == book }?.chapters ?? 1
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let bibleDataDidChange = Notification.Name("bibleDataDidChange")
}

// MARK: - Bible Reading State

class BibleReadingState: ObservableObject {
    // Shared singleton instance for syncing across views
    static let shared = BibleReadingState()

    @Published var highlights: [String: VerseHighlight] = [:] // keyed by reference
    @Published var notes: [String: VerseNote] = [:] // keyed by reference
    @Published var selectedVerses: Set<String> = []
    @Published var currentBook: String = "John"
    @Published var currentChapter: Int = 1

    /// Flag to prevent sync loop when loading from cloud
    var isSyncingFromCloud = false

    private let highlightsKey = "bible_highlights"
    private let notesKey = "bible_notes"

    init() {
        loadFromStorage()
    }

    // MARK: - Highlights

    func highlight(reference: String, book: String, chapter: Int, verse: Int, color: HighlightColor) {
        let highlight = VerseHighlight(
            id: UUID().uuidString,
            reference: reference,
            book: book,
            chapter: chapter,
            verse: verse,
            color: color.rawValue,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        highlights[reference] = highlight
        saveToStorage()
    }

    func removeHighlight(reference: String) {
        highlights.removeValue(forKey: reference)
        saveToStorage()
    }

    func getHighlight(for reference: String) -> VerseHighlight? {
        highlights[reference]
    }

    // MARK: - Notes

    func addNote(reference: String, book: String, chapter: Int, verse: Int,
                 content: String, crossReferences: [String] = []) {
        let now = ISO8601DateFormatter().string(from: Date())
        let note = VerseNote(
            id: UUID().uuidString,
            reference: reference,
            book: book,
            chapter: chapter,
            verse: verse,
            content: content,
            createdAt: now,
            updatedAt: now,
            crossReferences: crossReferences
        )
        notes[reference] = note
        saveToStorage()
    }

    func updateNote(reference: String, content: String, crossReferences: [String] = []) {
        guard var note = notes[reference] else { return }
        note.updatedAt = ISO8601DateFormatter().string(from: Date())
        notes[reference] = VerseNote(
            id: note.id,
            reference: note.reference,
            book: note.book,
            chapter: note.chapter,
            verse: note.verse,
            content: content,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            crossReferences: crossReferences
        )
        saveToStorage()
    }

    func removeNote(reference: String) {
        notes.removeValue(forKey: reference)
        saveToStorage()
    }

    func getNote(for reference: String) -> VerseNote? {
        notes[reference]
    }

    /// Get all notes sorted by date (most recent first)
    var allNotes: [VerseNote] {
        notes.values.sorted { note1, note2 in
            // Sort by updatedAt, most recent first
            note1.updatedAt > note2.updatedAt
        }
    }

    // MARK: - Selection

    func toggleSelection(_ reference: String) {
        if selectedVerses.contains(reference) {
            selectedVerses.remove(reference)
        } else {
            selectedVerses.insert(reference)
        }
    }

    func clearSelection() {
        selectedVerses.removeAll()
    }

    func isSelected(_ reference: String) -> Bool {
        selectedVerses.contains(reference)
    }

    // MARK: - Persistence

    private func saveToStorage() {
        if let highlightsData = try? JSONEncoder().encode(Array(highlights.values)) {
            UserDefaults.standard.set(highlightsData, forKey: highlightsKey)
        }
        if let notesData = try? JSONEncoder().encode(Array(notes.values)) {
            UserDefaults.standard.set(notesData, forKey: notesKey)
        }
        // Notify AppState to trigger cloud sync (skip if loading from cloud to avoid loop)
        if !isSyncingFromCloud {
            NotificationCenter.default.post(name: .bibleDataDidChange, object: nil)
        }
    }

    private func loadFromStorage() {
        if let highlightsData = UserDefaults.standard.data(forKey: highlightsKey),
           let highlightsArray = try? JSONDecoder().decode([VerseHighlight].self, from: highlightsData) {
            highlights = Dictionary(uniqueKeysWithValues: highlightsArray.map { ($0.reference, $0) })
        }
        if let notesData = UserDefaults.standard.data(forKey: notesKey),
           let notesArray = try? JSONDecoder().decode([VerseNote].self, from: notesData) {
            notes = Dictionary(uniqueKeysWithValues: notesArray.map { ($0.reference, $0) })
        }
    }

    /// Writes the current in-memory highlights and notes to UserDefaults without posting
    /// the `.bibleDataDidChange` notification. Called after loading data from CloudKit so
    /// the merged state survives a cold restart before the next sync.
    func persistToStorage() {
        if let data = try? JSONEncoder().encode(Array(highlights.values)) {
            UserDefaults.standard.set(data, forKey: highlightsKey)
        }
        if let data = try? JSONEncoder().encode(Array(notes.values)) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }
}
