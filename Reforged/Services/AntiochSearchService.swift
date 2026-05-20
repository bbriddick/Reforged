import Foundation

// MARK: - API Types

private struct AntiochResult: Decodable {
    let Index: Int
    let book_name: String
    let book_number: Int
    let chapter_number: Int
    let translation_name: String
    let verse_number: Int
    let verse_text: String
}

// MARK: - Service

final class AntiochSearchService {
    static let shared = AntiochSearchService()
    private init() {}

    private let baseURL = "https://bible-search.antioch.tech/api/search"

    // Antioch API uses some book names that differ from the app's canonical names.
    private static let bookNameFixes: [String: String] = [
        "Psalm": "Psalms",
    ]

    func search(query: String) async throws -> [(reference: String, preview: String)] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?verse_query=\(encoded)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let results = try JSONDecoder().decode([AntiochResult].self, from: data)
        return results.map { r in
            let bookName = Self.bookNameFixes[r.book_name] ?? r.book_name
            let ref = "\(bookName) \(r.chapter_number):\(r.verse_number)"
            return (reference: ref, preview: r.verse_text)
        }
    }
}
