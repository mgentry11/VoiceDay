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
    @State private var loadedVoices: [ElevenLabsService.Voice] = []
    @State private var showResumePrompt = false
    @ObservedObject private var sessionService = SessionStateService.shared

    // Check if onboarding should show - show if no voice selected
    private var needsOnboarding: Bool {
        let hasApiKey = !appState.elevenLabsKey.isEmpty
        let hasVoice = !appState.selectedVoiceId.isEmpty
        let completedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        // Show onboarding if has API key but no voice selected AND not completed
        let shouldShow = hasApiKey && (!hasVoice || !completedOnboarding)
        print("🎯 needsOnboarding CHECK:")
        print("   hasApiKey: \(hasApiKey)")
        print("   hasVoice: \(hasVoice) (id: '\(appState.selectedVoiceId)')")
        print("   completedOnboarding: \(completedOnboarding)")
        print("   shouldShow: \(shouldShow)")
        return shouldShow
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

            SimpleSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(themeColors.accent)
        .id(themeColors.currentTheme.rawValue) // Force rebuild when theme changes
        .onAppear {
            print("🚀 ContentView onAppear - voiceId: '\(appState.selectedVoiceId)'")
            if !appState.hasValidClaudeKey {
                appState.selectedTab = 3
            }
            
            sessionService.startAutoSave()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🚀 Checking onboarding - needsOnboarding: \(needsOnboarding), voicesLoaded: \(voicesLoaded)")
                if needsOnboarding && !voicesLoaded {
                    Task {
                        await loadVoicesAndShowPicker()
                    }
                } else if sessionService.hasInterruptedSession && sessionService.canResume {
                    showResumePrompt = true
                }
            }
        }
        .sheet(isPresented: $showResumePrompt) {
            if let resumeInfo = sessionService.getResumeInfo() {
                ResumeSessionView(
                    resumeInfo: resumeInfo,
                    onResume: {
                        handleSessionResume()
                    },
                    onStartFresh: {
                        sessionService.clearInterruption()
                    }
                )
            }
        }
        // Voice setup - DISABLED temporarily (was blocking touches)
        .fullScreenCover(isPresented: .constant(false)) {
            VoiceSetupView(
                voices: loadedVoices,
                onComplete: {
                    showVoiceSetup = false
                    // Mark onboarding complete
                    UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
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
        print("🎤 Loading voices for onboarding... API key: \(appState.elevenLabsKey.prefix(10))...")
        do {
            let voices = try await elevenLabsService.fetchVoices(apiKey: appState.elevenLabsKey)
            print("🎤 Loaded \(voices.count) voices:")
            for voice in voices.prefix(5) {
                print("   - \(voice.name) (\(voice.voice_id))")
            }
            await MainActor.run {
                loadedVoices = voices
                showVoiceSetup = true
            }
        } catch {
            print("❌ Failed to load voices: \(error)")
            await MainActor.run {
                loadedVoices = []
                showVoiceSetup = true
            }
        }
    }
    
    private func handleSessionResume() {
        guard let progress = sessionService.currentState.checkInProgress else { return }
        
        switch progress.type {
        case .morning:
            appState.triggerMorningChecklist = true
        case .midday:
            appState.triggerMiddayChecklist = true
        case .evening:
            appState.triggerEveningChecklist = true
        case .bedtime:
            appState.triggerEveningChecklist = true
        }
        
        appState.selectedTab = 0
    }
}

// MARK: - Onboarding Flow

struct VoiceSetupView: View {
    let voices: [ElevenLabsService.Voice]
    let onComplete: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // 0: Voice, 1: Personality, 2: Daily Structure, 3: Nagging Level, 4: Start Choice
    @State private var currentStep = 0
    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Step labels
                HStack {
                    Text(stepLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentStep + 1) of \(totalSteps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)

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
                    DailyStructureStep {
                        withAnimation { currentStep = 3 }
                    }
                case 3:
                    NaggingLevelStep {
                        withAnimation { currentStep = 4 }
                    }
                case 4:
                    StartChoiceStep {
                        DayStructureService.shared.hasCompletedSetup = true
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

    private var stepLabel: String {
        switch currentStep {
        case 0: return "Voice"
        case 1: return "Personality"
        case 2: return "Daily Structure"
        case 3: return "Reminders"
        case 4: return "Get Started"
        default: return ""
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
    @State private var localVoices: [ElevenLabsService.Voice] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedId: String = "" // Local tracking for UI

    @State private var showQuickStart = false

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

            // Quick Start option
            Button {
                quickStart()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Quick Start with Defaults")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Voice list
            List {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading voices...")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if displayVoices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("No voices loaded")
                            .font(.headline)
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Check your internet connection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            loadVoices()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(displayVoices) { voice in
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
                            } else if selectedId == voice.voice_id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle()) // Make entire row tappable
                        .onTapGesture {
                            print("👆 TAPPED: \(voice.name)")
                            selectAndPreview(voice)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .onAppear {
                print("🎤 VoiceSelectionStep appeared with \(voices.count) passed voices")
                // Use passed voices or load if empty
                if voices.isEmpty && localVoices.isEmpty {
                    loadVoices()
                } else if !voices.isEmpty {
                    localVoices = voices
                }
            }

            // Continue button
            if !selectedId.isEmpty {
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

    // Use local voices if loaded, otherwise passed voices
    private var displayVoices: [ElevenLabsService.Voice] {
        localVoices.isEmpty ? voices : localVoices
    }

    private func loadVoices() {
        isLoading = true
        errorMessage = nil
        print("🎤 VoiceSelectionStep: Loading voices directly...")

        Task {
            do {
                let loadedVoices = try await elevenLabsService.fetchVoices(apiKey: appState.elevenLabsKey)
                print("🎤 VoiceSelectionStep: Loaded \(loadedVoices.count) voices")
                await MainActor.run {
                    localVoices = loadedVoices
                    isLoading = false
                }
            } catch {
                print("❌ VoiceSelectionStep: Failed to load voices: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func selectAndPreview(_ voice: ElevenLabsService.Voice) {
        print("🎤🎤🎤 SELECTING VOICE: \(voice.name) (\(voice.voice_id))")
        print("🎤🎤🎤 API Key available: \(!appState.elevenLabsKey.isEmpty)")
        print("🎤🎤🎤 API Key prefix: \(appState.elevenLabsKey.prefix(10))...")

        // Update local state FIRST for immediate UI feedback
        selectedId = voice.voice_id
        playingVoiceId = voice.voice_id

        // Then update appState and UserDefaults
        appState.selectedVoiceId = voice.voice_id
        appState.selectedVoiceName = voice.name
        UserDefaults.standard.set(voice.voice_id, forKey: "selected_voice_id")
        UserDefaults.standard.set(voice.name, forKey: "selected_voice_name")
        UserDefaults.standard.synchronize()

        print("🎤🎤🎤 Saved to UserDefaults, now speaking...")

        Task {
            do {
                try await elevenLabsService.speak("Hello! This is how I sound.", apiKey: appState.elevenLabsKey, voiceId: voice.voice_id)
                print("🎤🎤🎤 Preview COMPLETE!")
            } catch {
                print("❌❌❌ Voice preview FAILED: \(error)")
                print("❌❌❌ Error details: \(error.localizedDescription)")
            }
            await MainActor.run {
                playingVoiceId = nil
            }
        }
    }

    private func quickStart() {
        if let firstVoice = displayVoices.first {
            appState.selectedVoiceId = firstVoice.voice_id
            appState.selectedVoiceName = firstVoice.name
            UserDefaults.standard.set(firstVoice.voice_id, forKey: "selected_voice_id")
            UserDefaults.standard.set(firstVoice.name, forKey: "selected_voice_name")
        }

        appState.selectedPersonality = .cheerleader
        appState.isSimpleMode = true

        DayStructureService.shared.resetToDefaults()
        NaggingLevelService.shared.resetToDefaults()
        DayStructureService.shared.hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        UserDefaults.standard.synchronize()

        SpeechService.shared.queueSpeech("Welcome! Let's get started.")
        
        appState.selectedTab = 0
        onNext()
    }
}

// MARK: - Step 2: Personality Selection

struct PersonalitySelectionStep: View {
    let onNext: () -> Void

    @EnvironmentObject var appState: AppState
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var isPlaying = false
    @State private var showAllPersonalities = false

    // 5 Core archetypes for Simple mode
    private var displayedPersonalities: [BotPersonality] {
        if showAllPersonalities || !appState.isSimpleMode {
            return Array(BotPersonality.allCases)
        } else {
            return BotPersonality.corePersonalities
        }
    }

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
                // Core personalities section
                Section {
                    ForEach(displayedPersonalities) { personality in
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
                } header: {
                    if showAllPersonalities {
                        Text("All Personalities")
                    }
                }

                // Show more button (only in Simple mode when not expanded)
                if appState.isSimpleMode && !showAllPersonalities {
                    Section {
                        Button {
                            withAnimation {
                                showAllPersonalities = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.blue)
                                Text("Show 10 more personalities...")
                                    .foregroundStyle(.blue)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            // Continue button
            Button(action: onNext) {
                Text("Next: Daily Structure")
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
        print("🎭 Selected personality: \(personality.displayName)")
        appState.selectedPersonality = personality
        isPlaying = true

        Task {
            let greeting = personality.introGreeting
            print("🎭 Speaking personality intro: \(greeting.prefix(50))...")
            do {
                try await elevenLabsService.speak(greeting, apiKey: appState.elevenLabsKey, voiceId: appState.selectedVoiceId)
                print("🎭 Personality preview complete!")
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
    @State private var showBedtimeChecklist = false
    @State private var showSettings = false

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
                        startWithMorningCheckIn()
                    } label: {
                        startOptionRow(
                            icon: "sunrise.fill",
                            color: .orange,
                            title: "Morning Check-in",
                            subtitle: "Start your day with a guided routine"
                        )
                    }
                    .padding(.horizontal)

                    // Mid-day Check-in option
                    Button {
                        startWithMiddayCheckIn()
                    } label: {
                        startOptionRow(
                            icon: "sun.max.fill",
                            color: .yellow,
                            title: "Mid-day Check-in",
                            subtitle: "Quick focus reset"
                        )
                    }
                    .padding(.horizontal)

                    // Evening Check-in option
                    Button {
                        startWithEveningCheckIn()
                    } label: {
                        startOptionRow(
                            icon: "moon.fill",
                            color: .indigo,
                            title: "Evening Check-in",
                            subtitle: "Reflect on your day"
                        )
                    }
                    .padding(.horizontal)

                    // Custom Check-in option
                    Button {
                        startWithCustomCheckIn()
                    } label: {
                        startOptionRow(
                            icon: "slider.horizontal.3",
                            color: .teal,
                            title: "Custom Check-in",
                            subtitle: "Build your own routine"
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
                            color: .green,
                            title: "Focus Mode",
                            subtitle: "Simple view, one thing at a time"
                        )
                    }
                    .padding(.horizontal)

                    // Bedtime checklist option
                    Button {
                        startWithBedtimeChecklist()
                    } label: {
                        startOptionRow(
                            icon: "moon.stars.fill",
                            color: .indigo,
                            title: "Bedtime Checklist",
                            subtitle: "Make sure you're ready for tomorrow"
                        )
                    }
                    .padding(.horizontal)

                    // Record option
                    Button {
                        startWithRecord()
                    } label: {
                        startOptionRow(
                            icon: "mic.fill",
                            color: .red,
                            title: "Voice Record",
                            subtitle: "Tell me what you need to do"
                        )
                    }
                    .padding(.horizontal)

                    // Settings option
                    Button {
                        showSettings = true
                    } label: {
                        startOptionRow(
                            icon: "gearshape.fill",
                            color: .gray,
                            title: "Settings",
                            subtitle: "Configure app preferences"
                        )
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            // Set Simple mode by default since it's pre-selected
            appState.isSimpleMode = true
            print("🎯 StartChoiceStep: Simple mode set by default")
        }
        .fullScreenCover(isPresented: $showBedtimeChecklist) {
            SelfCheckView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func startWithBedtimeChecklist() {
        // Mark onboarding as complete and show bedtime checklist
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        showBedtimeChecklist = true
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

    private func startWithMorningCheckIn() {
        // Set trigger so FocusHomeView opens the morning checklist automatically
        // Don't speak here - the checklist will speak its own greeting
        appState.triggerMorningChecklist = true
        completeOnboardingOnly()
        appState.selectedTab = 0
    }

    private func startWithMiddayCheckIn() {
        // Set trigger so FocusHomeView opens the midday check-in
        // Don't speak here - the checklist will speak its own greeting
        appState.triggerMiddayChecklist = true
        completeOnboardingOnly()
        appState.selectedTab = 0
    }

    private func startWithEveningCheckIn() {
        // Set trigger so FocusHomeView opens the evening check-in automatically
        // Don't speak here - the checklist will speak its own greeting
        appState.triggerEveningChecklist = true
        completeOnboardingOnly()
        appState.selectedTab = 0
    }

    private func startWithCustomCheckIn() {
        speakAndComplete("Let's set up your custom routine! Go to Settings to customize your check-ins.")
        appState.selectedTab = 3
    }

    private func startWithTasks() {
        speakAndComplete("Let's see what you have to do today!")
        appState.selectedTab = 2
    }

    private func startWithFocus() {
        speakAndComplete("Focus mode. One thing at a time. You've got this.")
        appState.selectedTab = 0
    }

    private func startWithRecord() {
        speakAndComplete("I'm listening. Tell me what you need to get done.")
        appState.selectedTab = 1
    }

    private func speakAndComplete(_ message: String) {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")

        Task {
            do {
                try await elevenLabsService.speak(message, apiKey: appState.elevenLabsKey, voiceId: appState.selectedVoiceId)
            } catch {
                print("❌ Start message failed: \(error)")
            }
        }
        onComplete()
    }

    private func completeOnboardingOnly() {
        // Mark onboarding as complete without speaking (checklist will speak)
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
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
        case .sage: return "Ancient wisdom"
        case .rebel: return "Fight the system"
        case .trickster: return "Chaotic energy"
        case .stoic: return "Duty and virtue"
        case .pirate: return "Adventure awaits"
        case .witch: return "Dark magic vibes"
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
        case .sage: return "Ah, young one. You seek guidance on your path. The journey of a thousand tasks begins with a single action."
        case .rebel: return "Society wants you distracted. The system profits from your chaos. Let's prove them wrong today."
        case .trickster: return "Oh, you're NOT going to be productive today? Good, good... unless... nah, forget I said anything."
        case .stoic: return "Today you are alive. Tomorrow is uncertain. What will you do with this finite time?"
        case .pirate: return "Ahoy, matey! The treasure of productivity awaits! What adventures shall we plunder today?"
        case .witch: return "The cauldron bubbles with potential. What ingredients shall we add to today's productivity potion?"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
