import SwiftUI
import EventKit

struct CalendarListView: View {
    @StateObject private var calendarService = CalendarService()
    @State private var events: [EKEvent] = []
    @State private var isLoading = true
    @State private var selectedDays = 7
    @State private var selectedEvent: EKEvent?
    @State private var showingDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading events...")
                } else if events.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Next 7 days") { selectedDays = 7; loadEvents() }
                        Button("Next 14 days") { selectedDays = 14; loadEvents() }
                        Button("Next 30 days") { selectedDays = 30; loadEvents() }
                    } label: {
                        Label("\(selectedDays) days", systemImage: "calendar")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadEvents()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let event = selectedEvent {
                    EventDetailView(
                        event: event,
                        calendarService: calendarService,
                        onUpdate: { loadEvents() }
                    )
                }
            }
        }
        .task {
            _ = await calendarService.requestCalendarAccess()
            loadEvents()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Upcoming Events",
            systemImage: "calendar",
            description: Text("Events you create through voice dictation will appear here.")
        )
    }

    private var eventsList: some View {
        List {
            ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                Section {
                    ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .listRowBackground(Color.themeSecondary)
                            .onTapGesture {
                                selectedEvent = event
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        deleteEvents(at: indexSet, for: date)
                    }
                } header: {
                    HStack {
                        Text(date, style: .date)
                            .foregroundStyle(Color.themeSubtext)
                        if Calendar.current.isDateInToday(date) {
                            Text("Today")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.themeAccent.opacity(0.2))
                                .foregroundStyle(Color.themeAccent)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .refreshable {
            loadEvents()
        }
    }

    private var groupedEvents: [Date: [EKEvent]] {
        let calendar = Calendar.current
        var grouped: [Date: [EKEvent]] = [:]

        for event in events {
            let startOfDay = calendar.startOfDay(for: event.startDate)
            if grouped[startOfDay] == nil {
                grouped[startOfDay] = []
            }
            grouped[startOfDay]?.append(event)
        }

        return grouped
    }

    private func loadEvents() {
        isLoading = true
        events = calendarService.fetchUpcomingEvents(days: selectedDays)
        isLoading = false
    }

    private func deleteEvents(at offsets: IndexSet, for date: Date) {
        guard let eventsForDate = groupedEvents[date] else { return }
        for index in offsets {
            let event = eventsForDate[index]
            try? calendarService.deleteEvent(event)
        }
        loadEvents()
    }
}

struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(timeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if event.isAllDay {
            return "All day"
        }

        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }
}

struct EventDetailView: View {
    let event: EKEvent
    let calendarService: CalendarService
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isAllDay: Bool = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)

                    TextField("Location", text: $location)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("All Day", isOn: $isAllDay)

                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }

                Section {
                    HStack {
                        Text("Calendar")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 10, height: 10)
                            Text(event.calendar.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        try? calendarService.deleteEvent(event)
                        onUpdate()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear {
                title = event.title ?? ""
                location = event.location ?? ""
                notes = event.notes ?? ""
                startDate = event.startDate
                endDate = event.endDate
                isAllDay = event.isAllDay
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue {
                    endDate = newValue.addingTimeInterval(3600)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        do {
            var adjustedEndDate = endDate
            if isAllDay {
                // For all-day events, end date should be start of next day
                adjustedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: startDate)) ?? endDate
            }

            try calendarService.updateEvent(
                event,
                title: title,
                startDate: startDate,
                endDate: adjustedEndDate,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes
            )
            event.isAllDay = isAllDay
            onUpdate()
            dismiss()
        } catch {
            print("Error saving: \(error)")
        }
        isSaving = false
    }
}

#Preview {
    CalendarListView()
}
