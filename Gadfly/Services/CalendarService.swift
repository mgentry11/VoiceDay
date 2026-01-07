import Foundation
import EventKit

@MainActor
class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthStatus: EKAuthorizationStatus = .notDetermined

    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    func requestReminderAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            reminderAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
            return granted
        } catch {
            print("Reminder access error: \(error)")
            return false
        }
    }

    func createCalendarEvent(_ parsedEvent: ParsedEvent) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = parsedEvent.title
        event.startDate = parsedEvent.startDate
        event.endDate = parsedEvent.endDate ?? parsedEvent.startDate.addingTimeInterval(3600)
        event.location = parsedEvent.location
        event.notes = parsedEvent.notes

        event.calendar = eventStore.defaultCalendarForNewEvents

        event.addAlarm(EKAlarm(relativeOffset: -900))

        try eventStore.save(event, span: .thisEvent)

        return event.eventIdentifier
    }

    func createReminder(_ parsedReminder: ParsedReminder) throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = parsedReminder.title

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: parsedReminder.triggerDate
        )
        reminder.dueDateComponents = components

        let alarm = EKAlarm(absoluteDate: parsedReminder.triggerDate)
        reminder.addAlarm(alarm)

        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        try eventStore.save(reminder, commit: true)

        return reminder.calendarItemIdentifier
    }

    func createTask(_ parsedTask: ParsedTask) throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = parsedTask.title

        if let deadline = parsedTask.deadline {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: deadline
            )
            reminder.dueDateComponents = components

            let alarm = EKAlarm(absoluteDate: deadline)
            reminder.addAlarm(alarm)
        }

        switch parsedTask.priority {
        case .high:
            reminder.priority = 1
        case .medium:
            reminder.priority = 5
        case .low:
            reminder.priority = 9
        }

        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        try eventStore.save(reminder, commit: true)

        return reminder.calendarItemIdentifier
    }

    func fetchUpcomingEvents(days: Int = 7) -> [EKEvent] {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        return eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func fetchReminders(includeCompleted: Bool = false) async -> [EKReminder] {
        let predicate: NSPredicate
        if includeCompleted {
            // Fetch all reminders (completed and incomplete)
            predicate = eventStore.predicateForReminders(in: nil)
        } else {
            // Fetch only incomplete reminders
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: nil
            )
        }

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let sorted = (reminders ?? []).sorted { r1, r2 in
                    // Sort incomplete first, then by date
                    if r1.isCompleted != r2.isCompleted {
                        return !r1.isCompleted // Incomplete tasks first
                    }
                    let date1 = r1.dueDateComponents?.date ?? Date.distantFuture
                    let date2 = r2.dueDateComponents?.date ?? Date.distantFuture
                    return date1 < date2
                }
                continuation.resume(returning: sorted)
            }
        }
    }

    func toggleReminderComplete(_ reminder: EKReminder) async throws {
        reminder.isCompleted = !reminder.isCompleted
        if reminder.isCompleted {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }
        try eventStore.save(reminder, commit: true)
    }

    func updateReminder(_ reminder: EKReminder, title: String, notes: String?, dueDate: Date?, priority: Int) async throws {
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        if let dueDate = dueDate {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.dueDateComponents = components

            // Update alarm
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        } else {
            reminder.dueDateComponents = nil
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
        }

        try eventStore.save(reminder, commit: true)
    }

    func deleteReminder(_ reminder: EKReminder) async throws {
        try eventStore.remove(reminder, commit: true)
    }

    func completeReminder(_ reminder: EKReminder) async throws {
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    // MARK: - Push Task to Later/Tomorrow

    /// Push a task to tomorrow morning (9 AM)
    func pushToTomorrow(_ reminder: EKReminder) async throws {
        let calendar = Calendar.current
        var tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        // Set to 9 AM tomorrow
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0

        tomorrow = calendar.date(from: components) ?? tomorrow

        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: tomorrow
        )

        // Update alarm
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        let alarm = EKAlarm(absoluteDate: tomorrow)
        reminder.addAlarm(alarm)

        try eventStore.save(reminder, commit: true)
        print("📅 Pushed '\(reminder.title ?? "task")' to tomorrow")
    }

    /// Push a task to tomorrow at a specific time
    func pushToTomorrowAtTime(_ reminder: EKReminder, time: Date) async throws {
        try await pushToDate(reminder, date: time)
    }

    /// Push a task to any future date/time
    func pushToDate(_ reminder: EKReminder, date: Date) async throws {
        let calendar = Calendar.current
        let taskTitle = reminder.title ?? "task"

        print("🔄 PUSH START: '\(taskTitle)'")
        print("   isCompleted BEFORE: \(reminder.isCompleted)")
        print("   Target date: \(date)")

        // ONLY update the due date - nothing else
        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        print("   isCompleted AFTER setting date: \(reminder.isCompleted)")

        // Update alarm
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        let alarm = EKAlarm(absoluteDate: date)
        reminder.addAlarm(alarm)

        print("   isCompleted AFTER setting alarm: \(reminder.isCompleted)")

        // Save
        try eventStore.save(reminder, commit: true)

        print("   isCompleted AFTER save: \(reminder.isCompleted)")

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        print("🔄 PUSH DONE: '\(taskTitle)' to \(formatter.string(from: date))")
    }

    /// Push a task to later today (X hours from now)
    func pushToLater(_ reminder: EKReminder, hours: Int = 3) async throws {
        let calendar = Calendar.current
        let laterDate = calendar.date(byAdding: .hour, value: hours, to: Date())!

        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: laterDate
        )

        // Update alarm
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        let alarm = EKAlarm(absoluteDate: laterDate)
        reminder.addAlarm(alarm)

        try eventStore.save(reminder, commit: true)
        print("⏰ Pushed '\(reminder.title ?? "task")' to \(hours) hours later")
    }

    func deleteEvent(_ event: EKEvent) throws {
        try eventStore.remove(event, span: .thisEvent)
    }

    func updateEvent(_ event: EKEvent, title: String, startDate: Date, endDate: Date, location: String?, notes: String?) throws {
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        try eventStore.save(event, span: .thisEvent)
    }

    func saveAllItems(
        from result: OpenAIService.ParseResult,
        remindersEnabled: Bool = true,
        eventReminderMinutes: Int = 15,
        nagIntervalMinutes: Int = 5
    ) async throws -> SaveResult {
        var eventIds: [String] = []
        var reminderIds: [String] = []
        var taskIds: [String] = []

        let notificationService = NotificationService.shared

        for event in result.events {
            let id = try createCalendarEvent(event)
            eventIds.append(id)

            // Schedule notification for event
            if remindersEnabled {
                notificationService.scheduleEventReminder(
                    eventId: id,
                    title: event.title,
                    eventDate: event.startDate,
                    reminderMinutesBefore: eventReminderMinutes
                )
            }
        }

        for reminder in result.reminders {
            let id = try createReminder(reminder)
            reminderIds.append(id)

            // Schedule notification for reminder
            if remindersEnabled {
                notificationService.scheduleTaskReminder(
                    taskId: id,
                    title: reminder.title,
                    deadline: reminder.triggerDate,
                    reminderTime: reminder.triggerDate,
                    repeatInterval: nagIntervalMinutes
                )
            }
        }

        for task in result.tasks {
            let id = try createTask(task)
            taskIds.append(id)

            // Schedule notification for task with deadline
            if remindersEnabled, let deadline = task.deadline {
                // Calculate reminder time - X minutes before deadline
                var reminderTime = deadline.addingTimeInterval(-Double(eventReminderMinutes * 60))

                // If reminder time is in the past or very soon, schedule for 1 minute from now
                let minimumTime = Date().addingTimeInterval(60)
                if reminderTime < minimumTime {
                    reminderTime = minimumTime
                }

                print("📋 Task '\(task.title)' - deadline: \(deadline), reminder scheduled for: \(reminderTime)")

                notificationService.scheduleTaskReminder(
                    taskId: id,
                    title: task.title,
                    deadline: deadline,
                    reminderTime: reminderTime,
                    repeatInterval: nagIntervalMinutes
                )
            } else if remindersEnabled {
                // Task without deadline - schedule a reminder for 30 minutes from now as a nudge
                let reminderTime = Date().addingTimeInterval(30 * 60)
                print("📋 Task '\(task.title)' - no deadline, reminder in 30 min at: \(reminderTime)")

                notificationService.scheduleTaskReminder(
                    taskId: id,
                    title: task.title,
                    deadline: nil,
                    reminderTime: reminderTime,
                    repeatInterval: nagIntervalMinutes
                )
            }
        }

        return SaveResult(
            eventCount: eventIds.count,
            reminderCount: reminderIds.count,
            taskCount: taskIds.count
        )
    }

    struct SaveResult {
        let eventCount: Int
        let reminderCount: Int
        let taskCount: Int

        var totalCount: Int {
            eventCount + reminderCount + taskCount
        }

        var summary: String {
            var parts: [String] = []
            if eventCount > 0 {
                parts.append("\(eventCount) event\(eventCount == 1 ? "" : "s")")
            }
            if reminderCount > 0 {
                parts.append("\(reminderCount) reminder\(reminderCount == 1 ? "" : "s")")
            }
            if taskCount > 0 {
                parts.append("\(taskCount) task\(taskCount == 1 ? "" : "s")")
            }
            return parts.joined(separator: ", ")
        }
    }
}
