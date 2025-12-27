import Foundation
import SwiftUI

/// Manages custom morning self-checks
/// User creates their own checklist items via voice
@MainActor
class MorningChecklistService: ObservableObject {
    static let shared = MorningChecklistService()

    // MARK: - Published State

    @Published var selfChecks: [SelfCheck] = []
    @Published var todaysProgress: [String: Bool] = [:]  // checkId: completed
    @Published var shouldShowMorningChecklist = false
    @Published var lastChecklistDate: Date?

    // MARK: - Settings

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "morning_checklist_enabled") }
    }

    @Published var triggerTime: Date {
        didSet { UserDefaults.standard.set(triggerTime, forKey: "morning_checklist_time") }
    }

    @Published var triggerOnAppOpen: Bool {
        didSet { UserDefaults.standard.set(triggerOnAppOpen, forKey: "morning_checklist_on_open") }
    }

    // MARK: - Model

    struct SelfCheck: Identifiable, Codable {
        let id: UUID
        var title: String
        var isActive: Bool
        var order: Int
        var createdAt: Date

        init(title: String, order: Int = 0) {
            self.id = UUID()
            self.title = title
            self.isActive = true
            self.order = order
            self.createdAt = Date()
        }
    }

    // MARK: - Init

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "morning_checklist_enabled")
        self.triggerOnAppOpen = UserDefaults.standard.object(forKey: "morning_checklist_on_open") as? Bool ?? true

        if let savedTime = UserDefaults.standard.object(forKey: "morning_checklist_time") as? Date {
            self.triggerTime = savedTime
        } else {
            // Default to 7 AM
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 7
            components.minute = 0
            self.triggerTime = Calendar.current.date(from: components) ?? Date()
        }

        loadSelfChecks()
        loadTodaysProgress()
    }

    // MARK: - Check Management

    func addSelfCheck(_ title: String) {
        let check = SelfCheck(title: title, order: selfChecks.count)
        selfChecks.append(check)
        saveSelfChecks()
    }

    func removeSelfCheck(at index: Int) {
        guard index < selfChecks.count else { return }
        selfChecks.remove(at: index)
        reorderChecks()
        saveSelfChecks()
    }

    func removeSelfCheck(id: UUID) {
        selfChecks.removeAll { $0.id == id }
        reorderChecks()
        saveSelfChecks()
    }

    func toggleCheckActive(id: UUID) {
        if let index = selfChecks.firstIndex(where: { $0.id == id }) {
            selfChecks[index].isActive.toggle()
            saveSelfChecks()
        }
    }

    func updateCheckTitle(id: UUID, newTitle: String) {
        if let index = selfChecks.firstIndex(where: { $0.id == id }) {
            selfChecks[index].title = newTitle
            saveSelfChecks()
        }
    }

    func moveCheck(from source: IndexSet, to destination: Int) {
        selfChecks.move(fromOffsets: source, toOffset: destination)
        reorderChecks()
        saveSelfChecks()
    }

    private func reorderChecks() {
        for (index, _) in selfChecks.enumerated() {
            selfChecks[index].order = index
        }
    }

    // MARK: - Today's Progress

    var activeChecks: [SelfCheck] {
        selfChecks.filter { $0.isActive }.sorted { $0.order < $1.order }
    }

    var completedCount: Int {
        activeChecks.filter { todaysProgress[$0.id.uuidString] == true }.count
    }

    var allCompletedToday: Bool {
        guard !activeChecks.isEmpty else { return true }
        return completedCount == activeChecks.count
    }

    func markCompleted(id: UUID, completed: Bool = true) {
        todaysProgress[id.uuidString] = completed
        saveTodaysProgress()
    }

    func isCompleted(id: UUID) -> Bool {
        todaysProgress[id.uuidString] == true
    }

    func resetTodaysProgress() {
        todaysProgress.removeAll()
        saveTodaysProgress()
    }

    // MARK: - Morning Trigger Logic

    func checkIfShouldShowChecklist() {
        guard isEnabled else {
            shouldShowMorningChecklist = false
            return
        }

        guard !activeChecks.isEmpty else {
            shouldShowMorningChecklist = false
            return
        }

        let calendar = Calendar.current
        let now = Date()

        // Check if we already showed it today
        if let lastDate = lastChecklistDate,
           calendar.isDateInToday(lastDate) {
            // Already showed today, check if all completed
            if allCompletedToday {
                shouldShowMorningChecklist = false
                return
            }
        }

        // Reset progress if it's a new day
        if let lastDate = lastChecklistDate,
           !calendar.isDateInToday(lastDate) {
            resetTodaysProgress()
        }

        if triggerOnAppOpen {
            // Check if it's morning (before noon)
            let hour = calendar.component(.hour, from: now)
            if hour < 12 && !allCompletedToday {
                shouldShowMorningChecklist = true
            }
        } else {
            // Check if current time is after trigger time
            let triggerComponents = calendar.dateComponents([.hour, .minute], from: triggerTime)
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

            if let triggerHour = triggerComponents.hour,
               let triggerMinute = triggerComponents.minute,
               let nowHour = nowComponents.hour,
               let nowMinute = nowComponents.minute {

                let triggerMinutes = triggerHour * 60 + triggerMinute
                let nowMinutes = nowHour * 60 + nowMinute

                // Show if we're past trigger time and before noon, and not completed
                if nowMinutes >= triggerMinutes && nowHour < 12 && !allCompletedToday {
                    shouldShowMorningChecklist = true
                }
            }
        }
    }

    func markChecklistShown() {
        lastChecklistDate = Date()
        UserDefaults.standard.set(lastChecklistDate, forKey: "morning_checklist_last_shown")
    }

    func dismissChecklist() {
        shouldShowMorningChecklist = false
        markChecklistShown()
    }

    // MARK: - Persistence

    private func saveSelfChecks() {
        if let encoded = try? JSONEncoder().encode(selfChecks) {
            UserDefaults.standard.set(encoded, forKey: "morning_self_checks")
        }
    }

    private func loadSelfChecks() {
        if let data = UserDefaults.standard.data(forKey: "morning_self_checks"),
           let decoded = try? JSONDecoder().decode([SelfCheck].self, from: data) {
            selfChecks = decoded.sorted { $0.order < $1.order }
        }
    }

    private func saveTodaysProgress() {
        UserDefaults.standard.set(todaysProgress, forKey: "morning_checklist_progress")
        UserDefaults.standard.set(Date(), forKey: "morning_checklist_progress_date")
    }

    private func loadTodaysProgress() {
        // Only load if it's from today
        if let progressDate = UserDefaults.standard.object(forKey: "morning_checklist_progress_date") as? Date,
           Calendar.current.isDateInToday(progressDate),
           let progress = UserDefaults.standard.dictionary(forKey: "morning_checklist_progress") as? [String: Bool] {
            todaysProgress = progress
        } else {
            todaysProgress = [:]
        }

        lastChecklistDate = UserDefaults.standard.object(forKey: "morning_checklist_last_shown") as? Date
    }

    // MARK: - Sample Checks (for first-time users)

    func addSampleChecks() {
        guard selfChecks.isEmpty else { return }

        let samples = [
            "Check my calendar for today",
            "Take my medication",
            "Review my task list",
            "Eat breakfast",
            "Check messages/email"
        ]

        for (index, title) in samples.enumerated() {
            var check = SelfCheck(title: title, order: index)
            check.isActive = true
            selfChecks.append(check)
        }

        saveSelfChecks()
    }
}
