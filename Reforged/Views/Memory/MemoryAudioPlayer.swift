import SwiftUI
import AVFoundation

// MARK: - Verse Reference Parser

struct MemoryVerseReference {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int

    var chapterLabel: String { "\(book) \(chapter)" }

    static func parse(_ reference: String) -> MemoryVerseReference? {
        guard let colonIdx = reference.lastIndex(of: ":") else { return nil }
        let bookChapter = String(reference[..<colonIdx])
        let versePart = String(reference[reference.index(after: colonIdx)...])
        guard let spaceIdx = bookChapter.lastIndex(of: " "),
              let chapter = Int(bookChapter[bookChapter.index(after: spaceIdx)...]) else { return nil }
        let book = String(bookChapter[..<spaceIdx])
        if let dashIdx = versePart.firstIndex(of: "-") {
            let start = Int(versePart[..<dashIdx]) ?? 1
            let end = Int(versePart[versePart.index(after: dashIdx)...]) ?? start
            return MemoryVerseReference(book: book, chapter: chapter, verseStart: start, verseEnd: end)
        }
        let verse = Int(versePart) ?? 1
        return MemoryVerseReference(book: book, chapter: chapter, verseStart: verse, verseEnd: verse)
    }

    func buildReference(start: Int, end: Int) -> String {
        start == end ? "\(book) \(chapter):\(start)" : "\(book) \(chapter):\(start)-\(end)"
    }
}

// MARK: - Memory Audio Player

class MemoryAudioPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = MemoryAudioPlayer()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentVerse: MemoryVerse?
    @Published var loopCount = 0
    @Published var targetLoopCount: Int? = nil   // nil = infinite
    @Published var playbackRate: Float = 1.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // Overrides set via settings sheet
    @Published var overrideStartVerse: Int? = nil
    @Published var overrideEndVerse: Int? = nil
    @Published var overrideTranslation: String? = nil
    /// Loop the entire chapter instead of just the verse range. ESV and KJV then play their
    /// narrated chapter audio; the KJV narration only exists per chapter, not per verse.
    @Published var overrideWholeChapter = false
    /// True right after a KJV verse loop starts, so the bar can point out the narrated option.
    @Published var showKJVChapterHint = false

    private var player: AVPlayer?
    /// Invalidated on every stop so a slow KJV file lookup can't start after the loop was cancelled.
    private var loadToken = UUID()
    /// The utterance this player is currently speaking. A finish callback for any other
    /// utterance (one cancelled by a restart or a switch to narrated audio) is ignored.
    private var activeUtterance: AVSpeechUtterance?
    private var timeObserver: Any?
    private var loopObserver: Any?
    private let synthesizer = AVSpeechSynthesizer()

    var activeReference: String {
        guard let verse = currentVerse,
              let parsed = MemoryVerseReference.parse(verse.reference) else {
            return currentVerse?.reference ?? ""
        }
        if overrideWholeChapter { return parsed.chapterLabel }
        let start = overrideStartVerse ?? parsed.verseStart
        let end = max(overrideEndVerse ?? parsed.verseEnd, start)
        return parsed.buildReference(start: start, end: end)
    }

    var activeTranslation: String {
        overrideTranslation ?? currentVerse?.translation ?? "ESV"
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// ESV always streams narrated audio. KJV does too, but only for whole-chapter loops.
    private var usesNarratedAudio: Bool {
        activeTranslation == "ESV" || (activeTranslation == "KJV" && overrideWholeChapter)
    }

    func play(verse: MemoryVerse) {
        stopAudio()
        if currentVerse?.id != verse.id { overrideWholeChapter = false }
        currentVerse = verse
        loopCount = 1
        isPlaying = false
        showKJVChapterHint = activeTranslation == "KJV" && !overrideWholeChapter
        startAudio()
    }

    /// Switches a KJV verse loop to the narrated KJV chapter audio.
    func loopWholeChapter() {
        overrideWholeChapter = true
        showKJVChapterHint = false
        restart()
    }

    func restart() {
        guard currentVerse != nil else { return }
        stopAudio()
        loopCount = 1
        startAudio()
    }

    private func startAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { debugLog("MemoryAudioPlayer session error: \(error)") }

        if activeTranslation == "ESV" {
            playESV()
        } else if usesNarratedAudio {
            playKJV()
        } else {
            playTTS()
        }
        isPlaying = true
    }

    private func stopAudio() {
        loadToken = UUID()
        activeUtterance = nil
        player?.pause()
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        if let obs = loopObserver { NotificationCenter.default.removeObserver(obs); loopObserver = nil }
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
        currentTime = 0
        duration = 0
        isLoading = false
    }

    func pause() {
        if player != nil { player?.pause() }
        else { synthesizer.pauseSpeaking(at: .word) }
        isPlaying = false
    }

    func resume() {
        if player != nil { player?.play() }
        else { synthesizer.continueSpeaking() }
        isPlaying = true
    }

    func stop() {
        stopAudio()
        isPlaying = false
        currentVerse = nil
        loopCount = 0
        overrideStartVerse = nil
        overrideEndVerse = nil
        overrideTranslation = nil
        overrideWholeChapter = false
        showKJVChapterHint = false
        targetLoopCount = nil
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
    }

    // MARK: - ESV Audio

    private func playESV() {
        guard let url = ESVService.shared.getAudioURL(reference: activeReference) else { return }
        startNarratedPlayback(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Token \(ESVConfig.apiKey)"]]
        )
    }

    // MARK: - KJV Chapter Audio

    /// KJV narration (the same source as the Bible reader, or the offline download when
    /// present). Falls back to the on-device voice if the chapter can't be resolved.
    private func playKJV() {
        guard let parsed = currentVerse.flatMap({ MemoryVerseReference.parse($0.reference) }),
              let book = Self.kjvAudioBook(parsed.book) else {
            playTTS()
            return
        }
        isLoading = true
        let token = loadToken
        Task { @MainActor in
            do {
                let url = try await KJVAudioService.shared.getAudioURL(book: book, chapter: parsed.chapter)
                guard token == self.loadToken else { return }
                self.startNarratedPlayback(url: url, options: nil)
            } catch {
                debugLog("MemoryAudioPlayer KJV audio error: \(error)")
                guard token == self.loadToken else { return }
                self.isLoading = false
                self.playTTS()
            }
        }
    }

    /// Maps memory-verse book names onto the KJV audio manifest's names (e.g. "Psalm" → "Psalms").
    private static func kjvAudioBook(_ book: String) -> String? {
        let aliases = ["Psalm": "Psalms", "Song of Songs": "Song of Solomon", "Songs of Solomon": "Song of Solomon"]
        let name = aliases[book] ?? book
        return KJVAudioService.shared.chapterCount(book: name) > 0 ? name : nil
    }

    private func startNarratedPlayback(url: URL, options: [String: Any]?) {
        isLoading = true
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.rate = playbackRate

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.handleLoopEnd() }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let d = self.player?.currentItem?.duration.seconds, !d.isNaN { self.duration = d }
            if self.isLoading && time.seconds > 0 { self.isLoading = false }
        }

        player?.play()
    }

    // MARK: - TTS Audio

    private func playTTS() {
        guard let verse = currentVerse,
              let parsed = MemoryVerseReference.parse(verse.reference) else {
            if let v = currentVerse { speakText(v.text) }
            return
        }

        isLoading = true
        let translation = activeTranslation
        let start = overrideStartVerse ?? parsed.verseStart
        let end = max(overrideEndVerse ?? parsed.verseEnd, start)
        let wholeChapter = overrideWholeChapter
        // The chapter-text fetch is async. If the loop is restarted or switched to narrated
        // audio before it returns, the stale fetch must not start speaking over the new audio.
        let token = loadToken

        Task { @MainActor in
            do {
                let verses = try await self.fetchVerses(book: parsed.book, chapter: parsed.chapter, translation: translation)
                guard token == self.loadToken else { return }
                let text = verses
                    .filter { wholeChapter || ($0.number >= start && $0.number <= end) }
                    .map { $0.text }
                    .joined(separator: " ")
                self.isLoading = false
                self.speakText(text.isEmpty ? verse.text : text)
            } catch {
                debugLog("MemoryAudioPlayer TTS fetch error: \(error)")
                guard token == self.loadToken else { return }
                self.isLoading = false
                self.speakText(verse.text)
            }
        }
    }

    private func speakText(_ text: String) {
        // Narrated audio owns playback; never speak over it.
        guard player == nil else { return }
        let utterance = TTSVoiceService.shared.makeUtterance(text: text, rate: playbackRate)
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    private func fetchVerses(book: String, chapter: Int, translation: String) async throws -> [ParsedVerse] {
        switch translation {
        case "ESV":
            let (verses, _, _) = try await ESVService.shared.fetchChapterParsed(book: book, chapter: chapter)
            return verses
        case "KJV":
            let (verses, _) = try await KJVService.shared.fetchChapterParsed(book: book, chapter: chapter)
            return verses
        case "NET":
            let (verses, _) = try await NETService.shared.fetchChapterParsed(book: book, chapter: chapter)
            return verses
        default:
            let bt = BibleTranslation(rawValue: translation) ?? .nasb
            let (verses, _) = try await ApiBibleService.shared.fetchChapterParsed(book: book, chapter: chapter, translation: bt)
            return verses
        }
    }

    // MARK: - Loop Management

    private func handleLoopEnd() {
        if let target = targetLoopCount, loopCount >= target {
            DispatchQueue.main.async { self.stop() }
            return
        }
        loopCount += 1
        player?.seek(to: .zero) { [weak self] _ in self?.player?.play() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard isPlaying, utterance === activeUtterance else { return }
        if let target = targetLoopCount, loopCount >= target {
            DispatchQueue.main.async { self.stop() }
            return
        }
        let token = loadToken
        DispatchQueue.main.async {
            // Dropped if the loop was stopped/restarted between the finish and this hop.
            guard token == self.loadToken, self.player == nil else { return }
            self.loopCount += 1
            self.playTTS()
        }
    }
}

// MARK: - Collapsed Audio Bar (matches BibleAudioBar style)

struct MemoryAudioBar: View {
    @ObservedObject private var player = MemoryAudioPlayer.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettings = false

    private var iconColor: Color { Color.adaptivePrimaryIcon(colorScheme) }

    /// Verse loops can't use the KJV narration (it only exists per chapter), so point out
    /// the whole-chapter option when a KJV verse loop starts.
    private var kjvChapterHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.subheadline.bold())
                .foregroundStyle(Color.reforgedGold)

            Text("Verse loops use the on-device voice. Loop the whole chapter to hear the narrated KJV.")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Use it") { player.loopWholeChapter() }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.reforgedCoral, in: Capsule())

            Button { player.showKJVChapterHint = false } label: {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.reforgedGold.opacity(colorScheme == .dark ? 0.16 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var repeatLabel: String {
        if let target = player.targetLoopCount {
            return "× \(player.loopCount) of \(target)"
        }
        return "× \(player.loopCount)"
    }

    var body: some View {
        if player.currentVerse != nil {
            VStack(spacing: 6) {
                if player.showKJVChapterHint {
                    kjvChapterHint
                }

                // Progress bar (visible when narrated-audio duration is known)
                if player.duration > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.reforgedNavy.opacity(0.12))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.reforgedGold)
                                .frame(width: geo.size.width * min(player.currentTime / max(player.duration, 1), 1))
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    // Close
                    Button { player.stop() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(iconColor)
                            .frame(width: 28, height: 28)
                            .background(Color.adaptiveBorder(colorScheme))
                            .clipShape(Circle())
                    }

                    // Play / Pause
                    Button {
                        if player.isPlaying { player.pause() } else { player.resume() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.reforgedNavy)
                                .frame(width: 36, height: 36)
                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // Reference + loop count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.activeReference)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            Image(systemName: "repeat")
                                .font(.system(size: 9))
                            Text(repeatLabel)
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    Spacer()

                    // Speed menu
                    Menu {
                        ForEach([Float(0.75), 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                            Button {
                                player.setRate(rate)
                            } label: {
                                HStack {
                                    Text(String(format: "%.2gx", rate))
                                    if player.playbackRate == rate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(String(format: "%.2gx", player.playbackRate))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(iconColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.adaptiveBorder(colorScheme))
                            .clipShape(Capsule())
                    }

                    // Expand settings
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption.bold())
                            .foregroundStyle(iconColor)
                            .frame(width: 28, height: 28)
                            .background(Color.adaptiveBorder(colorScheme))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .padding(.top, player.duration > 0 ? 2 : 10)
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .shadow(color: .black.opacity(0.06), radius: 6, y: -2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $showSettings) {
                MemoryAudioSettingsSheet()
            }
        }
    }
}

// MARK: - Settings Sheet

struct MemoryAudioSettingsSheet: View {
    @ObservedObject private var player = MemoryAudioPlayer.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var startVerse: Int = 1
    @State private var endVerse: Int = 1
    @State private var speed: Float = 1.0
    @State private var repeatCount: Int? = nil
    @State private var translation: String = "ESV"
    @State private var voiceIdentifier: String? = nil
    @State private var wholeChapter = false

    private let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private let repeatOptions: [(String, Int?)] = [
        ("1", 1), ("3", 3), ("5", 5), ("10", 10), ("20", 20), ("∞", nil)
    ]
    private let translationOptions = ["ESV", "KJV", "NASB", "CSB", "NKJV"]

    private var parsedRef: MemoryVerseReference? {
        player.currentVerse.flatMap { MemoryVerseReference.parse($0.reference) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let verse = player.currentVerse {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verse.reference)
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("Listening on Loop")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "repeat")
                                .font(.title2)
                                .foregroundStyle(Color.reforgedNavy.opacity(0.4))
                        }
                        .padding()
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                    }

                    // Verse Range
                    if let parsed = parsedRef {
                        settingsCard(title: "Verse Range", icon: "text.book.closed") {
                            HStack {
                                Text(parsed.chapterLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Spacer()
                            }
                            .padding(.bottom, 2)

                            Toggle(isOn: $wholeChapter.animation()) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Loop the whole chapter")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Text("Plays the narrated chapter audio for ESV and KJV")
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                            .tint(Color.reforgedCoral)

                            Divider()

                            Group {
                            Stepper(value: $startVerse, in: 1...200) {
                                HStack {
                                    Text("From verse")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Spacer()
                                    Text("\(startVerse)")
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                        .frame(width: 32, alignment: .center)
                                }
                            }

                            Divider()

                            Stepper(value: $endVerse, in: startVerse...200) {
                                HStack {
                                    Text("To verse")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Spacer()
                                    Text("\(endVerse)")
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                        .frame(width: 32, alignment: .center)
                                }
                            }
                            .onChange(of: startVerse) { newVal in
                                if endVerse < newVal { endVerse = newVal }
                            }
                            }
                            .disabled(wholeChapter)
                            .opacity(wholeChapter ? 0.4 : 1)
                        }
                    }

                    // Speed
                    settingsCard(title: "Speed", icon: "gauge.with.dots.needle.67percent") {
                        HStack(spacing: 6) {
                            ForEach(speedOptions, id: \.self) { rate in
                                let selected = speed == rate
                                Button { speed = rate } label: {
                                    Text(String(format: "%.2gx", rate))
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(selected ? .white : Color.adaptiveText(colorScheme))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(selected ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Repeat
                    settingsCard(title: "Repeat", icon: "repeat") {
                        HStack(spacing: 6) {
                            ForEach(repeatOptions, id: \.0) { label, value in
                                let selected = repeatCount == value
                                Button { repeatCount = value } label: {
                                    Text(label)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(selected ? .white : Color.adaptiveText(colorScheme))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(selected ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Voice
                    settingsCard(title: "Voice", icon: "waveform") {
                        TTSVoicePickerView(selectedIdentifier: $voiceIdentifier)
                    }

                    // Translation
                    settingsCard(title: "Translation", icon: "globe") {
                        HStack(spacing: 6) {
                            ForEach(translationOptions, id: \.self) { t in
                                let selected = translation == t
                                Button { translation = t } label: {
                                    VStack(spacing: 2) {
                                        Text(t)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(selected ? .white : Color.adaptiveText(colorScheme))
                                        Text(t == "ESV" || (t == "KJV" && wholeChapter) ? "audio" : "TTS")
                                            .font(.system(size: 9))
                                            .foregroundStyle(selected ? .white.opacity(0.65) : Color.adaptiveTextSecondary(colorScheme))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selected ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        if translation == "KJV" && !wholeChapter {
                            Button {
                                withAnimation { wholeChapter = true }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(Color.reforgedGold)
                                    Text("Narrated KJV audio is only available when looping a whole chapter. Tap to switch.")
                                        .font(.caption)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Listening Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyAndDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedNavy)
                }
            }
        }
        .onAppear { loadCurrentSettings() }
    }

    @ViewBuilder
    private func settingsCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                Text(title)
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
    }

    private func loadCurrentSettings() {
        if let parsed = parsedRef {
            startVerse = player.overrideStartVerse ?? parsed.verseStart
            endVerse = player.overrideEndVerse ?? parsed.verseEnd
        }
        speed = player.playbackRate
        repeatCount = player.targetLoopCount
        translation = player.overrideTranslation ?? player.currentVerse?.translation ?? "ESV"
        wholeChapter = player.overrideWholeChapter
        voiceIdentifier = TTSVoiceService.shared.selectedVoiceIdentifier
    }

    private func applyAndDismiss() {
        if let parsed = parsedRef {
            player.overrideStartVerse = startVerse == parsed.verseStart ? nil : startVerse
            player.overrideEndVerse = endVerse == parsed.verseEnd ? nil : endVerse
        }
        player.overrideWholeChapter = wholeChapter
        player.showKJVChapterHint = false
        player.targetLoopCount = repeatCount
        player.setRate(speed)
        player.overrideTranslation = (translation == (player.currentVerse?.translation ?? "ESV")) ? nil : translation
        TTSVoiceService.shared.selectedVoiceIdentifier = voiceIdentifier
        player.restart()
        dismiss()
    }
}
