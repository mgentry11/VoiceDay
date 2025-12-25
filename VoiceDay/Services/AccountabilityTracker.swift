import Foundation

@MainActor
class AccountabilityTracker: ObservableObject {
    static let shared = AccountabilityTracker()

    // MARK: - Published State

    @Published var returnCount: Int = 0
    @Published var lastReturnTime: Date?
    @Published var shortReturnPattern: Bool = false
    @Published var currentEscalationLevel: Int = 0  // 0-5

    @Published var todayStats: DailyStats
    @Published var weeklyStats: [DailyStats] = []

    // Session tracking
    private var sessionStartTime: Date?
    private var totalTimeAway: TimeInterval = 0

    // MARK: - Constants

    private let shortReturnThresholdMin: TimeInterval = 30    // Seconds before counting as return
    private let shortReturnThresholdMax: TimeInterval = 300   // 5 minutes - after this, reset pattern
    private let doomscrollTriggerCount = 3                    // Returns to trigger doomscroll detection
    private let storageKeyToday = "accountability_today"
    private let storageKeyWeekly = "accountability_weekly"

    // MARK: - Daily Stats

    struct DailyStats: Codable {
        var date: Date
        var timeInApp: TimeInterval
        var timeAway: TimeInterval
        var returnCount: Int
        var tasksCompleted: Int
        var goalsProgressed: Int
        var doomscrollWarnings: Int
        var maxEscalationLevel: Int

        static func empty() -> DailyStats {
            DailyStats(
                date: Date(),
                timeInApp: 0,
                timeAway: 0,
                returnCount: 0,
                tasksCompleted: 0,
                goalsProgressed: 0,
                doomscrollWarnings: 0,
                maxEscalationLevel: 0
            )
        }
    }

    // MARK: - Initialization

    init() {
        todayStats = DailyStats.empty()
        loadData()
        checkForNewDay()
    }

    // MARK: - App Return Detection

    func recordAppReturn() {
        let now = Date()

        if let lastReturn = lastReturnTime {
            let timeSinceLastReturn = now.timeIntervalSince(lastReturn)

            // Short return = came back within 30 seconds to 5 minutes
            // This suggests: opened app -> immediately left -> came back
            if timeSinceLastReturn > shortReturnThresholdMin && timeSinceLastReturn < shortReturnThresholdMax {
                returnCount += 1
                todayStats.returnCount += 1

                // Three or more quick returns = doomscroll pattern
                if returnCount >= doomscrollTriggerCount {
                    shortReturnPattern = true
                    todayStats.doomscrollWarnings += 1
                    escalateNagging()
                    print("⚠️ Doomscroll pattern detected! Return count: \(returnCount)")
                }
            } else if timeSinceLastReturn >= shortReturnThresholdMax {
                // Reset pattern after 5+ minutes
                returnCount = 1
                shortReturnPattern = false
            }
        } else {
            returnCount = 1
        }

        lastReturnTime = now
        saveData()
    }

    func recordTimeAway(_ duration: TimeInterval) {
        totalTimeAway += duration
        todayStats.timeAway += duration

        // Update escalation based on time away
        updateEscalationForTimeAway(duration)
        saveData()
    }

    // MARK: - Activity Recording

    func recordTaskCompletion() {
        todayStats.tasksCompleted += 1
        deescalateNagging()
        saveData()
        print("✅ Task completed - escalation reduced to \(currentEscalationLevel)")
    }

    func recordGoalProgress() {
        todayStats.goalsProgressed += 1
        deescalateNagging()
        deescalateNagging()  // Double de-escalate for goal progress
        saveData()
        print("🎯 Goal progress - escalation reduced to \(currentEscalationLevel)")
    }

    func recordUserInteraction() {
        // Called when user actively interacts with the app
        // This could reset idle detection if implemented
    }

    // MARK: - Escalation Management

