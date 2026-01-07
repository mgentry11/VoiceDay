import Foundation

enum ItemPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "red"
        }
    }
}

struct ParsedTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var deadline: Date?
    var priority: ItemPriority
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, deadline: Date? = nil, priority: ItemPriority = .medium, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

struct ParsedEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var location: String?
    var notes: String?
    var createdAt: Date

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date? = nil, location: String? = nil, notes: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.createdAt = createdAt
    }
}

struct ParsedReminder: Identifiable, Codable {
    let id: UUID
    var title: String
    var triggerDate: Date
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, triggerDate: Date, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.triggerDate = triggerDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

struct OpenAIParseResponse: Decodable {
    let tasks: [TaskDTO]?
    let events: [EventDTO]?
    let reminders: [ReminderDTO]?
    let notes: [NoteDTO]?
    let vaultOperations: [VaultDTO]?
    let breakCommand: BreakDTO?
    let goals: [GoalDTO]?
    let goalOperations: [GoalOperationDTO]?
    let rescheduleOperations: [RescheduleDTO]?
    let helpRequest: HelpRequestDTO?
    let clarifyingQuestion: String?
    let isComplete: Bool
    let summary: String?

    struct TaskDTO: Decodable {
        let title: String
        let deadline: String?
        let priority: String?
    }

    struct EventDTO: Decodable {
        let title: String
        let startDate: String
        let endDate: String?
        let location: String?
    }

    struct ReminderDTO: Decodable {
        let title: String
        let triggerDate: String
    }
    
    struct NoteDTO: Decodable {
        let content: String
        let title: String?
    }

    struct VaultDTO: Decodable {
        let action: String
        let name: String
        let value: String?
    }

    struct BreakDTO: Decodable {
        let durationMinutes: Int?
        let endTime: String?
        let isEndingBreak: Bool?
    }

    struct RescheduleDTO: Decodable {
        let taskTitle: String
        let newDate: String?
        let bringToToday: Bool?
    }
}

struct VaultOperation: Identifiable {
    let id = UUID()
    let action: VaultAction
    let name: String
    let value: String?

    enum VaultAction: String {
        case store
        case retrieve
        case delete
        case list
    }
}

// MARK: - Conversation Service

/// Shared service for managing conversation messages
/// Allows nags and notifications to be logged to the conversation history
@MainActor
class ConversationService: ObservableObject {
    static let shared = ConversationService()

    @Published var messages: [ConversationMessage] = []

    private let maxMessages = 100
    private let storageKey = "conversation_messages"

    init() {
        loadMessages()
    }

    func addUserMessage(_ content: String) {
        let message = ConversationMessage(role: .user, content: content, timestamp: Date())
        messages.append(message)
        trimAndSave()
    }

    func addAssistantMessage(_ content: String) {
        let message = ConversationMessage(role: .assistant, content: content, timestamp: Date())
        messages.append(message)
        trimAndSave()
    }

    func addNagMessage(_ content: String, forTask taskTitle: String) {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let formattedContent = "[\(formatter.string(from: timestamp))] Nag for \"\(taskTitle)\": \(content)"
        let message = ConversationMessage(role: .assistant, content: formattedContent, timestamp: timestamp, isNag: true)
        messages.append(message)
        trimAndSave()
    }

    func addFocusCheckIn(_ content: String) {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a" // Include seconds for accuracy
        let formattedContent = "[\(formatter.string(from: timestamp))] Focus check-in: \(content)"
        let message = ConversationMessage(role: .assistant, content: formattedContent, timestamp: timestamp, isNag: true)
        messages.append(message)
        trimAndSave()
        print("📝 Logged focus check-in at \(formatter.string(from: timestamp))")
    }

    var nagCount: Int {
        messages.filter { $0.isNag }.count
    }

    var todayNagCount: Int {
        let calendar = Calendar.current
        return messages.filter { $0.isNag && calendar.isDateInToday($0.timestamp) }.count
    }

    func clearAll() {
        messages.removeAll()
        save()
    }

    func clearNags() {
        messages.removeAll { $0.isNag }
        save()
    }

    private func trimAndSave() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let saved = try? decoder.decode([ConversationMessage].self, from: data) {
            messages = saved
        }
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let isNag: Bool

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(role: Role, content: String, timestamp: Date, isNag: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isNag = isNag
    }

    // For Codable
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, isNag
    }
}

// MARK: - Architect Models

struct ProductBlueprint: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var targetAudience: String
    var coreValueProposition: String
    var mvpFeatures: [String]
    var revenueModel: String
    var technicalStack: [String]
    var roadmap: [String]
    var confidenceScore: Double // 0.0 to 1.0 based on info gathered
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String = "", description: String = "", targetAudience: String = "", coreValueProposition: String = "", mvpFeatures: [String] = [], revenueModel: String = "", technicalStack: [String] = [], roadmap: [String] = [], confidenceScore: Double = 0.0, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.targetAudience = targetAudience
        self.coreValueProposition = coreValueProposition
        self.mvpFeatures = mvpFeatures
        self.revenueModel = revenueModel
        self.technicalStack = technicalStack
        self.roadmap = roadmap
        self.confidenceScore = confidenceScore
        self.createdAt = createdAt
    }
}

