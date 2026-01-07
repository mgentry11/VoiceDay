import SwiftUI
import AVFoundation

/// Voice-first prompt when the bot notices an aging task
/// User doesn't think - just responds to options
struct AgingTaskPromptView: View {
    let task: TaskAgingService.AgingTaskPrompt
    let onBreakdown: () -> Void
    let onPushLater: () -> Void
    let onPushTomorrow: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var selectedReason: TaskAgingService.BlockerReason?
    @State private var showingReasonPicker = true
    @State private var showingActions = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                // Personality avatar
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 80))
                    .padding(.top, 40)

                // Task info
                VStack(spacing: 8) {
                    Text(task.taskTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    HStack {
                        Circle()
                            .fill(task.severity.color)
                            .frame(width: 12, height: 12)
                        Text("\(Int(task.hoursOld / 24)) days old")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                if showingReasonPicker {
                    // Step 1: Ask why it's not done
                    reasonPickerSection
                } else if showingActions {
                    // Step 2: Offer solutions based on reason
                    actionSection
                }

                Spacer()

                // Skip button
                Button {
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
        .onAppear {
            speakPrompt()
        }
    }

    // MARK: - Reason Picker

    private var reasonPickerSection: some View {
        VStack(spacing: 16) {
            Text("What's getting in the way?")
                .font(.headline)
                .foregroundStyle(.white)

            // Big reason buttons - 2 per row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TaskAgingService.BlockerReason.allCases, id: \.self) { reason in
                    ReasonButton(reason: reason) {
                        selectReason(reason)
                    }
                }
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 20) {
            if let reason = selectedReason {
                // Show the bot's response
                Text(reason.helpResponse)
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }

            // Action buttons - big and clear
            VStack(spacing: 12) {
                // Primary action - Break it down
                ActionButton(
                    icon: "scissors",
                    title: "Break it down",
                    subtitle: "Help me figure out the steps",
                    color: Color.themeAccent
                ) {
                    onBreakdown()
                }

                // Push options
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "clock.arrow.circlepath",
                        title: "Later",
                        subtitle: "In 3 hours",
                        color: .orange
                    ) {
                        onPushLater()
                    }

                    ActionButton(
                        icon: "sunrise.fill",
                        title: "Tomorrow",
                        subtitle: "Fresh start",
                        color: .blue
                    ) {
                        onPushTomorrow()
                    }
                }

                // Delete option (if they said they don't want to)
                if selectedReason == .dontWant {
                    ActionButton(
                        icon: "trash.fill",
                        title: "Just delete it",
                        subtitle: "It's not important",
                        color: .red.opacity(0.8)
                    ) {
                        onDelete()
                    }
                }
            }
        }
    }

    // MARK: - Voice

    private func speakPrompt() {
        let personality = appState.selectedPersonality
        let message = getPromptMessage(personality)
        speak(message)
    }

    private func getPromptMessage(_ personality: BotPersonality) -> String {
        let days = Int(task.hoursOld / 24)

        switch personality {
        case .pemberton:
            return "'\(task.taskTitle)' has been waiting for \(days) days. What seems to be the obstacle?"
        case .cheerleader:
            return "Hey! I noticed '\(task.taskTitle)' has been there a while. What's making it tricky?"
        case .bestie:
            return "Okay so '\(task.taskTitle)' is still there. What's up?"
        case .therapist:
            return "I see '\(task.taskTitle)' has been with you for a bit. What's coming up for you around it?"
        default:
            return "'\(task.taskTitle)' has been waiting. What's getting in the way?"
        }
    }

    private func selectReason(_ reason: TaskAgingService.BlockerReason) {
        selectedReason = reason

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Speak the response
        speak(reason.helpResponse)

        withAnimation(.spring(response: 0.3)) {
            showingReasonPicker = false
            showingActions = true
        }
    }

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }
}

// MARK: - Reason Button

struct ReasonButton: View {
    let reason: TaskAgingService.BlockerReason
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: reason.icon)
                    .font(.title)
                Text(reason.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.8)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(color == Color.themeAccent ? .black : .white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    AgingTaskPromptView(
        task: TaskAgingService.AgingTaskPrompt(
            taskTitle: "Write the quarterly report",
            taskId: "123",
            hoursOld: 72,
            severity: .critical
        ),
        onBreakdown: {},
        onPushLater: {},
        onPushTomorrow: {},
        onDelete: {},
        onDismiss: {}
    )
    .environmentObject(AppState())
}
