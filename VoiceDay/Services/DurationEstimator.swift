import Foundation

// MARK: - Duration Estimator

/// AI-powered task duration estimation
/// Helps ADHD users who chronically underestimate how long things take
@MainActor
class DurationEstimator: ObservableObject {
    static let shared = DurationEstimator()

    // MARK: - Published State

    @Published private(set) var isLearning = false

    // MARK: - Task History

    private struct TaskHistory: Codable {
        let title: String
        let keywords: [String]
        let estimatedMinutes: Int
        let actualMinutes: Int
        let completedAt: Date
    }

    private var taskHistories: [TaskHistory] = []
    private let historyKey = "task_duration_history"

    // MARK: - Keyword Categories

    private let quickKeywords = ["quick", "fast", "simple", "brief", "check", "reply", "send", "review"]
    private let mediumKeywords = ["email", "call", "meeting", "update", "write", "prepare", "organize"]
    private let longKeywords = ["deep", "research", "analysis", "report", "project", "build", "create", "design"]
    private let veryLongKeywords = ["comprehensive", "complete", "full", "entire", "major", "overhaul"]

    // MARK: - Initialization

    init() {
        loadHistory()
    }

    // MARK: - Estimation

    /// Estimate duration for a new task
    func estimateDuration(for taskTitle: String) -> DurationEstimate {
        let keywords = extractKeywords(from: taskTitle)

        // Check historical data first
        if let historicalEstimate = estimateFromHistory(keywords: keywords, title: taskTitle) {
            return historicalEstimate
        }

        // Fall back to keyword-based estimation
        return estimateFromKeywords(keywords: keywords, title: taskTitle)
    }

    /// Suggest duration when user enters a custom estimate
    func validateUserEstimate(userMinutes: Int, taskTitle: String) -> DurationValidation {
        let aiEstimate = estimateDuration(for: taskTitle)

        // Compare user estimate to AI estimate
        let ratio = Double(userMinutes) / Double(aiEstimate.minutes)

        if ratio < 0.5 {
            // User significantly underestimating
            return DurationValidation(
                isRealistic: false,
                message: "This usually takes longer. Last time similar tasks took ~\(aiEstimate.minutes) min.",
                suggestedMinutes: aiEstimate.minutes,
                confidence: aiEstimate.confidence
            )
        } else if ratio > 2.0 {
            // User overestimating (rare for ADHD, but possible)
            return DurationValidation(
                isRealistic: true,
                message: "That's generous! You might finish faster.",
                suggestedMinutes: nil,
                confidence: aiEstimate.confidence
            )
        } else {
            return DurationValidation(
                isRealistic: true,
                message: nil,
                suggestedMinutes: nil,
                confidence: aiEstimate.confidence
            )
        }
    }

    // MARK: - Learning

    /// Record actual task completion time for learning
    func recordCompletion(
        taskTitle: String,
        estimatedMinutes: Int,
        startTime: Date,
        endTime: Date
    ) {
        let actualMinutes = Int(endTime.timeIntervalSince(startTime) / 60)

        // Only record if reasonable (between 1 min and 8 hours)
        guard actualMinutes >= 1 && actualMinutes <= 480 else { return }

        let history = TaskHistory(
            title: taskTitle,
            keywords: extractKeywords(from: taskTitle),
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes,
            completedAt: endTime
        )

        taskHistories.append(history)

        // Keep last 100 tasks
        if taskHistories.count > 100 {
            taskHistories = Array(taskHistories.suffix(100))
        }

        saveHistory()

        // Log for debugging
        let accuracy = estimatedMinutes > 0 ? Double(actualMinutes) / Double(estimatedMinutes) : 0
        print("📊 Duration recorded: '\(taskTitle)' estimated \(estimatedMinutes)m, actual \(actualMinutes)m (accuracy: \(Int(accuracy * 100))%)")
    }

