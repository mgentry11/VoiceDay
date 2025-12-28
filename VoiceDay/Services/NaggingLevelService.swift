import Foundation
import SwiftUI

/// Manages how much the app nags the user - from gentle reminders to persistent nudges
@MainActor
class NaggingLevelService: ObservableObject {
    static let shared = NaggingLevelService()

    // MARK: - Nagging Level

    enum NaggingLevel: String, CaseIterable, Codable {
        case gentle = "gentle"
        case moderate = "moderate"
        case persistent = "persistent"

        var displayName: String {
            switch self {
            case .gentle: return "Gentle"
            case .moderate: return "Moderate"
            case .persistent: return "Persistent"
            }
        }

        var description: String {
            switch self {
            case .gentle: return "One reminder per task, no pressure"
            case .moderate: return "Reminder + follow-up, supportive nudges"
            case .persistent: return "Multiple reminders, won't let you forget"
            }
        }

        var icon: String {
            switch self {
            case .gentle: return "leaf.fill"
            case .moderate: return "hand.wave.fill"
            case .persistent: return "bell.badge.fill"
            }
        }

        var color: Color {
            switch self {
            case .gentle: return .green
            case .moderate: return .orange
            case .persistent: return .red
            }
        }

        /// Minutes between reminders for overdue tasks
        var reminderInterval: Int {
            switch self {
            case .gentle: return 0 // No repeat
            case .moderate: return 30
            case .persistent: return 15
            }
        }

        /// How many times to remind for a single task
        var maxReminders: Int {
            switch self {
            case .gentle: return 1
            case .moderate: return 2
            case .persistent: return 5
            }
        }
    }

    // MARK: - Published Properties

    @Published var naggingLevel: NaggingLevel = .moderate {
        didSet { save() }
    }

    // MARK: - Self-Care Reminders

    @Published var waterRemindersEnabled: Bool = true {
        didSet { save() }
    }

    @Published var waterReminderInterval: Int = 60 { // minutes
        didSet { save() }
    }

    @Published var foodRemindersEnabled: Bool = true {
        didSet { save() }
    }

    @Published var breakRemindersEnabled: Bool = true {
        didSet { save() }
    }

    @Published var breakReminderInterval: Int = 45 { // minutes of focus before break reminder
        didSet { save() }
    }

    @Published var medicationRemindersEnabled: Bool = false {
        didSet { save() }
    }

    @Published var medicationTimes: [Date] = [] {
        didSet { save() }
    }

    @Published var sleepReminderEnabled: Bool = true {
        didSet { save() }
    }

    @Published var sleepReminderTime: Date = defaultTime(hour: 22, minute: 0) {
        didSet { save() }
    }

    // MARK: - Hyperfocus Mode

    @Published var isHyperfocusActive: Bool = false {
        didSet { save() }
    }

    @Published var hyperfocusStartTime: Date? = nil

    @Published var hyperfocusAutoExitMinutes: Int = 120 { // 2 hours default
        didSet { save() }
    }

    // MARK: - Snooze State

    @Published var allNaggingSnoozedUntil: Date? = nil {
        didSet { save() }
    }

    // MARK: - Persistence Keys

    private let keys = (
        naggingLevel: "nagging_level",
        waterEnabled: "nagging_water_enabled",
        waterInterval: "nagging_water_interval",
        foodEnabled: "nagging_food_enabled",
        breakEnabled: "nagging_break_enabled",
        breakInterval: "nagging_break_interval",
        medicationEnabled: "nagging_medication_enabled",
        medicationTimes: "nagging_medication_times",
        sleepEnabled: "nagging_sleep_enabled",
        sleepTime: "nagging_sleep_time",
        hyperfocusAutoExit: "nagging_hyperfocus_auto_exit",
        snoozedUntil: "nagging_snoozed_until"
    )

    // MARK: - Initialization

    private var isLoading = false

    private init() {
        load()
    }

    // MARK: - Public Methods

    /// Check if nagging is currently active (not snoozed or hyperfocusing)
    var isNaggingActive: Bool {
        if isHyperfocusActive { return false }
        if let snoozedUntil = allNaggingSnoozedUntil, Date() < snoozedUntil { return false }
        return true
    }

    /// Snooze all nagging for a duration
    func snoozeAll(minutes: Int) {
        allNaggingSnoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        print("😴 Nagging snoozed for \(minutes) minutes")
    }

    /// Cancel snooze
    func cancelSnooze() {
        allNaggingSnoozedUntil = nil
        print("⏰ Snooze cancelled")
    }

    /// Enter hyperfocus mode
    func enterHyperfocus() {
        isHyperfocusActive = true
        hyperfocusStartTime = Date()
        print("🎯 Hyperfocus mode started")
    }

    /// Exit hyperfocus mode
    func exitHyperfocus() {
        isHyperfocusActive = false
        hyperfocusStartTime = nil
        print("🎯 Hyperfocus mode ended")
    }

    /// Get hyperfocus duration in minutes
    var hyperfocusDuration: Int {
        guard let startTime = hyperfocusStartTime else { return 0 }
        return Int(Date().timeIntervalSince(startTime) / 60)
    }

