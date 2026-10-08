import SwiftUI
import AVKit

// MARK: - Tips
//
// "Get more out of Reforged": short motion-graphic walkthroughs, one per feature,
// grouped into four categories. Each tip always has readable steps; the video is
// an enhancement streamed from Supabase Storage and silently hidden if it isn't
// uploaded yet or the device is offline, so the section never shows a broken player.
//
// Content mirrors Marketing/Tips/tips.json (the same source the After Effects
// builder uses). Keep the two in sync when adding or editing a tip.

// MARK: - Model

enum TipCategory: String, CaseIterable, Identifiable {
    case memory, reader, habits, study

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory: return "Scripture Memory"
        case .reader: return "Bible Reader"
        case .habits: return "Habits & Streaks"
        case .study:  return "Study & Focus"
        }
    }

    var shortTitle: String {
        switch self {
        case .memory: return "Memory"
        case .reader: return "Reader"
        case .habits: return "Habits"
        case .study:  return "Study"
        }
    }

    var icon: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .reader: return "text.book.closed.fill"
        case .habits: return "flame.fill"
        case .study:  return "books.vertical.fill"
        }
    }

    /// Category accents follow DESIGN.md: coral for memory, deep gold for
    /// Scripture/reading, and the track hues for the rest. Safe in light and dark.
    var color: Color {
        switch self {
        case .memory: return Color.reforgedCoral
        case .reader: return Color(red: 0.69, green: 0.50, blue: 0.31)  // #B07F4E
        case .habits: return Color(red: 0.20, green: 0.60, blue: 0.40)  // #339966
        case .study:  return Color(red: 0.30, green: 0.30, blue: 0.60)  // #4D4D99
        }
    }

    /// Main-tab index the "Try it" button jumps to (see MainTabView tags).
    var tryItTab: Int {
        switch self {
        case .memory: return 3
        case .reader: return 2
        case .habits: return 0
        case .study:  return 1
        }
    }
}

struct ReforgedTip: Identifiable, Hashable {
    let id: String
    let number: Int
    let category: TipCategory
    let title: String
    let hook: String
    let steps: [String]
    let tryItLabel: String

    static func == (lhs: ReforgedTip, rhs: ReforgedTip) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Rendered 16x9 master, uploaded to the public `tips` bucket as
    /// `<NN>_<id>_16x9.mp4` (the After Effects render queue uses the same names).
    var videoURL: URL? {
        URL(string: "\(TipsLibrary.videoBaseURL)/\(String(format: "%02d", number))_\(id)_16x9.mp4")
    }
}

enum TipsLibrary {
    static let videoBaseURL = "https://ztklhghgnpmmjtznphfs.supabase.co/storage/v1/object/public/tips"

    static let all: [ReforgedTip] = [
        ReforgedTip(
            id: "memory-spaced", number: 1, category: .memory,
            title: "Let spaced repetition do the remembering",
            hook: "Read a verse today, forget it by Friday? Not anymore.",
            steps: [
                "Tap any verse in the reader, then tap Memory to add it.",
                "Open the Memory tab each day and clear your Verses Due.",
                "Reforged schedules each review right before you'd forget, moving verses up five mastery levels."
            ],
            tryItLabel: "Open Memory"),
        ReforgedTip(
            id: "memory-modes", number: 2, category: .memory,
            title: "Climb the six practice modes",
            hook: "Flashcards are just the first rung.",
            steps: [
                "Start with Flashcard and Tap to Reveal while a verse is new.",
                "Step up to Drag & Drop, Fill in Blank, and First Letter.",
                "Prove it with Typing, then follow the Memory journey through 150 verses in 15 themes."
            ],
            tryItLabel: "Start practicing"),
        ReforgedTip(
            id: "reader-strongs", number: 3, category: .reader,
            title: "Press a word to open the original",
            hook: "There's Greek and Hebrew under every English word.",
            steps: [
                "Press and hold any word to see its Strong's Hebrew or Greek definition.",
                "Tap a verse, then Study for word study, cross references, and commentary.",
                "Jump to Places to see where the passage happened on the atlas."
            ],
            tryItLabel: "Open the Bible"),
        ReforgedTip(
            id: "reader-yours", number: 4, category: .reader,
            title: "Make every verse your own",
            hook: "Highlight it. Hear it. Share it.",
            steps: [
                "Tap a verse to Highlight, add a Note, or Bookmark it.",
                "Tap Share to turn a verse into a beautiful image card.",
                "Hit play to listen, with speed and skip controls."
            ],
            tryItLabel: "Open the Bible"),
        ReforgedTip(
            id: "habits-streak", number: 5, category: .habits,
            title: "Protect your streak",
            hook: "Missed a day? Your streak can survive it.",
            steps: [
                "Reading a chapter, reviewing a verse, or finishing a lesson all keep your streak alive.",
                "You get 4 free streak freezes every month to cover a missed day.",
                "Need more? Tap your streak card and trade XP for an extra freeze."
            ],
            tryItLabel: "See my streak"),
        ReforgedTip(
            id: "habits-widgets", number: 6, category: .habits,
            title: "Start your day before you open the app",
            hook: "Your Home Screen can point you to Scripture.",
            steps: [
                "Add the Verse of the Day or Reading Streak widget to your Home Screen.",
                "Tap Morning Routine on Home for Scripture, prayer, gratitude, and a quick review.",
                "Pick a reading plan, including Spurgeon's Morning and Evening."
            ],
            tryItLabel: "Go to Home"),
        ReforgedTip(
            id: "study-library", number: 7, category: .study,
            title: "Study with the classics",
            hook: "Centuries of wisdom, one tap from the text.",
            steps: [
                "Open the Study Library for commentaries, the Tyndale Open Study Notes, a Bible dictionary, and an atlas.",
                "Read Calvin, Matthew Henry, and Barnes right beside the verse.",
                "Download the larger classics for offline study."
            ],
            tryItLabel: "Open Discipleship"),
        ReforgedTip(
            id: "study-focus", number: 8, category: .study,
            title: "Guard your focus",
            hook: "Build a rhythm, and a way out when you're tempted.",
            steps: [
                "In Discipleship, turn on the Focus & Purity Shield and set focus sessions.",
                "Build My Rhythm: habits to keep, temptations to avoid, and real reminders.",
                "Add the I'm Being Tempted widget and invite an accountability partner."
            ],
            tryItLabel: "Open Discipleship")
    ]

