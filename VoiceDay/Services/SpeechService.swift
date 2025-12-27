import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let elevenLabsService = ElevenLabsService()

    // Speech queue to prevent overlapping speech
    private var speechQueue: [String] = []
    private var isProcessingQueue = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // Check if ElevenLabs is configured
    private var hasElevenLabsVoice: Bool {
        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        let selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""
        let customVoiceId = VoiceCloningService.shared.customVoiceId
        let hasVoice = !apiKey.isEmpty && (customVoiceId != nil || !selectedVoiceId.isEmpty)
        print("🎤 Voice check: apiKey=\(!apiKey.isEmpty), selectedVoiceId='\(selectedVoiceId)', customVoiceId=\(customVoiceId ?? "nil"), hasVoice=\(hasVoice)")
        return hasVoice
    }

    /// Ensure audio is routed to speaker before any speech
    private func ensureSpeakerOutput() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("❌ Failed to ensure speaker output: \(error)")
        }
    }

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopListening()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        transcribedText = ""
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    /// Speak text and wait for completion (async)
    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        stopListening()
        await speakImmediate(text)
    }

    /// Queue speech - doesn't block, speaks in order when available
    /// Use this from views to avoid blocking UI
    func queueSpeech(_ text: String) {
        guard !text.isEmpty else { return }

        speechQueue.append(text)
        processQueueIfNeeded()
    }

    private func processQueueIfNeeded() {
        guard !isProcessingQueue, !speechQueue.isEmpty else { return }

        isProcessingQueue = true
        stopListening()

        Task {
            while !speechQueue.isEmpty {
                let text = speechQueue.removeFirst()
                await speakImmediate(text)
            }
            isProcessingQueue = false
        }
    }

    /// Speak immediately (internal use)
    private func speakImmediate(_ text: String) async {
        isSpeaking = true

        // Force audio to speaker BEFORE any speech
        ensureSpeakerOutput()

        // Try ElevenLabs first if configured
        if hasElevenLabsVoice {
            let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
            let selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""

            do {
                try await elevenLabsService.speakWithBestVoice(text, apiKey: apiKey, selectedVoiceId: selectedVoiceId)
                isSpeaking = false
                return
            } catch {
                // Fall through to system voice on error
                print("ElevenLabs speech failed, falling back to system voice: \(error)")
            }
        }

        // Fallback to system voice - use US English (more universal)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5  // Slightly slower for ADHD clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        await withCheckedContinuation { continuation in
            self.speakingContinuation = continuation
            synthesizer.speak(utterance)
        }

        isSpeaking = false
    }

    /// Stop all speech and clear queue
    func stopSpeaking() {
        speechQueue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        isProcessingQueue = false
        isSpeaking = false
    }

    private var speakingContinuation: CheckedContinuation<Void, Never>?
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingContinuation?.resume()
            self.speakingContinuation = nil
        }
    }
}

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case requestCreationFailed
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .requestCreationFailed:
            return "Failed to create speech recognition request"
        case .notAuthorized:
            return "Speech recognition not authorized"
        }
    }
}
