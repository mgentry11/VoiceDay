import SwiftUI

// MARK: - Medication Window View

/// Privacy-first focus window tracker
/// No medication names stored - just timing data
struct MedicationWindowView: View {
    @ObservedObject var windowService = MedicationWindowService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingSettings = false
    @State private var showingEndConfirmation = false
    @State private var selectedRating: MedicationWindowService.WindowLog.ProductivityRating?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current state card
                    currentStateCard

                    // Action button
                    actionButton

                    // Recommendation
                    recommendationCard

                    // Statistics (if has history)
                    if windowService.averagePeakDuration != nil {
                        statisticsCard
                    }

                    // Privacy note
                    privacyNote
                }
                .padding()
            }
            .background(themeColors.background)
            .navigationTitle("Focus Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                WindowSettingsView()
            }
            .confirmationDialog(
                "End Focus Window",
                isPresented: $showingEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("Poor Focus") {
                    windowService.endWindow(productivity: .poor)
                }
                Button("Fair Focus") {
                    windowService.endWindow(productivity: .fair)
                }
                Button("Good Focus") {
                    windowService.endWindow(productivity: .good)
                }
                Button("Excellent Focus") {
                    windowService.endWindow(productivity: .excellent)
                }
                Button("Skip Rating", role: .cancel) {
                    windowService.endWindow()
                }
            } message: {
                Text("How was your focus during this window?")
            }
        }
    }

    // MARK: - Current State Card

    private var currentStateCard: some View {
        VStack(spacing: 16) {
            // State icon
            ZStack {
                Circle()
                    .fill(windowService.currentWindow.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: windowService.currentWindow.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(windowService.currentWindow.color)
            }

            // State name
            Text(windowService.currentWindow.displayName)
                .font(.title2.bold())
                .foregroundStyle(themeColors.text)

            // Time remaining
            if let timeString = windowService.timeRemainingString {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text("\(timeString) remaining")
                }
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
            }

            // Progress bar (if in active window)
            if windowService.windowStartTime != nil {
                windowProgressBar
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeColors.secondary)
        )
    }

    private var windowProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeColors.subtext.opacity(0.2))

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progressPercentage)
                    .animation(.linear(duration: 1), value: progressPercentage)
            }
        }
        .frame(height: 8)
    }

    private var progressPercentage: Double {
        guard let start = windowService.windowStartTime else { return 0 }
        let totalDuration = TimeInterval(windowService.config.totalDurationMinutes * 60)
        let elapsed = Date().timeIntervalSince(start)
        return min(1, max(0, elapsed / totalDuration))
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if windowService.windowStartTime == nil {
                Button {
                    windowService.startWindow()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Focus Window")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
                }
            } else {
                Button {
                    showingEndConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Window")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange)
                    )
                }
            }
        }
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Recommendation")
                    .font(.headline)
            }
            .foregroundStyle(themeColors.text)

            Text(windowService.currentWindow.taskRecommendation)
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }

    // MARK: - Statistics Card

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Patterns")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            HStack(spacing: 24) {
                if let avgPeak = windowService.averagePeakDuration {
                    StatItem(
                        label: "Avg Peak",
                        value: "\(Int(avgPeak / 60))m",
                        icon: "bolt.fill"
                    )
                }

                if let avgProd = windowService.averageProductivity {
                    StatItem(
                        label: "Avg Focus",
                        value: String(format: "%.1f/4", avgProd),
                        icon: "star.fill"
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.green)
            Text("Your data stays on this device. No medication names are stored.")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColors.secondary.opacity(0.5))
        )
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title3.bold())
            }
            .foregroundStyle(themeColors.text)

            Text(label)
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
        }
    }
}

// MARK: - Window Settings View

struct WindowSettingsView: View {
    @ObservedObject var windowService = MedicationWindowService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Focus Window Tracking", isOn: $windowService.isEnabled)
                } footer: {
                    Text("Track your focus periods to get personalized task recommendations.")
                }

                if windowService.isEnabled {
                    Section {
                        Stepper(
                            "Peak Duration: \(windowService.config.peakDurationMinutes) min",
                            value: $windowService.config.peakDurationMinutes,
                            in: 60...360,
                            step: 30
                        )

                        Stepper(
                            "Total Duration: \(windowService.config.totalDurationMinutes) min",
                            value: $windowService.config.totalDurationMinutes,
                            in: 120...720,
                            step: 30
                        )
                    } header: {
                        Text("Window Duration")
                    } footer: {
                        Text("Set how long your typical focus window lasts. Peak is when you're most effective.")
                    }

                    Section {
                        Toggle("Remind Before Peak Ends", isOn: $windowService.config.reminderEnabled)

                        if windowService.config.reminderEnabled {
                            Stepper(
                                "\(windowService.config.reminderMinutesBefore) min before",
                                value: $windowService.config.reminderMinutesBefore,
                                in: 5...60,
                                step: 5
                            )
                        }
                    } header: {
                        Text("Reminders")
                    }
                }
            }
            .navigationTitle("Focus Window Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Compact Window Badge

/// Small badge for displaying current window state
struct WindowBadge: View {
    @ObservedObject var windowService = MedicationWindowService.shared

    var body: some View {
        if windowService.isEnabled {
            HStack(spacing: 4) {
                Image(systemName: windowService.currentWindow.icon)
                    .font(.caption2)
                if let time = windowService.timeRemainingString {
                    Text(time)
                        .font(.caption2)
                }
            }
            .foregroundStyle(windowService.currentWindow.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(windowService.currentWindow.color.opacity(0.15))
            )
        }
    }
}

// MARK: - Preview

#Preview("Medication Window") {
    MedicationWindowView()
}

#Preview("Window Badge") {
    WindowBadge()
        .padding()
}
