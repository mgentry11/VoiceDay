import SwiftUI
import EventKit

struct TasksListView: View {
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var calendarService = CalendarService()
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var selectedReminder: EKReminder?
    @State private var showingDetail = false

    private var incompleteReminders: [EKReminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [EKReminder] {
        reminders.filter { $0.isCompleted }
    }

    var body: some View {
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
        }
        .task {
            _ = await calendarService.requestReminderAccess()
            await loadReminders()
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

        do {
            try await calendarService.toggleReminderComplete(reminder)

            // Small delay to let EventKit propagate the change
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Refresh the list FIRST so UI updates immediately
            await loadReminders()

            // Then celebrate (if marking complete)
            if !wasCompleted {
                await celebrateCompletion(taskTitle: taskTitle)
            }
        } catch {
            print("Error toggling reminder: \(error)")
        }
    }

    @MainActor
    private func celebrateCompletion(taskTitle: String) async {
        // Cancel any nags for this task
        NotificationService.shared.cancelAllRemindersForTask(taskId: taskTitle)

        // Get celebration message and speak it
        let celebration = NotificationService.shared.getCelebrationMessage(for: taskTitle)
        ConversationService.shared.addAssistantMessage(celebration)

        // Update app badge
        BackgroundAudioManager.shared.updateAppBadge()

        // Haptic feedback for completion
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Speak the celebration in parent's voice (or selected voice)
        await AppDelegate.shared?.speakMessage(celebration)
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
}

struct ReminderRow: View {
    let reminder: EKReminder
    let onToggleComplete: () -> Void
    let onTapRow: () -> Void
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox - separate tap target
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(reminder.isCompleted ? themeColors.success : themeColors.subtext)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleComplete()
                }

            // Row content - taps here open details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title ?? "Untitled")
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? themeColors.subtext : themeColors.text)

                    if let dueDate = reminder.dueDateComponents?.date {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dueDate, style: .date)
                            Text("at")
                            Text(dueDate, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                    }

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                            .lineLimit(2)
                    }
                }

                Spacer()

                priorityBadge

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.5))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapRow()
            }
        }
        .padding(.vertical, 4)
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
