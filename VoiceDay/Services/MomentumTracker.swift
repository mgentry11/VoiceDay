import Foundation
import SwiftUI

// MARK: - Momentum Tracker

/// Replaces punishing streak counters with a forgiving momentum system
/// Momentum decays slowly instead of resetting to zero on a bad day
@MainActor
class MomentumTracker: ObservableObject {
    static let shared = MomentumTracker()

    // MARK: - Published State

    @Published private(set) var momentum: Double = 50.0  // 0-100 scale
    @Published private(set) var todayCompleted: Int = 0
    @Published private(set) var lastActiveDate: Date?
    @Published private(set) var currentLevel: MomentumLevel = .moderate

    // MARK: - Configuration

    struct Config {
        // Points earned
        static let pointsPerLowPriority: Double = 5
        static let pointsPerMediumPriority: Double = 8
        static let pointsPerHighPriority: Double = 15
        static let bonusForFirstTaskOfDay: Double = 10
        static let bonusForThreeInARow: Double = 5

        // Decay rates (per day of inactivity)
        static let decayWeekday: Double = 5      // Slow decay on weekdays
        static let decayWeekend: Double = 2      // Even slower on weekends
        static let decaySick: Double = 1         // Minimal decay when marked sick

        // Caps
        static let maxMomentum: Double = 100
        static let minMomentum: Double = 0

        // Comeback
        static let comebackBoostBase: Double = 15
        static let comebackBoostMax: Double = 30
    }

    // MARK: - Momentum Levels

    enum MomentumLevel: String, CaseIterable {
        case excellent    // 80-100
        case good         // 60-79
        case moderate     // 40-59
        case needsWork    // 20-39
        case building     // 0-19

        var displayName: String {
            switch self {
            case .excellent: return "On Fire!"
            case .good: return "Rolling"
            case .moderate: return "Steady"
            case .needsWork: return "Building"
            case .building: return "Starting"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "flame.fill"
            case .good: return "bolt.fill"
            case .moderate: return "arrow.right"
            case .needsWork: return "arrow.up.right"
            case .building: return "leaf.fill"
            }
        }

        var color: Color {
            switch self {
            case .excellent: return .orange
            case .good: return .green
            case .moderate: return .blue
            case .needsWork: return .yellow
            case .building: return .purple
            }
        }

        var encouragement: String {
            switch self {
            case .excellent: return "You're unstoppable!"
            case .good: return "Great momentum going!"
            case .moderate: return "Steady progress - keep it up!"
            case .needsWork: return "Every task builds momentum"
            case .building: return "Starting fresh - you've got this!"
            }
        }

        static func from(momentum: Double) -> MomentumLevel {
            switch momentum {
            case 80...100: return .excellent
            case 60..<80: return .good
            case 40..<60: return .moderate
            case 20..<40: return .needsWork
            default: return .building
            }
        }
    }

    // MARK: - Persistence Keys

    private let momentumKey = "momentum_value"
    private let lastActiveDateKey = "momentum_last_active"
    private let todayCompletedKey = "momentum_today_completed"
    private let todayDateKey = "momentum_today_date"

    // MARK: - Initialization

    init() {
        loadState()
        applyDecayIfNeeded()
    }

    // MARK: - Task Completion

    /// Record a task completion and gain momentum
    func recordTaskCompletion(priority: ItemPriority) {
        let isFirstToday = !Calendar.current.isDateInToday(lastActiveDate ?? .distantPast)

        // Reset today counter if new day
        if isFirstToday {
            todayCompleted = 0
        }

        // Calculate points
        var points: Double = 0

        switch priority {
        case .low: points = Config.pointsPerLowPriority
        case .medium: points = Config.pointsPerMediumPriority
        case .high: points = Config.pointsPerHighPriority
        }

        // First task of day bonus
        if isFirstToday {
            points += Config.bonusForFirstTaskOfDay
        }

        // Three in a row bonus
        if (todayCompleted + 1) % 3 == 0 {
            points += Config.bonusForThreeInARow
        }

        // Apply momentum gain
        momentum = min(Config.maxMomentum, momentum + points)
        todayCompleted += 1
        lastActiveDate = Date()
        currentLevel = MomentumLevel.from(momentum: momentum)

        saveState()

        print("Momentum: +\(points) → \(Int(momentum)) (\(currentLevel.displayName))")
    }

