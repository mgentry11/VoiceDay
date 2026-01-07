import SwiftUI

/// Large floating button for Hyperfocus Mode
/// Shows timer and changes color based on duration
struct HyperfocusButtonView: View {
    @ObservedObject var hyperfocusService = HyperfocusModeService.shared

    var body: some View {
        Button {
            hyperfocusService.toggle()
        } label: {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: hyperfocusService.isActive ? "lock.fill" : "scope")
                    .font(.title3)

                // Text
                Text(hyperfocusService.isActive ? "Focused" : "Hyperfocusing")
                    .fontWeight(.semibold)

                // Timer (only when active)
                if hyperfocusService.isActive {
                    Text(hyperfocusService.timerDisplayString)
                        .font(.callout.monospacedDigit())
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: hyperfocusService.currentStage.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(
                color: hyperfocusService.currentStage.color.opacity(0.4),
                radius: hyperfocusService.isActive ? 12 : 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: hyperfocusService.isActive)
        .animation(.easeInOut(duration: 0.5), value: hyperfocusService.currentStage)
        .scaleEffect(hyperfocusService.isActive ? 1.02 : 1.0)
        .animation(
            hyperfocusService.isActive ?
            .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
            .default,
            value: hyperfocusService.isActive
        )
    }
}

/// Compact version for the navigation bar
struct HyperfocusButtonCompact: View {
    @ObservedObject var hyperfocusService = HyperfocusModeService.shared

    var body: some View {
        Button {
            hyperfocusService.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: hyperfocusService.isActive ? "lock.fill" : "scope")
                    .font(.caption)

                if hyperfocusService.isActive {
                    Text(hyperfocusService.timerDisplayString)
                        .font(.caption.monospacedDigit())
                }
            }
            .foregroundStyle(hyperfocusService.isActive ? .white : hyperfocusService.currentStage.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        hyperfocusService.isActive ?
                        LinearGradient(
                            colors: hyperfocusService.currentStage.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [hyperfocusService.currentStage.color.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Hyperfocus Button - Inactive") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            HyperfocusButtonView()
                .padding(.bottom, 40)
        }
    }
}

#Preview("Hyperfocus Button - Active") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            HyperfocusButtonView()
                .padding(.bottom, 40)
                .onAppear {
                    HyperfocusModeService.shared.isActive = true
                    HyperfocusModeService.shared.currentStage = .stage2
                    HyperfocusModeService.shared.elapsedSeconds = 1845
                }
        }
    }
}

#Preview("Compact Button") {
    HStack {
        HyperfocusButtonCompact()
        HyperfocusButtonCompact()
            .onAppear {
                HyperfocusModeService.shared.isActive = true
                HyperfocusModeService.shared.currentStage = .stage4
                HyperfocusModeService.shared.elapsedSeconds = 5523
            }
    }
    .padding()
}
