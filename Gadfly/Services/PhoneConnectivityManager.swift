import Foundation
import WatchConnectivity

@MainActor
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable = false
    @Published var isWatchPaired = false

    private var session: WCSession?

    override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("📱 WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 Phone Connectivity activating...")
    }

    // MARK: - Send to Watch

    /// Send current tasks to Watch
    func syncTasks(_ tasks: [ParsedTask]) {
        guard let session = session, session.isPaired else { return }

        let watchTasks = tasks.map { task in
            WatchTaskDTO(
                id: task.id,
                title: task.title,
                deadline: task.deadline,
                priority: task.priority.rawValue,
                isCompleted: task.isCompleted
            )
        }

        do {
            let data = try JSONEncoder().encode(watchTasks)
            let message: [String: Any] = [
                "action": "syncTasks",
                "tasks": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil)
                print("⌚ Sent \(watchTasks.count) tasks to Watch")
            } else {
                try session.updateApplicationContext(message)
                print("⌚ Queued \(watchTasks.count) tasks for Watch")
            }
        } catch {
            print("❌ Failed to encode tasks for Watch: \(error)")
        }
    }

    /// Send a spoken message to the Watch
    func speakOnWatch(_ text: String) {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(
            ["action": "speak", "text": text],
            replyHandler: nil
        )
        print("⌚ Sent speech to Watch: \(text.prefix(50))...")
    }

    /// Notify Watch that a task was removed
    func notifyTaskRemoved(taskId: String) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "action": "taskRemoved",
            "taskId": taskId
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    /// Send a new task to Watch
    func sendTaskToWatch(_ task: ParsedTask) {
        guard let session = session else { return }

        let watchTask = WatchTaskDTO(
            id: task.id,
            title: task.title,
            deadline: task.deadline,
            priority: task.priority.rawValue,
            isCompleted: task.isCompleted
        )

        do {
            let data = try JSONEncoder().encode(watchTask)
            let message: [String: Any] = [
                "action": "newTask",
                "task": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil)
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("❌ Failed to send task to Watch: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            print("📱 Phone session activated: \(activationState.rawValue)")
            isWatchPaired = session.isPaired
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 Phone session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("📱 Phone session deactivated")
        // Reactivate for switching watches
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
        }
    }

    // Receive messages from Watch
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleWatchMessage(applicationContext)
        }
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "taskCompleted":
            if let taskId = message["taskId"] as? String {
                print("⌚ Watch marked task complete: \(taskId)")
                // Post notification for the app to handle
                NotificationCenter.default.post(
                    name: .watchTaskCompleted,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }

        case "snooze":
            if let minutes = message["minutes"] as? Int,
               let taskId = message["taskId"] as? String,
               let title = message["title"] as? String {
                print("⌚ Watch snoozed task: \(title) for \(minutes) min")
                NotificationService.shared.scheduleNagReminder(
                    originalId: taskId,
                    title: title,
                    type: "task",
                    delayMinutes: minutes
                )
            }

        case "newTask":
            if let text = message["text"] as? String {
                print("⌚ Watch created new task: \(text)")
                // Post notification for the app to process with AI
                NotificationCenter.default.post(
                    name: .watchNewTask,
                    object: nil,
                    userInfo: ["text": text]
                )
            }

        case "syncRequest":
            print("⌚ Watch requested sync")
            // Post notification for app to send current tasks
            NotificationCenter.default.post(
                name: .watchSyncRequested,
                object: nil
            )

        default:
            break
        }
    }
}

// MARK: - DTO for Watch

struct WatchTaskDTO: Codable {
    let id: UUID
    let title: String
    let deadline: Date?
    let priority: String
    let isCompleted: Bool
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchTaskCompleted = Notification.Name("watchTaskCompleted")
    static let watchNewTask = Notification.Name("watchNewTask")
    static let watchSyncRequested = Notification.Name("watchSyncRequested")
}
