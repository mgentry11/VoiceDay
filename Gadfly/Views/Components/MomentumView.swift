import SwiftUI

// MARK: - Momentum Meter View

/// Visual momentum meter replacing streak counters
/// Shows current momentum level with encouraging, non-punishing UI
struct MomentumMeterView: View {
    @ObservedObject var tracker = MomentumTracker.shared

    var body: some View {
        VStack(spacing: 8) {
            // Level indicator with icon
            HStack(spacing: 6) {
                Image(systemName: tracker.currentLevel.icon)
                    .foregroundStyle(tracker.currentLevel.color)

                Text(tracker.currentLevel.displayName)
                    .font(.headline)
                    .foregroundStyle(tracker.currentLevel.color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (tracker.momentum / 100))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tracker.momentum)
                }
            }
            .frame(height: 12)

            // Today's count
            if tracker.todayCompleted > 0 {
                Text("\(tracker.todayCompleted) done today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gradientColors: [Color] {
        switch tracker.currentLevel {
        case .excellent:
            return [.orange, .red]
        case .good:
            return [.green, .mint]
        case .moderate:
            return [.blue, .cyan]
        case .needsWork:
            return [.yellow, .orange]
        case .building:
            return [.purple, .pink]
        }
    }
}

// MARK: - Compact Momentum Badge

/// Small momentum indicator for nav bars or compact spaces
struct MomentumBadge: View {
    @ObservedObject var tracker = MomentumTracker.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tracker.currentLevel.icon)
                .font(.caption)
            Text("\(Int(tracker.momentum))")
                .font(.caption.monospacedDigit())
        }
        .foregroundStyle(tracker.currentLevel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tracker.currentLevel.color.opacity(0.15))
        )
    }
}

// MARK: - Momentum Card

/// Full momentum display with encouragement message
struct MomentumCard: View {
    @ObservedObject var tracker = MomentumTracker.shared
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Momentum")
                    .font(.headline)
                    .foregroundStyle(themeColors.text)

                Spacer()

                MomentumBadge()
            }

            // Meter
            MomentumMeterView()

            // Encouragement
            Text(tracker.currentLevel.encouragement)
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }
}

// MARK: - Animated Momentum Gain

/// Shows animated momentum gain when completing a task
struct MomentumGainView: View {
    let points: Double
    @State private var show = false

    var body: some View {
        if points > 0 {
            Text("+\(Int(points))")
                .font(.title3.bold())
                .foregroundStyle(.green)
                .scaleEffect(show ? 1.2 : 0.8)
                .opacity(show ? 1 : 0)
                .offset(y: show ? -30 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        show = true
                    }
                }
        }
    }
}

// MARK: - Level Up Celebration

/// Overlay shown when user levels up their momentum
struct MomentumLevelUpView: View {
    let newLevel: MomentumTracker.MomentumLevel
    @Binding var isShowing: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        if isShowing {
            VStack(spacing: 16) {
                Image(systemName: newLevel.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(newLevel.color)

                Text("Level Up!")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text(newLevel.displayName)
                    .font(.title2)
                    .foregroundStyle(newLevel.color)

                Text(newLevel.encouragement)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }

                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 0
                        scale = 0.8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Momentum Meter") {
    VStack(spacing: 20) {
        MomentumMeterView()
            .padding()

        MomentumBadge()

        MomentumCard()
            .padding()
    }
}

#Preview("Level Up") {
    MomentumLevelUpView(newLevel: .good, isShowing: .constant(true))
}
