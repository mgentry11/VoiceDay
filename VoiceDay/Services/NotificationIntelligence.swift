import Foundation
import UserNotifications

// MARK: - Notification Intelligence

/// Learns user's notification response patterns and adapts timing
/// ADHD users have variable attention - notifications should respect that
@MainActor
class NotificationIntelligence: ObservableObject {
    static let shared = NotificationIntelligence()

    // MARK: - Published State

    @Published private(set) var isLearning = true
    @Published private(set) var optimalWindows: [ProductiveWindow] = []
    @Published private(set) var quietPeriods: [QuietPeriod] = []

    // MARK: - Response Tracking

    struct NotificationResponse: Codable {
        let notificationId: String
        let sentAt: Date
        let respondedAt: Date?
        let action: ResponseAction
        let hourOfDay: Int
        let dayOfWeek: Int
        let responseTimeSeconds: Int?

        enum ResponseAction: String, Codable {
            case completed      // User completed the task
            case snoozed       // User snoozed
            case dismissed     // User dismissed without action
            case ignored       // No response (timed out)
        }
    }

    private var responseHistory: [NotificationResponse] = []
    private let historyKey = "notification_response_history"
    private let maxHistorySize = 500

    // MARK: - Productive Windows

    struct ProductiveWindow: Codable, Identifiable {
        let id: UUID
        let startHour: Int
        let endHour: Int
        let dayOfWeek: Int?  // nil = all days
        let responseRate: Double
        let averageResponseTime: TimeInterval

        var displayTime: String {
            let start = String(format: "%d:00", startHour)
            let end = String(format: "%d:00", endHour)
            return "\(start) - \(end)"
        }

        var dayName: String? {
            guard let day = dayOfWeek else { return nil }
            let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days[safe: day]
        }
    }

    struct QuietPeriod: Codable, Identifiable {
        let id: UUID
        let startHour: Int
        let endHour: Int
        let reason: String  // e.g., "Low response rate", "User marked"

        var displayTime: String {
            let start = String(format: "%d:00", startHour)
            let end = String(format: "%d:00", endHour)
            return "\(start) - \(end)"
        }
    }

    // MARK: - Initialization

    init() {
        loadHistory()
        analyzePatterns()
    }

    // MARK: - Response Recording

    /// Record when a notification is sent
    func recordNotificationSent(id: String) {
        let now = Date()
        let calendar = Calendar.current

        let response = NotificationResponse(
            notificationId: id,
            sentAt: now,
            respondedAt: nil,
            action: .ignored,  // Will update when responded
            hourOfDay: calendar.component(.hour, from: now),
            dayOfWeek: calendar.component(.weekday, from: now),
            responseTimeSeconds: nil
        )

        responseHistory.append(response)
        trimAndSave()
    }

    /// Record user's response to a notification
    func recordResponse(notificationId: String, action: NotificationResponse.ResponseAction) {
        let now = Date()

        if let index = responseHistory.lastIndex(where: { $0.notificationId == notificationId }) {
            let original = responseHistory[index]
            let responseTime = Int(now.timeIntervalSince(original.sentAt))

            responseHistory[index] = NotificationResponse(
                notificationId: original.notificationId,
                sentAt: original.sentAt,
                respondedAt: now,
                action: action,
                hourOfDay: original.hourOfDay,
                dayOfWeek: original.dayOfWeek,
                responseTimeSeconds: responseTime
            )

            trimAndSave()
            analyzePatterns()
        }
    }

    // MARK: - Intelligence

    /// Should we send a notification now, or wait?
    func shouldSendNotificationNow() -> NotificationDecision {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentDay = calendar.component(.weekday, from: now)

        // Check quiet periods
        for quiet in quietPeriods {
            if currentHour >= quiet.startHour && currentHour < quiet.endHour {
                return NotificationDecision(
                    shouldSend: false,
                    reason: "Currently in quiet period",
                    suggestedDelay: TimeInterval((quiet.endHour - currentHour) * 3600)
                )
            }
        }

        // Check if current time is in a productive window
        let currentWindow = optimalWindows.first { window in
            currentHour >= window.startHour && currentHour < window.endHour &&
            (window.dayOfWeek == nil || window.dayOfWeek == currentDay)
        }

        if let window = currentWindow {
            return NotificationDecision(
                shouldSend: true,
                reason: "Good time - \(Int(window.responseRate * 100))% response rate",
                suggestedDelay: nil
            )
        }

        // Check historical response rate for this hour
        let hourlyRate = responseRateForHour(currentHour)

        if hourlyRate < 0.3 {
            // Low response rate - suggest waiting
            let nextGoodHour = findNextGoodHour(from: currentHour)
            let delay = TimeInterval((nextGoodHour - currentHour) * 3600)

            return NotificationDecision(
                shouldSend: false,
                reason: "Low response rate at this time (\(Int(hourlyRate * 100))%)",
                suggestedDelay: max(0, delay)
            )
        }

        return NotificationDecision(
            shouldSend: true,
            reason: "Normal response window",
            suggestedDelay: nil
        )
    }

