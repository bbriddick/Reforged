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
        // Check if consecutive range
        let isConsecutive = numbers.count == (numbers.last! - numbers.first! + 1)
        if isConsecutive {
            return "\(book) \(chapter):\(numbers.first!)-\(numbers.last!)"
        }
        // Non-consecutive: list them
        let refs = numbers.map { String($0) }.joined(separator: ", ")
        return "\(book) \(chapter):\(refs)"
    }

    var fullText: String {
        verses.sorted(by: { $0.number < $1.number }).map { $0.text }.joined(separator: " ")
    }
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
            // Background image
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
                    // Branding
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

    /// Dynamically size font based on text length
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
    @State private var photographerName: String?
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var isLoadingUnsplash = false
    @State private var bundledImages: [(name: String, image: UIImage)] = []

    private var currentBackground: UIImage {
        selectedImage ?? UnsplashService.fallbackGradientImage()
    }

    private var shareCard: some View {
        VerseShareCard(
            verseText: selection.fullText,
            reference: selection.referenceText,
            translation: selection.translation,
            backgroundImage: currentBackground,
            photographerName: photographerName
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 8)

                        shareCard
                            .scaleEffect(0.3)
                            .frame(width: 324, height: 324)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)

                        // Background image picker
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Background")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))

                                Spacer()

                                // Shuffle from Unsplash
                                Button {
                                    fetchUnsplashImage()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isLoadingUnsplash {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.caption)
                                        }
                                        Text("Shuffle")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                }
                                .disabled(isLoadingUnsplash)
                            }
                            .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(bundledImages, id: \.name) { item in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedImage = item.image
                                                photographerName = nil
                                                renderedImage = nil
                                            }
                                        } label: {
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 64, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            selectedImage === item.image ? Color.reforgedGold : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        Spacer().frame(height: 8)
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        renderImage()
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .reforgedPrimaryButton()
                    }

                    Button {
                        HapticManager.shared.lightImpact()
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
            }
        }
    }

    // MARK: - Image Helpers

    private func loadBundledImages() {
        bundledImages = UnsplashService.shared.allBundledImages()
        if selectedImage == nil, let first = bundledImages.first {
            selectedImage = first.image
        }
    }

    private func fetchUnsplashImage() {
        isLoadingUnsplash = true
        renderedImage = nil
        Task {
            let result = await UnsplashService.shared.getImage()
            await MainActor.run {
                selectedImage = result.image
                photographerName = result.photographer?.name
                renderedImage = nil
                isLoadingUnsplash = false
            }
        }
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
