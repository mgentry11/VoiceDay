import Foundation

// MARK: - GadflyTask

/// Unified task model used across the app
/// Wraps both EKReminder and custom tasks
struct GadflyTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var priority: ItemPriority
    var isCompleted: Bool
    var notes: String?
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var createdAt: Date
    var completedAt: Date?
    var subtasks: [GadflyTask]?

    // For linking to system reminders
    var calendarItemId: String?

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        priority: ItemPriority = .medium,
        isCompleted: Bool = false,
        notes: String? = nil,
        estimatedMinutes: Int? = nil,
        calendarItemId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.notes = notes
        self.estimatedMinutes = estimatedMinutes
        self.calendarItemId = calendarItemId
        self.createdAt = Date()
        self.completedAt = nil
        self.actualMinutes = nil
        self.subtasks = nil
    }

    // MARK: - Computed Properties

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }

    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let hoursUntilDue = dueDate.timeIntervalSinceNow / 3600
        return hoursUntilDue > 0 && hoursUntilDue <= 4
    }

    var hasSubtasks: Bool {
        guard let subtasks = subtasks else { return false }
        return !subtasks.isEmpty
    }

    var completedSubtasksCount: Int {
        subtasks?.filter { $0.isCompleted }.count ?? 0
    }

    var totalSubtasksCount: Int {
        subtasks?.count ?? 0
    }

    // MARK: - Mutations

    mutating func markComplete() {
        isCompleted = true
        completedAt = Date()
    }

    mutating func addSubtask(_ subtask: GadflyTask) {
        if subtasks == nil {
            subtasks = []
        }
        subtasks?.append(subtask)
    }

    mutating func setEstimatedDuration(_ minutes: Int) {
        estimatedMinutes = minutes
    }
}

// MARK: - Priority Extension
// ItemPriority already conforms to Codable in its definition

// MARK: - Task Helpers

extension GadflyTask {

    /// Create subtasks from a list of step strings
    static func subtasksFrom(steps: [String], parentPriority: ItemPriority = .medium) -> [GadflyTask] {
        steps.map { step in
            GadflyTask(
                title: step,
                priority: parentPriority
            )
        }
    }

    /// Estimate when task should be started based on duration and due date
    var suggestedStartTime: Date? {
        guard let dueDate = dueDate,
              let minutes = estimatedMinutes else { return nil }

        let bufferMinutes = 15 // Extra buffer time
        let totalMinutes = minutes + bufferMinutes

        return dueDate.addingTimeInterval(TimeInterval(-totalMinutes * 60))
    }

    /// User-friendly time remaining string
    var timeRemainingString: String? {
        guard let dueDate = dueDate else { return nil }

        let remaining = dueDate.timeIntervalSinceNow

        if remaining < 0 {
            return "Overdue"
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes)m left"
        } else {
            return "Due now"
        }
    }
}