    /// Get optimal notification interval based on patterns
    func optimalNotificationInterval() -> TimeInterval {
        let baseInterval: TimeInterval = 15 * 60 // 15 minutes default

        // Adjust based on energy level
        let energyMultiplier = EnergyService.shared.currentEnergy.notificationMultiplier

        // Adjust based on recent response patterns
        let recentResponses = responseHistory.suffix(20)
        let recentIgnoreRate = Double(recentResponses.filter { $0.action == .ignored }.count) / Double(max(1, recentResponses.count))

        var adjustedInterval = baseInterval * energyMultiplier

        // If user is ignoring a lot, back off
        if recentIgnoreRate > 0.5 {
            adjustedInterval *= 1.5
        }

        // Clamp to reasonable bounds
        return min(60 * 60, max(5 * 60, adjustedInterval)) // 5 min to 1 hour
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns() {
        guard responseHistory.count >= 20 else {
            isLearning = true
            return
        }

        isLearning = false

        // Analyze by hour
        var hourlyStats: [Int: (responses: Int, completed: Int, avgTime: Double)] = [:]

        for response in responseHistory {
            let hour = response.hourOfDay
            var stats = hourlyStats[hour] ?? (0, 0, 0)
            stats.responses += 1

            if response.action == .completed {
                stats.completed += 1
            }

            if let time = response.responseTimeSeconds {
                stats.avgTime = (stats.avgTime * Double(stats.responses - 1) + Double(time)) / Double(stats.responses)
            }

            hourlyStats[hour] = stats
        }

        // Find productive windows (>50% response rate)
        var windows: [ProductiveWindow] = []
        var windowStart: Int?

        for hour in 6..<23 { // 6 AM to 11 PM
            if let stats = hourlyStats[hour] {
                let rate = Double(stats.completed) / Double(max(1, stats.responses))

                if rate >= 0.5 {
                    if windowStart == nil {
                        windowStart = hour
                    }
                } else if let start = windowStart {
                    windows.append(ProductiveWindow(
                        id: UUID(),
                        startHour: start,
                        endHour: hour,
                        dayOfWeek: nil,
                        responseRate: rate,
                        averageResponseTime: stats.avgTime
                    ))
                    windowStart = nil
                }
            }
        }

        // Close any open window
        if let start = windowStart {
            windows.append(ProductiveWindow(
                id: UUID(),
                startHour: start,
                endHour: 23,
                dayOfWeek: nil,
                responseRate: 0.5,
                averageResponseTime: 0
            ))
        }

        optimalWindows = windows

        // Find quiet periods (low response rate)
        var quiets: [QuietPeriod] = []
        var quietStart: Int?

        for hour in 0..<24 {
            if let stats = hourlyStats[hour] {
                let rate = Double(stats.completed) / Double(max(1, stats.responses))

                if rate < 0.2 && stats.responses >= 5 {
                    if quietStart == nil {
                        quietStart = hour
                    }
                } else if let start = quietStart {
                    quiets.append(QuietPeriod(
                        id: UUID(),
                        startHour: start,
                        endHour: hour,
                        reason: "Low response rate"
                    ))
                    quietStart = nil
                }
            }
        }

        quietPeriods = quiets

        savePatterns()
    }

    private func responseRateForHour(_ hour: Int) -> Double {
        let hourResponses = responseHistory.filter { $0.hourOfDay == hour }
        guard !hourResponses.isEmpty else { return 0.5 } // Default

        let completed = hourResponses.filter { $0.action == .completed }.count
        return Double(completed) / Double(hourResponses.count)
    }

    private func findNextGoodHour(from currentHour: Int) -> Int {
        for offset in 1..<24 {
            let hour = (currentHour + offset) % 24
            if responseRateForHour(hour) >= 0.5 {
                return currentHour + offset
            }
        }
        return currentHour + 1 // Default: try again in an hour
    }

    // MARK: - Persistence

    private func trimAndSave() {
        if responseHistory.count > maxHistorySize {
            responseHistory = Array(responseHistory.suffix(maxHistorySize))
        }

        if let encoded = try? JSONEncoder().encode(responseHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([NotificationResponse].self, from: data) {
            responseHistory = history
        }
    }

    private func savePatterns() {
        if let windowData = try? JSONEncoder().encode(optimalWindows) {
            UserDefaults.standard.set(windowData, forKey: "optimal_windows")
        }
        if let quietData = try? JSONEncoder().encode(quietPeriods) {
            UserDefaults.standard.set(quietData, forKey: "quiet_periods")
        }
    }
}

// MARK: - Notification Decision

struct NotificationDecision {
    let shouldSend: Bool
    let reason: String
    let suggestedDelay: TimeInterval?
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
