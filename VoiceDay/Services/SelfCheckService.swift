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

    /// Custom items added by the user
    @Published var customItems: [CheckItem] = [] {
        didSet { saveSettings() }
    }

    @Published var scheduledTime: Date? = nil {
        didSet { saveSettings(); scheduleNotification() }
    }

    @Published var useScheduledReminder: Bool = false {
        didSet { saveSettings(); scheduleNotification() }
    }

    // MARK: - Item Definitions

    struct CheckItem: Identifiable, Codable {
        let id: String
        let icon: String
        let name: String
        let question: String
        var isCustom: Bool = false

        init(id: String, icon: String, name: String, question: String, isCustom: Bool = false) {
            self.id = id
            self.icon = icon
            self.name = name
            self.question = question
            self.isCustom = isCustom
        }
    }

    static let allItems: [CheckItem] = [
        // Essential items - things you need to find
        CheckItem(id: "keys", icon: "key.fill", name: "Keys", question: "Do you know where your keys are?"),
        CheckItem(id: "wallet", icon: "creditcard.fill", name: "Wallet", question: "Is your wallet where you can find it?"),
        CheckItem(id: "phone", icon: "iphone", name: "Phone", question: "Is your phone charging?"),
        CheckItem(id: "glasses", icon: "eyeglasses", name: "Glasses", question: "Do you know where your glasses are?"),
        CheckItem(id: "headphones", icon: "airpodspro", name: "Headphones", question: "Do you know where your headphones are?"),
        CheckItem(id: "badge", icon: "person.text.rectangle", name: "ID Badge", question: "Do you know where your badge is?"),

        // Morning prep - things for tomorrow
        CheckItem(id: "alarm", icon: "alarm.fill", name: "Alarm Set", question: "Is your alarm set for tomorrow?"),
        CheckItem(id: "clothes", icon: "tshirt.fill", name: "Clothes Ready", question: "Are your clothes ready for tomorrow?"),
        CheckItem(id: "bag", icon: "bag.fill", name: "Bag Packed", question: "Is your bag packed for tomorrow?"),
        CheckItem(id: "lunch", icon: "takeoutbag.and.cup.and.straw.fill", name: "Lunch Ready", question: "Is your lunch prepped or planned?"),
        CheckItem(id: "laptop", icon: "laptopcomputer", name: "Laptop Charged", question: "Is your laptop charged?"),
        CheckItem(id: "waterbottle", icon: "waterbottle.fill", name: "Water Bottle", question: "Is your water bottle filled?"),

        // Health & Self-care
        CheckItem(id: "medication", icon: "pills.fill", name: "Medication", question: "Did you take your evening medication?"),
        CheckItem(id: "teeth", icon: "mouth.fill", name: "Brush Teeth", question: "Did you brush your teeth?"),
        CheckItem(id: "skincare", icon: "face.smiling", name: "Skincare", question: "Did you do your skincare routine?"),

        // Home security - things people forget
        CheckItem(id: "door_locked", icon: "door.left.hand.closed", name: "Door Locked", question: "Is the front door locked?"),
        CheckItem(id: "stove", icon: "flame.fill", name: "Stove Off", question: "Is the stove/oven turned off?"),
        CheckItem(id: "lights", icon: "lightbulb.fill", name: "Lights Off", question: "Are unnecessary lights turned off?"),
        CheckItem(id: "windows", icon: "window.vertical.closed", name: "Windows Closed", question: "Are the windows closed and locked?"),
        CheckItem(id: "garage", icon: "car.fill", name: "Garage Closed", question: "Is the garage door closed?"),

        // Pet care
        CheckItem(id: "pet_food", icon: "pawprint.fill", name: "Pet Fed", question: "Did you feed your pet?"),
        CheckItem(id: "pet_water", icon: "drop.fill", name: "Pet Water", question: "Does your pet have fresh water?"),

        // Misc
        CheckItem(id: "trash", icon: "trash.fill", name: "Trash Out", question: "Does the trash need to go out tonight?"),
        CheckItem(id: "dishes", icon: "fork.knife", name: "Dishes Done", question: "Are the dishes done or in the dishwasher?")
    ]

    // MARK: - Computed Properties

    /// All items (preset + custom)
    var allItemsIncludingCustom: [CheckItem] {
        Self.allItems + customItems
    }

    var activeItems: [CheckItem] {
        allItemsIncludingCustom.filter { enabledItems.contains($0.id) }
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
    private let customItemsKey = "selfCheck_customItems"

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

    // MARK: - Custom Items

    /// Add a custom item to the checklist
    func addCustomItem(name: String, question: String, icon: String = "star.fill") {
        let id = "custom_\(UUID().uuidString)"
        let item = CheckItem(id: id, icon: icon, name: name, question: question, isCustom: true)
        customItems.append(item)
        enabledItems.insert(id)  // Auto-enable new custom items
    }

    /// Remove a custom item
    func removeCustomItem(_ itemId: String) {
        customItems.removeAll { $0.id == itemId }
        enabledItems.remove(itemId)
        itemLocations.removeValue(forKey: itemId)
    }

    /// Available icons for custom items (includes all preset icons + extras)
    static let customItemIcons: [(icon: String, name: String)] = [
        // Essential items
        ("key.fill", "Keys"),
        ("creditcard.fill", "Wallet"),
        ("iphone", "Phone"),
        ("eyeglasses", "Glasses"),
        ("airpodspro", "Headphones"),
        ("person.text.rectangle", "Badge"),
        // Morning prep
        ("alarm.fill", "Alarm"),
        ("tshirt.fill", "Clothes"),
        ("bag.fill", "Bag"),
        ("takeoutbag.and.cup.and.straw.fill", "Lunch"),
        ("laptopcomputer", "Laptop"),
        ("waterbottle.fill", "Water"),
        // Health
        ("pills.fill", "Meds"),
        ("mouth.fill", "Teeth"),
        ("face.smiling", "Skincare"),
        // Home security
        ("door.left.hand.closed", "Door"),
        ("flame.fill", "Stove"),
        ("lightbulb.fill", "Lights"),
        ("window.vertical.closed", "Window"),
        ("car.fill", "Garage"),
        // Pets
        ("pawprint.fill", "Pet"),
        ("drop.fill", "Water"),
        // Chores
        ("trash.fill", "Trash"),
        ("fork.knife", "Dishes"),
        // Extras for custom items
        ("star.fill", "Star"),
        ("heart.fill", "Heart"),
        ("bolt.fill", "Energy"),
        ("flag.fill", "Flag"),
        ("bell.fill", "Reminder"),
        ("bookmark.fill", "Bookmark"),
        ("tag.fill", "Tag"),
        ("paperclip", "Clip"),
        ("folder.fill", "Folder"),
        ("cup.and.saucer.fill", "Cup"),
        ("leaf.fill", "Plant"),
        ("figure.walk", "Exercise"),
        ("bed.double.fill", "Bed"),
        ("clock.fill", "Clock"),
        ("envelope.fill", "Mail"),
        ("book.fill", "Book"),
        ("gamecontroller.fill", "Games"),
        ("tv.fill", "TV"),
        ("lock.fill", "Lock"),
        ("backpack.fill", "Backpack")
    ]

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

    private var isLoading = false  // Prevent didSet during load

    private func saveSettings() {
        guard !isLoading else { return }  // Don't save while loading

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

        // Save custom items
        if let data = try? JSONEncoder().encode(customItems) {
            userDefaults.set(data, forKey: customItemsKey)
        }

        // Ensure settings are written to disk immediately
        userDefaults.synchronize()
        print("💾 SelfCheckService: Settings saved (customItems: \(customItems.count), enabledItems: \(enabledItems.count))")
    }

    private func loadSettings() {
        isLoading = true  // Prevent didSet from triggering saveSettings

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

        // Load custom items
        if let data = userDefaults.data(forKey: customItemsKey),
           let items = try? JSONDecoder().decode([CheckItem].self, from: data) {
            customItems = items
        }

        isLoading = false  // Re-enable saving
        print("📂 SelfCheckService: Settings loaded (customItems: \(customItems.count), enabledItems: \(enabledItems.count))")
    }
}
