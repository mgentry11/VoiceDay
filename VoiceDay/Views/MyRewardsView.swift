import SwiftUI

struct MyRewardsView: View {
    @StateObject private var rewardsService = RewardsService.shared
    @State private var showingRedemptionAlert = false
    @State private var selectedReward: RewardConfig?
    @State private var redemptionMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Points Card
                pointsCard

                // Available Rewards
                if let team = rewardsService.currentTeam {
                    rewardsSection(rewards: team.rewards)
                } else {
                    // Show default rewards as preview
                    rewardsSection(rewards: Team.defaultRewards())
                }

                // My Redemptions
                if !rewardsService.pendingRedemptions.isEmpty {
                    redemptionsSection
                }
            }
            .padding()
        }
        .navigationTitle("My Rewards")
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
                StatItem(label: "Earned Today", value: "+45")
                StatItem(label: "This Week", value: "+280")
                StatItem(label: "Redeemed", value: "150")
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

struct StatItem: View {
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
                    .fill(Color(hex: reward.type.color)?.opacity(0.2) ?? Color.green.opacity(0.2))
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

#Preview {
    NavigationStack {
        MyRewardsView()
    }
}
