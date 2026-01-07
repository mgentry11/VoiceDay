import SwiftUI

struct MyRewardsView: View {
    @StateObject private var rewardsService = RewardsService.shared
    @State private var showingRedemptionAlert = false
    @State private var selectedReward: RewardConfig?
    @State private var redemptionMessage = ""
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Rewards").tag(1)
                Text("Badges").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == 0 {
                        // Overview Tab
                        pointsCard
                        streakCard
                        dailyChallengesSection
                    } else if selectedTab == 1 {
                        // Rewards Tab
                        pointsCard

                        if let team = rewardsService.currentTeam {
                            rewardsSection(rewards: team.rewards)
                        } else {
                            rewardsSection(rewards: Team.defaultRewards())
                        }

                        if !rewardsService.pendingRedemptions.isEmpty {
                            redemptionsSection
                        }
                    } else {
                        // Badges Tab
                        achievementsSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("My Rewards")
        .onAppear {
            rewardsService.refreshDailyChallenges()
        }
        .alert("Redeem Reward", isPresented: $showingRedemptionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Redeem") {
                if let reward = selectedReward {
                    redeemReward(reward)
                }
            }
        } message: {
            if let reward = selectedReward {
                Text("Spend \(reward.pointCost) points to redeem \(reward.name)?")
            }
        }
    }

    private var pointsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(rewardsService.myPoints)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.green)
                }

                Spacer()

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow.opacity(0.8))
            }

            Divider()

            // Quick stats
            HStack(spacing: 24) {
                RewardStatItem(label: "Today", value: "+\(rewardsService.streakData.tasksCompletedToday * 10)")
                RewardStatItem(label: "This Week", value: "+\(rewardsService.streakData.weeklyTotal * 10)")
                RewardStatItem(label: "Total", value: "\(rewardsService.totalPointsEarned)")
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(rewardsService.streakData.currentStreak)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("days")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Divider()

            HStack(spacing: 32) {
                VStack(spacing: 2) {
                    Text("\(rewardsService.streakData.longestStreak)")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("Best Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(rewardsService.totalTasksCompleted)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text("Tasks Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(rewardsService.streakData.tasksCompletedToday)")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Daily Challenges

    private var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Challenges")
                    .font(.headline)
                Spacer()
                Text("\(rewardsService.dailyChallenges.filter { $0.isCompleted }.count)/\(rewardsService.dailyChallenges.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(rewardsService.dailyChallenges) { challenge in
                DailyChallengeRow(challenge: challenge)
            }
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(rewardsService.unlockedAchievementsCount)/\(rewardsService.achievements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(rewardsService.achievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
    }

    private func rewardsSection(rewards: [RewardConfig]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Rewards")
                .font(.headline)

            ForEach(rewards.filter { $0.isActive }) { reward in
                RewardRow(
                    reward: reward,
                    canAfford: rewardsService.myPoints >= reward.pointCost
                ) {
                    selectedReward = reward
                    showingRedemptionAlert = true
                }
            }
        }
    }

    private var redemptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Redemptions")
                .font(.headline)

            ForEach(rewardsService.pendingRedemptions) { redemption in
                RedemptionRow(redemption: redemption)
            }
        }
    }

    private func redeemReward(_ reward: RewardConfig) {
        if rewardsService.redeemReward(reward) {
            redemptionMessage = "Successfully redeemed \(reward.name)! Your manager will be notified."

            // Add celebration to conversation
            let message = "You've redeemed '\(reward.name)' for \(reward.pointCost) points! Your manager has been notified to fulfill this reward."
            ConversationService.shared.addAssistantMessage(message)
        } else {
            redemptionMessage = "Not enough points to redeem this reward."
        }
    }
}

struct RewardStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(value.hasPrefix("+") ? .green : .primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct RewardRow: View {
    let reward: RewardConfig
    let canAfford: Bool
    let onRedeem: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: reward.type.color).opacity(0.2) ?? Color.green.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: reward.type.icon)
                    .foregroundStyle(Color(hex: reward.type.color) ?? .green)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.name)
                    .font(.subheadline.weight(.medium))
                Text(reward.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let value = reward.dollarValue {
                    Text("$\(Int(value)) value")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Redeem button
            Button {
                onRedeem()
            } label: {
                VStack(spacing: 2) {
                    Text("\(reward.pointCost)")
                        .font(.headline)
                    Text("pts")
                        .font(.caption2)
                }
                .foregroundStyle(canAfford ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(canAfford ? Color.green : Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            .disabled(!canAfford)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(canAfford ? 1 : 0.7)
    }
}

struct RedemptionRow: View {
    let redemption: RewardRedemption

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(redemption.rewardName)
                    .font(.subheadline.weight(.medium))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Text("-\(redemption.pointsSpent) pts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var statusIcon: String {
        switch redemption.status {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .fulfilled: return "gift.fill"
        case .denied: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch redemption.status {
        case .pending: return .orange
        case .approved: return .blue
        case .fulfilled: return .green
        case .denied: return .red
        }
    }

    private var statusText: String {
        switch redemption.status {
        case .pending: return "Pending approval"
        case .approved: return "Approved - being fulfilled"
        case .fulfilled: return "Fulfilled!"
        case .denied: return "Denied"
        }
    }
}

// MARK: - Daily Challenge Row

struct DailyChallengeRow: View {
    let challenge: DailyChallenge

    var body: some View {
        HStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: challenge.progressPercent)
                    .stroke(
                        challenge.isCompleted ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                if challenge.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(challenge.currentProgress)/\(challenge.targetCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(challenge.isCompleted)
                Text(challenge.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("+\(challenge.bonusPoints)")
                    .font(.headline)
                    .foregroundStyle(challenge.isCompleted ? .green : .secondary)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(challenge.isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .yellow : .gray.opacity(0.4))
            }

            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .opacity(achievement.isUnlocked ? 1 : 0.6)
    }
}

#Preview {
    NavigationStack {
        MyRewardsView()
    }
}
