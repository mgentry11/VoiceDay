import Foundation
import AVFoundation

/// Service for recording voice samples and creating custom voice clones via ElevenLabs
@MainActor
class VoiceCloningService: NSObject, ObservableObject {
    static let shared = VoiceCloningService()

    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var recordings: [VoiceRecording] = []
    @Published var customVoiceId: String?
    @Published var customVoiceName: String?
    @Published var isProcessing = false
    @Published var error: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 30 // 30 seconds per sample

    // Suggested phrases for voice cloning (need variety for good clone)
    let suggestedPhrases = [
        "Hey, it's time to focus on your tasks. I know you can do this!",
        "Remember, you've got important things to accomplish today.",
        "I'm proud of you for staying on track. Keep up the great work!",
        "Don't forget about your tasks. Let's get them done together.",
        "You're doing amazing! Just a few more things to check off.",
        "Time to put down the phone and get back to work, okay?",
        "I believe in you. You've got this. Now let's be productive!",
        "Hey there! Your task list is waiting for you. Let's go!",
        "Remember what we talked about? Time to focus now.",
        "You're almost done! Just finish up these last few things."
    ]

    // MARK: - Custom Parent/Manager Phrases

    /// Custom phrases the parent/manager wants to use for reminders
    /// These get mixed in with The Gadfly's messages
    @Published var customPhrases: [CustomPhrase] = []

    struct CustomPhrase: Identifiable, Codable {
        let id: UUID
        var text: String
        var category: PhraseCategory
        var isActive: Bool

        enum PhraseCategory: String, Codable, CaseIterable {
            case nag = "Nag/Reminder"
            case celebration = "Celebration"
            case focus = "Focus Check-in"
            case motivation = "Motivation"
        }

        init(id: UUID = UUID(), text: String, category: PhraseCategory = .nag, isActive: Bool = true) {
            self.id = id
            self.text = text
            self.category = category
            self.isActive = isActive
        }
    }

    func addCustomPhrase(_ text: String, category: CustomPhrase.PhraseCategory) {
        let phrase = CustomPhrase(text: text, category: category)
        customPhrases.append(phrase)
        saveCustomPhrases()
    }

    func deleteCustomPhrase(_ id: UUID) {
        customPhrases.removeAll { $0.id == id }
        saveCustomPhrases()
    }

    func togglePhrase(_ id: UUID) {
        if let index = customPhrases.firstIndex(where: { $0.id == id }) {
            customPhrases[index].isActive.toggle()
            saveCustomPhrases()
        }
    }

    /// Get a random custom phrase for a category, or nil if none available
    func getRandomCustomPhrase(for category: CustomPhrase.PhraseCategory) -> String? {
        let active = customPhrases.filter { $0.category == category && $0.isActive }
        return active.randomElement()?.text
    }

    private func saveCustomPhrases() {
        if let data = try? JSONEncoder().encode(customPhrases) {
            UserDefaults.standard.set(data, forKey: "custom_phrases")
        }
    }

    private func loadCustomPhrases() {
        if let data = UserDefaults.standard.data(forKey: "custom_phrases"),
           let phrases = try? JSONDecoder().decode([CustomPhrase].self, from: data) {
            customPhrases = phrases
        }
    }

    override init() {
        super.init()
        loadSavedVoice()
        loadRecordings()
        loadCustomPhrases()
    }

    // MARK: - Recording