    static func tips(in category: TipCategory?) -> [ReforgedTip] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}

// MARK: - Home entry card

struct TipsEntryCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: TipsView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tips")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Get more out of Reforged in under a minute each")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .reforgedCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Short walkthroughs of Reforged's features")
    }
}

// MARK: - Tips list

struct TipsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selected: TipCategory? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                header
                categoryChips
                if selected == nil {
                    ForEach(TipCategory.allCases) { category in
                        section(for: category)
                    }
                } else if let selected {
                    tipGrid(TipsLibrary.tips(in: selected))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Get more out of Reforged")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Short walkthroughs of the features that help Scripture stick.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", icon: nil, isOn: selected == nil) { selected = nil }
                ForEach(TipCategory.allCases) { category in
                    chip(title: category.shortTitle, icon: category.icon, isOn: selected == category) {
                        selected = category
                    }
                }
            }
        }
    }

    private func chip(title: String, icon: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.white : Color.adaptiveTextSecondary(colorScheme))
            .background(
                Capsule().fill(isOn ? Color.reforgedCoral : Color.adaptiveChipBackground(colorScheme))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func section(for category: TipCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(category.title.uppercased(), systemImage: category.icon)
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(category.color)
            tipGrid(TipsLibrary.tips(in: category))
        }
    }

    @ViewBuilder
    private func tipGrid(_ tips: [ReforgedTip]) -> some View {
        let columns = horizontalSizeClass == .regular
            ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
            : [GridItem(.flexible())]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(tips) { tip in
                NavigationLink(destination: TipDetailView(tip: tip)) {
                    TipRow(tip: tip)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TipRow: View {
    let tip: ReforgedTip
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", tip.number))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tip.category.color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tip.category.color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text(tip.hook)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reforgedCard()
    }
}

// MARK: - Tip detail

struct TipDetailView: View {
    let tip: ReforgedTip
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                if let url = tip.videoURL {
                    TipVideoPlayer(url: url)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("TIP \(String(format: "%02d", tip.number))  ·  \(tip.category.title.uppercased())")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(tip.category.color)
                    Text(tip.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tip.hook)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(tip.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(tip.category.color))
                                .accessibilityHidden(true)
                            Text(step)
                                .font(.body)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                                .accessibilityLabel("Step \(index + 1). \(step)")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .reforgedCard()

                Button {
                    HapticManager.shared.lightImpact()
                    NotificationCenter.default.post(name: .switchTab, object: nil,
                                                    userInfo: ["tab": tip.category.tryItTab])
                    dismiss()
                } label: {
                    Text(tip.tryItLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color.reforgedCoral))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(tip.category.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Video

/// 16:9 player that only appears once the video is actually playable. Until then
/// (or if it's missing/offline) it takes no space, so the steps lead instead.
private struct TipVideoPlayer: View {
    let url: URL
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var model = TipVideoModel()

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.adaptiveChipBackground(colorScheme))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(ProgressView())
            case .ready:
                VideoPlayer(player: model.player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            case .unavailable:
                EmptyView()
            }
        }
        .onAppear { model.load(url) }
        .onDisappear { model.player?.pause() }
    }
}

@MainActor
private final class TipVideoModel: ObservableObject {
    enum State { case loading, ready, unavailable }

    @Published var state: State = .loading
    private(set) var player: AVPlayer?
    private var observation: NSKeyValueObservation?

    func load(_ url: URL) {
        guard player == nil else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        observation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor in
                switch status {
                case .readyToPlay:
                    self?.state = .ready
                    self?.player?.play()
                case .failed:
                    self?.state = .unavailable
                default:
                    break
                }
            }
        }
        // Don't hold a spinner forever on a slow or captive network.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if self?.state == .loading { self?.state = .unavailable }
        }
    }
}

#Preview {
    NavigationStack { TipsView() }
}
