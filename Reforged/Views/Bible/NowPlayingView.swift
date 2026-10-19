import SwiftUI
import AVFoundation

// MARK: - Now Playing View (full-screen player)

/// Full-screen audio player. It follows the app's appearance (warm paper in light, charcoal in
/// dark) like every other screen; only the cover art is fixed, the way an album cover is.
struct NowPlayingView: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    /// When hosted in the iPad tools sidebar (not a sheet), the environment dismiss
    /// is a no-op, so the host passes an explicit close. Falls back to `dismiss`.
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0
    @StateObject private var kjvDownloads = KJVAudioDownloadManager.shared
    @State private var showKJVDownloads = false

    /// KJV is the only translation with downloadable audio; surface the control
    /// only when a KJV chapter (not TTS) is the active track.
    var showsKJVDownload: Bool {
        audioPlayer.currentTranslation == .kjv && !audioPlayer.isTTSMode
    }

    var displayBook: String { audioPlayer.currentBook.isEmpty ? "" : audioPlayer.currentBook }
    var displayChapter: Int { audioPlayer.currentChapter }

    var audioSubtitle: String {
        audioPlayer.isTTSMode
            ? "\(audioPlayer.currentTranslation.rawValue.uppercased()) \u{00B7} Text-to-Speech"
            : (audioPlayer.currentTranslation == .kjv ? "KJV Audio Bible" : "ESV Audio Bible")
    }

    private var primary: Color { Color.adaptiveText(colorScheme) }
    private var secondary: Color { Color.adaptiveTextSecondary(colorScheme) }

    var body: some View {
        GeometryReader { geo in
            let isWide = horizontalSizeClass == .regular
            let isLandscape = !isWide && geo.size.width > geo.size.height

            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if isLandscape {
                    landscapeBody(geo: geo)
                } else {
                    portraitBody(geo: geo, isWide: isWide)
                }
            }
        }
        .onAppear {
            scrubPosition = audioPlayer.currentTime
            kjvDownloads.refreshState()
        }
        .sheet(isPresented: $showKJVDownloads) {
            NavigationStack {
                KJVAudioDownloadsView()
            }
        }
    }

    // MARK: - Portrait / iPad layout

    @ViewBuilder
    private func portraitBody(geo: GeometryProxy, isWide: Bool) -> some View {
        let maxContent: CGFloat = isWide ? min(geo.size.width * 0.65, 520) : geo.size.width
        let artSize: CGFloat = isWide ? min(max(0, maxContent - 80), 380) : max(0, geo.size.width - 72)
        let hPad: CGFloat = isWide ? 40 : 32

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Grab handle (the sheet's own indicator is hidden for this full-screen player)
                Capsule()
                    .fill(secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Header: collapse, title
                ZStack {
                    Text("Now playing")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(secondary)

                    HStack {
                        Button { onClose?() ?? dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(primary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close player")
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)

                Spacer(minLength: isWide ? 24 : 16)

                cover(size: artSize, radius: 16)

                Spacer(minLength: isWide ? 32 : 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayBook.isEmpty ? "Audio Bible" : "\(displayBook) \(displayChapter)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primary)
                        .lineLimit(1)
                    Text(audioSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, hPad)

                Spacer(minLength: 20)

                scrubberView(hPad: hPad)

                Spacer(minLength: isWide ? 24 : 20)

                controlsRow(isWide: isWide)

                Spacer(minLength: 28)

                optionsRow
                    .padding(.horizontal, hPad)

                Spacer(minLength: isWide ? 40 : 32)
            }
            .frame(width: maxContent)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Landscape iPhone layout (top: artwork + info, bottom: full-width controls)

    @ViewBuilder
    private func landscapeBody(geo: GeometryProxy) -> some View {
        // Reserve space for controls + options + gaps at the bottom
        let bottomSectionHeight: CGFloat = 72 + 44 + 28
        let topSectionHeight: CGFloat = geo.size.height - bottomSectionHeight
        // Artwork is square, sized to fit the top section height
        let artSize: CGFloat = max(80, topSectionHeight - 16)
        let hPad: CGFloat = 24

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    cover(size: artSize, radius: 12)

                    Button { onClose?() ?? dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close player")
                }
                .frame(width: artSize)
                .padding(.leading, hPad)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayBook.isEmpty ? "Audio Bible" : "\(displayBook) \(displayChapter)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(primary)
                            .lineLimit(1)
                        Text(audioSubtitle)
                            .font(.caption)
                            .foregroundStyle(secondary)
                    }
                    .padding(.horizontal, hPad)
                    Spacer(minLength: 12)
                    scrubberView(hPad: hPad)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: topSectionHeight)

            controlsRow(isWide: false)
                .padding(.bottom, 4)

            optionsRow
                .padding(.horizontal, hPad)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Sub-views

    /// Cover art with the warm elevation shadow; it eases back slightly while paused.
    private func cover(size: CGFloat, radius: CGFloat) -> some View {
        AudioAlbumArtwork(book: displayBook, chapter: displayChapter, translation: audioPlayer.currentTranslation)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: Color.black.opacity(0.16), radius: 24, y: 12)
            .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.94)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: audioPlayer.isPlaying)
            .accessibilityHidden(true)
    }

    /// Speed, offline download (KJV) and sleep timer: one row of equal secondary controls.
    private var optionsRow: some View {
        HStack(alignment: .center) {
            speedButton()
            Spacer()
            if showsKJVDownload {
                kjvDownloadButton()
                Spacer()
            }
            SleepTimerButtonView(audioPlayer: audioPlayer).equatable()
        }
    }

    @ViewBuilder
    private func scrubberView(hPad: CGFloat) -> some View {
        Group {
            if audioPlayer.isTTSMode {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text("Text-to-Speech \u{00B7} \(audioPlayer.currentTranslation.rawValue.uppercased())")
                }
                .font(.footnote)
                .foregroundStyle(secondary)
                .padding(.horizontal, hPad)
                .padding(.vertical, 8)
            } else {
                progressScrubber(hPad: hPad)
            }
        }
    }

    private func progressScrubber(hPad: CGFloat) -> some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(secondary.opacity(0.2))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.reforgedCoral)
                        .frame(width: scrubFraction(geo.size.width), height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            scrubPosition = fraction * audioPlayer.duration
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            audioPlayer.seek(to: fraction * audioPlayer.duration)
                            isScrubbing = false
                        }
                )
            }
            // 44 pt tall touch area around the 4 pt track
            .frame(height: 44)
            .padding(.horizontal, hPad)
            .accessibilityElement()
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(formatTime(isScrubbing ? scrubPosition : audioPlayer.currentTime)) of \(formatTime(audioPlayer.duration))")

            HStack {
                Text(formatTime(isScrubbing ? scrubPosition : audioPlayer.currentTime))
                Spacer()
                Text("-\(formatTime(audioPlayer.duration - (isScrubbing ? scrubPosition : audioPlayer.currentTime)))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(secondary)
            .padding(.horizontal, hPad)
        }
        .onChange(of: audioPlayer.currentTime) { newTime in
            if !isScrubbing { scrubPosition = newTime }
        }
    }

    private func transportButton(_ icon: String, size: CGFloat, label: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(primary)
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func controlsRow(isWide: Bool) -> some View {
        let btnSpacing: CGFloat = isWide ? 40 : 0
        HStack(spacing: btnSpacing) {
            if !isWide { Spacer() }

            transportButton("backward.fill", size: 26, label: "Previous chapter") { audioPlayer.playPreviousChapter() }

            if !isWide { Spacer() }

            transportButton("gobackward.15", size: 24, label: "Back 15 seconds") { audioPlayer.skipBackward(15) }

            if !isWide { Spacer() }

            // Play / Pause
            Button {
                if audioPlayer.isPlaying || audioPlayer.currentTime > 0 {
                    audioPlayer.togglePlayPause()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(primary)
                        .frame(width: 72, height: 72)
                    if audioPlayer.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.adaptiveBackground(colorScheme)))
                    } else {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.adaptiveBackground(colorScheme))
                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

            if !isWide { Spacer() }

            transportButton("goforward.15", size: 24, label: "Forward 15 seconds") { audioPlayer.skipForward(15) }

            if !isWide { Spacer() }

            transportButton("forward.fill", size: 26, label: "Next chapter") { audioPlayer.playNextChapter() }

            if !isWide { Spacer() }
        }
    }

    /// Download affordance for KJV audio: opens the offline-download screen and reflects the
    /// current book's state (available / downloading / saved).
    @ViewBuilder
    private func kjvDownloadButton() -> some View {
        let book = audioPlayer.currentBook
        let bookProgress = kjvDownloads.bookProgress[book]
        let isDownloading = bookProgress != nil || kjvDownloads.isDownloadingAll
        let isSaved = kjvDownloads.downloadedBooks.contains(book)

        Button {
            showKJVDownloads = true
        } label: {
            PlayerPill(colorScheme: colorScheme) {
                if isDownloading {
                    let pct = Int((bookProgress ?? kjvDownloads.allProgress) * 100)
                    Image(systemName: "arrow.down.circle")
                    Text("\(pct)%").monospacedDigit()
                } else if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved")
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                }
            }
            .foregroundStyle(isSaved ? Color.reforgedGold : secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func speedButton() -> some View {
        Menu {
            ForEach([0.75, 1.0, 1.25, 1.5, 2.0] as [Float], id: \.self) { rate in
                Button {
                    audioPlayer.setPlaybackRate(rate)
                } label: {
                    HStack {
                        Text(rateLabel(rate))
                        if audioPlayer.playbackRate == rate {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            PlayerPill(colorScheme: colorScheme) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                Text(rateLabel(audioPlayer.playbackRate)).monospacedDigit()
            }
            .foregroundStyle(secondary)
        }
        .accessibilityLabel("Playback speed")
    }

    // MARK: - Helpers

    private func scrubFraction(_ width: CGFloat) -> CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        let fraction = (isScrubbing ? scrubPosition : audioPlayer.currentTime) / audioPlayer.duration
        return CGFloat(fraction) * width
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time > 0 else { return "0:00" }
        let t = max(0, time)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func rateLabel(_ rate: Float) -> String {
        switch rate {
        case 0.75: return "\u{00BE}\u{00D7}"
        case 1.0:  return "1\u{00D7}"
        case 1.25: return "1.25\u{00D7}"
        case 1.5:  return "1.5\u{00D7}"
        case 2.0:  return "2\u{00D7}"
        default:   return String(format: "%.2g\u{00D7}", rate)
        }
    }
}

// MARK: - Player pill

/// The secondary controls under the transport (speed, download, sleep): a quiet chip with a
/// 44 pt hit area. Foreground colour comes from the caller.
struct PlayerPill<Content: View>: View {
    let colorScheme: ColorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 6) {
            content()
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.adaptiveChipBackground(colorScheme)))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Sleep Timer Button (equatable to avoid re-rendering on every currentTime tick)

struct SleepTimerButtonView: View, Equatable {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    @Environment(\.colorScheme) private var colorScheme

    static func == (lhs: SleepTimerButtonView, rhs: SleepTimerButtonView) -> Bool {
        lhs.audioPlayer.sleepTimerRemaining == rhs.audioPlayer.sleepTimerRemaining &&
        lhs.audioPlayer.sleepTimerEndOfChapter == rhs.audioPlayer.sleepTimerEndOfChapter
    }

    var body: some View {
        if audioPlayer.sleepTimerRemaining > 0 || audioPlayer.sleepTimerEndOfChapter {
            PlayerPill(colorScheme: colorScheme) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(Color.reforgedGold)
                Text(audioPlayer.sleepTimerEndOfChapter
                     ? "End of chapter"
                     : sleepTimerLabel(audioPlayer.sleepTimerRemaining))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .monospacedDigit()
                Button {
                    audioPlayer.cancelSleepTimer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel sleep timer")
            }
        } else {
            Menu {
                Button("5 minutes")  { audioPlayer.setSleepTimer(minutes: 5) }
                Button("10 minutes") { audioPlayer.setSleepTimer(minutes: 10) }
                Button("15 minutes") { audioPlayer.setSleepTimer(minutes: 15) }
                Button("30 minutes") { audioPlayer.setSleepTimer(minutes: 30) }
                Button("45 minutes") { audioPlayer.setSleepTimer(minutes: 45) }
                Button("1 hour")     { audioPlayer.setSleepTimer(minutes: 60) }
                Divider()
                Button("End of chapter") { audioPlayer.setSleepTimerEndOfChapter() }
            } label: {
                PlayerPill(colorScheme: colorScheme) {
                    Image(systemName: "moon.fill")
                    Text("Sleep")
                }
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .accessibilityLabel("Sleep timer")
        }
    }

    private func sleepTimerLabel(_ remaining: TimeInterval) -> String {
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : String(format: "0:%02d", secs)
    }
}

// MARK: - Album Artwork

/// Cover for the audio player, the lock screen and the mini player. A light, editorial card in
/// the same family as the shareable verse card: warm paper on a soft rim, the chapter number as
/// the one large element (it has to read at 44 pt), the book name in the Scripture serif, a gold
/// divider, and the charcoal mark. Flat on purpose: no gradients, textures or glows.
struct AudioAlbumArtwork: View {
    let book: String
    let chapter: Int
    var translation: BibleTranslation = .esv

    // Fixed brand values, so the cover is the same object in light and dark appearance.
    private static let rim = Color(red: 0.945, green: 0.933, blue: 0.914)        // #F1EEE9
    private static let paper = Color(red: 0.980, green: 0.973, blue: 0.961)      // #FAF8F5
    private static let deepGold = Color(red: 0.690, green: 0.498, blue: 0.306)   // #B07F4E, reads on paper

    private var ink: Color { Color.reforgedCharcoal }

    /// "KJV" / "ESV" in the corner, so the cover says which audio this is.
    private var translationCode: String { translation.rawValue.uppercased() }

    /// KJV is public domain; ESV requires the Crossway notice.
    private var attribution: String {
        translation == .kjv ? "Public Domain" : "\u{00A9} 2001 Crossway"
    }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 300

            ZStack {
                Self.rim

                RoundedRectangle(cornerRadius: 22)
                    .fill(Self.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(10)

                VStack(spacing: 0) {
                    // Eyebrow: what this is, and which translation
                    HStack {
                        Text("AUDIO BIBLE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Self.deepGold)
                        Spacer()
                        Text(translationCode)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(ink.opacity(0.45))
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                    Spacer(minLength: 0)

                    if book.isEmpty {
                        // Nothing loaded yet: the mark stands in for the chapter
                        Image("ReforgedMark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 84)
                    } else {
                        Text("\(chapter)")
                            .font(Font.custom("LibreBaskerville-Regular", size: 104))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 30)

                        Text(book)
                            .font(Font.custom("LibreBaskerville-Regular", size: 24))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 30)
                            .padding(.top, 2)
                    }

                    Capsule()
                        .fill(Color.reforgedGold.opacity(0.8))
                        .frame(width: 40, height: 3)
                        .padding(.top, 14)

                    Spacer(minLength: 0)

                    // Footer: mark + wordmark, as on the verse card
                    HStack(spacing: 8) {
                        Image("ReforgedMark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                        Text("REFORGED")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(ink)
                    }
                    .padding(.bottom, 26)
                }

                // Copyright (bottom corner)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(attribution)
                            .font(.system(size: 7.5))
                            .foregroundStyle(ink.opacity(0.4))
                            .padding(.trailing, 24)
                            .padding(.bottom, 14)
                    }
                }
            }
            // Render at the 300 pt reference size, then scale to the actual container
            .frame(width: 300, height: 300)
            .scaleEffect(scale, anchor: .center)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .light)
        .accessibilityLabel(book.isEmpty ? "Audio Bible cover" : "\(book) chapter \(chapter), \(translationCode) audio cover")
    }
}

// MARK: - Lock Screen Artwork Renderer

/// Renders `AudioAlbumArtwork` to a UIImage for the lock screen / Control Center,
/// so KJV and ESV get the same custom cover there as in the in-app player.
@MainActor
enum AudioArtworkRenderer {
    private static var cache: [String: UIImage] = [:]

    static func image(translation: BibleTranslation, book: String, chapter: Int) -> UIImage? {
        let key = "\(translation.rawValue)|\(book)|\(chapter)"
        if let cached = cache[key] { return cached }

        let view = AudioAlbumArtwork(book: book, chapter: chapter, translation: translation)
            .frame(width: 600, height: 600)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage else { return nil }
        cache[key] = image
        return image
    }
}

// MARK: - Mini Player Bar

struct AudioMiniPlayerBar: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    let onTap: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Small artwork thumbnail
                AudioAlbumArtwork(book: audioPlayer.currentBook, chapter: audioPlayer.currentChapter, translation: audioPlayer.currentTranslation)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayer.currentBook.isEmpty ? "Audio Bible" : "\(audioPlayer.currentBook) \(audioPlayer.currentChapter)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(audioPlayer.currentTranslation == .kjv ? "KJV Audio Bible" : "ESV Audio Bible")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                // Play/Pause
                Button {
                    audioPlayer.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(width: 36, height: 36)
                }

                // Next chapter
                Button {
                    audioPlayer.playNextChapter()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(width: 36, height: 36)
                }

                // Close
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
                    // Progress tint strip at bottom
                    if audioPlayer.duration > 0 {
                        GeometryReader { geo in
                            Color.reforgedCoral
                                .frame(width: geo.size.width * CGFloat(audioPlayer.currentTime / audioPlayer.duration), height: 2)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
    }
}
