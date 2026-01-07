import Foundation
import SwiftUI

// MARK: - Task Attack Advisor

/// Helps ADHD users figure out HOW to start tasks
/// Reduces "I don't know where to begin" paralysis
@MainActor
class TaskAttackAdvisor: ObservableObject {
    static let shared = TaskAttackAdvisor()

    // MARK: - Dependencies

    private let energyService = EnergyService.shared
    private let durationEstimator = DurationEstimator.shared

    // MARK: - Attack Strategies

    enum AttackStrategy: String, CaseIterable {
        case tinyFirstStep = "tiny_first_step"
        case fifteenMinuteSprint = "fifteen_minute_sprint"
        case eatTheFrog = "eat_the_frog"
        case quickWinsFirst = "quick_wins_first"
        case breakItDown = "break_it_down"
        case bodyDoubleIt = "body_double_it"
        case timeBoxIt = "time_box_it"
        case justStart = "just_start"

        var displayName: String {
            switch self {
            case .tinyFirstStep: return "Tiny First Step"
            case .fifteenMinuteSprint: return "15-Minute Sprint"
            case .eatTheFrog: return "Eat the Frog"
            case .quickWinsFirst: return "Quick Wins First"
            case .breakItDown: return "Break It Down"
            case .bodyDoubleIt: return "Body Double It"
            case .timeBoxIt: return "Time Box It"
            case .justStart: return "Just Start"
            }
        }

        var icon: String {
            switch self {
            case .tinyFirstStep: return "shoeprints.fill"
            case .fifteenMinuteSprint: return "timer"
            case .eatTheFrog: return "bolt.fill"
            case .quickWinsFirst: return "checkmark.circle.fill"
            case .breakItDown: return "square.grid.2x2"
            case .bodyDoubleIt: return "person.2.fill"
            case .timeBoxIt: return "clock.fill"
            case .justStart: return "play.fill"
            }
        }

        var color: Color {
            switch self {
            case .tinyFirstStep: return .green
            case .fifteenMinuteSprint: return .orange
            case .eatTheFrog: return .red
            case .quickWinsFirst: return .blue
            case .breakItDown: return .purple
            case .bodyDoubleIt: return .pink
            case .timeBoxIt: return .indigo
            case .justStart: return .mint
            }
        }

        var description: String {
            switch self {
            case .tinyFirstStep:
                return "Start with the smallest possible action. Just one tiny step."
            case .fifteenMinuteSprint:
                return "Commit to just 15 minutes. Anyone can do 15 minutes."
            case .eatTheFrog:
                return "Tackle the hardest part first while your energy is high."
            case .quickWinsFirst:
                return "Build momentum with a few easy wins before the big stuff."
            case .breakItDown:
                return "This is too big. Let's split it into smaller pieces."
            case .bodyDoubleIt:
                return "Start a focus session. Working alongside others helps."
            case .timeBoxIt:
                return "Set a specific time limit. Done is better than perfect."
            case .justStart:
                return "Don't overthink it. Open it up and begin."
            }
        }
    }

    // MARK: - Task Analysis

    struct TaskAnalysis {
        let task: GadflyTask
        let recommendedStrategy: AttackStrategy
        let alternativeStrategies: [AttackStrategy]
        let tinyFirstStep: String
        let estimatedDuration: DurationEstimate
        let energyMatch: EnergyMatch
        let timing: TimingRecommendation
        let canBreakDown: Bool
        let breakdownSuggestions: [String]
    }

    enum EnergyMatch {
        case perfect   // Task difficulty matches energy
        case good      // Close enough
        case mismatch  // Task too hard/easy for current energy

        var message: String {
            switch self {
            case .perfect: return "Perfect energy match"
            case .good: return "Good energy match"
            case .mismatch: return "Consider saving for different energy"
            }
        }

        var icon: String {
            switch self {
            case .perfect: return "checkmark.circle.fill"
            case .good: return "circle.fill"
            case .mismatch: return "exclamationmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .perfect: return .green
            case .good: return .yellow
            case .mismatch: return .orange
            }
        }
    }

    struct TimingRecommendation {
        let isGoodTime: Bool
        let reason: String
        let suggestedTime: String?
    }

    // MARK: - Analyze Task

