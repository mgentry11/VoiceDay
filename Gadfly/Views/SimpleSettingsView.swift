import SwiftUI

enum HelpMode: String, CaseIterable, Identifiable {
    case gentle = "gentle"
    case balanced = "balanced"
    case persistent = "persistent"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gentle: return "Gentle Guide"
        case .balanced: return "Stay On Me"
        case .persistent: return "Keep Me Accountable"
        }
    }
    
    var description: String {
        switch self {
        case .gentle: return "Soft reminders, lots of space"
        case .balanced: return "Regular check-ins, balanced"
        case .persistent: return "Persistent, won't let you forget"
        }
    }
    
    var icon: String {
        switch self {
        case .gentle: return "leaf.fill"
        case .balanced: return "scale.3d"
        case .persistent: return "bell.badge.fill"
        }
    }
}

struct SimpleSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("help_mode") private var helpMode: String = HelpMode.balanced.rawValue
    @AppStorage("sounds_enabled") private var soundsEnabled: Bool = true
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("celebrations_enabled") private var celebrationsEnabled: Bool = true
    @State private var showAdvanced = false
    @State private var selectedVibe: VoiceVibe = .friendly
    
    private var currentHelpMode: HelpMode {
        HelpMode(rawValue: helpMode) ?? .balanced
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    helpModeSection
                    voiceSection
                    quickTogglesSection
                    advancedSection
                }
                .padding()
            }
            .background(Color.themeBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var helpModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How should I help you?")
                .font(.headline)
                .foregroundStyle(Color.themeText)
            
            VStack(spacing: 8) {
                ForEach(HelpMode.allCases) { mode in
                    helpModeRow(mode)
                }
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func helpModeRow(_ mode: HelpMode) -> some View {
        Button {
            helpMode = mode.rawValue
            applyHelpMode(mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundStyle(currentHelpMode == mode ? Color.themeAccent : Color.themeSubtext)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.themeText)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(Color.themeSubtext)
                }
                
                Spacer()
                
                if currentHelpMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.themeAccent)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voice")
                    .font(.headline)
                    .foregroundStyle(Color.themeText)
                Spacer()
                Text(selectedVibe.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeAccent)
            }
            
            HStack(spacing: 12) {
                ForEach(VoiceVibe.allCases) { vibe in
                    vibeButton(vibe)
                }
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func vibeButton(_ vibe: VoiceVibe) -> some View {
        Button {
            selectedVibe = vibe
            updateVoiceForVibe(vibe)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selectedVibe == vibe ? vibe.color : Color.themeBackground)
                        .frame(width: 50, height: 50)
                    Image(systemName: vibe.icon)
                        .font(.title2)
                        .foregroundStyle(selectedVibe == vibe ? .white : vibe.color)
                }
                Text(vibe.displayName)
                    .font(.caption)
                    .foregroundStyle(selectedVibe == vibe ? Color.themeText : Color.themeSubtext)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private var quickTogglesSection: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "speaker.wave.2.fill", title: "Sounds", isOn: $soundsEnabled)
            Divider().background(Color.themeBackground)
            toggleRow(icon: "iphone.radiowaves.left.and.right", title: "Vibration", isOn: $hapticsEnabled)
            Divider().background(Color.themeBackground)
            toggleRow(icon: "party.popper.fill", title: "Celebrations", isOn: $celebrationsEnabled)
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.themeAccent)
                .frame(width: 30)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.themeText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.themeAccent)
        }
        .padding(.vertical, 8)
    }
    
    private var advancedSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title3)
                        .foregroundStyle(Color.themeSubtext)
                        .frame(width: 30)
                    Text("Advanced Settings")
                        .font(.subheadline)
                        .foregroundStyle(Color.themeSubtext)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.themeSubtext)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            if showAdvanced {
                VStack(spacing: 0) {
                    Divider().background(Color.themeBackground)
                    advancedRow(title: "Personality", value: appState.selectedPersonality.displayName)
                    Divider().background(Color.themeBackground)
                    advancedRow(title: "Check-in Times", value: "Customize")
                    Divider().background(Color.themeBackground)
                    advancedRow(title: "Location Reminders", value: "Configure")
                    Divider().background(Color.themeBackground)
                    advancedRow(title: "API Keys", value: "Manage")
                }
            }
        }
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func advancedRow(title: String, value: String) -> some View {
        NavigationLink {
            Text("Coming soon")
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeText)
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.themeSubtext)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.themeSubtext)
            }
            .padding()
        }
    }
    
    private func applyHelpMode(_ mode: HelpMode) {
        switch mode {
        case .gentle:
            NaggingLevelService.shared.naggingLevel = .gentle
        case .balanced:
            NaggingLevelService.shared.naggingLevel = .moderate
        case .persistent:
            NaggingLevelService.shared.naggingLevel = .persistent
        }
    }
    
    private func updateVoiceForVibe(_ vibe: VoiceVibe) {
        Task {
            let service = ElevenLabsService()
            if let voices = try? await service.fetchVoices(apiKey: appState.elevenLabsKey),
               let bestVoice = SimpleVoicePicker.bestVoice(for: vibe, from: voices) {
                await MainActor.run {
                    appState.selectedVoiceId = bestVoice.voice_id
                    appState.selectedVoiceName = bestVoice.name
                    UserDefaults.standard.set(bestVoice.voice_id, forKey: "selected_voice_id")
                    UserDefaults.standard.set(bestVoice.name, forKey: "selected_voice_name")
                }
            }
        }
    }
}

#Preview {
    SimpleSettingsView()
        .environmentObject(AppState())
}
