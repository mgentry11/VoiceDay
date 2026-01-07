import SwiftUI
import AVFoundation

struct VoiceRecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var voiceService = VoiceCloningService.shared
    @State private var currentPhraseIndex = 0
    @State private var showingCloneConfirm = false
    @State private var voiceName = ""
    @State private var showingSuccess = false
    @State private var showingDeleteConfirm = false
    @State private var showingAddPhrase = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Section", selection: $selectedTab) {
                Text("Clone Voice").tag(0)
                Text("My Phrases").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                if selectedTab == 0 {
                    voiceCloneTab
                } else {
                    customPhrasesTab
                }
            }
        }
        .navigationTitle("Your Voice")
        .alert("Create Voice Clone", isPresented: $showingCloneConfirm) {
            TextField("Your Name", text: $voiceName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createVoiceClone()
            }
        } message: {
            Text("This will create a custom voice that sounds like you! Enter your name:")
        }
        .alert("Voice Created!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Your voice clone is ready! All reminders will now use your voice.")
        }
        .alert("Delete Voice?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVoice()
            }
        } message: {
            Text("This will delete your custom voice clone. You can always record a new one.")
        }
    }

    // MARK: - Voice Clone Tab

    private var voiceCloneTab: some View {
        VStack(spacing: 24) {
            headerSection

            if let voiceName = voiceService.customVoiceName {
                currentVoiceCard(name: voiceName)
            }

            recordingSection
            progressSection
            recordedSamplesSection

            if voiceService.recordings.count >= 3 {
                createVoiceButton
            }
        }
        .padding()
    }

    // MARK: - Custom Phrases Tab

    private var customPhrasesTab: some View {
        VStack(spacing: 20) {
            // Explanation
            VStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("Your Custom Messages")
                    .font(.title3.bold())

                Text("Add your own phrases that will be spoken in your cloned voice. These get mixed in with The Gadfly's messages!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Add phrase button
            Button {
                showingAddPhrase = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Phrase")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // Existing phrases
            if voiceService.customPhrases.isEmpty {
                VStack(spacing: 12) {
                    Text("No custom phrases yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Examples:")
                        .font(.caption.bold())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• \"Put the phone down and do your homework!\"")
                        Text("• \"I love you, but those tasks won't do themselves!\"")
                        Text("• \"Great job finishing that! I'm so proud of you!\"")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                ForEach(VoiceCloningService.CustomPhrase.PhraseCategory.allCases, id: \.self) { category in
                    let phrases = voiceService.customPhrases.filter { $0.category == category }
                    if !phrases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(phrases) { phrase in
                                CustomPhraseRow(phrase: phrase) {
                                    voiceService.togglePhrase(phrase.id)
                                } onDelete: {
                                    voiceService.deleteCustomPhrase(phrase.id)
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 50)
        }
        .sheet(isPresented: $showingAddPhrase) {
            AddCustomPhraseView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Record Your Voice")
                .font(.title2.bold())

            Text("Record yourself saying these phrases. We'll create a voice clone so reminders sound like YOU nagging your family!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Current Voice Card

    private func currentVoiceCard(name: String) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.title2)

            VStack(alignment: .leading) {
                Text("Active Voice: \(name)")
                    .font(.headline)
                Text("Your voice is being used for all reminders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 16) {
            // Current phrase to record
            VStack(spacing: 8) {
                Text("Phrase \(currentPhraseIndex + 1) of \(voiceService.suggestedPhrases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\"\(voiceService.suggestedPhrases[currentPhraseIndex])\"")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            // Record button
            Button {
                if voiceService.isRecording {
                    voiceService.stopRecording(phraseIndex: currentPhraseIndex)
                } else {
                    try? voiceService.startRecording(phraseIndex: currentPhraseIndex)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(voiceService.isRecording ? Color.red : Color.green)
                        .frame(width: 80, height: 80)

                    if voiceService.isRecording {
                        // Recording progress ring
                        Circle()
                            .trim(from: 0, to: voiceService.recordingProgress)
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
            }

            Text(voiceService.isRecording ? "Recording... Tap to stop" : "Tap to record")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Navigation buttons
            HStack {
                Button {
                    if currentPhraseIndex > 0 {
                        currentPhraseIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .disabled(currentPhraseIndex == 0 || voiceService.isRecording)

                Spacer()

                Button {
                    if currentPhraseIndex < voiceService.suggestedPhrases.count - 1 {
                        currentPhraseIndex += 1
                    }
                } label: {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPhraseIndex >= voiceService.suggestedPhrases.count - 1 || voiceService.isRecording)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recording Progress")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(voiceService.recordings.count)/\(voiceService.suggestedPhrases.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(voiceService.recordings.count), total: Double(voiceService.suggestedPhrases.count))
                .tint(.green)

            if voiceService.recordings.count < 3 {
                Text("Record at least 3 phrases to create your voice clone")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("You have enough samples! Record more for better quality.")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Recorded Samples List

    private var recordedSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded Samples")
                .font(.subheadline.bold())

            if voiceService.recordings.isEmpty {
                Text("No recordings yet. Start by recording the first phrase above!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(voiceService.recordings.sorted(by: { $0.phraseIndex < $1.phraseIndex })) { recording in
                    RecordingSampleRow(recording: recording) {
                        voiceService.playRecording(at: recording.phraseIndex)
                    } onDelete: {
                        voiceService.deleteRecording(at: recording.phraseIndex)
                    } onRerecord: {
                        currentPhraseIndex = recording.phraseIndex
                    }
                }
            }
        }
    }

    // MARK: - Create Voice Button

    private var createVoiceButton: some View {
        VStack {
            Button {
                voiceName = appState.userName.isEmpty ? "Parent" : appState.userName
                showingCloneConfirm = true
            } label: {
                HStack {
                    if voiceService.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.badge.plus")
                    }
                    Text(voiceService.isProcessing ? "Creating Voice Clone..." : "Create My Voice Clone")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(voiceService.isProcessing || !appState.hasValidElevenLabsKey)

            if !appState.hasValidElevenLabsKey {
                Text("Add your ElevenLabs API key in Settings to enable voice cloning")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Actions

    private func createVoiceClone() {
        Task {
            do {
                _ = try await voiceService.createVoiceClone(
                    name: voiceName,
                    apiKey: appState.elevenLabsKey
                )
                showingSuccess = true
            } catch {
                voiceService.error = error.localizedDescription
            }
        }
    }

    private func deleteVoice() {
        Task {
            try? await voiceService.deleteVoiceClone(apiKey: appState.elevenLabsKey)
        }
    }
}

// MARK: - Recording Sample Row

struct RecordingSampleRow: View {
    let recording: VoiceRecording
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onRerecord: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            // Phrase info
            VStack(alignment: .leading, spacing: 2) {
                Text("Phrase \(recording.phraseIndex + 1)")
                    .font(.subheadline.bold())
                Text(recording.phrase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(String(format: "%.1fs", recording.duration))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Re-record button
            Button(action: onRerecord) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.orange)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Custom Phrase Row

struct CustomPhraseRow: View {
    let phrase: VoiceCloningService.CustomPhrase
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Toggle
            Button(action: onToggle) {
                Image(systemName: phrase.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(phrase.isActive ? .green : .secondary)
            }

            // Text
            Text(phrase.text)
                .font(.subheadline)
                .foregroundStyle(phrase.isActive ? .primary : .secondary)
                .lineLimit(2)

            Spacer()

            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Add Custom Phrase View

struct AddCustomPhraseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceCloningService.shared
    @State private var phraseText = ""
    @State private var selectedCategory: VoiceCloningService.CustomPhrase.PhraseCategory = .nag

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Message") {
                    TextField("What do you want to say?", text: $phraseText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Category") {
                    Picker("Type", selection: $selectedCategory) {
                        ForEach(VoiceCloningService.CustomPhrase.PhraseCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples by category:")
                            .font(.caption.bold())

                        Group {
                            Text("Nag: \"Put the phone down and finish your homework!\"")
                            Text("Celebration: \"I'm so proud of you for finishing that!\"")
                            Text("Focus: \"Are you still working? I believe in you!\"")
                            Text("Motivation: \"You've got this! Just a little more to go!\"")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        voiceService.addCustomPhrase(phraseText, category: selectedCategory)
                        dismiss()
                    }
                    .disabled(phraseText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VoiceRecordingView()
            .environmentObject(AppState())
    }
}
