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

        // NUCLEAR FIX: Always clear custom voice to prevent Syn voice taking over
        // Custom voice cloning feature is disabled - always use ElevenLabs library voices
        nukeCustomVoice()

        // Configure audio session for speaker output IMMEDIATELY at launch
        configureAudioForSpeaker()

        // CRITICAL: Do NOT cancel all notifications here - that permanently breaks task reminders!
        Task { @MainActor in
            DayStructureService.shared.scheduleCheckInNotifications()
            NotificationService.shared.refillFocusCheckIns()
        }

        return true
    }

    /// ALWAYS clear custom voice - prevents Syn voice from ever taking over
    /// Custom voice cloning feature is disabled in favor of ElevenLabs library voices
    private func nukeCustomVoice() {
        // Always clear - don't check if exists
        print("🔥 NUKING ALL CUSTOM VOICE DATA")

        // Clear from UserDefaults FIRST
        UserDefaults.standard.removeObject(forKey: "custom_voice_id")
        UserDefaults.standard.removeObject(forKey: "custom_voice_name")
        UserDefaults.standard.removeObject(forKey: "voice_recordings") // Also clear recordings
        UserDefaults.standard.synchronize()

        // Force a read to confirm it's cleared
        let checkId = UserDefaults.standard.string(forKey: "custom_voice_id")
        let checkName = UserDefaults.standard.string(forKey: "custom_voice_name")
        print("🔥 After clear - custom_voice_id: \(checkId ?? "nil"), custom_voice_name: \(checkName ?? "nil")")

        // Now access VoiceCloningService - its init will load nil from UserDefaults
        // But also force clear its properties just in case
        let service = VoiceCloningService.shared
        service.customVoiceId = nil
        service.customVoiceName = nil

        print("🔥 VoiceCloningService.customVoiceId: \(service.customVoiceId ?? "nil")")
        print("🔥 Custom voice completely nuked")
    }

    /// Configure audio session - use earbuds if connected, otherwise speaker
    func configureAudioForSpeaker() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Only force speaker if no external audio device connected
            let currentRoute = audioSession.currentRoute
            let hasExternalOutput = currentRoute.outputs.contains {
                $0.portType == .bluetoothA2DP ||
                $0.portType == .bluetoothHFP ||
                $0.portType == .headphones ||
                $0.portType == .bluetoothLE
            }
            if !hasExternalOutput {
                try audioSession.overrideOutputAudioPort(.speaker)
                print("🔊 Audio routed to SPEAKER")
            } else {
                print("🎧 Audio routed to EARBUDS/HEADPHONES")
            }
        } catch {
            print("❌ Failed to configure audio: \(error)")
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

    // Speak a message using ElevenLabs ONLY - NO system voice fallback
    @MainActor
    func speakMessage(_ message: String) async {
        let elevenLabsKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        let selectedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""

        print("🎤🎤🎤 AppDelegate.speakMessage")
        print("🎤🎤🎤 API Key: \(elevenLabsKey.prefix(10))...")
        print("🎤🎤🎤 Voice ID: \(selectedVoiceId.isEmpty ? "NONE - using Rachel" : selectedVoiceId)")

        guard !elevenLabsKey.isEmpty else {
            print("❌❌❌ NO API KEY - Cannot speak!")
            return
        }

        do {
            try await elevenLabsService?.speakWithBestVoice(message, apiKey: elevenLabsKey, selectedVoiceId: selectedVoiceId)
            print("🎤🎤🎤 AppDelegate: Speech complete!")
        } catch {
            print("❌❌❌ ElevenLabs FAILED: \(error)")
            // DO NOT fall back to system voice - that's the "Syn" voice!
        }
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
        case .sage:
            return "Your rest has honored the body. Now, the path of action awaits."
        case .rebel:
            return "Break's done. Time to get back to fighting the system. Let's go."
        case .trickster:
            return "Oh, you thought the break would last forever? Interesting theory."
        case .stoic:
            return "Rest complete. Return to your duties with renewed purpose."
        case .pirate:
            return "Shore leave is over, matey! Back to the ship! Adventure awaits!"
        case .witch:
            return "The break spell has lifted. Time to brew more productivity magic."
        }
    }
}
