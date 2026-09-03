import Foundation
import CoreLocation

/// A geolocated place mentioned in the Bible.
struct BiblePlace: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    /// Verses that mention this place, as canonical "Book C:V" strings.
    let verses: [String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func == (lhs: BiblePlace, rhs: BiblePlace) -> Bool { lhs.id == rhs.id }
}

/// Offline gazetteer of Bible places, bundled from openbible.info's Bible Geocoding data
/// (CC-BY). Powers the Bible Atlas and the "Places" section in verse study. Synchronous
/// lookup — no network — mirroring `CrossReferenceService`.
final class BiblePlaceService {
    static let shared = BiblePlaceService()

    private struct Bundle_: Decodable {
        let places: [BiblePlace]
        let versePlaces: [String: [String]]
    }

    private var places: [BiblePlace] = []
    private var placesByID: [String: BiblePlace] = [:]
    private var versePlaces: [String: [String]] = [:]
    private var loaded = false

    private init() {}

    /// Every place, sorted by name.
    var allPlaces: [BiblePlace] {
        ensureLoaded()
        return places
    }

    func place(id: String) -> BiblePlace? {
        ensureLoaded()
        return placesByID[id]
    }

    /// Places mentioned in a specific verse reference (e.g. "Matthew 2:1").
    func places(forVerse reference: String) -> [BiblePlace] {
        ensureLoaded()
        return (versePlaces[reference] ?? []).compactMap { placesByID[$0] }
    }

    /// Name search for the search bars / atlas. Prefix matches and more-referenced places rank
    /// first.
    func search(_ term: String, limit: Int = 6) -> [BiblePlace] {
        ensureLoaded()
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        let lower = query.lowercased()
        let matches = places.filter { $0.name.lowercased().contains(lower) }
        return Array(matches.sorted {
            let ap = $0.name.lowercased().hasPrefix(lower)
            let bp = $1.name.lowercased().hasPrefix(lower)
            if ap != bp { return ap }
            return $0.verses.count > $1.verses.count
        }.prefix(limit))
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "BiblePlaces", withExtension: "json") else {
            debugLog("BiblePlaceService: Could not find BiblePlaces.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(Bundle_.self, from: data)
            places = decoded.places.sorted { $0.name < $1.name }
            placesByID = Dictionary(decoded.places.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            versePlaces = decoded.versePlaces
        } catch {
            debugLog("BiblePlaceService: Failed to load BiblePlaces.json: \(error)")
        }
    }
}
