import SwiftUI

/// View to manage user-created custom check-ins
struct ManageCustomCheckInsView: View {
    @ObservedObject private var dayStructure = DayStructureService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSheet = false
    @State private var editingCheckIn: DayStructureService.CustomCheckIn?

    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(themeColors.accent)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Check-ins")
                                .font(.headline)
                                .foregroundStyle(themeColors.text)
                            Text("Create personalized check-ins beyond the preset Morning, Midday, Evening, and Bedtime routines.")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Custom check-ins list
                Section {
                    if dayStructure.customCheckIns.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(themeColors.accent)
                            Text("No custom check-ins yet")
                                .foregroundStyle(themeColors.subtext)
                                .italic()
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(dayStructure.customCheckIns) { checkIn in
                            CustomCheckInRow(
                                checkIn: checkIn,
                                onToggle: {
                                    dayStructure.toggleCustomCheckIn(id: checkIn.id)
                                },
                                onEdit: {
                                    editingCheckIn = checkIn
                                }
                            )
                        }
                        .onDelete(perform: deleteCheckIns)
                        .onMove(perform: moveCheckIns)
                    }
                } header: {
                    HStack {
                        Text("Your Custom Check-ins")
                        Spacer()
                        Text("\(dayStructure.customCheckIns.count) items")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                }

                // Add button section
                Section {
                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.themeAccent)

                            Text("Add Custom Check-in")
                                .foregroundStyle(themeColors.text)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                }

                // Sample ideas section
                if dayStructure.customCheckIns.isEmpty {
                    Section {
                        Button {
                            addSampleCheckIns()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.orange)
                                Text("Add sample check-ins to get started")
                                    .foregroundStyle(themeColors.text)
                            }
                        }
                    } footer: {
                        Text("Examples: Medication reminder, Exercise break, Hydration check, Social time, etc.")
                    }
                }
            }
            .navigationTitle("Custom Check-ins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomCheckInSheet()
            }
            .sheet(item: $editingCheckIn) { checkIn in
                EditCustomCheckInSheet(checkIn: checkIn)
            }
        }
    }

    private func deleteCheckIns(at offsets: IndexSet) {
        for index in offsets {
            let checkIn = dayStructure.customCheckIns[index]
            dayStructure.removeCustomCheckIn(id: checkIn.id)
        }
    }

    private func moveCheckIns(from source: IndexSet, to destination: Int) {
        dayStructure.moveCustomCheckIn(from: source, to: destination)
    }

    private func addSampleCheckIns() {
        // Add some sample custom check-ins
        dayStructure.addCustomCheckIn(
            name: "Medication Reminder",
            subtitle: "Time to take your meds",
            icon: "pills.fill",
            colorHex: "#EF4444",
            time: DayStructureService.defaultTime(hour: 9, minute: 0),
            items: [
                DayStructureService.CheckInItem(title: "Take morning medication", icon: "pill.fill"),
                DayStructureService.CheckInItem(title: "Check supplement bottles", icon: "cross.vial.fill")
            ]
        )

        dayStructure.addCustomCheckIn(
            name: "Movement Break",
            subtitle: "Get up and stretch",
            icon: "figure.walk",
            colorHex: "#22C55E",
            time: DayStructureService.defaultTime(hour: 11, minute: 0),
            items: [
                DayStructureService.CheckInItem(title: "Stand up and stretch", icon: "figure.stand"),
                DayStructureService.CheckInItem(title: "Take a short walk", icon: "figure.walk"),
                DayStructureService.CheckInItem(title: "Drink water", icon: "drop.fill")
            ]
        )

        dayStructure.addCustomCheckIn(
            name: "Hydration Check",
            subtitle: "Stay hydrated",
            icon: "drop.fill",
            colorHex: "#3B82F6",
            time: DayStructureService.defaultTime(hour: 15, minute: 0),
            items: [
                DayStructureService.CheckInItem(title: "Drink a full glass of water", icon: "drop.fill"),
                DayStructureService.CheckInItem(title: "Refill water bottle", icon: "waterbottle.fill")
            ]
        )
    }
}

