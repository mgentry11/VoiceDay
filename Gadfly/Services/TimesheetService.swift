import Foundation
import SwiftUI

/// Tracks time spent on tasks - automatic during focus sessions + manual entries
@MainActor
class TimesheetService: ObservableObject {
    static let shared = TimesheetService()

    @Published var entries: [TimeEntry] = []
    @Published var isTracking = false
    @Published var currentEntryStart: Date?
    @Published var currentTaskName: String?

    // MARK: - Model

    struct TimeEntry: Identifiable, Codable {
        let id: UUID
        var taskName: String
        var startTime: Date
        var endTime: Date
        var durationMinutes: Int
        var wasAutomatic: Bool  // true if from focus session
        var notes: String?

        init(taskName: String, startTime: Date, endTime: Date, wasAutomatic: Bool = true, notes: String? = nil) {
            self.id = UUID()
            self.taskName = taskName
            self.startTime = startTime
            self.endTime = endTime
            self.durationMinutes = Int(endTime.timeIntervalSince(startTime) / 60)
            self.wasAutomatic = wasAutomatic
            self.notes = notes
        }
    }

    // MARK: - Init

    init() {
        loadEntries()
    }

    // MARK: - Tracking

    /// Start tracking time for a task (called when focus session starts)
    func startTracking(taskName: String) {
        currentEntryStart = Date()
        currentTaskName = taskName
        isTracking = true
        print("⏱️ Started tracking: \(taskName)")
    }

    /// Stop tracking and save entry (called when focus session ends)
    func stopTracking() {
        guard let start = currentEntryStart, let taskName = currentTaskName else {
            isTracking = false
            return
        }

        let entry = TimeEntry(
            taskName: taskName,
            startTime: start,
            endTime: Date(),
            wasAutomatic: true
        )

        // Only save if at least 1 minute
        if entry.durationMinutes >= 1 {
            entries.insert(entry, at: 0)
            saveEntries()
            print("⏱️ Saved entry: \(taskName) - \(entry.durationMinutes) minutes")
        }

        currentEntryStart = nil
        currentTaskName = nil
        isTracking = false
    }

    /// Add a manual time entry
    func addManualEntry(taskName: String, date: Date, minutes: Int, notes: String? = nil) {
        let endTime = date
        let startTime = date.addingTimeInterval(-Double(minutes * 60))

        let entry = TimeEntry(
            taskName: taskName,
            startTime: startTime,
            endTime: endTime,
            wasAutomatic: false,
            notes: notes
        )

        entries.insert(entry, at: 0)
        saveEntries()
    }

    /// Delete an entry
    func deleteEntry(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    // MARK: - Queries

    /// Get entries for today
    var todaysEntries: [TimeEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.startTime) }
    }

    /// Get entries for this week
    var thisWeeksEntries: [TimeEntry] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return entries.filter { $0.startTime >= weekAgo }
    }

    /// Total minutes today
    var totalMinutesToday: Int {
        todaysEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Total minutes this week
    var totalMinutesThisWeek: Int {
        thisWeeksEntries.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Group entries by day
    func entriesByDay(_ entries: [TimeEntry]) -> [(Date, [TimeEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.startTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    /// Group entries by task name
    func entriesByTask(_ entries: [TimeEntry]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: entries) { $0.taskName }
        return grouped.map { (task, entries) in
            (task, entries.reduce(0) { $0 + $1.durationMinutes })
        }.sorted { $0.1 > $1.1 }
    }

    // MARK: - Formatting

    func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    // MARK: - Persistence

    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "timesheet_entries")
        }
    }

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: "timesheet_entries"),
           let decoded = try? JSONDecoder().decode([TimeEntry].self, from: data) {
            entries = decoded
        }
    }

    /// Clear old entries (older than 30 days)
    func pruneOldEntries() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        entries.removeAll { $0.startTime < thirtyDaysAgo }
        saveEntries()
    }
}