    /// Get user's estimation accuracy trend
    var estimationAccuracy: Double {
        let recent = taskHistories.suffix(20)
        guard !recent.isEmpty else { return 1.0 }

        let ratios = recent.compactMap { history -> Double? in
            guard history.estimatedMinutes > 0 else { return nil }
            return Double(history.actualMinutes) / Double(history.estimatedMinutes)
        }

        guard !ratios.isEmpty else { return 1.0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    /// Get common underestimation patterns
    var underestimationPatterns: [String] {
        let underestimated = taskHistories.filter {
            Double($0.actualMinutes) > Double($0.estimatedMinutes) * 1.5
        }

        // Find common keywords in underestimated tasks
        var keywordCounts: [String: Int] = [:]
        for history in underestimated {
            for keyword in history.keywords {
                keywordCounts[keyword, default: 0] += 1
            }
        }

        return keywordCounts
            .filter { $0.value >= 3 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    // MARK: - Private Helpers

    private func extractKeywords(from title: String) -> [String] {
        let words = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }

        return words
    }

    private func estimateFromHistory(keywords: [String], title: String) -> DurationEstimate? {
        // Find similar tasks from history
        let similarTasks = taskHistories.filter { history in
            let matchingKeywords = Set(history.keywords).intersection(Set(keywords))
            return matchingKeywords.count >= 2 || history.title.lowercased().contains(title.lowercased())
        }

        guard similarTasks.count >= 2 else { return nil }

        // Calculate average actual duration
        let avgMinutes = similarTasks.map { $0.actualMinutes }.reduce(0, +) / similarTasks.count

        // Confidence based on sample size
        let confidence: DurationEstimate.Confidence
        switch similarTasks.count {
        case 2...4: confidence = .low
        case 5...9: confidence = .medium
        default: confidence = .high
        }

        return DurationEstimate(
            minutes: avgMinutes,
            confidence: confidence,
            source: .historical,
            basedOnCount: similarTasks.count
        )
    }

    private func estimateFromKeywords(keywords: [String], title: String) -> DurationEstimate {
        var baseMinutes = 15 // Default

        // Check for duration modifiers
        for keyword in keywords {
            if quickKeywords.contains(keyword) {
                baseMinutes = max(5, baseMinutes - 10)
            } else if longKeywords.contains(keyword) {
                baseMinutes += 30
            } else if veryLongKeywords.contains(keyword) {
                baseMinutes += 60
            } else if mediumKeywords.contains(keyword) {
                baseMinutes += 10
            }
        }

        // Check for specific patterns
        if title.lowercased().contains("email") && !title.lowercased().contains("all") {
            baseMinutes = min(baseMinutes, 20)
        }
        if title.lowercased().contains("meeting") {
            baseMinutes = max(30, baseMinutes)
        }
        if title.lowercased().contains("report") || title.lowercased().contains("document") {
            baseMinutes = max(45, baseMinutes)
        }

        // Apply user's typical underestimation correction
        if estimationAccuracy > 1.3 {
            // User typically takes 30%+ longer, adjust estimate up
            baseMinutes = Int(Double(baseMinutes) * estimationAccuracy)
        }

        // Round to nice numbers
        baseMinutes = roundToNiceNumber(baseMinutes)

        return DurationEstimate(
            minutes: baseMinutes,
            confidence: .low,
            source: .keywordBased,
            basedOnCount: 0
        )
    }

    private func roundToNiceNumber(_ minutes: Int) -> Int {
        switch minutes {
        case 0...7: return 5
        case 8...12: return 10
        case 13...17: return 15
        case 18...25: return 20
        case 26...35: return 30
        case 36...50: return 45
        case 51...75: return 60
        case 76...100: return 90
        default: return (minutes / 30) * 30 // Round to nearest 30
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(taskHistories) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let histories = try? JSONDecoder().decode([TaskHistory].self, from: data) {
            taskHistories = histories
        }
    }
}

// MARK: - Duration Estimate

struct DurationEstimate {
    let minutes: Int
    let confidence: Confidence
    let source: Source
    let basedOnCount: Int

    enum Confidence {
        case low, medium, high

        var displayName: String {
            switch self {
            case .low: return "rough estimate"
            case .medium: return "based on similar tasks"
            case .high: return "based on your history"
            }
        }
    }

    enum Source {
        case historical
        case keywordBased
    }

    var displayString: String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(mins) min"
        }
    }
}

// MARK: - Duration Validation

struct DurationValidation {
    let isRealistic: Bool
    let message: String?
    let suggestedMinutes: Int?
    let confidence: DurationEstimate.Confidence
}
