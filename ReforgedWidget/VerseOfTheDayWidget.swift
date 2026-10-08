import WidgetKit
import SwiftUI
import UIKit
import ImageIO

struct WidgetDailyInsight: Decodable {
    let id: String
    let date: String
    let title: String
    let verse: String
    let verseText: String
    let reflection: String
}

struct VerseOfTheDayEntry: TimelineEntry {
    let date: Date
    let insight: WidgetDailyInsight
    let backgroundImageData: Data?
    /// The style chosen in Settings → Widgets (or the Crown Shop), read from the App Group.
    var style: WidgetStyle { .current }
}

struct UnsplashWidgetPhoto: Decodable {
    let urls: URLs

    struct URLs: Decodable {
        let regular: String
        let small: String?
    }
}

struct VerseOfTheDayProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.reforged.app")
    private let insightKey = "reforged_widget_daily_insight"
    private let accessKey = "xmX_W9xuD4j1Qew_TqTvZz39Civ2Ub7gnWWD2h6UOYY"

    func placeholder(in context: Context) -> VerseOfTheDayEntry {
        VerseOfTheDayEntry(
            date: Date(),
            insight: WidgetDailyInsight(
                id: "placeholder",
                date: "2026-01-01",
                title: "Daily Insight",
                verse: "Psalm 23:1",
                verseText: "The Lord is my shepherd; I shall not want.",
                reflection: "Rest in God's faithful care today."
            ),
            backgroundImageData: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseOfTheDayEntry) -> Void) {
        Task {
            completion(await loadEntry(fallback: placeholder(in: context)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseOfTheDayEntry>) -> Void) {
        Task {
            let placeholder = placeholder(in: context)
            let entry = await loadEntry(fallback: placeholder)
            let calendar = Calendar.current
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(tomorrow)))
        }
    }

    private func loadEntry(fallback: VerseOfTheDayEntry) async -> VerseOfTheDayEntry {
        guard
            let data = defaults?.data(forKey: insightKey),
            let insight = try? JSONDecoder().decode(WidgetDailyInsight.self, from: data)
        else {
            return fallback
        }

        // A crown-shop widget style replaces the photo, so don't fetch one.
        let imageData = WidgetStyle.current.background == nil ? await fetchRandomNatureImageData() : nil
        return VerseOfTheDayEntry(date: Date(), insight: insight, backgroundImageData: imageData)
    }

    /// Decodes at most `maxPixel` on the long edge (ImageIO thumbnailing never
    /// inflates the full bitmap) and re-encodes as JPEG.
    static func downsampled(_ data: Data, maxPixel: Int) -> Data? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }

    private func fetchRandomNatureImageData() async -> Data? {
        var components = URLComponents(string: "https://api.unsplash.com/photos/random")
        components?.queryItems = [
            URLQueryItem(name: "query", value: "nature landscape"),
            URLQueryItem(name: "orientation", value: "portrait"),
            URLQueryItem(name: "content_filter", value: "high")
        ]

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let photo = try JSONDecoder().decode(UnsplashWidgetPhoto.self, from: data)
            // The small (400pt) rendition, downsampled again below: widgets run
            // under a tight memory cap, and a full-size photo can get the
            // extension killed, leaving a blank widget.
            guard let imageURL = URL(string: photo.urls.small ?? photo.urls.regular) else { return nil }

            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            guard let httpResponse = imageResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return Self.downsampled(imageData, maxPixel: 700)
        } catch {
            return nil
        }
    }
}

