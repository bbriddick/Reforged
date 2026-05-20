import Foundation

final class BibleSearchService {
    static let shared = BibleSearchService()

    private init() {}

    func search(query: String,
                translations: [BibleTranslation],
                pageSizePerTranslation: Int = 50) async -> [BibleSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        var combinedResults: [BibleSearchResult] = []

        for translation in translations where translation.isTextSearchable {
            do {
                let results = try await search(query: normalizedQuery,
                                               translation: translation,
                                               pageSize: pageSizePerTranslation)
                combinedResults.append(contentsOf: results)
            } catch {
                print("BibleSearchService: search failed for \(translation.rawValue): \(error)")
            }
        }

        return sortResults(combinedResults)
    }

    func search(query: String,
                translation: BibleTranslation,
                pageSize: Int = 50) async throws -> [BibleSearchResult] {
        switch translation {
        case .esv:
            return try await ESVService.shared.searchPassages(query: query, pageSize: pageSize)
                .map { BibleSearchResult(reference: $0.reference, content: $0.content, translation: .esv) }
        case .kjv:
            return await KJVService.shared.searchPassages(query: query, pageSize: pageSize)
        case .net:
            return await NETService.shared.searchPassages(query: query, pageSize: pageSize)
        case .csb, .nkjv, .nasb, .rvr1960:
            return try await ApiBibleService.shared.searchPassages(query: query, translation: translation, pageSize: pageSize)
                .map { BibleSearchResult(reference: $0.reference, content: $0.text, translation: translation) }
        case .tr, .wlc:
            return []
        }
    }

    // Built once at class load time; reused for every search sort.
    private static let bookOrder = Dictionary(uniqueKeysWithValues: BibleData.books.enumerated().map { ($1.name, $0) })

    private func sortResults(_ results: [BibleSearchResult]) -> [BibleSearchResult] {
        let bookOrder = Self.bookOrder

        return results.sorted { lhs, rhs in
            if lhs.translation != rhs.translation {
                return lhs.translation.rawValue < rhs.translation.rawValue
            }

            let lhsBook = bookName(for: lhs.reference)
            let rhsBook = bookName(for: rhs.reference)
            let lhsOrder = bookOrder[lhsBook] ?? Int.max
            let rhsOrder = bookOrder[rhsBook] ?? Int.max

            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            let lhsChapterVerse = extractChapterVerse(from: lhs.reference, bookName: lhsBook)
            let rhsChapterVerse = extractChapterVerse(from: rhs.reference, bookName: rhsBook)

            if lhsChapterVerse.chapter != rhsChapterVerse.chapter {
                return lhsChapterVerse.chapter < rhsChapterVerse.chapter
            }

            return lhsChapterVerse.verse < rhsChapterVerse.verse
        }
    }

    private static let sortedBooks = BibleData.books.sorted { $0.name.count > $1.name.count }

    private func bookName(for reference: String) -> String {
        Self.sortedBooks.first(where: { reference.hasPrefix($0.name) })?.name ?? ""
    }

    private func extractChapterVerse(from reference: String, bookName: String) -> (chapter: Int, verse: Int) {
        let suffix = reference.dropFirst(bookName.count).trimmingCharacters(in: .whitespaces)
        let parts = suffix.components(separatedBy: ":")
        let chapter = Int(parts.first ?? "") ?? 0
        let versePart = parts.count > 1 ? parts[1].components(separatedBy: "-").first ?? "" : ""
        let verse = Int(versePart) ?? 0
        return (chapter, verse)
    }
}
