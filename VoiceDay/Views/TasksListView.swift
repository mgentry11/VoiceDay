import SwiftUI
import EventKit

struct TasksListView: View {
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var celebrationService = CelebrationService.shared
    @ObservedObject private var momentumTracker = MomentumTracker.shared
    @ObservedObject private var selfCheckService = SelfCheckService.shared
    @ObservedObject private var bodyDoublingService = BodyDoublingService.shared
    @StateObject private var calendarService = CalendarService()
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
    @State private var showingTomorrowTimePicker = false
    @State private var reminderToPush: EKReminder?

    @State private var showingWeeklyView = false

    // MARK: - Grouped Tasks by Date

    private var incompleteReminders: [EKReminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [EKReminder] {
        reminders.filter { $0.isCompleted }
    }

    /// Tasks due today (or overdue)
    private var todaysTasks: [EKReminder] {
        let calendar = Calendar.current
        return incompleteReminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return true } // No date = show in today
            return calendar.isDateInToday(dueDate) || dueDate < Date()
        }
    }

    /// Tasks due tomorrow
    private var tomorrowsTasks: [EKReminder] {
        let calendar = Calendar.current
        return incompleteReminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return calendar.isDateInTomorrow(dueDate)
        }
    }

    /// Tasks due this week (after tomorrow, within 7 days)
    private var thisWeeksTasks: [EKReminder] {
        let calendar = Calendar.current
        let twoDaysFromNow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))!
        return incompleteReminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return dueDate >= twoDaysFromNow && dueDate < weekFromNow
        }.sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }
    }

    /// Tasks due later (beyond this week)
    private var laterTasks: [EKReminder] {
        let calendar = Calendar.current
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))!
        return incompleteReminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return dueDate >= weekFromNow
        }.sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }
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
                        MomentumBadge()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            // Weekly view button
                            Button {
                                showingWeeklyView = true
                            } label: {
                                Image(systemName: "calendar.badge.clock")
                            }

                            // Refresh button
                            Button {
                                Task { await loadReminders() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
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
                .sheet(isPresented: $showingTomorrowTimePicker) {
                    PushToTomorrowSheet(
                        taskTitle: reminderToPush?.title ?? "This task",
                        onPush: { selectedTime in
                            if let reminder = reminderToPush {
                                Task {
                                    await pushTaskToTomorrowWithTime(reminder, time: selectedTime)
                                }
                            }
                            showingTomorrowTimePicker = false
                        },
                        onCancel: {
                            showingTomorrowTimePicker = false
                        }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showingPushCelebration) {
                    PushCelebrationView(
                        taskTitle: pushedTaskTitle,
                        onDismiss: {
                            showingPushCelebration = false
                        }
                    )
                    .presentationDetents([.medium])
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

            // Tomorrow's tasks
            if !tomorrowsTasks.isEmpty {
                Section {
                    ForEach(tomorrowsTasks, id: \.calendarItemIdentifier) { reminder in
                        reminderRowView(for: reminder)
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

            // This week's tasks
            if !thisWeeksTasks.isEmpty {
                Section {
                    ForEach(thisWeeksTasks, id: \.calendarItemIdentifier) { reminder in
                        reminderRowView(for: reminder)
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

            // Later tasks
            if !laterTasks.isEmpty {
                Section {
                    ForEach(laterTasks, id: \.calendarItemIdentifier) { reminder in
                        reminderRowView(for: reminder)
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
                        ReminderRow(
                            reminder: reminder,
                            onToggleComplete: {
                                Task { await toggleComplete(reminder) }
                            },
                            onTapRow: {
                                selectedReminder = reminder
                                showingDetail = true
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
        .sheet(isPresented: $showingWeeklyView) {
            WeeklyTasksView(reminders: incompleteReminders)
        }
    }

    // Helper to create reminder row with all handlers
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
                reminderToPush = reminder
                showingTomorrowTimePicker = true
            }
        )
    }

    private func loadReminders() async {
        isLoading = true
        reminders = await calendarService.fetchReminders(includeCompleted: true)
        isLoading = false
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

    private func pushTaskToTomorrow(_ reminder: EKReminder) async {
        do {
            pushedTaskTitle = reminder.title ?? "Task"
            try await calendarService.pushToTomorrow(reminder)

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Show celebration
            showingPushCelebration = true

            // Reload list
            await loadReminders()
        } catch {
            print("Error pushing to tomorrow: \(error)")
        }
    }

    private func pushTaskToTomorrowWithTime(_ reminder: EKReminder, time: Date) async {
        do {
            pushedTaskTitle = reminder.title ?? "Task"
            try await calendarService.pushToDate(reminder, date: time)

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Show celebration
            showingPushCelebration = true

            // Reload list
            await loadReminders()
        } catch {
            print("Error pushing task: \(error)")
        }
    }
}

// MARK: - Weekly Tasks View

struct WeeklyTasksView: View {
    let reminders: [EKReminder]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    private var calendar: Calendar { Calendar.current }

    // Days of the week starting from today
    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))
        }
    }

    // Tasks grouped by day
    private func tasks(for day: Date) -> [EKReminder] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return dueDate >= dayStart && dueDate < dayEnd
        }.sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }
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

                                if !dayTasks.isEmpty {
                                    Text("\(dayTasks.count)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.themeAccent))
                                }
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

// MARK: - Push To Later Sheet (Flexible Date Picker)

struct PushToTomorrowSheet: View {
    let taskTitle: String
    let onPush: (Date) -> Void
    let onCancel: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var selectedTab = 0 // 0 = Quick, 1 = Calendar

    // Quick day options
    private let dayPresets: [(String, Int, String)] = [
        ("Tomorrow", 1, "sunrise.fill"),
        ("In 2 Days", 2, "calendar"),
        ("In 3 Days", 3, "calendar"),
        ("Next Week", 7, "calendar.badge.plus")
    ]

    // Time presets
    private let timePresets: [(String, Int, Int)] = [
        ("9 AM", 9, 0),
        ("12 PM", 12, 0),
        ("3 PM", 15, 0),
        ("6 PM", 18, 0)
    ]

    @State private var selectedDayOffset = 1
    @State private var selectedHour = 9
    @State private var selectedMinute = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task title
                    VStack(spacing: 8) {
                        Text(appState.selectedPersonality.emoji)
                            .font(.system(size: 40))

                        Text("When should I remind you?")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(themeColors.text)

                        Text(taskTitle)
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 12)

                    // Tab picker
                    Picker("Mode", selection: $selectedTab) {
                        Text("Quick Pick").tag(0)
                        Text("Calendar").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selectedTab == 0 {
                        // Quick pick mode
                        quickPickView
                    } else {
                        // Calendar mode
                        calendarPickView
                    }

                    Spacer(minLength: 20)
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
        }
        .onAppear {
            SpeechService.shared.queueSpeech("When do you want to tackle this?")
        }
    }

    // MARK: - Quick Pick View

    private var quickPickView: some View {
        VStack(spacing: 16) {
            // Day selection - BIG buttons
            VStack(spacing: 8) {
                Text("Which day?")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(dayPresets, id: \.0) { preset in
                        Button {
                            selectedDayOffset = preset.1
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: preset.2)
                                Text(preset.0)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedDayOffset == preset.1 ? .white : themeColors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedDayOffset == preset.1 ? Color.themeAccent : Color.themeSecondary)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Time selection - BIG buttons
            VStack(spacing: 8) {
                Text("What time?")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(timePresets, id: \.0) { preset in
                        Button {
                            selectedHour = preset.1
                            selectedMinute = preset.2
                        } label: {
                            Text(preset.0)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selectedHour == preset.1 ? .white : themeColors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedHour == preset.1 ? Color.blue : Color.themeSecondary)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Confirm button
            Button {
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: selectedDayOffset, to: Date())!)
                components.hour = selectedHour
                components.minute = selectedMinute
                if let date = calendar.date(from: components) {
                    onPush(date)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Push to \(dayPresets.first { $0.1 == selectedDayOffset }?.0 ?? "Later") at \(selectedHour > 12 ? selectedHour - 12 : selectedHour) \(selectedHour >= 12 ? "PM" : "AM")")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.themeAccent)
                .cornerRadius(14)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Calendar Pick View

    private var calendarPickView: some View {
        VStack(spacing: 16) {
            // Full date/time picker
            DatePicker(
                "Select date and time",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            // Confirm button
            Button {
                onPush(selectedDate)
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Push to \(selectedDate.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.themeAccent)
                .cornerRadius(14)
            }
            .padding(.horizontal)
        }
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
                    HStack(spacing: 8) {
                        // Push to tomorrow
                        Button {
                            onPushTomorrow?()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.title3)
                                Text("Tomorrow")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 65, height: 50)
                            .background(Color.orange)
                            .cornerRadius(10)
                        }

                        // Focus button
                        Button {
                            onStartFocus?()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "target")
                                    .font(.title3)
                                Text("Focus")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.black)
                            .frame(width: 55, height: 50)
                            .background(Color.themeAccent)
                            .cornerRadius(10)
                        }
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

#Preview {
    TasksListView()
}