    private func escalateNagging() {
        currentEscalationLevel = min(5, currentEscalationLevel + 1)
        todayStats.maxEscalationLevel = max(todayStats.maxEscalationLevel, currentEscalationLevel)
        print("📈 Escalation increased to \(currentEscalationLevel)")
    }

    private func deescalateNagging() {
        currentEscalationLevel = max(0, currentEscalationLevel - 1)
    }

    private func updateEscalationForTimeAway(_ duration: TimeInterval) {
        let hoursAway = duration / 3600

        if hoursAway >= 4 {
            escalateNagging()
            escalateNagging()
        } else if hoursAway >= 2 {
            escalateNagging()
        } else if hoursAway >= 1 {
            // Gentle escalation for 1+ hour
            if currentEscalationLevel < 2 {
                escalateNagging()
            }
        }
    }

    // MARK: - Session Tracking

    func startSession() {
        sessionStartTime = Date()
        print("📱 Session started")
    }

    func endSession() {
        if let start = sessionStartTime {
            let duration = Date().timeIntervalSince(start)
            todayStats.timeInApp += duration
            sessionStartTime = nil
            saveData()
            print("📱 Session ended - \(Int(duration / 60)) minutes in app")
        }
    }

    // MARK: - Escalating Messages

    func getTimeAwayMessage(minutes: Int) -> String {
        let level = currentEscalationLevel
        let timeString = formatTimeAway(minutes: minutes)

        let messagesByLevel: [[String]] = [
            // Level 0 - Gentle
            [
                "Ah, you've returned after \(timeString). Welcome back.",
                "Back after \(timeString). Your tasks await.",
                "\(timeString) away. Not too bad. Let's get productive."
            ],
            // Level 1 - Concerned
            [
                "You were away for \(timeString). One begins to wonder about priorities.",
                "\(timeString) away. The tasks don't complete themselves, I'm afraid.",
                "After \(timeString), you grace us with your presence. Your goals await."
            ],
            // Level 2 - Disappointed
            [
                "\(timeString) of your finite existence, gone. Aristotle weeps.",
                "You've been absent \(timeString). Marcus Aurelius achieved more in his bathroom breaks.",
                "\(timeString). That's what you've spent away from your goals. Heraclitus noted you can't step in the same river twice - nor recover lost time."
            ],
            // Level 3 - Harsh
            [
                "\(timeString) wasted. WASTED. The algorithm's grip on you is concerning.",
                "After \(timeString), you grace us with your presence. Your goals certainly haven't progressed.",
                "\(timeString) of life, scattered to the digital wind. Sisyphus at least made it to the top sometimes."
            ],
            // Level 4 - Very Harsh
            [
                "\(timeString) of life. Gone. Irrecoverable. Your goals? They're gathering dust. Your potential? Gathering cobwebs.",
                "I've waited \(timeString). Your goals have waited longer. Neither of us is pleased.",
                "Let me be direct: \(timeString) away. At this rate, entropy wins. The Second Law is merciless."
            ],
            // Level 5 - Maximum
            [
                "\(timeString) - that's how long since you worked on anything meaningful. Your goals are gathering dust. Your potential is gathering cobwebs. Schrödinger would note that your ambitions are effectively dead.",
                "Allow me to calculate: \(timeString) away. If we add up all such absences, the cumulative waste is... staggering. Leibniz wept.",
                "\(timeString). I've moved past disappointment into a kind of philosophical acceptance. Camus was right - we must imagine Sisyphus happy. I imagine you scrolling."
            ]
        ]

        let messages = messagesByLevel[min(level, messagesByLevel.count - 1)]
        return messages.randomElement() ?? messages[0]
    }

