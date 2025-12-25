import Foundation
import UIKit

@MainActor
class VoiceDayAPIService: ObservableObject {
    static let shared = VoiceDayAPIService()

    private let baseURL = "https://bigoil-backend.onrender.com/api/voiceday"

    @Published var isRegistered = false
    @Published var connections: [VoiceDayConnection] = []
    @Published var sharedTasks: [SharedTask] = []
    @Published var nags: [NagMessage] = []

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    // MARK: - Registration

    func register(name: String, phone: String, pushToken: String = "") async throws {
        let url = URL(string: "\(baseURL)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "name": name,
            "phone": phone,
            "push_token": pushToken
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.registrationFailed
        }

        isRegistered = true
        print("✅ VoiceDay registration successful")
    }

    // MARK: - Connections

    func fetchConnections() async throws {
        let url = URL(string: "\(baseURL)/connections?device_id=\(deviceId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        connections = try JSONDecoder().decode([VoiceDayConnection].self, from: data)
    }

    func addConnection(phone: String, nickname: String, relationship: String) async throws -> VoiceDayConnection {
        let url = URL(string: "\(baseURL)/connections")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "owner_device_id": deviceId,
            "connected_phone": phone,
            "nickname": nickname,
            "relationship": relationship
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.connectionFailed
        }

        let connection = try JSONDecoder().decode(VoiceDayConnection.self, from: data)
        connections.append(connection)
        return connection
    }

