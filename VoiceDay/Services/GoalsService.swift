import Foundation

@MainActor
class GoalsService: ObservableObject {
    static let shared = GoalsService()

    @Published var goals: [Goal] = []

    private let storageKey = "user_goals"
    private let workSessionDurationMinutes = 45  // Remind to take break after this

    // MARK: - Computed Properties

    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }

    var pausedGoals: [Goal] {
        goals.filter { $0.status == .paused }
    }

    var completedGoals: [Goal] {
        goals.filter { $0.status == .completed }
    }

    var mostNeglectedGoal: Goal? {
        activeGoals.max { $0.daysSinceLastProgress < $1.daysSinceLastProgress }
    }

    var goalsNeedingAttention: [Goal] {
        activeGoals.filter { $0.daysSinceLastProgress >= 3 }
    }

    // MARK: - Initialization

    init() {
        loadGoals()
    }

    // MARK: - CRUD Operations

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        saveGoals()
        print("📎 Added goal: \(goal.title) with \(goal.milestones.count) milestones")
    }

    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        saveGoals()
    }

    func getGoal(byId id: UUID) -> Goal? {
        goals.first { $0.id == id }
    }

    func getGoal(byTitle title: String) -> Goal? {
        // Fuzzy match - case insensitive contains
        let lowercased = title.lowercased()
        return goals.first { $0.title.lowercased().contains(lowercased) }
    }

    // MARK: - Goal Status Management

    func pauseGoal(id: UUID) {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals[index].status = .paused
            saveGoals()
        }
    }

    func resumeGoal(id: UUID) {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals[index].status = .active
            goals[index].lastProgressUpdate = Date()
            saveGoals()
        }
    }

    func completeGoal(id: UUID) {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals[index].status = .completed
            saveGoals()
        }
    }

    func abandonGoal(id: UUID) {
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals[index].status = .abandoned
            saveGoals()
        }
    }

    // MARK: - Milestone Management

    func completeMilestone(goalId: UUID, milestoneIndex: Int) -> (goal: Goal, completedMilestone: Milestone, nextMilestone: Milestone?)? {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return nil }
        guard milestoneIndex >= 0 && milestoneIndex < goals[index].milestones.count else { return nil }

        let completedMilestone = goals[index].milestones[milestoneIndex]
        goals[index].completeMilestone(at: milestoneIndex)
        saveGoals()

        let updatedGoal = goals[index]
        let nextMilestone = updatedGoal.currentMilestone
        return (updatedGoal, completedMilestone, nextMilestone)
    }

    func completeCurrentMilestone(goalId: UUID) -> (goal: Goal, completedMilestone: Milestone, nextMilestone: Milestone?)? {
        guard let goal = getGoal(byId: goalId) else { return nil }
        return completeMilestone(goalId: goalId, milestoneIndex: goal.currentMilestoneIndex)
    }

    // MARK: - Task Linking

    func linkTask(taskId: String, to goalId: UUID) {
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].linkTask(taskId: taskId)
            saveGoals()
            print("🔗 Linked task \(taskId) to goal: \(goals[index].title)")
        }
    }

    func unlinkTask(taskId: String, from goalId: UUID) {
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].unlinkTask(taskId: taskId)
            saveGoals()
        }
    }

    func recordTaskCompletion(taskId: String) {
        for (index, goal) in goals.enumerated() {
            if goal.linkedTaskIds.contains(taskId) {
                goals[index].recordTaskCompletion()

                // Check if goal should be marked complete
                if goals[index].completedTaskCount >= goals[index].linkedTaskIds.count &&
                   goals[index].milestones.allSatisfy({ $0.isCompleted }) {
                    goals[index].status = .completed
                }

                print("✅ Recorded task completion for goal: \(goals[index].title)")
            }
        }
        saveGoals()
    }

    // MARK: - Progress Tracking

    func recordProgress(goalId: UUID, note: String? = nil) {
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].recordProgress()
            saveGoals()
            print("📈 Recorded progress on goal: \(goals[index].title)")
        }
    }

    func recordWorkSession(goalId: UUID) {
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].recordWorkSession()
            saveGoals()
            print("💪 Recorded work session for goal: \(goals[index].title)")
        }
    }

    // MARK: - Work Session Management

    func shouldRemindToBreak(goalId: UUID) -> Bool {
        guard let goal = getGoal(byId: goalId),
              let lastWork = goal.lastWorkSession else {
            return false
        }

        let minutesSinceLastWork = Int(Date().timeIntervalSince(lastWork) / 60)
        return minutesSinceLastWork >= workSessionDurationMinutes
    }

    func getWorkSessionDuration(goalId: UUID) -> Int? {
        guard let goal = getGoal(byId: goalId),
              let lastWork = goal.lastWorkSession else {
            return nil
        }
        return Int(Date().timeIntervalSince(lastWork) / 60)
    }

    // MARK: - Today's Focus

    func getCurrentMilestoneTask(for goalId: UUID) -> (milestone: Milestone, task: String?)? {
        guard let goal = getGoal(byId: goalId),
              let milestone = goal.currentMilestone else {
            return nil
        }

        let task = milestone.suggestedTasks.first
        return (milestone, task)
    }

    func getTodaysFocus() -> (goal: Goal, milestone: Milestone, task: String?)? {
        // Find most active goal that needs work today
        guard let goal = activeGoals.first(where: { goal in
            // Check if today is a preferred day
            if let preferredDays = goal.preferredDays {
                let weekday = Calendar.current.component(.weekday, from: Date()) - 1 // 0=Sun
                return preferredDays.contains(weekday)
            }
            return true  // No preference = every day
        }),
        let milestone = goal.currentMilestone else {
            return nil
        }

        let task = milestone.suggestedTasks.first { task in
            // Could check against completed tasks if we track them
            true
        }

        return (goal, milestone, task)
    }

    // MARK: - Gadfly Messages

    func getNeglectMessage(for goal: Goal) -> String {
        let days = goal.daysSinceLastProgress
        let title = goal.title

        switch goal.neglectLevel {
        case 0:
            return "You're actively working on '\(title)'. Keep it up."
        case 1:
            return "'\(title)' - it's been \(days) days. A gentle nudge to keep momentum."
        case 2:
            return "'\(title)' hasn't seen action in \(days) days. Aristotle said excellence is a habit. Yours is... taking a holiday."
        case 3:
            return "I'm disappointed, but not surprised. '\(title)' has been neglected for \(days) days. Seneca warned about wasting time."
        case 4:
            return "'\(title)' - \(days) days of neglect. At this rate, entropy wins. The Second Law is merciless."
        default:
            return "'\(title)' has been abandoned for \(days) days. Let me be direct: either commit or delete this goal. This limbo serves no one."
        }
    }

    func getMilestoneCompletionMessage(milestone: Milestone, nextMilestone: Milestone?) -> String {
        if let next = nextMilestone {
            return "Excellent! You've completed '\(milestone.title)'. Moving to '\(next.title)'. Here's what to focus on: \(next.suggestedTasks.first ?? "Review the material")."
        } else {
            return "Outstanding! You've completed the final milestone: '\(milestone.title)'. This goal is complete. Aristotle would approve."
        }
    }

    func getBreakReminder(minutesWorked: Int) -> String {
        let messages = [
            "You've been at this for \(minutesWorked) minutes. Aristotle would remind you that excellence requires rest. Take 10 minutes.",
            "\(minutesWorked) minutes of focused work. Even Euler took breaks. Stand up, stretch, hydrate.",
            "The Pomodoro Technique exists for a reason. \(minutesWorked) minutes is enough. Your brain needs a break.",
            "\(minutesWorked) minutes. Impressive dedication. Now move around - your body and mind will thank you."
        ]
        return messages.randomElement() ?? messages[0]
    }

    func getWelcomeBackMessage(goal: Goal) -> String? {
        guard let milestone = goal.currentMilestone else { return nil }

        var message = "Welcome back. You're on '\(goal.title)', Milestone \(goal.currentMilestoneIndex + 1): \(milestone.title)."

        if let task = milestone.suggestedTasks.first {
            message += " Today's focus: \(task)."
        }

        if let minutes = goal.dailyTimeMinutes {
            message += " Aim for \(minutes) minutes."
        }

        return message
    }

    // MARK: - Persistence

    private func saveGoals() {
        do {
            let data = try JSONEncoder().encode(goals)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save goals: \(error)")
        }
    }

    private func loadGoals() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            goals = try JSONDecoder().decode([Goal].self, from: data)
            print("📂 Loaded \(goals.count) goals")
        } catch {
            print("❌ Failed to load goals: \(error)")
        }
    }

    // MARK: - Goal Creation from DTO

    func createGoal(from dto: GoalDTO) -> Goal {
        let milestones: [Milestone] = dto.milestones?.map { milestoneDTO in
            Milestone(
                title: milestoneDTO.title,
                description: milestoneDTO.description,
                estimatedDays: milestoneDTO.estimatedDays,
                suggestedTasks: milestoneDTO.tasks ?? []
            )
        } ?? []

        // Parse target date
        var targetDate: Date? = nil
        if let dateString = dto.targetDate {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: dateString)
        }

        return Goal(
            title: dto.title,
            description: dto.description,
            targetDate: targetDate,
            milestones: milestones,
            dailyTimeMinutes: dto.dailyTimeMinutes,
            preferredDays: dto.preferredDays
        )
    }
}
