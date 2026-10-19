import SwiftUI

// MARK: - Southland partnership branding
//
// Southland Christian Ministries' mark is a black hand-lettered wordmark with a silver
// boot print, always shown on a light plate so it reads the same in light and dark mode.
// These views advertise the camp verse track and head it once opened.

private enum SouthlandBrand {
    static let plate = Color(red: 250/255, green: 248/255, blue: 245/255)   // cream-bg
    static let plateLip = Color(red: 0.78, green: 0.78, blue: 0.78)
    static let ink = Color(red: 45/255, green: 45/255, blue: 45/255)
    static let inkSecondary = Color(red: 102/255, green: 102/255, blue: 102/255)
}

/// How many of the track's verses the member has started.
private func southlandLearnedCount(_ verses: [MemoryVerse]) -> Int {
    verses.filter { SouthlandCurriculum.references.contains($0.reference) }.count
}

// MARK: - Promo card (top of the main journey)

struct SouthlandPromoCard: View {
    let learned: Int
    let onOpen: () -> Void

    private var total: Int { SouthlandCurriculum.allVerses.count }

    var body: some View {
        Button {
            HapticManager.shared.cardFlipEdgeThud()
            onOpen()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Image("SouthlandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                        .accessibilityHidden(true)

                    Text("Memorize the Southland 2026 Verses")
                        .font(.subheadline.bold())
                        .foregroundStyle(SouthlandBrand.ink)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text("TAKE COURAGE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                        Text("·")
                        Text(learned == 0 ? "\(total) camp verses" : "\(learned) of \(total) learned")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(SouthlandBrand.inkSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(SouthlandBrand.inkSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .trailing) {
                Image("SouthlandBootprint")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)
                    .rotationEffect(.degrees(18))
                    .offset(x: 18)
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PracticeLipButtonStyle(face: SouthlandBrand.plate, lip: SouthlandBrand.plateLip,
                                            cornerRadius: 20, depth: 5))
        .accessibilityLabel("Southland 2026 Verses, Take Courage. \(learned) of \(total) learned.")
        .accessibilityHint("Opens the camp verse track")
    }
}

// MARK: - Track header (top of the opened track)

struct SouthlandTrackHeader: View {
    let learned: Int
    var xp: Int = 0
    let onBack: () -> Void
    var onShare: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var total: Int { SouthlandCurriculum.allVerses.count }
    private var fraction: CGFloat { total == 0 ? 0 : CGFloat(learned) / CGFloat(total) }

    var body: some View {
        VStack(spacing: 14) {
            Button {
                HapticManager.shared.buttonTap()
                onBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Main journey")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if let onShare, learned > 0 {
                    Button {
                        HapticManager.shared.buttonTap()
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.reforgedCoral)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.reforgedCoral.opacity(colorScheme == .dark ? 0.22 : 0.13), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share your camp progress")
                }
            }

            VStack(spacing: 14) {
                Image("SouthlandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .accessibilityLabel("Southland Christian Ministries")

                VStack(spacing: 4) {
                    Text("TAKE COURAGE")
                        .font(.custom("ArchivoBlack-Regular", size: 26))
                        .foregroundStyle(SouthlandBrand.ink)
                    Text("Summer 2026 camp verses, one day at a time. In partnership with Southland.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SouthlandBrand.inkSecondary)
                }

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(SouthlandBrand.plateLip.opacity(0.55)).frame(height: 10)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.reforgedGold, Color.orange],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * fraction, height: 10)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: fraction)
                        }
                    }
                    .frame(height: 10)

                    Text("\(learned) of \(total) verses learned · \(xp) XP earned")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SouthlandBrand.inkSecondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottomTrailing) {
                Image("SouthlandBootprint")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .rotationEffect(.degrees(18))
                    .offset(x: 30, y: 26)
                    .opacity(0.4)
                    .accessibilityHidden(true)
            }
            .background(SouthlandBrand.plate)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 14, y: 6)
        }
    }
}