    func getDoomscrollMessage() -> String {
        let messages = [
            "Back again so soon? The infinite scroll beckons, and you answer. Every. Single. Time.",
            "This is return #\(returnCount) in quick succession. The dopamine loop has you firmly in its grasp.",
            "Open app. Close app. Open app. You're not using technology; it's using you.",
            "I've noticed a pattern: brief visits, no progress, endless returns. This is not productivity.",
            "The algorithm knows you'll come back. You always do. Breaking the cycle requires actual work on your goals.",
            "Quick return #\(returnCount). At what point do we call this an addiction? Asking for a friend.",
            "You're oscillating between here and... wherever you go. Heisenberg would note the uncertainty of your commitment.",
            "Another brief appearance. Your goals must feel like a long-distance relationship at this point."
        ]
        return messages.randomElement() ?? messages[0]
    }

    private func formatTimeAway(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") and \(mins) minute\(mins == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        }
    }

    // MARK: - Reporting

    func getDailySummary() -> String {
        let inAppMinutes = Int(todayStats.timeInApp / 60)
        let awayMinutes = Int(todayStats.timeAway / 60)

        var summary = "Today: \(inAppMinutes) min in-app, \(awayMinutes) min away. "
        summary += "\(todayStats.tasksCompleted) tasks completed. "

        if todayStats.goalsProgressed > 0 {
            summary += "\(todayStats.goalsProgressed) goal\(todayStats.goalsProgressed == 1 ? "" : "s") progressed. "
        }

        if todayStats.doomscrollWarnings > 0 {
            summary += "Doomscroll detected \(todayStats.doomscrollWarnings) time\(todayStats.doomscrollWarnings == 1 ? "" : "s")."
        }

        return summary
    }

    func getWeeklySummary() -> String {
        let totalTasks = weeklyStats.reduce(0) { $0 + $1.tasksCompleted } + todayStats.tasksCompleted
        let totalGoals = weeklyStats.reduce(0) { $0 + $1.goalsProgressed } + todayStats.goalsProgressed
        let totalDoomscroll = weeklyStats.reduce(0) { $0 + $1.doomscrollWarnings } + todayStats.doomscrollWarnings

        return "This week: \(totalTasks) tasks completed, \(totalGoals) goal progressions, \(totalDoomscroll) doomscroll warnings."
    }

    // MARK: - Persistence

    private func saveData() {
        do {
            let todayData = try JSONEncoder().encode(todayStats)
            UserDefaults.standard.set(todayData, forKey: storageKeyToday)

            let weeklyData = try JSONEncoder().encode(weeklyStats)
            UserDefaults.standard.set(weeklyData, forKey: storageKeyWeekly)
        } catch {
            print("❌ Failed to save accountability data: \(error)")
        }
    }

    private func loadData() {
        // Load today's stats
        if let data = UserDefaults.standard.data(forKey: storageKeyToday),
           let saved = try? JSONDecoder().decode(DailyStats.self, from: data) {
            todayStats = saved
        }

        // Load weekly stats
        if let data = UserDefaults.standard.data(forKey: storageKeyWeekly),
           let saved = try? JSONDecoder().decode([DailyStats].self, from: data) {
            weeklyStats = saved
        }
    }

    private func checkForNewDay() {
        if !Calendar.current.isDateInToday(todayStats.date) {
            // Archive yesterday's stats
            weeklyStats.append(todayStats)

            // Keep only last 7 days
            if weeklyStats.count > 7 {
                weeklyStats.removeFirst()
            }

            // Reset for new day
            todayStats = DailyStats.empty()
            currentEscalationLevel = max(0, currentEscalationLevel - 1)  // Slight de-escalation overnight
            returnCount = 0
            shortReturnPattern = false

            saveData()
            print("🌅 New day - reset daily stats")
        }
    }

    // MARK: - Reset

    func resetEscalation() {
        currentEscalationLevel = 0
        returnCount = 0
        shortReturnPattern = false
        saveData()
    }

    func resetAllStats() {
        todayStats = DailyStats.empty()
        weeklyStats = []
        currentEscalationLevel = 0
        returnCount = 0
        shortReturnPattern = false
        saveData()
    }
}
