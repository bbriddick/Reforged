import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Bible Audio Bar (Collapsible)

class BibleAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var skipInterval: TimeInterval = 10.0
    @Published var currentBook: String = ""
    @Published var currentChapter: Int = 0

    // Sleep timer
    @Published var sleepTimerRemaining: TimeInterval = 0   // 0 = off
    @Published var sleepTimerEndOfChapter: Bool = false
    private var sleepTimer: Timer?

    private var player: AVPlayer?
    private var timeObserver: Any?

    /// Called when a chapter finishes playing (for marking as read + auto-advance).
    /// Parameters: (book, chapter) of the completed chapter.
    var onChapterCompleted: ((String, Int) -> Void)?

    // Persistence keys for resuming audio across app backgrounding
    private let audioBookKey = "audio_last_book"
    private let audioChapterKey = "audio_last_chapter"
    private let audioWasPlayingKey = "audio_was_playing"
    private let audioTimeKey = "audio_last_time"

    init() {
        setupRemoteCommandCenter()
    }

    /// Update settings from SettingsManager (call from view)
    @MainActor
    func updateFromSettings() {
        playbackRate = SettingsManager.shared.playbackSpeed.rate
        skipInterval = TimeInterval(SettingsManager.shared.skipInterval.seconds)
        if skipInterval == 0 { skipInterval = 10 } // Default for "By Verse" mode
        player?.rate = isPlaying ? playbackRate : 0
    }

    func play(book: String, chapter: Int) {
        guard let url = ESVService.shared.getAudioURL(book: book, chapter: chapter) else { return }

        stop()
        isLoading = true
        currentBook = book
        currentChapter = chapter

        // Persist current audio state for resume
        saveAudioState()

        do {
            // Configure audio session for background playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Token \(ESVConfig.apiKey)"]
        ])

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.rate = playbackRate

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleChapterPlaybackEnded()
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds

            if let duration = self.player?.currentItem?.duration.seconds,
               !duration.isNaN {
                self.duration = duration
            }

            if self.isLoading && time.seconds > 0 {
                self.isLoading = false
            }

            // Update Now Playing info periodically
            self.updateNowPlayingInfo()

            // Periodically save audio position for resume (every ~5 seconds)
            if Int(time.seconds) % 5 == 0 && time.seconds > 0 {
                self.saveAudioState()
            }
        }

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        saveAudioState()
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        currentBook = ""
        currentChapter = 0
        clearAudioState()
        clearNowPlayingInfo()
    }

    // MARK: - Chapter Completion & Auto-Advance

    /// Called when AVPlayer finishes playing the current chapter.
    private func handleChapterPlaybackEnded() {
        let finishedBook = currentBook
        let finishedChapter = currentChapter

        // Notify BibleView to mark chapter as read
        onChapterCompleted?(finishedBook, finishedChapter)

        // Sleep timer: end of chapter mode stops here
        if sleepTimerEndOfChapter {
            cancelSleepTimer()
            isPlaying = false
            currentTime = 0
            updateNowPlayingInfo()
            return
        }

        // Auto-advance to next chapter
        if let nextChapter = nextChapterInfo(book: finishedBook, chapter: finishedChapter) {
            play(book: nextChapter.book, chapter: nextChapter.chapter)
        } else {
            // No more chapters (end of Revelation) — just stop
            isPlaying = false
            currentTime = 0
            updateNowPlayingInfo()
        }
    }

    /// Returns the next book/chapter in canonical order, or nil if at end of Bible.
    private func nextChapterInfo(book: String, chapter: Int) -> (book: String, chapter: Int)? {
        guard let bookData = BibleData.books.first(where: { $0.name == book }) else { return nil }

        // If there are more chapters in this book, go to next chapter
        if chapter < bookData.chapters {
            return (book: book, chapter: chapter + 1)
        }

        // Otherwise, go to next book chapter 1
        guard let bookIndex = BibleData.books.firstIndex(where: { $0.name == book }),
              bookIndex + 1 < BibleData.books.count else {
            return nil // End of Bible
        }

        let nextBook = BibleData.books[bookIndex + 1]
        return (book: nextBook.name, chapter: 1)
    }

    // MARK: - Audio State Persistence (for resume on foreground)

    private func saveAudioState() {
        UserDefaults.standard.set(currentBook, forKey: audioBookKey)
        UserDefaults.standard.set(currentChapter, forKey: audioChapterKey)
        UserDefaults.standard.set(isPlaying, forKey: audioWasPlayingKey)
        UserDefaults.standard.set(currentTime, forKey: audioTimeKey)
    }

    /// Public wrapper for saving audio state (called from BibleView on resign active).
    func saveAudioStatePublic() {
        saveAudioState()
    }

    func clearAudioState() {
        UserDefaults.standard.removeObject(forKey: audioBookKey)
        UserDefaults.standard.removeObject(forKey: audioChapterKey)
        UserDefaults.standard.removeObject(forKey: audioWasPlayingKey)
        UserDefaults.standard.removeObject(forKey: audioTimeKey)
    }

    /// Returns saved audio state, or nil if none exists.
    func savedAudioState() -> (book: String, chapter: Int, time: TimeInterval)? {
        guard let book = UserDefaults.standard.string(forKey: audioBookKey),
              !book.isEmpty else { return nil }
        let chapter = UserDefaults.standard.integer(forKey: audioChapterKey)
        let wasPlaying = UserDefaults.standard.bool(forKey: audioWasPlayingKey)
        let time = UserDefaults.standard.double(forKey: audioTimeKey)
        guard chapter > 0, wasPlaying else { return nil }
        return (book: book, chapter: chapter, time: time)
    }

    /// Resumes playback from saved state (call on app foreground / view appear).
    func resumeFromSavedState() {
        guard let saved = savedAudioState() else { return }
        // Only resume if not already playing something
        guard !isPlaying && player == nil else { return }

        play(book: saved.book, chapter: saved.chapter)

        // Seek to the saved position after a short delay to let the player load
        if saved.time > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.seek(to: saved.time)
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updateNowPlayingInfo()
    }

    func skipForward(_ seconds: TimeInterval? = nil) {
        let interval = seconds ?? skipInterval
        let newTime = min(currentTime + interval, duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval? = nil) {
        let interval = seconds ?? skipInterval
        let newTime = max(currentTime - interval, 0)
        seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
        updateNowPlayingInfo()
    }

    // MARK: - Chapter Navigation

    func playNextChapter() {
        guard let next = nextChapterInfo(book: currentBook, chapter: currentChapter) else { return }
        play(book: next.book, chapter: next.chapter)
    }

    func playPreviousChapter() {
        // If more than 3 seconds in, restart current chapter
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard let bookData = BibleData.books.first(where: { $0.name == currentBook }) else { return }
        let prevChapter: (book: String, chapter: Int)
        if currentChapter > 1 {
            prevChapter = (book: currentBook, chapter: currentChapter - 1)
        } else if let bookIndex = BibleData.books.firstIndex(where: { $0.name == currentBook }), bookIndex > 0 {
            let prevBook = BibleData.books[bookIndex - 1]
            prevChapter = (book: prevBook.name, chapter: prevBook.chapters)
        } else {
            seek(to: 0)
            return
        }
        _ = bookData // suppress warning
        play(book: prevChapter.book, chapter: prevChapter.chapter)
    }

    // MARK: - Now Playing Info (Lock Screen & Control Center)

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(currentBook) \(currentChapter)"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "ESV Audio Bible"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Reforged"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote Command Center (Headphones, Lock Screen Controls)

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.player?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.player?.pause()
                self.isPlaying = false
                self.updateNowPlayingInfo()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        // Skip forward/backward
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(15)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(15)
            return .success
        }

        // Previous / Next chapter
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousChapter()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextChapter()
            return .success
        }

        // Seek
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        sleepTimerEndOfChapter = false
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying { self.sleepTimerRemaining -= 1 }
            if self.sleepTimerRemaining <= 0 {
                DispatchQueue.main.async {
                    self.cancelSleepTimer()
                    self.player?.pause()
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    func setSleepTimerEndOfChapter() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerEndOfChapter = true
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerEndOfChapter = false
    }

    deinit {
        sleepTimer?.invalidate()
        stop()
    }
}

