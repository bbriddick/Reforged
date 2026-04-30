import SwiftUI
import AVFoundation

private extension Color {
    static let walkTalksTeal = Color(red: 0.004, green: 0.490, blue: 0.616)
}

// MARK: - SleepTimerOption

enum SleepTimerOption: Equatable {
    case off
    case minutes(Int)
    case endOfEpisode
}

// MARK: - PodcastPlayerViewModel

final class PodcastPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = false
    @Published var isDragging = false
    @Published var playbackRate: PlaybackSpeed = .normal
    @Published var sleepTimerRemaining: TimeInterval = 0
    @Published var sleepTimerOption: SleepTimerOption = .off

    private(set) var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var sleepTimer: Timer?
    private(set) var currentEpisodeID: String?

    func load(episode: PodcastEpisode) {
        stop()
        isLoading = true
        currentEpisodeID = episode.id

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }

        let item = AVPlayerItem(url: episode.audioURL)
        player = AVPlayer(playerItem: item)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.sleepTimerOption == .endOfEpisode {
                self.cancelSleepTimer()
            }
            if let id = self.currentEpisodeID {
                Task { @MainActor in
                    PodcastService.shared.markAsPlayed(id)
                }
            }
            self.isPlaying = false
            self.currentTime = 0
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, !isDragging else { return }
            currentTime = time.seconds.isNaN ? 0 : time.seconds
            if let d = player?.currentItem?.duration.seconds, d.isFinite, d > 0 {
                duration = d
            }
            if isLoading && time.seconds > 0 { isLoading = false }
        }

        player?.play()
        player?.rate = playbackRate.rate
        isPlaying = true
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
            player.rate = playbackRate.rate
        }
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, duration > 0 ? duration : seconds))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    func stop() {
        player?.pause()
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        sleepTimer?.invalidate()
        sleepTimer = nil
        timeObserver = nil
        endObserver = nil
        player = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        currentEpisodeID = nil
    }

    func setPlaybackRate(_ speed: PlaybackSpeed) {
        playbackRate = speed
        if isPlaying { player?.rate = speed.rate }
    }

    func setSleepTimer(minutes: Int) {
        sleepTimerOption = .minutes(minutes)
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isPlaying { self.sleepTimerRemaining -= 1 }
            if self.sleepTimerRemaining <= 0 {
                self.player?.pause()
                self.isPlaying = false
                self.cancelSleepTimer()
            }
        }
    }

    func setSleepTimerEndOfEpisode() {
        sleepTimerOption = .endOfEpisode
        sleepTimerRemaining = 0
        sleepTimer?.invalidate()
        sleepTimer = nil
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerOption = .off
    }

    var sleepTimerLabel: String {
        switch sleepTimerOption {
        case .off: return "Off"
        case .endOfEpisode: return "End of ep."
        case .minutes:
            guard sleepTimerRemaining > 0 else { return "Off" }
            let mins = Int(sleepTimerRemaining) / 60
            let secs = Int(sleepTimerRemaining) % 60
            return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
        }
    }

    var timeLabel: String {
        formatTime(currentTime) + " / " + formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - PodcastView

struct PodcastView: View {
    @StateObject private var service = PodcastService.shared
    @StateObject private var playerVM = PodcastPlayerViewModel()
    @State private var selectedEpisode: PodcastEpisode?
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var showAbout = false
    @State private var showExpandedPlayer = false
    @Environment(\.colorScheme) var colorScheme

    private var filteredEpisodes: [PodcastEpisode] {
        guard let episodes = service.feed?.episodes else { return [] }
        var result = episodes
        if let cat = selectedCategory {
            result = result.filter { $0.seriesName == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.plainDescription.lowercased().contains(q)
            }
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if service.isLoading && service.feed == nil {
                VStack {
                    Spacer()
                    ProgressView("Loading episodes…")
                    Spacer()
                }
            } else if let error = service.error, service.feed == nil {
                errorView(error)
            } else {
                episodeList
            }

            if let episode = selectedEpisode {
                MiniPlayerView(
                    episode: episode,
                    feed: service.feed,
                    vm: playerVM,
                    showExpanded: $showExpandedPlayer,
                    onClose: {
                        playerVM.stop()
                        selectedEpisode = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Walk Talks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAbout = true } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showAbout) {
            PodcastAboutView()
        }
        .sheet(isPresented: $showExpandedPlayer) {
            if let episode = selectedEpisode {
                ExpandedPlayerView(
                    episode: episode,
                    feed: service.feed,
                    vm: playerVM,
                    onPrevious: previousEpisode(from: episode).map { prev in { selectEpisode(prev) } },
                    onNext: nextEpisode(from: episode).map { next in { selectEpisode(next) } }
                )
                .presentationDragIndicator(.visible)
            }
        }
        .searchable(text: $searchText, prompt: "Search episodes")
        .task { await service.loadEpisodes() }
        .animation(.easeInOut(duration: 0.3), value: selectedEpisode?.id)
        .animation(.easeInOut(duration: 0.2), value: selectedCategory)
    }

    private var episodeList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let feed = service.feed {
                    PodcastHeaderView(feed: feed)
                        .padding(.bottom, 12)

                    CategoryFilterRow(
                        categories: feed.categories,
                        selectedCategory: $selectedCategory
                    )
                    .padding(.bottom, 12)
                }

                LazyVStack(spacing: 12) {
                    ForEach(filteredEpisodes) { episode in
                        EpisodeRowView(
                            episode: episode,
                            fallbackImageURL: service.feed?.artworkURL,
                            isSelected: episode.id == selectedEpisode?.id,
                            isPlaying: episode.id == selectedEpisode?.id && playerVM.isPlaying,
                            isPlayed: service.isPlayed(episode.id),
                            colorScheme: colorScheme,
                            onTogglePlayed: {
                                if service.isPlayed(episode.id) {
                                    service.markAsUnplayed(episode.id)
                                } else {
                                    service.markAsPlayed(episode.id)
                                }
                            }
                        )
                        .onTapGesture { selectEpisode(episode) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, selectedEpisode != nil ? 120 : 40)
        }
        .refreshable { await service.refresh() }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text(error.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Button("Retry") { Task { await service.refresh() } }
                .buttonStyle(.borderedProminent)
                .tint(Color.walkTalksTeal)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func selectEpisode(_ episode: PodcastEpisode) {
        if selectedEpisode?.id == episode.id {
            playerVM.togglePlayPause()
        } else {
            selectedEpisode = episode
            playerVM.load(episode: episode)
        }
        HapticManager.shared.lightImpact()
    }

    private func previousEpisode(from episode: PodcastEpisode) -> PodcastEpisode? {
        guard let episodes = service.feed?.episodes,
              let idx = episodes.firstIndex(where: { $0.id == episode.id }),
              idx > 0 else { return nil }
        return episodes[idx - 1]
    }

    private func nextEpisode(from episode: PodcastEpisode) -> PodcastEpisode? {
        guard let episodes = service.feed?.episodes,
              let idx = episodes.firstIndex(where: { $0.id == episode.id }),
              idx < episodes.count - 1 else { return nil }
        return episodes[idx + 1]
    }
}

// MARK: - CategoryFilterRow

private struct CategoryFilterRow: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "All", isSelected: selectedCategory == nil, colorScheme: colorScheme) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryChip(label: cat, isSelected: selectedCategory == cat, colorScheme: colorScheme) {
                        selectedCategory = cat
                        HapticManager.shared.lightImpact()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.walkTalksTeal : Color.adaptiveCardBackground(colorScheme))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0.07), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PodcastAboutView

struct PodcastAboutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PodcastArtworkView(
                        url: URL(string: "https://d3t3ozftmdmh3i.cloudfront.net/staging/podcast_uploaded_nologo/24104082/24104082-1692647468238-9795be178feee.jpg"),
                        size: 120,
                        cornerRadius: 20
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
                    .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text("Walk Talks")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("by Southland Christian Ministries")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Walk Talks")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Walk Talks is an extension of the ministry of Southland Christian Camp in Ringgold, LA and is designed for believers of all ages to strengthen their walk with God through daily challenges from God's Word.\n\nEach week, a different member of Southland's full-time staff delivers a series of short, practical podcasts on one Scriptural theme. The \"Friday Focus\" each week highlights summer camp speakers, specific ministries, or personal testimonies.\n\nPacked with practical application, Walk Talks encourages every believer to take the next step to be consistent and passionate in their walk with God.")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Series")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        ForEach(PodcastSeries.displayOrder.filter { $0 != .other }, id: \.rawValue) { series in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.walkTalksTeal.opacity(0.15))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(series.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Text(series.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        Text("Learn More")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        AboutLinkRow(
                            icon: "globe",
                            color: Color.walkTalksTeal,
                            title: "Southland Christian Camp",
                            subtitle: "southlandcamp.org",
                            url: URL(string: "https://www.southlandcamp.org")!
                        )

                        AboutLinkRow(
                            icon: "music.note.list",
                            color: Color(red: 0.1, green: 0.65, blue: 0.8),
                            title: "Listen on Spotify",
                            subtitle: "Open in Spotify app",
                            url: URL(string: "https://open.spotify.com/show/0jGMRRTqNkFRMmkMJEdRpV")!
                        )

                        AboutLinkRow(
                            icon: "waveform",
                            color: Color.reforgedCoral,
                            title: "Listen on Apple Podcasts",
                            subtitle: "Open in Apple Podcasts",
                            url: URL(string: "https://podcasts.apple.com/us/podcast/walk-talks/id1578823699")!
                        )
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 20)
                }
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AboutLinkRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let url: URL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(14)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PodcastHeaderView

