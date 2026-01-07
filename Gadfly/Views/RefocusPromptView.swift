import SwiftUI
import AVFoundation

/// After completing a task, help user refocus + self-care
/// Bot guides - user just responds
struct RefocusPromptView: View {
    let completedTaskTitle: String
    let remainingTasks: [String]
    let suggestedNextTask: String?
    let taskCompletedCount: Int  // How many done today
    let onStartNext: (String) -> Void  // Start the suggested task
    let onPickDifferent: () -> Void    // Let them see all tasks
    let onTakeBreak: () -> Void        // Take a break first
    let onDone: () -> Void             // Done for now

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var showingSelfCare = false
    @State private var selfCareShown = false

    // Show self-care every 2-3 tasks
    private var shouldShowSelfCare: Bool {
        taskCompletedCount > 0 && taskCompletedCount % 2 == 0
    }

    var body: some View {
        VStack(spacing: 24) {
            // Celebration
            VStack(spacing: 12) {
                Text("✓")
                    .font(.system(size: 60))
                    .foregroundStyle(themeColors.success)

                Text("Done!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)

                Text(completedTaskTitle)
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Self-care check (every 2 tasks)
            if shouldShowSelfCare && !selfCareShown {
                selfCareSection
            } else {
                Divider()

                // Refocus section
                if remainingTasks.isEmpty {
                    allDoneView
                } else {
                    nextTaskSection
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.themeBackground)
        .onAppear {
            if shouldShowSelfCare {
                speakSelfCare()
            } else {
                speakRefocus()
            }
        }
    }

    // MARK: - Self-Care Section

    private var selfCareSection: some View {
        VStack(spacing: 20) {
            // Personality asks about self-care
            HStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 40))

                Text(getSelfCareMessage())
                    .font(.body)
                    .foregroundStyle(themeColors.text)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            // Self-care options - BIG buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SelfCareButton(icon: "drop.fill", title: "Water", color: .blue) {
                        completeSelfCare()
                    }
                    SelfCareButton(icon: "figure.walk", title: "Stretch", color: .green) {
                        completeSelfCare()
                    }
                }

                HStack(spacing: 12) {
                    SelfCareButton(icon: "eye.slash.fill", title: "Rest eyes", color: .purple) {
                        completeSelfCare()
                    }
                    SelfCareButton(icon: "lungs.fill", title: "Breathe", color: .cyan) {
                        completeSelfCare()
                    }
                }
            }

            // Skip
            Button {
                completeSelfCare()
            } label: {
                Text("I'm good, let's continue")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }
        }
    }

    private func completeSelfCare() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3)) {
            selfCareShown = true
        }

        // Now speak refocus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speakRefocus()
        }
    }

    private func getSelfCareMessage() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Before we proceed, perhaps attend to your biological needs? Water, perhaps?"
        case .sergent:
            return "Quick break! Hydrate and stretch, soldier! 30 seconds!"
        case .cheerleader:
            return "You're doing AMAZING! Time for a quick self-care moment!"
        case .parent:
            return "Sweetie, have you had water? Let's take care of you."
        case .therapist:
            return "Let's pause and check in with your body. What do you need?"
        case .tiredParent:
            return "We both need a second. Water? Stretch? Something?"
        default:
            return "Quick self-care check. Water? Stretch? Rest your eyes?"
        }
    }

    private func speakSelfCare() {
        speak(getSelfCareMessage())
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 20) {
            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 50))

            Text("You've finished everything!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.text)

            Text(getAllDoneMessage())
                .font(.body)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)

            Button {
                onDone()
            } label: {
                Text("Celebrate!")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Next Task Section

    private var nextTaskSection: some View {
        VStack(spacing: 20) {
            // Personality asks what's next
            HStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.title)

                Text(getRefocusQuestion())
                    .font(.body)
                    .foregroundStyle(themeColors.text)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            // Suggested next task - BIG button
            if let suggested = suggestedNextTask {
                VStack(spacing: 8) {
                    Text("Up next:")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)

                    Button {
                        onStartNext(suggested)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                            Text(suggested)
                                .font(.headline)
                                .lineLimit(2)
                            Spacer()
                        }
                        .foregroundStyle(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                    }
                }
            }

            // Other options
            HStack(spacing: 12) {
                // Different task
                Button {
                    onPickDifferent()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                        Text("Pick\ndifferent")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // Take a break
                Button {
                    onTakeBreak()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title2)
                        Text("Take\na break")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // Done for now
                Button {
                    onDone()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                        Text("Done\nfor now")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }
            }

            // Remaining count
            Text("\(remainingTasks.count) tasks remaining today")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
        }
    }

    // MARK: - Voice

    private func speakRefocus() {
        let message: String
        if remainingTasks.isEmpty {
            message = getAllDoneMessage()
        } else if let next = suggestedNextTask {
            message = "\(getRefocusQuestion()) How about \(next)?"
        } else {
            message = getRefocusQuestion()
        }
        speak(message)
    }

    private func getRefocusQuestion() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Well done. Now then, what shall we tackle next?"
        case .sergent:
            return "Good work soldier! Next objective?"
        case .cheerleader:
            return "Amazing! You're on fire! What's next?"
        case .butler:
            return "Very good, Sir. What would you like to attend to next?"
        case .coach:
            return "Great play! What's the next move?"
        case .zen:
            return "One task complete. What calls to you next?"
        case .parent:
            return "I'm so proud! Ready for the next one?"
        case .bestie:
            return "Nice! Okay what's next on the list?"
        case .robot:
            return "Task complete. Next task?"
        case .therapist:
            return "How does it feel to finish that? Ready to continue?"
        case .hypeFriend:
            return "YESSS! You're CRUSHING it! What's next?!"
        case .chillBuddy:
            return "Cool, that's done. What do you feel like doing next?"
        case .snarky:
            return "Look at you, being productive. What's next?"
        case .gamer:
            return "Quest complete! +XP! Ready for the next quest?"
        case .tiredParent:
            return "One down. Okay, what's next?"
        case .sage:
            return "One step complete on the path. What is the next stone?"
        case .rebel:
            return "Good. You took control. What's next to conquer?"
        case .trickster:
            return "Impressive! Or was it? Let's find out... what's next?"
        case .stoic:
            return "Duty fulfilled. What duty follows?"
        case .pirate:
            return "Treasure secured! What's the next prize, matey?"
        case .witch:
            return "The spell worked! What magic shall we brew next?"
        }
    }

    private func getAllDoneMessage() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Remarkable. You've actually finished everything. I'm... impressed."
        case .sergent:
            return "ALL OBJECTIVES COMPLETE! Outstanding work, soldier!"
        case .cheerleader:
            return "OH MY GOSH YOU DID IT ALL! I'M SO PROUD!"
        case .hypeFriend:
            return "LEGENDARY! You finished EVERYTHING! You're UNSTOPPABLE!"
        case .tiredParent:
            return "We did it. We actually did it. Time to rest."
        default:
            return "You've completed all your tasks! Well done!"
        }
    }

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }
}