    func deleteConnection(_ connectionId: String) async throws {
        let url = URL(string: "\(baseURL)/connections/\(connectionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
        connections.removeAll { $0.id == connectionId }
    }

    // MARK: - Shared Tasks

    func fetchSharedTasks() async throws {
        let url = URL(string: "\(baseURL)/shared-tasks?device_id=\(deviceId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        sharedTasks = try JSONDecoder().decode([SharedTask].self, from: data)
    }

    func createSharedTask(
        title: String,
        assignedPhone: String,
        assignedDeviceId: String?,
        deadline: Date?,
        priority: String = "medium",
        nagIntervalMinutes: Int = 15
    ) async throws -> SharedTask {
        let url = URL(string: "\(baseURL)/shared-tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "owner_device_id": deviceId,
            "assigned_phone": assignedPhone,
            "title": title,
            "priority": priority,
            "nag_interval_minutes": nagIntervalMinutes
        ]

        if let assignedDeviceId = assignedDeviceId {
            body["assigned_device_id"] = assignedDeviceId
        }

        if let deadline = deadline {
            let formatter = ISO8601DateFormatter()
            body["deadline"] = formatter.string(from: deadline)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.taskCreationFailed
        }

        let task = try JSONDecoder().decode(SharedTask.self, from: data)
        sharedTasks.append(task)
        return task
    }

    func updateSharedTask(_ taskId: String, completed: Bool) async throws {
        let url = URL(string: "\(baseURL)/shared-tasks/\(taskId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["is_completed": completed]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)

        if let index = sharedTasks.firstIndex(where: { $0.id == taskId }) {
            let task = sharedTasks[index]
            sharedTasks[index].isCompleted = completed

            // If completing a task assigned to me, award points and celebrate!
            if completed && task.isAssignedToMe {
                await celebrateTaskCompletion(task)
            }
        }
    }

    /// Celebrate completing a shared task with points and message
    private func celebrateTaskCompletion(_ task: SharedTask) async {
        // Determine priority
        let priority = ItemPriority(rawValue: task.priority) ?? .medium

        // Award points
        RewardsService.shared.awardPoints(
            for: task.title,
            priority: priority,
            deadline: task.deadline
        )

        // Get points earned
        let points = RewardsService.shared.currentTeam?.pointRules.pointsFor(
            priority: priority,
            wasEarly: task.deadline.map { Date() < $0 } ?? false,
            wasLate: task.deadline.map { Date() > $0 } ?? false
        ) ?? 15

        // Generate celebration message with points
        let celebration = NotificationService.shared.getCelebrationMessage(for: task.title)
        let fullMessage = "\(celebration) You earned \(points) Gadfly points!"

        // Add to conversation
        ConversationService.shared.addAssistantMessage(fullMessage)

        // Speak celebration
        await AppDelegate.shared?.speakMessage(fullMessage)
    }

    func deleteSharedTask(_ taskId: String) async throws {
        let url = URL(string: "\(baseURL)/shared-tasks/\(taskId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await URLSession.shared.data(for: request)
        sharedTasks.removeAll { $0.id == taskId }
    }

    // MARK: - Nagging

    func sendNag(toDeviceId: String?, toPhone: String, taskId: String?, message: String) async throws -> NagResult {
        let url = URL(string: "\(baseURL)/nag")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "from_device_id": deviceId,
            "to_phone": toPhone,
            "message": message
        ]

        if let toDeviceId = toDeviceId {
            body["to_device_id"] = toDeviceId
        }

        if let taskId = taskId {
            body["task_id"] = taskId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.nagFailed
        }

        return try JSONDecoder().decode(NagResult.self, from: data)
    }

    func fetchNags() async throws {
        let url = URL(string: "\(baseURL)/nags?device_id=\(deviceId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        nags = try JSONDecoder().decode([NagMessage].self, from: data)
    }

    func acknowledgeNag(_ nagId: String) async throws {
        let url = URL(string: "\(baseURL)/nags/\(nagId)/acknowledge")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        _ = try await URLSession.shared.data(for: request)

        if let index = nags.firstIndex(where: { $0.id == nagId }) {
            nags[index].acknowledgedAt = Date()
        }
    }

    // MARK: - User Lookup

    func lookupUser(phone: String) async throws -> UserLookupResult {
        let url = URL(string: "\(baseURL)/lookup-user?phone=\(phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? phone)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(UserLookupResult.self, from: data)
    }
}

// MARK: - Models

struct VoiceDayConnection: Identifiable, Codable {
    let id: String
    let ownerDeviceId: String
    let connectedDeviceId: String?
    let connectedPhone: String
    let relationship: String
    let nickname: String
    let createdAt: Date?
    var hasApp: Bool { connectedDeviceId != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerDeviceId = "owner_device_id"
        case connectedDeviceId = "connected_device_id"
        case connectedPhone = "connected_phone"
        case relationship
        case nickname
        case createdAt = "created_at"
    }
}

struct SharedTask: Identifiable, Codable {
    let id: String
    let ownerDeviceId: String
    let assignedDeviceId: String?
    let assignedPhone: String
    let title: String
    let deadline: Date?
    let priority: String
    let nagIntervalMinutes: Int
    var isCompleted: Bool
    let createdAt: Date?

    var isOwner: Bool {
        ownerDeviceId == UIDevice.current.identifierForVendor?.uuidString
    }

    var isAssignedToMe: Bool {
        assignedDeviceId == UIDevice.current.identifierForVendor?.uuidString
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerDeviceId = "owner_device_id"
        case assignedDeviceId = "assigned_device_id"
        case assignedPhone = "assigned_phone"
        case title
        case deadline
        case priority
        case nagIntervalMinutes = "nag_interval_minutes"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
    }
}

struct NagMessage: Identifiable, Codable {
    let id: String
    let fromDeviceId: String
    let toDeviceId: String?
    let toPhone: String?
    let taskId: String?
    let message: String
    var acknowledgedAt: Date?
    let createdAt: Date?

    var isSent: Bool {
        fromDeviceId == UIDevice.current.identifierForVendor?.uuidString
    }

    var isReceived: Bool {
        toDeviceId == UIDevice.current.identifierForVendor?.uuidString
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fromDeviceId = "from_device_id"
        case toDeviceId = "to_device_id"
        case toPhone = "to_phone"
        case taskId = "task_id"
        case message
        case acknowledgedAt = "acknowledged_at"
        case createdAt = "created_at"
    }
}

struct NagResult: Codable {
    let success: Bool
    let nagId: String?
    let deliveryMethod: String

    enum CodingKeys: String, CodingKey {
        case success
        case nagId = "nag_id"
        case deliveryMethod = "delivery_method"
    }
}

struct UserLookupResult: Codable {
    let found: Bool
    let hasApp: Bool
    let name: String?
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case found
        case hasApp = "has_app"
        case name
        case deviceId = "device_id"
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case registrationFailed
    case connectionFailed
    case taskCreationFailed
    case nagFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .registrationFailed: return "Failed to register device"
        case .connectionFailed: return "Failed to add connection"
        case .taskCreationFailed: return "Failed to create shared task"
        case .nagFailed: return "Failed to send nag message"
        case .networkError: return "Network connection error"
        }
    }
}

// MARK: - Rewards Service (Consolidated from RewardsSystem.swift)

enum RewardType: String, Codable, CaseIterable {
    case coffee = "coffee"
    case money = "money"
    case giftCard = "gift_card"
    case doordash = "doordash"
    case ubereats = "ubereats"
    case timeOff = "time_off"
    case custom = "custom"

    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .money: return "dollarsign.circle.fill"
        case .giftCard: return "giftcard.fill"
        case .doordash: return "bag.fill"
        case .ubereats: return "car.fill"
        case .timeOff: return "clock.badge.checkmark.fill"
        case .custom: return "star.fill"
        }
    }

    var displayName: String {
        switch self {
        case .coffee: return "Coffee"
        case .money: return "Cash Bonus"
        case .giftCard: return "Gift Card"
        case .doordash: return "DoorDash"
        case .ubereats: return "Uber Eats"
        case .timeOff: return "Time Off"
        case .custom: return "Custom Reward"
        }
    }

    var color: String {
        switch self {
        case .doordash: return "#FF3008" // DoorDash red
        case .ubereats: return "#06C167" // Uber green
        case .coffee: return "#6F4E37"   // Coffee brown
        case .money: return "#85BB65"    // Dollar green
        default: return "#10B981"        // App green
        }
    }
}

struct RewardConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: RewardType
    var pointCost: Int
    var dollarValue: Double?
    var description: String
    var isActive: Bool
    var quantity: Int?