struct BibleAudioBar: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    let book: String
    let chapter: Int
    var translation: BibleTranslation = .esv
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var timeString: String {
        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(audioPlayer.duration)
        return "\(current) / \(total)"
    }

    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var iconColor: Color {
        Color.adaptivePrimaryIcon(colorScheme)
    }

    /// Whether the audio is playing a different chapter than the one being read
    var isPlayingDifferentChapter: Bool {
        !audioPlayer.currentBook.isEmpty &&
        (audioPlayer.currentBook != book || audioPlayer.currentChapter != chapter)
    }

    var body: some View {
        VStack(spacing: 8) {
            // "Now playing" label when audio has auto-advanced to a different chapter
            if isPlayingDifferentChapter {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.reforgedGold)
                    Text("Now playing: \(audioPlayer.currentBook) \(audioPlayer.currentChapter)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.reforgedGold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.reforgedNavy.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.reforgedGold)
                        .frame(width: audioPlayer.duration > 0 ? geo.size.width * (audioPlayer.currentTime / audioPlayer.duration) : 0)
                }
            }
            .frame(height: 3)
            .padding(.horizontal)

            HStack(spacing: 16) {
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(Color.adaptiveBorder(colorScheme))
                        .clipShape(Circle())
                }

                // Skip backward
                Button { audioPlayer.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.callout)
                        .foregroundStyle(iconColor)
                }

                // Play/Pause button
                Button {
                    if audioPlayer.isPlaying || audioPlayer.currentTime > 0 {
                        audioPlayer.togglePlayPause()
                    } else {
                        audioPlayer.play(book: book, chapter: chapter)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.reforgedNavy)
                            .frame(width: 36, height: 36)

                        if audioPlayer.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // Skip forward
                Button { audioPlayer.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.callout)
                        .foregroundStyle(iconColor)
                }

                // Time
                Text(timeString)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 70)

                Spacer()

                // Speed button
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            audioPlayer.setPlaybackRate(Float(rate))
                        } label: {
                            HStack {
                                Text("\(String(format: "%.2g", rate))x")
                                if audioPlayer.playbackRate == Float(rate) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(String(format: "%.1f", audioPlayer.playbackRate))x")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.adaptiveBorder(colorScheme))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}
