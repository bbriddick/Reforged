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
        guard let firstNum = numbers.first, let lastNum = numbers.last else { return "" }
        let isConsecutive = numbers.count == (lastNum - firstNum + 1)
        if isConsecutive {
            return "\(book) \(chapter):\(firstNum)-\(lastNum)"
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

// MARK: - Shareable Verse Card

/// Renders in two styles: the default "classic" editorial card (cream, serif,
/// gold accents — no photo), or the photo style when a background is selected.
struct VerseShareCard: View {
    let verseText: String
    let reference: String
    let bookName: String
    let translation: String
    let backgroundImage: UIImage?
    let photographerName: String?
    var noteText: String? = nil

    static let classicSize = CGSize(width: 1080, height: 1350)
    static let photoSize = CGSize(width: 1080, height: 1080)

    var cardSize: CGSize {
        backgroundImage == nil ? Self.classicSize : Self.photoSize
    }

    var body: some View {
        if let image = backgroundImage {
            photoCard(image)
        } else {
            classicCard
        }
    }

    // MARK: Classic editorial style (default)

    private var classicCard: some View {
        ZStack {
            // Rim behind the rounded card
            Color(red: 0.945, green: 0.933, blue: 0.914) // #F1EEE9

            RoundedRectangle(cornerRadius: 48)
                .fill(Color(red: 0.980, green: 0.973, blue: 0.961)) // #FAF8F5
                .overlay(
                    RoundedRectangle(cornerRadius: 48)
                        .stroke(Color.black.opacity(0.06), lineWidth: 2)
                )
                .padding(28)

            VStack(spacing: 0) {
                // Eyebrow: book name
                HStack {
                    Text(bookName.uppercased())
                        .font(.system(size: 28, weight: .bold))
                        .tracking(9)
                        .foregroundStyle(Color.reforgedGold)
                    Spacer()
                }
                .padding(.horizontal, 100)
                .padding(.top, 110)

                Spacer()

                // Decorative quote mark
                Text("\u{201C}")
                    .font(Font.custom("LibreBaskerville-Regular", size: 170))
                    .foregroundStyle(Color.reforgedGold.opacity(0.45))
                    .frame(height: 120, alignment: .top)

                Spacer().frame(height: 44)

                // Verse text
                Text(verseText)
                    .font(Font.custom("LibreBaskerville-Regular", size: classicVerseFontSize))
                    .foregroundStyle(Color.reforgedCharcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(16)
                    .padding(.horizontal, 96)

                Spacer().frame(height: 56)

                // Gold divider
                Capsule()
                    .fill(Color.reforgedGold.opacity(0.7))
                    .frame(width: 64, height: 4)

                Spacer().frame(height: 36)

                // Reference · Translation
                HStack(spacing: 14) {
                    Text(reference)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                    Text("\u{00B7}")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.reforgedCharcoal.opacity(0.35))
                    Text(translation)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(Color.reforgedCharcoal.opacity(0.5))
                }

                // Note section — shown when a note is attached
                if let note = noteText, !note.isEmpty {
                    Spacer().frame(height: 48)

                    Rectangle()
                        .fill(Color.reforgedCharcoal.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 180)

                    Spacer().frame(height: 36)

                    Text(note)
                        .font(Font.custom("LibreBaskerville-Italic", size: classicNoteFontSize))
                        .foregroundStyle(Color.reforgedCharcoal.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.horizontal, 130)
                }

                Spacer()

                // Footer: logomark + wordmark
                HStack(spacing: 14) {
                    Image("ReforgedMark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 36)
                    Text("REFORGED")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(7)
                        .foregroundStyle(Color.reforgedCharcoal)
                }
                .padding(.bottom, 110)
            }
        }
        .frame(width: Self.classicSize.width, height: Self.classicSize.height)
        .environment(\.colorScheme, .light)
    }

    private var classicVerseFontSize: CGFloat {
        let hasNote = !(noteText?.isEmpty ?? true)
        let length = verseText.count
        let bump: CGFloat = hasNote ? 6 : 0
        if length < 80 { return 74 - bump }
        if length < 150 { return 66 - bump }
        if length < 250 { return 58 - bump }
        if length < 400 { return 48 - bump }
        return 40 - bump
    }

    private var classicNoteFontSize: CGFloat {
        let length = noteText?.count ?? 0
        if length < 80 { return 34 }
        if length < 180 { return 30 }
        if length < 300 { return 26 }
        return 24
    }

    // MARK: Photo style (when a background is selected)

    private func photoCard(_ backgroundImage: UIImage) -> some View {
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

                // Note section — shown when a note is attached
                if let note = noteText, !note.isEmpty {
                    Spacer().frame(height: 40)

                    // Thin divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 100)

                    Spacer().frame(height: 28)

                    Text("\u{201C}\(note)\u{201D}")
                        .font(.system(size: noteFontSize, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 100)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                }

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
        let hasNote = !(noteText?.isEmpty ?? true)
        let length = verseText.count
        // Slightly smaller when a note is also shown
        let bump: CGFloat = hasNote ? 4 : 0
        if length < 80 { return 42 - bump }
        if length < 150 { return 36 - bump }
        if length < 250 { return 30 - bump }
        if length < 400 { return 26 - bump }
        return 22 - bump
    }

    private var noteFontSize: CGFloat {
        let length = noteText?.count ?? 0
        if length < 80 { return 28 }
        if length < 180 { return 24 }
        if length < 300 { return 20 }
        return 18
    }
}

// MARK: - Verse Share Sheet

struct VerseShareSheet: View {
    let selection: VerseShareSelection
    var noteText: String? = nil
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

    private var shareCard: VerseShareCard {
        VerseShareCard(
            verseText: selection.fullText,
            reference: selection.referenceText,
            bookName: selection.book,
            translation: selection.translation,
            backgroundImage: selectedImage,
            photographerName: currentAttribution?.name,
            noteText: noteText
        )
    }

    private var isClassicSelected: Bool {
        selectedImage == nil
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
                            .frame(
                                width: shareCard.cardSize.width * 0.3,
                                height: shareCard.cardSize.height * 0.3
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)

                        // Unsplash attribution link
                        if let attribution = currentAttribution {
                            HStack(spacing: 4) {
                                Text("Photo by")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                                if let profileURL = URL(string: attribution.profileURL) {
                                    Link(attribution.name, destination: profileURL)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                } else {
                                    Text(attribution.name)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                }

                                Text("on")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                                if let unsplashURL = URL(string: "https://unsplash.com/?utm_source=reforged&utm_medium=referral") {
                                    Link("Unsplash", destination: unsplashURL)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Unsplash")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                }
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
                                    Button {
                                        selectClassicStyle()
                                    } label: {
                                        classicThumbnailView(isSelected: isClassicSelected)
                                    }

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

    private func classicThumbnailView(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(red: 0.980, green: 0.973, blue: 0.961))
            .frame(width: 64, height: 64)
            .overlay(
                Text("\u{201C}")
                    .font(Font.custom("LibreBaskerville-Regular", size: 40))
                    .foregroundStyle(Color.reforgedGold)
                    .offset(y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.reforgedGold : Color.black.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color.reforgedGold.opacity(0.3) : .clear, radius: 4)
    }

    // MARK: - Selection

    private func selectClassicStyle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedImage = nil
            currentAttribution = nil
            selectedUnsplashId = nil
            renderedImage = nil
        }
    }

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
        // No auto-selection — the classic editorial style (no photo) is the default.
        bundledImages = UnsplashService.shared.allBundledImages()
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
