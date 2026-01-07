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

    // Check if ElevenLabs is configured - use if API key exists (will use default Rachel if no selection)
    private var hasElevenLabsKey: Bool {
        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        let hasKey = !apiKey.isEmpty
        print("🎤 ElevenLabs check: hasApiKey=\(hasKey)")
        return hasKey
    }

    /// Ensure audio is routed correctly - use earbuds if connected, otherwise speaker
    private func ensureSpeakerOutput() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Only force speaker if no external audio device connected
            let currentRoute = audioSession.currentRoute
            let hasExternalOutput = currentRoute.outputs.contains {
                $0.portType == .bluetoothA2DP ||
                $0.portType == .bluetoothHFP ||
                $0.portType == .headphones ||
                $0.portType == .bluetoothLE
            }
            if !hasExternalOutput {
                try audioSession.overrideOutputAudioPort(.speaker)
                print("🔊 SpeechService: Audio routed to SPEAKER")
            } else {
                print("🎧 SpeechService: Audio routed to EARBUDS")
            }
        } catch {
            print("❌ Failed to configure audio: \(error)")
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
        // FORCE speaker output - never use earpiece
        try audioSession.overrideOutputAudioPort(.speaker)

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

                // Only stop on actual errors, NOT when isFinal is true
                // This allows continuous recording until user presses stop
                if let error = error {
                    print("❌ Speech recognition error: \(error.localizedDescription)")
                    // Only stop for real errors, not end-of-speech detection
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 1110 {
                        self.stopListening()
                    }
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

        // Reconfigure audio session for speech output after listening stops
        reconfigureAudioForPlayback()
    }

    private func reconfigureAudioForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let currentRoute = audioSession.currentRoute
            let hasExternalOutput = currentRoute.outputs.contains {
                $0.portType == .bluetoothA2DP ||
                $0.portType == .bluetoothHFP ||
                $0.portType == .headphones ||
                $0.portType == .bluetoothLE
            }
            if !hasExternalOutput {
                try audioSession.overrideOutputAudioPort(.speaker)
                print("🔊 SpeechService: Audio reconfigured for SPEAKER")
            } else {
                print("🎧 SpeechService: Audio reconfigured for EARBUDS")
            }
        } catch {
            print("❌ Failed to reconfigure audio: \(error)")
        }
    }
    
    func prepareForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.overrideOutputAudioPort(.speaker)
            print("🎤 SpeechService: Audio prepared for RECORDING")
        } catch {
            print("❌ Failed to prepare audio for recording: \(error)")
        }
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

    /// Speak immediately (internal use) - ONLY uses ElevenLabs, NO system voice
    private func speakImmediate(_ text: String) async {
        isSpeaking = true
        defer { isSpeaking = false }

        // Force audio to speaker BEFORE any speech
        ensureSpeakerOutput()

        // ALWAYS use ElevenLabs - NEVER fall back to system voice (that's the "Syn" voice!)
        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        let selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""

        print("🎤🎤🎤 SpeechService.speakImmediate")
        print("🎤🎤🎤 API Key: \(apiKey.prefix(10))...")
        print("🎤🎤🎤 Selected Voice: \(selectedVoiceId.isEmpty ? "NONE - using Rachel" : selectedVoiceId)")

        if apiKey.isEmpty {
            print("❌❌❌ NO API KEY - Cannot speak!")
            return
        }

        do {
            try await elevenLabsService.speakWithBestVoice(text, apiKey: apiKey, selectedVoiceId: selectedVoiceId)
            print("🎤🎤🎤 SpeechService: Speech complete!")
        } catch {
            print("❌❌❌ ElevenLabs FAILED: \(error)")
            print("❌❌❌ NOT falling back to system voice!")
            // DO NOT fall back to system voice - that's the "Syn" voice!
        }
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
