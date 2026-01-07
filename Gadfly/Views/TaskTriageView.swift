import SwiftUI
import AVFoundation
import EventKit

/// Help user strip down their task list to essentials
/// One task at a time - bot asks, user responds with big buttons
struct TaskTriageView: View {
    let tasks: [EKReminder]
    let calendarService: CalendarService
    let onComplete: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var currentIndex = 0
    @State private var categorizedTasks: [TaskCategory: [EKReminder]] = [
        .mustDo: [],
        .wantTo: [],
        .avoidingButMust: [],
        .canWait: [],
        .delete: []
    ]
    @State private var isProcessing = false
    @State private var showingSummary = false


    enum TaskCategory: String, CaseIterable {
        case mustDo = "Must do today"
        case wantTo = "Want to do"
        case avoidingButMust = "Avoiding but must"
        case canWait = "Can wait"
        case delete = "Delete"

        var icon: String {
            switch self {
            case .mustDo: return "exclamationmark.circle.fill"
            case .wantTo: return "heart.fill"
            case .avoidingButMust: return "face.dashed"
            case .canWait: return "arrow.right.circle.fill"
            case .delete: return "trash.fill"
            }
        }

        var color: Color {
            switch self {
            case .mustDo: return .red
            case .wantTo: return .green
            case .avoidingButMust: return .orange
            case .canWait: return .blue
            case .delete: return .gray
            }
        }
    }

    var currentTask: EKReminder? {
        guard currentIndex < tasks.count else { return nil }
        return tasks[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            if showingSummary {
                summaryView
            } else if let task = currentTask {
                triageView(for: task)
            } else {
                // No tasks
                noTasksView
            }
        }
        .onAppear {
            speakIntro()
        }
    }

    // MARK: - Triage View

    private func triageView(for task: EKReminder) -> some View {
        VStack(spacing: 24) {
            // Progress
            VStack(spacing: 8) {
                Text("Task \(currentIndex + 1) of \(tasks.count)")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                ProgressView(value: Double(currentIndex), total: Double(tasks.count))
                    .tint(Color.themeAccent)
            }
            .padding(.top)

            Spacer()

            // Personality asking
            VStack(spacing: 16) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 60))

