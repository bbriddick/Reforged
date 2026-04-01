import WidgetKit
import SwiftUI
import UIKit

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
}

struct UnsplashWidgetPhoto: Decodable {
    let urls: URLs

    struct URLs: Decodable {
        let regular: String
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

        let imageData = await fetchRandomNatureImageData()
        return VerseOfTheDayEntry(date: Date(), insight: insight, backgroundImageData: imageData)
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
            guard let imageURL = URL(string: photo.urls.regular) else { return nil }

            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            guard let httpResponse = imageResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return imageData
        } catch {
            return nil
        }
    }
}

private struct VerseOfTheDayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseOfTheDayEntry

    private let widgetGold = Color(red: 1.0, green: 0.86, blue: 0.45)

    var body: some View {
        ZStack {
            backgroundView

            overlayView

            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .widgetURL(deepLinkURL)
    }

    private var verseFont: Font {
        family == .systemSmall
            ? .system(size: 18, weight: .medium, design: .serif)
            : .system(size: 22, weight: .medium, design: .serif)
    }

    private var referenceFont: Font {
        family == .systemSmall
            ? .system(size: 12, weight: .semibold, design: .serif)
            : .system(size: 14, weight: .semibold, design: .serif)
    }

    private var smallLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)

            topAccent

            Spacer(minLength: 14)

            Text("“\(entry.insight.verseText)”")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(6)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

            Spacer(minLength: 12)

            Text(entry.insight.verse)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(widgetGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

            Spacer()

            Text("REFORGED")
                .font(.system(size: 9, weight: .bold))
                .tracking(2.8)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var mediumLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)

            topAccent

            Spacer(minLength: 14)

            headerView

            Spacer(minLength: 14)

            Text("“\(entry.insight.verseText)”")
                .font(verseFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 20)

            Spacer(minLength: 12)

            Text(entry.insight.verse)
                .font(referenceFont)
                .foregroundStyle(widgetGold)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(entry.insight.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .padding(.horizontal, 18)

            Spacer(minLength: 10)

            bottomBranding
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    private var topAccent: some View {
        Rectangle()
                    .fill(
                        LinearGradient(
                    colors: [.clear, widgetGold.opacity(0.75), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: family == .systemSmall ? 54 : 72, height: 3)
            .clipShape(Capsule())
    }

    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: family == .systemSmall ? 10 : 11, weight: .semibold))
            Text("VERSE OF THE DAY")
                .font(.system(size: family == .systemSmall ? 9 : 10, weight: .bold))
                .tracking(1.4)
        }
        .foregroundStyle(.white.opacity(0.86))
    }

    private var bottomBranding: some View {
        VStack(spacing: family == .systemSmall ? 2 : 3) {
            Text("REFORGED")
                .font(.system(size: family == .systemSmall ? 9 : 10, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.54))

            if family == .systemMedium {
                Text("Tap to open in Bible view")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let data = entry.backgroundImageData, let image = UIImage(data: data) {
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
            if #available(iOS 17.0, *) {
                VerseOfTheDayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                VerseOfTheDayWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Verse of the Day")
        .description("Shows today's daily insight verse with a nature background.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOS 17.0, *)
#Preview("Verse Small", as: .systemSmall) {
    VerseOfTheDayWidget()
} timeline: {
    VerseOfTheDayEntry(
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
    )
}

@available(iOS 17.0, *)
#Preview("Verse Medium", as: .systemMedium) {
    VerseOfTheDayWidget()
} timeline: {
    VerseOfTheDayEntry(
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
    )
}
