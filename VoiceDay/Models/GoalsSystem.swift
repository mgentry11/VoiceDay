import Foundation

// MARK: - Goal Status

enum GoalStatus: String, Codable, CaseIterable {
    case active
    case paused
    case completed
    case abandoned

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .abandoned: return "Abandoned"
        }
    }

    var icon: String {
        switch self {
        case .active: return "target"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

// MARK: - Milestone

struct Milestone: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var estimatedDays: Int?
    var isCompleted: Bool
    var completedAt: Date?
    var suggestedTasks: [String]

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        estimatedDays: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        suggestedTasks: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.estimatedDays = estimatedDays
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.suggestedTasks = suggestedTasks
    }
}

// MARK: - Goal

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var targetDate: Date?
    var status: GoalStatus

    // Milestone-based structure
    var milestones: [Milestone]
    var currentMilestoneIndex: Int

    // Schedule
    var dailyTimeMinutes: Int?
    var preferredDays: [Int]?  // 0=Sun, 1=Mon, etc.

    // Task linking
    var linkedTaskIds: [String]  // EKReminder calendarItemIdentifier
    var completedTaskCount: Int

    // Timestamps
    var createdAt: Date
    var lastProgressUpdate: Date
    var lastWorkSession: Date?

    // MARK: - Computed Properties

    var progressPercentage: Double {
        if milestones.isEmpty {
            guard linkedTaskIds.count > 0 else { return 0 }
            return Double(completedTaskCount) / Double(linkedTaskIds.count) * 100
        } else {
            let completedMilestones = milestones.filter { $0.isCompleted }.count
            return Double(completedMilestones) / Double(milestones.count) * 100
        }
    }

    var daysSinceLastProgress: Int {
        Calendar.current.dateComponents([.day], from: lastProgressUpdate, to: Date()).day ?? 0
    }

    var daysSinceLastWorkSession: Int? {
        guard let lastWork = lastWorkSession else { return nil }
        return Calendar.current.dateComponents([.day], from: lastWork, to: Date()).day
    }

    /// Neglect level from 0 (active) to 5 (severely neglected)
    var neglectLevel: Int {
        switch daysSinceLastProgress {
        case 0...1: return 0   // Active
        case 2...3: return 1   // Gentle reminder
        case 4...6: return 2   // Concerned
        case 7...13: return 3  // Disappointed
        case 14...29: return 4 // Harsh
        default: return 5      // Maximum harshness
        }
    }

    var currentMilestone: Milestone? {
        guard currentMilestoneIndex >= 0 && currentMilestoneIndex < milestones.count else {
            return nil
        }
        return milestones[currentMilestoneIndex]
    }

    var completedMilestonesCount: Int {
        milestones.filter { $0.isCompleted }.count
    }

    var remainingMilestonesCount: Int {
        milestones.count - completedMilestonesCount
    }

    var estimatedTotalDays: Int {
        milestones.compactMap { $0.estimatedDays }.reduce(0, +)
    }

    var estimatedRemainingDays: Int {
        milestones.filter { !$0.isCompleted }.compactMap { $0.estimatedDays }.reduce(0, +)
    }

    var scheduleDescription: String {
        var parts: [String] = []
        if let minutes = dailyTimeMinutes {
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                if mins > 0 {
                    parts.append("\(hours)h \(mins)m/day")
                } else {
                    parts.append("\(hours)h/day")
                }
            } else {
                parts.append("\(minutes) min/day")
            }
        }
        if let days = preferredDays, !days.isEmpty {
            let dayNames = days.map { dayOfWeekShort($0) }.joined(separator: ", ")
            parts.append(dayNames)
        }
        return parts.joined(separator: " on ")
    }

    private func dayOfWeekShort(_ day: Int) -> String {
        switch day {
        case 0: return "Sun"
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        default: return ""
        }
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        targetDate: Date? = nil,
        status: GoalStatus = .active,
        milestones: [Milestone] = [],
        currentMilestoneIndex: Int = 0,
        dailyTimeMinutes: Int? = nil,
        preferredDays: [Int]? = nil,
        linkedTaskIds: [String] = [],
        completedTaskCount: Int = 0,
        createdAt: Date = Date(),
        lastProgressUpdate: Date = Date(),
        lastWorkSession: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.status = status
        self.milestones = milestones
        self.currentMilestoneIndex = currentMilestoneIndex
        self.dailyTimeMinutes = dailyTimeMinutes
        self.preferredDays = preferredDays
        self.linkedTaskIds = linkedTaskIds
        self.completedTaskCount = completedTaskCount
        self.createdAt = createdAt
        self.lastProgressUpdate = lastProgressUpdate
        self.lastWorkSession = lastWorkSession
    }

    // MARK: - Mutating Methods

    mutating func completeMilestone(at index: Int) {
        guard index >= 0 && index < milestones.count else { return }
        milestones[index].isCompleted = true
        milestones[index].completedAt = Date()
        lastProgressUpdate = Date()

        // Advance to next incomplete milestone
        if let nextIndex = milestones.firstIndex(where: { !$0.isCompleted }) {
            currentMilestoneIndex = nextIndex
        } else {
            // All milestones complete
            status = .completed
        }
    }

    mutating func completeCurrentMilestone() {
        completeMilestone(at: currentMilestoneIndex)
    }

    mutating func recordProgress() {
        lastProgressUpdate = Date()
    }

    mutating func recordWorkSession() {
        lastWorkSession = Date()
        lastProgressUpdate = Date()
    }

    mutating func linkTask(taskId: String) {
        if !linkedTaskIds.contains(taskId) {
            linkedTaskIds.append(taskId)
        }
    }

    mutating func unlinkTask(taskId: String) {
        linkedTaskIds.removeAll { $0 == taskId }
    }

    mutating func recordTaskCompletion() {
        completedTaskCount += 1
        lastProgressUpdate = Date()
    }
}

// MARK: - Goal DTO for AI Parsing

struct GoalDTO: Decodable {
    let title: String
    let description: String?
    let targetDate: String?
    let milestones: [MilestoneDTO]?
    let dailyTimeMinutes: Int?
    let preferredDays: [Int]?

    struct MilestoneDTO: Decodable {
        let title: String
        let description: String?
        let estimatedDays: Int?
        let tasks: [String]?
    }
}

struct GoalOperationDTO: Decodable {
    let action: String        // "create", "link", "progress", "pause", "resume", "complete_milestone", "delete"
    let goalId: UUID?         // For direct goal reference
    let goalTitle: String?    // For referencing existing goals by name
    let taskTitle: String?    // For linking tasks
    let progressNote: String? // For progress updates
    let milestoneIndex: Int?  // For milestone operations
}

struct HelpRequestDTO: Decodable {
    let topic: String?       // "goals", "accountability", "break", "vault", "general"
    let isFirstTime: Bool?   // Trigger onboarding
}
