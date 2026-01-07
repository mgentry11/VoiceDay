import SwiftUI
import EventKit

struct TasksListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var celebrationService = CelebrationService.shared
    @ObservedObject private var momentumTracker = MomentumTracker.shared
    @ObservedObject private var selfCheckService = SelfCheckService.shared
    @ObservedObject private var bodyDoublingService = BodyDoublingService.shared
    @StateObject private var calendarService = CalendarService()
    @StateObject private var speechService = SpeechService()
    @StateObject private var openAIService = OpenAIService()
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var selectedReminder: EKReminder?
    @State private var showingDetail = false
    @State private var showingSelfCheck = false
    @State private var showingSelfCheckPrompt = false
    @State private var showingFocusSession = false
    @State private var showingFocusSetup = false
    @State private var focusTaskTitle: String = ""
    @State private var showingPushCelebration = false
    @State private var pushedTaskTitle: String = ""
    @State private var taskToPush: ReminderWrapper?

    // Voice command state
    @State private var isListening = false
    @State private var isProcessingVoice = false
    @State private var voiceStatusMessage: String = ""
    @State private var showVoiceStatus = false

    // Wrapper to make EKReminder work with .sheet(item:)
    struct ReminderWrapper: Identifiable {
        let id: String
        let reminder: EKReminder

        init(_ reminder: EKReminder) {
            self.id = reminder.calendarItemIdentifier
            self.reminder = reminder
        }
    }

    @State private var showingWeeklyView = false

    // MARK: - Grouped Tasks by Date

    private var incompleteReminders: [EKReminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [EKReminder] {
        reminders.filter { $0.isCompleted }
    }

    // Helper to get date from reminder - tries multiple approaches
    private func dueDate(for reminder: EKReminder) -> Date? {
        guard let components = reminder.dueDateComponents else { return nil }
        let calendar = Calendar.current

        // Try direct date first
        if let date = components.date {
            return date
        }

        // Try constructing from components
        if let date = calendar.date(from: components) {
            return date
        }

        // Manual construction if we have year, month, day
        if let year = components.year, let month = components.month, let day = components.day {
            var newComponents = DateComponents()
            newComponents.year = year
            newComponents.month = month
            newComponents.day = day
            newComponents.hour = components.hour ?? 9
            newComponents.minute = components.minute ?? 0
            return calendar.date(from: newComponents)
        }

        return nil
    }

    /// Tasks due today (or overdue) - compare components directly
    private var todaysTasks: [EKReminder] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())

        return incompleteReminders.filter { reminder in
            guard let components = reminder.dueDateComponents,
                  let year = components.year,
                  let month = components.month,
                  let day = components.day else { return true } // No date = show in today

            // Check if same day as today OR in the past (overdue)
            if year == today.year && month == today.month && day == today.day {
                return true // Today
            }

            // Check if overdue (before today)
            if year < (today.year ?? 0) { return true }
            if year == today.year && month < (today.month ?? 0) { return true }
            if year == today.year && month == today.month && day < (today.day ?? 0) { return true }

            return false
        }
    }

    /// Tasks due tomorrow - compare components directly
    private var tomorrowsTasks: [EKReminder] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)

        return incompleteReminders.filter { reminder in
            guard let components = reminder.dueDateComponents,
                  let year = components.year,
                  let month = components.month,
                  let day = components.day else { return false }

            return year == tomorrowComponents.year &&
                   month == tomorrowComponents.month &&
                   day == tomorrowComponents.day
        }
    }

    /// Tasks due this week (after tomorrow, within 7 days)
    private var thisWeeksTasks: [EKReminder] {
        let calendar = Calendar.current

        // Get components for day after tomorrow through 7 days from now
        var validDays: [DateComponents] = []
        for offset in 2...6 {
            if let date = calendar.date(byAdding: .day, value: offset, to: Date()) {
                validDays.append(calendar.dateComponents([.year, .month, .day], from: date))
            }
        }

        return incompleteReminders.filter { reminder in
            guard let components = reminder.dueDateComponents,
                  let year = components.year,
                  let month = components.month,
                  let day = components.day else { return false }

            return validDays.contains { $0.year == year && $0.month == month && $0.day == day }
        }.sorted { (dueDate(for: $0) ?? .distantFuture) < (dueDate(for: $1) ?? .distantFuture) }
    }

    /// Tasks due later (beyond this week)
    private var laterTasks: [EKReminder] {
        let calendar = Calendar.current
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date())!
        let weekComponents = calendar.dateComponents([.year, .month, .day], from: weekFromNow)

        return incompleteReminders.filter { reminder in
            guard let components = reminder.dueDateComponents,
                  let year = components.year,
                  let month = components.month,
                  let day = components.day else { return false }

            // Check if on or after the week boundary
            if year > (weekComponents.year ?? 0) { return true }
            if year == weekComponents.year && month > (weekComponents.month ?? 0) { return true }
            if year == weekComponents.year && month == weekComponents.month && day >= (weekComponents.day ?? 0) { return true }

            return false
        }.sorted { (dueDate(for: $0) ?? .distantFuture) < (dueDate(for: $1) ?? .distantFuture) }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if isLoading {
                        ProgressView("Loading tasks...")
                            .foregroundStyle(themeColors.text)
                    } else if reminders.isEmpty {
                        emptyState
                    } else {
                        remindersList
                    }
                }
                .navigationTitle("Tasks")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await toggleVoiceCommand() }
                        } label: {
                            Image(systemName: isListening ? "waveform.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                                .foregroundStyle(isListening ? .red : Color.themeAccent)
                                .symbolEffect(.pulse, isActive: isListening)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { Task { await loadReminders() } } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            Button { showingWeeklyView = true } label: {
                                Label("Weekly View", systemImage: "calendar.badge.clock")
                            }
                            Divider()
                            Button { showingSelfCheck = true } label: {
                                Label("Self Check-in", systemImage: "heart.fill")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundStyle(Color.themeText)
                        }
                    }
                }
                .sheet(isPresented: $showingDetail) {
                    if let reminder = selectedReminder {
                        ReminderDetailView(
                            reminder: reminder,
                            calendarService: calendarService,
                            onUpdate: {
                                Task { await loadReminders() }
                            }
                        )
                    }
                }
                .fullScreenCover(isPresented: $showingSelfCheck) {
                    SelfCheckView()
                }
                .sheet(isPresented: $showingSelfCheckPrompt) {
                    SelfCheckPromptView(
                        onDoNow: {
                            showingSelfCheckPrompt = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingSelfCheck = true
                            }
                        },
                        onScheduleLater: { hours in
                            showingSelfCheckPrompt = false
                            selfCheckService.scheduleReminderInHours(hours)
                        },
                        onSkip: {
                            showingSelfCheckPrompt = false
                        }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showingFocusSetup) {
                    QuickFocusSetupView(
                        taskTitle: focusTaskTitle,
                        onStart: { minutes, successDefinition in
                            showingFocusSetup = false
                            // Start the body doubling session with time tracking
                            bodyDoublingService.startSession(
                                type: .solo,
                                taskTitle: focusTaskTitle
                            )
                            // TODO: Add timer for minutes and success tracking
                            showingFocusSession = true
                        },
                        onCancel: {
                            showingFocusSetup = false
                        }
                    )
                    .presentationDetents([.large])
                }
                .fullScreenCover(isPresented: $showingFocusSession) {
                    ActiveFocusSessionView(
                        onEnd: {
                            bodyDoublingService.endSession()
                            showingFocusSession = false
                        }
                    )
                }
                .alert("Moved!", isPresented: $showingPushCelebration) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("\"\(pushedTaskTitle)\" has been rescheduled")
                }
                .sheet(item: $taskToPush) { wrapper in
                    PushOptionsSheet(
                        taskTitle: wrapper.reminder.title ?? "This task",
                        onPush: { date in
                            taskToPush = nil
                            Task { await pushToDate(wrapper.reminder, date: date) }
                        },
                        onCancel: {
                            taskToPush = nil
                        }
                    )
                    .presentationDetents([.height(350)])
                }
                .fullScreenCover(isPresented: $showingWeeklyView) {
                    WeeklyTasksView(reminders: reminders)
                }
                // Voice status overlay
                .overlay(alignment: .top) {
                    if showVoiceStatus {
                        VoiceStatusBanner(
                            isListening: isListening,
                            isProcessing: isProcessingVoice,
                            message: voiceStatusMessage,
                            transcription: speechService.transcribedText
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: showVoiceStatus)
                    }
                }
            }
            .task {
                _ = await calendarService.requestReminderAccess()
                await loadReminders()
            }

            // Celebration overlay
            CelebrationOverlay()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Tasks Yet",
            systemImage: "checklist",
            description: Text("Tasks you create through voice dictation will appear here.")
        )
    }

    private var remindersList: some View {
        List {
            // Today's tasks
            if !todaysTasks.isEmpty {
                Section {
                    ForEach(todaysTasks, id: \.calendarItemIdentifier) { reminder in
                        reminderRowView(for: reminder)
                            .listRowBackground(themeColors.secondary)
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: todaysTasks) }
                    }
                } header: {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.orange)
                        Text("Today (\(todaysTasks.count))")
                    }
                    .foregroundStyle(themeColors.text)
                    .font(.headline)
                }
            }

            // Tomorrow's tasks - with "Today" button to bring back
            if !tomorrowsTasks.isEmpty {
                Section {
                    ForEach(tomorrowsTasks, id: \.calendarItemIdentifier) { reminder in
                        futureTaskRowView(for: reminder)
                            .listRowBackground(themeColors.secondary.opacity(0.8))
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: tomorrowsTasks) }
                    }
                } header: {
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .foregroundStyle(.yellow)
                        Text("Tomorrow (\(tomorrowsTasks.count))")
                    }
                    .foregroundStyle(themeColors.text)
                    .font(.headline)
                }
            }

            // This week's tasks - with "Today" button to bring back
            if !thisWeeksTasks.isEmpty {
                Section {
                    ForEach(thisWeeksTasks, id: \.calendarItemIdentifier) { reminder in
                        futureTaskRowView(for: reminder)
                            .listRowBackground(themeColors.secondary.opacity(0.6))
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: thisWeeksTasks) }
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                        Text("This Week (\(thisWeeksTasks.count))")
                    }
                    .foregroundStyle(themeColors.text)
                    .font(.headline)
                }
            }

            // Later tasks - with "Today" button to bring back
            if !laterTasks.isEmpty {
                Section {
                    ForEach(laterTasks, id: \.calendarItemIdentifier) { reminder in
                        futureTaskRowView(for: reminder)
                            .listRowBackground(themeColors.secondary.opacity(0.4))
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: laterTasks) }
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.purple)
                        Text("Later (\(laterTasks.count))")
                    }
                    .foregroundStyle(themeColors.text)
                    .font(.headline)
                }
            }

            // Completed tasks section
            if !completedReminders.isEmpty {
                Section {
                    ForEach(completedReminders, id: \.calendarItemIdentifier) { reminder in
                        CompletedTaskRow(
                            reminder: reminder,
                            onUncomplete: {
                                Task { await toggleComplete(reminder) }
                            }
                        )
                        .listRowBackground(themeColors.secondary.opacity(0.3))
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: completedReminders) }
                    }
                } header: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Completed (\(completedReminders.count))")
                    }
                    .foregroundStyle(themeColors.subtext)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeColors.background)
        .refreshable {
            await loadReminders()
        }
        .id(themeColors.currentTheme.rawValue)
    }

    // Helper to create reminder row with all handlers (for TODAY tasks)
    @ViewBuilder
    private func reminderRowView(for reminder: EKReminder) -> some View {
        ReminderRow(
            reminder: reminder,
            onToggleComplete: {
                Task { await toggleComplete(reminder) }
            },
            onTapRow: {
                selectedReminder = reminder
                showingDetail = true
            },
            onStartFocus: {
                focusTaskTitle = reminder.title ?? "This task"
                showingFocusSetup = true
            },
            onPushTomorrow: {
                taskToPush = ReminderWrapper(reminder)
            }
        )
    }

    // Helper for FUTURE tasks (tomorrow, this week, later) - has "Today" button
    @ViewBuilder
    private func futureTaskRowView(for reminder: EKReminder) -> some View {
        FutureTaskRow(
            reminder: reminder,
            onBringToToday: {
                Task { await bringToToday(reminder) }
            },
            onReschedule: {
                taskToPush = ReminderWrapper(reminder)
            }
        )
    }

    private func loadReminders() async {
        isLoading = true
        reminders = await calendarService.fetchReminders(includeCompleted: true)
        isLoading = false
    }

    private func uncompleteAllTasks() async {
        let completed = reminders.filter { $0.isCompleted }
        print("🔄 Uncompleting \(completed.count) tasks...")

        for reminder in completed {
            do {
                try await calendarService.toggleReminderComplete(reminder)
                print("  ✓ Uncompleted: \(reminder.title ?? "?")")
            } catch {
                print("  ✗ Failed: \(reminder.title ?? "?") - \(error)")
            }
        }

        await loadReminders()
        print("🔄 Done! All tasks uncompleted.")
    }

    private func toggleComplete(_ reminder: EKReminder) async {
        let wasCompleted = reminder.isCompleted
        let taskTitle = reminder.title ?? "that task"
        let priority = priorityFrom(ekPriority: reminder.priority)

        do {
            try await calendarService.toggleReminderComplete(reminder)

            // Small delay to let EventKit propagate the change
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Refresh the list FIRST so UI updates immediately
            await loadReminders()

            // Then celebrate (if marking complete)
            if !wasCompleted {
                await celebrateCompletion(taskTitle: taskTitle, priority: priority)
            }
        } catch {
            print("Error toggling reminder: \(error)")
        }
    }

    @MainActor
    private func celebrateCompletion(taskTitle: String, priority: ItemPriority) async {
        // Cancel any nags for this task
        NotificationService.shared.cancelAllRemindersForTask(taskId: taskTitle)

        // Update momentum
        momentumTracker.recordTaskCompletion(priority: priority)

        // Calculate celebration level
        let level = celebrationService.levelFor(priority: priority)

        // Get points from rewards system if active
        let points = pointsFor(priority: priority)

        // Trigger celebration (haptics, sound, confetti)
        celebrationService.celebrate(
            level: level,
            taskTitle: taskTitle,
            priority: priority,
            points: points
        )

        // Log to conversation
        ConversationService.shared.addAssistantMessage(celebrationService.celebrationMessage)

        // Update app badge
        BackgroundAudioManager.shared.updateAppBadge()

        // Speak the celebration in parent's voice (or selected voice)
        await AppDelegate.shared?.speakMessage(celebrationService.celebrationMessage)

        // Check if all tasks are done - trigger self-check prompt
        if incompleteReminders.isEmpty && selfCheckService.isEnabled && !selfCheckService.activeItems.isEmpty {
            // Small delay to let the celebration finish
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            showingSelfCheckPrompt = true
        }
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

    private func deleteReminders(at offsets: IndexSet, from list: [EKReminder]) async {
        for index in offsets {
            let reminder = list[index]
            do {
                try await calendarService.deleteReminder(reminder)
            } catch {
                print("Error deleting reminder: \(error)")
            }
        }
        await loadReminders()
        BackgroundAudioManager.shared.updateAppBadge()
    }

    private func pushToDate(_ reminder: EKReminder, date: Date) async {
        let taskTitle = reminder.title ?? "Task"
        pushedTaskTitle = taskTitle

        print("📌 VIEW: Starting push for '\(taskTitle)'")
        print("   isCompleted at start: \(reminder.isCompleted)")

        do {
            try await calendarService.pushToDate(reminder, date: date)

            print("   isCompleted after calendarService.pushToDate: \(reminder.isCompleted)")

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Show confirmation
            showingPushCelebration = true

            // Reload list
            await loadReminders()

            // Check if the task is now in completed list
            if let reloaded = reminders.first(where: { $0.title == taskTitle }) {
                print("   AFTER RELOAD: '\(taskTitle)' isCompleted = \(reloaded.isCompleted)")
            } else {
                print("   AFTER RELOAD: '\(taskTitle)' NOT FOUND!")
            }
        } catch {
            print("❌ Error pushing task: \(error)")
        }
    }

    // MARK: - Voice Commands

    private func toggleVoiceCommand() async {
        if isListening {
            await stopListeningAndProcess()
        } else {
            await startListening()
        }
    }

    private func startListening() async {
        guard appState.hasValidClaudeKey else {
            voiceStatusMessage = "Please add Claude API key in Settings"
            showVoiceStatus = true
            try? await Task.sleep(for: .seconds(2))
            showVoiceStatus = false
            return
        }

        do {
            try speechService.startListening()
            isListening = true
            voiceStatusMessage = "Listening..."
            showVoiceStatus = true
        } catch {
            voiceStatusMessage = "Microphone error"
            showVoiceStatus = true
            try? await Task.sleep(for: .seconds(2))
            showVoiceStatus = false
        }
    }

    private func stopListeningAndProcess() async {
        speechService.stopListening()
        isListening = false

        let transcription = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            voiceStatusMessage = "Didn't catch that"
            try? await Task.sleep(for: .seconds(1))
            showVoiceStatus = false
            return
        }

        voiceStatusMessage = "Processing..."
        isProcessingVoice = true

        do {
            let result = try await openAIService.processUserInput(transcription, apiKey: appState.claudeKey, personality: appState.selectedPersonality)

            print("🎤 Voice result:")
            print("   rescheduleOperations: \(result.rescheduleOperations.count)")
            print("   tasks: \(result.tasks.count)")
            print("   summary: \(result.summary ?? "nil")")

            // Handle reschedule operations
            if !result.rescheduleOperations.isEmpty {
                print("   → Handling reschedule operations")
                await handleRescheduleOperations(result.rescheduleOperations, summary: result.summary)
            }
            // Handle new tasks
            else if !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty {
                let _ = try await calendarService.saveAllItems(
                    from: result,
                    remindersEnabled: appState.remindersEnabled,
                    eventReminderMinutes: appState.eventReminderMinutes,
                    nagIntervalMinutes: appState.nagIntervalMinutes
                )
                voiceStatusMessage = result.summary ?? "Added!"
                await loadReminders()
                SpeechService.shared.queueSpeech(result.summary ?? "Done!")
            } else {
                voiceStatusMessage = result.summary ?? "Got it"
                SpeechService.shared.queueSpeech(result.summary ?? "Got it")
            }

            isProcessingVoice = false
            try? await Task.sleep(for: .seconds(2))
            showVoiceStatus = false

        } catch {
            voiceStatusMessage = "Error: \(error.localizedDescription)"
            isProcessingVoice = false
            try? await Task.sleep(for: .seconds(2))
            showVoiceStatus = false
        }
    }

    private func handleRescheduleOperations(_ operations: [OpenAIService.RescheduleOperation], summary: String?) async {
        print("🔄 handleRescheduleOperations called with \(operations.count) operations")

        var movedCount = 0
        var movedTasks: [String] = []

        for op in operations {
            let searchTerm = op.taskTitle.lowercased()
            print("   Looking for task containing: '\(searchTerm)'")
            print("   Available tasks: \(reminders.map { $0.title ?? "?" })")

            if let matchingReminder = reminders.first(where: {
                ($0.title ?? "").lowercased().contains(searchTerm)
            }) {
                print("   ✓ Found match: '\(matchingReminder.title ?? "?")'")
                do {
                    try await calendarService.pushToDate(matchingReminder, date: op.newDate)
                    movedCount += 1
                    movedTasks.append(matchingReminder.title ?? op.taskTitle)
                    print("   ✓ Successfully moved to \(op.newDate)")
                } catch {
                    print("   ✗ Failed to reschedule: \(error)")
                }
            } else {
                print("   ✗ No match found for '\(searchTerm)'")
            }
        }

        await loadReminders()

        if movedCount > 0 {
            voiceStatusMessage = summary ?? "Moved \(movedTasks.joined(separator: ", "))"
            SpeechService.shared.queueSpeech(summary ?? "Done. Moved \(movedTasks.first ?? "the task").")
        } else {
            voiceStatusMessage = "Couldn't find that task"
            SpeechService.shared.queueSpeech("I couldn't find a task matching what you said.")
        }
    }

    private func bringToToday(_ reminder: EKReminder) async {
        let taskTitle = reminder.title ?? "Task"
        pushedTaskTitle = taskTitle

        // Set to now (or in 5 minutes to give a slight buffer)
        let today = Date().addingTimeInterval(5 * 60)

        do {
            try await calendarService.pushToDate(reminder, date: today)

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Reload list
            await loadReminders()

            // Announce
            SpeechService.shared.queueSpeech("Alright, \(taskTitle) is back on today's list.")
        } catch {
            print("❌ Error bringing task to today: \(error)")
        }
    }
}

