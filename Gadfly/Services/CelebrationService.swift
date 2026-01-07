import SwiftUI
import AVFoundation
import CoreHaptics

// MARK: - Celebration Service

/// Multi-sensory celebration feedback for task completions
/// Provides dopamine-boosting rewards for ADHD brains
@MainActor
class CelebrationService: ObservableObject {
    static let shared = CelebrationService()

    // MARK: - Published State

    @Published var showConfetti = false
    @Published var celebrationMessage = ""
    @Published var pointsEarned: Int = 0
    @Published var showPointsBadge = false

    // MARK: - Settings

    var celebrationSoundsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "celebration_sounds_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "celebration_sounds_enabled") }
    }

    var celebrationHapticsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "celebration_haptics_enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "celebration_haptics_enabled") }
    }

    var celebrationAnimationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "celebration_animations_enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "celebration_animations_enabled") }
    }

    // MARK: - Private Properties

    private var hapticEngine: CHHapticEngine?
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Celebration Levels

    enum CelebrationLevel {
        case micro      // Subtask, small item, low priority
        case standard   // Normal task completion
        case major      // High priority or goal milestone
        case epic       // Goal completed, streak milestone, big achievement

        var hapticIntensity: Float {
            switch self {
            case .micro: return 0.4
            case .standard: return 0.6
            case .major: return 0.8
            case .epic: return 1.0
            }
        }

        var confettiCount: Int {
            switch self {
            case .micro: return 0
            case .standard: return 0
            case .major: return 30
            case .epic: return 80
            }
        }

        var soundName: String? {
            switch self {
            case .micro: return nil  // No sound for micro
            case .standard: return "completion_ding"
            case .major: return "completion_chime"
            case .epic: return "completion_fanfare"
            }
        }
    }

    // MARK: - Initialization

    init() {
        prepareHaptics()
    }

    // MARK: - Main Celebration Method

    /// Trigger a celebration for completing a task
    /// - Parameters:
    ///   - level: The intensity of the celebration
    ///   - taskTitle: The task that was completed
    ///   - priority: The task priority (affects points)
    ///   - points: Points earned (0 if rewards system not active)
    func celebrate(
        level: CelebrationLevel,
        taskTitle: String,
        priority: ItemPriority = .medium,
        points: Int = 0
    ) {
        // Store points for display
        self.pointsEarned = points

        // Haptic feedback (instant gratification)
        if celebrationHapticsEnabled {
            playHaptic(for: level)
        }

        // Sound feedback
        if celebrationSoundsEnabled {
            playSound(for: level)
        }

        // Visual feedback
        if celebrationAnimationsEnabled {
            triggerVisual(for: level, points: points)
        }

        let intensity: RecentlySpokenService.CelebrationIntensity
        switch level {
        case .micro: intensity = .micro
        case .standard: intensity = .standard
        case .major: intensity = .major
        case .epic: intensity = .epic
        }
        celebrationMessage = RecentlySpokenService.shared.getCelebration(intensity: intensity)

        // Auto-hide confetti after delay
        if level == .major || level == .epic {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                withAnimation {
                    showConfetti = false
                }
            }
        }

        // Auto-hide points badge
        if points > 0 {
            showPointsBadge = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                withAnimation {
                    showPointsBadge = false
                }
            }
        }
    }

    /// Determine celebration level based on task properties
    func levelFor(priority: ItemPriority, isGoalMilestone: Bool = false, isGoalComplete: Bool = false) -> CelebrationLevel {
        if isGoalComplete {
            return .epic
        }
        if isGoalMilestone {
            return .major
        }
        switch priority {
        case .high:
            return .major
        case .medium:
            return .standard
        case .low:
            return .micro
        }
    }

    // MARK: - Haptic Feedback

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            // Restart engine if it stops
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                Task { @MainActor in
                    try? self?.hapticEngine?.start()
                }
            }

            hapticEngine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.hapticEngine?.start()
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }

    private func playHaptic(for level: CelebrationLevel) {
        // Fallback to basic haptics if CoreHaptics unavailable
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            playBasicHaptic(for: level)
            return
        }

        do {
            let pattern = try hapticPattern(for: level)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
            playBasicHaptic(for: level)
        }
    }

    private func hapticPattern(for level: CelebrationLevel) throws -> CHHapticPattern {
        switch level {
        case .micro:
            // Quick light tap
            return try CHHapticPattern(events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                )
            ], parameters: [])

        case .standard:
            // Satisfying double-tap
            return try CHHapticPattern(events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0.1
                )
            ], parameters: [])

        case .major:
            // Rising crescendo
            return try CHHapticPattern(events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.08
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.16
                )
            ], parameters: [])

        case .epic:
            // "Ta-da-DAH!" celebration pattern
            var events: [CHHapticEvent] = []

            // Opening burst
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0
            ))

            // Build up
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0.12
            ))

            // Final big hit
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.24,
                duration: 0.3
            ))

            // Celebratory ripples
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.6 - Double(i) * 0.15)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.6 + Double(i) * 0.12
                ))
            }

            return try CHHapticPattern(events: events, parameters: [])
        }
    }

    private func playBasicHaptic(for level: CelebrationLevel) {
        let generator = UINotificationFeedbackGenerator()
        switch level {
        case .micro:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()
        case .standard:
            generator.notificationOccurred(.success)
        case .major, .epic:
            generator.notificationOccurred(.success)
            // Double tap for emphasis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.notificationOccurred(.success)
            }
        }
    }

    // MARK: - Sound Feedback

    private func playSound(for level: CelebrationLevel) {
        guard let soundName = level.soundName else { return }

        // Try to play bundled sound
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = 0.5
                audioPlayer?.play()
            } catch {
                print("Failed to play sound: \(error)")
                playSystemSound(for: level)
            }
        } else {
            // Fallback to system sounds
            playSystemSound(for: level)
        }
    }

    private func playSystemSound(for level: CelebrationLevel) {
        switch level {
        case .micro:
            break // No sound for micro
        case .standard:
            AudioServicesPlaySystemSound(1057) // Soft ping
        case .major:
            AudioServicesPlaySystemSound(1025) // Success sound
        case .epic:
            AudioServicesPlaySystemSound(1025) // Success sound
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AudioServicesPlaySystemSound(1026) // Another success
            }
        }
    }

    // MARK: - Visual Feedback

    private func triggerVisual(for level: CelebrationLevel, points: Int) {
        switch level {
        case .micro, .standard:
            // Just the points badge, no confetti
            break
        case .major, .epic:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension CelebrationService {
    func testCelebration(_ level: CelebrationLevel) {
        celebrate(level: level, taskTitle: "Test Task", priority: .medium, points: 15)
    }
}
#endif
