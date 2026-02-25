import Foundation
import UIKit

// MARK: - Unsplash API Service

final class UnsplashService {
    static let shared = UnsplashService()
    private init() {}

    private let accessKey = "YOUR_UNSPLASH_ACCESS_KEY"
    private let baseURL = "https://api.unsplash.com"

    /// Last fetched photographer info for attribution
    private(set) var lastPhotographer: PhotographerAttribution?

    // MARK: - Models

    struct UnsplashPhoto: Codable {
        let id: String
        let urls: PhotoURLs
        let user: PhotoUser

        struct PhotoURLs: Codable {
            let regular: String
            let small: String
        }

        struct PhotoUser: Codable {
            let name: String
            let links: UserLinks

            struct UserLinks: Codable {
                let html: String
            }
        }
    }

    struct PhotographerAttribution {
        let name: String
        let profileURL: String
    }

    // MARK: - Cache

    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("UnsplashImages")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cachedImagePath(for id: String) -> URL {
        cacheDirectory.appendingPathComponent("\(id).jpg")
    }

    private func cleanOldCache() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        for file in files {
            if let attrs = try? fm.attributesOfItem(atPath: file.path),
               let created = attrs[.creationDate] as? Date,
               created < cutoff {
                try? fm.removeItem(at: file)
            }
        }
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

    // MARK: - Fetch from Unsplash

    /// Fetches a random nature landscape photo from Unsplash
    func fetchRandomImage() async throws -> UIImage {
        cleanOldCache()

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

        // Store photographer attribution
        lastPhotographer = PhotographerAttribution(
            name: photo.user.name,
            profileURL: photo.user.links.html
        )

        // Download the image
        guard let imageURL = URL(string: photo.urls.regular) else {
            throw UnsplashError.invalidURL
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: imageData) else {
            throw UnsplashError.invalidImageData
        }

        // Cache it
        let cachePath = cachedImagePath(for: photo.id)
        try? imageData.write(to: cachePath)

        return image
    }

    /// Tries Unsplash API, falls back to bundled image
    func getImage() async -> (image: UIImage, photographer: PhotographerAttribution?) {
        do {
            let image = try await fetchRandomImage()
            return (image, lastPhotographer)
        } catch {
            return (randomBundledImage(), nil)
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
