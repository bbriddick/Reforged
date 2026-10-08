import SwiftUI

// MARK: - Avatar frame ring

/// Draws an avatar frame by style id (CrownCatalog.frames `value`). "" is the
/// original thin gold ring, so users who never equip a frame see no change.
struct AvatarFrameRing: View {
    let style: String
    var lineWidth: CGFloat = 3

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var body: some View {
        switch style {
        case "border-gold":
            Circle().strokeBorder(Color.reforgedGold, lineWidth: lineWidth)
        case "border-flame":
            Circle().strokeBorder(Color.reforgedCoral, lineWidth: lineWidth)
        case "border-crown":
            doubleRing(outer: Self.hex(0x7B4FB0), inner: .reforgedGold)
                .overlay(alignment: .top) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: lineWidth * 3.2, weight: .bold))
                        .foregroundStyle(Color.reforgedGold)
                        .offset(y: -lineWidth * 2.2)
                }
        case "border-diamond":
            doubleRing(outer: Self.hex(0x5BC8E8), inner: .white)
        case "frame.olive":
            ZStack {
                Circle().strokeBorder(Self.hex(0x6B8F3A), lineWidth: lineWidth)
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(Self.hex(0x8DB050))
                        .frame(width: lineWidth * 1.1, height: lineWidth * 2.4)
                        .rotationEffect(.degrees(35))
                        .offset(y: -1)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .rotationEffect(.degrees(Double(i) * 36))
                }
            }
        case "frame.sea":
            doubleRing(outer: Self.hex(0x2F7FA8), inner: Self.hex(0x9FD3E6))
        case "frame.dawn":
            doubleRing(outer: Self.hex(0xE58A3C), inner: Self.hex(0xF3C77A))
        case "frame.stainedglass":
            let colors: [Color] = [0xC0392B, 0xE3B341, 0x2F6FB5, 0x3E8E5A, 0x7B4FB0, 0xE07A3F, 0x2F6FB5, 0xE3B341].map(Self.hex)
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .trim(from: CGFloat(i) / 8 + 0.006, to: CGFloat(i + 1) / 8 - 0.006)
                        .stroke(colors[i], style: StrokeStyle(lineWidth: lineWidth * 1.2, lineCap: .butt))
                        .padding(lineWidth * 0.6)
                }
            }
        default:
            Circle().strokeBorder(Color.reforgedGold.opacity(0.9), lineWidth: max(1.5, lineWidth * 0.55))
        }
    }

    private func doubleRing(outer: Color, inner: Color) -> some View {
        ZStack {
            Circle().strokeBorder(outer, lineWidth: lineWidth)
            Circle().strokeBorder(inner, lineWidth: max(1, lineWidth * 0.35)).padding(lineWidth)
        }
    }

    /// Glow tint for the profile header shadow.
    static func glow(for style: String) -> Color? {
        switch style {
        case "": return nil
        case "border-flame": return .reforgedCoral
        case "border-crown": return hex(0x7B4FB0)
        case "border-diamond": return hex(0x5BC8E8)
        case "frame.olive": return hex(0x6B8F3A)
        case "frame.sea": return hex(0x2F7FA8)
        case "frame.dawn": return hex(0xE58A3C)
        default: return .reforgedGold
        }
    }
}

// MARK: - Illuminated initial