struct ArchitectDiscoveryResponse: Decodable {
    let blueprint: ProductBlueprintDTO?
    let analysis: String?
    let clarifyingQuestion: String?
    let infoCompleteness: Double
    let isReadyToFinalize: Bool
    
    struct ProductBlueprintDTO: Decodable {
        let title: String?
        let description: String?
        let targetAudience: String?
        let coreValueProposition: String?
        let mvpFeatures: [String]?
        let revenueModel: String?
        let technicalStack: [String]?
        let roadmap: [String]?
    }
}

// MARK: - Goal Models

enum GoalStatus: String, Codable, CaseIterable {
    case active, paused, completed, abandoned
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .active: return "target"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

struct Milestone: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var estimatedDays: Int?
    var isCompleted: Bool
    var completedAt: Date?
    var suggestedTasks: [String]
    init(id: UUID = UUID(), title: String, description: String? = nil, estimatedDays: Int? = nil, isCompleted: Bool = false, completedAt: Date? = nil, suggestedTasks: [String] = []) {
        self.id = id; self.title = title; self.description = description; self.estimatedDays = estimatedDays; self.isCompleted = isCompleted; self.completedAt = completedAt; self.suggestedTasks = suggestedTasks
    }
}

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var targetDate: Date?
    var status: GoalStatus
    var milestones: [Milestone]
    var currentMilestoneIndex: Int
    var dailyTimeMinutes: Int?
    var preferredDays: [Int]?
    var linkedTaskIds: [String]
    var completedTaskCount: Int
    var createdAt: Date
    var lastProgressUpdate: Date
    var lastWorkSession: Date?

    var progressPercentage: Double {
        if milestones.isEmpty {
            guard linkedTaskIds.count > 0 else { return 0 }
            return Double(completedTaskCount) / Double(linkedTaskIds.count) * 100
        }
        let completed = milestones.filter { $0.isCompleted }.count
        return Double(completed) / Double(milestones.count) * 100
    }
    var daysSinceLastProgress: Int { Calendar.current.dateComponents([.day], from: lastProgressUpdate, to: Date()).day ?? 0 }
    var currentMilestone: Milestone? { (currentMilestoneIndex >= 0 && currentMilestoneIndex < milestones.count) ? milestones[currentMilestoneIndex] : nil }
    var completedMilestonesCount: Int { milestones.filter { $0.isCompleted }.count }
    var neglectLevel: Int {
        switch daysSinceLastProgress {
        case 0...1: return 0
        case 2...3: return 1
        case 4...6: return 2
        case 7...13: return 3
        case 14...29: return 4
        default: return 5
        }
    }
    var scheduleDescription: String {
        var parts: [String] = []
        if let mins = dailyTimeMinutes { parts.append(mins >= 60 ? "\(mins/60)h \(mins%60)m/day" : "\(mins) min/day") }
        return parts.joined()
    }

    init(id: UUID = UUID(), title: String, description: String? = nil, targetDate: Date? = nil, status: GoalStatus = .active, milestones: [Milestone] = [], currentMilestoneIndex: Int = 0, dailyTimeMinutes: Int? = nil, preferredDays: [Int]? = nil, linkedTaskIds: [String] = [], completedTaskCount: Int = 0, createdAt: Date = Date(), lastProgressUpdate: Date = Date(), lastWorkSession: Date? = nil) {
        self.id = id; self.title = title; self.description = description; self.targetDate = targetDate; self.status = status; self.milestones = milestones; self.currentMilestoneIndex = currentMilestoneIndex; self.dailyTimeMinutes = dailyTimeMinutes; self.preferredDays = preferredDays; self.linkedTaskIds = linkedTaskIds; self.completedTaskCount = completedTaskCount; self.createdAt = createdAt; self.lastProgressUpdate = lastProgressUpdate; self.lastWorkSession = lastWorkSession
    }

    mutating func completeMilestone(at index: Int) {
        guard index >= 0 && index < milestones.count else { return }
        milestones[index].isCompleted = true
        milestones[index].completedAt = Date()
        lastProgressUpdate = Date()
        if let next = milestones.firstIndex(where: { !$0.isCompleted }) { currentMilestoneIndex = next }
        else { status = .completed }
    }
    mutating func recordProgress() { lastProgressUpdate = Date() }
    mutating func recordWorkSession() { lastWorkSession = Date(); lastProgressUpdate = Date() }
    mutating func linkTask(taskId: String) { if !linkedTaskIds.contains(taskId) { linkedTaskIds.append(taskId) } }
    mutating func recordTaskCompletion() { completedTaskCount += 1; lastProgressUpdate = Date() }
}

struct GoalDTO: Decodable {
    let title: String; let description: String?; let targetDate: String?; let milestones: [MilestoneDTO]?; let dailyTimeMinutes: Int?; let preferredDays: [Int]?
    struct MilestoneDTO: Decodable { let title: String; let description: String?; let estimatedDays: Int?; let tasks: [String]? }
}
struct GoalOperationDTO: Decodable {
    let action: String; let goalId: UUID?; let goalTitle: String?; let taskTitle: String?; let progressNote: String?; let milestoneIndex: Int?
}
struct HelpRequestDTO: Decodable { let topic: String?; let isFirstTime: Bool? }
