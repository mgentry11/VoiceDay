import SwiftUI

// MARK: - Task Attack View

/// Visual, minimal-text interface for attacking tasks
/// ADHD-friendly: icons over words, one-tap actions
struct TaskAttackView: View {
    let task: GadflyTask
    let onStart: () -> Void
    let onBreakDown: () -> Void
    let onSkip: () -> Void

    @StateObject private var advisor = TaskAttackAdvisor.shared
    @State private var analysis: TaskAttackAdvisor.TaskAnalysis?
    @State private var showAlternatives = false

    var body: some View {
        VStack(spacing: 20) {
            // Task title - brief
            Text(task.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal)

            if let analysis = analysis {
                // Main strategy card - BIG and visual
                mainStrategyCard(analysis)

                // Tiny first step - the key insight
                tinyStepCard(analysis)

                // Quick info badges - visual, not text
                quickInfoBadges(analysis)

                // Alternative strategies - collapsed by default
                if showAlternatives {
                    alternativeStrategies(analysis)
                }

                // Action buttons - BIG
                actionButtons(analysis)
            } else {
                ProgressView()
                    .onAppear {
                        analysis = advisor.analyzeTask(task)
                    }
            }
        }
        .padding()
    }

    // MARK: - Main Strategy Card

    @ViewBuilder
    private func mainStrategyCard(_ analysis: TaskAttackAdvisor.TaskAnalysis) -> some View {
        VStack(spacing: 12) {
            // Big icon
            Image(systemName: analysis.recommendedStrategy.icon)
                .font(.system(size: 44))
                .foregroundStyle(analysis.recommendedStrategy.color)

            // Strategy name
            Text(analysis.recommendedStrategy.displayName)
                .font(.headline)

            // One line description
            Text(analysis.recommendedStrategy.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(analysis.recommendedStrategy.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(analysis.recommendedStrategy.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Tiny Step Card

    @ViewBuilder
    private func tinyStepCard(_ analysis: TaskAttackAdvisor.TaskAnalysis) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shoeprints.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("First step")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(analysis.tinyFirstStep)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }

    // MARK: - Quick Info Badges

    @ViewBuilder
    private func quickInfoBadges(_ analysis: TaskAttackAdvisor.TaskAnalysis) -> some View {
        HStack(spacing: 12) {
            // Duration estimate
            badgeView(
                icon: "clock",
                text: analysis.estimatedDuration.displayString,
                color: .blue
            )

            // Energy match
            badgeView(
                icon: analysis.energyMatch.icon,
                text: energyMatchShort(analysis.energyMatch),
                color: analysis.energyMatch.color
            )

            // Can break down?
            if analysis.canBreakDown {
                badgeView(
                    icon: "square.grid.2x2",
                    text: "Splittable",
                    color: .purple
                )
            }
        }
    }

    private func energyMatchShort(_ match: TaskAttackAdvisor.EnergyMatch) -> String {
        switch match {
        case .perfect: return "Perfect"
        case .good: return "Good"
        case .mismatch: return "Mismatch"
        }
    }

    @ViewBuilder
    private func badgeView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    // MARK: - Alternative Strategies

    @ViewBuilder
    private func alternativeStrategies(_ analysis: TaskAttackAdvisor.TaskAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other approaches")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(analysis.alternativeStrategies, id: \.rawValue) { strategy in
                    Button {
                        // Could switch strategy here
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: strategy.icon)
                                .font(.title3)
                            Text(strategy.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(strategy.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(strategy.color.opacity(0.1))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(_ analysis: TaskAttackAdvisor.TaskAnalysis) -> some View {
        VStack(spacing: 12) {
            // Primary action - START
            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                )
            }

            HStack(spacing: 12) {
                // Break it down
                if analysis.canBreakDown {
                    Button(action: onBreakDown) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("Split")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple, lineWidth: 1)
                        )
                    }
                }

                // Skip / Not now
                Button(action: onSkip) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Skip")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Show more options toggle
            Button {
                withAnimation {
                    showAlternatives.toggle()
                }
            } label: {
                Text(showAlternatives ? "Less options" : "More options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Compact Attack Card

/// Smaller version for inline display in Focus view
struct CompactAttackCard: View {
    let task: GadflyTask
    let onTap: () -> Void

    @StateObject private var advisor = TaskAttackAdvisor.shared
    @State private var analysis: TaskAttackAdvisor.TaskAnalysis?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let analysis = analysis {
                    // Strategy icon
                    Image(systemName: analysis.recommendedStrategy.icon)
                        .font(.title2)
                        .foregroundStyle(analysis.recommendedStrategy.color)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("How to attack this?")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(analysis.recommendedStrategy.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            analysis = advisor.analyzeTask(task)
        }
    }
}

// MARK: - Attack Sheet

/// Full-screen sheet for task attack planning
struct TaskAttackSheet: View {
    let task: GadflyTask
    @Binding var isPresented: Bool
    let onStartTask: () -> Void
    let onBreakDown: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                TaskAttackView(
                    task: task,
                    onStart: {
                        onStartTask()
                        isPresented = false
                    },
                    onBreakDown: {
                        onBreakDown()
                    },
                    onSkip: {
                        isPresented = false
                    }
                )
            }
            .navigationTitle("Attack Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Task Attack View") {
    TaskAttackView(
        task: GadflyTask(
            title: "Write quarterly report",
            dueDate: Date().addingTimeInterval(3600 * 24),
            priority: .high
        ),
        onStart: {},
        onBreakDown: {},
        onSkip: {}
    )
    .padding()
}

#Preview("Compact Card") {
    CompactAttackCard(
        task: GadflyTask(
            title: "Clean the kitchen",
            dueDate: nil,
            priority: .medium
        ),
        onTap: {}
    )
    .padding()
}
