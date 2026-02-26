import SwiftUI

// MARK: - Verse Share Selection Model

struct VerseShareSelection: Identifiable {
    let id = UUID()
    let verses: [ParsedVerse]
    let book: String
    let chapter: Int
    let translation: String

    var referenceText: String {
        guard !verses.isEmpty else { return "" }
        let numbers = verses.map { $0.number }.sorted()
        if numbers.count == 1 {
            return "\(book) \(chapter):\(numbers[0])"
        }
        let isConsecutive = numbers.count == (numbers.last! - numbers.first! + 1)
        if isConsecutive {
            return "\(book) \(chapter):\(numbers.first!)-\(numbers.last!)"
        }
        let refs = numbers.map { String($0) }.joined(separator: ", ")
        return "\(book) \(chapter):\(refs)"
    }

    var fullText: String {
        verses.sorted(by: { $0.number < $1.number }).map { $0.text }.joined(separator: " ")
    }
}

// MARK: - Unsplash Thumbnail Model

struct UnsplashThumbnail: Identifiable {
    let id: String
    let photo: UnsplashService.UnsplashPhoto
    var thumbnail: UIImage?
    var fullImage: UIImage?
    var attribution: UnsplashService.PhotographerAttribution
}

// MARK: - Shareable Verse Card (1080x1080)

struct VerseShareCard: View {
    let verseText: String
    let reference: String
    let translation: String
    let backgroundImage: UIImage
    let photographerName: String?

    var body: some View {
        ZStack {
            // Background image (hotlinked from Unsplash CDN)
            Image(uiImage: backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 1080)
                .clipped()

            // Dark overlay for text legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Decorative top accent
                Rectangle()
                    .fill(Color.reforgedGold.opacity(0.6))
                    .frame(width: 60, height: 3)
                    .clipShape(Capsule())

                Spacer().frame(height: 40)

                // Verse text
                Text("\u{201C}\(verseText)\u{201D}")
                    .font(.system(size: verseFontSize, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.horizontal, 80)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                Spacer().frame(height: 36)

                // Reference
                Text("\(reference) (\(translation))")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.reforgedGold)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                Spacer()

                // Bottom section: branding + photographer credit
                VStack(spacing: 8) {
                    Text("REFORGED")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(4)

                    if let photographer = photographerName {
                        Text("Photo by \(photographer) on Unsplash")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .frame(width: 1080, height: 1080)
        .environment(\.colorScheme, .dark)
    }

    private var verseFontSize: CGFloat {
        let length = verseText.count
        if length < 80 { return 42 }
        if length < 150 { return 36 }
        if length < 250 { return 30 }
        if length < 400 { return 26 }
        return 22
    }
}

// MARK: - Verse Share Sheet

struct VerseShareSheet: View {
    let selection: VerseShareSelection
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedImage: UIImage?
    @State private var currentAttribution: UnsplashService.PhotographerAttribution?
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false

    // Bundled images
    @State private var bundledImages: [(name: String, image: UIImage)] = []

    // Unsplash images
    @State private var unsplashThumbnails: [UnsplashThumbnail] = []
    @State private var isLoadingInitial = false
    @State private var isLoadingMore = false
    @State private var selectedUnsplashId: String?

    private var currentBackground: UIImage {
        selectedImage ?? UnsplashService.fallbackGradientImage()
    }

    private var shareCard: some View {
        VerseShareCard(
            verseText: selection.fullText,
            reference: selection.referenceText,
            translation: selection.translation,
            backgroundImage: currentBackground,
            photographerName: currentAttribution?.name
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 8)

                        // Preview card
                        shareCard
                            .scaleEffect(0.3)
                            .frame(width: 324, height: 324)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)

                        // Unsplash attribution link
                        if let attribution = currentAttribution {
                            HStack(spacing: 4) {
                                Text("Photo by")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                                Link(attribution.name, destination: URL(string: attribution.profileURL)!)
                                    .font(.caption2)
                                    .fontWeight(.medium)

                                Text("on")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                                Link("Unsplash", destination: URL(string: "https://unsplash.com/?utm_source=reforged&utm_medium=referral")!)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }

                        // MARK: - Bundled Backgrounds
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Backgrounds")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(bundledImages, id: \.name) { item in
                                        Button {
                                            selectBundledImage(item.image)
                                        } label: {
                                            thumbnailView(image: item.image, isSelected: selectedUnsplashId == nil && selectedImage === item.image)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        // MARK: - Unsplash Images
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                    Text("Unsplash")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                }

                                Spacer()

                                // Load More button
                                Button {
                                    loadMoreUnsplashImages()
                                } label: {
                                    HStack(spacing: 5) {
                                        if isLoadingMore {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        Text("Load More")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.adaptiveNavyText(colorScheme))
                                    .clipShape(Capsule())
                                }
                                .disabled(isLoadingMore || isLoadingInitial)
                            }
                            .padding(.horizontal, 24)

                            if isLoadingInitial && unsplashThumbnails.isEmpty {
                                // Initial loading state
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("Loading images...")
                                            .font(.caption)
                                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(unsplashThumbnails) { item in
                                            Button {
                                                selectUnsplashImage(item)
                                            } label: {
                                                if let thumb = item.thumbnail {
                                                    thumbnailView(image: thumb, isSelected: selectedUnsplashId == item.id)
                                                } else {
                                                    // Placeholder while loading thumbnail
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: 64, height: 64)
                                                        .overlay(
                                                            ProgressView()
                                                                .scaleEffect(0.6)
                                                        )
                                                }
                                            }
                                            .disabled(item.thumbnail == nil)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }

                        Spacer().frame(height: 8)
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        trackUnsplashDownload()
                        renderImage()
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .reforgedPrimaryButton()
                    }

                    Button {
                        HapticManager.shared.lightImpact()
                        trackUnsplashDownload()
                        saveToPhotos()
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                            .reforgedSecondaryButton()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .padding(.top, 12)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Share Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(activityItems: [image])
                }
            }
            .alert("Saved!", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your verse image has been saved to your photo library.")
            }
            .onAppear {
                loadBundledImages()
                loadInitialUnsplashImages()
            }
        }
    }