// MARK: - Self Care Button

struct SelfCareButton: View {
    let icon: String
    let title: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(color)
            .cornerRadius(16)
        }
    }
}

// MARK: - Quick Add Task View (for forgotten tasks)

struct QuickAddForgottenView: View {
    let onAddVoice: () -> Void
    let onSkip: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.title)

                Text(getForgotQuestion())
                    .font(.body)
                    .foregroundStyle(themeColors.text)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            HStack(spacing: 16) {
                // Add via voice - BIG
                Button(action: onAddVoice) {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.title)
                        Text("Add task")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
                }

                // Skip
                Button(action: onSkip) {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.title)
                        Text("All set")
                            .font(.subheadline)
                    }
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func getForgotQuestion() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Anything else rattling around in that mind of yours that we should capture?"
        case .sergent:
            return "Any other objectives to add to the mission, soldier?"
        case .cheerleader:
            return "Did you remember everything? Anything else we should add?"
        case .parent:
            return "Is there anything else on your mind, sweetie?"
        case .bestie:
            return "Anything else you forgot to mention?"
        default:
            return "Anything else you need to add while we're here?"
        }
    }
}

#Preview {
    RefocusPromptView(
        completedTaskTitle: "Write the quarterly report",
        remainingTasks: ["Call mom", "Grocery shopping", "Pay bills"],
        suggestedNextTask: "Call mom",
        taskCompletedCount: 2,
        onStartNext: { _ in },
        onPickDifferent: {},
        onTakeBreak: {},
        onDone: {}
    )
    .environmentObject(AppState())
}
