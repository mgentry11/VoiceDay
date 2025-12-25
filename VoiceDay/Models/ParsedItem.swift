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
    let vaultOperations: [VaultDTO]?
    let breakCommand: BreakDTO?
    let goals: [GoalDTO]?
    let goalOperations: [GoalOperationDTO]?
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

    struct VaultDTO: Decodable {
        let action: String  // "store", "retrieve", "delete", "list"
        let name: String    // The secret name
        let value: String?  // Only for store action
    }

    struct BreakDTO: Decodable {
        let durationMinutes: Int?   // Duration in minutes (e.g., 30, 60, 120)
        let endTime: String?        // ISO8601 end time for "until X" commands
        let isEndingBreak: Bool?    // True if user wants to END their break early
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
