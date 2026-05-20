import AVFoundation
import SwiftUI

// MARK: - TTS Voice Service

class TTSVoiceService: ObservableObject {
    static let shared = TTSVoiceService()

    private let voiceKey = "tts_voice_id"

    @Published var selectedVoiceIdentifier: String? {
        didSet { UserDefaults.standard.set(selectedVoiceIdentifier, forKey: voiceKey) }
    }

    private init() {
        selectedVoiceIdentifier = UserDefaults.standard.string(forKey: voiceKey)
        autoSelectBestVoice()
    }

    // All English voices, sorted premium → enhanced → default.
    // Excludes legacy novelty voices (Albert, Bahh, Bells, etc.) which use the
    // com.apple.speech.synthesis.voice.* identifier and are not suitable for reading.
    func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter {
                $0.language.hasPrefix("en") &&
                !$0.identifier.hasPrefix("com.apple.speech.synthesis.voice")
            }
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let voices = availableEnglishVoices()
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
    }

    func autoSelectBestVoice() {
        guard selectedVoiceIdentifier == nil else { return }
        if let best = bestAvailableVoice() {
            selectedVoiceIdentifier = best.identifier
        }
    }

    func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Standard"
        }
    }

    func qualityColor(_ voice: AVSpeechSynthesisVoice) -> Color {
        switch voice.quality {
        case .premium:  return .reforgedGold
        case .enhanced: return Color(red: 0.2, green: 0.6, blue: 1.0)
        default:        return .secondary
        }
    }

    func makeUtterance(text: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        if let id = selectedVoiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: id)
        } else {
            utterance.voice = bestAvailableVoice()
        }
        utterance.rate = min(AVSpeechUtteranceDefaultSpeechRate * rate,
                             AVSpeechUtteranceMaximumSpeechRate)
        return utterance
    }

    var hasEnhancedVoices: Bool {
        availableEnglishVoices().contains { $0.quality == .enhanced || $0.quality == .premium }
    }
}

// MARK: - Shared Voice Picker View

struct TTSVoicePickerView: View {
    @Binding var selectedIdentifier: String?
    @Environment(\.colorScheme) var colorScheme
    private let service = TTSVoiceService.shared
    private let voices: [AVSpeechSynthesisVoice]

    init(selectedIdentifier: Binding<String?>) {
        self._selectedIdentifier = selectedIdentifier
        self.voices = TTSVoiceService.shared.availableEnglishVoices()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !service.hasEnhancedVoices {
                downloadTip
            }

            // Voice pills in a wrapped layout
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(voices, id: \.identifier) { voice in
                    voicePill(voice)
                }
            }
        }
    }

    private func voicePill(_ voice: AVSpeechSynthesisVoice) -> some View {
        let selected = selectedIdentifier == voice.identifier
        return Button { selectedIdentifier = voice.identifier } label: {
            VStack(spacing: 3) {
                Text(voice.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(selected ? .white : Color.adaptiveText(colorScheme))
                    .lineLimit(1)

                Text(service.qualityLabel(voice))
                    .font(.system(size: 10)).fontWeight(.medium)
                    .foregroundStyle(selected ? .white.opacity(0.75) : service.qualityColor(voice))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.reforgedNavy : Color.adaptiveBorder(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var downloadTip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.reforgedGold)
                Text("Better voices available")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            Text("Download Enhanced or Premium voices for a much more natural sound.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open iOS Settings → Accessibility → Spoken Content → Voices")
                    .font(.caption)
                    .foregroundStyle(Color.reforgedNavy)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reforgedGold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1))
    }
}
