import SwiftUI

// MARK: - Smart Scheduler View

/// Insights view showing productivity patterns and suggestions
struct SmartSchedulerView: View {
    @ObservedObject var scheduler = SmartScheduler.shared
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Learning status
                    if scheduler.isLearning {
                        learningCard
                    } else {
                        // Productivity chart
                        productivityChart

                        // Top hours
                        topHoursCard

                        // Category breakdown
                        categoryCard

                        // Suggestions
                        if !scheduler.suggestions.isEmpty {
                            suggestionsCard
                        }
                    }
                }
                .padding()
            }
            .background(themeColors.background)
            .navigationTitle("Smart Scheduling")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Learning Card

    private var learningCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(themeColors.accent)

            Text("Learning Your Patterns")
                .font(.title2.bold())
                .foregroundStyle(themeColors.text)

            Text("Complete more tasks and I'll learn when you're most productive for different types of work.")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)

            // Progress indicator
            ProgressView(value: 0.3)
                .tint(themeColors.accent)
                .padding(.horizontal, 40)

            Text("Need about 10 more completions")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeColors.secondary)
        )
    }

    // MARK: - Productivity Chart

    private var productivityChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Productivity by Hour")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            // Simple bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(6..<22) { hour in
                    let score = scheduler.productivityScore(for: hour)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: score))
                            .frame(width: 14, height: max(8, CGFloat(score * 100)))

                        if hour % 3 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }

    private func barColor(for score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .orange
    }

    // MARK: - Top Hours Card

    private var topHoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Power Hours")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            if scheduler.topProductiveHours.isEmpty {
                Text("Complete more tasks to discover your peak hours")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            } else {
                HStack(spacing: 12) {
                    ForEach(scheduler.topProductiveHours, id: \.self) { hour in
                        VStack(spacing: 4) {
                            Text(formatHour(hour))
                                .font(.title3.bold())
                                .foregroundStyle(themeColors.text)

                            Text(periodName(for: hour))
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeColors.accent.opacity(0.15))
                        )
                    }
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

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour > 12 { return "\(hour - 12) PM" }
        return "\(hour) AM"
    }

    private func periodName(for hour: Int) -> String {
        switch hour {
        case 5..<9: return "Early morning"
        case 9..<12: return "Morning"
        case 12..<14: return "Midday"
        case 14..<17: return "Afternoon"
        case 17..<20: return "Evening"
        default: return "Night"
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Breakdown")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            let breakdown = scheduler.categoryBreakdown
            let sorted = breakdown.sorted { $0.value > $1.value }

            ForEach(sorted.prefix(5), id: \.key) { category, count in
                HStack {
                    Image(systemName: category.icon)
                        .frame(width: 24)
                        .foregroundStyle(themeColors.accent)

                    Text(category.displayName)
                        .foregroundStyle(themeColors.text)

                    Spacer()

                    Text("\(count)")
                        .foregroundStyle(themeColors.subtext)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduling Suggestions")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            ForEach(scheduler.suggestions) { suggestion in
                HStack {
                    Image(systemName: suggestion.category.icon)
                        .frame(width: 24)
                        .foregroundStyle(themeColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.taskTitle)
                            .font(.subheadline)
                            .foregroundStyle(themeColors.text)

                        Text(suggestion.reason)
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }

                    Spacer()

                    Text(suggestion.suggestedTime, style: .time)
                        .font(.caption.bold())
                        .foregroundStyle(themeColors.accent)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
    }
}

// MARK: - Scheduling Suggestion Row

struct ScheduleSuggestionRow: View {
    let suggestion: SmartScheduler.ScheduleSuggestion
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.category.icon)
                .font(.title3)
                .foregroundStyle(themeColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.taskTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(themeColors.text)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(suggestion.suggestedTime, style: .time)
                        .font(.caption)
                }
                .foregroundStyle(themeColors.subtext)

                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(themeColors.accent)
            }

            Spacer()

            // Confidence indicator
            Image(systemName: confidenceIcon)
                .foregroundStyle(confidenceColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColors.secondary)
        )
    }

    private var confidenceIcon: String {
        switch suggestion.confidence {
        case .high: return "checkmark.seal.fill"
        case .medium: return "checkmark.circle"
        case .low: return "questionmark.circle"
        }
    }

    private var confidenceColor: Color {
        switch suggestion.confidence {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .gray
        }
    }
}

// MARK: - Preview

#Preview("Smart Scheduler") {
    SmartSchedulerView()
}