// MARK: - Custom Check-in Row

struct CustomCheckInRow: View {
    let checkIn: DayStructureService.CustomCheckIn
    let onToggle: () -> Void
    let onEdit: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            // Enable/disable toggle
            Button(action: onToggle) {
                Image(systemName: checkIn.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checkIn.isEnabled ? themeColors.accent : themeColors.subtext)
            }
            .buttonStyle(.plain)

            // Icon with color
            ZStack {
                Circle()
                    .fill(Color(hex: checkIn.colorHex).opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: checkIn.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: checkIn.colorHex))
            }

            // Name and time
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.name)
                    .foregroundStyle(checkIn.isEnabled ? themeColors.text : themeColors.subtext)
                    .strikethrough(!checkIn.isEnabled)

                Text(timeFormatter.string(from: checkIn.time))
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }

            Spacer()

            // Item count
            Text("\(checkIn.items.count) items")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Add Custom Check-in Sheet

struct AddCustomCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var dayStructure = DayStructureService.shared

    @State private var name = ""
    @State private var subtitle = ""
    @State private var selectedIcon = "checkmark.circle.fill"
    @State private var selectedColorHex = "#10B981"
    @State private var selectedTime = Date()
    @State private var items: [DayStructureService.CheckInItem] = []
    @State private var newItemTitle = ""

    private let iconOptions = [
        "checkmark.circle.fill", "star.fill", "heart.fill", "bolt.fill",
        "figure.walk", "figure.run", "pills.fill", "drop.fill",
        "cup.and.saucer.fill", "fork.knife", "book.fill", "pencil",
        "phone.fill", "envelope.fill", "bell.fill", "alarm.fill",
        "brain.head.profile", "leaf.fill", "sun.max.fill", "moon.fill"
    ]

    private let colorOptions = [
        "#10B981", // Emerald
        "#22C55E", // Green
        "#3B82F6", // Blue
        "#8B5CF6", // Purple
        "#EF4444", // Red
        "#F97316", // Orange
        "#FFBF00", // Amber
        "#EC4899"  // Pink
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Basic info section
                Section {
                    TextField("Check-in Name", text: $name)
                    TextField("Subtitle (optional)", text: $subtitle)
                } header: {
                    Text("Basic Info")
                }

                // Time section
                Section {
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("Schedule")
                }

                // Icon section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex) : Color.gray.opacity(0.2))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(selectedIcon == icon ? .white : themeColors.text)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }

                // Color section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 44, height: 44)

                                    if selectedColorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                // Items section
                Section {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundStyle(Color(hex: selectedColorHex))
                            Text(item.title)
                                .foregroundStyle(themeColors.text)
                        }
                    }
                    .onDelete(perform: deleteItem)

                    // Add new item row
                    HStack {
                        TextField("Add item...", text: $newItemTitle)

                        Button {
                            addItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(newItemTitle.isEmpty ? .gray : Color.themeAccent)
                        }
                        .disabled(newItemTitle.isEmpty)
                    }
                } header: {
                    Text("Check-in Items")
                } footer: {
                    Text("Items to check off during this check-in")
                }

                // Preview section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColorHex).opacity(0.2))
                                .frame(width: 50, height: 50)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 24))
                                .foregroundStyle(Color(hex: selectedColorHex))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "Check-in Name" : name)
                                .font(.headline)
                                .foregroundStyle(themeColors.text)

                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(themeColors.subtext)
                            }

                            Text(timeFormatter.string(from: selectedTime))
                                .font(.caption)
                                .foregroundStyle(Color(hex: selectedColorHex))
                        }

                        Spacer()

                        Text("\(items.count) items")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("New Custom Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        saveCheckIn()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private func addItem() {
        guard !newItemTitle.isEmpty else { return }
        let newItem = DayStructureService.CheckInItem(
            title: newItemTitle.trimmingCharacters(in: .whitespaces),
            icon: "checkmark.circle"
        )
        items.append(newItem)
        newItemTitle = ""
    }

    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func saveCheckIn() {
        dayStructure.addCustomCheckIn(
            name: name.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorHex: selectedColorHex,
            time: selectedTime,
            items: items
        )
        dismiss()
    }
}

