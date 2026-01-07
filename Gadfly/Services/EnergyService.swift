import Foundation
import SwiftUI

// MARK: - Energy Service

/// Tracks user's energy level and adapts app behavior accordingly
/// ADHD users have variable energy - the app should respect that
@MainActor
class EnergyService: ObservableObject {
    static let shared = EnergyService()

    // MARK: - Published State

    @Published private(set) var currentEnergy: EnergyLevel = .medium
    @Published private(set) var lastCheckIn: Date?
    @Published var showCheckInPrompt = false

    // MARK: - Energy Levels

    enum EnergyLevel: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var displayName: String {
            switch self {
            case .low: return "Low Energy"
            case .medium: return "Normal"
            case .high: return "High Energy"
            }
        }

        var shortName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Normal"
            case .high: return "High"
            }
        }

        var icon: String {
            switch self {
            case .low: return "battery.25"
            case .medium: return "battery.50"
            case .high: return "battery.100"
            }
        }

        var emoji: String {
            switch self {
            case .low: return "🔋"
            case .medium: return "⚡"
            case .high: return "🚀"
            }
        }

        var color: Color {
            switch self {
            case .low: return .orange
            case .medium: return .blue
            case .high: return .green
            }
        }

        var description: String {
            switch self {
            case .low: return "Taking it easy today - gentle reminders only"
            case .medium: return "Balanced mode - normal productivity expectations"
            case .high: return "Feeling great - let's tackle challenging tasks!"
            }
        }

        // How this affects app behavior
        var notificationMultiplier: Double {
            switch self {
            case .low: return 2.0    // Double the interval between reminders
            case .medium: return 1.0  // Normal intervals
            case .high: return 0.75   // Slightly more frequent for focus
            }
        }

        var taskSortPriority: [TaskDifficulty] {
            switch self {
            case .low: return [.easy, .medium, .hard]     // Easy tasks first
            case .medium: return [.medium, .hard, .easy]   // Balanced
            case .high: return [.hard, .medium, .easy]     // Tackle hard stuff
            }
        }

        var celebrationIntensity: Double {
            switch self {
            case .low: return 1.5    // Extra encouragement when low
            case .medium: return 1.0
            case .high: return 0.8   // Less fanfare needed
            }
        }

        var expectedTasksPerDay: Int {
            switch self {
            case .low: return 3      // Reduced expectations
            case .medium: return 5   // Normal
            case .high: return 8     // Stretch goal
            }
        }
    }

    enum TaskDifficulty: String, Codable {
        case easy, medium, hard
    }

    // MARK: - Persistence Keys

    private let energyKey = "current_energy_level"
    private let lastCheckInKey = "last_energy_checkin"
    private let checkInHistoryKey = "energy_checkin_history"

    // MARK: - Initialization

    init() {
        loadState()
        checkIfNeedsCheckIn()
    }

    // MARK: - Check-In Methods

    /// Set the current energy level
    func setEnergy(_ level: EnergyLevel) {
        let previousLevel = currentEnergy
        currentEnergy = level
        lastCheckIn = Date()
        showCheckInPrompt = false

        saveState()
        saveToHistory(level)

        // Notify other services of the change
        NotificationCenter.default.post(
            name: .energyLevelChanged,
            object: nil,
            userInfo: ["level": level, "previous": previousLevel]
        )

        print("⚡ Energy level set to \(level.displayName)")
    }

    /// Check if we should prompt for an energy check-in
    func checkIfNeedsCheckIn() {
        guard let lastCheck = lastCheckIn else {
            // Never checked in - prompt on first launch of day
            showCheckInPrompt = true
            return
        }

        let calendar = Calendar.current

        // Check if it's a new day
        if !calendar.isDateInToday(lastCheck) {
            showCheckInPrompt = true
            return
        }

        // Check if it's been more than 4 hours (optional mid-day check)
        let hoursSinceCheck = calendar.dateComponents([.hour], from: lastCheck, to: Date()).hour ?? 0
        if hoursSinceCheck >= 4 {
            // Only prompt mid-day if user has opted in
            if UserDefaults.standard.bool(forKey: "energy_midday_checkin") {
                showCheckInPrompt = true
            }
        }
    }

    /// Skip the check-in (use previous/default energy)
    func skipCheckIn() {
        showCheckInPrompt = false
        // If never set, default to medium
        if lastCheckIn == nil {
            currentEnergy = .medium
            saveState()
        }
    }

    // MARK: - History & Analytics

    struct EnergyCheckIn: Codable {
        let level: EnergyLevel
        let timestamp: Date
        let dayOfWeek: Int
        let hourOfDay: Int
    }

    private var checkInHistory: [EnergyCheckIn] = []

    private func saveToHistory(_ level: EnergyLevel) {
        let calendar = Calendar.current
        let now = Date()

        let checkIn = EnergyCheckIn(
            level: level,
            timestamp: now,
            dayOfWeek: calendar.component(.weekday, from: now),
            hourOfDay: calendar.component(.hour, from: now)
        )

        checkInHistory.append(checkIn)

        // Keep last 30 days
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        checkInHistory = checkInHistory.filter { $0.timestamp > thirtyDaysAgo }

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(checkInHistory) {
            UserDefaults.standard.set(encoded, forKey: checkInHistoryKey)
        }
    }

    /// Get the most common energy level for a given day/time
    func predictedEnergy(for date: Date = Date()) -> EnergyLevel? {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)
        let hourOfDay = calendar.component(.hour, from: date)

        // Find check-ins on similar days/times
        let similarCheckIns = checkInHistory.filter { checkIn in
            checkIn.dayOfWeek == dayOfWeek &&
            abs(checkIn.hourOfDay - hourOfDay) <= 2 // Within 2 hours
        }

        guard !similarCheckIns.isEmpty else { return nil }

        // Return most common level
        let counts = Dictionary(grouping: similarCheckIns, by: { $0.level })
        return counts.max(by: { $0.value.count < $1.value.count })?.key
    }

    /// Get average energy for analytics
    var averageEnergyThisWeek: Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let recentCheckIns = checkInHistory.filter { $0.timestamp > weekAgo }
        guard !recentCheckIns.isEmpty else { return 2.0 } // Default to medium

        let total = recentCheckIns.reduce(0.0) { sum, checkIn in
            switch checkIn.level {
            case .low: return sum + 1
            case .medium: return sum + 2
            case .high: return sum + 3
            }
        }

        return total / Double(recentCheckIns.count)
    }

    // MARK: - Persistence

    private func saveState() {
        UserDefaults.standard.set(currentEnergy.rawValue, forKey: energyKey)
        UserDefaults.standard.set(lastCheckIn, forKey: lastCheckInKey)
    }

    private func loadState() {
        if let energyRaw = UserDefaults.standard.string(forKey: energyKey),
           let energy = EnergyLevel(rawValue: energyRaw) {
            currentEnergy = energy
        }

        lastCheckIn = UserDefaults.standard.object(forKey: lastCheckInKey) as? Date

        // Load history
        if let data = UserDefaults.standard.data(forKey: checkInHistoryKey),
           let history = try? JSONDecoder().decode([EnergyCheckIn].self, from: data) {
            checkInHistory = history
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let energyLevelChanged = Notification.Name("energyLevelChanged")
}

// MARK: - Settings

extension EnergyService {
    var midDayCheckInEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "energy_midday_checkin") }
        set { UserDefaults.standard.set(newValue, forKey: "energy_midday_checkin") }
    }
}
