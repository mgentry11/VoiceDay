import SwiftUI
import AVFoundation

/// Celebration when user pushes a task to tomorrow
/// Reframes it as "getting organized" not procrastinating
struct PushCelebrationView: View {
    let taskTitle: String
    let onDismiss: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }

            // Personality celebration
            VStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 50))

                Text(getCelebrationMessage())
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Task moved
            VStack(spacing: 8) {
                Text("Moved to tomorrow:")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                Text(taskTitle)
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text("9:00 AM")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            Spacer()

            // Encouragement text
            Text(getEncouragementText())
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Done button
            Button {
                onDismiss()
            } label: {
                Text("Got it")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color.themeBackground)
        .onAppear {
            speakCelebration()
        }
    }

    // MARK: - Personality Messages

    private func getCelebrationMessage() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "A strategic reallocation. Tomorrow shall bear this burden."
        case .sergent:
            return "Mission rescheduled! Tomorrow's objective is set!"
        case .cheerleader:
            return "Smart planning! You're SO organized!"
        case .butler:
            return "Very good, Sir. I've arranged it for the morrow."
        case .coach:
            return "Good game management! Tomorrow we attack fresh!"
        case .zen:
            return "Sometimes patience is wisdom. Tomorrow awaits."
        case .parent:
            return "Good choice, sweetie. You know what's best for you."
        case .bestie:
            return "Smart call. Tomorrow's a fresh start anyway."
        case .robot:
            return "Task rescheduled. Tomorrow 09:00."
        case .therapist:
            return "That's a healthy boundary. It's okay to pace yourself."
        case .hypeFriend:
            return "YES! Organizing like a BOSS! Tomorrow you'll CRUSH it!"
        case .chillBuddy:
            return "No stress... tomorrow works. It's all good."
        case .snarky:
            return "Look at you, being all strategic. Tomorrow it is."
        case .gamer:
            return "Quest rescheduled! +10 Organization XP!"
        case .tiredParent:
            return "Good call. We're tired. Tomorrow we try again."
        case .sage:
            return "Wisdom knows when to pause. Tomorrow, the path continues."
        case .rebel:
            return "Taking control of your schedule. Tomorrow, you strike."
        case .trickster:
            return "Plot twist! The task moves to tomorrow. Clever, clever..."
        case .stoic:
            return "A rational choice. Tomorrow's duties await."
        case .pirate:
            return "Arr! Stashin' this treasure for tomorrow's plunder!"
        case .witch:
            return "Into the cauldron of tomorrow it goes... *cackles*"
        }
    }

    private func getEncouragementText() -> String {
        [
            "Organizing is progress. You're doing great.",
            "Knowing when to pause is a skill.",
            "Tomorrow is a fresh opportunity.",
            "Being realistic is being smart.",
            "One less thing to worry about today."
        ].randomElement() ?? "Great organizing!"
    }

    private func speakCelebration() {
        let message = getCelebrationMessage()
        SpeechService.shared.queueSpeech(message)
    }
}

#Preview {
    PushCelebrationView(
        taskTitle: "Write the quarterly report",
        onDismiss: {}
    )
    .environmentObject(AppState())
}