                Text(getTriageQuestion())
                    .font(.title3)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
            }

            // Task name - big and clear
            Text(task.title ?? "Untitled")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.themeSecondary)
                .cornerRadius(16)

            Spacer()

            // Category buttons - BIG
            VStack(spacing: 12) {
                // Top row - essential
                HStack(spacing: 12) {
                    CategoryButton(category: .mustDo) {
                        categorize(task, as: .mustDo)
                    }
                    CategoryButton(category: .wantTo) {
                        categorize(task, as: .wantTo)
                    }
                }

                // Middle row
                HStack(spacing: 12) {
                    CategoryButton(category: .avoidingButMust) {
                        categorize(task, as: .avoidingButMust)
                    }
                    CategoryButton(category: .canWait) {
                        categorize(task, as: .canWait)
                    }
                }

                // Delete row
                CategoryButton(category: .delete, fullWidth: true) {
                    categorize(task, as: .delete)
                }
            }
            .padding(.bottom)
        }
        .padding()
    }

    // MARK: - Summary View

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celebration
                VStack(spacing: 12) {
                    Text("🎯")
                        .font(.system(size: 60))

                    Text("List sorted!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)

                    Text(getSummaryMessage())
                        .font(.body)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Category summaries
                VStack(spacing: 16) {
                    if !categorizedTasks[.mustDo]!.isEmpty {
                        CategorySummary(
                            category: .mustDo,
                            tasks: categorizedTasks[.mustDo]!
                        )
                    }

                    if !categorizedTasks[.wantTo]!.isEmpty {
                        CategorySummary(
                            category: .wantTo,
                            tasks: categorizedTasks[.wantTo]!
                        )
                    }

                    if !categorizedTasks[.avoidingButMust]!.isEmpty {
                        CategorySummary(
                            category: .avoidingButMust,
                            tasks: categorizedTasks[.avoidingButMust]!
                        )
                    }

                    if !categorizedTasks[.canWait]!.isEmpty {
                        CategorySummary(
                            category: .canWait,
                            tasks: categorizedTasks[.canWait]!,
                            note: "Pushed to tomorrow"
                        )
                    }

                    if !categorizedTasks[.delete]!.isEmpty {
                        CategorySummary(
                            category: .delete,
                            tasks: categorizedTasks[.delete]!,
                            note: "Removed"
                        )
                    }
                }

                // Today's focus
                todaysFocusSection

                // Done button
                Button {
                    applyChanges()
                } label: {
                    Text("Let's do this")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                }
                .padding(.vertical)
            }
            .padding()
        }
    }

    private var todaysFocusSection: some View {
        VStack(spacing: 12) {
            Text("Today's Focus")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            let todayTasks = (categorizedTasks[.mustDo] ?? []) +
                             (categorizedTasks[.avoidingButMust] ?? []) +
                             (categorizedTasks[.wantTo] ?? [])

            Text("\(todayTasks.count) tasks")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeAccent)

            if todayTasks.count <= 3 {
                Text("Perfect! A focused list.")
                    .font(.caption)
                    .foregroundStyle(themeColors.success)
            } else if todayTasks.count <= 5 {
                Text("Manageable. You've got this.")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            } else {
                Text("Consider pushing more to tomorrow.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }

    // MARK: - No Tasks View

    private var noTasksView: some View {
        VStack(spacing: 24) {
            Text("✨")
                .font(.system(size: 60))

            Text("No tasks to sort!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeColors.text)

            Button {
                onComplete()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func categorize(_ task: EKReminder, as category: TaskCategory) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        categorizedTasks[category]?.append(task)

        // Speak acknowledgment
        speakCategoryResponse(category)

        // Move to next
        withAnimation(.spring(response: 0.3)) {
            if currentIndex < tasks.count - 1 {
                currentIndex += 1
            } else {
                showingSummary = true
                speakSummary()
            }
        }
    }

    private func applyChanges() {
        isProcessing = true

        Task {
            // Push "can wait" to tomorrow
            for task in categorizedTasks[.canWait] ?? [] {
                try? await calendarService.pushToTomorrow(task)
            }

            // Delete removed tasks
            for task in categorizedTasks[.delete] ?? [] {
                try? await calendarService.deleteReminder(task)
            }

            await MainActor.run {
                isProcessing = false
                onComplete()
            }
        }
    }

    // MARK: - Voice

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    private func speakIntro() {
        let message = "Let's sort through your tasks. For each one, tell me: is it essential today, or can it wait?"
        speak(message)
    }

    private func speakCategoryResponse(_ category: TaskCategory) {
        let responses: [TaskCategory: [String]] = [
            .mustDo: ["Got it, essential.", "On the list.", "Priority one."],
            .wantTo: ["Nice, something you enjoy!", "Good motivation.", "Love it."],
            .avoidingButMust: ["I hear you. We'll tackle it together.", "Acknowledged. No judgment.", "We'll get through it."],
            .canWait: ["Tomorrow it is.", "Pushed.", "One less thing today."],
            .delete: ["Gone.", "Deleted.", "Off the list."]
        ]

        if let options = responses[category], let message = options.randomElement() {
            speak(message)
        }
    }

    private func speakSummary() {
        let todayCount = (categorizedTasks[.mustDo]?.count ?? 0) +
                        (categorizedTasks[.avoidingButMust]?.count ?? 0) +
                        (categorizedTasks[.wantTo]?.count ?? 0)

        let message = "Done! You have \(todayCount) tasks for today. That's a focused list."
        speak(message)
    }

    private func getTriageQuestion() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Is this truly necessary, or merely cluttering your existence?"
        case .sergent:
            return "Is this mission-critical or can it wait?"
        case .cheerleader:
            return "How do you feel about this one?"
        case .therapist:
            return "What comes up for you with this task?"
        case .bestie:
            return "Okay real talk - do we need this today?"
        default:
            return "What about this one?"
        }
    }

    private func getSummaryMessage() -> String {
        let pushed = categorizedTasks[.canWait]?.count ?? 0
        let deleted = categorizedTasks[.delete]?.count ?? 0

        if pushed > 0 && deleted > 0 {
            return "Pushed \(pushed) to tomorrow, removed \(deleted). Much cleaner!"
        } else if pushed > 0 {
            return "Pushed \(pushed) to tomorrow. Less pressure today."
        } else if deleted > 0 {
            return "Removed \(deleted) tasks. Freedom!"
        } else {
            return "Everything stays for today. Let's do this!"
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: TaskTriageView.TaskCategory
    var fullWidth: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(category == .delete ? .white : .white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(category.color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Category Summary

struct CategorySummary: View {
    let category: TaskTriageView.TaskCategory
    let tasks: [EKReminder]
    var note: String? = nil

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.text)

                Spacer()

                Text("\(tasks.count)")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)

                if let note = note {
                    Text("• \(note)")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
            }

            ForEach(tasks, id: \.calendarItemIdentifier) { task in
                Text("• \(task.title ?? "Untitled")")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    TaskTriageView(
        tasks: [],
        calendarService: CalendarService(),
        onComplete: {}
    )
    .environmentObject(AppState())
}
