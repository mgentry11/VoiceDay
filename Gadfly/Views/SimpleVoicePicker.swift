import SwiftUI

enum VoiceVibe: String, CaseIterable, Identifiable {
    case calm = "calm"
    case friendly = "friendly"
    case direct = "direct"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .friendly: return "Friendly"
        case .direct: return "Direct"
        }
    }
    
    var icon: String {
        switch self {
        case .calm: return "leaf.fill"
        case .friendly: return "sun.max.fill"
        case .direct: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .calm: return "Soft, unhurried, soothing"
        case .friendly: return "Warm, upbeat, encouraging"
        case .direct: return "Clear, efficient, no fluff"
        }
    }
    
    var color: Color {
        switch self {
        case .calm: return .blue
        case .friendly: return .orange
        case .direct: return .purple
        }
    }
    
    var recommendedVoiceNames: [String] {
        switch self {
        case .calm: return ["Alice", "Aria", "Grace", "Lily", "Sarah"]
        case .friendly: return ["Jessica", "Charlotte", "Nicole", "Rachel", "Matilda"]
        case .direct: return ["Roger", "George", "Daniel", "Eric", "Brian"]
        }
    }
}

struct SimpleVoicePicker: View {
    @Binding var selectedVibe: VoiceVibe
    var onSelect: ((VoiceVibe) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Pick your voice vibe")
                .font(.headline)
                .foregroundStyle(Color.themeText)
            
            VStack(spacing: 12) {
                ForEach(VoiceVibe.allCases) { vibe in
                    vibeCard(vibe)
                }
            }
        }
        .padding()
    }
    
    private func vibeCard(_ vibe: VoiceVibe) -> some View {
        Button {
            selectedVibe = vibe
            onSelect?(vibe)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(vibe.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: vibe.icon)
                        .font(.title2)
                        .foregroundStyle(vibe.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vibe.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.themeText)
                    Text(vibe.description)
                        .font(.caption)
                        .foregroundStyle(Color.themeSubtext)
                }
                
                Spacer()
                
                if selectedVibe == vibe {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vibe.color)
                } else {
                    Circle()
                        .stroke(Color.themeSubtext.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedVibe == vibe ? vibe.color.opacity(0.1) : Color.themeSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedVibe == vibe ? vibe.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

extension SimpleVoicePicker {
    static func bestVoice(for vibe: VoiceVibe, from voices: [ElevenLabsService.Voice]) -> ElevenLabsService.Voice? {
        let preferred = vibe.recommendedVoiceNames
        for name in preferred {
            if let match = voices.first(where: { $0.name.lowercased().contains(name.lowercased()) }) {
                return match
            }
        }
        return voices.first
    }
}

#Preview {
    SimpleVoicePicker(selectedVibe: .constant(.friendly))
        .background(Color.themeBackground)
}