// MARK: - Push Options Sheet (Simple Time Picker)

struct PushOptionsSheet: View {
    let taskTitle: String
    let onPush: (Date) -> Void
    let onCancel: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @State private var selectedDay = 1 // 1 = tomorrow
    @State private var selectedHour = 9
    @State private var showingCustomPicker = false
    @State private var customDate = Date()

    private let dayOptions = [
        ("Tomorrow", 1),
        ("In 2 Days", 2),
        ("Next Week", 7)
    ]

    private let timeOptions = [
        ("9 AM", 9),
        ("12 PM", 12),
        ("3 PM", 15),
        ("6 PM", 18)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Task name
                Text(taskTitle)
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Day options
                VStack(spacing: 8) {
                    Text("Which day?")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)

                    HStack(spacing: 8) {
                        ForEach(dayOptions, id: \.0) { option in
                            Button {
                                selectedDay = option.1
                            } label: {
                                Text(option.0)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedDay == option.1 ? .black : themeColors.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedDay == option.1 ? Color.themeAccent : Color.themeSecondary)
                                    )
                            }
                        }
                    }
                }

                // Time options
                VStack(spacing: 8) {
                    Text("What time?")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)

                    HStack(spacing: 8) {
                        ForEach(timeOptions, id: \.0) { option in
                            Button {
                                selectedHour = option.1
                            } label: {
                                Text(option.0)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedHour == option.1 ? .white : themeColors.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedHour == option.1 ? Color.blue : Color.themeSecondary)
                                    )
                            }
                        }
                    }
                }

                // Move button
                Button {
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: selectedDay, to: Date())!)
                    components.hour = selectedHour
                    components.minute = 0
                    if let date = calendar.date(from: components) {
                        onPush(date)
                    }
                } label: {
                    Text("Move It →")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Custom date option
                Button {
                    showingCustomPicker = true
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Pick a specific date & time")
                    }
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
                }

                Spacer()
            }
            .padding(.top)
            .background(Color.themeBackground)
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showingCustomPicker) {
                CustomDatePickerSheet(
                    selectedDate: $customDate,
                    onConfirm: { date in
                        showingCustomPicker = false
                        onPush(date)
                    },
                    onCancel: {
                        showingCustomPicker = false
                    }
                )
            }
        }
    }
}

