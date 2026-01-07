import Foundation

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
