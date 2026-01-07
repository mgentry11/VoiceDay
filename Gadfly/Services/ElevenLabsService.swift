import Foundation
import AVFoundation

@MainActor
class ElevenLabsService: NSObject, ObservableObject {
    @Published var isSpeaking = false
    @Published var availableVoices: [Voice] = []

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    struct Voice: Identifiable, Codable {
        let voice_id: String
        let name: String
        let labels: Labels?

        var id: String { voice_id }

        struct Labels: Codable {
            let accent: String?
            let description: String?
            let age: String?
            let gender: String?
        }
    }

    struct VoicesResponse: Codable {
        let voices: [Voice]
    }

    func fetchVoices(apiKey: String) async throws -> [Voice] {
        let url = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse(statusCode: 0, message: "No HTTP response")
        }

        if httpResponse.statusCode != 200 {
            // Parse error for better messaging
            if httpResponse.statusCode == 401 {
                if let errorData = try? JSONDecoder().decode(ElevenLabsAPIError.self, from: data) {
                    if errorData.detail?.status == "missing_permissions" ||
                       errorData.error?.code == "missing_permissions" {
                        throw ElevenLabsError.missingPermissions(permission: "voice.read")
                    }
                }
                throw ElevenLabsError.invalidAPIKey
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.invalidResponse(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
            availableVoices = voicesResponse.voices
            return voicesResponse.voices
        } catch {
            throw ElevenLabsError.decodingFailed(message: error.localizedDescription)
        }
    }

    // Default Rachel voice ID - ALWAYS use this if no voice selected
    static let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM"

    /// Speak using selected voice or default Rachel - NEVER use custom voice or system voice
    func speakWithBestVoice(_ text: String, apiKey: String, selectedVoiceId: String) async throws {
        // ALWAYS use Rachel if no selection - never fall back to anything else
        let voiceId = selectedVoiceId.isEmpty ? Self.defaultVoiceId : selectedVoiceId
        print("🎤🎤🎤 speakWithBestVoice - using voiceId: \(voiceId)")
        try await speak(text, apiKey: apiKey, voiceId: voiceId)
    }

    func speak(_ text: String, apiKey: String, voiceId: String) async throws {
        guard !text.isEmpty else { return }

        print("🔊🔊🔊 ElevenLabsService.speak() CALLED")
        print("🔊🔊🔊 voiceId parameter: '\(voiceId)'")
        print("🔊🔊🔊 text: '\(text.prefix(50))...'")

        isSpeaking = true
        defer { isSpeaking = false }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        print("🔊🔊🔊 API URL: \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.speechGenerationFailed(statusCode: 0, message: "No response")
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.speechGenerationFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        try await playAudio(data: data)
    }

    private func playAudio(data: Data) async throws {
        // Stop any currently playing audio first
        audioPlayer?.stop()
        audioPlayer = nil

        let audioSession = AVAudioSession.sharedInstance()
        // Use playAndRecord with allowBluetooth for earbuds, defaultToSpeaker as fallback
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Only force speaker if no external audio device (earbuds/headphones) connected
        let currentRoute = audioSession.currentRoute
        let hasExternalOutput = currentRoute.outputs.contains {
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothHFP ||
            $0.portType == .headphones ||
            $0.portType == .bluetoothLE
        }
        if !hasExternalOutput {
            try audioSession.overrideOutputAudioPort(.speaker)
            print("🔊 ElevenLabs: Audio routed to SPEAKER (no earbuds)")
        } else {
            print("🎧 ElevenLabs: Audio routed to EARBUDS/HEADPHONES")
        }

        audioPlayer = try AVAudioPlayer(data: data)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playbackContinuation = continuation
            audioPlayer?.delegate = self
            audioPlayer?.play()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
}

extension ElevenLabsService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }
}

enum ElevenLabsError: LocalizedError {
    case invalidResponse(statusCode: Int, message: String)
    case speechGenerationFailed(statusCode: Int, message: String)
    case decodingFailed(message: String)
    case noVoiceSelected
    case invalidAPIKey
    case missingPermissions(permission: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let code, let message):
            return "API Error (\(code)): \(message)"
        case .speechGenerationFailed(let code, let message):
            return "Speech Error (\(code)): \(message)"
        case .decodingFailed(let message):
            return "Parse Error: \(message)"
        case .noVoiceSelected:
            return "No voice selected"
        case .invalidAPIKey:
            return "Invalid API key. Please check your ElevenLabs API key in Settings."
        case .missingPermissions(let permission):
            return "API key missing '\(permission)' permission. Please create a new API key with full permissions at elevenlabs.io"
        }
    }
}

// API error response structure
private struct ElevenLabsAPIError: Decodable {
    let detail: Detail?
    let error: ErrorDetail?

    struct Detail: Decodable {
        let status: String?
        let message: String?
    }

    struct ErrorDetail: Decodable {
        let code: String?
        let message: String?
    }
}

// Recommended British voices from ElevenLabs library:
// - "Daniel" - British male, authoritative
// - "Charlotte" - British female, professional
// - "George" - British male, warm
// - "Lily" - British female
// Or clone your own voice for the posh sarcastic personality!

// NOTE: VoiceCloningService is in its own file: VoiceCloningService.swift
