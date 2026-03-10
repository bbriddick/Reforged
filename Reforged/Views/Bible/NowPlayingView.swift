import SwiftUI
import AVFoundation

// MARK: - Now Playing View (Apple Music style full-screen player)

struct NowPlayingView: View {
    @ObservedObject var audioPlayer: BibleAudioPlayer
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    var displayBook: String { audioPlayer.currentBook.isEmpty ? "" : audioPlayer.currentBook }
    var displayChapter: Int { audioPlayer.currentChapter }

    var body: some View {
        GeometryReader { geo in
            let isWide = horizontalSizeClass == .regular
            let isLandscape = !isWide && geo.size.width > geo.size.height

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.22),
                        Color(red: 0.04, green: 0.06, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLandscape {
                    landscapeBody(geo: geo)
                } else {
                    portraitBody(geo: geo, isWide: isWide)
                }
            }
        }
        .onAppear { scrubPosition = audioPlayer.currentTime }
    }

    // MARK: - Portrait / iPad layout (existing vertical stack)

    @ViewBuilder
    private func portraitBody(geo: GeometryProxy, isWide: Bool) -> some View {
        let maxContent: CGFloat = isWide ? min(geo.size.width * 0.65, 520) : geo.size.width
        let artSize: CGFloat = isWide ? min(maxContent - 80, 380) : geo.size.width - 72
        let hPad: CGFloat = isWide ? 40 : 32

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Handle / dismiss bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("NOW PLAYING")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.5)
                        Text("ESV Audio Bible")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: isWide ? 28 : 20)

                AudioAlbumArtwork(book: displayBook, chapter: displayChapter)
                    .frame(width: artSize, height: artSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.5), radius: 30, y: 12)
                    .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: audioPlayer.isPlaying)

                Spacer(minLength: isWide ? 28 : 24)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayBook.isEmpty ? "—" : "\(displayBook) \(displayChapter)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("ESV Audio Bible")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, hPad)

                Spacer(minLength: 20)

                scrubberView(hPad: hPad)

                Spacer(minLength: isWide ? 28 : 24)

                controlsRow(isWide: isWide)

                Spacer(minLength: 28)

                HStack(alignment: .center) {
                    speedButton()
                    Spacer()
                    SleepTimerButtonView(audioPlayer: audioPlayer).equatable()
                }
                .padding(.horizontal, hPad)

                Spacer(minLength: isWide ? 48 : 40)
            }
            .frame(width: maxContent)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Landscape iPhone layout (top: artwork+info, bottom: full-width controls)

    @ViewBuilder
    private func landscapeBody(geo: GeometryProxy) -> some View {
        // Reserve space for controls + speed/sleep + gaps at the bottom
        let bottomSectionHeight: CGFloat = 80 + 38 + 36   // controls row + speed/sleep + padding
        let topSectionHeight: CGFloat = geo.size.height - bottomSectionHeight
        // Artwork is square, sized to fit the top section height
        let artSize: CGFloat = max(80, topSectionHeight - 16)
        let hPad: CGFloat = 24

        VStack(spacing: 0) {
            // Top section: artwork (left) + title/scrubber (right)
            HStack(alignment: .center, spacing: 0) {
                // Left: dismiss button overlaid above artwork
                ZStack(alignment: .topLeading) {
                    AudioAlbumArtwork(book: displayBook, chapter: displayChapter)
                        .frame(width: artSize, height: artSize)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.45), radius: 16, y: 6)
                        .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.92)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: audioPlayer.isPlaying)

                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
                .frame(width: artSize)
                .padding(.leading, hPad)

                // Right: title + scrubber
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayBook.isEmpty ? "—" : "\(displayBook) \(displayChapter)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("ESV Audio Bible")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, hPad)
                    Spacer(minLength: 12)
                    scrubberView(hPad: hPad)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: topSectionHeight)

            // Full-width controls row
            controlsRow(isWide: false)
                .padding(.bottom, 8)

            // Full-width speed + sleep timer
            HStack(alignment: .center) {
                speedButton()
                Spacer()
                SleepTimerButtonView(audioPlayer: audioPlayer).equatable()
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func scrubberView(hPad: CGFloat) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: scrubFraction(geo.size.width), height: 4)
                }
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
            .frame(height: 20)
            .padding(.horizontal, hPad)

            HStack {
                Text(formatTime(isScrubbing ? scrubPosition : audioPlayer.currentTime))
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("-\(formatTime(audioPlayer.duration - (isScrubbing ? scrubPosition : audioPlayer.currentTime)))")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, hPad)
        }
        .onChange(of: audioPlayer.currentTime) { newTime in
            if !isScrubbing { scrubPosition = newTime }
        }
    }

    @ViewBuilder
    private func controlsRow(isWide: Bool) -> some View {
        let btnSpacing: CGFloat = isWide ? 56 : 0
        HStack(spacing: btnSpacing) {
            if !isWide { Spacer() }

            Button { audioPlayer.playPreviousChapter() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            if !isWide { Spacer() }

            Button { audioPlayer.skipBackward(15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            if !isWide { Spacer() }

            // Play / Pause
            Button {
                if audioPlayer.isPlaying || audioPlayer.currentTime > 0 {
                    audioPlayer.togglePlayPause()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                    if audioPlayer.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.08, green: 0.12, blue: 0.22)))
                    } else {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.22))
                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                    }
                }
            }

            if !isWide { Spacer() }

            Button { audioPlayer.skipForward(15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            if !isWide { Spacer() }

            Button { audioPlayer.playNextChapter() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            if !isWide { Spacer() }
        }
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
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 13))
                Text(rateLabel(audioPlayer.playbackRate))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.white.opacity(0.55))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
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
        case 0.75: return "¾×"
        case 1.0:  return "1×"
        case 1.25: return "1.25×"
        case 1.5:  return "1.5×"
        case 2.0:  return "2×"
        default:   return String(format: "%.2g×", rate)
        }
    }
}

