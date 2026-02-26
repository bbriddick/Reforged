import UIKit

// MARK: - Profile Image Service

class ProfileImageService {
    static let shared = ProfileImageService()
    private init() {}

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Save a profile image, resized to 400x400 max
    func saveImage(_ image: UIImage) -> String? {
        let resized = resizeImage(image, maxSize: 400)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = "profile_image.jpg"
        let url = documentsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return filename
        } catch {
            print("ProfileImageService: Failed to save image: \(error)")
            return nil
        }
    }

    /// Load a profile image by filename
    func loadImage(named filename: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Delete a profile image
    func deleteImage(named filename: String) {
        let url = documentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// Get the file URL for a profile image (used for CloudKit CKAsset)
    func imageURL(named filename: String) -> URL? {
        let url = documentsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Resize image to fit within maxSize while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxSize || size.height > maxSize else { return image }

        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
