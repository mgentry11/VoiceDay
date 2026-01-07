import Foundation
import EventKit

// MARK: - Smart Scheduler

/// AI-powered scheduling based on user's productivity patterns
/// Learns when users complete different types of tasks and suggests optimal times
@MainActor
class SmartScheduler: ObservableObject {
    static let shared = SmartScheduler()

    // MARK: - Published State

    @Published private(set) var isLearning = true
    @Published private(set) var suggestions: [ScheduleSuggestion] = []

    // MARK: - Task Completion Record

    struct TaskCompletion: Codable {
        let taskTitle: String
        let keywords: [String]
        let category: TaskCategory
        let completedAt: Date
        let hourOfDay: Int
        let dayOfWeek: Int
        let durationMinutes: Int?
        let wasOnTime: Bool  // Completed before deadline
    }

    enum TaskCategory: String, Codable, CaseIterable {
        case email = "email"
        case meeting = "meeting"
        case deepWork = "deep_work"
        case admin = "admin"
        case creative = "creative"
        case exercise = "exercise"
        case personal = "personal"
        case other = "other"

        var displayName: String {
            switch self {
            case .email: return "Email/Messages"
            case .meeting: return "Meetings"
            case .deepWork: return "Deep Work"
            case .admin: return "Admin Tasks"
            case .creative: return "Creative Work"
            case .exercise: return "Exercise"
            case .personal: return "Personal"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .meeting: return "person.2.fill"
            case .deepWork: return "brain.head.profile"
            case .admin: return "doc.text.fill"
            case .creative: return "paintbrush.fill"
            case .exercise: return "figure.run"
            case .personal: return "heart.fill"
            case .other: return "square.grid.2x2.fill"
            }
        }

        static func categorize(title: String) -> TaskCategory {
            let lower = title.lowercased()

            if lower.contains("email") || lower.contains("message") || lower.contains("reply") || lower.contains("respond") {
                return .email
            }
            if lower.contains("meeting") || lower.contains("call") || lower.contains("zoom") || lower.contains("sync") {
                return .meeting
            }
            if lower.contains("write") || lower.contains("report") || lower.contains("analysis") || lower.contains("research") || lower.contains("deep") {
                return .deepWork
            }
            if lower.contains("expense") || lower.contains("invoice") || lower.contains("file") || lower.contains("organize") {
                return .admin
            }
            if lower.contains("design") || lower.contains("create") || lower.contains("brainstorm") || lower.contains("idea") {
                return .creative
            }
            if lower.contains("workout") || lower.contains("gym") || lower.contains("run") || lower.contains("exercise") {
                return .exercise
            }
            if lower.contains("doctor") || lower.contains("appointment") || lower.contains("personal") || lower.contains("family") {
                return .personal
            }

            return .other
        }
    }

    // MARK: - Schedule Suggestion

    struct ScheduleSuggestion: Identifiable {
        let id = UUID()
        let taskTitle: String
        let suggestedTime: Date
        let reason: String
        let confidence: Confidence
        let category: TaskCategory

        enum Confidence {
            case high, medium, low

            var displayName: String {
                switch self {
                case .high: return "Strong match"
                case .medium: return "Good time"
                case .low: return "Suggestion"
                }
            }
        }
    }

    // MARK: - Productivity Patterns

    struct HourlyPattern: Codable {
        var completionCount: Int = 0
        var onTimeRate: Double = 0
        var averageDuration: Double = 0
        var categories: [TaskCategory: Int] = [:]
    }

    private var hourlyPatterns: [Int: HourlyPattern] = [:]  // Hour (0-23) -> Pattern
    private var dayPatterns: [Int: [Int: HourlyPattern]] = [:]  // Day (1-7) -> Hour -> Pattern

    // MARK: - History

    private var completionHistory: [TaskCompletion] = []
    private let historyKey = "smart_scheduler_history"
    private let maxHistorySize = 200

    // MARK: - Initialization

    init() {
        loadHistory()
        analyzePatterns()
    }

    // MARK: - Recording

