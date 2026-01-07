import SwiftUI
import AVFoundation

/// Active focus session with body doubling and task breakdown
struct ActiveFocusSessionView: View {
    let onEnd: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var bodyDoublingService = BodyDoublingService.shared
    @EnvironmentObject var appState: AppState

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingBreakdown = false
    @State private var suggestedSteps: [SubTask] = []
    @State private var isGeneratingSteps = false
    @State private var showEndConfirm = false
    @State private var showAllSubtasks = false

    // SubTask model
    struct SubTask: Identifiable {
        let id = UUID()
        let title: String
        var isComplete: Bool = false
    }


    var body: some View {
        VStack(spacing: 0) {
            // SCROLLABLE CONTENT
            ScrollView {
                VStack(spacing: 12) {
                    // Task name + timer
                    Text(bodyDoublingService.currentSession?.taskTitle ?? "Your task")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)
                        .lineLimit(1)
                        .padding(.top, 12)

                    Text(formatTime(elapsedTime))
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundStyle(themeColors.accent)

                    // Subtasks or breakdown prompt
                    if !suggestedSteps.isEmpty {
                        currentStepCard
                    } else {
                        breakdownPrompt
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }

            // FIXED BOTTOM - never scrolls
            Divider()

            VStack(spacing: 6) {
                companionCard
                actionButtons
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.themeBackground)
        .onAppear {
            startTimer()
            speakGreeting()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .alert("End session?", isPresented: $showEndConfirm) {
            Button("Keep going", role: .cancel) { }
            Button("I'm done", role: .destructive) {
                speakGoodbye()
                onEnd()
            }
        } message: {
            Text("You've been focused for \(formatTime(elapsedTime)). Ready to wrap up?")
        }
    }


    // MARK: - Subtask List Card

    private var currentStepCard: some View {
        VStack(spacing: 12) {
            // Header - tap to toggle view
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAllSubtasks.toggle()
                }
            } label: {
                HStack {
                    Text("Subtasks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)

                    Spacer()

                    Text("\(completedCount)/\(suggestedSteps.count)")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.accent)

                    Image(systemName: showAllSubtasks ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
            }

            // Subtask list
            if showAllSubtasks {
                VStack(spacing: 8) {
                    ForEach(Array(suggestedSteps.enumerated()), id: \.1.id) { index, step in
                        CompactSubtaskRow(
                            title: step.title,
                            isComplete: step.isComplete,
                            onToggle: {
                                toggleSubtask(at: index)
                            }
                        )
                    }
                }
            } else {
                // Show just the current/next incomplete step
                if let nextIndex = suggestedSteps.firstIndex(where: { !$0.isComplete }) {
                    VStack(spacing: 8) {
                        Text("Up next:")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        SubtaskRow(
                            title: suggestedSteps[nextIndex].title,
                            isComplete: false,
                            isHighlighted: true,
                            onToggle: {
                                toggleSubtask(at: nextIndex)
                            }
                        )
                    }
                } else {
                    // All done!
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(themeColors.success)
                        Text("All done!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColors.success)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }

    private var completedCount: Int {
        suggestedSteps.filter { $0.isComplete }.count
    }

    private func toggleSubtask(at index: Int) {
        guard index < suggestedSteps.count else { return }

        let wasComplete = suggestedSteps[index].isComplete
        suggestedSteps[index].isComplete.toggle()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Speak if completing
        if !wasComplete {
            let remaining = suggestedSteps.filter { !$0.isComplete }.count
            if remaining == 0 {
                speakAllDone()
            } else {
                speak("Nice! \(remaining) more to go.")
            }
        }
    }

    // MARK: - Breakdown Prompt

    private var breakdownPrompt: some View {
        VStack(spacing: 12) {
            if isGeneratingSteps {
                ProgressView()
                Text("Breaking down...")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            } else {
                Image(systemName: "wand.and.sparkles")
                    .font(.title)
                    .foregroundStyle(themeColors.accent)

                Text("Break into smaller steps?")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.text)

                HStack(spacing: 12) {
                    Button {
                        generateBreakdown()
                    } label: {
                        Text("Yes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                    }

                    Button {
                        showingBreakdown = false
                    } label: {
                        Text("No")
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeSecondary)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Companion Card

    private var companionCard: some View {
        HStack(spacing: 10) {
            Text(appState.selectedPersonality.emoji)
                .font(.title2)

            Text("Here with you")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)

            Spacer()

            // Speak button
            Button {
                speakEncouragement()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(themeColors.accent)
                    .frame(width: 36, height: 36)
                    .background(Color.themeSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(10)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Button {
            showEndConfirm = true
        } label: {
            HStack {
                Image(systemName: "stop.fill")
                Text("End")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.8))
            .cornerRadius(10)
        }
    }

    // MARK: - Helper Functions

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func generateBreakdown() {
        isGeneratingSteps = true

        // For now, generate sample steps (would use AI in production)
        // This would call OpenAI to break down the task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            suggestedSteps = [
                SubTask(title: "Gather everything you need"),
                SubTask(title: "Open/prepare what you're working on"),
                SubTask(title: "Do the main part for 10 minutes"),
                SubTask(title: "Review what you've done"),
                SubTask(title: "Wrap up and save your progress")
            ]
            isGeneratingSteps = false
            showAllSubtasks = true
            speakFirstStep()
        }
    }

    // MARK: - Voice Functions

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    private func speakGreeting() {
        let personality = appState.selectedPersonality
        let task = bodyDoublingService.currentSession?.taskTitle ?? "this"

        let greeting: String
        switch personality {
        case .pemberton:
            greeting = "Very well. Let's see if we can make progress on \(task). I'll be timing you."
        case .sergent:
            greeting = "Mission started! Focus on \(task)! I'm watching!"
        case .cheerleader:
            greeting = "Yes! You're doing it! Working on \(task)! I'm so proud of you!"
        case .hypeFriend:
            greeting = "Let's GOOO! You're about to absolutely crush \(task)!"
        case .chillBuddy:
            greeting = "Cool... let's just chill and work on \(task). No stress."
        default:
            greeting = "Starting focus session for \(task). I'm here with you."
        }

        speak(greeting)
    }

    private func speakEncouragement() {
        let messages = appState.selectedPersonality.focusCheckInMessages
        if let message = messages.randomElement() {
            speak(message)
        }
    }

    private func speakFirstStep() {
        guard let step = suggestedSteps.first else { return }
        speak("Okay, first step: \(step.title)")
    }

    private func speakNextStep() {
        guard let nextStep = suggestedSteps.first(where: { !$0.isComplete }) else { return }
        speak("Nice! Next: \(nextStep.title)")
    }

    private func speakAllDone() {
        speak("Amazing! You finished all the steps. Great work!")
    }

    private func speakGoodbye() {
        let time = formatTime(elapsedTime)
        speak("Great session! You focused for \(time). Well done.")
    }
}

// MARK: - Subtask Row Component

struct SubtaskRow: View {
    let title: String
    let isComplete: Bool
    var isHighlighted: Bool = false
    let onToggle: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // BIG checkbox
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 36))
                    .foregroundStyle(isComplete ? themeColors.success : themeColors.subtext)

                // Title
                Text(title)
                    .font(.body)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                    .foregroundStyle(isComplete ? themeColors.subtext : themeColors.text)
                    .strikethrough(isComplete)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isHighlighted ? Color.themeAccent.opacity(0.15) : Color.clear)
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Subtask Row (for list view)

struct CompactSubtaskRow: View {
    let title: String
    let isComplete: Bool
    let onToggle: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isComplete ? themeColors.success : themeColors.subtext)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isComplete ? themeColors.subtext : themeColors.text)
                    .strikethrough(isComplete)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.themeBackground.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

#Preview {
    ActiveFocusSessionView(onEnd: {})
        .environmentObject(AppState())
}
