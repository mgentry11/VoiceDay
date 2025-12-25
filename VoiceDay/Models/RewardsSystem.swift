import Foundation

// MARK: - Reward Types

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

// MARK: - Reward Configuration (Set by Manager)

struct RewardConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: RewardType
    var pointCost: Int           // How many points to redeem
    var dollarValue: Double?     // Monetary value if applicable
    var description: String
    var isActive: Bool
    var quantity: Int?           // Limited quantity? nil = unlimited

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

// MARK: - Point Rules (Set by Manager)

struct PointRules: Codable {
    var pointsPerTask: Int = 10
    var pointsPerHighPriority: Int = 25
    var pointsPerMediumPriority: Int = 15
    var pointsPerLowPriority: Int = 10
    var bonusForEarlyCompletion: Int = 5      // Completed before deadline
    var bonusForStreak: Int = 10              // Completing 3+ tasks in a day
    var penaltyForLate: Int = -5              // Completed after deadline

    func pointsFor(priority: ItemPriority, wasEarly: Bool, wasLate: Bool) -> Int {
        var points: Int
        switch priority {
        case .high: points = pointsPerHighPriority
        case .medium: points = pointsPerMediumPriority
        case .low: points = pointsPerLowPriority
        }

        if wasEarly { points += bonusForEarlyCompletion }
        if wasLate { points += penaltyForLate }

        return max(0, points) // Never negative
    }
}

// MARK: - Team Member

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

// MARK: - Reward Redemption

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

// MARK: - Team/Workspace

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
            // Food rewards
            RewardConfig(name: "DoorDash Lunch", type: .doordash, pointCost: 100, dollarValue: 15, description: "Get lunch delivered on us - $15 DoorDash credit"),
            RewardConfig(name: "DoorDash Dinner", type: .doordash, pointCost: 150, dollarValue: 25, description: "Dinner's on us - $25 DoorDash credit"),
            RewardConfig(name: "Coffee on the Boss", type: .coffee, pointCost: 50, dollarValue: 5, description: "Redeem for a $5 coffee of your choice"),

            // Cash rewards
            RewardConfig(name: "$10 Bonus", type: .money, pointCost: 100, dollarValue: 10, description: "Cash bonus added to next paycheck"),
            RewardConfig(name: "$25 Gift Card", type: .giftCard, pointCost: 200, dollarValue: 25, description: "Amazon, Starbucks, or your choice"),

            // Time rewards
            RewardConfig(name: "30 Min Early Leave", type: .timeOff, pointCost: 75, description: "Leave 30 minutes early on a day of your choice"),
            RewardConfig(name: "Work From Home Day", type: .timeOff, pointCost: 150, description: "One remote work day"),

            // Special
            RewardConfig(name: "Lunch with the CEO", type: .custom, pointCost: 500, description: "Exclusive lunch with company leadership")
        ]
    }

    // Preset reward packages managers can quickly add
    static func familyRewards() -> [RewardConfig] {
        [
            RewardConfig(name: "Ice Cream Trip", type: .custom, pointCost: 30, dollarValue: 10, description: "Trip to the ice cream shop"),
            RewardConfig(name: "Movie Night Pick", type: .custom, pointCost: 50, description: "You choose the movie tonight"),
            RewardConfig(name: "Extra Screen Time", type: .timeOff, pointCost: 25, description: "30 extra minutes of screen time"),
            RewardConfig(name: "DoorDash Treat", type: .doordash, pointCost: 75, dollarValue: 15, description: "Order your favorite snack"),
            RewardConfig(name: "Skip a Chore", type: .custom, pointCost: 40, description: "Skip one assigned chore"),
            RewardConfig(name: "Sleepover Permission", type: .custom, pointCost: 100, description: "Permission for a sleepover")
        ]
    }
}

// MARK: - Rewards Service

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

    // MARK: - Point Earning

    func awardPoints(for taskTitle: String, priority: ItemPriority, deadline: Date?, completedAt: Date = Date()) {
        guard let team = currentTeam else { return }

        let wasEarly = deadline.map { completedAt < $0 } ?? false
        let wasLate = deadline.map { completedAt > $0 } ?? false

        let points = team.pointRules.pointsFor(priority: priority, wasEarly: wasEarly, wasLate: wasLate)

        myPoints += points
        saveData()

        // Generate celebration message with points
        let pointsMessage = points > 0 ? " You've earned \(points) Gadfly points!" : ""
        print("🏆 Awarded \(points) points for completing '\(taskTitle)'\(pointsMessage)")
    }

    // MARK: - Redemption

    func redeemReward(_ reward: RewardConfig) -> Bool {
        guard myPoints >= reward.pointCost else { return false }
        guard reward.isActive else { return false }

        myPoints -= reward.pointCost

        let redemption = RewardRedemption(
            id: UUID(),
            memberId: UUID(), // Would be actual user ID
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

    // MARK: - Manager Functions

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

    // MARK: - Persistence

    private func saveData() {
        // In production, this would sync to a backend
        let data: [String: Any] = [
            "myPoints": myPoints
        ]
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
    /// Get celebration message with points info
    func getCelebrationMessageWithPoints(for taskTitle: String, points: Int) -> String {
        let baseMessage = getCelebrationMessage(for: taskTitle)
        if points > 0 {
            return "\(baseMessage) You've earned \(points) Gadfly points."
        }
        return baseMessage
    }
}
