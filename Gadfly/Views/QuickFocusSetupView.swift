import SwiftUI
import AVFoundation

/// Quick focus session setup - minimal cognitive load
/// All voice and buttons - no typing required
struct QuickFocusSetupView: View {
    let taskTitle: String
    let onStart: (Int, String?) -> Void  // minutes, success definition
    let onCancel: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var selectedMinutes: Int = 25

    private let timeOptions = [15, 25, 45, 60, 90]
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Task name - big and clear
                VStack(spacing: 12) {
                    Text(appState.selectedPersonality.emoji)
                        .font(.system(size: 60))

                    Text(taskTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                // Time picker - BIG easy buttons
                VStack(spacing: 16) {
                    Text("How long?")
                        .font(.title3)
                        .foregroundStyle(themeColors.subtext)

                    // First row - quick options
                    HStack(spacing: 16) {
                        ForEach([15, 25, 45], id: \.self) { minutes in
                            BigTimeButton(
                                minutes: minutes,
                                isSelected: selectedMinutes == minutes
                            ) {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMinutes = minutes
                                    speakTime(minutes)
                                }
                            }
                        }
                    }

                    // Second row - longer options
                    HStack(spacing: 16) {
                        ForEach([60, 90], id: \.self) { minutes in
                            BigTimeButton(
                                minutes: minutes,
                                isSelected: selectedMinutes == minutes
                            ) {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedMinutes = minutes
                                    speakTime(minutes)
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Personality encouragement
                personalityEncouragement

                // Big Start button
                Button {
                    speakStart()
                    onStart(selectedMinutes, nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                        Text("Let's go!")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.themeAccent)
                    .cornerRadius(16)
                }

                // Skip - just start without timer
                Button {
                    onStart(0, nil)  // 0 means no timer
                } label: {
                    Text("Just start (no timer)")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }
                .padding(.bottom)
            }
            .padding()
            .background(Color.themeBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(themeColors.subtext)
                    }
                }
            }
        }
        .onAppear {
            speakPrompt()
        }
    }

    // MARK: - Voice Functions

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    private func speakPrompt() {
        speak("How long do you want to work on this?")
    }

    private func speakTime(_ minutes: Int) {
        speak("\(minutes) minutes")
    }

    private func speakStart() {
        speak("Let's do this!")
    }

    @ViewBuilder
    private var personalityEncouragement: some View {
        let personality = appState.selectedPersonality
        let message = getPersonalityMessage(personality)

        Text(message)
            .font(.subheadline)
            .foregroundStyle(themeColors.subtext)
            .italic()
            .multilineTextAlignment(.center)
            .padding()
    }

    private func getPersonalityMessage(_ personality: BotPersonality) -> String {
        switch personality {
        case .pemberton:
            return "Well then, shall we attempt to be productive for once?"
        case .sergent:
            return "Time to execute! No excuses, soldier!"
        case .cheerleader:
            return "You've SO got this! I'm right here cheering you on!"
        case .butler:
            return "Very good, Sir. I shall keep time for you."
        case .coach:
            return "Game time! Let's make this play count!"
        case .zen:
            return "Be present. The journey of completion begins now."
        case .parent:
            return "I'm so proud of you for starting. You've got this, sweetie!"
        case .bestie:
            return "Okay let's do this together. I got your back."
        case .robot:
            return "Timer initialized. Task: \(taskTitle)"
        case .therapist:
            return "It's brave to start. I'm here with you."
        case .hypeFriend:
            return "YESSS let's GOOO! You're about to CRUSH this!"
        case .chillBuddy:
            return "No pressure... we'll just chill and get it done."
        case .snarky:
            return "Oh wow, actually starting? Color me impressed."
        case .gamer:
            return "Quest accepted! +\(selectedMinutes) XP awaits!"
        case .tiredParent:
            return "Okay. Deep breath. We can do this."
        case .sage:
            return "The path of focus awaits. Begin your journey."
        case .rebel:
            return "Time to take control. The system doesn't own your focus."
        case .trickster:
            return "You're not going to focus for \(selectedMinutes) minutes... or ARE you?"
        case .stoic:
            return "Control what you can. Focus now. Begin."
        case .pirate:
            return "Set sail for productivity, matey! \(selectedMinutes) minutes to treasure!"
        case .witch:
            return "The focus spell begins. Stir the cauldron of productivity."
        }
    }
}

// MARK: - Big Time Button (for easy tapping)

struct BigTimeButton: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 32, weight: .bold))
                Text("min")
                    .font(.subheadline)
            }
            .foregroundStyle(isSelected ? .black : Color.themeText)
            .frame(width: 90, height: 90)
            .background(isSelected ? Color.themeAccent : Color.themeSecondary)
            .cornerRadius(16)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
    }
}

#Preview {
    QuickFocusSetupView(
        taskTitle: "Write the quarterly report",
        onStart: { minutes, success in
            print("Starting \(minutes) min focus, success: \(success ?? "none")")
        },
        onCancel: {}
    )
    .environmentObject(AppState())
}
