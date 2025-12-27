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

// MARK: - Streak Data

struct StreakData: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCompletionDate: Date?
    var tasksCompletedToday: Int = 0
    var todayDate: String = ""
    var weeklyCompletions: [String: Int] = [:] // "2025-01-15": 5

    mutating func recordCompletion() {
        let today = Self.dateString(from: Date())

        // Check if streak continues
        if let lastDate = lastCompletionDate {
            let lastDateString = Self.dateString(from: lastDate)
            let yesterday = Self.dateString(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

            if lastDateString == today {
                // Same day - just increment today's count
                tasksCompletedToday += 1
            } else if lastDateString == yesterday {
                // Continuing streak from yesterday
                currentStreak += 1
                tasksCompletedToday = 1
                todayDate = today
            } else {
                // Streak broken - start fresh
                currentStreak = 1
                tasksCompletedToday = 1
                todayDate = today
            }
        } else {
            // First completion ever
            currentStreak = 1
            tasksCompletedToday = 1
            todayDate = today
        }

        lastCompletionDate = Date()
        longestStreak = max(longestStreak, currentStreak)

        // Update weekly completions
        weeklyCompletions[today, default: 0] += 1

        // Clean up old weekly data (keep only last 7 days)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklyCompletions = weeklyCompletions.filter { key, _ in
            if let date = Self.date(from: key) {
                return date >= sevenDaysAgo
            }
            return false
        }
    }

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    var weeklyTotal: Int {
        weeklyCompletions.values.reduce(0, +)
    }
}

// MARK: - Daily Challenge

struct DailyChallenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let targetCount: Int
    let bonusPoints: Int
    var currentProgress: Int
    let dateCreated: String

    var isCompleted: Bool {
        currentProgress >= targetCount
    }

    var progressPercent: Double {
        min(1.0, Double(currentProgress) / Double(targetCount))
    }

    static func generateForToday() -> [DailyChallenge] {
        let today = StreakData.dateString(from: Date())
        return [
            DailyChallenge(
                id: UUID(),
                title: "Early Bird",
                description: "Complete 3 tasks before noon",
                targetCount: 3,
                bonusPoints: 25,
                currentProgress: 0,
                dateCreated: today
            ),
            DailyChallenge(
                id: UUID(),
                title: "Streak Builder",
                description: "Complete 5 tasks today",
                targetCount: 5,
                bonusPoints: 50,
                currentProgress: 0,
                dateCreated: today
            ),
            DailyChallenge(
                id: UUID(),
                title: "Priority Crusher",
                description: "Complete 2 high-priority tasks",
                targetCount: 2,
                bonusPoints: 35,
                currentProgress: 0,
                dateCreated: today
            )
        ]
    }
}

// MARK: - Achievement Badge

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let unlockedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }

    static let allAchievements: [Achievement] = [
        Achievement(id: "first_task", title: "Getting Started", description: "Complete your first task", icon: "star.fill", unlockedAt: nil),
        Achievement(id: "streak_3", title: "On a Roll", description: "3-day completion streak", icon: "flame.fill", unlockedAt: nil),
        Achievement(id: "streak_7", title: "Week Warrior", description: "7-day completion streak", icon: "flame.circle.fill", unlockedAt: nil),
        Achievement(id: "streak_30", title: "Unstoppable", description: "30-day completion streak", icon: "bolt.fill", unlockedAt: nil),
        Achievement(id: "early_bird", title: "Early Bird", description: "Complete 10 tasks before noon", icon: "sunrise.fill", unlockedAt: nil),
        Achievement(id: "points_100", title: "Point Collector", description: "Earn 100 points", icon: "star.circle.fill", unlockedAt: nil),
        Achievement(id: "points_500", title: "Point Master", description: "Earn 500 points", icon: "star.square.fill", unlockedAt: nil),
        Achievement(id: "points_1000", title: "Point Legend", description: "Earn 1000 points", icon: "crown.fill", unlockedAt: nil),
        Achievement(id: "tasks_10", title: "Productive", description: "Complete 10 tasks", icon: "checkmark.circle.fill", unlockedAt: nil),
        Achievement(id: "tasks_50", title: "Task Master", description: "Complete 50 tasks", icon: "checkmark.seal.fill", unlockedAt: nil),
        Achievement(id: "tasks_100", title: "Centurion", description: "Complete 100 tasks", icon: "trophy.fill", unlockedAt: nil),
        Achievement(id: "reward_redeemed", title: "Treat Yourself", description: "Redeem your first reward", icon: "gift.fill", unlockedAt: nil),
    ]
}