// MARK: - Edit Custom Check-in Sheet

struct EditCustomCheckInSheet: View {
    let checkIn: DayStructureService.CustomCheckIn

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var dayStructure = DayStructureService.shared

    @State private var name: String
    @State private var subtitle: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var selectedTime: Date
    @State private var items: [DayStructureService.CheckInItem]
    @State private var newItemTitle = ""
    @State private var showDeleteConfirmation = false

    init(checkIn: DayStructureService.CustomCheckIn) {
        self.checkIn = checkIn
        self._name = State(initialValue: checkIn.name)
        self._subtitle = State(initialValue: checkIn.subtitle)
        self._selectedIcon = State(initialValue: checkIn.icon)
        self._selectedColorHex = State(initialValue: checkIn.colorHex)
        self._selectedTime = State(initialValue: checkIn.time)
        self._items = State(initialValue: checkIn.items)
    }

    private let iconOptions = [
        "checkmark.circle.fill", "star.fill", "heart.fill", "bolt.fill",
        "figure.walk", "figure.run", "pills.fill", "drop.fill",
        "cup.and.saucer.fill", "fork.knife", "book.fill", "pencil",
        "phone.fill", "envelope.fill", "bell.fill", "alarm.fill",
        "brain.head.profile", "leaf.fill", "sun.max.fill", "moon.fill"
    ]

    private let colorOptions = [
        "#10B981", // Emerald
        "#22C55E", // Green
        "#3B82F6", // Blue
        "#8B5CF6", // Purple
        "#EF4444", // Red
        "#F97316", // Orange
        "#FFBF00", // Amber
        "#EC4899"  // Pink
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Basic info section
                Section {
                    TextField("Check-in Name", text: $name)
                    TextField("Subtitle (optional)", text: $subtitle)
                } header: {
                    Text("Basic Info")
                }

                // Time section
                Section {
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("Schedule")
                }

                // Icon section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex) : Color.gray.opacity(0.2))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(selectedIcon == icon ? .white : themeColors.text)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }

                // Color section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 44, height: 44)

                                    if selectedColorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                // Items section
                Section {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundStyle(Color(hex: selectedColorHex))
                            Text(item.title)
                                .foregroundStyle(themeColors.text)
                        }
                    }
                    .onDelete(perform: deleteItem)

                    // Add new item row
                    HStack {
                        TextField("Add item...", text: $newItemTitle)

                        Button {
                            addItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(newItemTitle.isEmpty ? .gray : Color.themeAccent)
                        }
                        .disabled(newItemTitle.isEmpty)
                    }
                } header: {
                    Text("Check-in Items")
                }

                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete this check-in")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Check-in")
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
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete \"\(checkIn.name)\"?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    dayStructure.removeCustomCheckIn(id: checkIn.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func addItem() {
        guard !newItemTitle.isEmpty else { return }
        let newItem = DayStructureService.CheckInItem(
            title: newItemTitle.trimmingCharacters(in: .whitespaces),
            icon: "checkmark.circle"
        )
        items.append(newItem)
        newItemTitle = ""
    }

    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func saveChanges() {
        dayStructure.updateCustomCheckIn(
            id: checkIn.id,
            name: name.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorHex: selectedColorHex,
            isEnabled: checkIn.isEnabled,
            time: selectedTime,
            items: items
        )
        dismiss()
    }
}

#Preview {
    ManageCustomCheckInsView()
}
