import WidgetKit
import SwiftUI

// MARK: - Panic Widget
//
// A one-tap way into the Tempted SOS flow (breathe → verse → prayer → reach out)
// from the Home Screen or Lock Screen. Deliberately static: in the moment this is
// used, the only thing that matters is that the tap target is instant, obvious,
// and never shows a stale or discouraging number.

// The widget target doesn't compile Theme.swift, so the brand colors are declared
// locally. Keep these in sync with Color.reforgedCoral / reforgedCream in Theme.swift.
private extension Color {
    static let panicCoral = Color(red: 0.914, green: 0.271, blue: 0.376)   // #E94560
    static let panicCream = Color(red: 0.910, green: 0.894, blue: 0.863)   // #E8E4DC
}

private let panicURL = URL(string: "reforged://panic")

struct PanicEntry: TimelineEntry {
    let date: Date
}

struct PanicProvider: TimelineProvider {
    func placeholder(in context: Context) -> PanicEntry {
        PanicEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PanicEntry) -> Void) {
        completion(PanicEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PanicEntry>) -> Void) {
        // Nothing to refresh — the button says the same thing every day.
        completion(Timeline(entries: [PanicEntry(date: Date())], policy: .never))
    }
}

// MARK: - Views

struct PanicSmallView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "hand.raised.brakesignal")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            Text("I'm Being\nTempted")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tap for a way out")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.panicCream.opacity(0.9))
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct PanicMediumView: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: "hand.raised.brakesignal")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("I'm Being Tempted")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Pause, breathe, and take hold of a way out.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.panicCream.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Lock Screen — rendered by the system in a monochrome tint, so shape carries
/// the meaning and no color can be relied on.
struct PanicCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "hand.raised.brakesignal")
                .font(.system(size: 22, weight: .semibold))
        }
    }
}

struct PanicRectangularView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.brakesignal")
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("I'm Being Tempted")
                    .font(.system(size: 14, weight: .bold))
                Text("Tap for a way out")
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Entry View

struct PanicWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: PanicEntry

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                container { PanicSmallView() }
            case .systemMedium:
                container { PanicMediumView() }
            case .accessoryCircular:
                PanicCircularView()
            case .accessoryRectangular:
                PanicRectangularView()
            case .accessoryInline:
                Label("I'm Being Tempted", systemImage: "hand.raised.brakesignal")
            default:
                container { PanicSmallView() }
            }
        }
        .widgetURL(panicURL)
    }

    /// Coral fills the whole widget: on a crowded Home Screen this has to be
    /// findable without reading it.
    @ViewBuilder
    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            content()
                .padding(4)
                .containerBackground(for: .widget) { Color.panicCoral }
        } else {
            content()
                .padding(16)
                .background(Color.panicCoral)
        }
    }
}

// MARK: - Widget Configuration

struct PanicWidget: Widget {
    let kind: String = "PanicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PanicProvider()) { entry in
            PanicWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("I'm Being Tempted")
        .description("A one-tap way out: pause, breathe, and take hold of God's Word.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    PanicWidget()
} timeline: {
    PanicEntry(date: Date())
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    PanicWidget()
} timeline: {
    PanicEntry(date: Date())
}

@available(iOS 17.0, *)
#Preview("Circular", as: .accessoryCircular) {
    PanicWidget()
} timeline: {
    PanicEntry(date: Date())
}
