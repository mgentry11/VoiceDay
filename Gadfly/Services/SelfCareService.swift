import SwiftUI
import UserNotifications
import Combine

/// Self-Care Service - Manages gentle reminders for water, meals, stretch, and eye breaks
/// Like a caring parent reminding you to take care of yourself while hyperfocusing
class SelfCareService: ObservableObject {
    static let shared = SelfCareService()

    // MARK: - Published Settings

    @Published var isEnabled: Bool = false {
        didSet { saveSettings(); scheduleReminders() }
    }

    @Published var careLevel: CareLevel = .gentle {
        didSet { saveSettings() }
    }

    @Published var ageMode: AgeMode = .adult {
        didSet { saveSettings(); scheduleReminders() }
    }

    // Granular settings
    @Published var waterSettings = WaterSettings()
    @Published var mealSettings = MealSettings()
    @Published var stretchSettings = StretchSettings()
    @Published var eyeSettings = EyeSettings()
    @Published var hyperfocusSettings = HyperfocusBreakSettings()

    // MARK: - Private Properties

    private var timers: [String: Timer] = [:]
    private var isPaused = false
    private let userDefaults = UserDefaults.standard

    // MARK: - Types

    enum CareLevel: String, CaseIterable, Identifiable {
        case gentle = "Gentle"
        case moderate = "Moderate"
        case full = "Full Nag"

        var id: String { rawValue }
    }

    enum AgeMode: String, CaseIterable, Identifiable {
        case kid = "Kid"
        case teen = "Teen"
        case adult = "Adult"

        var id: String { rawValue }

        var multiplier: Double {
            switch self {
            case .kid: return 0.6    // More frequent reminders
            case .teen: return 0.8
            case .adult: return 1.0
            }
        }
    }

    struct WaterSettings: Codable {
        var isEnabled: Bool = true
        var intervalMinutes: Int = 45
    }

    struct MealSettings: Codable {
        var isEnabled: Bool = false
        var mealCount: Int = 3
        var breakfastTime: String = "08:00"
        var lunchTime: String = "12:30"
        var dinnerTime: String = "18:30"
        var snackTime1: String? = nil
        var snackTime2: String? = nil
    }

    struct StretchSettings: Codable {
        var isEnabled: Bool = true
        var intervalMinutes: Int = 30
    }

    struct EyeSettings: Codable {
        var isEnabled: Bool = false
        var intervalMinutes: Int = 20  // 20-20-20 rule
    }

    struct HyperfocusBreakSettings: Codable {
        var isEnabled: Bool = true
        var intervalMinutes: Int = 90
        var protectProductiveFlow: Bool = false
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Public Methods

    func pauseReminders() {
        isPaused = true
        cancelAllTimers()
    }

    func resumeReminders() {
        isPaused = false
        scheduleReminders()
    }

    func scheduleReminders() {
        guard isEnabled, !isPaused else {
            cancelAllTimers()
            return
        }

        cancelAllTimers()

        // Water reminders
        if waterSettings.isEnabled {
            let interval = Double(waterSettings.intervalMinutes) * 60 * ageMode.multiplier
            scheduleTimer(id: "water", interval: interval) { [weak self] in
                self?.showReminder(type: .water)
            }
        }

        // Stretch reminders
        if stretchSettings.isEnabled {
            let interval = Double(stretchSettings.intervalMinutes) * 60 * ageMode.multiplier
            scheduleTimer(id: "stretch", interval: interval) { [weak self] in
                self?.showReminder(type: .stretch)
            }
        }

        // Eye rest reminders
        if eyeSettings.isEnabled {
            let interval = Double(eyeSettings.intervalMinutes) * 60
            scheduleTimer(id: "eyes", interval: interval) { [weak self] in
                self?.showReminder(type: .eyes)
            }
        }

        // Hyperfocus break reminders
        if hyperfocusSettings.isEnabled {
            let interval = Double(hyperfocusSettings.intervalMinutes) * 60
            scheduleTimer(id: "hyperfocus", interval: interval) { [weak self] in
                self?.showReminder(type: .hyperfocusBreak)
            }
        }

        // Meal reminders (scheduled at specific times)
        if mealSettings.isEnabled {
            scheduleMealReminders()
        }
    }

    // MARK: - Reminder Types

    enum ReminderType {
        case water
        case stretch
        case eyes
        case hyperfocusBreak
        case meal(String)

        var icon: String {
            switch self {
            case .water: return "drop.fill"
            case .stretch: return "figure.walk"
            case .eyes: return "eye.fill"
            case .hyperfocusBreak: return "arrow.2.circlepath"
            case .meal: return "fork.knife"
            }
        }

        var title: String {
            switch self {
            case .water: return "Hydration Check"
            case .stretch: return "Time to Move"
            case .eyes: return "Eye Rest (20-20-20)"
            case .hyperfocusBreak: return "Hyperfocus Check-in"
            case .meal(let name): return "\(name) Time"
            }
        }
    }

    // MARK: - Private Methods

    private func scheduleTimer(id: String, interval: TimeInterval, action: @escaping () -> Void) {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
        timers[id] = timer
    }