    func startRecording(phraseIndex: Int) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true)

        let url = getRecordingURL(for: phraseIndex)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        isRecording = true
        recordingProgress = 0

        // Progress timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingProgress += 0.1 / self.maxRecordingDuration
                if self.recordingProgress >= 1.0 {
                    self.stopRecording(phraseIndex: phraseIndex)
                }
            }
        }
    }

    func stopRecording(phraseIndex: Int) {
        audioRecorder?.stop()
        audioRecorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        // Save recording metadata
        let recording = VoiceRecording(
            id: UUID(),
            phraseIndex: phraseIndex,
            phrase: suggestedPhrases[phraseIndex],
            url: getRecordingURL(for: phraseIndex),
            duration: recordingProgress * maxRecordingDuration,
            recordedAt: Date()
        )

        if let existingIndex = recordings.firstIndex(where: { $0.phraseIndex == phraseIndex }) {
            recordings[existingIndex] = recording
        } else {
            recordings.append(recording)
        }

        saveRecordings()
    }

    func deleteRecording(at phraseIndex: Int) {
        let url = getRecordingURL(for: phraseIndex)
        try? FileManager.default.removeItem(at: url)
        recordings.removeAll { $0.phraseIndex == phraseIndex }
        saveRecordings()
    }

    func playRecording(at phraseIndex: Int) {
        let url = getRecordingURL(for: phraseIndex)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
        } catch {
            print("❌ Failed to play recording: \(error)")
        }
    }

    // MARK: - Voice Cloning

    /// Create a custom voice clone using ElevenLabs API
    func createVoiceClone(name: String, apiKey: String) async throws -> String {
        guard recordings.count >= 3 else {
            throw VoiceCloneError.notEnoughSamples
        }

        isProcessing = true
        defer { isProcessing = false }

        // Prepare multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/voices/add")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        var body = Data()

        // Add name
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)

        // Add description
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        body.append("Custom voice for The Gadfly - Gadfly App\r\n".data(using: .utf8)!)

        // Add each recording file
        for (index, recording) in recordings.enumerated() {
            if let audioData = try? Data(contentsOf: recording.url) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"files\"; filename=\"sample\(index).m4a\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
                body.append(audioData)
                body.append("\r\n".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloneError.networkError
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoiceCloneError.apiError(errorText)
        }

        // Parse response
        let result = try JSONDecoder().decode(VoiceCloneResponse.self, from: data)

        // Save the custom voice
        customVoiceId = result.voice_id
        customVoiceName = name
        saveVoice()

        return result.voice_id
    }

    /// Delete the custom voice from ElevenLabs
    func deleteVoiceClone(apiKey: String) async throws {
        guard let voiceId = customVoiceId else { return }

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/voices/\(voiceId)")!)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw VoiceCloneError.deleteFailed
        }

        customVoiceId = nil
        customVoiceName = nil
        saveVoice()
    }

    /// Clear local custom voice data without deleting from ElevenLabs
    /// Use this when user wants to switch to a different voice
    func clearCustomVoice() {
        print("🎤 Clearing custom voice locally")
        customVoiceId = nil
        customVoiceName = nil
        saveVoice()
    }

    // MARK: - Persistence

    private func getRecordingURL(for phraseIndex: Int) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("voice_sample_\(phraseIndex).m4a")
    }

    private func saveRecordings() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recordings) {
            UserDefaults.standard.set(data, forKey: "voice_recordings")
        }
    }

    private func loadRecordings() {
        guard let data = UserDefaults.standard.data(forKey: "voice_recordings"),
              let saved = try? JSONDecoder().decode([VoiceRecording].self, from: data) else {
            return
        }
        // Only keep recordings where file still exists
        recordings = saved.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    private func saveVoice() {
        UserDefaults.standard.set(customVoiceId, forKey: "custom_voice_id")
        UserDefaults.standard.set(customVoiceName, forKey: "custom_voice_name")
    }

    private func loadSavedVoice() {
        customVoiceId = UserDefaults.standard.string(forKey: "custom_voice_id")
        customVoiceName = UserDefaults.standard.string(forKey: "custom_voice_name")

        // Debug logging at startup
        if let id = customVoiceId {
            print("⚠️ STARTUP: Loaded custom voice ID: \(id)")
            print("⚠️ STARTUP: Custom voice name: \(customVoiceName ?? "nil")")
        } else {
            print("✅ STARTUP: No custom voice loaded")
        }

        let selectedId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""
        let selectedName = UserDefaults.standard.string(forKey: "selected_voice_name") ?? ""
        print("✅ STARTUP: Selected voice ID: \(selectedId.isEmpty ? "none" : selectedId)")
        print("✅ STARTUP: Selected voice name: \(selectedName.isEmpty ? "none" : selectedName)")
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceCloningService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
        }
    }
}

// MARK: - Models

struct VoiceRecording: Identifiable, Codable {
    let id: UUID
    let phraseIndex: Int
    let phrase: String
    let url: URL
    let duration: TimeInterval
    let recordedAt: Date
}

struct VoiceCloneResponse: Codable {
    let voice_id: String
}

enum VoiceCloneError: LocalizedError {
    case notEnoughSamples
    case networkError
    case apiError(String)
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notEnoughSamples:
            return "Please record at least 3 voice samples for best results"
        case .networkError:
            return "Network error - please check your connection"
        case .apiError(let message):
            return "API Error: \(message)"
        case .deleteFailed:
            return "Failed to delete voice clone"
        }
    }
}