// MARK: - Custom Date Picker Sheet

struct CustomDatePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Date & Time",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()

                Button {
                    onConfirm(selectedDate)
                } label: {
                    Text("Move to \(selectedDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color.themeBackground)
            .navigationTitle("Pick Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Tasks View

struct WeeklyTasksView: View {
    let reminders: [EKReminder]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    private var calendar: Calendar { Calendar.current }

    // Helper to get date from reminder - tries multiple approaches
    private func dueDate(for reminder: EKReminder) -> Date? {
        guard let components = reminder.dueDateComponents else { return nil }

        // Try direct date first
        if let date = components.date {
            return date
        }

        // Try constructing from components
        if let date = calendar.date(from: components) {
            return date
        }

        // Manual construction if we have year, month, day
        if let year = components.year, let month = components.month, let day = components.day {
            var newComponents = DateComponents()
            newComponents.year = year
            newComponents.month = month
            newComponents.day = day
            newComponents.hour = components.hour ?? 9
            newComponents.minute = components.minute ?? 0
            return calendar.date(from: newComponents)
        }

        return nil
    }

    // Days of the week starting from today
    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))
        }
    }

    // Tasks grouped by day - compare full year/month/day
    private func tasks(for day: Date) -> [EKReminder] {
        let targetYear = calendar.component(.year, from: day)
        let targetMonth = calendar.component(.month, from: day)
        let targetDay = calendar.component(.day, from: day)

        return reminders.filter { reminder in
            guard !reminder.isCompleted else { return false } // Don't show completed
            guard let components = reminder.dueDateComponents else { return false }
            let taskYear = components.year ?? -1
            let taskMonth = components.month ?? -1
            let taskDay = components.day ?? -1
            return taskYear == targetYear && taskMonth == targetMonth && taskDay == targetDay
        }
    }

    // All tasks that have dates
    private var tasksWithDates: [EKReminder] {
        reminders.filter { dueDate(for: $0) != nil }
    }

    // Tasks without dates
    private var tasksWithoutDates: [EKReminder] {
        reminders.filter { dueDate(for: $0) == nil }
    }

    private func dayName(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(weekDays, id: \.self) { day in
                        let dayTasks = tasks(for: day)

                        VStack(alignment: .leading, spacing: 8) {
                            // Day header
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dayName(for: day))
                                        .font(.headline)
                                        .foregroundStyle(calendar.isDateInToday(day) ? Color.themeAccent : themeColors.text)

                                    Text(dateString(for: day))
                                        .font(.caption)
                                        .foregroundStyle(themeColors.subtext)
                                }

                                Spacer()

                                Text("\(dayTasks.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(dayTasks.isEmpty ? .gray : .white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(dayTasks.isEmpty ? Color.gray.opacity(0.3) : Color.themeAccent))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(calendar.isDateInToday(day) ? Color.themeAccent.opacity(0.15) : Color.themeSecondary)
                            )

                            // Tasks for this day
                            if dayTasks.isEmpty {
                                Text("No tasks")
                                    .font(.subheadline)
                                    .foregroundStyle(themeColors.subtext)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(dayTasks, id: \.calendarItemIdentifier) { task in
                                    WeeklyTaskRow(task: task)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Tasks without dates
                    let undatedTasks = reminders.filter { $0.dueDateComponents?.date == nil }
                    if !undatedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No Date Set")
                                        .font(.headline)
                                        .foregroundStyle(themeColors.subtext)

                                    Text("Unscheduled tasks")
                                        .font(.caption)
                                        .foregroundStyle(themeColors.subtext)
                                }

                                Spacer()

                                Text("\(undatedTasks.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(.gray))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.themeSecondary.opacity(0.5))
                            )

                            ForEach(undatedTasks, id: \.calendarItemIdentifier) { task in
                                WeeklyTaskRow(task: task)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.themeBackground)
            .navigationTitle("Week View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Task Row

struct WeeklyTaskRow: View {
    let task: EKReminder
    @ObservedObject private var themeColors = ThemeColors.shared

    private var timeString: String {
        guard let date = task.dueDateComponents?.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var priorityColor: Color {
        switch task.priority {
        case 1...4: return themeColors.priorityHigh
        case 5...6: return themeColors.priorityMedium
        default: return themeColors.subtext
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "Untitled")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(1)

                if !timeString.isEmpty {
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.themeSecondary.opacity(0.3))
        )
        .padding(.horizontal)
    }
}

// MARK: - Push Task Sheet (Ask Why, Then Move It)

struct PushToTomorrowSheet: View {
    let taskTitle: String
    let onPush: (Date) -> Void
    let onCancel: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState
    @State private var selectedReason: PushReason?
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    @State private var selectedDayOffset = 1
    @State private var selectedHour = 9

    enum PushReason: String, CaseIterable {
        case noEnergy = "Low energy right now"
        case tooMuch = "Too much on my plate"
        case notReady = "Not ready / need prep"
        case wrongTime = "Wrong time of day"
        case other = "Just not today"

        var icon: String {
            switch self {
            case .noEnergy: return "battery.25"
            case .tooMuch: return "tray.full.fill"
            case .notReady: return "clock.badge.questionmark"
            case .wrongTime: return "sun.horizon"
            case .other: return "arrow.right.circle"
            }
        }

        var encouragement: String {
            switch self {
            case .noEnergy: return "Rest is productive too. We'll tackle it fresh!"
            case .tooMuch: return "Smart move. Better to do one thing well."
            case .notReady: return "Good call. Preparation prevents frustration."
            case .wrongTime: return "Timing matters. Let's find a better slot."
            case .other: return "No problem. Tomorrow's a new day!"
            }
        }
    }

    // Quick day options
    private let dayOptions: [(String, Int)] = [
        ("Tomorrow", 1),
        ("In 2 Days", 2),
        ("Next Week", 7)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(appState.selectedPersonality.emoji)
                            .font(.system(size: 44))

                        Text("Why push this?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(themeColors.text)

                        Text(taskTitle)
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 16)

                    // Reason buttons - big and easy to tap
                    VStack(spacing: 10) {
                        ForEach(PushReason.allCases, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: reason.icon)
                                        .font(.title3)
                                        .frame(width: 30)

                                    Text(reason.rawValue)
                                        .font(.body.weight(.medium))

                                    Spacer()

                                    if selectedReason == reason {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.themeAccent)
                                    }
                                }
                                .foregroundStyle(selectedReason == reason ? themeColors.text : themeColors.subtext)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedReason == reason ? Color.themeAccent.opacity(0.2) : Color.themeSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedReason == reason ? Color.themeAccent : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // When to reschedule (only show after reason selected)
                    if selectedReason != nil {
                        VStack(spacing: 12) {
                            Text("When instead?")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)

                            HStack(spacing: 10) {
                                ForEach(dayOptions, id: \.0) { option in
                                    Button {
                                        selectedDayOffset = option.1
                                    } label: {
                                        Text(option.0)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(selectedDayOffset == option.1 ? .white : themeColors.text)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedDayOffset == option.1 ? Color.themeAccent : Color.themeSecondary)
                                            )
                                    }
                                }

                                Button {
                                    showingDatePicker = true
                                } label: {
                                    Image(systemName: "calendar")
                                        .font(.title3)
                                        .foregroundStyle(themeColors.text)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.themeSecondary)
                                        )
                                }
                            }

                            // Move it button
                            Button {
                                let calendar = Calendar.current
                                var components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: selectedDayOffset, to: Date())!)
                                components.hour = 9
                                components.minute = 0
                                if let date = calendar.date(from: components) {
                                    onPush(date)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Move It")
                                }
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.themeAccent)
                                .cornerRadius(14)
                            }
                            .padding(.top, 8)

                            // Encouragement
                            if let reason = selectedReason {
                                Text(reason.encouragement)
                                    .font(.caption)
                                    .foregroundStyle(themeColors.subtext)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.themeBackground)
            .navigationTitle("Push Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate) { date in
                    showingDatePicker = false
                    onPush(date)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedReason)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Select date and time",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()

                Button {
                    onConfirm(selectedDate)
                } label: {
                    Text("Move to \(selectedDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.themeAccent)
                        .cornerRadius(14)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color.themeBackground)
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Future Task Row (with Today button)

struct FutureTaskRow: View {
    let reminder: EKReminder
    let onBringToToday: () -> Void
    let onReschedule: () -> Void
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(2)

                if let dueDate = reminder.dueDateComponents?.date {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(dueDate, format: .dateTime.weekday().month().day().hour().minute())
                    }
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Bring to Today button
                Button {
                    onBringToToday()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.left.circle")
                            .font(.title3)
                        Text("Today")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 55, height: 45)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Reschedule button
                Button {
                    onReschedule()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                        Text("Move")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 55, height: 45)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Completed Task Row (with Undo button)

struct CompletedTaskRow: View {
    let reminder: EKReminder
    let onUncomplete: () -> Void
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            // Completed checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green.opacity(0.6))

            // Task title (struck through)
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled")
                    .font(.body)
                    .strikethrough()
                    .foregroundStyle(themeColors.subtext)
                    .lineLimit(2)

                if let completionDate = reminder.completionDate {
                    Text("Done \(completionDate.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext.opacity(0.7))
                }
            }

            Spacer()

            // Undo button - clear and obvious
            Button {
                onUncomplete()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    let onToggleComplete: () -> Void
    let onTapRow: () -> Void
    var onStartFocus: (() -> Void)? = nil
    var onPushTomorrow: (() -> Void)? = nil
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var bodyDoublingService = BodyDoublingService.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // BIG Checkbox - easy to tap
                Button {
                    onToggleComplete()
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundStyle(reminder.isCompleted ? themeColors.success : themeColors.subtext)
                }
                .frame(width: 50, height: 50)

                // Task content - taps here open details
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title ?? "Untitled")
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? themeColors.subtext : themeColors.text)
                        .lineLimit(2)

                    if let dueDate = reminder.dueDateComponents?.date {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(dueDate, format: .dateTime.month().day().hour().minute())
                        }
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapRow()
                }

                Spacer()

                // Action buttons - BIG and easy to tap
                if !reminder.isCompleted {
                    HStack(spacing: 12) {
                        // Push to tomorrow - ONLY this action
                        Button {
                            print("📌 Tomorrow button action triggered")
                            onPushTomorrow?()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.title3)
                                Text("Later")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 50)
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // Focus button - ONLY this action
                        Button {
                            print("🎯 Focus button action triggered")
                            onStartFocus?()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "target")
                                    .font(.title3)
                                Text("Focus")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.black)
                            .frame(width: 60, height: 50)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        let priority = reminder.priority
        if priority > 0 && priority <= 4 {
            Text("High")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeColors.priorityHigh.opacity(0.2))
                .foregroundStyle(themeColors.priorityHigh)
                .clipShape(Capsule())
        } else if priority >= 5 && priority <= 6 {
            Text("Medium")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeColors.priorityMedium.opacity(0.2))
                .foregroundStyle(themeColors.priorityMedium)
                .clipShape(Capsule())
        }
    }
}

