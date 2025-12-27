import Foundation
import SwiftUI

// MARK: - Preset Modes

/// Pre-configured app modes that replace complex individual settings
/// ADHD users get "just works" configurations instead of decision paralysis
enum PresetMode: String, CaseIterable, Codable, Identifiable {
    case focusFirst = "focus_first"
    case stayOnMe = "stay_on_me"
    case gentleFlow = "gentle_flow"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focusFirst: return "Focus First"
        case .stayOnMe: return "Stay On Me"
        case .gentleFlow: return "Gentle Flow"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .focusFirst: return "scope"
        case .stayOnMe: return "bell.fill"
        case .gentleFlow: return "leaf.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .focusFirst: return .orange
        case .stayOnMe: return .blue
        case .gentleFlow: return .green
        case .custom: return .purple
        }
    }

    var description: String {
        switch self {
        case .focusFirst:
            return "Aggressive reminders for maximum focus. Frequent check-ins, celebration sounds ON, minimal breaks."
        case .stayOnMe:
            return "Balanced mode. Regular reminders, hourly check-ins, gentle but persistent nudges."
        case .gentleFlow:
            return "Minimal interruptions. Soft reminders, no sounds, extra patient with timing."
        case .custom:
            return "Full control over individual settings. For power users who know what works for them."
        }
    }

    var shortDescription: String {
        switch self {
        case .focusFirst: return "Maximum focus"
        case .stayOnMe: return "Balanced nudges"
        case .gentleFlow: return "Minimal interruptions"
        case .custom: return "Your settings"
        }
    }

    // Best for scenarios
    var bestFor: [String] {
        switch self {
        case .focusFirst:
            return ["Deep work sessions", "Tight deadlines", "High-priority tasks"]
        case .stayOnMe:
            return ["Regular workdays", "Mixed task types", "General productivity"]
        case .gentleFlow:
            return ["Low energy days", "Creative work", "When feeling overwhelmed"]
        case .custom:
            return ["Specific personal preferences", "Testing what works"]
        }
    }
}

// MARK: - Preset Configuration

struct PresetConfiguration {
    // Notification settings
    let nagIntervalMinutes: Int
    let focusCheckInMinutes: Int
    let focusGracePeriodMinutes: Int
    let timeAwayThresholdMinutes: Int
    let focusTimeAwayThresholdMinutes: Int
    let idleThresholdMinutes: Int

    // Celebration settings
    let celebrationSoundsEnabled: Bool
    let celebrationHapticsEnabled: Bool
    let celebrationAnimationsEnabled: Bool

    // Check-in settings
    let dailyCheckInsEnabled: Bool
    let morningBriefingEnabled: Bool

    // Focus settings
    let keepScreenOn: Bool

    static func configuration(for mode: PresetMode) -> PresetConfiguration {
        switch mode {
        case .focusFirst:
            return PresetConfiguration(
                nagIntervalMinutes: 5,
                focusCheckInMinutes: 5,
                focusGracePeriodMinutes: 2,
                timeAwayThresholdMinutes: 3,
                focusTimeAwayThresholdMinutes: 1,
                idleThresholdMinutes: 3,
                celebrationSoundsEnabled: true,
                celebrationHapticsEnabled: true,
                celebrationAnimationsEnabled: true,
                dailyCheckInsEnabled: true,
                morningBriefingEnabled: true,
                keepScreenOn: true
            )

        case .stayOnMe:
            return PresetConfiguration(
                nagIntervalMinutes: 15,
                focusCheckInMinutes: 15,
                focusGracePeriodMinutes: 5,
                timeAwayThresholdMinutes: 10,
                focusTimeAwayThresholdMinutes: 3,
                idleThresholdMinutes: 10,
                celebrationSoundsEnabled: false,
                celebrationHapticsEnabled: true,
                celebrationAnimationsEnabled: true,
                dailyCheckInsEnabled: true,
                morningBriefingEnabled: true,
                keepScreenOn: true
            )

        case .gentleFlow:
            return PresetConfiguration(
                nagIntervalMinutes: 30,
                focusCheckInMinutes: 30,
                focusGracePeriodMinutes: 15,
                timeAwayThresholdMinutes: 30,
                focusTimeAwayThresholdMinutes: 10,
                idleThresholdMinutes: 9999, // Never
                celebrationSoundsEnabled: false,
                celebrationHapticsEnabled: true,
                celebrationAnimationsEnabled: false,
                dailyCheckInsEnabled: false,
                morningBriefingEnabled: false,
                keepScreenOn: false
            )

        case .custom:
            // Returns marker values - actual settings are not overwritten
            return PresetConfiguration(
                nagIntervalMinutes: -1, // Signal to use current value
                focusCheckInMinutes: -1,
                focusGracePeriodMinutes: -1,
                timeAwayThresholdMinutes: -1,
                focusTimeAwayThresholdMinutes: -1,
                idleThresholdMinutes: -1,
                celebrationSoundsEnabled: true,  // Defaults, not applied for custom
                celebrationHapticsEnabled: true,
                celebrationAnimationsEnabled: true,
                dailyCheckInsEnabled: true,
                morningBriefingEnabled: true,
                keepScreenOn: true
            )
        }
    }
}

// MARK: - Preset Mode Service

@MainActor
class PresetModeService: ObservableObject {
    static let shared = PresetModeService()

    @Published var currentMode: PresetMode = .stayOnMe

    private let modeKey = "preset_mode"

    init() {
        loadMode()
    }

    func setMode(_ mode: PresetMode, appState: AppState) {
        currentMode = mode
        saveMode()

        // Apply configuration unless custom
        guard mode != .custom else { return }

        let config = PresetConfiguration.configuration(for: mode)
        applyConfiguration(config, to: appState)

        print("📱 Applied preset mode: \(mode.displayName)")
    }

    private func applyConfiguration(_ config: PresetConfiguration, to appState: AppState) {
        // Skip values of -1 (custom mode marker)
        if config.nagIntervalMinutes > 0 {
            appState.nagIntervalMinutes = config.nagIntervalMinutes
        }
        if config.focusCheckInMinutes > 0 {
            appState.focusCheckInMinutes = config.focusCheckInMinutes
        }
        if config.focusGracePeriodMinutes > 0 {
            appState.focusGracePeriodMinutes = config.focusGracePeriodMinutes
        }
        if config.timeAwayThresholdMinutes > 0 {
            appState.timeAwayThresholdMinutes = config.timeAwayThresholdMinutes
        }
        if config.focusTimeAwayThresholdMinutes > 0 {
            appState.focusTimeAwayThresholdMinutes = config.focusTimeAwayThresholdMinutes
        }
        if config.idleThresholdMinutes > 0 {
            appState.idleThresholdMinutes = config.idleThresholdMinutes
        }

        appState.dailyCheckInsEnabled = config.dailyCheckInsEnabled
        appState.morningBriefingEnabled = config.morningBriefingEnabled
        appState.keepScreenOn = config.keepScreenOn

        // Celebration settings
        CelebrationService.shared.celebrationSoundsEnabled = config.celebrationSoundsEnabled
        CelebrationService.shared.celebrationHapticsEnabled = config.celebrationHapticsEnabled
        CelebrationService.shared.celebrationAnimationsEnabled = config.celebrationAnimationsEnabled
    }

    private func saveMode() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: modeKey)
    }

    private func loadMode() {
        if let modeRaw = UserDefaults.standard.string(forKey: modeKey),
           let mode = PresetMode(rawValue: modeRaw) {
            currentMode = mode
        }
    }
}
