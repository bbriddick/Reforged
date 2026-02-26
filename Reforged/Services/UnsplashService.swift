import Foundation
import UIKit

// MARK: - Unsplash API Service
// Compliant with Unsplash API Guidelines:
// - Hotlinks images from Unsplash CDN URLs
// - Triggers download tracking endpoint on use
// - Attributes photographer + Unsplash with profile links

final class UnsplashService {
    static let shared = UnsplashService()
    private init() {}

    private let accessKey = "xmX_W9xuD4j1Qew_TqTvZz39Civ2Ub7gnWWD2h6UOYY"
    private let baseURL = "https://api.unsplash.com"

    // MARK: - Models

    struct UnsplashPhoto: Codable {
        let id: String
        let urls: PhotoURLs
        let links: PhotoLinks
        let user: PhotoUser

        struct PhotoURLs: Codable {
            let raw: String
            let full: String
            let regular: String
            let small: String
            let thumb: String
        }

        struct PhotoLinks: Codable {
            let html: String
            let download_location: String
        }

        struct PhotoUser: Codable {
            let name: String
            let links: UserLinks

            struct UserLinks: Codable {
                let html: String
            }
        }
    }

    /// Attribution info for display. Contains links per Unsplash guidelines.
    struct PhotographerAttribution {
        let name: String
        let profileURL: String       // Link to photographer's Unsplash profile
        let photoURL: String          // Link to photo on Unsplash
        let downloadLocation: String  // Download tracking endpoint
    }

    // MARK: - Bundled Images

    static let bundledImageNames = [
        "verse-bg-mountains",
        "verse-bg-ocean",
        "verse-bg-forest",
        "verse-bg-sunset",
        "verse-bg-field",
        "verse-bg-sky"
    ]

    /// Returns a random bundled background image
    func randomBundledImage() -> UIImage {
        let name = Self.bundledImageNames.randomElement() ?? "verse-bg-mountains"
        return UIImage(named: name) ?? Self.fallbackGradientImage()
    }

    /// Returns all bundled images for the picker
    func allBundledImages() -> [(name: String, image: UIImage)] {
        Self.bundledImageNames.compactMap { name in
            guard let img = UIImage(named: name) else { return nil }
            return (name: name, image: img)
        }
    }

    /// Generates a solid gradient fallback if no images are available
    static func fallbackGradientImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    // MARK: - Fetch from Unsplash (Hotlinked)

    /// Fetches a random nature landscape photo from Unsplash.
    /// Returns the image loaded from Unsplash's CDN URL (hotlinked) and attribution info.
    func fetchRandomPhoto() async throws -> (image: UIImage, attribution: PhotographerAttribution) {
        var components = URLComponents(string: "\(baseURL)/photos/random")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "nature landscape"),
            URLQueryItem(name: "orientation", value: "squarish"),
            URLQueryItem(name: "content_filter", value: "high")
        ]

        guard let url = components.url else { throw UnsplashError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnsplashError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UnsplashError.httpError(httpResponse.statusCode)
        }

        let photo = try JSONDecoder().decode(UnsplashPhoto.self, from: data)

        // Build attribution with UTM parameters per Unsplash guidelines
        let utmParams = "?utm_source=reforged&utm_medium=referral"
        let attribution = PhotographerAttribution(
            name: photo.user.name,
            profileURL: photo.user.links.html + utmParams,
            photoURL: photo.links.html + utmParams,
            downloadLocation: photo.links.download_location
        )

        // Hotlink: load image directly from Unsplash CDN URL
        guard let imageURL = URL(string: photo.urls.regular) else {
            throw UnsplashError.invalidURL
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: imageData) else {
            throw UnsplashError.invalidImageData
        }

        return (image, attribution)
    }

    /// Tries Unsplash API first, falls back to bundled image on failure
    func getImage() async -> (image: UIImage, attribution: PhotographerAttribution?) {
        do {
            let result = try await fetchRandomPhoto()
            return (result.image, result.attribution)
        } catch {
            return (randomBundledImage(), nil)
        }
    }

    /// Fetches multiple random nature landscape photos in a single API call.
    /// Uses the `count` parameter (max 30 per request).
    func fetchRandomPhotos(count: Int = 10) async throws -> [UnsplashPhoto] {
        var components = URLComponents(string: "\(baseURL)/photos/random")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "nature landscape"),
            URLQueryItem(name: "orientation", value: "squarish"),
            URLQueryItem(name: "content_filter", value: "high"),
            URLQueryItem(name: "count", value: "\(min(count, 30))")
        ]

        guard let url = components.url else { throw UnsplashError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnsplashError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UnsplashError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([UnsplashPhoto].self, from: data)
    }

    /// Downloads the image for a given UnsplashPhoto and returns it with attribution.
    func loadImage(for photo: UnsplashPhoto) async -> (image: UIImage, attribution: PhotographerAttribution)? {
        let utmParams = "?utm_source=reforged&utm_medium=referral"
        let attribution = PhotographerAttribution(
            name: photo.user.name,
            profileURL: photo.user.links.html + utmParams,
            photoURL: photo.links.html + utmParams,
            downloadLocation: photo.links.download_location
        )

        // Use small URL for thumbnails / quick loading
        guard let imageURL = URL(string: photo.urls.small) else { return nil }

        do {
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: imageData) else { return nil }
            return (image, attribution)
        } catch {
            return nil
        }
    }

    /// Downloads full-resolution image for a given photo (used for final render).
    func loadFullImage(for photo: UnsplashPhoto) async -> UIImage? {
        guard let imageURL = URL(string: photo.urls.regular) else { return nil }
        do {
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    // MARK: - Download Tracking (Required by Unsplash API Guidelines)

    /// Triggers the Unsplash download endpoint when a photo is actually used
    /// (shared or saved). Required per Section 6 of API Terms.
    func trackDownload(attribution: PhotographerAttribution) {
        guard !attribution.downloadLocation.isEmpty,
              let url = URL(string: attribution.downloadLocation) else { return }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        // Fire-and-forget — don't block the UI
        Task {
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}

// MARK: - Errors

enum UnsplashError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from Unsplash"
        case .httpError(let code): return "HTTP error \(code)"
        case .invalidImageData: return "Could not decode image data"
        }
    }
}
