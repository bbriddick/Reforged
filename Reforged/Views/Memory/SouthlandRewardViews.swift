import SwiftUI

// MARK: - Southland milestones
//
// Finishing a camp day (all of that day's verses learned) or the whole Friday review earns
// a shareable poster tagged for Southland and Reforged. Each milestone is shown once;
// the Share button on the track header re-opens a poster for current progress any time.

struct SouthlandMilestone: Identifiable {
    enum Kind {
        case day(CurriculumUnit)
        case complete
        case progress
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .day(let unit): return unit.id
        case .complete: return "complete"
        case .progress: return "progress"
        }
    }
}

@MainActor
enum SouthlandMilestones {
    private static let seenKey = "southland.milestones.seen"

    /// The first earned milestone the member hasn't been shown yet.
    static func pending(_ appState: AppState) -> SouthlandMilestone? {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        for unit in SouthlandCurriculum.dayUnits where appState.southlandDayComplete(unit) && !seen.contains(unit.id) {
            return SouthlandMilestone(kind: .day(unit))
        }
        if appState.southlandReviewComplete && !seen.contains("complete") {
            return SouthlandMilestone(kind: .complete)
        }
        return nil
    }

    static func markSeen(_ milestone: SouthlandMilestone) {
        guard case .progress = milestone.kind else {
            var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
            seen.insert(milestone.id)
            UserDefaults.standard.set(Array(seen), forKey: seenKey)
            return
        }
    }
}

// MARK: - Share poster (1080 x 1350)

