import Foundation
import Speech
import AVFoundation

/// Word match status for live visual feedback in "Say It Back" mode
enum SpokenWordState: Equatable {
    case pending
    case spoken
    case active
}

/// Service managing microphone capture and real-time speech recognition for Scripture recitation
final class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var permissionGranted: Bool = false
    @Published var errorMessage: String? = nil
    @Published var audioLevel: Float = 0.0

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Request user authorization for Speech Recognition and Microphone
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                        DispatchQueue.main.async {
                            self.permissionGranted = micGranted
                            completion(micGranted)
                        }
                    }
                default:
                    self.permissionGranted = false
                    completion(false)
                }
            }
        }
    }

    /// Start listening and transcribing spoken audio in real-time
    func startListening(onTranscription: @escaping (String) -> Void) {
        guard !audioEngine.isRunning else { return }

        // Reset previous tasks
        stopListening()
        errorMessage = nil
        recognizedText = ""

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            if speechRecognizer?.supportsOnDeviceRecognition == true {
                recognitionRequest.requiresOnDeviceRecognition = false
            }
        }

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = transcription
                    onTranscription(transcription)
                }
            }

            if error != nil || (result?.isFinal == true) {
                self.stopListening()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate rough audio level for waveform animation
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            var sum: Float = 0
            for sample in channelDataArray {
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            let level = min(max(rms * 10, 0), 1)
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            stopListening()
        }
    }

    /// Stop speech recognition engine cleanly
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.isListening = false
            self.audioLevel = 0.0
        }
    }

    // MARK: - Verse Comparison Engine

    /// Clean strings by removing punctuation and converting to lowercase
    static func normalize(_ string: String) -> String {
        string.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined()
    }

    /// Compare spoken transcription with target verse words and return match states
    static func evaluateRecitation(targetWords: [String], spokenText: String) -> (states: [SpokenWordState], matchedCount: Int, isComplete: Bool) {
        let spokenWords = spokenText
            .components(separatedBy: .whitespacesAndNewlines)
            .map { normalize($0) }
            .filter { !$0.isEmpty }

        var states: [SpokenWordState] = Array(repeating: .pending, count: targetWords.count)
        var spokenIndex = 0
        var matchedCount = 0

        for i in 0..<targetWords.count {
            let targetWord = normalize(targetWords[i])
            guard !targetWord.isEmpty else { continue }

            var foundMatch = false
            // Look ahead up to 3 words in spoken stream to account for minor speech recognizer slips
            let lookAheadLimit = min(spokenIndex + 3, spokenWords.count)
            for s in spokenIndex..<lookAheadLimit {
                let spoken = spokenWords[s]
                if spoken == targetWord || isCloseFuzzyMatch(spoken, targetWord) {
                    states[i] = .spoken
                    spokenIndex = s + 1
                    matchedCount += 1
                    foundMatch = true
                    break
                }
            }

            if !foundMatch {
                states[i] = (i == matchedCount) ? .active : .pending
            }
        }

        let isComplete = matchedCount >= Int(Double(targetWords.count) * 0.85)
        return (states, matchedCount, isComplete)
    }

    private static func isCloseFuzzyMatch(_ s1: String, _ s2: String) -> Bool {
        if s1 == s2 { return true }
        // Simple Levenshtein distance check for small typos/homophones
        let d = levenshtein(s1, s2)
        return d <= 1 && max(s1.count, s2.count) > 3
    }

    private static func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(dist[i - 1][j] + 1, dist[i][j - 1] + 1, dist[i - 1][j - 1] + 1)
                }
            }
        }
        return dist[a.count][b.count]
    }
}