    func analyzeTask(_ task: GadflyTask) -> TaskAnalysis {
        let duration = durationEstimator.estimateDuration(for: task.title)
        let energyMatch = evaluateEnergyMatch(task: task, duration: duration)
        let timing = evaluateTiming(task: task)
        let canBreakDown = shouldSuggestBreakdown(task: task, duration: duration)
        let breakdownSuggestions = generateBreakdownSuggestions(for: task)

        let (primary, alternatives) = recommendStrategies(
            task: task,
            duration: duration,
            energyMatch: energyMatch,
            canBreakDown: canBreakDown
        )

        let tinyStep = generateTinyFirstStep(for: task)

        return TaskAnalysis(
            task: task,
            recommendedStrategy: primary,
            alternativeStrategies: alternatives,
            tinyFirstStep: tinyStep,
            estimatedDuration: duration,
            energyMatch: energyMatch,
            timing: timing,
            canBreakDown: canBreakDown,
            breakdownSuggestions: breakdownSuggestions
        )
    }

    // MARK: - Strategy Recommendation

    private func recommendStrategies(
        task: GadflyTask,
        duration: DurationEstimate,
        energyMatch: EnergyMatch,
        canBreakDown: Bool
    ) -> (primary: AttackStrategy, alternatives: [AttackStrategy]) {

        var strategies: [(AttackStrategy, Int)] = [] // Strategy and priority score

        let energy = energyService.currentEnergy
        let isLongTask = duration.minutes >= 45
        let isShortTask = duration.minutes <= 15
        let isOverdue = task.dueDate.map { $0 < Date() } ?? false

        // Score each strategy based on context

        // Tiny First Step - good for overwhelm or low energy
        if energy == .low || isLongTask {
            strategies.append((.tinyFirstStep, 80))
        } else {
            strategies.append((.tinyFirstStep, 40))
        }

        // 15-Minute Sprint - universal fallback
        strategies.append((.fifteenMinuteSprint, 60))

        // Eat the Frog - high energy + hard/important task
        if energy == .high && (task.priority == .high || isLongTask) {
            strategies.append((.eatTheFrog, 90))
        } else if energy == .high {
            strategies.append((.eatTheFrog, 50))
        }

        // Quick Wins First - low energy or anxious
        if energy == .low || (energy == .medium && isLongTask) {
            strategies.append((.quickWinsFirst, 75))
        } else {
            strategies.append((.quickWinsFirst, 30))
        }

        // Break It Down - long or complex tasks
        if canBreakDown {
            strategies.append((.breakItDown, 85))
        }

        // Body Double It - always an option
        strategies.append((.bodyDoubleIt, 45))

        // Time Box It - good for perfectionism or open-ended tasks
        if isLongTask || task.title.lowercased().contains("finish") || task.title.lowercased().contains("complete") {
            strategies.append((.timeBoxIt, 70))
        } else {
            strategies.append((.timeBoxIt, 35))
        }

        // Just Start - short tasks or overdue
        if isShortTask || isOverdue {
            strategies.append((.justStart, 85))
        } else {
            strategies.append((.justStart, 50))
        }

        // Sort by score
        let sorted = strategies.sorted { $0.1 > $1.1 }
        let primary = sorted.first?.0 ?? .fifteenMinuteSprint
        let alternatives = Array(sorted.dropFirst().prefix(3).map { $0.0 })

        return (primary, alternatives)
    }

    // MARK: - Energy Matching

    private func evaluateEnergyMatch(task: GadflyTask, duration: DurationEstimate) -> EnergyMatch {
        let energy = energyService.currentEnergy
        let isHardTask = duration.minutes >= 45 || task.priority == .high
        let isEasyTask = duration.minutes <= 15 || task.priority == .low

        switch energy {
        case .high:
            if isHardTask { return .perfect }
            if isEasyTask { return .mismatch } // Wasting high energy
            return .good

        case .medium:
            if isHardTask { return .mismatch }
            return .good

        case .low:
            if isEasyTask { return .perfect }
            if isHardTask { return .mismatch }
            return .good
        }
    }

    // MARK: - Timing Evaluation

