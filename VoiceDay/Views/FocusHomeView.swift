import SwiftUI
import EventKit

// MARK: - Focus Home View

/// Simplified home screen showing ONE task at a time
/// Reduces overwhelm and decision paralysis for ADHD users
struct FocusHomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var celebrationService = CelebrationService.shared
    @ObservedObject private var momentumTracker = MomentumTracker.shared
    @ObservedObject private var energyService = EnergyService.shared
    @ObservedObject private var modeService = PresetModeService.shared
    @StateObject private var calendarService = CalendarService()

    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var showAllTasks = false
    @State private var showCelebration = false
    @State private var showEnergyCheckIn = false
    @State private var showTimeRing = false
    @State private var showAttackPlan = false
    @State private var showCoaching = false
    @State private var showBreakdown = false
    @State private var showCalendar = false
    @State private var showHyperfocus = false
    @State private var showMorningChecklist = false
    @State private var showEveningCheckIn = false
    @ObservedObject private var hyperfocusService = HyperfocusModeService.shared
    @ObservedObject private var morningChecklistService = MorningChecklistService.shared

    // Current task is the highest priority incomplete one
    private var currentTask: EKReminder? {
        reminders
            .filter { !$0.isCompleted }
            .sorted { r1, r2 in
                // Sort by priority (1 = high, 0 = none, 9 = low)
                let p1 = r1.priority == 0 ? 5 : r1.priority
                let p2 = r2.priority == 0 ? 5 : r2.priority
                if p1 != p2 { return p1 < p2 }

                // Then by due date
                let d1 = r1.dueDateComponents?.date ?? .distantFuture
                let d2 = r2.dueDateComponents?.date ?? .distantFuture
                return d1 < d2
            }
            .first
    }

    private var remainingCount: Int {
        reminders.filter { !$0.isCompleted }.count - (currentTask != nil ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 16) {
                // Top bar with energy and mode
                HStack {
                    EnergyBadge()
                        .onTapGesture { showEnergyCheckIn = true }

                    Spacer()

                    // Calendar button
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(themeColors.accent)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(themeColors.secondary)
                            )
                    }

                    // Mode indicator
                    HStack(spacing: 4) {
                        Image(systemName: modeService.currentMode.icon)
                        Text(modeService.currentMode.displayName)
                    }
                    .font(.caption)
                    .foregroundStyle(modeService.currentMode.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(modeService.currentMode.color.opacity(0.15))
                    )
                }
                .padding(.horizontal)

                // Momentum meter
                MomentumMeterView()
                    .padding(.horizontal)

                // Mode selector (compact)
                PresetModeSelector()
                    .padding(.horizontal)

                Spacer()

                // Main content
                if isLoading {
                    ProgressView()
                        .tint(themeColors.accent)
                } else if let task = currentTask {
                    // Show time ring for tasks with deadlines
                    if let dueDate = task.dueDateComponents?.date, showTimeRing {
                        TimeRingView(
                            deadline: dueDate,
                            taskTitle: task.title ?? "Task",
                            totalDuration: TimeInterval(estimatedMinutes(for: task) * 60)
                        )
                        .frame(width: 180, height: 180)
                        .onTapGesture { showTimeRing = false }
                    } else {
                        focusTaskCard(task)
                    }
                } else {
                    allDoneView
                }

                Spacer()

                // Bottom actions
                if currentTask != nil {
                    bottomActions
                }

                // Hyperfocus button - tap to open dedicated page
                Button {
                    showHyperfocus = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: hyperfocusService.isActive ? "lock.fill" : "scope")
                            .font(.title3)
                        Text(hyperfocusService.isActive ? "Focused" : "Hyperfocus")
                            .fontWeight(.semibold)
                        if hyperfocusService.isActive {
                            Text(hyperfocusService.timerDisplayString)
                                .font(.callout.monospacedDigit())
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
                .padding(.bottom, 8)
        }
        .padding(.bottom, 60)  // Extra padding for tab bar
        .background(themeColors.background.ignoresSafeArea())
        .overlay(alignment: .center) {
            // Celebration overlay
            CelebrationOverlay()
        }
        .sheet(isPresented: $showAllTasks) {
            TasksListView()
        }
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                CalendarListView()
                    .navigationTitle("Calendar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showCalendar = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showEnergyCheckIn) {
            EnergyCheckInView()
        }
        .sheet(isPresented: $showAttackPlan) {
            if let task = currentTask {
                TaskAttackSheet(
                    task: voiceDayTask(from: task),
                    isPresented: $showAttackPlan,
                    onStartTask: {
                        // User is starting the task
                    },
                    onBreakDown: {
                        showAttackPlan = false
                        showBreakdown = true
                    }
                )
            }
        }
        .sheet(isPresented: $showCoaching) {
            if let task = currentTask {
                TaskCoachView(
                    task: voiceDayTask(from: task),
                    isPresented: $showCoaching,
                    onComplete: { insights in
                        // Could save insights to task
                    }
                )
            }
        }
        .sheet(isPresented: $showBreakdown) {
            if let task = currentTask {
                TaskBreakdownView(
                    task: voiceDayTask(from: task),
                    isPresented: $showBreakdown,
                    onCreateSubtasks: { steps in
                        // Would create subtasks from steps
                        print("Creating subtasks: \(steps)")
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showHyperfocus) {
            NavigationStack {
                HyperfocusView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showHyperfocus = false
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showMorningChecklist) {
            MorningChecklistView(
                onComplete: {
                    morningChecklistService.dismissChecklist()
                    showMorningChecklist = false
                },
                onSkip: {
                    morningChecklistService.dismissChecklist()
                    showMorningChecklist = false
                }
            )
        }
        .fullScreenCover(isPresented: $showEveningCheckIn) {
            EveningCheckInView(
                completedTaskCount: reminders.filter { $0.isCompleted }.count,
                morningIntention: nil,
                onComplete: {
                    showEveningCheckIn = false
                }
            )
        }
        .onAppear {
            // Check for morning checklist
            morningChecklistService.checkIfShouldShowChecklist()
            if morningChecklistService.shouldShowMorningChecklist {
                showMorningChecklist = true
            }

            // Check for evening check-in (after 6 PM)
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 18 && hour < 22 {
                // Could add a service to track if shown today
                // For now, users can trigger manually from settings
            }

            // Check for energy check-in
            energyService.checkIfNeedsCheckIn()
            if energyService.showCheckInPrompt {
                showEnergyCheckIn = true
            }
        }
        .task {
            _ = await calendarService.requestReminderAccess()
            await loadReminders()
        }
    }

    private func estimatedMinutes(for task: EKReminder) -> Int {
        let estimate = DurationEstimator.shared.estimateDuration(for: task.title ?? "")
        return estimate.minutes
    }

    // MARK: - Focus Task Card

    private func focusTaskCard(_ task: EKReminder) -> some View {
        VStack(spacing: 20) {
            // Priority badge
            if task.priority > 0 && task.priority <= 4 {
                Text("HIGH PRIORITY")
                    .font(.caption.bold())
                    .foregroundStyle(themeColors.priorityHigh)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeColors.priorityHigh.opacity(0.15))
                    )
            }

            // Task title
            Text(task.title ?? "Untitled Task")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Time remaining (tap to show ring)
            if let dueDate = task.dueDateComponents?.date {
                TimeRemainingView(deadline: dueDate)
                    .onTapGesture { showTimeRing = true }

                // AI duration estimate hint
                let estimate = DurationEstimator.shared.estimateDuration(for: task.title ?? "")
                Text("Estimated: \(estimate.displayString)")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }

            // Help buttons - friendly assistance
            helpButtons

            // Big Done button
            Button {
                Task { await completeTask(task) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Done")
                        .font(.title2.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeColors.success)
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(themeColors.success)

            Text("All caught up!")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.text)

            Text("No tasks waiting for your attention")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
    }

    // MARK: - Help Buttons

    private var helpButtons: some View {
        HStack(spacing: 12) {
            // Attack plan
            Button {
                showAttackPlan = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                    Text("How?")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Talk it through
            Button {
                showCoaching = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Think")
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }

            // Break it down
            Button {
                showBreakdown = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                    Text("Split")
                }
                .font(.caption)
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.1))
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Skip button
            Button {
                skipCurrentTask()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }

            // See all tasks
            if remainingCount > 0 {
                Button {
                    showAllTasks = true
                } label: {
                    Text("\(remainingCount) more task\(remainingCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(themeColors.accent)
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func loadReminders() async {
        isLoading = true
        reminders = await calendarService.fetchReminders(includeCompleted: false)
        isLoading = false
    }

    private func completeTask(_ task: EKReminder) async {
        let taskTitle = task.title ?? "that task"
        let priority = priorityFrom(ekPriority: task.priority)

        do {
            try await calendarService.toggleReminderComplete(task)
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Update momentum
            momentumTracker.recordTaskCompletion(priority: priority)

            // Calculate celebration level
            let level = celebrationService.levelFor(priority: priority)

            // Get points from rewards system if active
            let points = RewardsService.shared.currentTeam != nil ? pointsFor(priority: priority) : 0

            // Celebrate!
            celebrationService.celebrate(
                level: level,
                taskTitle: taskTitle,
                priority: priority,
                points: points
            )

            // Cancel nags
            NotificationService.shared.cancelAllRemindersForTask(taskId: taskTitle)

            // Reload list
            await loadReminders()

            // Update badge
            BackgroundAudioManager.shared.updateAppBadge()

            // Speak celebration
            await AppDelegate.shared?.speakMessage(celebrationService.celebrationMessage)

        } catch {
            print("Error completing task: \(error)")
        }
    }

    private func skipCurrentTask() {
        guard let current = currentTask,
              let index = reminders.firstIndex(where: { $0.calendarItemIdentifier == current.calendarItemIdentifier }) else {
            return
        }

        // Move to end of list
        var updated = reminders
        let skipped = updated.remove(at: index)
        updated.append(skipped)
        reminders = updated
    }

    private func priorityFrom(ekPriority: Int) -> ItemPriority {
        switch ekPriority {
        case 1...4: return .high
        case 5...6: return .medium
        default: return .low
        }
    }

    private func pointsFor(priority: ItemPriority) -> Int {
        guard let team = RewardsService.shared.currentTeam else { return 0 }
        let rules = team.pointRules
        switch priority {
        case .high: return rules.pointsPerHighPriority
        case .medium: return rules.pointsPerMediumPriority
        case .low: return rules.pointsPerLowPriority
        }
    }

    /// Convert EKReminder to VoiceDayTask for use with coaching/attack views
    private func voiceDayTask(from reminder: EKReminder) -> VoiceDayTask {
        VoiceDayTask(
            title: reminder.title ?? "Untitled",
            dueDate: reminder.dueDateComponents?.date,
            priority: priorityFrom(ekPriority: reminder.priority)
        )
    }
}

// MARK: - Time Remaining View

/// Visual indicator of time remaining until deadline
/// Uses color to communicate urgency without causing anxiety
struct TimeRemainingView: View {
    let deadline: Date
    @State private var timeRemaining: TimeInterval = 0
    @ObservedObject private var themeColors = ThemeColors.shared

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: urgencyIcon)
                .foregroundStyle(urgencyColor)

            Text(timeString)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(urgencyColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(urgencyColor.opacity(0.1))
        )
        .onAppear { updateTimeRemaining() }
        .onReceive(timer) { _ in updateTimeRemaining() }
    }

    private func updateTimeRemaining() {
        timeRemaining = deadline.timeIntervalSinceNow
    }

    private var timeString: String {
        if timeRemaining < 0 {
            return "Overdue"
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes) min left"
        } else {
            return "Due now"
        }
    }

    private var urgencyColor: Color {
        if timeRemaining < 0 {
            return themeColors.priorityHigh // Overdue
        } else if timeRemaining < 900 { // < 15 min
            return themeColors.priorityHigh
        } else if timeRemaining < 3600 { // < 1 hour
            return .orange
        } else if timeRemaining < 14400 { // < 4 hours
            return .yellow
        } else {
            return themeColors.success
        }
    }

    private var urgencyIcon: String {
        if timeRemaining < 0 {
            return "exclamationmark.circle.fill"
        } else if timeRemaining < 900 {
            return "clock.badge.exclamationmark.fill"
        } else if timeRemaining < 3600 {
            return "clock.fill"
        } else {
            return "clock"
        }
    }
}

// MARK: - Preview

#Preview("Focus Home") {
    FocusHomeView()
}

#Preview("Time Remaining") {
    VStack(spacing: 16) {
        TimeRemainingView(deadline: Date().addingTimeInterval(300)) // 5 min
        TimeRemainingView(deadline: Date().addingTimeInterval(1800)) // 30 min
        TimeRemainingView(deadline: Date().addingTimeInterval(7200)) // 2 hours
        TimeRemainingView(deadline: Date().addingTimeInterval(86400)) // 1 day
        TimeRemainingView(deadline: Date().addingTimeInterval(-600)) // Overdue
    }
    .padding()
}
