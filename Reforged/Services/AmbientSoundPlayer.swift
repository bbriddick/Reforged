import AVFoundation
import SwiftUI

/// Ambient reading sounds (crown shop Reader Extras), synthesized live so the
/// app ships no audio files: rain = pink noise + soft droplets, Galilee shore =
/// brown noise swelling like waves, hearth = low rumble + crackles, chapel = a
/// quiet sustained chord. Plays only while the Bible reader is open.
@MainActor
final class AmbientSoundPlayer {
    static let shared = AmbientSoundPlayer()

    static let sounds = ["rain", "sea", "hearth", "chapel"]
    static func isSound(_ value: String) -> Bool { sounds.contains(value) }

    static func icon(for value: String) -> String {
        switch value {
        case "rain": return "cloud.rain.fill"
        case "sea": return "water.waves"
        case "hearth": return "flame.fill"
        case "chapel": return "building.columns.fill"
        default: return "speaker.wave.2.fill"
        }
    }

    /// Set by the reader so previews in the shop don't leave sound running elsewhere.
    var readerActive = false

    /// 0.05…1, remembered between sessions; adjustable from the reader's AA panel.
    var volume: Double = UserDefaults.standard.object(forKey: "ambient_volume") as? Double ?? 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "ambient_volume")
            engine.mainMixerNode.outputVolume = Float(volume)
        }
    }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let synth = AmbientSynth()
    private(set) var playing: String?

    private init() {}

    func play(_ kind: String) {
        guard Self.isSound(kind) else { return }
        if playing == kind, engine.isRunning { return }
        stop()
        let session = AVAudioSession.sharedInstance()
        // Don't take over a session the Bible audio player is using.
        if session.category != .playback {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
        }
        try? session.setActive(true)

        synth.configure(kind: kind, sampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: synth.sampleRate, channels: 1)!
        let synth = self.synth
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            for frame in 0..<Int(frameCount) { data[frame] = synth.next() }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = Float(volume)
        do {
            try engine.start()
            source = node
            playing = kind
        } catch {
            engine.detach(node)
        }
    }

    func stop() {
        if let source {
            engine.stop()
            engine.detach(source)
        }
        source = nil
        playing = nil
    }

    /// Plays the equipped ambient sound while the reader is open; silence otherwise.
    func syncWithEquipped() {
        let equipped = Self.sounds.first { AppState.shared.isReaderExtraOn("reader.\($0)") }
        if readerActive, let equipped { play(equipped) } else { stop() }
    }
}

/// The DSP. Runs on the audio render thread; its state is only touched there
/// after `configure`, which happens before the node starts.
private final class AmbientSynth: @unchecked Sendable {
    var sampleRate: Double = 44_100
    private var kind = "rain"
    private var t: Double = 0
    private var gain: Float = 0          // fade-in
    // Pink noise (Paul Kellet) and brown noise state
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var brown: Float = 0
    // Droplets / crackles
    private var click: Float = 0
    private var clickDecay: Float = 0.99
    private var phases: [Double] = [0, 0, 0, 0]

    func configure(kind: String, sampleRate: Double) {
        self.kind = kind
        self.sampleRate = sampleRate > 0 ? sampleRate : 44_100
        t = 0; gain = 0; click = 0
    }

    private func white() -> Float { Float.random(in: -1...1) }

    private func pink() -> Float {
        let w = white()
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
        b6 = w * 0.115926
        return out * 0.11
    }

    private func brownNoise() -> Float {
        brown = (brown + 0.02 * white()) / 1.02
        return brown * 3.5
    }

    func next() -> Float {
        t += 1 / sampleRate
        if gain < 1 { gain = min(1, gain + Float(1 / (sampleRate * 2.5))) }  // 2.5 s fade-in
        var s: Float
        switch kind {
        case "sea":
            let swell = Float(0.35 + 0.65 * pow(sin(Double.pi * t / 7.5), 2))
            s = brownNoise() * 0.45 * swell + pink() * 0.05 * swell
        case "hearth":
            if Float.random(in: 0...1) < 0.0005 {
                click = Float.random(in: 0.2...0.6) * (Bool.random() ? 1 : -1)
                clickDecay = Float.random(in: 0.93...0.975)
            }
            click *= clickDecay
            s = brownNoise() * 0.28 + click * white() * 0.9
        case "chapel":
            let freqs = [110.0, 164.81, 220.0, 277.18]
            var chord: Double = 0
            for i in 0..<freqs.count {
                phases[i] += 2 * Double.pi * freqs[i] * (1 + 0.0007 * sin(t * 0.3 + Double(i))) / sampleRate
                if phases[i] > 2 * Double.pi { phases[i] -= 2 * Double.pi }
                chord += sin(phases[i]) * (0.5 + 0.5 * sin(t * 0.21 + Double(i) * 1.7))
            }
            s = Float(chord * 0.035) + pink() * 0.015
        default: // rain
            if Float.random(in: 0...1) < 0.002 {
                click = Float.random(in: 0.05...0.18)
                clickDecay = 0.96
            }
            click *= clickDecay
            s = pink() * 0.32 + click * white()
        }
        return max(-1, min(1, s * gain))
    }
}
