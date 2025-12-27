import UIKit
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static var shared: AppDelegate?
    private var elevenLabsService: ElevenLabsService?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppDelegate.shared = self
        UNUserNotificationCenter.current().delegate = self
        elevenLabsService = ElevenLabsService()

        // NUCLEAR FIX: Clear any stale custom voice ID that might be causing Syn voice
        // This runs ONCE on startup to fix the persistent Syn voice issue
        clearStaleCustomVoice()

        // Configure audio session for speaker output IMMEDIATELY at launch
        configureAudioForSpeaker()

        // Clear any stale notifications that might have old personality
        // This ensures clean slate on each launch
        Task { @MainActor in
            // Cancel all pending notifications - they'll be rescheduled with current personality
            NotificationService.shared.cancelAllNotifications()
            NotificationService.shared.refillFocusCheckIns()
        }

        return true
    }

    /// Clear any stale custom voice ID - fixes Syn voice issue
    private func clearStaleCustomVoice() {
        let customVoiceId = UserDefaults.standard.string(forKey: "custom_voice_id")
        if customVoiceId != nil {
            print("⚠️ CLEARING STALE CUSTOM VOICE: \(customVoiceId ?? "nil")")
            UserDefaults.standard.removeObject(forKey: "custom_voice_id")
            UserDefaults.standard.removeObject(forKey: "custom_voice_name")
            UserDefaults.standard.synchronize()

            // Also clear from VoiceCloningService
            Task { @MainActor in
                VoiceCloningService.shared.clearCustomVoice()
            }
        }
    }

    /// Configure audio session to always use speaker - call at app launch and before any speech
    func configureAudioForSpeaker() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.overrideOutputAudioPort(.speaker)
            print("🔊 Audio configured for speaker output")
        } catch {
            print("❌ Failed to configure audio for speaker: \(error)")
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Ensure audio is configured for speaker every time app becomes active
        configureAudioForSpeaker()

        // Refill focus check-ins when app becomes active
        Task { @MainActor in
            NotificationService.shared.refillFocusCheckIns()
        }
    }

    // Handle notification when app is in foreground - SPEAK IT!
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let message = content.body
        let userInfo = content.userInfo

        // Speak the notification
        Task { @MainActor in
            await speakMessage(message)

            // Log to conversation history
            logNagToConversation(message: message, userInfo: userInfo, identifier: notification.request.identifier)
        }

        // Auto-schedule next nag (unless it's a one-time event)
        autoScheduleNextNag(from: userInfo, identifier: notification.request.identifier)

        // Show banner only - no sound since we're speaking it
        completionHandler([.banner])
    }

    // Auto-schedule next nag to keep nagging until user marks as done
    private func autoScheduleNextNag(from userInfo: [AnyHashable: Any], identifier: String) {
        // Skip if break mode is active
        if NotificationService.shared.isBreakModeActive() {
            print("⏸️ Break mode active - skipping nag rescheduling")
            return
        }

        // Handle focus check-ins - refill the queue
        if identifier.hasPrefix("focus-") {
            Task { @MainActor in
                NotificationService.shared.refillFocusCheckIns()
            }
            return
        }

        // Don't reschedule test or daily notifications
        if identifier.hasPrefix("test-") || identifier.hasPrefix("daily-") {
            return
        }

        // Get the nag interval from settings or userInfo
        let nagInterval = (userInfo["repeatInterval"] as? Int) ??
                         UserDefaults.standard.integer(forKey: "nag_interval_minutes")

        // Default to 5 minutes if not set
        let interval = nagInterval > 0 ? nagInterval : 5

        let title = (userInfo["taskTitle"] as? String) ??
                    (userInfo["eventTitle"] as? String) ??
                    (userInfo["title"] as? String) ?? "Task"
        let type = userInfo["type"] as? String ?? "task"
        let originalId = (userInfo["taskId"] as? String) ??
                         (userInfo["eventId"] as? String) ??
                         (userInfo["originalId"] as? String) ?? UUID().uuidString

        Task { @MainActor in
            NotificationService.shared.scheduleNagReminder(
                originalId: originalId,
                title: title,
                type: type,
                delayMinutes: interval
            )
            print("🔔 Auto-scheduled next nag for '\(title)' in \(interval) minutes")
        }
    }

    // Speak a message using ElevenLabs or fallback to system voice
    @MainActor
    func speakMessage(_ message: String) async {
        // Try to get ElevenLabs credentials from UserDefaults/Keychain
        let elevenLabsKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        let selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""

        // PRIORITY: Selected voice ALWAYS wins over custom voice
        // Only use ElevenLabs if we have API key AND a selected voice
        if !elevenLabsKey.isEmpty && !selectedVoiceId.isEmpty {
            print("🎤 AppDelegate: Using selected voice: \(selectedVoiceId)")
            do {
                try await elevenLabsService?.speakWithBestVoice(message, apiKey: elevenLabsKey, selectedVoiceId: selectedVoiceId)
            } catch {
                print("❌ ElevenLabs failed: \(error), falling back to system voice")
                speakWithSystemVoice(message)
            }
        } else if !elevenLabsKey.isEmpty, let customVoiceId = VoiceCloningService.shared.customVoiceId {
            // Only use custom voice if NO selected voice exists
            print("🎤 AppDelegate: Using custom voice (no selection): \(customVoiceId)")
            do {
                try await elevenLabsService?.speakWithBestVoice(message, apiKey: elevenLabsKey, selectedVoiceId: "")
            } catch {
                speakWithSystemVoice(message)
            }
        } else {
            // Use system voice
            print("🎤 AppDelegate: Using system voice")
            speakWithSystemVoice(message)
        }
    }

    private func speakWithSystemVoice(_ message: String) {
        // Use the shared SpeechService queue to prevent overlapping speech
        SpeechService.shared.queueSpeech(message)
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // Check if this is a break mode end notification
        if let type = userInfo["type"] as? String, type == "break_mode_end" {
            // Clear break mode state
            UserDefaults.standard.set(false, forKey: "break_mode_enabled")
            UserDefaults.standard.removeObject(forKey: "break_mode_end_time")
            print("⏸️ Break mode ended via notification")

            Task { @MainActor in
                // Get personality-aware break-end message
                let message = getBreakEndMessage()
                await speakMessage(message)
            }

            completionHandler()
            return
        }

        switch actionIdentifier {
        case "DONE_ACTION":
            // Mark as done - cancel any pending nag reminders and celebrate!
            let taskTitle = (userInfo["taskTitle"] as? String) ??
                           (userInfo["eventTitle"] as? String) ??
                           (userInfo["title"] as? String) ?? "that task"

            if let taskId = userInfo["taskId"] as? String {
                Task { @MainActor in
                    NotificationService.shared.cancelAllRemindersForTask(taskId: taskId)
                    // Celebrate!
                    let celebration = NotificationService.shared.getCelebrationMessage(for: taskTitle)
                    ConversationService.shared.addAssistantMessage(celebration)
                    await speakMessage(celebration)
                }
            }
            if let eventId = userInfo["eventId"] as? String {
                Task { @MainActor in
                    NotificationService.shared.cancelAllRemindersForEvent(eventId: eventId)
                    // Celebrate!
                    let celebration = NotificationService.shared.getCelebrationMessage(for: taskTitle)
                    ConversationService.shared.addAssistantMessage(celebration)
                    await speakMessage(celebration)
                }
            }

        case "SNOOZE_5_ACTION":
            scheduleNag(from: userInfo, delayMinutes: 5)

        case "SNOOZE_15_ACTION":
            scheduleNag(from: userInfo, delayMinutes: 15)

        case "SNOOZE_30_ACTION":
            scheduleNag(from: userInfo, delayMinutes: 30)

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - schedule next nag (they didn't mark done)
            let identifier = response.notification.request.identifier
            if !identifier.hasPrefix("focus-") && !identifier.hasPrefix("test-") && !identifier.hasPrefix("daily-") {
                let nagInterval = (userInfo["repeatInterval"] as? Int) ??
                                 UserDefaults.standard.integer(forKey: "nag_interval_minutes")
                let interval = nagInterval > 0 ? nagInterval : 5
                scheduleNag(from: userInfo, delayMinutes: interval)
            }

        case UNNotificationDismissActionIdentifier:
            // User dismissed without acting - still schedule next nag
            let identifier = response.notification.request.identifier
            if !identifier.hasPrefix("focus-") && !identifier.hasPrefix("test-") && !identifier.hasPrefix("daily-") {
                let nagInterval = (userInfo["repeatInterval"] as? Int) ??
                                 UserDefaults.standard.integer(forKey: "nag_interval_minutes")
                let interval = nagInterval > 0 ? nagInterval : 5
                scheduleNag(from: userInfo, delayMinutes: interval)
            }

        default:
            break
        }

        completionHandler()
    }

    // Log nag to conversation history
    @MainActor
    private func logNagToConversation(message: String, userInfo: [AnyHashable: Any], identifier: String) {
        // Get task title for context
        let taskTitle = (userInfo["taskTitle"] as? String) ??
                       (userInfo["eventTitle"] as? String) ??
                       (userInfo["title"] as? String) ?? "Task"

        if identifier.hasPrefix("focus-") {
            ConversationService.shared.addFocusCheckIn(message)
        } else if identifier.hasPrefix("test-") {
            // Don't log test notifications
        } else {
            ConversationService.shared.addNagMessage(message, forTask: taskTitle)
        }
    }

    private func scheduleNag(from userInfo: [AnyHashable: Any], delayMinutes: Int) {
        let title = (userInfo["taskTitle"] as? String) ??
                    (userInfo["eventTitle"] as? String) ??
                    (userInfo["title"] as? String) ?? "Task"
        let type = userInfo["type"] as? String ?? "task"
        let originalId = (userInfo["taskId"] as? String) ??
                         (userInfo["eventId"] as? String) ??
                         (userInfo["originalId"] as? String) ?? UUID().uuidString

        Task { @MainActor in
            NotificationService.shared.scheduleNagReminder(
                originalId: originalId,
                title: title,
                type: type,
                delayMinutes: delayMinutes
            )
        }
    }

    /// Get personality-aware break-end message
    private func getBreakEndMessage() -> String {
        let savedPersonality = UserDefaults.standard.string(forKey: "selected_personality") ?? ""
        let personality = BotPersonality(rawValue: savedPersonality) ?? .pemberton

        switch personality {
        case .pemberton:
            return "Your break is over. I return, ready to nag you about your tasks."
        case .sergent:
            return "BREAK TIME OVER! Back to work, soldier! No excuses!"
        case .cheerleader:
            return "Break's over! Ready to crush more goals? I know you are! Let's go!"
        case .butler:
            return "If I may, your break has concluded. Shall we resume our endeavors?"
        case .coach:
            return "Halftime's over, champ! Back in the game! Let's finish strong!"
        case .zen:
            return "Your rest has been honored. When you are ready, we may continue our journey."
        case .parent:
            return "Hey sweetie, break's over. Ready to get back to it? No rush."
        case .bestie:
            return "Break's done! Ready to get back at it? I'm here if you need me."
        case .robot:
            return "Break concluded. Resuming task tracking."
        case .therapist:
            return "I hope your break was restorative. Ready to continue when you are."
        case .hypeFriend:
            return "BREAK'S OVER! Time to get back to being AMAZING! Let's GOOO!"
        case .chillBuddy:
            return "Hey... break's up. No rush though. We can ease back into it."
        case .snarky:
            return "Oh look, break's over. Back to pretending to be productive?"
        case .gamer:
            return "Break ended! Ready to jump back into the quest? XP awaits!"
        case .tiredParent:
            return "Break's over. We're both tired, but we've got this. Probably."
        }
    }
}
