import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var checkoutService = CheckoutChecklistService.shared
    @StateObject private var elevenLabsService = ElevenLabsService()

    @State private var showCheckoutChecklist = false
    @State private var checkoutLocation: LocationService.SavedLocation?
    @State private var showVoiceSetup = false
    @State private var voicesLoaded = false

    // Check if voice is properly configured
    private var needsVoiceSetup: Bool {
        let hasApiKey = !appState.elevenLabsKey.isEmpty
        let hasSelectedVoice = !appState.selectedVoiceId.isEmpty
        // Only prompt if they have API key but no voice selected
        return hasApiKey && !hasSelectedVoice
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Focus tab - ADHD-friendly simplified view (primary entry point)
            FocusHomeView()
                .tabItem {
                    Label("Focus", systemImage: "scope")
                }
                .tag(0)

            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(1)

            TasksListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(2)

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(themeColors.accent)
        .id(themeColors.currentTheme.rawValue) // Force rebuild when theme changes
        .onAppear {
            if !appState.hasValidClaudeKey {
                appState.selectedTab = 4  // Settings tab
            }
            // Show voice setup if needed
            if needsVoiceSetup && !voicesLoaded {
                Task {
                    await loadVoicesAndShowPicker()
                }
            }
        }
        // Voice setup sheet - shows immediately if no voice selected
        .sheet(isPresented: $showVoiceSetup) {
            VoiceSetupView(
                voices: elevenLabsService.availableVoices,
                onComplete: {
                    showVoiceSetup = false
                }
            )
            .environmentObject(appState)
        }
        // Location exit trigger
        .onChange(of: locationService.locationExitTriggered) { (triggeredLocation: LocationService.SavedLocation?) in
            if let location = triggeredLocation {
                checkoutLocation = location
                showCheckoutChecklist = true
            }
        }
        .fullScreenCover(isPresented: $showCheckoutChecklist) {
            if let location = checkoutLocation {
                CheckoutChecklistView(
                    location: location,
                    onComplete: {
                        showCheckoutChecklist = false
                        checkoutLocation = nil
                        locationService.clearExitTrigger()
                        checkoutService.completeCheckout()
                    },
                    onDismiss: {
                        showCheckoutChecklist = false
                        checkoutLocation = nil
                        locationService.clearExitTrigger()
                        checkoutService.dismissCheckout()
                    }
                )
                .environmentObject(appState)
            }
        }
    }

    // MARK: - Voice Setup

    private func loadVoicesAndShowPicker() async {
        voicesLoaded = true
        do {
            _ = try await elevenLabsService.fetchVoices(apiKey: appState.elevenLabsKey)
            await MainActor.run {
                showVoiceSetup = true
            }
        } catch {
            print("❌ Failed to load voices: \(error)")
        }
    }
}

// MARK: - Voice Setup View (First-time setup)

struct VoiceSetupView: View {
    let voices: [ElevenLabsService.Voice]
    let onComplete: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var isPlaying = false
    @State private var playingVoiceId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Choose Your Voice")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Tap a voice to hear it speak as \(appState.selectedPersonality.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)

                // Voice list
                List {
                    ForEach(voices) { voice in
                        Button {
                            selectAndPreview(voice)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(voice.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if let labels = voice.labels {
                                        HStack(spacing: 8) {
                                            if let accent = labels.accent {
                                                Text(accent.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let desc = labels.description {
                                                Text(desc)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                if playingVoiceId == voice.voice_id {
                                    ProgressView()
                                } else if appState.selectedVoiceId == voice.voice_id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .listStyle(.plain)

                // Continue button (only shows after selection)
                if !appState.selectedVoiceId.isEmpty {
                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Continue with \(appState.selectedVoiceName)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appState.selectedVoiceId.isEmpty {
                        Button("Done") {
                            onComplete()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func selectAndPreview(_ voice: ElevenLabsService.Voice) {
        // Save selection immediately
        appState.selectedVoiceId = voice.voice_id
        appState.selectedVoiceName = voice.name

        // Show playing indicator
        playingVoiceId = voice.voice_id

        // Play preview in personality voice
        Task {
            let greeting = getPersonalityGreeting(voiceName: voice.name)
            do {
                try await elevenLabsService.speak(greeting, apiKey: appState.elevenLabsKey, voiceId: voice.voice_id)
            } catch {
                print("❌ Voice preview failed: \(error)")
            }
            await MainActor.run {
                playingVoiceId = nil
            }
        }
    }

    private func getPersonalityGreeting(voiceName: String) -> String {
        switch appState.selectedPersonality {
        case .pemberton:
            return "Ah, splendid choice. I am \(appState.selectedPersonality.displayName), and I shall be nagging you with this voice."
        case .sergent:
            return "Attention! I am \(appState.selectedPersonality.displayName)! This is my voice now, soldier!"
        case .cheerleader:
            return "Yay! I'm \(appState.selectedPersonality.displayName)! So excited to help you!"
        case .butler:
            return "Very good. I am \(appState.selectedPersonality.displayName), at your service."
        case .coach:
            return "Hey champ! I'm \(appState.selectedPersonality.displayName)! Let's win today!"
        case .zen:
            return "I am \(appState.selectedPersonality.displayName). May this voice bring you peace."
        case .parent:
            return "Hi sweetie, I'm \(appState.selectedPersonality.displayName). I'm here to help!"
        case .bestie:
            return "Hey! I'm \(appState.selectedPersonality.displayName)! We're gonna be great together!"
        case .robot:
            return "Voice module activated. I am \(appState.selectedPersonality.displayName)."
        case .therapist:
            return "Hello, I'm \(appState.selectedPersonality.displayName). How are you feeling today?"
        case .hypeFriend:
            return "OH YEAH! I'M \(appState.selectedPersonality.displayName.uppercased())! LET'S GOOO!"
        case .chillBuddy:
            return "Hey... I'm \(appState.selectedPersonality.displayName). No pressure. We got this."
        case .snarky:
            return "Oh great, another human to nag. I'm \(appState.selectedPersonality.displayName)."
        case .gamer:
            return "Player One Ready! I'm \(appState.selectedPersonality.displayName)! Quest begins!"
        case .tiredParent:
            return "Hi... I'm \(appState.selectedPersonality.displayName). Let's get through this together."
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
