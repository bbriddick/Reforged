import Foundation

// MARK: - Complete Study Bible API Response Models

/// Response from /{book}/{chapter}/{verse}/{verse}/KJV-Strongs/
struct StudyBibleKJVResponse: Codable {
    let id: Int
    let verse: Int
    let kjv_json: [StudyBiblePhrase]
    let places: [StudyBiblePlace]?
}

/// Response from /{book}/{chapter}/{verse}/{verse}/ORIG/
struct StudyBibleOrigResponse: Codable {
    let id: Int
    let verse: Int
    let orig_json: [StudyBiblePhrase]
    let places: [StudyBiblePlace]?
}

/// A phrase with optional Strong's numbers
struct StudyBiblePhrase: Codable {
    let phrase: String
    let data_nums: [String]?
}

/// Place data (not used for word study, but present in response)
struct StudyBiblePlace: Codable {
    let id: Int?
    let name: String?
}

/// Response from /strongs-detail/{numbers}/
struct StudyBibleStrongsDetail: Codable {
    let id: Int
    let original_word: String       // Lexical/root form (e.g., ἀγαπάω, אֱלֹהִים)
    let number: String              // "G25" or "H430"
    let strong_definition: String   // Short Strong's definition
    let mounce_definition: String   // Mounce's dictionary (NT mainly)
    let bdb_definition: String      // BDB lexicon (OT Hebrew) - contains HTML
    let helps_word_studies: String
    let thayers_definition: String  // Thayer's lexicon (NT Greek) - contains HTML
    let transliteration: String     // e.g., "ʼĕlôhîym"
    let kjv_usage: String           // KJV translation words
    let phonetics: String           // e.g., "el-o-heem'"
    let language: String            // "Hebrew" or "Greek"
    let linked_derivation: String   // Derivation with HTML links
    let count: Int                  // Total occurrences in Bible
    let translation_counts: [TranslationCount]?
    let teach_jesus_def: String?
    let lxx_only: Bool?
}

/// KJV translation count entry
struct TranslationCount: Codable {
    let count: String
    let trans_link: String?
    let trans: String?              // "miscellaneous" for grouped entries
}

// MARK: - Processed Interlinear Data

/// A single word position in a verse with both English and original-language data
struct InterlinearWordEntry: Codable, Identifiable {
    let id: String                   // Unique ID for SwiftUI
    let englishPhrase: String        // KJV English phrase (e.g., "loved ")
    let originalWord: String         // Hebrew/Greek as used in text (e.g., ἠγάπησεν)
    let strongsNumbers: [String]     // e.g., ["G25"]

    var primaryStrongsNumber: String? { strongsNumbers.first }
}

/// Cached interlinear data for a single verse
struct CachedVerseInterlinear: Codable {
    let bookName: String
    let chapter: Int
    let verse: Int
    let words: [InterlinearWordEntry]
    let cachedAt: Date

    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < thirtyDaysAgo
    }
}

/// Cached Strong's detail from the API
struct CachedStrongsDetail: Codable {
    let detail: StudyBibleStrongsDetail
    let cachedAt: Date

    var isStale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cachedAt < thirtyDaysAgo
    }
}

// MARK: - Word Lookup Result

struct WordLookupResult: Identifiable {
    let id = UUID()
    let tappedWord: String
    let verseReference: String
    let isHebrew: Bool
    let isFromAPI: Bool              // true = exact interlinear match; false = dictionary search fallback

    // Interlinear data (from API)
    let originalWord: String         // Inflected form as in text (e.g., ἠγάπησεν)
    let lexicalForm: String          // Dictionary/root form (e.g., ἀγαπάω)
    let strongsNumber: String        // e.g., "G25"
    let transliteration: String
    let pronunciation: String
    let strongsDefinition: String    // Short Strong's definition
    let detailedDefinition: String   // BDB (Hebrew) or Thayer's (Greek), HTML stripped
    let mounceDefinition: String
    let kjvUsage: String
    let derivation: String
    let occurrenceCount: Int
    let translationCounts: [(word: String, count: Int)]

    // Fallback: bundled dictionary entries (when API unavailable)
    let strongsEntries: [StrongsEntry]
}

// MARK: - Strong's Dictionary Entry (bundled offline data)

struct StrongsEntry: Identifiable {
    let number: String       // "H1" or "G25"
    let lemma: String        // The Hebrew/Greek word
    let transliteration: String
    let pronunciation: String
    let partOfSpeech: String
    let definition: String   // Cleaned full definition
    let shortDefinition: String // Primary meaning
    let usage: String        // KJV translation words
    let source: String       // Derivation info

    var id: String { number }

    var isHebrew: Bool { number.hasPrefix("H") }

    var languageLabel: String {
        isHebrew ? "Hebrew" : "Greek"
    }
}

// MARK: - Word Token (for word-level tap targets)

struct WordToken: Identifiable {
    let id: String           // unique identifier (e.g., "v3_2" for verse 3, word index 2)
    let displayText: String  // "loved " (with trailing space/punctuation)
    let cleanWord: String    // "loved" (normalized for lookup)
}

// MARK: - Tokenizer

func tokenizeVerseText(_ text: String, verseId: String = "v") -> [WordToken] {
    // Split on whitespace, preserving trailing punctuation in displayText
    let rawWords = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    var tokens: [WordToken] = []

    for (index, raw) in rawWords.enumerated() {
        let isLast = index == rawWords.count - 1
        let display = isLast ? raw : raw + " "

        // Strip punctuation for clean lookup word
        let clean = raw
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()

        let tokenId = "\(verseId)_\(index)"

        if !clean.isEmpty {
            tokens.append(WordToken(id: tokenId, displayText: display, cleanWord: clean))
        } else {
            // Pure punctuation token - still display it
            tokens.append(WordToken(id: tokenId, displayText: display, cleanWord: raw))
        }
    }

    return tokens
}

// MARK: - Raw Dictionary JSON Structures (bundled offline dictionaries)

/// Matches the structure of StrongHebrewDictionary.json / StrongGreekDictionary.json
struct RawStrongsDictionary: Codable {
    let dict: [String: RawStrongsEntry]
}

struct RawStrongsEntry: Codable {
    let w: RawStrongsWord
    let source: String
    let meaning: String
    let usage: String
    let note: String
}

struct RawStrongsWord: Codable {
    let pos: String   // part of speech
    let pron: String  // pronunciation
    let xlit: String  // transliteration
    let src: String
    let w: String     // the actual Hebrew/Greek word (lemma)
}

// MARK: - BibleBook API Name Extension

extension BibleBook {
    /// Converts book name to the Complete Study Bible API URL format.
    /// e.g., "1 Samuel" → "1samuel", "Song of Solomon" → "songofsolomon"
    var studyBibleAPIName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
