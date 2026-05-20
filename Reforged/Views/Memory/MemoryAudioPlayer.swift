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

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var loopObserver: Any?
    private let synthesizer = AVSpeechSynthesizer()

    var activeReference: String {
        guard let verse = currentVerse,
              let parsed = MemoryVerseReference.parse(verse.reference) else {
            return currentVerse?.reference ?? ""
        }
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

    func play(verse: MemoryVerse) {
        stopAudio()
        currentVerse = verse
        loopCount = 1
        isPlaying = false
        startAudio()
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
        } catch { print("MemoryAudioPlayer session error: \(error)") }

        if activeTranslation == "ESV" {
            playESV()
        } else {
            playTTS()
        }
        isPlaying = true
    }

    private func stopAudio() {
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
        if activeTranslation == "ESV" { player?.pause() }
        else { synthesizer.pauseSpeaking(at: .word) }
        isPlaying = false
    }

    func resume() {
        if activeTranslation == "ESV" { player?.play() }
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
        targetLoopCount = nil
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
    }

    // MARK: - ESV Audio

    private func playESV() {
        guard let url = ESVService.shared.getAudioURL(reference: activeReference) else { return }
        isLoading = true

        let options = ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Token \(ESVConfig.apiKey)"]]
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

        Task { @MainActor in
            do {
                let verses = try await self.fetchVerses(book: parsed.book, chapter: parsed.chapter, translation: translation)
                let text = verses
                    .filter { $0.number >= start && $0.number <= end }
                    .map { $0.text }
                    .joined(separator: " ")
                self.isLoading = false
                self.speakText(text.isEmpty ? verse.text : text)
            } catch {
                print("MemoryAudioPlayer TTS fetch error: \(error)")
                self.isLoading = false
                self.speakText(verse.text)
            }
        }
    }

    private func speakText(_ text: String) {
        let utterance = TTSVoiceService.shared.makeUtterance(text: text, rate: playbackRate)
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
        guard isPlaying else { return }
        if let target = targetLoopCount, loopCount >= target {
            DispatchQueue.main.async { self.stop() }
            return
        }
        DispatchQueue.main.async {
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

    private var repeatLabel: String {
        if let target = player.targetLoopCount {
            return "× \(player.loopCount) of \(target)"
        }
        return "× \(player.loopCount)"
    }

    var body: some View {
        if player.currentVerse != nil {
            VStack(spacing: 6) {
                // Progress bar (visible when ESV duration is known)
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
                                        Text(t == "ESV" ? "audio" : "TTS")
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
        voiceIdentifier = TTSVoiceService.shared.selectedVoiceIdentifier
    }

    private func applyAndDismiss() {
        if let parsed = parsedRef {
            player.overrideStartVerse = startVerse == parsed.verseStart ? nil : startVerse
            player.overrideEndVerse = endVerse == parsed.verseEnd ? nil : endVerse
        }
        player.targetLoopCount = repeatCount
        player.setRate(speed)
        player.overrideTranslation = (translation == (player.currentVerse?.translation ?? "ESV")) ? nil : translation
        TTSVoiceService.shared.selectedVoiceIdentifier = voiceIdentifier
        player.restart()
        dismiss()
    }
}
