import SwiftUI

/// Universal escape bar that appears on all screens - ADHD users need a way out
struct UniversalEscapeBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let showSettings: Bool
    let showHome: Bool
    let onEscape: (() -> Void)?

    init(showSettings: Bool = true, showHome: Bool = true, onEscape: (() -> Void)? = nil) {
        self.showSettings = showSettings
        self.showHome = showHome
        self.onEscape = onEscape
    }

    var body: some View {
        HStack(spacing: 16) {
            if showHome {
                Button {
                    handleEscape()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 14))
                        Text("Home")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(20)
                }
            }

            Spacer()

            if showSettings {
                Button {
                    appState.selectedTab = 3
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                        Text("Settings")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func handleEscape() {
        // Save state before escaping
        SessionStateService.shared.markInterrupted()

        // Speak gentle exit message
        let messages = [
            "No problem! We'll pick up later.",
            "Taking a break? That's okay!",
            "Heading home. See you soon!",
            "Got it. Take your time."
        ]
        let message = RecentlySpokenService.shared.getUnspokenAlternative(from: messages)
        SpeechService.shared.queueSpeech(message)

        // Execute custom escape handler or default
        if let onEscape = onEscape {
            onEscape()
        } else {
            appState.selectedTab = 0 // Focus Home
            dismiss()
        }
    }
}

/// Floating escape button for full-screen views
struct FloatingEscapeButton: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showOptions = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white, Color.gray.opacity(0.8))
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
        .confirmationDialog("Need to leave?", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Go Home") {
                SessionStateService.shared.markInterrupted()
                appState.selectedTab = 0
                dismiss()
            }

            Button("Open Settings") {
                appState.selectedTab = 3
                dismiss()
            }

            Button("Restart App") {
                restartApp()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No judgment - you can always come back!")
        }
    }

    private func restartApp() {
        UserDefaults.standard.set(false, forKey: "has_completed_onboarding")
        UserDefaults.standard.synchronize()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }
}

/// "I'm Overwhelmed" panic button
struct OverwhelmedButton: View {
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                Text("I'm stuck")
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.purple.opacity(0.8))
            .cornerRadius(25)
        }
        .sheet(isPresented: $showHelp) {
            OverwhelmedHelpView()
        }
    }
}

/// Help view when user is overwhelmed
struct OverwhelmedHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showBreathing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Calming header
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("It's okay to feel stuck")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Let's find one tiny thing you can do")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Options
                VStack(spacing: 16) {
                    OverwhelmedOption(
                        icon: "wind",
                        title: "Take 3 deep breaths",
                        subtitle: "Just 30 seconds",
                        color: .blue
                    ) {
                        showBreathing = true
                    }

                    OverwhelmedOption(
                        icon: "drop.fill",
                        title: "Drink some water",
                        subtitle: "Hydration helps",
                        color: .cyan
                    ) {
                        SpeechService.shared.queueSpeech("Just get some water. That's all you need to do right now.")
                        dismiss()
                    }

                    OverwhelmedOption(
                        icon: "figure.walk",
                        title: "Stand up and stretch",
                        subtitle: "Move your body",
                        color: .green
                    ) {
                        SpeechService.shared.queueSpeech("Stand up, stretch, look around. You've got this.")
                        dismiss()
                    }

                    OverwhelmedOption(
                        icon: "moon.fill",
                        title: "Take a break",
                        subtitle: "Come back later",
                        color: .indigo
                    ) {
                        SpeechService.shared.queueSpeech("Taking a break is okay. Rest now, tackle it later.")
                        dismiss()
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Reassurance
                Text("You're not failing. ADHD is hard.\nBeing here is already a win.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Need Help?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showBreathing) {
                BreathingExerciseView()
            }
        }
        .onAppear {
            SpeechService.shared.queueSpeech("It's okay. Let's find one small thing you can do right now.")
        }
    }
}

struct OverwhelmedOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

/// Simple breathing exercise
struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var breathPhase = 0 // 0: ready, 1: inhale, 2: hold, 3: exhale
    @State private var breathCount = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Breathing circle
            Circle()
                .fill(phaseColor.opacity(0.3))
                .frame(width: 200, height: 200)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: phaseDuration), value: scale)
                .overlay(
                    Text(phaseText)
                        .font(.title)
                        .fontWeight(.medium)
                )

            // Progress
            Text("Breath \(breathCount) of 3")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Done button
            if breathCount >= 3 {
                Button {
                    SpeechService.shared.queueSpeech("Great job! You did it. Feeling a bit better?")
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .onAppear {
            startBreathing()
        }
    }

    private var phaseText: String {
        switch breathPhase {
        case 0: return "Ready?"
        case 1: return "Breathe in..."
        case 2: return "Hold..."
        case 3: return "Breathe out..."
        default: return ""
        }
    }

    private var phaseColor: Color {
        switch breathPhase {
        case 1: return .blue
        case 2: return .purple
        case 3: return .green
        default: return .gray
        }
    }

    private var phaseDuration: Double {
        switch breathPhase {
        case 1: return 4.0
        case 2: return 4.0
        case 3: return 4.0
        default: return 1.0
        }
    }

    private func startBreathing() {
        // Start after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            runBreathCycle()
        }
    }

    private func runBreathCycle() {
        guard breathCount < 3 else { return }

        // Inhale
        breathPhase = 1
        scale = 1.5
        SpeechService.shared.queueSpeech("Breathe in")

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            // Hold
            breathPhase = 2
            SpeechService.shared.queueSpeech("Hold")

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                // Exhale
                breathPhase = 3
                scale = 1.0
                SpeechService.shared.queueSpeech("Breathe out")

                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    breathCount += 1
                    if breathCount < 3 {
                        runBreathCycle()
                    } else {
                        breathPhase = 0
                    }
                }
            }
        }
    }
}

/// Resume session prompt
struct ResumeSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let resumeInfo: (screen: String, progress: String)
    let onResume: () -> Void
    let onStartFresh: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            // Title
            Text("Welcome back!")
                .font(.title)
                .fontWeight(.bold)

            // Info
            VStack(spacing: 8) {
                Text("You were in the middle of:")
                    .foregroundStyle(.secondary)

                Text(resumeInfo.screen)
                    .font(.headline)

                Text(resumeInfo.progress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    onResume()
                    dismiss()
                } label: {
                    Text("Resume Where I Left Off")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button {
                    onStartFresh()
                    dismiss()
                } label: {
                    Text("Start Fresh")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding(.top, 60)
        .onAppear {
            SpeechService.shared.queueSpeech("Welcome back! Want to pick up where you left off?")
        }
    }
}

// MARK: - Previews

#Preview("Escape Bar") {
    UniversalEscapeBar()
        .environmentObject(AppState())
}

#Preview("Overwhelmed Help") {
    OverwhelmedHelpView()
}

#Preview("Breathing") {
    BreathingExerciseView()
}
