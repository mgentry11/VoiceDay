import SwiftUI

struct ManagerDashboardView: View {
    @StateObject private var rewardsService = RewardsService.shared
    @StateObject private var apiService = GadflyAPIService.shared
    @State private var selectedTab = 0
    @State private var showingAddReward = false
    @State private var showingTeamSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Team").tag(0)
                    Text("Rewards").tag(1)
                    Text("Pending").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    teamOverviewTab.tag(0)
                    rewardsConfigTab.tag(1)
                    pendingRedemptionsTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Manager Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingTeamSetup = true
                        } label: {
                            Label("Team Settings", systemImage: "gearshape")
                        }

                        Button {
                            showingAddReward = true
                        } label: {
                            Label("Add Reward", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddReward) {
                AddRewardView()
            }
            .sheet(isPresented: $showingTeamSetup) {
                TeamSetupView()
            }
        }
    }

    // MARK: - Team Overview Tab

    private var teamOverviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Team Members", value: "\(apiService.connections.count)", icon: "person.3.fill", color: .blue)
                    StatCard(title: "Active Tasks", value: "\(apiService.sharedTasks.filter { !$0.isCompleted }.count)", icon: "checklist", color: .orange)
                    StatCard(title: "Completed Today", value: "\(completedToday)", icon: "checkmark.circle.fill", color: .green)
                    StatCard(title: "Points Awarded", value: "\(totalPointsAwarded)", icon: "star.fill", color: .yellow)
                }
                .padding(.horizontal)

                // Leaderboard
                VStack(alignment: .leading, spacing: 12) {
                    Text("Leaderboard")
                        .font(.headline)
                        .padding(.horizontal)

                    if apiService.connections.isEmpty {
                        emptyTeamState
                    } else {
                        ForEach(Array(apiService.connections.enumerated()), id: \.element.id) { index, connection in
                            LeaderboardRow(
                                rank: index + 1,
                                name: connection.nickname,
                                points: 0, // Would come from backend
                                tasksCompleted: 0
                            )
                        }
                    }
                }

                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)

                    if apiService.sharedTasks.isEmpty {
                        Text("No shared tasks yet")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(apiService.sharedTasks.prefix(5)) { task in
                            ActivityRow(task: task)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var emptyTeamState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No team members yet")
                .font(.headline)

            Text("Add family members or employees in Settings → Family & Friends")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Team Member") {
                // Navigate to add connection
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }

    // MARK: - Rewards Config Tab

    private var rewardsConfigTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Point Rules
                VStack(alignment: .leading, spacing: 12) {
                    Text("Point Rules")
                        .font(.headline)

                    if let team = rewardsService.currentTeam {
                        PointRulesCard(rules: team.pointRules)
                    } else {
                        Button("Set Up Team") {
                            showingTeamSetup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)

                // Available Rewards
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Rewards")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddReward = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if let rewards = rewardsService.currentTeam?.rewards {
                        ForEach(rewards) { reward in
                            RewardConfigRow(reward: reward)
                        }
                    } else {
                        // Show default rewards preview
                        ForEach(Team.defaultRewards()) { reward in
                            RewardConfigRow(reward: reward)
                        }
                    }
                }
                .padding(.horizontal)

                // Quick Add Templates
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Add Templates")
                        .font(.headline)

                    HStack(spacing: 12) {
                        TemplateButton(title: "Business", icon: "building.2") {
                            loadBusinessRewards()
                        }
                        TemplateButton(title: "Family", icon: "house") {
                            loadFamilyRewards()
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Pending Redemptions Tab

    private var pendingRedemptionsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if rewardsService.pendingRedemptions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("No pending redemptions")
                            .font(.headline)

                        Text("When team members redeem rewards, they'll appear here for your approval")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(rewardsService.pendingRedemptions.filter { $0.status == .pending }) { redemption in
                        PendingRedemptionCard(redemption: redemption) {
                            rewardsService.approveRedemption(redemption)
                        } onFulfill: {
                            fulfillRedemption(redemption)
                        } onDeny: {
                            // Handle denial
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var completedToday: Int {
        apiService.sharedTasks.filter { $0.isCompleted }.count
    }

    private var totalPointsAwarded: Int {
        // Would come from backend
        completedToday * 15
    }

    private func loadBusinessRewards() {
        rewardsService.currentTeam?.rewards = Team.defaultRewards()
    }

    private func loadFamilyRewards() {
        rewardsService.currentTeam?.rewards = Team.familyRewards()
    }

    private func fulfillRedemption(_ redemption: RewardRedemption) {
        // Handle different reward types
        if let reward = rewardsService.currentTeam?.rewards.first(where: { $0.id == redemption.rewardId }) {
            switch reward.type {
            case .doordash:
                // Open DoorDash fulfillment flow
                Task {
                    await rewardsService.fulfillDoorDashReward(
                        redemption,
                        recipientEmail: "employee@example.com",
                        recipientName: "Team Member",
                        amount: reward.dollarValue ?? 15
                    )
                }
            default:
                rewardsService.fulfillRedemption(redemption)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let points: Int
    let tasksCompleted: Int

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text("\(tasksCompleted) tasks completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(points)")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("points")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct ActivityRow: View {
    let task: SharedTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("Assigned to: \(task.assignedPhone)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if task.isCompleted {
                Text("+15")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct PointRulesCard: View {
    let rules: PointRules

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("High Priority", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Spacer()
                Text("+\(rules.pointsPerHighPriority) pts")
                    .font(.headline)
            }

            HStack {
                Label("Medium Priority", systemImage: "minus.circle.fill")
                    .foregroundStyle(.yellow)
                Spacer()
                Text("+\(rules.pointsPerMediumPriority) pts")
                    .font(.headline)
            }

            HStack {
                Label("Low Priority", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text("+\(rules.pointsPerLowPriority) pts")
                    .font(.headline)
            }

            Divider()

            HStack {
                Label("Early Completion Bonus", systemImage: "clock.badge.checkmark")
                Spacer()
                Text("+\(rules.bonusForEarlyCompletion) pts")
                    .foregroundStyle(.green)
            }
            .font(.caption)

            HStack {
                Label("Late Penalty", systemImage: "clock.badge.exclamationmark")
                Spacer()
                Text("\(rules.penaltyForLate) pts")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RewardConfigRow: View {
    let reward: RewardConfig

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reward.type.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: reward.type.color) ?? .green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(reward.name)
                    .font(.subheadline.weight(.medium))
                Text(reward.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(reward.pointCost)")
                    .font(.headline)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TemplateButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct PendingRedemptionCard: View {
    let redemption: RewardRedemption
    let onApprove: () -> Void
    let onFulfill: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(redemption.rewardName)
                    .font(.headline)
                Spacer()
                Text("-\(redemption.pointsSpent) pts")
                    .foregroundStyle(.orange)
            }

            Text("Requested \(redemption.redeemedAt, style: .relative) ago")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Deny", action: onDeny)
                    .buttonStyle(.bordered)
                    .tint(.red)

                Button("Approve & Fulfill", action: onFulfill)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views

struct AddRewardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: RewardType = .custom
    @State private var pointCost = 100
    @State private var dollarValue = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(RewardType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    Stepper("Points: \(pointCost)", value: $pointCost, in: 10...1000, step: 10)
                    TextField("Dollar Value (optional)", text: $dollarValue)
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Add Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let reward = RewardConfig(
                            name: name,
                            type: type,
                            pointCost: pointCost,
                            dollarValue: Double(dollarValue),
                            description: description
                        )
                        RewardsService.shared.addReward(reward)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct TeamSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamName = ""
    @State private var isFamily = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Team/Family Name", text: $teamName)

                    Picker("Type", selection: $isFamily) {
                        Text("Family").tag(true)
                        Text("Work Team").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("This will set up") {
                    Label("Point tracking for members", systemImage: "star.fill")
                    Label("Customizable rewards", systemImage: "gift.fill")
                    Label("Leaderboard", systemImage: "chart.bar.fill")
                    if !isFamily {
                        Label("DoorDash integration", systemImage: "bag.fill")
                    }
                }
            }
            .navigationTitle("Set Up Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        RewardsService.shared.createTeam(name: teamName)
                        if isFamily {
                            RewardsService.shared.currentTeam?.rewards = Team.familyRewards()
                        }
                        dismiss()
                    }
                    .disabled(teamName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ManagerDashboardView()
}