// MARK: - Rewards Service

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
    @Published var earlyBirdCount: Int = 0

    private let storageKey = "rewards_data"

    init() {
        loadData()
        refreshDailyChallenges()
    }

    // MARK: - Daily Challenges

    func refreshDailyChallenges() {
        let today = StreakData.dateString(from: Date())

        // Check if challenges are from today
        if let firstChallenge = dailyChallenges.first, firstChallenge.dateCreated == today {
            return // Already have today's challenges
        }

        // Generate new challenges for today
        dailyChallenges = DailyChallenge.generateForToday()
        saveData()
    }

    private func updateChallengeProgress(isHighPriority: Bool, isBeforeNoon: Bool) {
        let today = StreakData.dateString(from: Date())

        for index in dailyChallenges.indices {
            guard dailyChallenges[index].dateCreated == today else { continue }
            guard !dailyChallenges[index].isCompleted else { continue }

            switch dailyChallenges[index].title {
            case "Early Bird":
                if isBeforeNoon {
                    dailyChallenges[index].currentProgress += 1
                }
            case "Streak Builder":
                dailyChallenges[index].currentProgress += 1
            case "Priority Crusher":
                if isHighPriority {
                    dailyChallenges[index].currentProgress += 1
                }
            default:
                break
            }

            // Award bonus if just completed
            if dailyChallenges[index].isCompleted {
                myPoints += dailyChallenges[index].bonusPoints
                print("🎯 Challenge completed: \(dailyChallenges[index].title) - Bonus: \(dailyChallenges[index].bonusPoints) pts")
            }
        }
    }

    // MARK: - Achievements

    private func checkAndUnlockAchievements() {
        var updated = false

        for index in achievements.indices {
            guard achievements[index].unlockedAt == nil else { continue }

            var shouldUnlock = false

            switch achievements[index].id {
            case "first_task":
                shouldUnlock = totalTasksCompleted >= 1
            case "streak_3":
                shouldUnlock = streakData.currentStreak >= 3
            case "streak_7":
                shouldUnlock = streakData.currentStreak >= 7
            case "streak_30":
                shouldUnlock = streakData.currentStreak >= 30
            case "early_bird":
                shouldUnlock = earlyBirdCount >= 10
            case "points_100":
                shouldUnlock = totalPointsEarned >= 100
            case "points_500":
                shouldUnlock = totalPointsEarned >= 500
            case "points_1000":
                shouldUnlock = totalPointsEarned >= 1000
            case "tasks_10":
                shouldUnlock = totalTasksCompleted >= 10
            case "tasks_50":
                shouldUnlock = totalTasksCompleted >= 50
            case "tasks_100":
                shouldUnlock = totalTasksCompleted >= 100
            case "reward_redeemed":
                shouldUnlock = !pendingRedemptions.isEmpty
            default:
                break
            }

            if shouldUnlock {
                achievements[index] = Achievement(
                    id: achievements[index].id,
                    title: achievements[index].title,
                    description: achievements[index].description,
                    icon: achievements[index].icon,
                    unlockedAt: Date()
                )
                updated = true
                print("🏆 Achievement unlocked: \(achievements[index].title)")
            }
        }

        if updated {
            saveData()
        }
    }

    var unlockedAchievementsCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }

    // MARK: - Point Earning

    func awardPoints(for taskTitle: String, priority: ItemPriority, deadline: Date?, completedAt: Date = Date()) {
        // Use team rules if available, otherwise use defaults
        let rules = currentTeam?.pointRules ?? PointRules()

        let wasEarly = deadline.map { completedAt < $0 } ?? false
        let wasLate = deadline.map { completedAt > $0 } ?? false

        let points = rules.pointsFor(priority: priority, wasEarly: wasEarly, wasLate: wasLate)

        myPoints += points
        totalPointsEarned += points
        totalTasksCompleted += 1

        // Update streak
        streakData.recordCompletion()

        // Check if before noon for early bird tracking
        let hour = Calendar.current.component(.hour, from: completedAt)
        let isBeforeNoon = hour < 12
        if isBeforeNoon {
            earlyBirdCount += 1
        }

        // Update daily challenges
        updateChallengeProgress(isHighPriority: priority == .high, isBeforeNoon: isBeforeNoon)

        // Check for new achievements
        checkAndUnlockAchievements()

        saveData()

        // Generate celebration message with points
        let pointsMessage = points > 0 ? " You've earned \(points) Gadfly points!" : ""
        print("🏆 Awarded \(points) points for completing '\(taskTitle)'\(pointsMessage)")
        print("🔥 Current streak: \(streakData.currentStreak) days")
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
        // Save all rewards data
        UserDefaults.standard.set(myPoints, forKey: "my_points")
        UserDefaults.standard.set(totalPointsEarned, forKey: "total_points_earned")
        UserDefaults.standard.set(totalTasksCompleted, forKey: "total_tasks_completed")
        UserDefaults.standard.set(earlyBirdCount, forKey: "early_bird_count")

        if let encoded = try? JSONEncoder().encode(currentTeam) {
            UserDefaults.standard.set(encoded, forKey: "current_team")
        }

        if let streakEncoded = try? JSONEncoder().encode(streakData) {
            UserDefaults.standard.set(streakEncoded, forKey: "streak_data")
        }

        if let challengesEncoded = try? JSONEncoder().encode(dailyChallenges) {
            UserDefaults.standard.set(challengesEncoded, forKey: "daily_challenges")
        }

        if let achievementsEncoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(achievementsEncoded, forKey: "achievements")
        }

        if let redemptionsEncoded = try? JSONEncoder().encode(pendingRedemptions) {
            UserDefaults.standard.set(redemptionsEncoded, forKey: "pending_redemptions")
        }
    }

    private func loadData() {
        myPoints = UserDefaults.standard.integer(forKey: "my_points")
        totalPointsEarned = UserDefaults.standard.integer(forKey: "total_points_earned")
        totalTasksCompleted = UserDefaults.standard.integer(forKey: "total_tasks_completed")
        earlyBirdCount = UserDefaults.standard.integer(forKey: "early_bird_count")

        if let data = UserDefaults.standard.data(forKey: "current_team"),
           let team = try? JSONDecoder().decode(Team.self, from: data) {
            currentTeam = team
        }

        if let streakData = UserDefaults.standard.data(forKey: "streak_data"),
           let decoded = try? JSONDecoder().decode(StreakData.self, from: streakData) {
            self.streakData = decoded
        }

        if let challengesData = UserDefaults.standard.data(forKey: "daily_challenges"),
           let decoded = try? JSONDecoder().decode([DailyChallenge].self, from: challengesData) {
            self.dailyChallenges = decoded
        }

        if let achievementsData = UserDefaults.standard.data(forKey: "achievements"),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: achievementsData) {
            self.achievements = decoded
        }

        if let redemptionsData = UserDefaults.standard.data(forKey: "pending_redemptions"),
           let decoded = try? JSONDecoder().decode([RewardRedemption].self, from: redemptionsData) {
            self.pendingRedemptions = decoded
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
