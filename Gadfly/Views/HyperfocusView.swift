import SwiftUI

/// Dedicated Hyperfocus Mode page with a giant, easy-to-tap button
/// Designed for ADHD users - minimal distractions, maximum clarity
struct HyperfocusView: View {
    @ObservedObject private var hyperfocusService = HyperfocusModeService.shared
    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Background gradient based on stage
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Status text
                statusText

                // Giant circular button
                giantButton

                // Timer display (when active)
                if hyperfocusService.isActive {
                    timerDisplay
                }

                Spacer()

                // Helpful tip at bottom
                tipText
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
        }
        .navigationTitle("Hyperfocus")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: hyperfocusService.isActive
                ? [
                    hyperfocusService.currentStage.gradientColors[0].opacity(0.3),
                    hyperfocusService.currentStage.gradientColors[1].opacity(0.1),
                    Color.black
                ]
                : [Color.black, Color.black.opacity(0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 12) {
            Text(hyperfocusService.isActive ? "You're in the zone" : "Ready to focus?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(hyperfocusService.isActive
                 ? "All reminders paused. Tap when you're done."
                 : "Tap the button to enter hyperfocus mode")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Giant Button

    private var giantButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                hyperfocusService.toggle()
            }
        } label: {
            ZStack {
                // Outer glow ring (animated when active)
                Circle()
                    .stroke(
                        hyperfocusService.currentStage.color.opacity(0.3),
                        lineWidth: hyperfocusService.isActive ? 20 : 0
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(hyperfocusService.isActive ? 1.1 : 1.0)
                    .animation(
                        hyperfocusService.isActive
                            ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                            : .default,
                        value: hyperfocusService.isActive
                    )

                // Main button circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: hyperfocusService.isActive
                                ? hyperfocusService.currentStage.gradientColors
                                : [Color(white: 0.15), Color(white: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .shadow(
                        color: hyperfocusService.isActive
                            ? hyperfocusService.currentStage.color.opacity(0.5)
                            : .clear,
                        radius: 30,
                        x: 0,
                        y: 10
                    )

                // Inner content
                VStack(spacing: 8) {
                    // Icon
                    Image(systemName: hyperfocusService.isActive ? "lock.fill" : "scope")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(.white)

                    // Label
                    Text(hyperfocusService.isActive ? "FOCUSED" : "START")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(2)
                }
            }
        }
        .buttonStyle(GiantButtonStyle())
        .sensoryFeedback(.impact(weight: .heavy), trigger: hyperfocusService.isActive)
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(hyperfocusService.timerDisplayString)
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .foregroundStyle(.white)

            Text(stageMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(hyperfocusService.currentStage.color)
                .animation(.easeInOut, value: hyperfocusService.currentStage)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var stageMessage: String {
        switch hyperfocusService.currentStage {
        case .none, .stage1: return "Just getting started"
        case .stage2: return "Great momentum!"
        case .stage3: return "Amazing focus session"
        case .stage4: return "Consider a break soon"
        case .stage5: return "You should take a break"
        }
    }

    // MARK: - Tip Text

    private var tipText: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow.opacity(0.8))

            Text(hyperfocusService.isActive
                 ? "Button color changes as time passes"
                 : "Hyperfocus pauses all reminders")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Giant Button Style

struct GiantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Hyperfocus - Inactive") {
    NavigationStack {
        HyperfocusView()
    }
}

#Preview("Hyperfocus - Active") {
    NavigationStack {
        HyperfocusView()
            .onAppear {
                HyperfocusModeService.shared.isActive = true
                HyperfocusModeService.shared.elapsedSeconds = 2534
                HyperfocusModeService.shared.currentStage = .stage2
            }
    }
}