/// A gilded drop capital, used by the reader's Illuminated Capitals extra and
/// the Illuminated verse card style.
struct IlluminatedInitial: View {
    let letter: String
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(Color.reforgedGold)
            RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: max(1, size * 0.025))
                .padding(size * 0.07)
            // Corner flourishes
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing][i])
                    .padding(size * 0.14)
            }
            Text(letter)
                .font(.system(size: size * 0.66, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Highlighter palettes

/// Six colors per palette, in HighlightColor order: yellow, green, blue, pink,
/// orange, purple. The stored highlight keeps its slot; only the look changes.
enum HighlightPalette {
    static let defaultsKey = "highlight_palette"

    static var current: String {
        UserDefaults.standard.string(forKey: defaultsKey) ?? "classic"
    }

    static func colors(for palette: String) -> [Color] {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch palette {
        case "goldleaf":
            return [rgb(0.92, 0.78, 0.36), rgb(0.80, 0.72, 0.40), rgb(0.86, 0.66, 0.30), rgb(0.95, 0.72, 0.52), rgb(0.93, 0.60, 0.30), rgb(0.78, 0.62, 0.45)]
        case "pastel":
            return [rgb(1.0, 0.95, 0.65), rgb(0.72, 0.93, 0.78), rgb(0.72, 0.86, 1.0), rgb(1.0, 0.80, 0.88), rgb(1.0, 0.85, 0.68), rgb(0.86, 0.80, 1.0)]
        case "jewel":
            return [rgb(0.95, 0.76, 0.20), rgb(0.16, 0.66, 0.44), rgb(0.20, 0.45, 0.85), rgb(0.82, 0.22, 0.38), rgb(0.93, 0.48, 0.18), rgb(0.50, 0.30, 0.75)]
        case "earth":
            return [rgb(0.90, 0.80, 0.55), rgb(0.62, 0.72, 0.52), rgb(0.55, 0.68, 0.74), rgb(0.85, 0.60, 0.52), rgb(0.80, 0.55, 0.35), rgb(0.66, 0.56, 0.62)]
        default:
            return [rgb(1.0, 0.95, 0.0), rgb(0.0, 0.9, 0.4), rgb(0.4, 0.8, 1.0), rgb(1.0, 0.6, 0.8), rgb(1.0, 0.7, 0.2), rgb(0.8, 0.6, 1.0)]
        }
    }
}

// MARK: - Verse card styles

/// Style keys for the verse image card (CrownCatalog.verseCards `value`).
enum VerseCardStyle {
    static let defaultsKey = "verse_card_style"
    static var current: String { UserDefaults.standard.string(forKey: defaultsKey) ?? "classic" }
}

/// The verse text treatment for a card style, drawn over whatever background
/// sits behind it. Shared by the shop preview and the real share card.
struct VerseCardStyledText: View {
    let style: String
    let text: String
    let reference: String
    var scale: CGFloat = 1

    var body: some View {
        switch style {
        case "illuminated":
            VStack(alignment: .leading, spacing: 12 * scale) {
                HStack(alignment: .top, spacing: 10 * scale) {
                    IlluminatedInitial(letter: String(text.first ?? "T"), size: 54 * scale)
                    Text(String(text.dropFirst()))
                        .font(.system(size: 20 * scale, design: .serif))
                        .foregroundStyle(.white)
                        .lineSpacing(4 * scale)
                }
                Rectangle().fill(Color.reforgedGold).frame(width: 48 * scale, height: 2 * scale)
                Text(reference)
                    .font(.system(size: 14 * scale, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.reforgedGold)
            }
            .shadow(color: .black.opacity(0.35), radius: 4)
        case "manuscript":
            VStack(spacing: 12 * scale) {
                Text(text)
                    .font(.system(size: 19 * scale, design: .serif).italic())
                    .foregroundStyle(Color(red: 0.23, green: 0.18, blue: 0.13))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4 * scale)
                Text("— \(reference)")
                    .font(.system(size: 13 * scale, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.55, green: 0.18, blue: 0.20))
            }
            .padding(22 * scale)
            .background(
                RoundedRectangle(cornerRadius: 6 * scale)
                    .fill(Color(red: 0.95, green: 0.91, blue: 0.83))
                    .overlay(RoundedRectangle(cornerRadius: 6 * scale)
                        .strokeBorder(Color(red: 0.55, green: 0.18, blue: 0.20).opacity(0.5), lineWidth: 1.5 * scale)
                        .padding(5 * scale))
            )
            .shadow(color: .black.opacity(0.3), radius: 10 * scale, y: 4 * scale)
        case "poster":
            VStack(alignment: .leading, spacing: 10 * scale) {
                Text(text.uppercased())
                    .font(.system(size: 26 * scale, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                    .lineSpacing(0)
                    .minimumScaleFactor(0.5)
                Text(reference.uppercased())
                    .font(.system(size: 12 * scale, weight: .bold))
                    .tracking(2 * scale)
                    .foregroundStyle(Color.reforgedGold)
            }
            .shadow(color: .black.opacity(0.4), radius: 4)
        case "minimal":
            VStack(alignment: .leading, spacing: 6 * scale) {
                Spacer(minLength: 0)
                Text(text)
                    .font(.system(size: 14 * scale, design: .serif))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(3 * scale)
                Text(reference)
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .shadow(color: .black.opacity(0.4), radius: 3)
        case "framed":
            VStack(spacing: 12 * scale) {
                Text(text)
                    .font(.system(size: 20 * scale, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4 * scale)
                Text(reference)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.reforgedGold)
            }
            .padding(24 * scale)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.reforgedGold, lineWidth: 1.5 * scale))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.reforgedGold.opacity(0.5), lineWidth: 0.75 * scale).padding(5 * scale))
            .shadow(color: .black.opacity(0.35), radius: 4)
        default:
            VStack(spacing: 14 * scale) {
                Text(text)
                    .font(.system(size: 21 * scale, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4 * scale)
                Text(reference)
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.4), radius: 4)
        }
    }
}

/// Shop preview: a verse card over a quiet landscape-toned backdrop.
struct VerseCardStylePreview: View {
    let style: String
    var large = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.30, green: 0.36, blue: 0.40), Color(red: 0.16, green: 0.19, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
            Image(systemName: "mountain.2.fill")
                .font(.system(size: large ? 150 : 90))
                .foregroundStyle(.black.opacity(0.18))
                .offset(y: large ? 50 : 30)
            VerseCardStyledText(style: style, text: "The LORD is my shepherd; I shall not want.",
                                reference: "Psalm 23:1", scale: large ? 0.72 : 0.42)
                .padding(large ? 18 : 10)
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}