/// A quiet poster built from the Reforged design system: warm off-white canvas, Archivo Black
/// display type, gold eyebrow, Libre Baskerville Scripture on a white card, coral for the
/// single accent. Southland's wordmark leads; both ministries are tagged along the bottom.
/// Fixed size so it renders identically as a shareable image.
struct SouthlandShareCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let quote: String
    let quoteReference: String

    // Reforged tokens (design system colors.css)
    private let canvas = Color(red: 250/255, green: 248/255, blue: 245/255)      // cream-bg #FAF8F5
    private let ink = Color(red: 45/255, green: 45/255, blue: 45/255)            // text-primary #2D2D2D
    private let secondary = Color(red: 102/255, green: 102/255, blue: 102/255)   // text-secondary #666
    private let hairline = Color(red: 229/255, green: 229/255, blue: 229/255)    // border-card #E5E5E5
    private let coral = Color(red: 233/255, green: 69/255, blue: 96/255)         // coral #E94560
    private let goldText = Color(red: 176/255, green: 127/255, blue: 78/255)     // gold-700 #B07F4E

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            canvas

            // One faint boot print, bleeding off the corner.
            Image("SouthlandBootprint")
                .resizable()
                .scaledToFit()
                .frame(height: 720)
                .rotationEffect(.degrees(20))
                .opacity(0.16)
                .offset(x: 170, y: 200)

            VStack(alignment: .leading, spacing: 0) {
                Image("SouthlandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 112)

                Spacer(minLength: 48)

                Text("SUMMER 2026")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(28 * 0.12)
                    .foregroundStyle(goldText)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title.uppercased())
                        .foregroundStyle(ink)
                    Text(subtitle.uppercased())
                        .foregroundStyle(coral)
                }
                .font(.custom("ArchivoBlack-Regular", size: 128))
                .tracking(-2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .padding(.top, 24)

                Text(detail)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(secondary)
                    .padding(.top, 32)

                // Scripture on a white card (design-system "insight" verse treatment).
                VStack(alignment: .leading, spacing: 24) {
                    Text("\u{201C}\(quote)\u{201D}")
                        .font(.custom("LibreBaskerville-Italic", size: 36))
                        .lineSpacing(36 * 0.65 - 12)
                        .foregroundStyle(ink)
                    Text(quoteReference)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(goldText)
                }
                .padding(48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(hairline, lineWidth: 2))
                .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                .padding(.top, 56)

                Spacer(minLength: 48)

                Rectangle().fill(hairline).frame(height: 2)

                // Tags: Southland on the left, Reforged on the right.
                HStack(alignment: .center, spacing: 24) {
                    Text("@SouthlandChristianMinistries")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    HStack(spacing: 16) {
                        Text("@reforgedapp")
                        Image("ReforgedMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                    }
                }
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(secondary)
                .padding(.top, 32)
            }
            .padding(96)
        }
        .frame(width: 1080, height: 1350)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Reward sheet

struct SouthlandRewardSheet: View {
    let milestone: SouthlandMilestone
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaved = false
    @State private var confetti = false

    private var learned: Int {
        appState.memoryVerses.filter { SouthlandCurriculum.references.contains($0.reference) }.count
    }

    private var total: Int { SouthlandCurriculum.allVerses.count }

    private var card: SouthlandShareCard {
        let points = appState.southlandPointsEarned
        let xp = points > 0 ? " · \(points) XP" : ""
        switch milestone.kind {
        case .day(let unit):
            let dayXP = (unit.pointsPerVerse ?? 0) * unit.verses.count
            return make(title: unit.title, subtitle: "complete",
                        detail: "\(unit.verses.count) of \(unit.verses.count) verses · \(dayXP) XP",
                        quote: Self.quote(for: unit.id))
        case .complete:
            return make(title: "Take Courage", subtitle: "complete",
                        detail: "\(total) of \(total) verses\(xp)", quote: Self.quote(for: "complete"))
        case .progress:
            return make(title: "Take Courage", subtitle: "in progress",
                        detail: "\(learned) of \(total) verses\(xp)", quote: Self.quote(for: "progress"))
        }
    }

    private func make(title: String, subtitle: String, detail: String,
                      quote: (text: String, reference: String)) -> SouthlandShareCard {
        SouthlandShareCard(title: title, subtitle: subtitle, detail: detail,
                           quote: quote.text, quoteReference: quote.reference)
    }

    /// One verse from each day to feature on its poster.
    private static func quote(for id: String) -> (text: String, reference: String) {
        switch id {
        case "southland-tue":
            return ("Keep thy heart with all diligence; for out of it are the issues of life.", "Proverbs 4:23")
        case "southland-wed":
            return ("For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.", "2 Timothy 1:7")
        case "southland-thu":
            return ("Draw nigh to God, and he will draw nigh to you.", "James 4:8")
        default:
            return ("Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.", "Joshua 1:9")
        }
    }

    private var headline: String {
        switch milestone.kind {
        case .day(let unit): return "\(unit.title) complete"
        case .complete: return "Take Courage"
        case .progress: return "Camp progress"
        }
    }

    private var shareText: String {
        "I memorized \(learned) Southland 2026 camp verses with Reforged! @SouthlandChristianMinistries @reforgedapp #Southland2026 #TakeCourage"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // The poster, scaled to fill the space above the buttons.
                GeometryReader { geo in
                    let scale = min(geo.size.width / 1080, geo.size.height / 1350)
                    card
                        .scaleEffect(scale)
                        .frame(width: 1080 * scale, height: 1350 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Same chunky buttons as the rest of the app.
                VStack(spacing: 8) {
                    PracticeButton(title: "Share", icon: "square.and.arrow.up") {
                        HapticManager.shared.mediumImpact()
                        renderImage()
                        showShareSheet = true
                    }

                    Button {
                        HapticManager.shared.lightImpact()
                        renderImage()
                        if let image = renderedImage {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            showSaved = true
                        }
                    } label: {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                            .font(.headline.bold())
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PracticeLipButtonStyle(
                        face: Color.adaptiveCardBackground(colorScheme),
                        lip: Color.adaptiveBorder(colorScheme),
                        stroke: Color.adaptiveBorder(colorScheme),
                        cornerRadius: 16, depth: 5))
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .arcadeConfetti(isActive: $confetti, intensity: .high)
            .navigationTitle(headline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(activityItems: [image, shareText])
                }
            }
            .alert("Saved!", isPresented: $showSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your poster has been saved to your photo library.")
            }
        }
        .onAppear {
            SouthlandMilestones.markSeen(milestone)
            HapticManager.shared.achievementUnlocked()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { confetti = true }
        }
    }

    @MainActor
    private func renderImage() {
        guard renderedImage == nil else { return }
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
    }
}
