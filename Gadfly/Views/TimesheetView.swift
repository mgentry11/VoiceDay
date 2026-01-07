import SwiftUI

/// View timesheet entries - daily/weekly summaries
struct TimesheetView: View {
    @ObservedObject private var timesheetService = TimesheetService.shared
    @ObservedObject private var themeColors = ThemeColors.shared

    @State private var selectedTab = 0  // 0 = Today, 1 = Week, 2 = By Task
    @State private var showingAddEntry = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary cards
                summaryCards
                    .padding()

                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Today").tag(0)
                    Text("This Week").tag(1)
                    Text("By Task").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedTab {
                        case 0:
                            todayView
                        case 1:
                            weekView
                        case 2:
                            byTaskView
                        default:
                            todayView
                        }
                    }
                    .padding()
                }
            }
            .background(Color.themeBackground)
            .navigationTitle("Timesheet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.themeAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddTimeEntrySheet()
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            // Today
            SummaryCard(
                title: "Today",
                value: timesheetService.formatDuration(timesheetService.totalMinutesToday),
                icon: "clock.fill",
                color: .blue
            )

            // This Week
            SummaryCard(
                title: "This Week",
                value: timesheetService.formatDuration(timesheetService.totalMinutesThisWeek),
                icon: "calendar",
                color: .green
            )

            // Active
            if timesheetService.isTracking {
                SummaryCard(
                    title: "Tracking",
                    value: timesheetService.currentTaskName ?? "Task",
                    icon: "record.circle",
                    color: .red
                )
            }
        }
    }

    // MARK: - Today View

    private var todayView: some View {
        Group {
            if timesheetService.todaysEntries.isEmpty {
                emptyState("No time tracked today")
            } else {
                ForEach(timesheetService.todaysEntries) { entry in
                    TimeEntryRow(entry: entry)
                }
            }
        }
    }

    // MARK: - Week View

    private var weekView: some View {
        Group {
            let byDay = timesheetService.entriesByDay(timesheetService.thisWeeksEntries)

            if byDay.isEmpty {
                emptyState("No time tracked this week")
            } else {
                ForEach(byDay, id: \.0) { day, entries in
                    VStack(alignment: .leading, spacing: 8) {
                        // Day header
                        HStack {
                            Text(formatDayHeader(day))
                                .font(.headline)
                                .foregroundStyle(themeColors.text)

                            Spacer()

                            Text(timesheetService.formatDuration(entries.reduce(0) { $0 + $1.durationMinutes }))
                                .font(.subheadline)
                                .foregroundStyle(themeColors.accent)
                        }

                        // Entries
                        ForEach(entries) { entry in
                            TimeEntryRow(entry: entry, compact: true)
                        }
                    }
                    .padding()
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - By Task View

    private var byTaskView: some View {
        Group {
            let byTask = timesheetService.entriesByTask(timesheetService.thisWeeksEntries)

            if byTask.isEmpty {
                emptyState("No time tracked this week")
            } else {
                ForEach(byTask, id: \.0) { taskName, totalMinutes in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(taskName)
                                .font(.headline)
                                .foregroundStyle(themeColors.text)
                                .lineLimit(2)

                            Text("This week")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }

                        Spacer()

                        Text(timesheetService.formatDuration(totalMinutes))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColors.accent)
                    }
                    .padding()
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(themeColors.subtext)

            Text(message)
                .foregroundStyle(themeColors.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .foregroundStyle(themeColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(themeColors.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Time Entry Row

struct TimeEntryRow: View {
    let entry: TimesheetService.TimeEntry
    var compact: Bool = false

    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var timesheetService = TimesheetService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: entry.wasAutomatic ? "scope" : "hand.raised")
                .font(compact ? .caption : .body)
                .foregroundStyle(entry.wasAutomatic ? themeColors.accent : .orange)
                .frame(width: compact ? 20 : 30)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName)
                    .font(compact ? .subheadline : .body)
                    .foregroundStyle(themeColors.text)
                    .lineLimit(1)

                if !compact {
                    Text(formatTimeRange(entry.startTime, entry.endTime))
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
            }

            Spacer()

            // Duration
            Text(timesheetService.formatDuration(entry.durationMinutes))
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(themeColors.accent)
        }
        .padding(compact ? 8 : 12)
        .background(compact ? Color.clear : Color.themeSecondary)
        .cornerRadius(compact ? 0 : 10)
    }

    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Add Time Entry Sheet

struct AddTimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var timesheetService = TimesheetService.shared

    @State private var taskName = ""
    @State private var duration = 30
    @State private var date = Date()
    @State private var notes = ""

    private let durationOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task name", text: $taskName)
                } header: {
                    Text("What did you work on?")
                }

                Section {
                    Picker("Duration", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { mins in
                            Text(timesheetService.formatDuration(mins)).tag(mins)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Time")
                }

                Section {
                    TextField("Notes (optional)", text: $notes)
                } header: {
                    Text("Notes")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Add Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(taskName.isEmpty)
                }
            }
        }
    }

    private func saveEntry() {
        timesheetService.addManualEntry(
            taskName: taskName,
            date: date,
            minutes: duration,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

#Preview {
    TimesheetView()
}
