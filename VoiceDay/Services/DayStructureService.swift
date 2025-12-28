import Foundation
import SwiftUI

/// Manages the user's daily structure - which check-ins are enabled, their times, and custom items
@MainActor
class DayStructureService: ObservableObject {
    static let shared = DayStructureService()

    // MARK: - Check-in Toggles

    @Published var morningCheckInEnabled: Bool = true {
        didSet { save() }
    }

    @Published var middayCheckInEnabled: Bool = true {
        didSet { save() }
    }

    @Published var eveningCheckInEnabled: Bool = true {
        didSet { save() }
    }

    @Published var bedtimeCheckInEnabled: Bool = true {
        didSet { save() }
    }

    // MARK: - Check-in Times

    @Published var morningCheckInTime: Date = defaultTime(hour: 7, minute: 0) {
        didSet { save() }
    }

    @Published var middayCheckInTime: Date = defaultTime(hour: 12, minute: 0) {
        didSet { save() }
    }

    @Published var eveningCheckInTime: Date = defaultTime(hour: 18, minute: 0) {
        didSet { save() }
    }

    @Published var bedtimeCheckInTime: Date = defaultTime(hour: 21, minute: 0) {
        didSet { save() }
    }

    // MARK: - Custom Check-in Items

    @Published var morningItems: [CheckInItem] = [] {
        didSet { save() }
    }

    @Published var bedtimeItems: [CheckInItem] = [] {
        didSet { save() }
    }

    // MARK: - Check-in Item Model

    struct CheckInItem: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var icon: String
        var isEnabled: Bool
        var order: Int

