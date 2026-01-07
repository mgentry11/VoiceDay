import SwiftUI
import UserNotifications
#if os(watchOS)
import WatchKit
#endif

#if os(watchOS)
@main
struct GadflyWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchConnectivityManager.shared)
        }
    }
}

class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        WatchConnectivityManager.shared.activate()

        // Request notification permissions
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    // Handle notification when app is in foreground - speak it!
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let message = content.body

        // Speak the notification
        WatchSpeechService.shared.speak(message)

        // Also show banner and play haptic
        WKInterfaceDevice.current().play(.notification)

        // Show banner only - no sound since we're speaking it
        completionHandler([.banner])
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "DONE_ACTION":
            // Mark as done - tell the phone
            if let taskId = userInfo["taskId"] as? String {
                WatchConnectivityManager.shared.sendTaskCompleted(taskId: taskId)
            }
            WKInterfaceDevice.current().play(.success)

        case "SNOOZE_5_ACTION":
            WatchConnectivityManager.shared.sendSnooze(minutes: 5, userInfo: userInfo)

        case "SNOOZE_15_ACTION":
            WatchConnectivityManager.shared.sendSnooze(minutes: 15, userInfo: userInfo)

        case UNNotificationDefaultActionIdentifier:
            // User tapped notification - open app
            break

        default:
            break
        }

        completionHandler()
    }
}
#endif