struct ReminderDetailView: View {
    let reminder: EKReminder
    let calendarService: CalendarService
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var priority: Int = 0
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Date & Time", selection: $dueDate)
                    }
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(0)
                        Text("Low").tag(9)
                        Text("Medium").tag(5)
                        Text("High").tag(1)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await calendarService.deleteReminder(reminder)
                            onUpdate()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Task")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear {
                title = reminder.title ?? ""
                notes = reminder.notes ?? ""
                priority = reminder.priority
                if let components = reminder.dueDateComponents, let date = components.date {
                    dueDate = date
                    hasDueDate = true
                }
            }
        }
    }

    private func saveChanges() async {
        isSaving = true
        do {
            try await calendarService.updateReminder(
                reminder,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority
            )
            onUpdate()
            dismiss()
        } catch {
            print("Error saving: \(error)")
        }
        isSaving = false
    }
}

// MARK: - Voice Status Banner

struct VoiceStatusBanner: View {
    let isListening: Bool
    let isProcessing: Bool
    let message: String
    let transcription: String

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Status icon
                if isListening {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .symbolEffect(.variableColor.iterative)
                } else if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    if isListening && !transcription.isEmpty {
                        Text(transcription)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isListening ? Color.red.opacity(0.9) : Color.black.opacity(0.85))
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    TasksListView()
        .environmentObject(AppState())
}
