import SwiftUI

// MARK: - Preset Mode Selector

/// Quick mode switcher for the home screen
struct PresetModeSelector: View {
    @ObservedObject var modeService = PresetModeService.shared
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PresetMode.allCases.filter { $0 != .custom }) { mode in
                PresetModeButton(
                    mode: mode,
                    isSelected: modeService.currentMode == mode,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            modeService.setMode(mode, appState: appState)
                        }
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                )
            }
        }
    }
}

// MARK: - Preset Mode Button

struct PresetModeButton: View {
    let mode: PresetMode
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                Text(mode.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : themeColors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color : themeColors.secondary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preset Mode Card

/// Full card for mode selection in settings
struct PresetModeCard: View {
    let mode: PresetMode
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundStyle(mode.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mode.displayName)
                            .font(.headline)
                            .foregroundStyle(themeColors.text)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(mode.color)
                        }
                    }

                    Text(mode.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? mode.color : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preset Mode Detail View

struct PresetModeDetailView: View {
    let mode: PresetMode
    let onSelect: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(mode.color.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: mode.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(mode.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.displayName)
                            .font(.title.bold())
                            .foregroundStyle(themeColors.text)

                        Text(mode.shortDescription)
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)
                    }
                }
                .padding(.horizontal)

                // Description
                Text(mode.description)
                    .font(.body)
                    .foregroundStyle(themeColors.text)
                    .padding(.horizontal)

                // Best for section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best for")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mode.bestFor, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(mode.color)
                                Text(item)
                                    .foregroundStyle(themeColors.text)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Settings preview
                if mode != .custom {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundStyle(themeColors.text)

                        let config = PresetConfiguration.configuration(for: mode)
                        SettingsPreviewRow(label: "Nag interval", value: "\(config.nagIntervalMinutes) min")
                        SettingsPreviewRow(label: "Focus check-ins", value: "\(config.focusCheckInMinutes) min")
                        SettingsPreviewRow(label: "Celebration sounds", value: config.celebrationSoundsEnabled ? "On" : "Off")
                        SettingsPreviewRow(label: "Confetti", value: config.celebrationAnimationsEnabled ? "On" : "Off")
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
            .padding(.top)
        }
        .background(themeColors.background)
        .safeAreaInset(edge: .bottom) {
            Button {
                onSelect()
                dismiss()
            } label: {
                Text("Use \(mode.displayName)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(mode.color)
                    )
            }
            .padding()
            .background(themeColors.background)
        }
        .navigationTitle("Mode Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsPreviewRow: View {
    let label: String
    let value: String

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(themeColors.subtext)
            Spacer()
            Text(value)
                .foregroundStyle(themeColors.text)
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.secondary)
        )
    }
}

// MARK: - Preset Mode Settings Section

struct PresetModeSettingsSection: View {
    @ObservedObject var modeService = PresetModeService.shared
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared

    @State private var selectedModeForDetail: PresetMode?

    var body: some View {
        Section {
            VStack(spacing: 12) {
                ForEach(PresetMode.allCases) { mode in
                    PresetModeCard(
                        mode: mode,
                        isSelected: modeService.currentMode == mode,
                        onSelect: {
                            if mode == .custom {
                                modeService.setMode(mode, appState: appState)
                            } else {
                                selectedModeForDetail = mode
                            }
                        }
                    )
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Mode")
        } footer: {
            Text("Choose a preset that matches how you want the app to behave. Select Custom to fine-tune individual settings below.")
        }
        .sheet(item: $selectedModeForDetail) { mode in
            NavigationStack {
                PresetModeDetailView(mode: mode) {
                    modeService.setMode(mode, appState: appState)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Mode Selector") {
    VStack {
        PresetModeSelector()
            .padding()

        Spacer()
    }
    .environmentObject(AppState())
}

#Preview("Mode Cards") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PresetMode.allCases) { mode in
                PresetModeCard(mode: mode, isSelected: mode == .stayOnMe, onSelect: {})
            }
        }
        .padding()
    }
}
