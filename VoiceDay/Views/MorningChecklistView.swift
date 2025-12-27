import SwiftUI

/// Bot-led morning checklist - one item at a time
/// Big buttons, voice prompts, no thinking required
struct MorningChecklistView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @ObservedObject private var checklistService = MorningChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var currentIndex = 0
    @State private var showingAllDone = false

    private var activeChecks: [MorningChecklistService.SelfCheck] {
        checklistService.activeChecks
    }

    private var currentCheck: MorningChecklistService.SelfCheck? {
        guard currentIndex < activeChecks.count else { return nil }
        return activeChecks[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingAllDone {
                allDoneView
            } else if let check = currentCheck {
                checkView(for: check)
            } else {
                // No checks configured
                noChecksView
            }
        }
        .background(Color.themeBackground)
        .onAppear {
            speakGreeting()
        }
    }

    // MARK: - Check View

    private func checkView(for check: MorningChecklistService.SelfCheck) -> some View {
        VStack(spacing: 24) {
            // Progress
            HStack {
                Text("Morning Check-in")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                Spacer()

                Text("\(currentIndex + 1) of \(activeChecks.count)")
                    .font(.caption)
                    .foregroundStyle(themeColors.accent)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Progress bar
            ProgressView(value: Double(currentIndex), total: Double(activeChecks.count))
                .tint(Color.themeAccent)
                .padding(.horizontal)

            Spacer()

            // Bot asking
            VStack(spacing: 16) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 70))

                Text(getQuestion(for: check))
                    .font(.title3)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // The check item - BIG
            Text(check.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.themeSecondary)
                .cornerRadius(16)
                .padding(.horizontal)

            Spacer()

            // Response buttons - BIG and easy
            VStack(spacing: 12) {
                // Done button
                Button {
                    markDone()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                        Text("Done")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.themeAccent)
                    .cornerRadius(14)
                }

                // Skip / Not today button
                Button {
                    skipCurrent()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeSecondary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration
            Text("🎉")
                .font(.system(size: 80))

            Text("Morning check-in complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeColors.text)

            Text(getCelebrationMessage())
                .font(.body)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Summary
            VStack(spacing: 8) {
                Text("\(checklistService.completedCount) of \(activeChecks.count) items done")
                    .font(.headline)
                    .foregroundStyle(themeColors.accent)

                if checklistService.completedCount == activeChecks.count {
                    Text("Perfect start to the day!")
                        .font(.caption)
                        .foregroundStyle(themeColors.success)
                }
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            Spacer()

            // Done button
            Button {
                speakGoodbye()
                onComplete()
            } label: {
                Text("Let's go!")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - No Checks View

    private var noChecksView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 60))

            Text("No morning checks set up yet")
                .font(.title3)
                .foregroundStyle(themeColors.text)

            Text("Add some in Settings to build your morning routine")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                onSkip()
            } label: {
                Text("Got it")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions

    private func markDone() {
        guard let check = currentCheck else { return }

        checklistService.markCompleted(id: check.id)

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Speak acknowledgment
        speakAcknowledgment()

        // Move to next or finish
        moveToNext()
    }

    private func skipCurrent() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        speakSkip()
        moveToNext()
    }

    private func moveToNext() {
        if currentIndex < activeChecks.count - 1 {
            withAnimation(.spring(response: 0.3)) {
                currentIndex += 1
            }
            // Small delay then speak next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                speakNextQuestion()
            }
        } else {
            withAnimation(.spring(response: 0.3)) {
                showingAllDone = true
            }
            speakAllDone()
        }
    }

    // MARK: - Voice

    private func speakGreeting() {
        let personality = appState.selectedPersonality
        let count = activeChecks.count

        let greeting: String
        switch personality {
        case .pemberton:
            greeting = "Good morning. Let's review your \(count) morning essentials, shall we?"
        case .sergent:
            greeting = "Rise and shine! \(count) items on your morning briefing. Let's go!"
        case .cheerleader:
            greeting = "Good morning superstar! Let's check in on your \(count) morning things!"
        case .hypeFriend:
            greeting = "GOOD MORNING! Let's crush this morning routine! \(count) quick checks!"
        case .chillBuddy:
            greeting = "Hey... morning. Just \(count) quick things to check on. No rush."
        case .tiredParent:
            greeting = "Morning. Let's just get through these \(count) things. You got this."
        default:
            greeting = "Good morning! Let's go through your \(count) morning checks."
        }

        SpeechService.shared.queueSpeech(greeting)
    }

    private func speakNextQuestion() {
        guard let check = currentCheck else { return }
        SpeechService.shared.queueSpeech("Next: \(check.title)?")
    }

    private func speakAcknowledgment() {
        let responses = ["Got it.", "Nice.", "Check.", "Done.", "Good."]
        if let response = responses.randomElement() {
            SpeechService.shared.queueSpeech(response)
        }
    }

    private func speakSkip() {
        let responses = ["Okay, skipping.", "No problem.", "We'll skip that one.", "Alright."]
        if let response = responses.randomElement() {
            SpeechService.shared.queueSpeech(response)
        }
    }

    private func speakAllDone() {
        let completed = checklistService.completedCount
        let total = activeChecks.count

        if completed == total {
            SpeechService.shared.queueSpeech("Perfect! All \(total) items done. You're ready for the day!")
        } else {
            SpeechService.shared.queueSpeech("Morning check-in done. \(completed) of \(total) complete. Let's have a good day!")
        }
    }

    private func speakGoodbye() {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            SpeechService.shared.queueSpeech("Carry on then. Make it count.")
        case .sergent:
            SpeechService.shared.queueSpeech("Mission briefing complete. Execute!")
        case .cheerleader:
            SpeechService.shared.queueSpeech("You're going to have an AMAZING day!")
        case .hypeFriend:
            SpeechService.shared.queueSpeech("LET'S GOOO! Crush it today!")
        default:
            SpeechService.shared.queueSpeech("Have a great day!")
        }
    }

    // MARK: - Message Helpers

    private func getQuestion(for check: MorningChecklistService.SelfCheck) -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Have you attended to this?"
        case .sergent:
            return "Status report:"
        case .cheerleader:
            return "Did you do this amazing thing?"
        case .therapist:
            return "How are we feeling about this one?"
        case .bestie:
            return "Did you get to this?"
        default:
            return "Did you do this?"
        }
    }

    private func getCelebrationMessage() -> String {
        let personality = appState.selectedPersonality
        let completed = checklistService.completedCount
        let total = activeChecks.count

        if completed == total {
            switch personality {
            case .pemberton:
                return "A thoroughly adequate start to the day."
            case .sergent:
                return "Full marks, soldier! Ready for action!"
            case .cheerleader:
                return "OH MY GOSH you're amazing! Perfect morning!"
            case .hypeFriend:
                return "UNSTOPPABLE! You're literally crushing life right now!"
            case .tiredParent:
                return "Hey, you actually did everything. That's... impressive."
            default:
                return "Great start! You're set up for success."
            }
        } else {
            return "You've checked in on what matters. That's what counts."
        }
    }
}

#Preview {
    MorningChecklistView(
        onComplete: {},
        onSkip: {}
    )
    .environmentObject(AppState())
}
