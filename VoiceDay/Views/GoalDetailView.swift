import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    @StateObject private var goalsService = GoalsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    private var currentGoal: Goal {
        goalsService.getGoal(byId: goal.id) ?? goal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with progress
                    headerSection

                    // Schedule
                    if currentGoal.dailyTimeMinutes != nil || currentGoal.preferredDays != nil {
                        scheduleSection
                    }

                    // Milestones
                    if !currentGoal.milestones.isEmpty {
                        milestonesSection
                    }

                    // Current tasks
                    if let milestone = currentGoal.currentMilestone, !milestone.suggestedTasks.isEmpty {
                        currentTasksSection(milestone: milestone)
                    }

                    // Stats
                    statsSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Color.themeBackground)
            .navigationTitle(currentGoal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete Goal", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    goalsService.deleteGoal(id: goal.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this goal? This action cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.themeSecondary, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: currentGoal.progressPercentage / 100)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: currentGoal.progressPercentage)

                VStack(spacing: 2) {
                    Text("\(Int(currentGoal.progressPercentage))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Description
            if let description = currentGoal.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Status badge
            HStack {
                Image(systemName: currentGoal.status.icon)
                Text(currentGoal.status.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(20)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schedule", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 20) {
                if let minutes = currentGoal.dailyTimeMinutes {
                    VStack(alignment: .leading) {
                        Text("Daily Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(minutes) min")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                if let days = currentGoal.preferredDays {
                    VStack(alignment: .leading) {
                        Text("Days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDays(days))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                if let target = currentGoal.targetDate {
                    VStack(alignment: .trailing) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(target.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            // Reminder info
            Text("Gadfly will remind you each morning and at your scheduled study time.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Milestones", systemImage: "flag.checkered")
                .font(.headline)

            ForEach(Array(currentGoal.milestones.enumerated()), id: \.element.id) { index, milestone in
                MilestoneRow(
                    milestone: milestone,
                    index: index,
                    isCurrent: index == currentGoal.currentMilestoneIndex,
                    onComplete: {
                        if let result = goalsService.completeMilestone(goalId: currentGoal.id, milestoneIndex: index) {
                            // Show celebration
                            print("Completed: \(result.completedMilestone.title)")
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Current Tasks

    private func currentTasksSection(milestone: Milestone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Focus: \(milestone.title)", systemImage: "list.bullet")
                .font(.headline)

            ForEach(milestone.suggestedTasks, id: \.self) { task in
                HStack {
                    Image(systemName: "circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(task)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            if let days = milestone.estimatedDays {
                Text("Estimated: \(days) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stats", systemImage: "chart.bar")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statItem(title: "Created", value: currentGoal.createdAt.formatted(date: .abbreviated, time: .omitted))
                statItem(title: "Last Progress", value: currentGoal.lastProgressUpdate.formatted(date: .abbreviated, time: .omitted))
                statItem(title: "Tasks Completed", value: "\(currentGoal.completedTaskCount)")
                statItem(title: "Days Since Progress", value: currentGoal.daysSinceLastProgress == 0 ? "Today" : "\(currentGoal.daysSinceLastProgress)d")
            }

            if currentGoal.daysSinceLastProgress >= 3 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(goalsService.getNeglectMessage(for: currentGoal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if currentGoal.status == .active {
                Button {
                    goalsService.recordProgress(goalId: currentGoal.id)
                } label: {
                    Label("Record Progress", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    goalsService.pauseGoal(id: currentGoal.id)
                } label: {
                    Label("Pause Goal", systemImage: "pause.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if currentGoal.status == .paused {
                Button {
                    goalsService.resumeGoal(id: currentGoal.id)
                } label: {
                    Label("Resume Goal", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Goal", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var progressColor: Color {
        switch currentGoal.progressPercentage {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        default: return .green
        }
    }

    private var statusColor: Color {
        switch currentGoal.status {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .abandoned: return .gray
        }
    }

    private func formatDays(_ days: [Int]) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.map { dayNames[$0] }.joined(separator: ", ")
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone
    let index: Int
    let isCurrent: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .stroke(borderColor, lineWidth: 2)
                    .frame(width: 32, height: 32)

                if milestone.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCurrent ? .blue : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .strikethrough(milestone.isCompleted)
                    .foregroundStyle(milestone.isCompleted ? .secondary : .primary)

                if let days = milestone.estimatedDays {
                    Text("\(days) days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isCurrent && !milestone.isCompleted {
                Button("Complete") {
                    onComplete()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if milestone.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrent && !milestone.isCompleted ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private var borderColor: Color {
        if milestone.isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return .secondary.opacity(0.5)
        }
    }
}

#Preview {
    GoalDetailView(goal: Goal(
        title: "Learn Real Analysis",
        description: "Master the foundations of mathematical analysis",
        milestones: [
            Milestone(title: "Sequences & Limits", estimatedDays: 14, suggestedTasks: ["Read Chapter 1", "Complete exercises"]),
            Milestone(title: "Series & Convergence", estimatedDays: 14, suggestedTasks: ["Study convergence tests"]),
            Milestone(title: "Continuity", estimatedDays: 14, suggestedTasks: ["Learn epsilon-delta"])
        ],
        dailyTimeMinutes: 45,
        preferredDays: [1, 2, 3, 4, 5, 6]
    ))
}