    // MARK: - Thumbnail View

    private func thumbnailView(image: UIImage, isSelected: Bool) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.reforgedGold : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: isSelected ? Color.reforgedGold.opacity(0.3) : .clear, radius: 4)
    }

    // MARK: - Selection

    private func selectBundledImage(_ image: UIImage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedImage = image
            currentAttribution = nil
            selectedUnsplashId = nil
            renderedImage = nil
        }
    }

    private func selectUnsplashImage(_ item: UnsplashThumbnail) {
        selectedUnsplashId = item.id
        currentAttribution = item.attribution
        renderedImage = nil

        // Use full image if already loaded, otherwise use thumbnail then upgrade
        if let full = item.fullImage {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedImage = full
            }
        } else if let thumb = item.thumbnail {
            selectedImage = thumb
            // Load full-res in background
            Task {
                if let fullImage = await UnsplashService.shared.loadFullImage(for: item.photo) {
                    await MainActor.run {
                        if let idx = unsplashThumbnails.firstIndex(where: { $0.id == item.id }) {
                            unsplashThumbnails[idx].fullImage = fullImage
                        }
                        if selectedUnsplashId == item.id {
                            selectedImage = fullImage
                            renderedImage = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Image Loading

    private func loadBundledImages() {
        bundledImages = UnsplashService.shared.allBundledImages()
        if selectedImage == nil, let first = bundledImages.first {
            selectedImage = first.image
        }
    }

    private func loadInitialUnsplashImages() {
        isLoadingInitial = true
        Task {
            await fetchAndAppendUnsplashImages(count: 10)
            await MainActor.run {
                isLoadingInitial = false
            }
        }
    }

    private func loadMoreUnsplashImages() {
        isLoadingMore = true
        Task {
            await fetchAndAppendUnsplashImages(count: 10)
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }

    private func fetchAndAppendUnsplashImages(count: Int) async {
        do {
            let photos = try await UnsplashService.shared.fetchRandomPhotos(count: count)
            let utmParams = "?utm_source=reforged&utm_medium=referral"

            // Create placeholder thumbnails immediately
            let newThumbnails = photos.map { photo in
                UnsplashThumbnail(
                    id: photo.id,
                    photo: photo,
                    thumbnail: nil,
                    fullImage: nil,
                    attribution: UnsplashService.PhotographerAttribution(
                        name: photo.user.name,
                        profileURL: photo.user.links.html + utmParams,
                        photoURL: photo.links.html + utmParams,
                        downloadLocation: photo.links.download_location
                    )
                )
            }

            await MainActor.run {
                unsplashThumbnails.append(contentsOf: newThumbnails)
            }

            // Load thumbnails concurrently
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for photo in photos {
                    group.addTask {
                        guard let url = URL(string: photo.urls.small) else { return (photo.id, nil) }
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            let image = UIImage(data: data)
                            return (photo.id, image)
                        } catch {
                            return (photo.id, nil)
                        }
                    }
                }

                for await (photoId, image) in group {
                    if let image = image {
                        await MainActor.run {
                            if let idx = unsplashThumbnails.firstIndex(where: { $0.id == photoId }) {
                                unsplashThumbnails[idx].thumbnail = image
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail — bundled images still available
        }
    }

    // MARK: - Actions

    private func trackUnsplashDownload() {
        guard let attribution = currentAttribution else { return }
        UnsplashService.shared.trackDownload(attribution: attribution)
    }

    private func renderImage() {
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
    }

    private func saveToPhotos() {
        renderImage()
        guard let image = renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaveConfirmation = true
    }
}