    private func evaluateTiming(task: GadflyTask) -> TimingRecommendation {
        let energy = energyService.currentEnergy
        let hour = Calendar.current.component(.hour, from: Date())

        // Check if overdue
        if let dueDate = task.dueDate, dueDate < Date() {
            return TimingRecommendation(
                isGoodTime: true,
                reason: "This is overdue - now is the time!",
                suggestedTime: nil
            )
        }

        // Check energy
        if energy == .high {
            return TimingRecommendation(
                isGoodTime: true,
                reason: "Your energy is high - great time to tackle this",
                suggestedTime: nil
            )
        }

        // Morning person logic
        if hour >= 9 && hour <= 11 {
            return TimingRecommendation(
                isGoodTime: true,
                reason: "Morning focus time - good window",
                suggestedTime: nil
            )
        }

        // Post-lunch slump
        if hour >= 13 && hour <= 15 && energy == .low {
            return TimingRecommendation(
                isGoodTime: false,
                reason: "Post-lunch energy dip detected",
                suggestedTime: "Try after 3pm or tomorrow morning"
            )
        }

        // Late night
        if hour >= 21 {
            return TimingRecommendation(
                isGoodTime: false,
                reason: "Getting late - save for tomorrow?",
                suggestedTime: "Tomorrow morning when fresh"
            )
        }

        return TimingRecommendation(
            isGoodTime: true,
            reason: "Now works",
            suggestedTime: nil
        )
    }

    // MARK: - Breakdown Logic

    private func shouldSuggestBreakdown(task: GadflyTask, duration: DurationEstimate) -> Bool {
        // Suggest breakdown for tasks over 30 minutes
        if duration.minutes >= 30 { return true }

        // Or tasks with certain keywords
        let breakdownKeywords = ["project", "report", "complete", "finish", "prepare", "organize", "clean", "plan"]
        let titleLower = task.title.lowercased()

        return breakdownKeywords.contains { titleLower.contains($0) }
    }

    private func generateBreakdownSuggestions(for task: GadflyTask) -> [String] {
        let titleLower = task.title.lowercased()

        // Common breakdown patterns
        if titleLower.contains("report") || titleLower.contains("document") {
            return [
                "Gather all needed information",
                "Create outline/structure",
                "Write first draft",
                "Review and edit",
                "Final formatting"
            ]
        }

        if titleLower.contains("email") && (titleLower.contains("all") || titleLower.contains("respond")) {
            return [
                "Open inbox and scan",
                "Reply to urgent ones first",
                "Handle quick replies",
                "Draft longer responses",
                "File/archive completed"
            ]
        }

        if titleLower.contains("clean") || titleLower.contains("organize") {
            return [
                "Clear one surface first",
                "Sort items into piles",
                "Put away/trash obvious items",
                "Organize remaining items",
                "Quick final sweep"
            ]
        }

        if titleLower.contains("project") || titleLower.contains("plan") {
            return [
                "Define the goal clearly",
                "List all steps needed",
                "Identify first action",
                "Set rough timeline",
                "Start first step"
            ]
        }

        if titleLower.contains("meeting") || titleLower.contains("prepare") {
            return [
                "Review agenda/purpose",
                "Gather needed materials",
                "Prepare talking points",
                "Set up tech if needed",
                "Do a quick mental run-through"
            ]
        }

        // Generic breakdown
        return [
            "Define what 'done' looks like",
            "Identify the very first step",
            "Do that first step only",
            "Then do the next step",
            "Review and wrap up"
        ]
    }

    // MARK: - Tiny First Step Generator

    private func generateTinyFirstStep(for task: GadflyTask) -> String {
        let titleLower = task.title.lowercased()

        // Specific patterns
        if titleLower.contains("email") {
            return "Open your email app"
        }
        if titleLower.contains("call") || titleLower.contains("phone") {
            return "Pull up the contact"
        }
        if titleLower.contains("write") || titleLower.contains("report") || titleLower.contains("document") {
            return "Open a blank document"
        }
        if titleLower.contains("clean") {
            return "Pick up one item"
        }
        if titleLower.contains("exercise") || titleLower.contains("workout") || titleLower.contains("gym") {
            return "Put on your workout clothes"
        }
        if titleLower.contains("study") || titleLower.contains("read") {
            return "Open the book/material"
        }
        if titleLower.contains("cook") || titleLower.contains("dinner") || titleLower.contains("lunch") {
            return "Take out one ingredient"
        }
        if titleLower.contains("laundry") {
            return "Grab the laundry basket"
        }
        if titleLower.contains("meeting") || titleLower.contains("prepare") {
            return "Open the calendar invite"
        }
        if titleLower.contains("pay") || titleLower.contains("bill") {
            return "Open the billing app or website"
        }
        if titleLower.contains("schedule") || titleLower.contains("appointment") {
            return "Open your calendar"
        }

        // Generic tiny steps
        let genericSteps = [
            "Set a 2-minute timer and just look at it",
            "Open the app or tool you need",
            "Write down one thing about this task",
            "Take one small action - any action",
            "Just get the materials ready"
        ]

        return genericSteps.randomElement() ?? "Take one tiny step toward this"
    }

