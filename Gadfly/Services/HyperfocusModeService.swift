import SwiftUI
import Combine

/// Manages Hyperfocus Mode - pauses all self-care reminders when the user is in deep focus
/// Tracks duration and changes visual indicators to remind users to take breaks
class HyperfocusModeService: ObservableObject {
    static let shared = HyperfocusModeService()

    // MARK: - Published Properties

    @Published var isActive: Bool = false
    @Published var startTime: Date?
    @Published var elapsedSeconds: Int = 0
    @Published var currentStage: HyperfocusStage = .none

    // MARK: - Private Properties

    private var timer: Timer?
    private let userDefaults = UserDefaults.standard

    private let startTimeKey = "hyperfocusStartTime"
    private let isActiveKey = "hyperfocusModeActive"

    // MARK: - Hyperfocus Stages (with color progression)

    enum HyperfocusStage: String {
        case none = "none"
        case stage1 = "purple"  // 0-30 min - Purple
        case stage2 = "blue"    // 30-60 min - Blue
        case stage3 = "teal"    // 60-90 min - Teal
        case stage4 = "amber"   // 90-120 min - Amber
        case stage5 = "red"     // 120+ min - Red (warning!)

        var color: Color {
            switch self {
            case .none: return .purple
            case .stage1: return .purple
            case .stage2: return .blue
            case .stage3: return .teal
            case .stage4: return .orange
            case .stage5: return .red
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .none, .stage1: return [Color(hex: "#7c3aed"), Color(hex: "#9333ea")]
            case .stage2: return [Color(hex: "#2563eb"), Color(hex: "#3b82f6")]
            case .stage3: return [Color(hex: "#0d9488"), Color(hex: "#14b8a6")]
            case .stage4: return [Color(hex: "#d97706"), Color(hex: "#f59e0b")]
            case .stage5: return [Color(hex: "#dc2626"), Color(hex: "#ef4444")]
            }
        }

        var message: String {
            switch self {
            case .none, .stage1: return "Focus time started"
            case .stage2: return "30 minutes of focus!"
            case .stage3: return "1 hour focused - amazing!"
            case .stage4: return "90 min! Consider a break soon"
            case .stage5: return "2+ hours - please take a break!"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Restore state if app was closed during hyperfocus
        restoreState()
    }

    // MARK: - Public Methods

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    func activate() {
        isActive = true
        startTime = Date()
        elapsedSeconds = 0
        currentStage = .stage1

        // Save to UserDefaults for persistence
        userDefaults.set(startTime?.timeIntervalSince1970, forKey: startTimeKey)
        userDefaults.set(true, forKey: isActiveKey)

        // Start timer
        startTimer()

        // Pause self-care notifications
        SelfCareService.shared.pauseReminders()

        // Speak feedback
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage("Hyperfocus mode activated. I'll track your focus time.")
        }
    }

    func deactivate() {
        let duration = elapsedSeconds

        isActive = false
        stopTimer()

        // Clear saved state
        userDefaults.removeObject(forKey: startTimeKey)
        userDefaults.set(false, forKey: isActiveKey)

        // Resume self-care
        SelfCareService.shared.resumeReminders()

        // Provide summary
        let durationText = formatDuration(seconds: duration)
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage("Great session! You focused for \(durationText).")
        }

        // Reset
        startTime = nil
        elapsedSeconds = 0
        currentStage = .none
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedTime() {
        guard let start = startTime else { return }

        elapsedSeconds = Int(Date().timeIntervalSince(start))
        let minutes = elapsedSeconds / 60

        // Update stage based on duration
        let newStage = stageFor(minutes: minutes)

        // Check for stage transitions (to provide audio feedback)
        if newStage != currentStage {
            currentStage = newStage
            handleStageTransition(newStage, minutes: minutes)
        }
    }

    private func stageFor(minutes: Int) -> HyperfocusStage {
        switch minutes {
        case 0..<30: return .stage1
        case 30..<60: return .stage2
        case 60..<90: return .stage3
        case 90..<120: return .stage4
        default: return .stage5
        }
    }

    private func handleStageTransition(_ stage: HyperfocusStage, minutes: Int) {
        var message: String?

        switch stage {
        case .stage2:
            // Quiet acknowledgment at 30 min
            break
        case .stage3:
            message = "One hour of focus! You're doing great. Consider a quick stretch soon."
        case .stage4:
            message = "90 minutes of hyperfocus! That's amazing, but your brain and body need a break soon."
        case .stage5:
            message = "Two hours focused! Impressive, but your eyes, back, and brain are asking for a break."
            // At 2+ hours, remind every 30 minutes
            if minutes > 120 && minutes % 30 == 0 {
                message = "\(minutes) minutes straight! Even the best brains need rest."
            }
        default:
            break
        }

        if let msg = message {
            Task { @MainActor in
                await AppDelegate.shared?.speakMessage(msg)
            }
        }
    }

    // MARK: - State Persistence

    private func restoreState() {
        let wasActive = userDefaults.bool(forKey: isActiveKey)

        if wasActive, let savedTimestamp = userDefaults.object(forKey: startTimeKey) as? TimeInterval {
            startTime = Date(timeIntervalSince1970: savedTimestamp)
            isActive = true

            // Calculate elapsed time
            elapsedSeconds = Int(Date().timeIntervalSince(startTime!))
            currentStage = stageFor(minutes: elapsedSeconds / 60)

            // Restart timer
            startTimer()
        }
    }

    // MARK: - Formatting

    func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }

    var timerDisplayString: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
