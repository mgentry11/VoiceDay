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

    private var incompleteReminders: [EKReminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [EKReminder] {
        reminders.filter { $0.isCompleted }
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
                        Button {
                            Task { await loadReminders() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
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
            // Incomplete tasks section
            if !incompleteReminders.isEmpty {
                Section {
                    ForEach(incompleteReminders, id: \.calendarItemIdentifier) { reminder in
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
                        .listRowBackground(themeColors.secondary)
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: incompleteReminders) }
                    }
                } header: {
                    Text("To Do (\(incompleteReminders.count))")
                        .foregroundStyle(themeColors.subtext)
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
                        .listRowBackground(themeColors.secondary.opacity(0.5))
                    }
                    .onDelete { indexSet in
                        Task { await deleteReminders(at: indexSet, from: completedReminders) }
                    }
                } header: {
                    Text("Completed (\(completedReminders.count))")
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
            try await calendarService.pushToTomorrowAtTime(reminder, time: time)

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
}

// MARK: - Push To Tomorrow Sheet

struct PushToTomorrowSheet: View {
    let taskTitle: String
    let onPush: (Date) -> Void
    let onCancel: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState
    @State private var selectedTime = Date()

    // Preset time options
    private let timePresets: [(String, Int, Int)] = [
        ("Morning (9 AM)", 9, 0),
        ("Late Morning (11 AM)", 11, 0),
        ("Afternoon (2 PM)", 14, 0),
        ("Evening (6 PM)", 18, 0)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Bot asking
                VStack(spacing: 12) {
                    Text(appState.selectedPersonality.emoji)
                        .font(.system(size: 50))

                    Text("When tomorrow?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)

                    Text(taskTitle)
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Quick time buttons - BIG
                VStack(spacing: 12) {
                    ForEach(timePresets, id: \.0) { preset in
                        Button {
                            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                            components.hour = preset.1
                            components.minute = preset.2
                            if let time = Calendar.current.date(from: components) {
                                onPush(time)
                            }
                        } label: {
                            Text(preset.0)
                                .font(.headline)
                                .foregroundStyle(themeColors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.themeSecondary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                // Or pick specific time
                VStack(spacing: 8) {
                    Text("Or pick a specific time:")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)

                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 100)

                    Button {
                        // Set the selected time to tomorrow
                        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        components.hour = timeComponents.hour
                        components.minute = timeComponents.minute
                        if let time = Calendar.current.date(from: components) {
                            onPush(time)
                        }
                    } label: {
                        Text("Set for this time")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeAccent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color.themeBackground)
            .navigationTitle("Push to Tomorrow")
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
            SpeechService.shared.queueSpeech("When do you want to tackle this tomorrow?")
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