private struct PodcastHeaderView: View {
    let feed: PodcastFeed
    @Environment(\.colorScheme) var colorScheme
    @State private var showAbout = false

    var body: some View {
        HStack(spacing: 16) {
            PodcastArtworkView(url: feed.artworkURL, size: 80, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.title.trimmingCharacters(in: .whitespaces))
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(feed.description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(3)
                Button {
                    showAbout = true
                } label: {
                    Text("Read more →")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.walkTalksTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .sheet(isPresented: $showAbout) {
            PodcastAboutView()
        }
    }
}

// MARK: - EpisodeRowView

private struct EpisodeRowView: View {
    let episode: PodcastEpisode
    let fallbackImageURL: URL?
    let isSelected: Bool
    let isPlaying: Bool
    let isPlayed: Bool
    let colorScheme: ColorScheme
    var onTogglePlayed: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PodcastArtworkView(
                    url: episode.imageURL ?? fallbackImageURL,
                    size: 56,
                    cornerRadius: 10
                )
                .opacity(isPlayed ? 0.6 : 1.0)

                if isPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.walkTalksTeal)
                        .background(Circle().fill(Color.white).padding(2))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isPlayed ? Color.adaptiveTextSecondary(colorScheme) : Color.adaptiveText(colorScheme))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(episode.formattedDate)
                    if !episode.duration.isEmpty {
                        Text("·")
                        Text(episode.duration)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.walkTalksTeal : Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onTogglePlayed?()
            } label: {
                Label(isPlayed ? "Unplayed" : "Played",
                      systemImage: isPlayed ? "circle" : "checkmark.circle")
            }
            .tint(Color.walkTalksTeal)
        }
    }
}