    // MARK: - Quick Priority Recommendation

    /// Get a simple recommendation for which task to do next
    func recommendNextTask(from tasks: [GadflyTask]) -> (task: GadflyTask, reason: String)? {
        let activeTasks = tasks.filter { !$0.isCompleted }
        guard !activeTasks.isEmpty else { return nil }

        let energy = energyService.currentEnergy

        // Score each task
        var scoredTasks: [(GadflyTask, Int, String)] = []

        for task in activeTasks {
            var score = 0
            var reason = ""

            let duration = durationEstimator.estimateDuration(for: task.title)
            let isOverdue = task.dueDate.map { $0 < Date() } ?? false
            let isDueToday = task.dueDate.map { Calendar.current.isDateInToday($0) } ?? false

            // Overdue gets highest priority
            if isOverdue {
                score += 100
                reason = "Overdue - let's get this done"
            }

            // Due today is important
            if isDueToday {
                score += 50
                reason = reason.isEmpty ? "Due today" : reason
            }

            // Priority weighting
            switch task.priority {
            case .high:
                score += 30
                if reason.isEmpty { reason = "High priority" }
            case .medium:
                score += 15
            case .low:
                score += 5
            }

            // Energy matching
            let isQuickTask = duration.minutes <= 15
            let isHardTask = duration.minutes >= 45 || task.priority == .high

            switch energy {
            case .high:
                if isHardTask {
                    score += 25
                    if reason.isEmpty { reason = "Good match for your high energy" }
                }
            case .medium:
                if !isHardTask && !isQuickTask {
                    score += 20
                }
            case .low:
                if isQuickTask {
                    score += 25
                    if reason.isEmpty { reason = "Quick win for low energy" }
                }
            }

            // Quick wins when low energy
            if energy == .low && isQuickTask {
                score += 15
            }

            if reason.isEmpty {
                reason = "Next up on your list"
            }

            scoredTasks.append((task, score, reason))
        }

        // Sort by score
        let sorted = scoredTasks.sorted { $0.1 > $1.1 }

        if let top = sorted.first {
            return (top.0, top.2)
        }

        return nil
    }
}

// MARK: - Attack History (for learning)

extension TaskAttackAdvisor {

    struct AttackAttempt: Codable {
        let taskTitle: String
        let strategy: String
        let startedAt: Date
        let completedAt: Date?
        let wasSuccessful: Bool
    }

    private var attemptsKey: String { "task_attack_attempts" }

    func recordAttempt(task: GadflyTask, strategy: AttackStrategy, completed: Bool) {
        var attempts = loadAttempts()

        let attempt = AttackAttempt(
            taskTitle: task.title,
            strategy: strategy.rawValue,
            startedAt: Date(),
            completedAt: completed ? Date() : nil,
            wasSuccessful: completed
        )

        attempts.append(attempt)

        // Keep last 50 attempts
        if attempts.count > 50 {
            attempts = Array(attempts.suffix(50))
        }

        saveAttempts(attempts)
    }

    private func loadAttempts() -> [AttackAttempt] {
        guard let data = UserDefaults.standard.data(forKey: attemptsKey),
              let attempts = try? JSONDecoder().decode([AttackAttempt].self, from: data) else {
            return []
        }
        return attempts
    }

    private func saveAttempts(_ attempts: [AttackAttempt]) {
        if let encoded = try? JSONEncoder().encode(attempts) {
            UserDefaults.standard.set(encoded, forKey: attemptsKey)
        }
    }
}