    private func cancelAllTimers() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }

    private func scheduleMealReminders() {
        let meals = [
            ("Breakfast", mealSettings.breakfastTime),
            ("Lunch", mealSettings.lunchTime),
            ("Dinner", mealSettings.dinnerTime)
        ]

        if mealSettings.mealCount >= 4, let snack1 = mealSettings.snackTime1 {
            scheduleMealAt(time: snack1, name: "Snack")
        }
        if mealSettings.mealCount >= 5, let snack2 = mealSettings.snackTime2 {
            scheduleMealAt(time: snack2, name: "Snack")
        }

        for (name, time) in meals.prefix(mealSettings.mealCount) {
            scheduleMealAt(time: time, name: name)
        }
    }

    private func scheduleMealAt(time: String, name: String) {
        guard let components = parseTime(time) else { return }

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let content = UNMutableNotificationContent()
        content.title = "\(name) Time!"
        content.body = message(for: .meal(name))
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "meal_\(name.lowercased())", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func parseTime(_ time: String) -> (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func showReminder(type: ReminderType) {
        let message = message(for: type)

        // Show local notification
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        // Speak it
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(message)
        }
    }

    private func message(for type: ReminderType) -> String {
        let messages: [String]

        switch (type, careLevel) {
        case (.water, .gentle):
            messages = ["Time for some water?", "Hydration check!"]
        case (.water, .moderate):
            messages = ["Hey! Your brain needs water. Drink up!", "Water time - fuel that brain!"]
        case (.water, .full):
            messages = ["STOP! Drink water NOW. Your brain is thirsty!", "HYDRATION EMERGENCY! Drink!"]

        case (.stretch, .gentle):
            messages = ["Maybe stretch a bit?", "Your body would love a stretch"]
        case (.stretch, .moderate):
            messages = ["Time to move! Stand up and stretch.", "Stretch break - your back will thank you"]
        case (.stretch, .full):
            messages = ["GET UP! Your body is stiff as a board!", "MOVE IT! Stretch those muscles NOW!"]

        case (.eyes, _):
            messages = ["20-20-20: Look at something 20 feet away for 20 seconds", "Give your eyes a break - look away from the screen"]

        case (.hyperfocusBreak, _):
            messages = ["You've been focused for a while. Still working on the right thing?", "Hyperfocus check: Is this still the best use of your time?"]

        case (.meal(let name), .gentle):
            messages = ["\(name) time?", "Time for \(name.lowercased()) - fuel up!"]
        case (.meal(let name), .moderate):
            messages = ["Hey! It's \(name.lowercased()) time. Your brain needs fuel!", "\(name) o'clock! Take a food break."]
        case (.meal(let name), .full):
            messages = ["STOP! It's \(name.uppercased()) TIME. Go eat!", "Your brain is hungry! \(name) NOW!"]
        }

        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Persistence

    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: "selfCare_isEnabled")
        userDefaults.set(careLevel.rawValue, forKey: "selfCare_careLevel")
        userDefaults.set(ageMode.rawValue, forKey: "selfCare_ageMode")

        if let data = try? JSONEncoder().encode(waterSettings) {
            userDefaults.set(data, forKey: "selfCare_water")
        }
        if let data = try? JSONEncoder().encode(mealSettings) {
            userDefaults.set(data, forKey: "selfCare_meals")
        }
        if let data = try? JSONEncoder().encode(stretchSettings) {
            userDefaults.set(data, forKey: "selfCare_stretch")
        }
        if let data = try? JSONEncoder().encode(eyeSettings) {
            userDefaults.set(data, forKey: "selfCare_eyes")
        }
        if let data = try? JSONEncoder().encode(hyperfocusSettings) {
            userDefaults.set(data, forKey: "selfCare_hyperfocus")
        }
    }

    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: "selfCare_isEnabled")

        if let level = userDefaults.string(forKey: "selfCare_careLevel"),
           let careLevel = CareLevel(rawValue: level) {
            self.careLevel = careLevel
        }

        if let mode = userDefaults.string(forKey: "selfCare_ageMode"),
           let ageMode = AgeMode(rawValue: mode) {
            self.ageMode = ageMode
        }

        if let data = userDefaults.data(forKey: "selfCare_water"),
           let settings = try? JSONDecoder().decode(WaterSettings.self, from: data) {
            waterSettings = settings
        }

        if let data = userDefaults.data(forKey: "selfCare_meals"),
           let settings = try? JSONDecoder().decode(MealSettings.self, from: data) {
            mealSettings = settings
        }

        if let data = userDefaults.data(forKey: "selfCare_stretch"),
           let settings = try? JSONDecoder().decode(StretchSettings.self, from: data) {
            stretchSettings = settings
        }

        if let data = userDefaults.data(forKey: "selfCare_eyes"),
           let settings = try? JSONDecoder().decode(EyeSettings.self, from: data) {
            eyeSettings = settings
        }

        if let data = userDefaults.data(forKey: "selfCare_hyperfocus"),
           let settings = try? JSONDecoder().decode(HyperfocusBreakSettings.self, from: data) {
            hyperfocusSettings = settings
        }
    }
}
