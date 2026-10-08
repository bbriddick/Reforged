import SwiftUI

/// "Say It Back" recitation workout: users speak the verse into the mic,
/// and words light up in rich gold/green as they are verified by speech recognition.
struct SayItBackView: View {
    let verse: MemoryVerse
    let onComplete: (Int) -> Void

    @StateObject private var speechService = SpeechRecognitionService.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var verseWords: [String] = []
    @State private var wordStates: [SpokenWordState] = []
    @State private var matchedWordCount: Int = 0
    @State private var isFinished: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var fallbackSelfGrade: Bool = false
    @State private var isMicPressed: Bool = false

    var progressPercent: Int {
        guard !verseWords.isEmpty else { return 0 }
        return Int((Double(matchedWordCount) / Double(verseWords.count)) * 100)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header instruction
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.title3)
                        .foregroundStyle(Color.reforgedGold)
                    Text("Say It Back")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                Text("Speak the verse aloud. Watch each word glow as you recite.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 12)

            // Dynamic recitation display card
            ScrollView {
                VStack(spacing: 16) {
                    Text(verse.reference)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    // Flow of word tokens with real-time speech highlight
                    FlowLayout(spacing: 8) {
                        ForEach(verseWords.indices, id: \.self) { index in
                            wordPill(word: verseWords[index], state: wordStates.indices.contains(index) ? wordStates[index] : .pending)
                        }
                    }
                    .padding(20)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, y: 6)
                }
                .padding(.horizontal)
            }

            // Live progress & waveform meter
            VStack(spacing: 12) {
                HStack {
                    Text("Spoken: \(progressPercent)%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Spacer()

                    if speechService.isListening {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Listening...")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.green)
                        }
                    }
                }
                .padding(.horizontal, 28)

                // 3D Microphone & Recitation Controls
                if !isFinished {
                    HStack(spacing: 20) {
                        // "Can't speak now" fallback button
                        Button {
                            speechService.stopListening()
                            fallbackSelfGrade = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "mic.slash.fill")
                                    .font(.system(size: 16))
                                Text("Can't Speak")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        // Primary hold-to-recite mic button: press and hold to
                        // record — the button itself turns coral while held, release
                        // to stop. No ring; the color IS the recording state.
                        VStack(spacing: 8) {
                            ZStack {
                                // The darker base stays put while the face travels
                                // down onto it, giving the hold gesture real depth.
                                Circle()
                                    .fill((isMicPressed ? Color.reforgedCoral : Color.reforgedGold).opacity(0.62))
                                    .frame(width: 76, height: 76)
                                    .offset(y: 7)

                                Circle()
                                    .fill(isMicPressed ? Color.reforgedCoral : Color.reforgedGold)
                                    .frame(width: 76, height: 76)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                    }
                                    .offset(y: isMicPressed ? 7 : 0)
                                    .shadow(
                                        color: (isMicPressed ? Color.reforgedCoral : Color.reforgedGold)
                                            .opacity(isMicPressed ? 0.18 : 0.38),
                                        radius: isMicPressed ? 3 : 10,
                                        y: isMicPressed ? 2 : 7
                                    )

                                Image(systemName: "mic.fill")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .offset(y: isMicPressed ? 7 : 0)
                            }
                            .frame(width: 76, height: 83, alignment: .top)
                            .scaleEffect(isMicPressed ? 0.97 : 1)
                            .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isMicPressed)
                            .contentShape(Circle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isMicPressed {
                                            isMicPressed = true
                                            HapticManager.shared.buttonTap()
                                            speechService.startListening { transcription in
                                                processSpokenText(transcription)
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        isMicPressed = false
                                        speechService.stopListening()
                                        HapticManager.shared.buttonTap()
                                    }
                            )

                            Text(isMicPressed ? "Listening…" : "Hold to speak")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isMicPressed ? Color.reforgedCoral
                                    : Color.adaptiveTextSecondary(colorScheme))
                        }

                        // Restart recitation
                        Button {
                            HapticManager.shared.buttonTap()
                            resetRecitation()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16))
                                Text("Restart")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Success Continue CTA
                    Button {
                        HapticManager.shared.masteryStampSeal()
                        onComplete(5)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Recitation Verified!")
                        }
                    }
                    .buttonStyle(Chunky3DButtonStyle(
                        backgroundColor: Color(red: 0.15, green: 0.65, blue: 0.35),
                        bevelColor: Color(red: 0.1, green: 0.5, blue: 0.25)
                    ))
                    .padding(.horizontal, 24)
                }

                // Fallback manual pass prompt if user used "Can't speak now"
                if fallbackSelfGrade && !isFinished {
                    HStack(spacing: 12) {
                        Button("Still Learning") {
                            onComplete(2)
                        }
                        .buttonStyle(Chunky3DButtonStyle(
                            backgroundColor: Color.orange,
                            bevelColor: Color.orange.opacity(0.7)
                        ))

                        Button("I Know It!") {
                            HapticManager.shared.lessonStageComplete()
                            onComplete(4)
                        }
                        .buttonStyle(Chunky3DButtonStyle(
                            backgroundColor: Color(red: 0.15, green: 0.65, blue: 0.35),
                            bevelColor: Color(red: 0.1, green: 0.5, blue: 0.25)
                        ))
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            setupWords()
            // Request permissions on first visit
            speechService.requestAuthorization { granted in
                if !granted {
                    showPermissionAlert = true
                }
            }
        }
        .onDisappear {
            isMicPressed = false
            speechService.stopListening()
        }
        .alert("Microphone & Speech Access", isPresented: $showPermissionAlert) {
            Button("Use Manual Mode", role: .cancel) {
                fallbackSelfGrade = true
            }
        } message: {
            Text("Reforged needs microphone and speech access to verify your recitation. You can also recite quietly and tap 'I Know It'.")
        }
    }

    private func setupWords() {
        verseWords = verse.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        wordStates = Array(repeating: .pending, count: verseWords.count)
    }

    private func resetRecitation() {
        speechService.stopListening()
        wordStates = Array(repeating: .pending, count: verseWords.count)
        matchedWordCount = 0
        isFinished = false
    }

    private func processSpokenText(_ transcription: String) {
        let (evaluatedStates, matched, complete) = SpeechRecognitionService.evaluateRecitation(
            targetWords: verseWords,
            spokenText: transcription
        )

        // Haptic feedback on new matches
        if matched > matchedWordCount {
            HapticManager.shared.speechWordMatched()
        }

        withAnimation(.easeOut(duration: 0.18)) {
            self.wordStates = evaluatedStates
            self.matchedWordCount = matched
        }

        if complete && !isFinished {
            self.isFinished = true
            speechService.stopListening()
            HapticManager.shared.lessonStageComplete()
        }
    }

    // MARK: - Word Token View
    @ViewBuilder
    private func wordPill(word: String, state: SpokenWordState) -> some View {
        Text(word)
            .font(.system(size: 18, weight: state == .spoken ? .bold : .regular))
            .foregroundStyle(textColor(for: state))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(backgroundColor(for: state))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(state == .spoken ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state)
    }

    private func textColor(for state: SpokenWordState) -> Color {
        switch state {
        case .spoken:
            return .white
        case .active:
            return Color.reforgedGold
        case .pending:
            return Color.adaptiveText(colorScheme).opacity(0.55)
        }
    }

    private func backgroundColor(for state: SpokenWordState) -> Color {
        switch state {
        case .spoken:
            return Color(red: 0.15, green: 0.65, blue: 0.35)
        case .active:
            return Color.reforgedGold.opacity(0.18)
        case .pending:
            return Color.clear
        }
    }
}
