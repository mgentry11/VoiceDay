import SwiftUI

struct GoalsView: View {
    @StateObject private var goalsService = GoalsService.shared
    @StateObject private var accountabilityTracker = AccountabilityTracker.shared
    @StateObject private var speechService = SpeechService()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var calendarService = CalendarService()
    @EnvironmentObject var appState: AppState
    @State private var selectedGoal: Goal?
    @State private var showingStats = false

    // Voice command state
    @State private var isVoiceActive = false
    @State private var voiceStatusMessage = ""
    @State private var isProcessingVoice = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBackground.ignoresSafeArea()

                if goalsService.goals.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Progress overview card
                            progressOverviewCard

                            // Active goals
                            if !goalsService.activeGoals.isEmpty {
                                goalsSection(title: "Active Goals", goals: goalsService.activeGoals)
                            }

                            // Paused goals
                            if !goalsService.pausedGoals.isEmpty {
                                goalsSection(title: "Paused", goals: goalsService.pausedGoals)
                            }

                            // Completed goals
                            if !goalsService.completedGoals.isEmpty {
                                goalsSection(title: "Completed", goals: goalsService.completedGoals)
                            }
                        }
                        .padding()
                    }
                }

                // Voice status banner
                if isVoiceActive || isProcessingVoice {
                    VStack {
                        VoiceStatusBanner(
                            isListening: isVoiceActive && !isProcessingVoice,
                            isProcessing: isProcessingVoice,
                            message: voiceStatusMessage,
                            transcription: speechService.transcribedText
                        )
                        Spacer()
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Microphone button
                    Button {
                        toggleVoiceCommand()
                    } label: {
                        Image(systemName: isVoiceActive ? "mic.fill" : "mic")
                            .font(.title3)
                            .foregroundStyle(isVoiceActive ? Color.red : Color.themeAccent)
                            .symbolEffect(.pulse, isActive: isVoiceActive)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
            }
            .sheet(isPresented: $showingStats) {
                AccountabilityStatsView()
            }
        }
    }

    // MARK: - Voice Commands

    private func toggleVoiceCommand() {
        if isVoiceActive {
            stopListeningAndProcess()
        } else {
            startListening()
        }
    }

    private func startListening() {
        do {
            try speechService.startListening()
            isVoiceActive = true
            voiceStatusMessage = "Listening..."
        } catch {
            voiceStatusMessage = "Microphone error"
            isVoiceActive = false
        }
    }

    private func stopListeningAndProcess() {
        speechService.stopListening()
        isVoiceActive = false

        let transcription = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            voiceStatusMessage = ""
            return
        }

        Task {
            await processVoiceCommand(transcription)
        }
    }

    private func processVoiceCommand(_ transcription: String) async {
        voiceStatusMessage = "Processing..."
        isProcessingVoice = true

        do {
            print("🎯 Goals voice command: \(transcription)")
            let result = try await openAIService.processUserInput(transcription, apiKey: appState.claudeKey, personality: appState.selectedPersonality)

            // Handle goals
            if !result.goals.isEmpty {
                for goal in result.goals {
                    goalsService.addGoal(goal)
                }
                voiceStatusMessage = result.summary ?? "Goal added!"
            }
            // Handle goal operations
            else if !result.goalOperations.isEmpty {
                for op in result.goalOperations {
                    handleGoalOperation(op)
                }
                voiceStatusMessage = result.summary ?? "Done!"
            }
            // Handle tasks/events/reminders too
            else if !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty {
                let _ = try await calendarService.saveAllItems(from: result)
                voiceStatusMessage = result.summary ?? "Items saved!"
            }
            else {
                voiceStatusMessage = result.summary ?? "Got it!"
            }

            // Speak the response
            if let summary = result.summary {
                await AppDelegate.shared?.speakMessage(summary)
            }

            // Clear after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isProcessingVoice = false
                voiceStatusMessage = ""
            }

        } catch {
            voiceStatusMessage = "Error: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isProcessingVoice = false
                voiceStatusMessage = ""
            }
        }
    }

    private func handleGoalOperation(_ op: GoalOperationDTO) {
        switch op.action {
        case "progress":
            if let title = op.goalTitle, let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(title.lowercased()) }) {
                goalsService.recordProgress(goalId: goal.id)
            }
        case "complete_milestone":
            if let title = op.goalTitle, let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(title.lowercased()) }) {
                let index = op.milestoneIndex ?? goal.currentMilestoneIndex
                _ = goalsService.completeMilestone(goalId: goal.id, milestoneIndex: index)
            }
        case "pause":
            if let title = op.goalTitle, let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(title.lowercased()) }) {
                goalsService.pauseGoal(id: goal.id)
            }
        case "resume":
            if let title = op.goalTitle, let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(title.lowercased()) }) {
                goalsService.resumeGoal(id: goal.id)
            }
        default:
            break
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(Color.themeAccent.opacity(0.5))

            Text("No Goals Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Say something like:\n\"My goal is to learn real analysis\"\nor \"I want to get fit by summer\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("Gadfly will:")
                    .font(.caption)
                    .fontWeight(.semibold)
                ForEach(["Break it into milestones", "Suggest a daily schedule", "Remind you every morning", "Track your progress"], id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(item)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.themeSecondary.opacity(0.3))
            .cornerRadius(12)
        }
    }

    // MARK: - Progress Overview

    private var progressOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Your Progress")
                        .font(.headline)
                    Text(motivationalMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Overall completion ring
                ZStack {
                    Circle()
                        .stroke(Color.themeSecondary, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(overallProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            // Stats row
            HStack(spacing: 20) {
                statItem(value: "\(goalsService.activeGoals.count)", label: "Active", color: .blue)
                statItem(value: "\(totalMilestonesCompleted)", label: "Milestones", color: .green)
                statItem(value: "\(accountabilityTracker.todayStats.tasksCompleted)", label: "Tasks Today", color: .orange)
                statItem(value: streakText, label: "Focus", color: progressColor)
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Goals Section

    private func goalsSection(title: String, goals: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(goals) { goal in
                GoalCard(goal: goal)
                    .onTapGesture {
                        selectedGoal = goal
                    }
            }
        }
    }

    // MARK: - Computed Properties

    private var overallProgress: Double {
        let activeGoals = goalsService.activeGoals
        guard !activeGoals.isEmpty else { return 0 }
        let total = activeGoals.reduce(0.0) { $0 + $1.progressPercentage }
        return (total / Double(activeGoals.count)) / 100.0
    }

    private var totalMilestonesCompleted: Int {
        goalsService.goals.reduce(0) { $0 + $1.completedMilestonesCount }
    }

    private var progressColor: Color {
        switch overallProgress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        default: return .green
        }
    }

    private var streakText: String {
        let level = accountabilityTracker.currentEscalationLevel
        switch level {
        case 0: return "Great"
        case 1: return "Good"
        case 2: return "Fair"
        case 3: return "Needs Work"
        default: return "Critical"
        }
    }

    private var motivationalMessage: String {
        let neglectedGoals = goalsService.goalsNeedingAttention
        let escalation = accountabilityTracker.currentEscalationLevel

        if neglectedGoals.isEmpty && escalation <= 1 {
            return "You're doing great! Keep up the momentum."
        } else if let goal = goalsService.mostNeglectedGoal, goal.daysSinceLastProgress >= 3 {
            return "'\(goal.title)' needs attention - \(goal.daysSinceLastProgress) days idle"
        } else if escalation >= 3 {
            return "Focus is slipping. Time to recommit to your goals."
        } else {
            return "Stay consistent. Every day counts."
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let milestone = goal.currentMilestone {
                        Text("Current: \(milestone.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status badge
                statusBadge
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: goal.progressPercentage / 100)
                    .tint(progressColor)

                HStack {
                    Text("\(goal.completedMilestonesCount)/\(goal.milestones.count) milestones")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(goal.progressPercentage))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(progressColor)
                }
            }

            // Schedule & neglect info
            HStack {
                if !goal.scheduleDescription.isEmpty {
                    Label(goal.scheduleDescription, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if goal.daysSinceLastProgress > 0 && goal.status == .active {
                    Text("\(goal.daysSinceLastProgress)d idle")
                        .font(.caption2)
                        .foregroundStyle(neglectColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(neglectColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(12)
    }

    private var statusBadge: some View {
        Image(systemName: goal.status.icon)
            .font(.title3)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch goal.status {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .abandoned: return .gray
        }
    }

    private var progressColor: Color {
        switch goal.progressPercentage {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        default: return .green
        }
    }

    private var neglectColor: Color {
        switch goal.neglectLevel {
        case 0...1: return .secondary
        case 2...3: return .orange
        default: return .red
        }
    }
}

// MARK: - Accountability Stats View

struct AccountabilityStatsView: View {
    @StateObject private var tracker = AccountabilityTracker.shared
    @StateObject private var goalsService = GoalsService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header message
                    headerMessage

                    // Today's stats
                    todayStatsCard

                    // Goal progress chart
                    goalProgressCard

                    // Weekly summary
                    if !tracker.weeklyStats.isEmpty {
                        weeklySummaryCard
                    }
                }
                .padding()
            }
            .background(Color.themeBackground)
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerMessage: some View {
        VStack(spacing: 8) {
            Image(systemName: isDoingWell ? "star.fill" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(isDoingWell ? .yellow : .orange)

            Text(isDoingWell ? "You're Making Progress!" : "Time to Refocus")
                .font(.title2)
                .fontWeight(.bold)

            Text(motivationalText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var todayStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statBox(title: "Time in App", value: formatTime(tracker.todayStats.timeInApp), icon: "hourglass", color: .blue)
                statBox(title: "Tasks Done", value: "\(tracker.todayStats.tasksCompleted)", icon: "checkmark.circle", color: .green)
                statBox(title: "Goals Progressed", value: "\(tracker.todayStats.goalsProgressed)", icon: "target", color: .purple)
                statBox(title: "Focus Level", value: focusLevel, icon: "brain.head.profile", color: focusColor)
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.themeBackground)
        .cornerRadius(12)
    }

    private var goalProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Progress")
                .font(.headline)

            ForEach(goalsService.activeGoals) { goal in
                HStack {
                    Text(goal.title)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    ProgressView(value: goal.progressPercentage / 100)
                        .frame(width: 100)
                        .tint(goalColor(for: goal))

                    Text("\(Int(goal.progressPercentage))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            if goalsService.activeGoals.isEmpty {
                Text("No active goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            Text(tracker.getWeeklySummary())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.themeSecondary.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var isDoingWell: Bool {
        tracker.currentEscalationLevel <= 1 && goalsService.goalsNeedingAttention.isEmpty
    }

    private var motivationalText: String {
        if isDoingWell {
            return "Keep up the great work! Consistency is the key to achieving your goals."
        } else if let neglected = goalsService.mostNeglectedGoal {
            return "'\(neglected.title)' has been neglected for \(neglected.daysSinceLastProgress) days. Every day away from your goal is a day lost."
        } else {
            return "Time to get back on track. Your future self will thank you."
        }
    }

    private var focusLevel: String {
        switch tracker.currentEscalationLevel {
        case 0: return "Excellent"
        case 1: return "Good"
        case 2: return "Fair"
        case 3: return "Needs Work"
        case 4: return "Poor"
        default: return "Critical"
        }
    }

    private var focusColor: Color {
        switch tracker.currentEscalationLevel {
        case 0: return .green
        case 1: return .blue
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }

    private func goalColor(for goal: Goal) -> Color {
        if goal.daysSinceLastProgress >= 7 {
            return .red
        } else if goal.daysSinceLastProgress >= 3 {
            return .orange
        } else {
            return .green
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    GoalsView()
        .environmentObject(AppState())
}

// MARK: - GoalDetailView Consolidated

struct GoalDetailView: View {
    let goal: Goal
    @StateObject private var goalsService = GoalsService.shared
    @Environment(\.dismiss) private var dismiss
    private var currentGoal: Goal { goalsService.getGoal(byId: goal.id) ?? goal }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(Color.themeSecondary, lineWidth: 12).frame(width: 120, height: 120)
                            Circle().trim(from: 0, to: currentGoal.progressPercentage / 100).stroke(Color.themeAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round)).frame(width: 120, height: 120).rotationEffect(.degrees(-90))
                            Text("\(Int(currentGoal.progressPercentage))%").font(.title).bold()
                        }
                        if let desc = currentGoal.description { Text(desc).font(.subheadline).foregroundStyle(.secondary) }
                    }.padding().background(Color.themeSecondary.opacity(0.3)).cornerRadius(16)
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Milestones", systemImage: "flag.checkered").font(.headline)
                        ForEach(Array(currentGoal.milestones.enumerated()), id: \.element.id) { index, milestone in
                            MilestoneRow(milestone: milestone, index: index, isCurrent: index == currentGoal.currentMilestoneIndex) {
                                _ = goalsService.completeMilestone(goalId: currentGoal.id, milestoneIndex: index)
                            }
                        }
                    }.padding().background(Color.themeSecondary.opacity(0.3)).cornerRadius(16)
                }.padding()
            }
            .background(Color.themeBackground).navigationTitle(currentGoal.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct MilestoneRow: View {
    let milestone: Milestone; let index: Int; let isCurrent: Bool; let onComplete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(milestone.isCompleted ? .green : (isCurrent ? .blue : .secondary), lineWidth: 2).frame(width: 32, height: 32)
                if milestone.isCompleted { Image(systemName: "checkmark").font(.caption).bold().foregroundStyle(.green) }
                else { Text("\(index + 1)").font(.caption).bold() }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title).font(.subheadline).strikethrough(milestone.isCompleted)
                if let days = milestone.estimatedDays { Text("\(days) days").font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
            if isCurrent && !milestone.isCompleted { Button("Complete") { onComplete() }.font(.caption).buttonStyle(.borderedProminent).tint(.green) }
        }.padding(.vertical, 8)
    }
}