    init(id: UUID = UUID(), name: String, type: RewardType, pointCost: Int, dollarValue: Double? = nil, description: String = "", isActive: Bool = true, quantity: Int? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.pointCost = pointCost
        self.dollarValue = dollarValue
        self.description = description
        self.isActive = isActive
        self.quantity = quantity
    }
}

struct PointRules: Codable {
    var pointsPerTask: Int = 10
    var pointsPerHighPriority: Int = 25
    var pointsPerMediumPriority: Int = 15
    var pointsPerLowPriority: Int = 10
    var bonusForEarlyCompletion: Int = 5
    var bonusForStreak: Int = 10
    var penaltyForLate: Int = -5

    func pointsFor(priority: ItemPriority, wasEarly: Bool, wasLate: Bool) -> Int {
        var points: Int
        switch priority {
        case .high: points = pointsPerHighPriority
        case .medium: points = pointsPerMediumPriority
        case .low: points = pointsPerLowPriority
        }

        if wasEarly { points += bonusForEarlyCompletion }
        if wasLate { points += penaltyForLate }

        return max(0, points)
    }
}

struct TeamMember: Identifiable, Codable {
    let id: UUID
    var userId: String
    var name: String
    var role: TeamRole
    var points: Int
    var tasksCompleted: Int
    var currentStreak: Int
    var joinedAt: Date

    enum TeamRole: String, Codable {
        case manager
        case employee
    }
}

struct RewardRedemption: Identifiable, Codable {
    let id: UUID
    let memberId: UUID
    let rewardId: UUID
    let rewardName: String
    let pointsSpent: Int
    let redeemedAt: Date
    var status: RedemptionStatus
    var fulfilledAt: Date?
    var fulfilledBy: String?

    enum RedemptionStatus: String, Codable {
        case pending
        case approved
        case fulfilled
        case denied
    }
}

struct Team: Identifiable, Codable {
    let id: UUID
    var name: String
    var managerId: String
    var pointRules: PointRules
    var rewards: [RewardConfig]
    var members: [TeamMember]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, managerId: String) {
        self.id = id
        self.name = name
        self.managerId = managerId
        self.pointRules = PointRules()
        self.rewards = Self.defaultRewards()
        self.members = []
        self.createdAt = Date()
    }

    static func defaultRewards() -> [RewardConfig] {
        [
            RewardConfig(name: "DoorDash Lunch", type: .doordash, pointCost: 100, dollarValue: 15, description: "Get lunch delivered on us - $15 DoorDash credit"),
            RewardConfig(name: "DoorDash Dinner", type: .doordash, pointCost: 150, dollarValue: 25, description: "Dinner's on us - $25 DoorDash credit"),
            RewardConfig(name: "Coffee on the Boss", type: .coffee, pointCost: 50, dollarValue: 5, description: "Redeem for a $5 coffee of your choice"),
            RewardConfig(name: "$10 Bonus", type: .money, pointCost: 100, dollarValue: 10, description: "Cash bonus added to next paycheck"),
            RewardConfig(name: "$25 Gift Card", type: .giftCard, pointCost: 200, dollarValue: 25, description: "Amazon, Starbucks, or your choice"),
            RewardConfig(name: "30 Min Early Leave", type: .timeOff, pointCost: 75, description: "Leave 30 minutes early on a day of your choice"),
            RewardConfig(name: "Work From Home Day", type: .timeOff, pointCost: 150, description: "One remote work day"),
            RewardConfig(name: "Lunch with the CEO", type: .custom, pointCost: 500, description: "Exclusive lunch with company leadership")
        ]
    }
}