// MARK: - MiniPlayerView

private struct MiniPlayerView: View {
    let episode: PodcastEpisode
    let feed: PodcastFeed?
    @ObservedObject var vm: PodcastPlayerViewModel
    @Binding var showExpanded: Bool
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: { showExpanded = true }) {
            HStack(spacing: 12) {
                PodcastArtworkView(
                    url: episode.imageURL ?? feed?.artworkURL,
                    size: 44,
                    cornerRadius: 8
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text("Walk Talks")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                Button(action: vm.togglePlayPause) {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(width: 36, height: 36)
                }

                Button { vm.seek(to: vm.currentTime + 30) } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(width: 36, height: 36)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveBorder(colorScheme))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Color.adaptiveCardBackground(colorScheme)
                    if vm.duration > 0 {
                        GeometryReader { geo in
                            Color.walkTalksTeal.opacity(0.15)
                                .frame(width: geo.size.width * CGFloat(vm.currentTime / vm.duration), height: 2)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - ExpandedPlayerView

struct ExpandedPlayerView: View {
    let episode: PodcastEpisode
    let feed: PodcastFeed?
    @ObservedObject var vm: PodcastPlayerViewModel
    @StateObject private var service = PodcastService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    private let hPad: CGFloat = 32
    private let accent = Color.walkTalksTeal

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.adaptiveBorder(colorScheme).opacity(0.6))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // Header
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("NOW PLAYING")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .tracking(1.5)
                            Text(episode.seriesName)
                                .font(.caption)
                                .foregroundStyle(accent)
                        }
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)

                    // Artwork
                    let artSize = geo.size.width - 72
                    PodcastArtworkView(
                        url: episode.imageURL ?? feed?.artworkURL,
                        size: artSize,
                        cornerRadius: 16
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, y: 8)
                    .scaleEffect(vm.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isPlaying)

                    Spacer(minLength: 28)

                    // Title
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .lineLimit(2)
                            Text(episode.formattedDate)
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, hPad)

                    Spacer(minLength: 20)

                    // Scrubber
                    scrubberView(geo: geo)

                    Spacer(minLength: 32)

                    // Controls
                    controlsRow()

                    Spacer(minLength: 36)

                    // Bottom row: speed | mark played | sleep
                    HStack(alignment: .center) {
                        speedMenu()
                        Spacer()
                        markPlayedButton()
                        Spacer()
                        sleepMenu()
                    }
                    .padding(.horizontal, hPad)

                    Spacer(minLength: 48)
                }
                .frame(width: geo.size.width)
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .onAppear { scrubPosition = vm.currentTime }
        .onChange(of: vm.currentTime) { newTime in
            if !isScrubbing { scrubPosition = newTime }
        }
    }

    // MARK: - Scrubber

    @ViewBuilder
    private func scrubberView(geo: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            GeometryReader { inner in
                let filled = scrubFraction(inner.size.width)
                let thumbSize: CGFloat = isScrubbing ? 20 : 14

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.adaptiveBorder(colorScheme).opacity(0.5))
                        .frame(height: 4)
                    // Fill
                    Capsule()
                        .fill(accent)
                        .frame(width: filled, height: 4)
                    // Thumb
                    Circle()
                        .fill(accent)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
                        .offset(x: max(0, filled - thumbSize / 2))
                        .animation(.interactiveSpring(response: 0.2), value: isScrubbing)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let fraction = max(0, min(1, value.location.x / inner.size.width))
                            scrubPosition = fraction * vm.duration
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / inner.size.width))
                            vm.seek(to: fraction * vm.duration)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 28)
            .padding(.horizontal, hPad)

            HStack {
                Text(formatTime(isScrubbing ? scrubPosition : vm.currentTime))
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text("-\(formatTime(vm.duration - (isScrubbing ? scrubPosition : vm.currentTime)))")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, hPad)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private func controlsRow() -> some View {
        HStack(spacing: 0) {
            Spacer()

            Button { onPrevious?() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(onPrevious != nil ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme).opacity(0.4))
            }
            .disabled(onPrevious == nil)

            Spacer()

            Button { vm.seek(to: vm.currentTime - 30) } label: {
                Image(systemName: "gobackward.30")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Spacer()

            Button { vm.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: vm.isPlaying ? 0 : 2)
                    }
                }
            }

            Spacer()

            Button { vm.seek(to: vm.currentTime + 30) } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Spacer()

            Button { onNext?() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(onNext != nil ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme).opacity(0.4))
            }
            .disabled(onNext == nil)

            Spacer()
        }
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private func speedMenu() -> some View {
        Menu {
            ForEach(PlaybackSpeed.allCases, id: \.rawValue) { speed in
                Button { vm.setPlaybackRate(speed) } label: {
                    HStack {
                        Text(speed.rawValue)
                        if vm.playbackRate == speed { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 13))
                Text(vm.playbackRate.rawValue).font(.caption).fontWeight(.semibold).monospacedDigit()
            }
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func markPlayedButton() -> some View {
        let isPlayed = service.isPlayed(episode.id)
        Button {
            isPlayed ? service.markAsUnplayed(episode.id) : service.markAsPlayed(episode.id)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isPlayed ? "checkmark.circle.fill" : "circle").font(.system(size: 13))
                Text(isPlayed ? "Played" : "Mark Played").font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(isPlayed ? accent : Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(isPlayed ? accent.opacity(0.12) : Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func sleepMenu() -> some View {
        Menu {
            Button { vm.cancelSleepTimer() } label: {
                HStack { Text("Off"); if vm.sleepTimerOption == .off { Image(systemName: "checkmark") } }
            }
            ForEach([15, 30, 45, 60], id: \.self) { mins in
                Button { vm.setSleepTimer(minutes: mins) } label: {
                    HStack {
                        Text("\(mins) minutes")
                        if vm.sleepTimerOption == .minutes(mins) { Image(systemName: "checkmark") }
                    }
                }
            }
            Button { vm.setSleepTimerEndOfEpisode() } label: {
                HStack { Text("End of episode"); if vm.sleepTimerOption == .endOfEpisode { Image(systemName: "checkmark") } }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "moon.fill").font(.system(size: 13))
                Text(vm.sleepTimerOption == .off ? "Sleep" : vm.sleepTimerLabel)
                    .font(.caption).fontWeight(.semibold).monospacedDigit()
            }
            .foregroundStyle(vm.sleepTimerOption != .off ? accent : Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(vm.sleepTimerOption != .off ? accent.opacity(0.12) : Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private func scrubFraction(_ width: CGFloat) -> CGFloat {
        guard vm.duration > 0 else { return 0 }
        return CGFloat((isScrubbing ? scrubPosition : vm.currentTime) / vm.duration) * width
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - PodcastArtworkView

struct PodcastArtworkView: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure, .empty:
                ZStack {
                    Color.walkTalksTeal.opacity(0.15)
                    Image(systemName: "headphones")
                        .foregroundStyle(Color.walkTalksTeal)
                        .font(.system(size: size * 0.35))
                }
            @unknown default:
                Color.gray.opacity(0.1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    NavigationStack {
        PodcastView()
    }
    .environmentObject(AppState.shared)
}
