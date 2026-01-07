import SwiftUI

// MARK: - Time Ring View

/// Visual circular countdown for ADHD time blindness
/// Makes time visible and tangible, not just a number
struct TimeRingView: View {
    let deadline: Date
    let taskTitle: String
    let totalDuration: TimeInterval  // Expected task duration

    @State private var progress: Double = 1.0
    @State private var timeRemaining: TimeInterval = 0
    @ObservedObject private var themeColors = ThemeColors.shared

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    ringColor.opacity(0.2),
                    lineWidth: 12
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Center content
            VStack(spacing: 4) {
                // Time display
                Text(timeString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ringColor)

                // Label
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                // Urgency indicator
                if urgencyLevel != .comfortable {
                    HStack(spacing: 4) {
                        Image(systemName: urgencyIcon)
                            .font(.caption2)
                        Text(urgencyMessage)
                            .font(.caption2)
                    }
                    .foregroundStyle(ringColor)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear { updateTime() }
        .onReceive(timer) { _ in updateTime() }
    }

    // MARK: - Time Calculations

    private func updateTime() {
        timeRemaining = deadline.timeIntervalSinceNow

        if totalDuration > 0 {
            // Progress based on task duration
            let elapsed = totalDuration - timeRemaining
            progress = max(0, min(1, 1 - (elapsed / totalDuration)))
        } else {
            // Default: progress based on time remaining
            let maxDisplay: TimeInterval = 3600 // Show up to 1 hour on ring
            progress = max(0, min(1, timeRemaining / maxDisplay))
        }
    }

    private var timeString: String {
        if timeRemaining < 0 {
            let overdue = abs(timeRemaining)
            let mins = Int(overdue) / 60
            let secs = Int(overdue) % 60
            return String(format: "-%d:%02d", mins, secs)
        }

        let hours = Int(timeRemaining) / 3600
        let mins = (Int(timeRemaining) % 3600) / 60
        let secs = Int(timeRemaining) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }

    private var timeLabel: String {
        if timeRemaining < 0 {
            return "overdue"
        } else if timeRemaining < 60 {
            return "seconds left"
        } else if timeRemaining < 3600 {
            return "minutes left"
        } else {
            return "until deadline"
        }
    }

    // MARK: - Urgency Levels

    private enum UrgencyLevel {
        case comfortable  // > 30 min
        case attention    // 15-30 min
        case urgent       // 5-15 min
        case critical     // < 5 min
        case overdue      // past deadline
    }

    private var urgencyLevel: UrgencyLevel {
        switch timeRemaining {
        case ..<0: return .overdue
        case 0..<300: return .critical      // < 5 min
        case 300..<900: return .urgent      // 5-15 min
        case 900..<1800: return .attention  // 15-30 min
        default: return .comfortable        // > 30 min
        }
    }

    private var ringColor: Color {
        switch urgencyLevel {
        case .comfortable: return themeColors.success
        case .attention: return .yellow
        case .urgent: return .orange
        case .critical, .overdue: return themeColors.priorityHigh
        }
    }

    private var gradientColors: [Color] {
        switch urgencyLevel {
        case .comfortable: return [themeColors.success, .mint]
        case .attention: return [.yellow, .orange]
        case .urgent: return [.orange, .red]
        case .critical, .overdue: return [.red, .pink]
        }
    }

    private var urgencyIcon: String {
        switch urgencyLevel {
        case .comfortable: return "clock"
        case .attention: return "clock.badge"
        case .urgent: return "clock.badge.exclamationmark"
        case .critical: return "exclamationmark.triangle"
        case .overdue: return "xmark.circle"
        }
    }

    private var urgencyMessage: String {
        switch urgencyLevel {
        case .comfortable: return ""
        case .attention: return "Getting close"
        case .urgent: return "Hurry up!"
        case .critical: return "Almost out of time!"
        case .overdue: return "Past deadline"
        }
    }
}

// MARK: - Compact Time Ring

/// Smaller time ring for inline use
struct CompactTimeRing: View {
    let deadline: Date

    @State private var progress: Double = 1.0
    @State private var timeRemaining: TimeInterval = 0
    @ObservedObject private var themeColors = ThemeColors.shared

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(shortTimeString)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ringColor)
        }
        .frame(width: 44, height: 44)
        .onAppear { updateTime() }
        .onReceive(timer) { _ in updateTime() }
    }

    private func updateTime() {
        timeRemaining = deadline.timeIntervalSinceNow
        let maxDisplay: TimeInterval = 3600
        progress = max(0, min(1, timeRemaining / maxDisplay))
    }

    private var shortTimeString: String {
        if timeRemaining < 0 {
            return "!"
        }
        let mins = Int(timeRemaining) / 60
        if mins >= 60 {
            return "\(mins / 60)h"
        }
        return "\(mins)m"
    }

    private var ringColor: Color {
        switch timeRemaining {
        case ..<0: return themeColors.priorityHigh
        case 0..<300: return themeColors.priorityHigh
        case 300..<900: return .orange
        case 900..<1800: return .yellow
        default: return themeColors.success
        }
    }
}

// MARK: - Time Ring Card

/// Full card with time ring and task info
struct TimeRingCard: View {
    let deadline: Date
    let taskTitle: String
    let estimatedMinutes: Int?
    let onComplete: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(spacing: 16) {
            // Task title
            Text(taskTitle)
                .font(.headline)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Time ring
            TimeRingView(
                deadline: deadline,
                taskTitle: taskTitle,
                totalDuration: TimeInterval((estimatedMinutes ?? 30) * 60)
            )
            .frame(width: 160, height: 160)

            // Complete button
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColors.success)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeColors.secondary)
        )
    }
}

// MARK: - Preview

#Preview("Time Ring") {
    VStack(spacing: 24) {
        TimeRingView(
            deadline: Date().addingTimeInterval(1800), // 30 min
            taskTitle: "Write report",
            totalDuration: 3600
        )
        .frame(width: 200, height: 200)

        HStack(spacing: 16) {
            CompactTimeRing(deadline: Date().addingTimeInterval(300))
            CompactTimeRing(deadline: Date().addingTimeInterval(1800))
            CompactTimeRing(deadline: Date().addingTimeInterval(7200))
        }
    }
    .padding()
}

#Preview("Time Ring Card") {
    TimeRingCard(
        deadline: Date().addingTimeInterval(1200),
        taskTitle: "Complete project review",
        estimatedMinutes: 30,
        onComplete: {}
    )
    .padding()
}
