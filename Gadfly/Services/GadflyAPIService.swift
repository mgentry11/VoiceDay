import Foundation
import UIKit

@MainActor
class GadflyAPIService: ObservableObject {
    static let shared = GadflyAPIService()

    private let baseURL = "https://bigoil-backend.onrender.com/api/voiceday"

    @Published var isRegistered = false
    @Published var connections: [GadflyConnection] = []
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
        print("✅ Gadfly registration successful")
    }

    // MARK: - Connections

    func fetchConnections() async throws {
        let url = URL(string: "\(baseURL)/connections?device_id=\(deviceId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        connections = try JSONDecoder().decode([GadflyConnection].self, from: data)
    }

    func addConnection(phone: String, nickname: String, relationship: String) async throws -> GadflyConnection {
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

        let connection = try JSONDecoder().decode(GadflyConnection.self, from: data)
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

struct GadflyConnection: Identifiable, Codable {
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

    static func familyRewards() -> [RewardConfig] {
        [
            RewardConfig(name: "Extra Screen Time", type: .custom, pointCost: 50, description: "30 minutes extra screen time"),
            RewardConfig(name: "Pick Dinner", type: .custom, pointCost: 75, description: "Choose what's for dinner tonight"),
            RewardConfig(name: "Stay Up Late", type: .timeOff, pointCost: 100, description: "Stay up 30 minutes past bedtime"),
            RewardConfig(name: "Ice Cream Trip", type: .custom, pointCost: 100, description: "Trip to get ice cream"),
            RewardConfig(name: "Movie Night Pick", type: .custom, pointCost: 75, description: "Choose the movie for movie night"),
            RewardConfig(name: "Skip One Chore", type: .custom, pointCost: 50, description: "Skip one assigned chore"),
            RewardConfig(name: "Friend Sleepover", type: .custom, pointCost: 200, description: "Have a friend sleep over"),
            RewardConfig(name: "New Game/Toy", type: .giftCard, pointCost: 300, dollarValue: 20, description: "$20 toward a new game or toy")
        ]
    }
}

@MainActor
class RewardsService: ObservableObject {
    static let shared = RewardsService()

    @Published var currentTeam: Team?
    @Published var myPoints: Int = 0
    @Published var pendingRedemptions: [RewardRedemption] = []
    @Published var streakData: StreakData = StreakData()
    @Published var dailyChallenges: [DailyChallenge] = []
    @Published var achievements: [Achievement] = Achievement.allAchievements
    @Published var totalTasksCompleted: Int = 0
    @Published var totalPointsEarned: Int = 0

    var unlockedAchievementsCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }

    private let storageKey = "rewards_data"

    init() {
        loadData()
        refreshDailyChallenges()
    }

    func refreshDailyChallenges() {
        let today = StreakData.dateString(from: Date())
        if dailyChallenges.isEmpty || dailyChallenges.first?.dateCreated != today {
            dailyChallenges = DailyChallenge.generateForToday()
        }
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

// MARK: - Architect Service

@MainActor
class ArchitectService: ObservableObject {
    static let shared = ArchitectService()
    
    @Published var isProcessing = false
    @Published var currentBlueprint = ProductBlueprint()
    @Published var discoveryMessages: [ConversationMessage] = []
    @Published var infoCompleteness: Double = 0.0
    @Published var isReadyToFinalize: Bool = false
    
    private var conversationHistory: [[String: String]] = []
    
    private let systemPrompt = """
    You are 'The Architect', a world-class product strategist and systems thinker with the dry, sardonic wit of an Oxford-educated polymath (The Gadfly persona). 
    
    YOUR GOAL:
    Help the user define a product from their stream-of-consciousness thoughts. You must extract structured information while providing high-level strategic advice.
    
    THE PROCESS:
    1. LISTEN: Analyze their rant/thoughts.
    2. EXTRACT: Update the 'Product Blueprint' with what you've learned.
    3. GAP ANALYSIS: Identify what is missing (Target Audience, Revenue Model, Tech Stack, etc.).
    4. QUESTION: Ask exactly ONE sharp, insightful question to fill a specific gap. 
    
    BLUEPRINT FIELDS:
    - title: Catchy but descriptive name.
    - description: 1-2 sentence summary.
    - targetAudience: Who specifically is this for?
    - coreValueProposition: Why would they care?
    - mvpFeatures: List of 3-5 essential features.
    - revenueModel: How does it make money or sustain itself?
    - technicalStack: Recommended tools/platforms.
    - roadmap: 3 high-level phases (Alpha, Beta, v1).
    
    TONE:
     Disappointed but brilliant. Use the Gadfly's vocabulary (pedestrian, entropy, Aristotelian). Be encouraging about the product idea but slightly dismissive of the user's current level of organization.
    
    RESPONSE FORMAT:
    You MUST respond with a JSON object:
    {
        "blueprint": {
            "title": "...",
            "description": "...",
            "targetAudience": "...",
            "coreValueProposition": "...",
            "mvpFeatures": ["..."],
            "revenueModel": "...",
            "technicalStack": ["..."],
            "roadmap": ["..."]
        },
        "analysis": "A quick, witty Gadfly-style analysis of their current progress.",
        "clarifyingQuestion": "Exactly one insightful question.",
        "infoCompleteness": 0.0 to 1.0,
        "isReadyToFinalize": true/false (true if you have enough to build a solid 1.0 plan)
    }
    """
    
    func resetSession() {
        currentBlueprint = ProductBlueprint()
        discoveryMessages = []
        conversationHistory = []
        infoCompleteness = 0.0
        isReadyToFinalize = false
    }
    
    func processDiscoveryInput(_ input: String, apiKey: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        discoveryMessages.append(ConversationMessage(role: .user, content: input, timestamp: Date()))
        conversationHistory.append(["role": "user", "content": input])
        
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": conversationHistory
        ]
        
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.invalidResponse(message: "Architect API Error: \(errorText)")
        }
        
        let decoder = JSONDecoder()
        let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
        guard let content = claudeResponse.content.first?.text else { throw AIServiceError.noContent }
        
        let jsonText = extractJSON(from: content)
        guard let jsonData = jsonText.data(using: .utf8) else { throw AIServiceError.parsingFailed(message: "Invalid JSON from Architect") }
        
        let discoveryResult = try decoder.decode(ArchitectDiscoveryResponse.self, from: jsonData)
        
        updateBlueprint(from: discoveryResult.blueprint)
        self.infoCompleteness = discoveryResult.infoCompleteness
        self.isReadyToFinalize = discoveryResult.isReadyToFinalize
        
        if let analysis = discoveryResult.analysis, let question = discoveryResult.clarifyingQuestion {
            let combinedResponse = analysis + "\n\n" + question
            discoveryMessages.append(ConversationMessage(role: .assistant, content: combinedResponse, timestamp: Date()))
            conversationHistory.append(["role": "assistant", "content": content])
        }
    }
    
    private func updateBlueprint(from dto: ArchitectDiscoveryResponse.ProductBlueprintDTO?) {
        guard let dto = dto else { return }
        if let val = dto.title { currentBlueprint.title = val }
        if let val = dto.description { currentBlueprint.description = val }
        if let val = dto.targetAudience { currentBlueprint.targetAudience = val }
        if let val = dto.coreValueProposition { currentBlueprint.coreValueProposition = val }
        if let val = dto.mvpFeatures { currentBlueprint.mvpFeatures = val }
        if let val = dto.revenueModel { currentBlueprint.revenueModel = val }
        if let val = dto.technicalStack { currentBlueprint.technicalStack = val }
        if let val = dto.roadmap { currentBlueprint.roadmap = val }
        currentBlueprint.confidenceScore = infoCompleteness
    }
    
    private func extractJSON(from text: String) -> String {
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }
}

// MARK: - Goals Service

@MainActor
class GoalsService: ObservableObject {
    static let shared = GoalsService()
    @Published var goals: [Goal] = []
    private let storageKey = "user_goals"
    var activeGoals: [Goal] { goals.filter { $0.status == .active } }
    var pausedGoals: [Goal] { goals.filter { $0.status == .paused } }
    var completedGoals: [Goal] { goals.filter { $0.status == .completed } }
    var mostNeglectedGoal: Goal? { activeGoals.max { $0.daysSinceLastProgress < $1.daysSinceLastProgress } }
    var goalsNeedingAttention: [Goal] { activeGoals.filter { $0.daysSinceLastProgress >= 3 } }
    init() { loadGoals() }
    func addGoal(_ goal: Goal) { goals.append(goal); saveGoals() }
    func updateGoal(_ goal: Goal) { if let idx = goals.firstIndex(where: { $0.id == goal.id }) { goals[idx] = goal; saveGoals() } }
    func deleteGoal(id: UUID) { goals.removeAll { $0.id == id }; saveGoals() }
    func getGoal(byId id: UUID) -> Goal? { goals.first { $0.id == id } }
    func pauseGoal(id: UUID) { if let idx = goals.firstIndex(where: { $0.id == id }) { goals[idx].status = .paused; saveGoals() } }
    func resumeGoal(id: UUID) { if let idx = goals.firstIndex(where: { $0.id == id }) { goals[idx].status = .active; goals[idx].lastProgressUpdate = Date(); saveGoals() } }
    func completeMilestone(goalId: UUID, milestoneIndex: Int) -> (goal: Goal, completedMilestone: Milestone, nextMilestone: Milestone?)? {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return nil }
        let completed = goals[idx].milestones[milestoneIndex]
        goals[idx].completeMilestone(at: milestoneIndex); saveGoals()
        return (goals[idx], completed, goals[idx].currentMilestone)
    }
        func recordProgress(goalId: UUID) { if let idx = goals.firstIndex(where: { $0.id == goalId }) { goals[idx].recordProgress(); saveGoals() } }
        func getNeglectMessage(for goal: Goal) -> String { "Keep working on \(goal.title)." }
        func getMilestoneCompletionMessage(milestone: Milestone, nextMilestone: Milestone?) -> String {
            if let next = nextMilestone { return "Completed \(milestone.title). Next is \(next.title)." }
            return "Goal complete!"
        }
        private func saveGoals() {
     if let data = try? JSONEncoder().encode(goals) { UserDefaults.standard.set(data, forKey: storageKey) } }
    private func loadGoals() { if let data = UserDefaults.standard.data(forKey: storageKey), let saved = try? JSONDecoder().decode([Goal].self, from: data) { goals = saved } }
}

// MARK: - Accountability Tracker

@MainActor
class AccountabilityTracker: ObservableObject {
    static let shared = AccountabilityTracker()
    @Published var currentEscalationLevel: Int = 0
    @Published var todayStats = DailyStats.empty()
    @Published var weeklyStats: [DailyStats] = []
    @Published var shortReturnPattern: Bool = false
    
    struct DailyStats: Codable {
        var date: Date; var timeInApp: TimeInterval; var tasksCompleted: Int; var goalsProgressed: Int; var doomscrollWarnings: Int
        static func empty() -> DailyStats { DailyStats(date: Date(), timeInApp: 0, tasksCompleted: 0, goalsProgressed: 0, doomscrollWarnings: 0) }
    }
    
    init() { }
    func recordAppReturn() { }
    func recordTimeAway(_ duration: TimeInterval) { }
    func getWeeklySummary() -> String { "Weekly summary placeholder." }
    func getDoomscrollMessage() -> String { "Stop scrolling." }
    func getTimeAwayMessage(minutes: Int) -> String { "You've been away." }
}

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}