// MARK: - Sleep Timer Button (equatable to avoid re-rendering on every currentTime tick)

struct SleepTimerButtonView: View, Equatable {
    @ObservedObject var audioPlayer: BibleAudioPlayer

    static func == (lhs: SleepTimerButtonView, rhs: SleepTimerButtonView) -> Bool {
        lhs.audioPlayer.sleepTimerRemaining == rhs.audioPlayer.sleepTimerRemaining &&
        lhs.audioPlayer.sleepTimerEndOfChapter == rhs.audioPlayer.sleepTimerEndOfChapter
    }

    var body: some View {
        if audioPlayer.sleepTimerRemaining > 0 || audioPlayer.sleepTimerEndOfChapter {
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.reforgedGold)
                Text(audioPlayer.sleepTimerEndOfChapter
                     ? "End of chapter"
                     : sleepTimerLabel(audioPlayer.sleepTimerRemaining))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .monospacedDigit()
                Button {
                    audioPlayer.cancelSleepTimer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
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
                HStack(spacing: 5) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 13))
                    Text("Sleep")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func sleepTimerLabel(_ remaining: TimeInterval) -> String {
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : String(format: "0:%02d", secs)
    }
}

// MARK: - Album Artwork

struct AudioAlbumArtwork: View {
    let book: String
    let chapter: Int

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 300

            ZStack {
                // Base gradient — deep navy to slightly lighter
                LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.30),
                    Color(red: 0.06, green: 0.09, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle texture rings
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.white.opacity(0.04 - Double(i) * 0.008), lineWidth: 1)
                    .scaleEffect(0.5 + Double(i) * 0.18)
            }

            // Cross / ornament
            VStack(spacing: 0) {
                Spacer()
                // Cross shape
                ZStack {
                    // Vertical beam
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.87, green: 0.72, blue: 0.42), Color(red: 0.75, green: 0.58, blue: 0.28)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: 80)

                    // Horizontal beam
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.87, green: 0.72, blue: 0.42), Color(red: 0.75, green: 0.58, blue: 0.28)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 52, height: 8)
                        .offset(y: -14)
                }
                .shadow(color: Color(red: 0.87, green: 0.72, blue: 0.42).opacity(0.4), radius: 16)

                Spacer()
            }
            .padding(.bottom, 16)

            // Branding text overlay
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 3) {
                    Text("REFORGED")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .tracking(4)
                        .foregroundStyle(Color(red: 0.87, green: 0.72, blue: 0.42))

                    Text("ESV Audio Bible")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.5))

                    if !book.isEmpty {
                        Text("\(book) \(chapter)")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.top, 6)
                    }
                }
                .padding(.bottom, 20)
            }

            // Crossway copyright (bottom corner)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("© 2001 Crossway")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .padding(.trailing, 12)
                        .padding(.bottom, 8)
                }
            }
        }
        // Render at reference size, then scale to fit the actual container
        .frame(width: 300, height: 300)
        .scaleEffect(scale, anchor: .center)
        .frame(width: geo.size.width, height: geo.size.height)
        }
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
                AudioAlbumArtwork(book: audioPlayer.currentBook, chapter: audioPlayer.currentChapter)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayer.currentBook.isEmpty ? "ESV Audio" : "\(audioPlayer.currentBook) \(audioPlayer.currentChapter)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text("ESV Audio Bible")
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
                            LinearGradient(
                                colors: [Color.reforgedNavy.opacity(0.12), Color.reforgedGold.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
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
