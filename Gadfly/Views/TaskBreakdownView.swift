import SwiftUI

// MARK: - Task Breakdown View

/// Voice-first breakdown of big tasks into small steps
/// User just talks, app figures out the pieces
struct TaskBreakdownView: View {
    let task: GadflyTask
    @Binding var isPresented: Bool
    let onCreateSubtasks: ([String]) -> Void

    @State private var isRecording = false
    @State private var rawInput = ""
    @State private var extractedSteps: [ExtractedStep] = []
    @State private var showingSuggestions = true

    @StateObject private var advisor = TaskAttackAdvisor.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Voice input area
                    voiceInputSection

                    // Suggested breakdown (from AI)
                    if showingSuggestions {
                        suggestionsSection
                    }

                    // Extracted steps from user input
                    if !extractedSteps.isEmpty {
                        extractedStepsSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Break it down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let steps = extractedSteps.filter { $0.isSelected }.map { $0.text }
                        onCreateSubtasks(steps)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(extractedSteps.filter { $0.isSelected }.isEmpty)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(task.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Let's split this into smaller pieces")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Voice Input

    @ViewBuilder
    private var voiceInputSection: some View {
        VStack(spacing: 16) {
            // Big record button
            Button {
                isRecording.toggle()
                if !isRecording && !rawInput.isEmpty {
                    processInput(rawInput)
                }
            } label: {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                    Text(isRecording ? "Tap when done" : "Tap and tell me the steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Text input fallback
            VStack(spacing: 8) {
                Text("or type them out")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                TextField("Step 1, step 2, step 3...", text: $rawInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .onSubmit {
                        processInput(rawInput)
                    }

                if !rawInput.isEmpty {
                    Button("Process") {
                        processInput(rawInput)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        let analysis = advisor.analyzeTask(task)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Here's one way to break it down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingSuggestions = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            ForEach(analysis.breakdownSuggestions.indices, id: \.self) { index in
                Button {
                    addSuggestedStep(analysis.breakdownSuggestions[index])
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.purple))

                        Text(analysis.breakdownSuggestions[index])
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "plus.circle")
                            .foregroundStyle(.purple)
                    }
                    .padding(.vertical, 8)
                }
            }

            Button {
                // Add all suggestions
                for step in analysis.breakdownSuggestions {
                    addSuggestedStep(step)
                }
                showingSuggestions = false
            } label: {
                Text("Use all these")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
        )
    }

    // MARK: - Extracted Steps

    @ViewBuilder
    private var extractedStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your steps")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach($extractedSteps) { $step in
                HStack(spacing: 12) {
                    Button {
                        step.isSelected.toggle()
                    } label: {
                        Image(systemName: step.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(step.isSelected ? .green : .secondary)
                    }

                    Text(step.text)
                        .font(.subheadline)
                        .strikethrough(!step.isSelected, color: .secondary)
                        .foregroundStyle(step.isSelected ? .primary : .secondary)

                    Spacer()

                    // Delete
                    Button {
                        extractedSteps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
            }

            // Add another manually
            Button {
                extractedSteps.append(ExtractedStep(text: "New step", isSelected: true))
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add another step")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Helpers

    private func processInput(_ input: String) {
        // Simple step extraction from natural language
        // In production, this would use AI for better parsing

        let steps = extractStepsFromText(input)
        for step in steps {
            if !extractedSteps.contains(where: { $0.text.lowercased() == step.lowercased() }) {
                extractedSteps.append(ExtractedStep(text: step, isSelected: true))
            }
        }

        rawInput = ""
    }

    private func extractStepsFromText(_ text: String) -> [String] {
        var steps: [String] = []

        // Split by common separators
        let separators: [String] = ["\n", ",", " then ", " and then ", " after that ", ". "]

        var remaining = text

        for separator in separators {
            let parts = remaining.components(separatedBy: separator)
            if parts.count > 1 {
                steps.append(contentsOf: parts)
                remaining = ""
                break
            }
        }

        if steps.isEmpty {
            // If no separators found, treat whole thing as one step
            steps = [text]
        }

        // Clean up steps
        return steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 2 }
            .map { step in
                // Capitalize first letter
                step.prefix(1).uppercased() + step.dropFirst()
            }
    }

    private func addSuggestedStep(_ step: String) {
        if !extractedSteps.contains(where: { $0.text == step }) {
            extractedSteps.append(ExtractedStep(text: step, isSelected: true))
        }
    }
}

// MARK: - Extracted Step

struct ExtractedStep: Identifiable {
    let id = UUID()
    var text: String
    var isSelected: Bool
}

// MARK: - Quick Breakdown Prompt

/// Simple inline prompt to break down a task
struct QuickBreakdownPrompt: View {
    let task: GadflyTask
    @State private var showBreakdown = false

    var body: some View {
        Button {
            showBreakdown = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                Text("Split into steps")
            }
            .font(.caption)
            .foregroundStyle(.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.purple.opacity(0.1))
            )
        }
        .sheet(isPresented: $showBreakdown) {
            TaskBreakdownView(
                task: task,
                isPresented: $showBreakdown,
                onCreateSubtasks: { steps in
                    // Would create subtasks here
                    print("Creating subtasks: \(steps)")
                }
            )
        }
    }
}

// MARK: - Preview

#Preview("Task Breakdown") {
    TaskBreakdownView(
        task: GadflyTask(
            title: "Clean the entire apartment",
            dueDate: nil,
            priority: .medium
        ),
        isPresented: .constant(true),
        onCreateSubtasks: { _ in }
    )
}
