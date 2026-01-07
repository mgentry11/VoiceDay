import Foundation
import SwiftUI

// MARK: - Medication Window Service

/// Privacy-first medication timing tracker for ADHD users
/// Tracks "focus windows" without storing medication names
/// Helps schedule demanding tasks during peak effectiveness
@MainActor
class MedicationWindowService: ObservableObject {
    static let shared = MedicationWindowService()

    // MARK: - Published State

    @Published var isEnabled = false
    @Published private(set) var currentWindow: WindowState = .unknown
    @Published private(set) var windowStartTime: Date?
    @Published private(set) var expectedPeakEnd: Date?
    @Published private(set) var expectedTotalEnd: Date?

    // MARK: - Window Configuration

    struct WindowConfig: Codable {
        var peakDurationMinutes: Int = 180      // 3 hours typical peak
        var totalDurationMinutes: Int = 360     // 6 hours total effect
        var reminderEnabled: Bool = true
        var reminderMinutesBefore: Int = 30     // Remind before window ends
    }

    @Published var config = WindowConfig()

    // MARK: - Window States

    enum WindowState: String {
        case unknown        // No data
        case preMedication  // Before taking medication
        case ramping        // Medication kicking in (first 30-60 min)
        case peak           // Peak effectiveness
        case declining      // Still effective but declining
        case ended          // Medication worn off

        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .preMedication: return "Before Window"
            case .ramping: return "Ramping Up"
            case .peak: return "Peak Focus"
            case .declining: return "Winding Down"
            case .ended: return "Window Ended"
            }
        }

        var icon: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .preMedication: return "moon.zzz"
            case .ramping: return "arrow.up.circle"
            case .peak: return "bolt.circle.fill"
            case .declining: return "arrow.down.circle"
            case .ended: return "moon.circle"
            }
        }

        var color: Color {
            switch self {
            case .unknown: return .gray
            case .preMedication: return .orange
            case .ramping: return .yellow
            case .peak: return .green
            case .declining: return .orange
            case .ended: return .gray
            }
        }

        var taskRecommendation: String {
            switch self {
            case .unknown: return "Track your focus window to get personalized recommendations"
            case .preMedication: return "Good time for routine tasks or planning"
            case .ramping: return "Start with easier tasks while focus builds"
            case .peak: return "Perfect time for challenging, deep work!"
            case .declining: return "Wrap up complex tasks, switch to easier ones"
            case .ended: return "Best for low-stakes tasks or taking a break"
            }
        }
    }

    // MARK: - History

    struct WindowLog: Codable, Identifiable {
        let id: UUID
        let startTime: Date
        let endTime: Date?
        let peakDuration: TimeInterval
        let totalDuration: TimeInterval
        let productivity: ProductivityRating?

        enum ProductivityRating: Int, Codable {
            case poor = 1
            case fair = 2
            case good = 3
            case excellent = 4
        }
    }

    private var windowHistory: [WindowLog] = []
    private let historyKey = "medication_window_history"
    private let configKey = "medication_window_config"
    private let enabledKey = "medication_window_enabled"

    // MARK: - Timer

    private var updateTimer: Timer?

    // MARK: - Initialization

    init() {
        loadState()
        startUpdateTimer()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Window Control

    /// User indicates they've started their focus window
    func startWindow() {
        let now = Date()
        windowStartTime = now
        expectedPeakEnd = now.addingTimeInterval(TimeInterval(config.peakDurationMinutes * 60))
        expectedTotalEnd = now.addingTimeInterval(TimeInterval(config.totalDurationMinutes * 60))
        currentWindow = .ramping

        // Schedule reminder if enabled
        if config.reminderEnabled {
            scheduleWindowEndReminder()
        }

        saveState()
        updateWindowState()

        print("🎯 Focus window started at \(now)")
    }

    /// User indicates their window has ended
    func endWindow(productivity: WindowLog.ProductivityRating? = nil) {
        guard let start = windowStartTime else { return }

        let now = Date()
        let duration = now.timeIntervalSince(start)

        // Log this window
        let log = WindowLog(
            id: UUID(),
            startTime: start,
            endTime: now,
            peakDuration: min(duration, TimeInterval(config.peakDurationMinutes * 60)),
            totalDuration: duration,
            productivity: productivity
        )
        windowHistory.append(log)

        // Learn from this window
        if let rating = productivity {
            learnFromWindow(log: log, rating: rating)
        }

        // Reset state
        windowStartTime = nil
        expectedPeakEnd = nil
        expectedTotalEnd = nil
        currentWindow = .ended

        // Cancel any pending reminders
        cancelWindowReminders()

        saveState()
        print("🎯 Focus window ended after \(Int(duration / 60)) minutes")
    }

    /// Update window state based on current time
    private func updateWindowState() {
        guard let start = windowStartTime else {
            if currentWindow != .preMedication && currentWindow != .unknown {
                currentWindow = .ended
            }
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(start)
        let elapsedMinutes = Int(elapsed / 60)

        // Determine current phase
        if elapsedMinutes < 30 {
            currentWindow = .ramping
        } else if elapsedMinutes < config.peakDurationMinutes {
            currentWindow = .peak
        } else if elapsedMinutes < config.totalDurationMinutes {
            currentWindow = .declining
        } else {
            currentWindow = .ended
            // Auto-end the window
            endWindow()
        }
    }

    // MARK: - Learning

    private func learnFromWindow(log: WindowLog, rating: WindowLog.ProductivityRating) {
        // If user reports good/excellent productivity with shorter duration,
        // suggest adjusting their window expectations
        let actualPeakMinutes = Int(log.peakDuration / 60)

        if rating.rawValue >= 3 && actualPeakMinutes < config.peakDurationMinutes - 30 {
            // User was productive with shorter peak - don't adjust down automatically
            // but could surface this insight
            print("📊 User productive with \(actualPeakMinutes) min peak (config: \(config.peakDurationMinutes))")
        }
    }

    // MARK: - Recommendations

    /// Should we suggest starting a demanding task now?
    func shouldSuggestDemandingTask() -> Bool {
        currentWindow == .peak || currentWindow == .ramping
    }

    /// Get time remaining in current phase
    var timeRemainingInPhase: TimeInterval? {
        guard let start = windowStartTime else { return nil }

        let now = Date()
        let elapsed = now.timeIntervalSince(start)

        switch currentWindow {
        case .ramping:
            return max(0, 30 * 60 - elapsed)
        case .peak:
            return max(0, TimeInterval(config.peakDurationMinutes * 60) - elapsed)
        case .declining:
            return max(0, TimeInterval(config.totalDurationMinutes * 60) - elapsed)
        default:
            return nil
        }
    }

    /// Get formatted time remaining
    var timeRemainingString: String? {
        guard let remaining = timeRemainingInPhase else { return nil }

        let minutes = Int(remaining / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Reminders

    private func scheduleWindowEndReminder() {
        guard let peakEnd = expectedPeakEnd else { return }

        let reminderTime = peakEnd.addingTimeInterval(-TimeInterval(config.reminderMinutesBefore * 60))

        // Only schedule if in the future
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Window Update"
        content.body = "Your peak focus period ends in \(config.reminderMinutesBefore) minutes. Wrap up demanding tasks."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderTime.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "medication_window_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelWindowReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["medication_window_reminder"]
        )
    }

    // MARK: - Statistics

    var averagePeakDuration: TimeInterval? {
        guard !windowHistory.isEmpty else { return nil }
        let total = windowHistory.reduce(0) { $0 + $1.peakDuration }
        return total / Double(windowHistory.count)
    }

    var averageProductivity: Double? {
        let rated = windowHistory.compactMap { $0.productivity?.rawValue }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    // MARK: - Timer

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWindowState()
            }
        }
    }

    // MARK: - Persistence

    private func saveState() {
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        UserDefaults.standard.set(windowStartTime, forKey: "medication_window_start")

        if let configData = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(configData, forKey: configKey)
        }

        if let historyData = try? JSONEncoder().encode(windowHistory) {
            UserDefaults.standard.set(historyData, forKey: historyKey)
        }
    }

    private func loadState() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        windowStartTime = UserDefaults.standard.object(forKey: "medication_window_start") as? Date

        if let configData = UserDefaults.standard.data(forKey: configKey),
           let savedConfig = try? JSONDecoder().decode(WindowConfig.self, from: configData) {
            config = savedConfig
        }

        if let historyData = UserDefaults.standard.data(forKey: historyKey),
           let savedHistory = try? JSONDecoder().decode([WindowLog].self, from: historyData) {
            windowHistory = savedHistory
        }

        // Restore window state
        if windowStartTime != nil {
            updateWindowState()
        }
    }
}
