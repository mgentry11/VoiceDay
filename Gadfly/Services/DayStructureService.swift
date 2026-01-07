import Foundation
import SwiftUI

/// Manages the user's daily structure - which check-ins are enabled, their times, and custom items
@MainActor
class DayStructureService: ObservableObject {
    static let shared = DayStructureService()

    // MARK: - Check-in Toggles

    @Published var morningCheckInEnabled: Bool = false {
        didSet { save() }
    }

    @Published var middayCheckInEnabled: Bool = false {
        didSet { save() }
    }

    @Published var eveningCheckInEnabled: Bool = false {
        didSet { save() }
    }

    @Published var bedtimeCheckInEnabled: Bool = false {
        didSet { save() }
    }
    
    @Published var hasDeclinedCheckInSetup: Bool = false {
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

    // MARK: - User-Created Custom Check-ins

    @Published var customCheckIns: [CustomCheckIn] = [] {
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

    // MARK: - Custom Check-in Model

    struct CustomCheckIn: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var subtitle: String
        var icon: String
        var colorHex: String  // Store color as hex for Codable
        var isEnabled: Bool
        var time: Date
        var items: [CheckInItem]
        var order: Int

        init(
            id: UUID = UUID(),
            name: String,
            subtitle: String = "",
            icon: String = "checkmark.circle.fill",
            colorHex: String = "#10B981",  // Default emerald green
            isEnabled: Bool = true,
            time: Date = defaultTimeStatic(hour: 14, minute: 0),
            items: [CheckInItem] = [],
            order: Int = 0
        ) {
            self.id = id
            self.name = name
            self.subtitle = subtitle
            self.icon = icon
            self.colorHex = colorHex
            self.isEnabled = isEnabled
            self.time = time
            self.items = items
            self.order = order
        }

        var color: Color {
            Color(hex: colorHex)
        }

        private static func defaultTimeStatic(hour: Int, minute: Int) -> Date {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? Date()
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
        customCheckIns: "dayStructure_customCheckIns",
        hasCompletedSetup: "dayStructure_hasCompletedSetup",
        hasDeclinedCheckInSetup: "dayStructure_hasDeclinedCheckInSetup"
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

    // MARK: - Custom Check-in Management

    /// Get all enabled custom check-ins sorted by time
    var enabledCustomCheckIns: [CustomCheckIn] {
        customCheckIns.filter { $0.isEnabled }.sorted { $0.time < $1.time }
    }

    /// Get all check-ins (preset + custom) sorted by time for the day
    var allEnabledCheckInsSortedByTime: [(type: CheckInType, time: Date)] {
        var checkIns: [(type: CheckInType, time: Date)] = []

        if morningCheckInEnabled {
            checkIns.append((.morning, morningCheckInTime))
        }
        if middayCheckInEnabled {
            checkIns.append((.midday, middayCheckInTime))
        }
        if eveningCheckInEnabled {
            checkIns.append((.evening, eveningCheckInTime))
        }
        if bedtimeCheckInEnabled {
            checkIns.append((.bedtime, bedtimeCheckInTime))
        }

        for custom in enabledCustomCheckIns {
            checkIns.append((.custom(id: custom.id), custom.time))
        }

        return checkIns.sorted { $0.time < $1.time }
    }

    /// Check-in type enum for routing
    enum CheckInType: Identifiable, Equatable {
        case morning
        case midday
        case evening
        case bedtime
        case custom(id: UUID)

        var id: String {
            switch self {
            case .morning: return "morning"
            case .midday: return "midday"
            case .evening: return "evening"
            case .bedtime: return "bedtime"
            case .custom(let id): return "custom_\(id.uuidString)"
            }
        }
    }

    /// Add a new custom check-in
    func addCustomCheckIn(
        name: String,
        subtitle: String = "",
        icon: String = "checkmark.circle.fill",
        colorHex: String = "#10B981",
        time: Date? = nil,
        items: [CheckInItem] = []
    ) -> CustomCheckIn {
        let checkIn = CustomCheckIn(
            name: name,
            subtitle: subtitle,
            icon: icon,
            colorHex: colorHex,
            isEnabled: true,
            time: time ?? Self.defaultTime(hour: 14, minute: 0),
            items: items,
            order: customCheckIns.count
        )
        customCheckIns.append(checkIn)
        return checkIn
    }

    /// Remove a custom check-in
    func removeCustomCheckIn(id: UUID) {
        customCheckIns.removeAll { $0.id == id }
        reorderCustomCheckIns()
    }

    /// Toggle a custom check-in's enabled state
    func toggleCustomCheckIn(id: UUID) {
        if let index = customCheckIns.firstIndex(where: { $0.id == id }) {
            customCheckIns[index].isEnabled.toggle()
        }
    }

    /// Update a custom check-in
    func updateCustomCheckIn(
        id: UUID,
        name: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        isEnabled: Bool? = nil,
        time: Date? = nil,
        items: [CheckInItem]? = nil
    ) {
        if let index = customCheckIns.firstIndex(where: { $0.id == id }) {
            if let name = name { customCheckIns[index].name = name }
            if let subtitle = subtitle { customCheckIns[index].subtitle = subtitle }
            if let icon = icon { customCheckIns[index].icon = icon }
            if let colorHex = colorHex { customCheckIns[index].colorHex = colorHex }
            if let isEnabled = isEnabled { customCheckIns[index].isEnabled = isEnabled }
            if let time = time { customCheckIns[index].time = time }
            if let items = items { customCheckIns[index].items = items }
        }
    }

    /// Add an item to a custom check-in
    func addItemToCustomCheckIn(checkInId: UUID, title: String, icon: String = "checkmark.circle") {
        if let index = customCheckIns.firstIndex(where: { $0.id == checkInId }) {
            let item = CheckInItem(title: title, icon: icon, order: customCheckIns[index].items.count)
            customCheckIns[index].items.append(item)
        }
    }

    /// Remove an item from a custom check-in
    func removeItemFromCustomCheckIn(checkInId: UUID, itemId: UUID) {
        if let index = customCheckIns.firstIndex(where: { $0.id == checkInId }) {
            customCheckIns[index].items.removeAll { $0.id == itemId }
            // Reorder items
            for (i, _) in customCheckIns[index].items.enumerated() {
                customCheckIns[index].items[i].order = i
            }
        }
    }

    /// Toggle an item in a custom check-in
    func toggleItemInCustomCheckIn(checkInId: UUID, itemId: UUID) {
        if let checkInIndex = customCheckIns.firstIndex(where: { $0.id == checkInId }),
           let itemIndex = customCheckIns[checkInIndex].items.firstIndex(where: { $0.id == itemId }) {
            customCheckIns[checkInIndex].items[itemIndex].isEnabled.toggle()
        }
    }

    /// Reorder custom check-ins
    func moveCustomCheckIn(from source: IndexSet, to destination: Int) {
        customCheckIns.move(fromOffsets: source, toOffset: destination)
        reorderCustomCheckIns()
    }

    /// Get a custom check-in by ID
    func customCheckIn(for id: UUID) -> CustomCheckIn? {
        customCheckIns.first { $0.id == id }
    }

    private func reorderCustomCheckIns() {
        for (index, _) in customCheckIns.enumerated() {
            customCheckIns[index].order = index
        }
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
        customCheckIns = []  // Clear custom check-ins on reset
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

    static func defaultTime(hour: Int, minute: Int) -> Date {
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
        defaults.set(hasDeclinedCheckInSetup, forKey: keys.hasDeclinedCheckInSetup)

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

        // Save custom check-ins
        if let customData = try? JSONEncoder().encode(customCheckIns) {
            defaults.set(customData, forKey: keys.customCheckIns)
        }

        defaults.synchronize()
        print("💾 DayStructureService: Settings saved")
        
        scheduleCheckInNotifications()
    }
    
    func scheduleCheckInNotifications() {
        var checkInTimes: [DateComponents] = []
        
        if morningCheckInEnabled {
            checkInTimes.append(Calendar.current.dateComponents([.hour, .minute], from: morningCheckInTime))
        }
        if middayCheckInEnabled {
            checkInTimes.append(Calendar.current.dateComponents([.hour, .minute], from: middayCheckInTime))
        }
        if eveningCheckInEnabled {
            checkInTimes.append(Calendar.current.dateComponents([.hour, .minute], from: eveningCheckInTime))
        }
        if bedtimeCheckInEnabled {
            checkInTimes.append(Calendar.current.dateComponents([.hour, .minute], from: bedtimeCheckInTime))
        }
        
        for custom in enabledCustomCheckIns {
            checkInTimes.append(Calendar.current.dateComponents([.hour, .minute], from: custom.time))
        }
        
        let hasAnyEnabled = morningCheckInEnabled || middayCheckInEnabled || 
                           eveningCheckInEnabled || bedtimeCheckInEnabled || 
                           !enabledCustomCheckIns.isEmpty
        
        NotificationService.shared.scheduleDailyCheckIns(times: checkInTimes, enabled: hasAnyEnabled)
    }

    private func load() {
        isLoading = true

        let defaults = UserDefaults.standard
        
        let isFirstLaunch = defaults.object(forKey: keys.morningEnabled) == nil

        if isFirstLaunch {
            setupFirstLaunchDefaults()
            isLoading = false
            print("📂 DayStructureService: First launch - enabled default check-ins")
            return
        }

        morningCheckInEnabled = defaults.object(forKey: keys.morningEnabled) as? Bool ?? false
        middayCheckInEnabled = defaults.object(forKey: keys.middayEnabled) as? Bool ?? false
        eveningCheckInEnabled = defaults.object(forKey: keys.eveningEnabled) as? Bool ?? false
        bedtimeCheckInEnabled = defaults.object(forKey: keys.bedtimeEnabled) as? Bool ?? false
        hasDeclinedCheckInSetup = defaults.object(forKey: keys.hasDeclinedCheckInSetup) as? Bool ?? false

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

        if let customData = defaults.data(forKey: keys.customCheckIns),
           let items = try? JSONDecoder().decode([CustomCheckIn].self, from: customData) {
            customCheckIns = items
        } else {
            customCheckIns = []
        }

        hasCompletedSetup = defaults.bool(forKey: keys.hasCompletedSetup)

        isLoading = false
        print("📂 DayStructureService: Settings loaded")
    }
    
    private func setupFirstLaunchDefaults() {
        morningCheckInEnabled = true
        middayCheckInEnabled = true
        bedtimeCheckInEnabled = true
        eveningCheckInEnabled = false
        
        morningCheckInTime = Self.defaultTime(hour: 7, minute: 0)
        middayCheckInTime = Self.defaultTime(hour: 12, minute: 0)
        bedtimeCheckInTime = Self.defaultTime(hour: 21, minute: 0)
        
        morningItems = Self.adhdMorningItems
        bedtimeItems = Self.adhdBedtimeItems
        
        let afternoonCheckIn = CustomCheckIn(
            name: "Afternoon Reset",
            subtitle: "Energy and focus check",
            icon: "bolt.fill",
            colorHex: "#F59E0B",
            isEnabled: true,
            time: Self.defaultTime(hour: 15, minute: 0),
            items: Self.adhdAfternoonItems,
            order: 0
        )
        customCheckIns = [afternoonCheckIn]
        
        hasDeclinedCheckInSetup = true
    }
    
    static let adhdMorningItems: [CheckInItem] = [
        CheckInItem(title: "Keys, wallet, phone check", icon: "key.fill", order: 0),
        CheckInItem(title: "Take medication", icon: "pills.fill", order: 1),
        CheckInItem(title: "Eat breakfast", icon: "fork.knife", order: 2),
        CheckInItem(title: "Review today's tasks", icon: "checklist", order: 3),
        CheckInItem(title: "Set one main intention", icon: "star.fill", order: 4)
    ]
    
    static let adhdAfternoonItems: [CheckInItem] = [
        CheckInItem(title: "Drink water", icon: "drop.fill", order: 0),
        CheckInItem(title: "Quick movement break", icon: "figure.walk", order: 1),
        CheckInItem(title: "Energy level check", icon: "battery.75", order: 2),
        CheckInItem(title: "Review task progress", icon: "checklist", order: 3)
    ]
    
    static let adhdBedtimeItems: [CheckInItem] = [
        CheckInItem(title: "Keys location set", icon: "key.fill", order: 0),
        CheckInItem(title: "Wallet location set", icon: "creditcard.fill", order: 1),
        CheckInItem(title: "Phone charging", icon: "battery.100.bolt", order: 2),
        CheckInItem(title: "Devices charging", icon: "laptopcomputer", order: 3),
        CheckInItem(title: "Alarm set", icon: "alarm.fill", order: 4),
        CheckInItem(title: "Tomorrow's outfit ready", icon: "tshirt.fill", order: 5),
        CheckInItem(title: "Wind-down routine started", icon: "moon.fill", order: 6)
    ]
}