@MainActor
class RewardsService: ObservableObject {
    static let shared = RewardsService()

    @Published var currentTeam: Team?
    @Published var myPoints: Int = 0
    @Published var pendingRedemptions: [RewardRedemption] = []

    private let storageKey = "rewards_data"

    init() {
        loadData()
    }

    func awardPoints(for taskTitle: String, priority: ItemPriority, deadline: Date?, completedAt: Date = Date()) {
        guard let team = currentTeam else { return }

        let wasEarly = deadline.map { completedAt < $0 } ?? false
        let wasLate = deadline.map { completedAt > $0 } ?? false

        let points = team.pointRules.pointsFor(priority: priority, wasEarly: wasEarly, wasLate: wasLate)

        myPoints += points
        saveData()

        let pointsMessage = points > 0 ? " You've earned \(points) Gadfly points!" : ""
        print("🏆 Awarded \(points) points for completing '\(taskTitle)'\(pointsMessage)")
    }

    func redeemReward(_ reward: RewardConfig) -> Bool {
        guard myPoints >= reward.pointCost else { return false }
        guard reward.isActive else { return false }

        myPoints -= reward.pointCost

        let redemption = RewardRedemption(
            id: UUID(),
            memberId: UUID(),
            rewardId: reward.id,
            rewardName: reward.name,
            pointsSpent: reward.pointCost,
            redeemedAt: Date(),
            status: .pending
        )

        pendingRedemptions.append(redemption)
        saveData()

        return true
    }

    func createTeam(name: String) {
        currentTeam = Team(name: name, managerId: "current_user")
        saveData()
    }

    func updatePointRules(_ rules: PointRules) {
        currentTeam?.pointRules = rules
        saveData()
    }

    func addReward(_ reward: RewardConfig) {
        currentTeam?.rewards.append(reward)
        saveData()
    }

    func approveRedemption(_ redemption: RewardRedemption) {
        if let index = pendingRedemptions.firstIndex(where: { $0.id == redemption.id }) {
            pendingRedemptions[index].status = .approved
            saveData()
        }
    }

    func fulfillRedemption(_ redemption: RewardRedemption) {
        if let index = pendingRedemptions.firstIndex(where: { $0.id == redemption.id }) {
            pendingRedemptions[index].status = .fulfilled
            pendingRedemptions[index].fulfilledAt = Date()
            saveData()
        }
    }

    func fulfillDoorDashReward(_ redemption: RewardRedemption, recipientEmail: String, recipientName: String, amount: Double) async {
        // Mock DoorDash fulfillment
        print("Mock DoorDash reward fulfilled for \(recipientName) (\(recipientEmail)) amount $\(amount)")
        fulfillRedemption(redemption)
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(currentTeam) {
            UserDefaults.standard.set(encoded, forKey: "current_team")
        }
        UserDefaults.standard.set(myPoints, forKey: "my_points")
    }

    private func loadData() {
        myPoints = UserDefaults.standard.integer(forKey: "my_points")
        if let data = UserDefaults.standard.data(forKey: "current_team"),
           let team = try? JSONDecoder().decode(Team.self, from: data) {
            currentTeam = team
        }
    }
}

// MARK: - Celebration Message Extension

extension NotificationService {
    func getCelebrationMessageWithPoints(for taskTitle: String, points: Int) -> String {
        let baseMessage = getCelebrationMessage(for: taskTitle)
        if points > 0 {
            return "\(baseMessage) You've earned \(points) Gadfly points."
        }
        return baseMessage
    }
}