        init(id: UUID = UUID(), title: String, icon: String = "checkmark.circle", isEnabled: Bool = true, order: Int = 0) {
            self.id = id
            self.title = title
            self.icon = icon
            self.isEnabled = isEnabled
            self.order = order
        }
    }

    // MARK: - Default Items

    static let defaultMorningItems: [CheckInItem] = [
        CheckInItem(title: "Check my calendar", icon: "calendar", order: 0),
        CheckInItem(title: "Review my tasks", icon: "checklist", order: 1),
        CheckInItem(title: "Take medication", icon: "pills.fill", order: 2),
        CheckInItem(title: "Eat breakfast", icon: "fork.knife", order: 3),
        CheckInItem(title: "Set daily intention", icon: "star.fill", order: 4)
    ]

    static let defaultBedtimeItems: [CheckInItem] = [
        CheckInItem(title: "Keys location", icon: "key.fill", order: 0),
        CheckInItem(title: "Wallet location", icon: "creditcard.fill", order: 1),
        CheckInItem(title: "Phone charging", icon: "battery.100.bolt", order: 2),
        CheckInItem(title: "Alarm set", icon: "alarm.fill", order: 3),
        CheckInItem(title: "Door locked", icon: "lock.fill", order: 4),
        CheckInItem(title: "Stove off", icon: "flame.fill", order: 5)
    ]

    // MARK: - Persistence Keys

    private let keys = (
        morningEnabled: "dayStructure_morningEnabled",
        middayEnabled: "dayStructure_middayEnabled",
        eveningEnabled: "dayStructure_eveningEnabled",
        bedtimeEnabled: "dayStructure_bedtimeEnabled",
        morningTime: "dayStructure_morningTime",
        middayTime: "dayStructure_middayTime",
        eveningTime: "dayStructure_eveningTime",
        bedtimeTime: "dayStructure_bedtimeTime",
        morningItems: "dayStructure_morningItems",
        bedtimeItems: "dayStructure_bedtimeItems",
        hasCompletedSetup: "dayStructure_hasCompletedSetup"
    )

    @Published var hasCompletedSetup: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedSetup, forKey: keys.hasCompletedSetup)
        }
    }

    // MARK: - Initialization

    private var isLoading = false

    private init() {
        load()
    }

    // MARK: - Public Methods

    /// Get enabled items for morning check-in
    var enabledMorningItems: [CheckInItem] {
        morningItems.filter { $0.isEnabled }.sorted { $0.order < $1.order }
    }

    /// Get enabled items for bedtime check-in
    var enabledBedtimeItems: [CheckInItem] {
        bedtimeItems.filter { $0.isEnabled }.sorted { $0.order < $1.order }
    }

    /// Add a custom item to morning check-in
    func addMorningItem(title: String, icon: String = "checkmark.circle") {
        let item = CheckInItem(title: title, icon: icon, order: morningItems.count)
        morningItems.append(item)
    }

    /// Add a custom item to bedtime check-in
    func addBedtimeItem(title: String, icon: String = "checkmark.circle") {
        let item = CheckInItem(title: title, icon: icon, order: bedtimeItems.count)
        bedtimeItems.append(item)
    }

    /// Remove a morning item
    func removeMorningItem(id: UUID) {
        morningItems.removeAll { $0.id == id }
        reorderMorningItems()
    }

    /// Remove a bedtime item
    func removeBedtimeItem(id: UUID) {
        bedtimeItems.removeAll { $0.id == id }
        reorderBedtimeItems()
    }

    /// Toggle a morning item's enabled state
    func toggleMorningItem(id: UUID) {
        if let index = morningItems.firstIndex(where: { $0.id == id }) {
            morningItems[index].isEnabled.toggle()
        }
    }

    /// Toggle a bedtime item's enabled state
    func toggleBedtimeItem(id: UUID) {
        if let index = bedtimeItems.firstIndex(where: { $0.id == id }) {
            bedtimeItems[index].isEnabled.toggle()
        }
    }

    /// Reorder morning items
    func moveMorningItem(from source: IndexSet, to destination: Int) {
        morningItems.move(fromOffsets: source, toOffset: destination)
        reorderMorningItems()
    }

    /// Reorder bedtime items
    func moveBedtimeItem(from source: IndexSet, to destination: Int) {
        bedtimeItems.move(fromOffsets: source, toOffset: destination)
        reorderBedtimeItems()
    }

    /// Reset to defaults
    func resetToDefaults() {
        morningCheckInEnabled = true
        middayCheckInEnabled = true
        eveningCheckInEnabled = true
        bedtimeCheckInEnabled = true

        morningCheckInTime = Self.defaultTime(hour: 7, minute: 0)
        middayCheckInTime = Self.defaultTime(hour: 12, minute: 0)
        eveningCheckInTime = Self.defaultTime(hour: 18, minute: 0)
        bedtimeCheckInTime = Self.defaultTime(hour: 21, minute: 0)

        morningItems = Self.defaultMorningItems
        bedtimeItems = Self.defaultBedtimeItems
    }

    // MARK: - Private Methods

    private func reorderMorningItems() {
        for (index, _) in morningItems.enumerated() {
            morningItems[index].order = index
        }
    }

    private func reorderBedtimeItems() {
        for (index, _) in bedtimeItems.enumerated() {
            bedtimeItems[index].order = index
        }
    }

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

        // Save toggles
        defaults.set(morningCheckInEnabled, forKey: keys.morningEnabled)
        defaults.set(middayCheckInEnabled, forKey: keys.middayEnabled)
        defaults.set(eveningCheckInEnabled, forKey: keys.eveningEnabled)
        defaults.set(bedtimeCheckInEnabled, forKey: keys.bedtimeEnabled)

        // Save times
        defaults.set(morningCheckInTime.timeIntervalSince1970, forKey: keys.morningTime)
        defaults.set(middayCheckInTime.timeIntervalSince1970, forKey: keys.middayTime)
        defaults.set(eveningCheckInTime.timeIntervalSince1970, forKey: keys.eveningTime)
        defaults.set(bedtimeCheckInTime.timeIntervalSince1970, forKey: keys.bedtimeTime)

        // Save custom items
        if let morningData = try? JSONEncoder().encode(morningItems) {
            defaults.set(morningData, forKey: keys.morningItems)
        }
        if let bedtimeData = try? JSONEncoder().encode(bedtimeItems) {
            defaults.set(bedtimeData, forKey: keys.bedtimeItems)
        }

        defaults.synchronize()
        print("💾 DayStructureService: Settings saved")
    }

    private func load() {
        isLoading = true

        let defaults = UserDefaults.standard

        // Load toggles (default to true if not set)
        morningCheckInEnabled = defaults.object(forKey: keys.morningEnabled) as? Bool ?? true
        middayCheckInEnabled = defaults.object(forKey: keys.middayEnabled) as? Bool ?? true
        eveningCheckInEnabled = defaults.object(forKey: keys.eveningEnabled) as? Bool ?? true
        bedtimeCheckInEnabled = defaults.object(forKey: keys.bedtimeEnabled) as? Bool ?? true

        // Load times
        if let timestamp = defaults.object(forKey: keys.morningTime) as? TimeInterval {
            morningCheckInTime = Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = defaults.object(forKey: keys.middayTime) as? TimeInterval {
            middayCheckInTime = Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = defaults.object(forKey: keys.eveningTime) as? TimeInterval {
            eveningCheckInTime = Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = defaults.object(forKey: keys.bedtimeTime) as? TimeInterval {
            bedtimeCheckInTime = Date(timeIntervalSince1970: timestamp)
        }

        // Load custom items (use defaults if not set)
        if let morningData = defaults.data(forKey: keys.morningItems),
           let items = try? JSONDecoder().decode([CheckInItem].self, from: morningData) {
            morningItems = items
        } else {
            morningItems = Self.defaultMorningItems
        }

        if let bedtimeData = defaults.data(forKey: keys.bedtimeItems),
           let items = try? JSONDecoder().decode([CheckInItem].self, from: bedtimeData) {
            bedtimeItems = items
        } else {
            bedtimeItems = Self.defaultBedtimeItems
        }

        hasCompletedSetup = defaults.bool(forKey: keys.hasCompletedSetup)

        isLoading = false
        print("📂 DayStructureService: Settings loaded")
    }
}
