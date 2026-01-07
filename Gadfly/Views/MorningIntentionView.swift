import SwiftUI
import AVFoundation
import Speech

/// Start of day - ask what will make today meaningful
/// Voice-first, one simple question
struct MorningIntentionView: View {
    let onComplete: (String) -> Void  // The intention they set
    let onSkip: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var showingConfirmation = false

    private let speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Greeting based on time
            Text(getGreeting())
                .font(.title2)
                .foregroundStyle(themeColors.subtext)

            // Personality avatar
            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 80))

            // The question - future self visualization
            VStack(spacing: 16) {
                Text("Imagine tonight...")
                    .font(.title3)
                    .foregroundStyle(themeColors.subtext)

                Text("You're going to bed feeling proud.")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(themeColors.text)

                Text("What did you accomplish?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeAccent)
            }
            .multilineTextAlignment(.center)

            // Personality's encouragement
            Text(getPersonalityPrompt())
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Voice input or transcribed text
            if showingConfirmation && !transcribedText.isEmpty {
                confirmationView
            } else {
                voiceInputView
            }
        }
        .padding()
        .background(Color.themeBackground)
        .onAppear {
            speakQuestion()
        }
    }

    // MARK: - Voice Input

    private var voiceInputView: some View {
        VStack(spacing: 20) {
            // Big record button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.themeAccent)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(isRecording ? .white : .black)
                }
            }

            Text(isRecording ? "Listening..." : "Tap to speak")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)

            // Skip option
            Button {
                onSkip()
            } label: {
                Text("Skip for now")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.7))
            }
            .padding(.bottom)
        }
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        VStack(spacing: 20) {
            Text("Your intention for today:")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)

            Text(transcribedText)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.themeSecondary)
                .cornerRadius(12)

            HStack(spacing: 16) {
                // Try again
                Button {
                    transcribedText = ""
                    showingConfirmation = false
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try again")
                    }
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // Confirm
                Button {
                    speakConfirmation()
                    onComplete(transcribedText)
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Let's do it")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.bottom)
    }

    // MARK: - Voice

    private func speakQuestion() {
        let message = "\(getGreeting()). Imagine tonight, you're going to bed feeling proud. What did you accomplish? \(getPersonalityPrompt())"
        speak(message)
    }

    private func speakConfirmation() {
        let personality = appState.selectedPersonality
        let message: String

        switch personality {
        case .pemberton:
            message = "A worthy endeavor. Let's see if you can actually accomplish it."
        case .sergent:
            message = "Mission accepted! Let's execute!"
        case .cheerleader:
            message = "YES! I love it! You're going to be AMAZING today!"
        case .hypeFriend:
            message = "THAT'S what I'm talking about! Let's GO!"
        case .tiredParent:
            message = "Good goal. Let's do our best."
        default:
            message = "Great intention. Let's make it happen."
        }

        speak(message)
    }

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    // MARK: - Speech Recognition

    private func startRecording() {
        // Request authorization first
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }

            DispatchQueue.main.async {
                self.isRecording = true
                self.startSpeechRecognition()
            }
        }
    }

    private func startSpeechRecognition() {
        let request = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        if !transcribedText.isEmpty {
            showingConfirmation = true
        }
    }

    // MARK: - Helpers

    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private func getPersonalityPrompt() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "What intellectual pursuit shall justify your existence today?"
        case .sergent:
            return "What's your primary objective, soldier?"
        case .cheerleader:
            return "What amazing thing are you going to accomplish today?"
        case .butler:
            return "What would bring you satisfaction today, Sir?"
        case .coach:
            return "What's the winning play for today?"
        case .zen:
            return "What will bring you peace and growth today?"
        case .parent:
            return "What would make you proud of yourself today, sweetie?"
        case .bestie:
            return "What do you actually want to get done today?"
        case .robot:
            return "State primary objective."
        case .therapist:
            return "What would feel meaningful to accomplish today?"
        case .hypeFriend:
            return "What legendary thing are you going to CRUSH today?!"
        case .chillBuddy:
            return "What would feel good to finish today?"
        case .snarky:
            return "What unrealistic goal are we setting today?"
        case .gamer:
            return "What's today's main quest?"
        case .tiredParent:
            return "What's one thing we can realistically do today?"
        case .sage:
            return "What wisdom will you seek on your path today?"
        case .rebel:
            return "What system are you going to beat today?"
        case .trickster:
            return "What if you did the opposite of what you should? ...Or maybe just do the thing?"
        case .stoic:
            return "What duty calls to you today?"
        case .pirate:
            return "What treasure are ye huntin' today, matey?"
        case .witch:
            return "What spell shall we cast upon the day?"
        }
    }
}

#Preview {
    MorningIntentionView(
        onComplete: { intention in
            print("Intention: \(intention)")
        },
        onSkip: {}
    )
    .environmentObject(AppState())
}
