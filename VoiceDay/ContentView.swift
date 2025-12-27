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

// MARK: - Onboarding Flow

struct VoiceSetupView: View {
    let voices: [ElevenLabsService.Voice]
    let onComplete: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0 // 0: Voice, 1: Personality, 2: Start Choice

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Step content
                switch currentStep {
                case 0:
                    VoiceSelectionStep(voices: voices) {
                        withAnimation { currentStep = 1 }
                    }
                case 1:
                    PersonalitySelectionStep {
                        withAnimation { currentStep = 2 }
                    }
                case 2:
                    StartChoiceStep {
                        onComplete()
                        dismiss()
                    }
                default:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 1: Voice Selection

struct VoiceSelectionStep: View {
    let voices: [ElevenLabsService.Voice]
    let onNext: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var playingVoiceId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)

                Text("Choose Your Voice")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Tap to preview each voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

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

                                if let labels = voice.labels, let accent = labels.accent {
                                    Text(accent.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)

            // Continue button
            if !appState.selectedVoiceId.isEmpty {
                Button(action: onNext) {
                    Text("Next: Choose Personality")
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
    }

    private func selectAndPreview(_ voice: ElevenLabsService.Voice) {
        appState.selectedVoiceId = voice.voice_id
        appState.selectedVoiceName = voice.name
        playingVoiceId = voice.voice_id

        Task {
            do {
                try await elevenLabsService.speak("Hello! This is how I sound.", apiKey: appState.elevenLabsKey, voiceId: voice.voice_id)
            } catch {
                print("❌ Voice preview failed: \(error)")
            }
            await MainActor.run {
                playingVoiceId = nil
            }
        }
    }
}

// MARK: - Step 2: Personality Selection

struct PersonalitySelectionStep: View {
    let onNext: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 50))

                Text("Choose Your Personality")
                    .font(.title)
                    .fontWeight(.bold)

                Text("How should I talk to you?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            // Personality list
            List {
                ForEach(BotPersonality.allCases) { personality in
                    Button {
                        selectPersonality(personality)
                    } label: {
                        HStack(spacing: 12) {
                            Text(personality.emoji)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(personality.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(personality.shortDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if appState.selectedPersonality == personality {
                                if isPlaying {
                                    ProgressView()
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)

            // Continue button
            Button(action: onNext) {
                Text("Next: Where to Start")
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

    private func selectPersonality(_ personality: BotPersonality) {
        appState.selectedPersonality = personality
        isPlaying = true

        Task {
            let greeting = personality.introGreeting
            do {
                try await elevenLabsService.speak(greeting, apiKey: appState.elevenLabsKey, voiceId: appState.selectedVoiceId)
            } catch {
                print("❌ Personality preview failed: \(error)")
            }
            await MainActor.run {
                isPlaying = false
            }
        }
    }
}

// MARK: - Step 3: Mode & Start Choice

struct StartChoiceStep: View {
    let onComplete: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var selectedMode: AppMode = .simple

    enum AppMode {
        case simple, pro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("Final Setup")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)

                // Mode Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Your Mode")
                        .font(.headline)
                        .padding(.horizontal)

                    // Simple Mode
                    Button {
                        selectedMode = .simple
                        appState.isSimpleMode = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "leaf.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                                .frame(width: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Simple Mode")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Voice-guided, step-by-step")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedMode == .simple {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                            }
                        }
                        .padding()
                        .background(selectedMode == .simple ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == .simple ? Color.green : Color.clear, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal)

                    // Pro Mode
                    Button {
                        selectedMode = .pro
                        appState.isSimpleMode = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundStyle(.purple)
                                .frame(width: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pro Mode")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("All features, full control")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedMode == .pro {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.purple)
                                    .font(.title2)
                            }
                        }
                        .padding()
                        .background(selectedMode == .pro ? Color.purple.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == .pro ? Color.purple : Color.clear, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.vertical, 8)

                // Start Location
                VStack(alignment: .leading, spacing: 12) {
                    Text("Where to Start?")
                        .font(.headline)
                        .padding(.horizontal)

                    // Morning Check-in option
                    Button {
                        startWithCheckIn()
                    } label: {
                        startOptionRow(
                            icon: "sunrise.fill",
                            color: .orange,
                            title: "Morning Check-in",
                            subtitle: "Walk through your day with me"
                        )
                    }
                    .padding(.horizontal)

                    // Tasks option
                    Button {
                        startWithTasks()
                    } label: {
                        startOptionRow(
                            icon: "checklist",
                            color: .blue,
                            title: "Jump to Tasks",
                            subtitle: "See your task list right away"
                        )
                    }
                    .padding(.horizontal)

                    // Focus mode option
                    Button {
                        startWithFocus()
                    } label: {
                        startOptionRow(
                            icon: "scope",
                            color: .purple,
                            title: "Focus Mode",
                            subtitle: "Simple view, one thing at a time"
                        )
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private func startOptionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func startWithCheckIn() {
        speakAndComplete("Let's start with your morning check-in!")
        appState.selectedTab = 0
    }

    private func startWithTasks() {
        speakAndComplete("Let's see what you have to do today!")
        appState.selectedTab = 2
    }

    private func startWithFocus() {
        speakAndComplete("Focus mode. One thing at a time. You've got this.")
        appState.selectedTab = 0
    }

    private func speakAndComplete(_ message: String) {
        Task {
            do {
                try await elevenLabsService.speak(message, apiKey: appState.elevenLabsKey, voiceId: appState.selectedVoiceId)
            } catch {
                print("❌ Start message failed: \(error)")
            }
        }
        onComplete()
    }
}

// MARK: - Personality Extensions

extension BotPersonality {
    var shortDescription: String {
        switch self {
        case .pemberton: return "Posh British nagger"
        case .sergent: return "Drill sergeant energy"
        case .cheerleader: return "Endless positivity"
        case .butler: return "Formal and polite"
        case .coach: return "Sports motivation"
        case .zen: return "Calm and mindful"
        case .parent: return "Warm and supportive"
        case .bestie: return "Your best friend"
        case .robot: return "Just the facts"
        case .therapist: return "Gentle check-ins"
        case .hypeFriend: return "MAXIMUM HYPE"
        case .chillBuddy: return "Low pressure vibes"
        case .snarky: return "Sarcastic humor"
        case .gamer: return "Quest mode activated"
        case .tiredParent: return "Relatable exhaustion"
        }
    }

    var introGreeting: String {
        switch self {
        case .pemberton: return "Ah, splendid. I am The Gadfly. I shall be nagging you with great enthusiasm."
        case .sergent: return "ATTENTION! I am Sergeant Focus! We will get things DONE!"
        case .cheerleader: return "Yay! I'm Sunny! I'm SO excited to help you today!"
        case .butler: return "Good day. I am Alfred. I shall attend to your schedule with utmost care."
        case .coach: return "Hey champ! Coach Max here! Ready to crush it today!"
        case .zen: return "I am Master Kai. Together, we shall find focus and peace."
        case .parent: return "Hi sweetie, I'm here to help you through your day."
        case .bestie: return "Hey! It's me, your best friend! We're gonna have a great day!"
        case .robot: return "System initialized. I am your task management unit."
        case .therapist: return "Hello. I'm Dr. Gentle. I'm here to support you today."
        case .hypeFriend: return "OH MY GOD HI! I'M YOUR HYPE FRIEND! TODAY IS GOING TO BE AMAZING!"
        case .chillBuddy: return "Hey... I'm your chill buddy. No stress. We got this."
        case .snarky: return "Oh great, another day of pretending to be productive. I'm here to help. Allegedly."
        case .gamer: return "Player detected! Achievement Hunter online! Quest log loading!"
        case .tiredParent: return "Hi... I'm tired, you're tired, but we're gonna make it through today. Somehow."
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
