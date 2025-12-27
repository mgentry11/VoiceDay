import SwiftUI
import Combine

/// End-of-Day Self-Check Service
/// Helps ADHD users confirm they know where important items are before ending their day
class SelfCheckService: ObservableObject {
    static let shared = SelfCheckService()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = true {
        didSet { saveSettings() }
    }

    @Published var enabledItems: Set<String> = ["keys", "wallet", "phone"] {
        didSet { saveSettings() }
    }

    @Published var itemLocations: [String: String] = [:] {
        didSet { saveSettings() }
    }

    @Published var checkedItems: Set<String> = []

    @Published var scheduledTime: Date? = nil {
        didSet { saveSettings(); scheduleNotification() }
    }

    @Published var useScheduledReminder: Bool = false {
        didSet { saveSettings(); scheduleNotification() }
    }

    // MARK: - Item Definitions

    struct CheckItem: Identifiable {
        let id: String
        let icon: String
        let name: String
        let question: String
    }

    static let allItems: [CheckItem] = [
        CheckItem(id: "keys", icon: "key.fill", name: "Keys", question: "Do you know where your keys are?"),
        CheckItem(id: "wallet", icon: "creditcard.fill", name: "Wallet", question: "Is your wallet where you can find it?"),
        CheckItem(id: "phone", icon: "iphone", name: "Phone", question: "Is your phone charged?"),
        CheckItem(id: "glasses", icon: "eyeglasses", name: "Glasses", question: "Do you know where your glasses are?"),
        CheckItem(id: "headphones", icon: "airpodspro", name: "Headphones", question: "Do you know where your headphones are?"),
        CheckItem(id: "medication", icon: "pills.fill", name: "Medication", question: "Did you take/prepare your medication?"),
        CheckItem(id: "waterbottle", icon: "waterbottle.fill", name: "Water Bottle", question: "Is your water bottle ready?"),
        CheckItem(id: "bag", icon: "bag.fill", name: "Bag", question: "Is your bag packed?"),
        CheckItem(id: "laptop", icon: "laptopcomputer", name: "Laptop", question: "Is your laptop charged?"),
        CheckItem(id: "badge", icon: "person.text.rectangle", name: "ID Badge", question: "Do you know where your badge is?")
    ]

    // MARK: - Computed Properties

    var activeItems: [CheckItem] {
        Self.allItems.filter { enabledItems.contains($0.id) }
    }

    var progress: Double {
        guard !activeItems.isEmpty else { return 0 }
        return Double(checkedItems.count) / Double(activeItems.count)
    }

    var isComplete: Bool {
        !activeItems.isEmpty && checkedItems.count == activeItems.count
    }

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let enabledKey = "selfCheck_enabled"
    private let itemsKey = "selfCheck_items"
    private let locationsKey = "selfCheck_locations"
    private let scheduledTimeKey = "selfCheck_scheduledTime"
    private let useScheduledKey = "selfCheck_useScheduled"

    private let notificationId = "selfcheck_bedtime_reminder"

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Public Methods

    func checkItem(_ itemId: String) {
        checkedItems.insert(itemId)

        if isComplete {
            Task { @MainActor in
                await AppDelegate.shared?.speakMessage("Perfect! Everything is accounted for. You're all set!")
            }
        }
    }

    func uncheckItem(_ itemId: String) {
        checkedItems.remove(itemId)
    }

    func setLocation(for itemId: String, location: String) {
        itemLocations[itemId] = location
        checkItem(itemId)
    }

    func resetChecks() {
        checkedItems.removeAll()
    }

    func toggleItem(_ itemId: String) {
        if enabledItems.contains(itemId) {
            enabledItems.remove(itemId)
        } else {
            enabledItems.insert(itemId)
        }
    }

    /// Schedule a reminder for X hours from now
    func scheduleReminderInHours(_ hours: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time for your Self-Check!"
        content.body = "Let's make sure you know where your important things are."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(hours * 3600), repeats: false)
        let request = UNNotificationRequest(identifier: "selfcheck_later_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule later self-check: \(error)")
            } else {
                print("Self-check scheduled for \(hours) hour(s) from now")
            }
        }
    }

    // MARK: - Notification Scheduling

    func scheduleNotification() {
        // Remove any existing notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])

        guard useScheduledReminder, let time = scheduledTime else { return }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time for your Self-Check!"
        content.body = "Let's make sure you know where your important things are before bed."
        content.sound = .default

        // Schedule daily at the specified time
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule self-check notification: \(error)")
            } else {
                print("Self-check notification scheduled for \(dateComponents.hour ?? 0):\(dateComponents.minute ?? 0)")
            }
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: enabledKey)
        userDefaults.set(Array(enabledItems), forKey: itemsKey)
        userDefaults.set(useScheduledReminder, forKey: useScheduledKey)

        if let time = scheduledTime {
            userDefaults.set(time.timeIntervalSince1970, forKey: scheduledTimeKey)
        } else {
            userDefaults.removeObject(forKey: scheduledTimeKey)
        }

        if let data = try? JSONEncoder().encode(itemLocations) {
            userDefaults.set(data, forKey: locationsKey)
        }
    }

    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: enabledKey)

        // Default to true if never set
        if userDefaults.object(forKey: enabledKey) == nil {
            isEnabled = true
        }

        if let items = userDefaults.stringArray(forKey: itemsKey) {
            enabledItems = Set(items)
        }

        useScheduledReminder = userDefaults.bool(forKey: useScheduledKey)

        if let timestamp = userDefaults.object(forKey: scheduledTimeKey) as? TimeInterval {
            scheduledTime = Date(timeIntervalSince1970: timestamp)
        } else {
            // Default to 9 PM
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 21
            components.minute = 0
            scheduledTime = Calendar.current.date(from: components)
        }

        if let data = userDefaults.data(forKey: locationsKey),
           let locations = try? JSONDecoder().decode([String: String].self, from: data) {
            itemLocations = locations
        }
    }
}
