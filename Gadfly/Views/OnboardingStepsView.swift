import SwiftUI

// MARK: - Step 3: Daily Structure Setup

struct DailyStructureStep: View {
    let onComplete: () -> Void

    @ObservedObject private var dayStructure = DayStructureService.shared
    @EnvironmentObject var appState: AppState

    @State private var expandedSection: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Your Daily Structure")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Choose which check-ins you want throughout your day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Check-in sections
                VStack(spacing: 16) {
                    // Morning Check-in
                    CheckInToggleCard(
                        title: "Morning Check-in",
                        subtitle: "Start your day with intention",
                        icon: "sunrise.fill",
                        color: .orange,
                        isEnabled: $dayStructure.morningCheckInEnabled,
                        time: $dayStructure.morningCheckInTime,
                        isExpanded: expandedSection == "morning",
                        onToggleExpand: { expandedSection = expandedSection == "morning" ? nil : "morning" },
                        customizeContent: {
                            MorningItemsEditor()
                        }
                    )

                    // Midday Check-in
                    CheckInToggleCard(
                        title: "Midday Check-in",
                        subtitle: "Quick progress review",
                        icon: "sun.max.fill",
                        color: .yellow,
                        isEnabled: $dayStructure.middayCheckInEnabled,
                        time: $dayStructure.middayCheckInTime,
                        isExpanded: expandedSection == "midday",
                        onToggleExpand: { expandedSection = expandedSection == "midday" ? nil : "midday" },
                        customizeContent: {
                            Text("Reviews your progress and checks energy level")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    )

                    // Evening Check-in
                    CheckInToggleCard(
                        title: "Evening Wind-down",
                        subtitle: "Reflect on your day",
                        icon: "moon.fill",
                        color: .indigo,
                        isEnabled: $dayStructure.eveningCheckInEnabled,
                        time: $dayStructure.eveningCheckInTime,
                        isExpanded: expandedSection == "evening",
                        onToggleExpand: { expandedSection = expandedSection == "evening" ? nil : "evening" },
                        customizeContent: {
                            Text("Mood check and gentle reflection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    )

                    // Bedtime Check-in
                    CheckInToggleCard(
                        title: "Bedtime Checklist",
                        subtitle: "Make sure you're ready for tomorrow",
                        icon: "moon.stars.fill",
                        color: .purple,
                        isEnabled: $dayStructure.bedtimeCheckInEnabled,
                        time: $dayStructure.bedtimeCheckInTime,
                        isExpanded: expandedSection == "bedtime",
                        onToggleExpand: { expandedSection = expandedSection == "bedtime" ? nil : "bedtime" },
                        customizeContent: {
                            BedtimeItemsEditor()
                        }
                    )
                }
                .padding(.horizontal)

                // Continue button
                Button {
                    speakConfirmation()
                    onComplete()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            speakIntro()
        }
    }

    private func speakIntro() {
        SpeechService.shared.queueSpeech("Let's set up your daily structure. Choose which check-ins you want, and tap to customize them.")
    }

    private func speakConfirmation() {
        var enabled: [String] = []
        if dayStructure.morningCheckInEnabled { enabled.append("morning") }
        if dayStructure.middayCheckInEnabled { enabled.append("midday") }
        if dayStructure.eveningCheckInEnabled { enabled.append("evening") }
        if dayStructure.bedtimeCheckInEnabled { enabled.append("bedtime") }

        if enabled.isEmpty {
            SpeechService.shared.queueSpeech("No check-ins enabled. You can always add them later in settings.")
        } else {
            SpeechService.shared.queueSpeech("Great! You have \(enabled.count) check-ins set up.")
        }
    }
}

// MARK: - Check-in Toggle Card

struct CheckInToggleCard<CustomContent: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    @Binding var time: Date
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    @ViewBuilder let customizeContent: () -> CustomContent

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(isEnabled ? color : .gray)
                    .frame(width: 44)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isEnabled ? .primary : .secondary)

                    if isEnabled {
                        Text(timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled {
                    onToggleExpand()
                }
            }

            // Expanded content
            if isExpanded && isEnabled {
                Divider()

                VStack(spacing: 12) {
                    // Time picker
                    HStack {
                        Text("Time:")
                            .font(.subheadline)
                        Spacer()
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Custom content
                    customizeContent()
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? color.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}

// MARK: - Morning Items Editor

struct MorningItemsEditor: View {
    @ObservedObject private var dayStructure = DayStructureService.shared
    @State private var newItemText = ""
    @State private var showAddItem = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in items:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(dayStructure.morningItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.isEnabled ? .blue : .gray)
                        .frame(width: 24)

                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)
                        .strikethrough(!item.isEnabled)

                    Spacer()

                    Button {
                        dayStructure.toggleMorningItem(id: item.id)
                    } label: {
                        Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isEnabled ? .green : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Add item button
            Button {
                showAddItem = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Add custom item")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .alert("Add Morning Item", isPresented: $showAddItem) {
            TextField("Item name", text: $newItemText)
            Button("Cancel", role: .cancel) { newItemText = "" }
            Button("Add") {
                if !newItemText.isEmpty {
                    dayStructure.addMorningItem(title: newItemText)
                    newItemText = ""
                }
            }
        }
    }
}

// MARK: - Bedtime Items Editor

struct BedtimeItemsEditor: View {
    @ObservedObject private var dayStructure = DayStructureService.shared
    @State private var newItemText = ""
    @State private var showAddItem = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Things to check before bed:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(dayStructure.bedtimeItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.isEnabled ? .purple : .gray)
                        .frame(width: 24)

                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)
                        .strikethrough(!item.isEnabled)

                    Spacer()

                    Button {
                        dayStructure.toggleBedtimeItem(id: item.id)
                    } label: {
                        Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isEnabled ? .green : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Add item button
            Button {
                showAddItem = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Add custom item")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .alert("Add Bedtime Item", isPresented: $showAddItem) {
            TextField("Item name", text: $newItemText)
            Button("Cancel", role: .cancel) { newItemText = "" }
            Button("Add") {
                if !newItemText.isEmpty {
                    dayStructure.addBedtimeItem(title: newItemText)
                    newItemText = ""
                }
            }
        }
    }
}

// MARK: - Step 4: Nagging Level Setup

struct NaggingLevelStep: View {
    let onComplete: () -> Void

    @ObservedObject private var naggingService = NaggingLevelService.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)

                    Text("How Much Help?")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Choose how persistently I should remind you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Nagging level selection
                VStack(spacing: 12) {
                    ForEach(NaggingLevelService.NaggingLevel.allCases, id: \.self) { level in
                        NaggingLevelCard(
                            level: level,
                            isSelected: naggingService.naggingLevel == level,
                            onSelect: {
                                naggingService.naggingLevel = level
                                speakLevelSelected(level)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                // Self-care reminders
                VStack(alignment: .leading, spacing: 16) {
                    Text("Self-Care Reminders")
                        .font(.headline)
                        .padding(.horizontal)

                    SelfCareToggle(
                        title: "Water reminders",
                        subtitle: "Remind me to drink water",
                        icon: "drop.fill",
                        color: .blue,
                        isEnabled: $naggingService.waterRemindersEnabled
                    )

                    SelfCareToggle(
                        title: "Food reminders",
                        subtitle: "Remind me to eat",
                        icon: "fork.knife",
                        color: .orange,
                        isEnabled: $naggingService.foodRemindersEnabled
                    )

                    SelfCareToggle(
                        title: "Break reminders",
                        subtitle: "Remind me to take breaks",
                        icon: "figure.walk",
                        color: .green,
                        isEnabled: $naggingService.breakRemindersEnabled
                    )

                    SelfCareToggle(
                        title: "Sleep reminder",
                        subtitle: "Remind me when it's bedtime",
                        icon: "moon.zzz.fill",
                        color: .purple,
                        isEnabled: $naggingService.sleepReminderEnabled
                    )
                }
                .padding(.horizontal)

                // Note about changing later
                Text("You can change these anytime in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Continue button
                Button {
                    onComplete()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            speakIntro()
        }
    }

    private func speakIntro() {
        SpeechService.shared.queueSpeech("How much help do you want? Choose gentle for light reminders, moderate for supportive nudges, or persistent if you need me to really stay on you.")
    }

    private func speakLevelSelected(_ level: NaggingLevelService.NaggingLevel) {
        switch level {
        case .gentle:
            SpeechService.shared.queueSpeech("Gentle mode. I'll remind you once and let you be.")
        case .moderate:
            SpeechService.shared.queueSpeech("Moderate mode. I'll check in with supportive nudges.")
        case .persistent:
            SpeechService.shared.queueSpeech("Persistent mode. I won't let you forget!")
        }
    }
}

// MARK: - Nagging Level Card

struct NaggingLevelCard: View {
    let level: NaggingLevelService.NaggingLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: level.icon)
                    .font(.title)
                    .foregroundStyle(level.color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }
            .padding()
            .background(isSelected ? level.color.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? level.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Self Care Toggle

struct SelfCareToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? color : .gray)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal)
    }
}

// MARK: - Previews

#Preview("Daily Structure") {
    DailyStructureStep(onComplete: {})
        .environmentObject(AppState())
}

#Preview("Nagging Level") {
    NaggingLevelStep(onComplete: {})
        .environmentObject(AppState())
}
