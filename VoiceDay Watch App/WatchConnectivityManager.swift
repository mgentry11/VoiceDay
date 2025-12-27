import Foundation
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

struct WatchTask: Identifiable, Codable {
    let id: UUID
    let title: String
    let deadline: Date?
    let priority: String
    let isCompleted: Bool
}

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var tasks: [WatchTask] = []
    @Published var isConnected = false

    private var session: WCSession?

    override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("❌ WatchConnectivity not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("⌚ Watch Connectivity activating...")
    }

    // MARK: - Send to iPhone

    func sendTaskCompleted(taskId: String) {
        guard let session = session, session.isReachable else {
            // Queue for later if not reachable
            try? session?.updateApplicationContext(["completedTaskId": taskId])
            return
        }

        session.sendMessage(
            ["action": "taskCompleted", "taskId": taskId],
            replyHandler: nil
        ) { error in
            print("❌ Failed to send task completion: \(error)")
        }

        // Remove from local list
        tasks.removeAll { $0.id.uuidString == taskId }
    }

    func sendSnooze(minutes: Int, userInfo: [AnyHashable: Any]) {
        guard let session = session else { return }

        var message: [String: Any] = [
            "action": "snooze",
            "minutes": minutes
        ]

        if let taskId = userInfo["taskId"] as? String {
            message["taskId"] = taskId
        }
        if let title = userInfo["taskTitle"] as? String {
            message["title"] = title
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    func sendNewTask(text: String) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "action": "newTask",
            "text": text
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    func requestSync() {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(["action": "syncRequest"], replyHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isConnected = activationState == .activated
            print("⌚ Watch session activated: \(activationState.rawValue)")

            if isConnected {
                requestSync()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⌚ Session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⌚ Session deactivated")
        session.activate()
    }
    #endif

    // Receive messages from iPhone
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleMessage(applicationContext)
        }
    }

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        if let action = message["action"] as? String {
            switch action {
            case "syncTasks":
                if let tasksData = message["tasks"] as? Data {
                    do {
                        let decodedTasks = try JSONDecoder().decode([WatchTask].self, from: tasksData)
                        self.tasks = decodedTasks.filter { !$0.isCompleted }
                        print("⌚ Received \(tasks.count) tasks from iPhone")
                    } catch {
                        print("❌ Failed to decode tasks: \(error)")
                    }
                }

            case "newTask":
                if let taskData = message["task"] as? Data,
                   let task = try? JSONDecoder().decode(WatchTask.self, from: taskData) {
                    tasks.append(task)
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.notification)
                    #endif
                }

            case "taskRemoved":
                if let taskId = message["taskId"] as? String {
                    tasks.removeAll { $0.id.uuidString == taskId }
                }

            case "speak":
                if let text = message["text"] as? String {
                    WatchSpeechService.shared.speak(text)
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.notification)
                    #endif
                }

            default:
                break
            }
        }
    }
}