    /// Check if should auto-exit hyperfocus
    var shouldAutoExitHyperfocus: Bool {
        hyperfocusDuration >= hyperfocusAutoExitMinutes
    }

    /// Add a medication time
    func addMedicationTime(_ time: Date) {
        medicationTimes.append(time)
        medicationTimes.sort { $0 < $1 }
    }

    /// Remove a medication time
    func removeMedicationTime(at index: Int) {
        guard index < medicationTimes.count else { return }
        medicationTimes.remove(at: index)
    }

    /// Get appropriate message based on nagging level
    func getNagMessage(for context: String) -> String {
        switch naggingLevel {
        case .gentle:
            return "When you're ready: \(context)"
        case .moderate:
            return "Friendly reminder: \(context)"
        case .persistent:
            return "Hey! Don't forget: \(context)"
        }
    }

    /// Reset to defaults
    func resetToDefaults() {
        naggingLevel = .moderate
        waterRemindersEnabled = true
        waterReminderInterval = 60
        foodRemindersEnabled = true
        breakRemindersEnabled = true
        breakReminderInterval = 45
        medicationRemindersEnabled = false
        medicationTimes = []
        sleepReminderEnabled = true
        sleepReminderTime = Self.defaultTime(hour: 22, minute: 0)
        hyperfocusAutoExitMinutes = 120
        isHyperfocusActive = false
        allNaggingSnoozedUntil = nil
    }

    // MARK: - Private Methods

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Persistence

    private func save() {
        guard !isLoading else { return }

        let defaults = UserDefaults.standard

        defaults.set(naggingLevel.rawValue, forKey: keys.naggingLevel)
        defaults.set(waterRemindersEnabled, forKey: keys.waterEnabled)
        defaults.set(waterReminderInterval, forKey: keys.waterInterval)
        defaults.set(foodRemindersEnabled, forKey: keys.foodEnabled)
        defaults.set(breakRemindersEnabled, forKey: keys.breakEnabled)
        defaults.set(breakReminderInterval, forKey: keys.breakInterval)
        defaults.set(medicationRemindersEnabled, forKey: keys.medicationEnabled)
        defaults.set(sleepReminderEnabled, forKey: keys.sleepEnabled)
        defaults.set(sleepReminderTime.timeIntervalSince1970, forKey: keys.sleepTime)
        defaults.set(hyperfocusAutoExitMinutes, forKey: keys.hyperfocusAutoExit)

        if let medData = try? JSONEncoder().encode(medicationTimes.map { $0.timeIntervalSince1970 }) {
            defaults.set(medData, forKey: keys.medicationTimes)
        }

        if let snoozedUntil = allNaggingSnoozedUntil {
            defaults.set(snoozedUntil.timeIntervalSince1970, forKey: keys.snoozedUntil)
        } else {
            defaults.removeObject(forKey: keys.snoozedUntil)
        }

        defaults.synchronize()
        print("💾 NaggingLevelService: Settings saved")
    }

    private func load() {
        isLoading = true

        let defaults = UserDefaults.standard

        if let levelRaw = defaults.string(forKey: keys.naggingLevel),
           let level = NaggingLevel(rawValue: levelRaw) {
            naggingLevel = level
        }

        waterRemindersEnabled = defaults.object(forKey: keys.waterEnabled) as? Bool ?? true
        waterReminderInterval = defaults.object(forKey: keys.waterInterval) as? Int ?? 60
        foodRemindersEnabled = defaults.object(forKey: keys.foodEnabled) as? Bool ?? true
        breakRemindersEnabled = defaults.object(forKey: keys.breakEnabled) as? Bool ?? true
        breakReminderInterval = defaults.object(forKey: keys.breakInterval) as? Int ?? 45
        medicationRemindersEnabled = defaults.object(forKey: keys.medicationEnabled) as? Bool ?? false
        sleepReminderEnabled = defaults.object(forKey: keys.sleepEnabled) as? Bool ?? true
        hyperfocusAutoExitMinutes = defaults.object(forKey: keys.hyperfocusAutoExit) as? Int ?? 120

        if let timestamp = defaults.object(forKey: keys.sleepTime) as? TimeInterval {
            sleepReminderTime = Date(timeIntervalSince1970: timestamp)
        }

        if let medData = defaults.data(forKey: keys.medicationTimes),
           let timestamps = try? JSONDecoder().decode([TimeInterval].self, from: medData) {
            medicationTimes = timestamps.map { Date(timeIntervalSince1970: $0) }
        }

        if let snoozedTimestamp = defaults.object(forKey: keys.snoozedUntil) as? TimeInterval {
            let snoozedDate = Date(timeIntervalSince1970: snoozedTimestamp)
            if snoozedDate > Date() {
                allNaggingSnoozedUntil = snoozedDate
            } else {
                allNaggingSnoozedUntil = nil
            }
        }

        isLoading = false
        print("📂 NaggingLevelService: Settings loaded")
    }
}
