import SwiftUI

// MARK: - Energy Check-In View

/// Quick energy check-in modal
/// Presented at start of day or on-demand
struct EnergyCheckInView: View {
    @ObservedObject var energyService = EnergyService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLevel: EnergyService.EnergyLevel?
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("How's your energy today?")
                    .font(.title2.bold())
                    .foregroundStyle(themeColors.text)

                Text("This helps adapt the app to your current state")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Energy options
            VStack(spacing: 12) {
                ForEach(EnergyService.EnergyLevel.allCases, id: \.self) { level in
                    EnergyOptionButton(
                        level: level,
                        isSelected: selectedLevel == level,
                        onSelect: { selectedLevel = level }
                    )
                }
            }
            .padding(.horizontal)

            // Prediction hint
            if let predicted = energyService.predictedEnergy() {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                    Text("Usually \(predicted.shortName.lowercased()) energy at this time")
                        .font(.caption)
                }
                .foregroundStyle(themeColors.subtext)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColors.secondary)
                )
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    if let level = selectedLevel {
                        confirmSelection(level)
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedLevel != nil ? themeColors.accent : themeColors.subtext)
                        )
                }
                .disabled(selectedLevel == nil)

                Button {
                    energyService.skipCheckIn()
                    dismiss()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(themeColors.background)
        .overlay {
            if showingConfirmation {
                confirmationOverlay
            }
        }
    }

    private func confirmSelection(_ level: EnergyService.EnergyLevel) {
        energyService.setEnergy(level)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private var confirmationOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedLevel?.icon ?? "battery.50")
                .font(.system(size: 48))
                .foregroundStyle(selectedLevel?.color ?? themeColors.accent)

            Text("Got it!")
                .font(.title2.bold())
                .foregroundStyle(themeColors.text)

            Text(selectedLevel?.description ?? "")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Energy Option Button

struct EnergyOptionButton: View {
    let level: EnergyService.EnergyLevel
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: level.icon)
                        .font(.title2)
                        .foregroundStyle(level.color)
                }

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    Text(levelHint)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? level.color : themeColors.subtext.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? level.color : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var levelHint: String {
        switch level {
        case .low: return "Gentle reminders, easy tasks first"
        case .medium: return "Balanced productivity mode"
        case .high: return "Ready for challenges!"
        }
    }
}

// MARK: - Energy Badge

/// Small energy indicator for status display
struct EnergyBadge: View {
    @ObservedObject var energyService = EnergyService.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: energyService.currentEnergy.icon)
                .font(.caption)
            Text(energyService.currentEnergy.shortName)
                .font(.caption)
        }
        .foregroundStyle(energyService.currentEnergy.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(energyService.currentEnergy.color.opacity(0.15))
        )
    }
}

// MARK: - Energy Settings Section

struct EnergySettingsSection: View {
    @ObservedObject var energyService = EnergyService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @State private var showingCheckIn = false

    var body: some View {
        Section {
            // Current energy display
            HStack {
                Text("Current Energy")
                Spacer()
                EnergyBadge()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingCheckIn = true
            }

            // Mid-day check-in toggle
            Toggle("Mid-day Check-in", isOn: Binding(
                get: { energyService.midDayCheckInEnabled },
                set: { energyService.midDayCheckInEnabled = $0 }
            ))

            // Last check-in time
            if let lastCheck = energyService.lastCheckIn {
                HStack {
                    Text("Last Check-in")
                    Spacer()
                    Text(lastCheck, style: .relative)
                        .foregroundStyle(themeColors.subtext)
                }
            }
        } header: {
            Text("Energy Level")
        } footer: {
            Text("The app adapts notifications and task suggestions based on your energy. Check in once a day or enable mid-day updates.")
        }
        .sheet(isPresented: $showingCheckIn) {
            EnergyCheckInView()
        }
    }
}

// MARK: - Preview

#Preview("Energy Check-In") {
    EnergyCheckInView()
}

#Preview("Energy Options") {
    VStack(spacing: 12) {
        ForEach(EnergyService.EnergyLevel.allCases, id: \.self) { level in
            EnergyOptionButton(level: level, isSelected: level == .medium, onSelect: {})
        }
    }
    .padding()
}