    /// Apply comeback boost when returning after absence
    func applyComebackBoost() {
        guard let lastActive = lastActiveDate else { return }

        let daysSinceActive = Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0

        // Only apply if been away 2+ days
        guard daysSinceActive >= 2 else { return }

        // Boost scales with time away (encourages coming back)
        let boost = min(Config.comebackBoostMax, Config.comebackBoostBase + Double(daysSinceActive - 2) * 2)
        momentum = min(Config.maxMomentum, momentum + boost)
        currentLevel = MomentumLevel.from(momentum: momentum)

        saveState()

        print("Welcome back! Comeback boost: +\(Int(boost)) → \(Int(momentum))")
    }

    /// Mark a sick/rest day (minimal decay)
    func markRestDay() {
        UserDefaults.standard.set(Date(), forKey: "momentum_rest_day")
    }

    // MARK: - Decay Logic

    private func applyDecayIfNeeded() {
        guard let lastActive = lastActiveDate else {
            // First time user - start at moderate momentum
            momentum = 50
            currentLevel = .moderate
            return
        }

        // Check if we already processed today
        if Calendar.current.isDateInToday(lastActive) {
            return
        }

        let calendar = Calendar.current
        let daysSinceActive = calendar.dateComponents([.day], from: lastActive, to: Date()).day ?? 0

        guard daysSinceActive > 0 else { return }

        // Calculate decay
        var totalDecay: Double = 0

        for dayOffset in 1...daysSinceActive {
            guard let decayDate = calendar.date(byAdding: .day, value: dayOffset, to: lastActive) else { continue }

            // Check if it was a rest day
            if let restDay = UserDefaults.standard.object(forKey: "momentum_rest_day") as? Date,
               calendar.isDate(restDay, inSameDayAs: decayDate) {
                totalDecay += Config.decaySick
                continue
            }

            // Weekend vs weekday decay
            let weekday = calendar.component(.weekday, from: decayDate)
            let isWeekend = weekday == 1 || weekday == 7

            totalDecay += isWeekend ? Config.decayWeekend : Config.decayWeekday
        }

        // Apply decay (but never go below 0)
        let previousMomentum = momentum
        momentum = max(Config.minMomentum, momentum - totalDecay)
        currentLevel = MomentumLevel.from(momentum: momentum)

        if totalDecay > 0 {
            print("Momentum decay: -\(Int(totalDecay)) (\(Int(previousMomentum)) → \(Int(momentum)))")
        }

        saveState()
    }

    // MARK: - Persistence

    private func saveState() {
        UserDefaults.standard.set(momentum, forKey: momentumKey)
        UserDefaults.standard.set(lastActiveDate, forKey: lastActiveDateKey)
        UserDefaults.standard.set(todayCompleted, forKey: todayCompletedKey)

        // Store today's date for counter reset
        if Calendar.current.isDateInToday(lastActiveDate ?? .distantPast) {
            UserDefaults.standard.set(Date(), forKey: todayDateKey)
        }
    }

    private func loadState() {
        momentum = UserDefaults.standard.double(forKey: momentumKey)
        if momentum == 0 && UserDefaults.standard.object(forKey: momentumKey) == nil {
            momentum = 50 // Default starting momentum
        }

        lastActiveDate = UserDefaults.standard.object(forKey: lastActiveDateKey) as? Date

        // Load today's completed count (reset if not today)
        if let savedDate = UserDefaults.standard.object(forKey: todayDateKey) as? Date,
           Calendar.current.isDateInToday(savedDate) {
            todayCompleted = UserDefaults.standard.integer(forKey: todayCompletedKey)
        } else {
            todayCompleted = 0
        }

        currentLevel = MomentumLevel.from(momentum: momentum)
    }

    // MARK: - Reset (for testing)

    #if DEBUG
    func reset() {
        momentum = 50
        todayCompleted = 0
        lastActiveDate = nil
        currentLevel = .moderate
        saveState()
    }
    #endif
}

// MARK: - Momentum Change

struct MomentumChange {
    let previousLevel: MomentumTracker.MomentumLevel
    let newLevel: MomentumTracker.MomentumLevel
    let pointsGained: Double

    var leveledUp: Bool {
        newLevel.rawValue != previousLevel.rawValue &&
        MomentumTracker.MomentumLevel.allCases.firstIndex(of: newLevel)! <
        MomentumTracker.MomentumLevel.allCases.firstIndex(of: previousLevel)!
    }
}