private struct VerseOfTheDayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseOfTheDayEntry

    /// Crown-shop widget style (or the photo, if this widget chose it).
    private var style: WidgetStyle { entry.style }

    private var widgetGold: Color { style.accent ?? Color(red: 1.0, green: 0.86, blue: 0.45) }
    private var ink: Color { style.ink ?? .white }

    var body: some View {
        let content = Group {
            if family == .systemSmall { smallLayout } else { mediumLayout }
        }
        .widgetURL(deepLinkURL)

        // The background must be the container background (iOS 17+) so it fills
        // the whole widget edge to edge; drawn inside the content margins it
        // left a black frame around the widget.
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { fullBackground }
        } else {
            ZStack { fullBackground; content.padding(16) }
        }
    }

    private var fullBackground: some View {
        ZStack {
            backgroundView
            if style.background == nil { overlayView }
        }
    }

    /// Photo backgrounds need a shadow for legibility; flat styles don't.
    private var textShadow: Color { style.background == nil ? .black.opacity(0.35) : .clear }

    private var eyebrow: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 9, weight: .bold))
            Text("VERSE OF THE DAY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(widgetGold)
    }

    // The verse gets layout priority: it fills the space and only shrinks when
    // long. Leading alignment keeps multi-line Scripture easy to read.
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            eyebrow
            Text(entry.insight.verseText)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(ink)
                .lineSpacing(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
                .shadow(color: textShadow, radius: 3, y: 1)
            Spacer(minLength: 0)
            Text(entry.insight.verse)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(widgetGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: textShadow, radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Medium: verse centered in the space and allowed to grow (shrinking only
    /// for long passages), date opposite the label, reference and the day's
    /// title as a quiet footer. The widget label already says "Reforged".
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                eyebrow
                Spacer()
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(ink.opacity(0.55))
            }
            Spacer(minLength: 6)
            Text(entry.insight.verseText)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(ink)
                .lineSpacing(2)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
                .shadow(color: textShadow, radius: 3, y: 1)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.insight.verse)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(widgetGold)
                    .lineLimit(1)
                    .layoutPriority(1)
                Rectangle()
                    .fill(ink.opacity(0.25))
                    .frame(width: 1, height: 10)
                Text(entry.insight.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ink.opacity(0.7))
                    .lineLimit(1)
            }
            .shadow(color: textShadow, radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var overlayView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.76),
                    Color.black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.42)
                ],
                center: .center,
                startRadius: family == .systemSmall ? 12 : 20,
                endRadius: family == .systemSmall ? 120 : 220
            )
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let styled = style.background {
            styled
        } else if let data = entry.backgroundImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.19, green: 0.28, blue: 0.24),
                        Color(red: 0.09, green: 0.14, blue: 0.12),
                        Color(red: 0.05, green: 0.07, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(widgetGold.opacity(0.10))
                    .frame(width: family == .systemSmall ? 90 : 140, height: family == .systemSmall ? 90 : 140)
                    .offset(x: family == .systemSmall ? 28 : 54, y: family == .systemSmall ? -42 : -58)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: family == .systemSmall ? 110 : 170, height: family == .systemSmall ? 110 : 170)
                    .offset(x: family == .systemSmall ? -36 : -60, y: family == .systemSmall ? 50 : 76)
            }
        }
    }

    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "reforged"
        components.host = "bible"
        components.queryItems = [
            URLQueryItem(name: "reference", value: entry.insight.verse)
        ]
        return components.url
    }
}

struct VerseOfTheDayWidget: Widget {
    let kind: String = "VerseOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseOfTheDayProvider()) { entry in
            VerseOfTheDayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("Today's verse. Choose a nature photo or another style in Reforged → Settings → Widgets.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#if DEBUG
struct VerseOfTheDayWidget_Previews: PreviewProvider {
    static var previews: some View {
        VerseOfTheDayWidgetEntryView(entry: VerseOfTheDayEntry(
            date: Date(),
            insight: WidgetDailyInsight(
                id: "preview",
                date: "2026-01-01",
                title: "Peace in the Shepherd",
                verse: "Psalm 23:1",
                verseText: "The Lord is my shepherd; I shall not want.",
                reflection: "God provides what you need today."
            ),
            backgroundImageData: nil
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif

// MARK: - Crown shop widget styles

/// Mirrors WidgetStylePreviewColors in the app (CrownShopView.swift) — keep
/// the two in step. `nil` fields mean "use the classic photo look".
struct WidgetStyle {
    let background: Color?
    let ink: Color?
    let accent: Color?

    static var current: WidgetStyle {
        let key = UserDefaults(suiteName: "group.com.reforged.app")?.string(forKey: "widget_style") ?? "classic"
        func hex(_ v: UInt32) -> Color {
            Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        }
        switch key {
        case "parchment": return WidgetStyle(background: hex(0xF3EAD7), ink: hex(0x3B2F22), accent: hex(0xA0652F))
        case "midnight": return WidgetStyle(background: hex(0x0E1422), ink: hex(0xE9ECF3), accent: hex(0xE0B872))
        case "charcoal": return WidgetStyle(background: hex(0x333333), ink: hex(0xE8E4DC), accent: hex(0xD4A574))
        case "stainedglass": return WidgetStyle(background: hex(0x17305A), ink: hex(0xF3F5FA), accent: hex(0xE3B341))
        default: return .photo
        }
    }

    static let photo = WidgetStyle(background: nil, ink: nil, accent: nil)
}