    /// Record a task completion for learning
    func recordCompletion(
        taskTitle: String,
        completedAt: Date = Date(),
        durationMinutes: Int? = nil,
        deadline: Date? = nil
    ) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: completedAt)
        let day = calendar.component(.weekday, from: completedAt)

        let wasOnTime = deadline.map { completedAt <= $0 } ?? true

        let completion = TaskCompletion(
            taskTitle: taskTitle,
            keywords: extractKeywords(from: taskTitle),
            category: TaskCategory.categorize(title: taskTitle),
            completedAt: completedAt,
            hourOfDay: hour,
            dayOfWeek: day,
            durationMinutes: durationMinutes,
            wasOnTime: wasOnTime
        )

        completionHistory.append(completion)
        trimAndSave()
        analyzePatterns()

        print("📊 Recorded completion: '\(taskTitle)' at \(hour):00 on day \(day)")
    }

    // MARK: - Suggestions

    /// Get suggested time for a new task
    func suggestTime(for taskTitle: String) -> ScheduleSuggestion? {
        let category = TaskCategory.categorize(title: taskTitle)
        let now = Date()
        let calendar = Calendar.current

        // Find best hour for this category
        var bestHour: Int?
        var bestScore: Double = 0

        for (hour, pattern) in hourlyPatterns {
            // Skip past hours today
            if calendar.isDateInToday(now) && hour <= calendar.component(.hour, from: now) {
                continue
            }

            // Calculate score for this hour
            let categoryCount = pattern.categories[category] ?? 0
            let score = Double(categoryCount) * pattern.onTimeRate

            if score > bestScore {
                bestScore = score
                bestHour = hour
            }
        }

        guard let hour = bestHour else { return nil }

        // Build suggested date
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0

        var suggestedDate = calendar.date(from: components) ?? now

        // If hour already passed today, suggest tomorrow
        if suggestedDate < now {
            suggestedDate = calendar.date(byAdding: .day, value: 1, to: suggestedDate) ?? suggestedDate
        }

        let confidence: ScheduleSuggestion.Confidence
        if bestScore > 5 {
            confidence = .high
        } else if bestScore > 2 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let hourPattern = hourlyPatterns[hour]
        let completions = hourPattern?.categories[category] ?? 0

        return ScheduleSuggestion(
            taskTitle: taskTitle,
            suggestedTime: suggestedDate,
            reason: "You've completed \(completions) similar tasks at this time",
            confidence: confidence,
            category: category
        )
    }

    /// Get suggestions for all pending tasks
    func generateSuggestions(for tasks: [String]) {
        suggestions = tasks.compactMap { suggestTime(for: $0) }
    }

    // MARK: - Insights

    /// Get best hours for a specific task category
    func bestHoursFor(category: TaskCategory) -> [Int] {
        hourlyPatterns
            .filter { ($0.value.categories[category] ?? 0) >= 2 }
            .sorted { ($0.value.categories[category] ?? 0) > ($1.value.categories[category] ?? 0) }
            .prefix(3)
            .map { $0.key }
    }

    /// Get productivity score for a given hour
    func productivityScore(for hour: Int) -> Double {
        guard let pattern = hourlyPatterns[hour], pattern.completionCount > 0 else {
            return 0.5 // Default
        }
        return pattern.onTimeRate
    }

    /// Most productive hours overall
    var topProductiveHours: [Int] {
        hourlyPatterns
            .filter { $0.value.completionCount >= 3 }
            .sorted { $0.value.onTimeRate > $1.value.onTimeRate }
            .prefix(3)
            .map { $0.key }
    }

    /// Category breakdown
    var categoryBreakdown: [TaskCategory: Int] {
        var breakdown: [TaskCategory: Int] = [:]
        for completion in completionHistory {
            breakdown[completion.category, default: 0] += 1
        }
        return breakdown
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns() {
        guard completionHistory.count >= 10 else {
            isLearning = true
            return
        }

        isLearning = false
        hourlyPatterns = [:]

        for completion in completionHistory {
            let hour = completion.hourOfDay

            var pattern = hourlyPatterns[hour] ?? HourlyPattern()
            pattern.completionCount += 1

            // Update on-time rate
            let currentOnTime = pattern.onTimeRate * Double(pattern.completionCount - 1)
            pattern.onTimeRate = (currentOnTime + (completion.wasOnTime ? 1 : 0)) / Double(pattern.completionCount)

            // Update category counts
            pattern.categories[completion.category, default: 0] += 1

            // Update duration average
            if let duration = completion.durationMinutes {
                let currentTotal = pattern.averageDuration * Double(pattern.completionCount - 1)
                pattern.averageDuration = (currentTotal + Double(duration)) / Double(pattern.completionCount)
            }

            hourlyPatterns[hour] = pattern
        }

        savePatterns()
    }

    private func extractKeywords(from title: String) -> [String] {
        title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    // MARK: - Persistence

    private func trimAndSave() {
        if completionHistory.count > maxHistorySize {
            completionHistory = Array(completionHistory.suffix(maxHistorySize))
        }

        if let data = try? JSONEncoder().encode(completionHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([TaskCompletion].self, from: data) {
            completionHistory = history
        }
    }

    private func savePatterns() {
        if let data = try? JSONEncoder().encode(hourlyPatterns) {
            UserDefaults.standard.set(data, forKey: "smart_scheduler_patterns")
        }
    }
}
