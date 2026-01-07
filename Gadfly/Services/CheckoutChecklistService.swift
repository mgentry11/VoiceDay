import Foundation
import SwiftUI

/// Manages checkout checklists for saved locations
/// Each location can have its own checklist that triggers on exit
@MainActor
class CheckoutChecklistService: ObservableObject {
    static let shared = CheckoutChecklistService()

    // MARK: - Published State

    @Published var checklistsByLocation: [UUID: [ChecklistItem]] = [:]
    @Published var todaysProgress: [String: Bool] = [:] // itemId: completed
    @Published var activeChecklist: ActiveCheckout?
    @Published var showingCheckout = false

    // MARK: - Models

    struct ChecklistItem: Identifiable, Codable {
        let id: UUID
        var title: String
        var isActive: Bool
        var order: Int
        var isExternalAppLink: Bool
        var appScheme: String? // e.g., "onerepstrength://" for deep linking

        init(title: String, order: Int = 0, isExternalAppLink: Bool = false, appScheme: String? = nil) {
            self.id = UUID()
            self.title = title
            self.isActive = true
            self.order = order
            self.isExternalAppLink = isExternalAppLink
            self.appScheme = appScheme
        }
    }

    struct ActiveCheckout: Identifiable {
        let id: UUID
        let location: LocationService.SavedLocation
        let startedAt: Date
        var items: [ChecklistItem]
    }

    // MARK: - Init

    init() {
        loadChecklists()
        loadTodaysProgress()
    }

    // MARK: - Checklist Management

    func getChecklist(for locationId: UUID) -> [ChecklistItem] {
        return (checklistsByLocation[locationId] ?? []).sorted { $0.order < $1.order }
    }

    func addItem(to locationId: UUID, title: String, isExternalAppLink: Bool = false, appScheme: String? = nil) {
        var items = checklistsByLocation[locationId] ?? []
        let item = ChecklistItem(
            title: title,
            order: items.count,
            isExternalAppLink: isExternalAppLink,
            appScheme: appScheme
        )
        items.append(item)
        checklistsByLocation[locationId] = items
        saveChecklists()
    }

    func removeItem(from locationId: UUID, itemId: UUID) {
        var items = checklistsByLocation[locationId] ?? []
        items.removeAll { $0.id == itemId }
        reorderItems(&items)
        checklistsByLocation[locationId] = items
        saveChecklists()
    }

    func updateItem(in locationId: UUID, item: ChecklistItem) {
        var items = checklistsByLocation[locationId] ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            checklistsByLocation[locationId] = items
            saveChecklists()
        }
    }

    func moveItem(in locationId: UUID, from source: IndexSet, to destination: Int) {
        var items = checklistsByLocation[locationId] ?? []
        items.move(fromOffsets: source, toOffset: destination)
        reorderItems(&items)
        checklistsByLocation[locationId] = items
        saveChecklists()
    }

    private func reorderItems(_ items: inout [ChecklistItem]) {
        for (index, _) in items.enumerated() {
            items[index].order = index
        }
    }

    // MARK: - Default Checklists

    func initializeDefaultChecklist(for location: LocationService.SavedLocation, preset: LocationService.LocationPreset) {
        let defaultItems = preset.defaultChecklistItems
        var items: [ChecklistItem] = []

        for (index, title) in defaultItems.enumerated() {
            // Special handling for gym preset - add OneRepStrength link
            var isAppLink = false
            var appScheme: String? = nil

            if preset == .gym && title.contains("fitness app") {
                isAppLink = true
                appScheme = "onerepstrength://"
            }

            items.append(ChecklistItem(
                title: title,
                order: index,
                isExternalAppLink: isAppLink,
                appScheme: appScheme
            ))
        }

        checklistsByLocation[location.id] = items
        saveChecklists()
    }

    // MARK: - Progress Tracking

    func markCompleted(itemId: UUID, completed: Bool = true) {
        todaysProgress[itemId.uuidString] = completed
        saveTodaysProgress()
    }

    func isCompleted(itemId: UUID) -> Bool {
        todaysProgress[itemId.uuidString] == true
    }

    func resetProgressForLocation(_ locationId: UUID) {
        let items = getChecklist(for: locationId)
        for item in items {
            todaysProgress.removeValue(forKey: item.id.uuidString)
        }
        saveTodaysProgress()
    }

    // MARK: - Active Checkout Session

    func startCheckout(for location: LocationService.SavedLocation) {
        let items = getChecklist(for: location.id).filter { $0.isActive }

        guard !items.isEmpty else {
            print("No checklist items for location: \(location.name)")
            return
        }

        activeChecklist = ActiveCheckout(
            id: UUID(),
            location: location,
            startedAt: Date(),
            items: items
        )
        showingCheckout = true

        print("Started checkout for: \(location.name) with \(items.count) items")
    }

    func completeCheckout() {
        activeChecklist = nil
        showingCheckout = false
    }

    func dismissCheckout() {
        activeChecklist = nil
        showingCheckout = false
    }

    var currentCheckoutProgress: (completed: Int, total: Int) {
        guard let checkout = activeChecklist else { return (0, 0) }
        let completed = checkout.items.filter { isCompleted(itemId: $0.id) }.count
        return (completed, checkout.items.count)
    }

    var isCurrentCheckoutComplete: Bool {
        let progress = currentCheckoutProgress
        return progress.total > 0 && progress.completed == progress.total
    }

    // MARK: - App Links

    func openAppLink(for item: ChecklistItem) {
        guard let scheme = item.appScheme,
              let url = URL(string: scheme) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // App not installed - could prompt to download
            print("App not installed for scheme: \(scheme)")
        }
    }

    // MARK: - Persistence

    private func saveChecklists() {
        // Convert UUID keys to strings for JSON encoding
        var stringKeyedDict: [String: [ChecklistItem]] = [:]
        for (key, value) in checklistsByLocation {
            stringKeyedDict[key.uuidString] = value
        }

        if let encoded = try? JSONEncoder().encode(stringKeyedDict) {
            UserDefaults.standard.set(encoded, forKey: "checkout_checklists")
        }
    }

    private func loadChecklists() {
        if let data = UserDefaults.standard.data(forKey: "checkout_checklists"),
           let stringKeyedDict = try? JSONDecoder().decode([String: [ChecklistItem]].self, from: data) {
            checklistsByLocation = [:]
            for (key, value) in stringKeyedDict {
                if let uuid = UUID(uuidString: key) {
                    checklistsByLocation[uuid] = value
                }
            }
        }
    }

    private func saveTodaysProgress() {
        UserDefaults.standard.set(todaysProgress, forKey: "checkout_progress")
        UserDefaults.standard.set(Date(), forKey: "checkout_progress_date")
    }

    private func loadTodaysProgress() {
        // Only load if it's from today
        if let progressDate = UserDefaults.standard.object(forKey: "checkout_progress_date") as? Date,
           Calendar.current.isDateInToday(progressDate),
           let progress = UserDefaults.standard.dictionary(forKey: "checkout_progress") as? [String: Bool] {
            todaysProgress = progress
        } else {
            todaysProgress = [:]
        }
    }
}
