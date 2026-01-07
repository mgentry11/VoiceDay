import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var elevenLabsService = ElevenLabsService()
    @StateObject private var notificationService = NotificationService.shared
    @ObservedObject private var themeColors = ThemeColors.shared

    @State private var isLoadingVoices = false
    @State private var voiceError: String?
    @State private var showVoicePicker = false
    @State private var messageCount = 0
    @State private var generatedCount = 0
    @State private var isGenerating = false
    @State private var showThemeSaved = false
    @State private var savedThemeName = ""
    @State private var showMorningChecklistSettings = false
    @State private var showCustomCheckInsSettings = false
    @State private var showPersonalitySaved = false
    @State private var savedPersonalityName = ""
    @State private var showVoiceSaved = false
    @State private var savedVoiceName = ""

    // Personality change confirmation
    @State private var showPersonalityConfirmation = false
    @State private var pendingPersonality: BotPersonality?

    // Location-based checkout checklists
    @State private var showLocationsManager = false

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Simple/Pro Mode Toggle (always visible)
                    simpleModeSection

                    // Version Selector Section (always visible)
                    versionSection

                    // Core sections (always visible)
                    appearanceSection
                    profileSection
                    personalitySection

                    // Voice section (always visible - critical for user experience)
                    if appState.isSimpleMode {
                        simpleVoiceSection
                    }

                    // Pro-only sections (hidden in Simple mode)
                    if !appState.isSimpleMode {
                        PresetModeSettingsSection()
                        EnergySettingsSection()
                        openAISection
                        elevenLabsSection
                        reminderSection
                    }

                    // Morning checklist (always visible - core feature)
                    morningChecklistSection

                    // Custom check-ins (always visible - user-created routines)
                    customCheckInsSection

                    // Location-based checkout checklists (always visible)
                    locationsSection

                    // Pro-only sections
                    if !appState.isSimpleMode {
                        celebrationSection
                        selfCareSection
                        endOfDayCheckSection
                        rewardBreaksSection
                        breakModeSection
                        messageGenerationSection
                        connectionsSection
                    }

                    // About and Legal (always visible)
                    aboutSection
                    legalSection

                    // Reset App (always visible at bottom)
                    resetAppSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground)

                // Theme saved toast
                if showThemeSaved {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.title2)
                            Text("\(savedThemeName) Theme Saved!")
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(themeColors.accent)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }

                // Personality saved toast
                if showPersonalitySaved {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.title2)
                            Text("\(savedPersonalityName) Saved!")
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(themeColors.accent)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }

                // Voice saved toast
                if showVoiceSaved {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.title2)
                            Text("Voice: \(savedVoiceName) Saved!")
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(themeColors.accent)
                        .cornerRadius(30)
                        .shadow(radius: 10)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.3), value: showThemeSaved)
            .animation(.spring(response: 0.3), value: showPersonalitySaved)
            .animation(.spring(response: 0.3), value: showVoiceSaved)
            .navigationTitle("Settings")
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(
                    voices: elevenLabsService.availableVoices,
                    selectedVoiceId: $appState.selectedVoiceId,
                    selectedVoiceName: $appState.selectedVoiceName,
                    onSave: { voiceName in
                        savedVoiceName = voiceName
                        // Delay to let sheet dismiss first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showVoiceSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showVoiceSaved = false
                            }
                        }
                    }
                )
            }
        }
        .id(themeColors.currentTheme.rawValue) // Force view refresh on theme change
    }

    private var appearanceSection: some View {
        Section {
            Picker("Mode", selection: $appState.selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            // Color Theme Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Color Theme")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(ColorTheme.allCases) { theme in
                        ColorThemeButton(
                            theme: theme,
                            isSelected: themeColors.currentTheme == theme,
                            onSelect: {
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()

                                // Update theme
                                appState.selectedColorTheme = theme
                                ThemeColors.shared.currentTheme = theme

                                // Show confirmation toast
                                savedThemeName = theme.rawValue
                                showThemeSaved = true

                                // Hide toast after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showThemeSaved = false
                                }
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Appearance")
        }
    }

    private var profileSection: some View {
        Section {
            TextField("Your Name", text: $appState.userName)
                .textContentType(.name)

            TextField("Phone Number", text: $appState.userPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)

            if !appState.userName.isEmpty && !appState.userPhone.isEmpty {
                Button("Register with Gadfly Network") {
                    Task {
                        do {
                            try await GadflyAPIService.shared.register(
                                name: appState.userName,
                                phone: appState.userPhone
                            )
                            appState.isRegistered = true
                        } catch {
                            print("Registration error: \(error)")
                        }
                    }
                }
                .disabled(appState.isRegistered)

                if appState.isRegistered {
                    Label("Connected to Gadfly Network", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Your Profile")
        } footer: {
            Text("Register to share tasks and nag family members who also use Gadfly.")
        }
    }

    @State private var showMorePersonalities = false

    private var personalitySection: some View {
        Section {
            // Core personalities - always visible
            ForEach(BotPersonality.corePersonalities) { personality in
                PersonalityButton(
                    personality: personality,
                    isSelected: appState.selectedPersonality == personality
                ) {
                    // Skip if already selected
                    guard personality != appState.selectedPersonality else { return }

                    // Show confirmation
                    pendingPersonality = personality
                    showPersonalityConfirmation = true
                }
            }

            // More options toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showMorePersonalities.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showMorePersonalities ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundStyle(Color.themeAccent)
                    Text(showMorePersonalities ? "Show fewer" : "More options")
                        .font(.subheadline)
                        .foregroundStyle(Color.themeAccent)
                    Spacer()
                    Text("\(BotPersonality.morePersonalities.count) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // More personalities - expandable
            if showMorePersonalities {
                ForEach(BotPersonality.morePersonalities) { personality in
                    PersonalityButton(
                        personality: personality,
                        isSelected: appState.selectedPersonality == personality
                    ) {
                        // Skip if already selected
                        guard personality != appState.selectedPersonality else { return }

                        // Show confirmation
                        pendingPersonality = personality
                        showPersonalityConfirmation = true
                    }
                }
            }
        } header: {
            HStack {
                Image(systemName: "theatermasks.fill")
                    .foregroundStyle(themeColors.accent)
                Text("Pick Your Vibe")
            }
        } footer: {
            Text("These 5 personalities work best for ADHD. Tap to select.")
        }
        .alert("Change Personality?", isPresented: $showPersonalityConfirmation) {
            Button("Apply Changes") {
                applyPersonalityChange()
            }
            Button("Cancel", role: .cancel) {
                pendingPersonality = nil
            }
        } message: {
            if let personality = pendingPersonality {
                Text("Switch to \(personality.displayName)?\n\nThis will clear scheduled reminders so they use the new personality.")
            }
        }
    }

    private func applyPersonalityChange() {
        guard let personality = pendingPersonality else { return }

        withAnimation(.spring(response: 0.3)) {
            appState.selectedPersonality = personality
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Cancel all pending notifications with old personality
        NotificationService.shared.cancelAllNotifications()

        // Show save confirmation
        savedPersonalityName = personality.displayName
        showPersonalitySaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showPersonalitySaved = false
        }

        // Voice feedback
        SpeechService.shared.queueSpeech("\(personality.displayName) activated.")

        pendingPersonality = nil
    }

    // MARK: - Simple Voice Section (for Simple Mode)

    private var simpleVoiceSection: some View {
        Section {
            // Voice picker button
            Button {
                Task {
                    await loadVoices()
                    if voiceError == nil {
                        showVoicePicker = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(themeColors.accent)
                    Text("Change Voice")
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    if isLoadingVoices {
                        ProgressView()
                    } else if !appState.selectedVoiceName.isEmpty {
                        Text(appState.selectedVoiceName)
                            .foregroundStyle(.green)
                    } else {
                        Text("Select")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Show current voice state for debugging
            VStack(alignment: .leading, spacing: 4) {
                if let customId = VoiceCloningService.shared.customVoiceId {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Custom voice active: \(VoiceCloningService.shared.customVoiceName ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if !appState.selectedVoiceId.isEmpty {
                    Text("Selected: \(appState.selectedVoiceName) (\(appState.selectedVoiceId.prefix(8))...)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Reset ALL voice data (nuclear option)
            Button(role: .destructive) {
                // Clear custom voice
                VoiceCloningService.shared.clearCustomVoice()

                // Clear UserDefaults directly
                UserDefaults.standard.removeObject(forKey: "custom_voice_id")
                UserDefaults.standard.removeObject(forKey: "custom_voice_name")

                // Speak confirmation with system voice
                SpeechService.shared.queueSpeech("All voice data cleared. Please select a new voice.")
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                    Text("Reset All Voice Data")
                        .foregroundStyle(.red)
                }
            }

            if let error = voiceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("If you hear the wrong voice, tap 'Reset All Voice Data' first, then select your preferred voice.")
        }
    }

    private var openAISection: some View {
        Section {
            SecureField("API Key", text: $appState.claudeKey)
                .textContentType(.password)
                .autocorrectionDisabled()

            if appState.hasValidClaudeKey {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Claude AI")
        } footer: {
            Text("Required for AI-powered task parsing. Get your key at console.anthropic.com")
        }
    }

    private var elevenLabsSection: some View {
        Section {
            SecureField("Enter ElevenLabs API Key", text: $appState.elevenLabsKey)
                .textContentType(.password)
                .autocorrectionDisabled()

            if appState.hasValidElevenLabsKey {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Key set (\(appState.elevenLabsKey.prefix(8))...)")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            if appState.hasValidElevenLabsKey {
                Button {
                    Task {
                        await loadVoices()
                        if voiceError == nil {
                            showVoicePicker = true
                        }
                    }
                } label: {
                    HStack {
                        Text("Select Voice")
                        Spacer()
                        if isLoadingVoices {
                            ProgressView()
                            Text("Loading...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !elevenLabsService.availableVoices.isEmpty {
                            Text("\(elevenLabsService.availableVoices.count) voices")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Tap to load")
                                .foregroundStyle(Color.themeAccent)
                        }
                    }
                }
                .foregroundStyle(.primary)

                if !appState.selectedVoiceId.isEmpty {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(appState.selectedVoiceName)
                            .foregroundStyle(.green)
                    }
                }

                // Custom voice recording - encouraged!
                NavigationLink {
                    VoiceRecordingView()
                } label: {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Record Your Voice")
                                    .fontWeight(.semibold)
                                Text("✨ Recommended")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.themeAccent.opacity(0.8))
                                    .cornerRadius(4)
                            }
                            if let voiceName = VoiceCloningService.shared.customVoiceName {
                                Text("Active: \(voiceName)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Your brain responds 40% better to your own voice!")
                                    .font(.caption)
                                    .foregroundStyle(Color.themeAccent)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }

                // Voice debug info
                VStack(alignment: .leading, spacing: 4) {
                    if let customId = VoiceCloningService.shared.customVoiceId {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Custom: \(VoiceCloningService.shared.customVoiceName ?? customId)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    if !appState.selectedVoiceId.isEmpty {
                        Text("Selected: \(appState.selectedVoiceName)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                // Reset all voice data
                Button(role: .destructive) {
                    VoiceCloningService.shared.clearCustomVoice()
                    UserDefaults.standard.removeObject(forKey: "custom_voice_id")
                    UserDefaults.standard.removeObject(forKey: "custom_voice_name")
                    SpeechService.shared.queueSpeech("Voice data reset. Select a new voice.")
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All Voice Data")
                    }
                    .foregroundStyle(.red)
                }
            }

            if let error = voiceError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error:")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        } header: {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(themeColors.accent)
                Text("Voice & Reminders")
            }
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Why use your own voice?")
                    .font(.caption.bold())
                Text("Research shows we pay 40% more attention to our own voice (the \"cocktail party effect\"). Your brain instantly recognizes self-referential cues like your name and voice, cutting through distraction. For ADHD brains, this makes reminders significantly more effective.")
                    .font(.caption)
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Enable Reminders", isOn: $appState.remindersEnabled)

            Toggle("Keep Screen On", isOn: $appState.keepScreenOn)

            if appState.remindersEnabled {
                Picker("Nag Interval", selection: $appState.nagIntervalMinutes) {
                    Text("Every 5 minutes").tag(5)
                    Text("Every 10 minutes").tag(10)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                }

                Picker("Event Reminder", selection: $appState.eventReminderMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }

                Toggle("Daily Check-ins", isOn: $appState.dailyCheckInsEnabled)

                if appState.dailyCheckInsEnabled {
                    NavigationLink {
                        CheckInTimesView(selectedTimes: $appState.dailyCheckInTimes)
                    } label: {
                        HStack {
                            Text("Check-in Times")
                            Spacer()
                            Text("\(appState.dailyCheckInTimes.count) times")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Picker("Focus Session Check-ins", selection: $appState.focusCheckInMinutes) {
                    Text("Every 5 minutes").tag(5)
                    Text("Every 10 minutes").tag(10)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 20 minutes").tag(20)
                    Text("Every 30 minutes").tag(30)
                }

                Picker("Grace Period (before first reminder)", selection: $appState.focusGracePeriodMinutes) {
                    Text("No grace period").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("20 minutes").tag(20)
                    Text("30 minutes").tag(30)
                }

                Picker("Chide After Away (normal)", selection: $appState.timeAwayThresholdMinutes) {
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("20 minutes").tag(20)
                    Text("30 minutes").tag(30)
                    Text("Never").tag(9999)
                }

                Picker("Chide After Away (focus)", selection: $appState.focusTimeAwayThresholdMinutes) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("Never").tag(9999)
                }

                Picker("Nudge If Idle In App", selection: $appState.idleThresholdMinutes) {
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("Never").tag(9999)
                }

                Toggle("Morning Briefing", isOn: $appState.morningBriefingEnabled)

                Button("Test Notification (5 seconds)") {
                    notificationService.sendTestNotification()
                }
                .foregroundStyle(Color.themeAccent)
            }
        } header: {
            Text("The Gadfly's Nagging")
        } footer: {
            Text("Keep Screen On prevents auto-lock so Gadfly stays active and can speak reminders. Focus Sessions also keep the screen on automatically.")
        }
    }

    private var morningChecklistSection: some View {
        Section {
            Button {
                showMorningChecklistSettings = true
            } label: {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text("Morning Checklist")
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    Text("\(MorningChecklistService.shared.selfChecks.count) items")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Reset for testing
            Button {
                // Reset morning self-checks
                MorningChecklistService.shared.resetForTesting()

                // Reset calendar/tasks review tracking
                UserDefaults.standard.removeObject(forKey: "calendar_review_last_shown")
                UserDefaults.standard.removeObject(forKey: "tasks_review_last_shown")
                UserDefaults.standard.removeObject(forKey: "morning_routine_completed_today")

                // Cancel all pending notifications so they reschedule with current personality
                NotificationService.shared.cancelAllNotifications()

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                SpeechService.shared.queueSpeech("All check-ins and notifications reset.")
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.blue)
                    Text("Reset All Check-ins (Test)")
                        .foregroundStyle(themeColors.text)
                }
            }
        } header: {
            Text("Daily Routines")
        } footer: {
            Text("Create personal morning checks like 'Take medication' or 'Check calendar'. The bot will walk you through them each morning.")
        }
        .sheet(isPresented: $showMorningChecklistSettings) {
            ManageSelfChecksView()
        }
    }

    private var customCheckInsSection: some View {
        Section {
            Button {
                showCustomCheckInsSettings = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(themeColors.accent)
                    Text("Custom Check-ins")
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    Text("\(DayStructureService.shared.customCheckIns.count) created")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Custom Routines")
        } footer: {
            Text("Create personalized check-ins for any time of day. Set custom times, icons, colors, and items.")
        }
        .sheet(isPresented: $showCustomCheckInsSettings) {
            ManageCustomCheckInsView()
        }
    }

    private var locationsSection: some View {
        Section {
            Button {
                showLocationsManager = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text("Checkout Locations")
                        .foregroundStyle(themeColors.text)
                    Spacer()
                    Text("\(LocationService.shared.savedLocations.count) saved")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Test location exit (development)
            #if DEBUG
            if let firstLocation = LocationService.shared.savedLocations.first {
                Button {
                    LocationService.shared.simulateExitFromLocation(firstLocation)
                } label: {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundStyle(.orange)
                        Text("Test Exit: \(firstLocation.name)")
                            .foregroundStyle(.orange)
                    }
                }
            }
            #endif
        } header: {
            Text("Location Checklists")
        } footer: {
            Text("Save locations like 'Gym' or 'Work' and create exit checklists that trigger when you leave. Great for post-workout routines!")
        }
        .sheet(isPresented: $showLocationsManager) {
            LocationsManagerView()
        }
    }

    private var celebrationSection: some View {
        Section {
            Toggle("Celebration Haptics", isOn: Binding(
                get: { CelebrationService.shared.celebrationHapticsEnabled },
                set: { CelebrationService.shared.celebrationHapticsEnabled = $0 }
            ))

            Toggle("Celebration Sounds", isOn: Binding(
                get: { CelebrationService.shared.celebrationSoundsEnabled },
                set: { CelebrationService.shared.celebrationSoundsEnabled = $0 }
            ))

            Toggle("Confetti Animations", isOn: Binding(
                get: { CelebrationService.shared.celebrationAnimationsEnabled },
                set: { CelebrationService.shared.celebrationAnimationsEnabled = $0 }
            ))

            // Momentum display
            MomentumCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

        } header: {
            Text("Celebrations & Momentum")
        } footer: {
            Text("Get rewarded for completing tasks! Haptics, sounds, and confetti celebrate your progress. Momentum builds over time and decays slowly - no punishing streak resets.")
        }
    }

    // MARK: - Self-Care Section
    @ObservedObject private var selfCareService = SelfCareService.shared

    private var selfCareSection: some View {
        Section {
            Toggle("Enable Self-Care Reminders", isOn: $selfCareService.isEnabled)

            if selfCareService.isEnabled {
                // Care Level Picker
                Picker("Reminder Intensity", selection: $selfCareService.careLevel) {
                    ForEach(SelfCareService.CareLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }

                // Age Mode
                Picker("I am a...", selection: $selfCareService.ageMode) {
                    ForEach(SelfCareService.AgeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                // Hydration
                NavigationLink {
                    SelfCareDetailView(
                        title: "Hydration",
                        icon: "drop.fill",
                        iconColor: .blue,
                        isEnabled: $selfCareService.waterSettings.isEnabled,
                        intervalMinutes: $selfCareService.waterSettings.intervalMinutes,
                        intervalOptions: [30, 45, 60, 90]
                    )
                } label: {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.blue)
                        Text("Hydration")
                        Spacer()
                        if selfCareService.waterSettings.isEnabled {
                            Text("Every \(selfCareService.waterSettings.intervalMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Stretch/Movement
                NavigationLink {
                    SelfCareDetailView(
                        title: "Movement & Stretching",
                        icon: "figure.walk",
                        iconColor: .green,
                        isEnabled: $selfCareService.stretchSettings.isEnabled,
                        intervalMinutes: $selfCareService.stretchSettings.intervalMinutes,
                        intervalOptions: [20, 30, 45, 60]
                    )
                } label: {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.green)
                        Text("Movement")
                        Spacer()
                        if selfCareService.stretchSettings.isEnabled {
                            Text("Every \(selfCareService.stretchSettings.intervalMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Eye Rest
                NavigationLink {
                    SelfCareDetailView(
                        title: "Eye Rest (20-20-20)",
                        icon: "eye.fill",
                        iconColor: .purple,
                        isEnabled: $selfCareService.eyeSettings.isEnabled,
                        intervalMinutes: $selfCareService.eyeSettings.intervalMinutes,
                        intervalOptions: [20, 30, 45]
                    )
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(.purple)
                        Text("Eye Rest")
                        Spacer()
                        if selfCareService.eyeSettings.isEnabled {
                            Text("Every \(selfCareService.eyeSettings.intervalMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Hyperfocus Breaks
                NavigationLink {
                    HyperfocusBreakSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "arrow.2.circlepath")
                            .foregroundStyle(.orange)
                        Text("Hyperfocus Breaks")
                        Spacer()
                        if selfCareService.hyperfocusSettings.isEnabled {
                            Text("Every \(selfCareService.hyperfocusSettings.intervalMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Meals
                NavigationLink {
                    MealSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.red)
                        Text("Meal Reminders")
                        Spacer()
                        if selfCareService.mealSettings.isEnabled {
                            Text("\(selfCareService.mealSettings.mealCount) meals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("Self-Care Mode")
            }
        } footer: {
            Text("Like a caring parent reminding you to take care of yourself. Get nudges for water, food, breaks, and more.")
        }
    }

    // MARK: - End-of-Day Check Section
    @ObservedObject private var selfCheckService = SelfCheckService.shared

    private var endOfDayCheckSection: some View {
        Section {
            Toggle("Enable End-of-Day Check", isOn: $selfCheckService.isEnabled)

            if selfCheckService.isEnabled {
                NavigationLink {
                    SelfCheckSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "checklist.checked")
                            .foregroundStyle(.green)
                        Text("Configure Items")
                        Spacer()
                        Text("\(selfCheckService.enabledItems.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Scheduled Reminder", isOn: $selfCheckService.useScheduledReminder)

                if selfCheckService.useScheduledReminder {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { selfCheckService.scheduledTime ?? Date() },
                            set: { selfCheckService.scheduledTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        } header: {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.indigo)
                Text("End-of-Day Check")
            }
        } footer: {
            Text("When all tasks are done, run through a quick checklist to make sure you know where important items are (keys, wallet, phone, etc.).")
        }
    }

    // MARK: - Reward Breaks Section
    private var rewardBreaksSection: some View {
        Section {
            Toggle("Enable Reward Breaks", isOn: $appState.rewardBreaksEnabled)

            if appState.rewardBreaksEnabled {
                Picker("Break Duration", selection: $appState.rewardBreakDuration) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("20 minutes").tag(20)
                }

                Toggle("Auto-suggest after tasks", isOn: $appState.autoSuggestBreaks)
            }
        } header: {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(themeColors.accent)
                Text("Reward Breaks")
            }
        } footer: {
            Text("Take a 15-minute break after completing tasks. Perfect for studying! Your brain needs rest to consolidate learning.")
        }
    }

    private var breakModeSection: some View {
        Section {
            if appState.isBreakModeActive, let endTime = appState.breakModeEndTime {
                // Show active break mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Break Mode Active")
                                .font(.headline)
                            Text("Resuming at \(endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Button {
                        appState.endBreakMode()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("End Break Early")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                // Show break mode controls
                Text("Take a break from notifications")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    BreakButton(minutes: 15, appState: appState)
                    BreakButton(minutes: 30, appState: appState)
                    BreakButton(minutes: 60, appState: appState)
                    BreakButton(minutes: 120, appState: appState)
                }

                // Until specific time option
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Or say: \"Gadfly, take a break until 5pm\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Break Mode")
        } footer: {
            Text("Pause all notifications temporarily. You can also say \"I'm taking a break for 30 minutes\" to the Gadfly.")
        }
    }

    private var messageGenerationSection: some View {
        Section {
            HStack {
                Text("Available Messages")
                Spacer()
                Text("\(messageCount)")
                    .foregroundStyle(.secondary)
            }

            if generatedCount > 0 {
                HStack {
                    Text("AI-Generated")
                    Spacer()
                    Text("\(generatedCount)")
                        .foregroundStyle(.green)
                }
            }

            Button {
                generateMoreMessages()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Generating...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Generate 20 New Messages")
                    }
                    Spacer()
                }
            }
            .disabled(isGenerating || !appState.hasValidClaudeKey)

            if generatedCount > 0 {
                Button(role: .destructive) {
                    notificationService.clearGeneratedMessages()
                    updateMessageCounts()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Generated Messages")
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Message Variety")
        } footer: {
            Text("Generate fresh AI-written nag messages so The Gadfly never repeats himself.")
        }
        .onAppear {
            updateMessageCounts()
        }
    }

    @State private var messageGenerationError: String?

    private func updateMessageCounts() {
        messageCount = notificationService.totalMessageCount
        generatedCount = notificationService.generatedMessageCount
    }

    private func generateMoreMessages() {
        isGenerating = true
        messageGenerationError = nil

        Task {
            do {
                let openAI = OpenAIService()
                let messages = try await openAI.generateNewNagMessages(apiKey: appState.claudeKey, count: 20)
                notificationService.addGeneratedMessages(messages)
                updateMessageCounts()
            } catch {
                messageGenerationError = error.localizedDescription
                print("Message generation error: \(error)")
            }
            isGenerating = false
        }
    }

    private var connectionsSection: some View {
        Section {
            if appState.isRegistered {
                NavigationLink {
                    ManagerDashboardView()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(.green)
                        Text("Manager Dashboard")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    ConnectionsListView()
                } label: {
                    HStack {
                        Text("Family & Friends")
                        Spacer()
                        Text("\(GadflyAPIService.shared.connections.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    SharedTasksView()
                } label: {
                    HStack {
                        Text("Shared Tasks")
                        Spacer()
                        Text("\(GadflyAPIService.shared.sharedTasks.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    MyRewardsView()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("My Points & Rewards")
                        Spacer()
                        Text("\(RewardsService.shared.myPoints) pts")
                            .foregroundStyle(.green)
                    }
                }
            } else {
                Text("Register above to share tasks with family")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Team & Rewards")
        } footer: {
            Text("Manage your team, assign tasks, and earn rewards for completing them.")
        }
    }

    // MARK: - Version Section
    private var versionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose the experience that fits you best")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    VersionButton(
                        icon: "rainbow",
                        title: "Kids",
                        subtitle: "Simple & fun",
                        isSelected: appState.appVersion == .kids
                    ) {
                        appState.appVersion = .kids
                    }

                    VersionButton(
                        icon: "bolt.fill",
                        title: "Teens",
                        subtitle: "School & life",
                        isSelected: appState.appVersion == .teens
                    ) {
                        appState.appVersion = .teens
                    }

                    VersionButton(
                        icon: "scope",
                        title: "Adults",
                        subtitle: "Full features",
                        isSelected: appState.appVersion == .adults
                    ) {
                        appState.appVersion = .adults
                    }
                }

                // Feature toggles for adults
                if appState.appVersion == .adults {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you want help with?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            FeatureToggle(icon: "briefcase.fill", label: "Work", isOn: $appState.featureWork)
                            FeatureToggle(icon: "book.fill", label: "School", isOn: $appState.featureSchool)
                            FeatureToggle(icon: "figure.run", label: "Health", isOn: $appState.featureHealth)
                            FeatureToggle(icon: "house.fill", label: "Home", isOn: $appState.featureHome)
                            FeatureToggle(icon: "paintbrush.fill", label: "Creative", isOn: $appState.featureCreative)
                            FeatureToggle(icon: "person.2.fill", label: "Social", isOn: $appState.featureSocial)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(themeColors.accent)
                Text("My Version")
            }
        } footer: {
            Text(versionFooterText)
        }
    }

    private var versionFooterText: String {
        switch appState.appVersion {
        case .kids:
            return "Bigger buttons, simpler interface, more celebrations!"
        case .teens:
            return "Balanced features for school, homework, and life."
        case .adults:
            return "Full feature set with customizable focus areas."
        }
    }

    // MARK: - Simple/Pro Mode Section

    private var simpleModeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // Simple Mode Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3)) {
                            appState.isSimpleMode = true
                        }
                        SpeechService.shared.queueSpeech("Simple mode. Voice-guided walk-through enabled.")
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                            Text("Simple")
                                .font(.headline)
                            Text("Less is more")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appState.isSimpleMode ? themeColors.accent.opacity(0.2) : Color.themeSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(appState.isSimpleMode ? themeColors.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appState.isSimpleMode ? themeColors.accent : .primary)

                    // Pro Mode Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3)) {
                            appState.isSimpleMode = false
                        }
                        SpeechService.shared.queueSpeech("Pro mode. All features unlocked.")
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                            Text("Pro")
                                .font(.headline)
                            Text("All features")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(!appState.isSimpleMode ? themeColors.accent.opacity(0.2) : Color.themeSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(!appState.isSimpleMode ? themeColors.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(!appState.isSimpleMode ? themeColors.accent : .primary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(themeColors.accent)
                Text("Interface Mode")
            }
        } footer: {
            Text(appState.isSimpleMode
                 ? "Simple mode hides advanced settings for a cleaner experience."
                 : "Pro mode shows all settings and advanced features.")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.green)
                    Text("Help & Guide")
                }
            }

            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://console.anthropic.com")!) {
                HStack {
                    Text("Get Claude API Key")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }

            Link(destination: URL(string: "https://elevenlabs.io")!) {
                HStack {
                    Text("Get ElevenLabs API Key")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        Section {
            Link(destination: URL(string: "https://bigoil.net/gadfly-privacy.html")!) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.blue)
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                HealthDisclaimerView()
            } label: {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(.red)
                    Text("Health Disclaimer")
                }
            }

            Button(role: .destructive) {
                // TODO: Implement account deletion
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Account")
                }
            }
        } header: {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(themeColors.accent)
                Text("Legal & Privacy")
            }
        } footer: {
            Text("Your data is stored securely. You can delete your account and all associated data at any time.")
        }
    }

    private var resetAppSection: some View {
        Section {
            Button {
                restartFromBeginning()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.blue)
                    Text("Restart from Beginning")
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
        } header: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                Text("Restart")
            }
        } footer: {
            Text("Go back to onboarding to change voice, personality, or mode.")
        }
    }

    private func restartFromBeginning() {
        // Just reset onboarding flag - keeps all other settings
        UserDefaults.standard.set(false, forKey: "has_completed_onboarding")
        UserDefaults.standard.synchronize()

        // Force app to restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }

    private func loadVoices() async {
        guard appState.hasValidElevenLabsKey else { return }

        isLoadingVoices = true
        voiceError = nil

        do {
            _ = try await elevenLabsService.fetchVoices(apiKey: appState.elevenLabsKey)
        } catch {
            voiceError = error.localizedDescription
        }

        isLoadingVoices = false
    }
}

// MARK: - Blocked Voices Manager
class BlockedVoicesManager: ObservableObject {
    static let shared = BlockedVoicesManager()
    private let key = "permanently_blocked_voices"

    @Published var blockedVoiceIds: Set<String> = []

    init() {
        loadBlockedVoices()
    }

    private func loadBlockedVoices() {
        if let blocked = UserDefaults.standard.array(forKey: key) as? [String] {
            blockedVoiceIds = Set(blocked)
        }
    }

    func blockVoice(id: String, name: String) {
        blockedVoiceIds.insert(id)
        saveBlockedVoices()
        print("🚫 Permanently blocked voice: \(name) (\(id))")
    }

    func unblockVoice(id: String) {
        blockedVoiceIds.remove(id)
        saveBlockedVoices()
    }

    func isBlocked(id: String) -> Bool {
        blockedVoiceIds.contains(id)
    }

    private func saveBlockedVoices() {
        UserDefaults.standard.set(Array(blockedVoiceIds), forKey: key)
    }
}

struct VoicePickerView: View {
    let voices: [ElevenLabsService.Voice]
    @Binding var selectedVoiceId: String
    @Binding var selectedVoiceName: String
    var onSave: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var blockedVoices = BlockedVoicesManager.shared
    @StateObject private var elevenLabsService = ElevenLabsService()

    // Delete confirmation states
    @State private var voiceToDelete: ElevenLabsService.Voice?
    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if availableVoices.isEmpty {
                    Section {
                        Text("No voices available. Check your ElevenLabs API key.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Instructions
                    Section {
                        Text("Tap to select • Swipe left to permanently remove")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !britishVoices.isEmpty {
                        Section {
                            ForEach(britishVoices) { voice in
                                VoiceRow(
                                    voice: voice,
                                    isSelected: voice.voice_id == selectedVoiceId
                                ) {
                                    selectVoice(voice)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        voiceToDelete = voice
                                        showFirstConfirmation = true
                                    } label: {
                                        Label("Remove Forever", systemImage: "trash.fill")
                                    }
                                }
                            }
                        } header: {
                            Text("British Voices (Recommended)")
                        }
                    }

                    Section {
                        ForEach(otherVoices) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: voice.voice_id == selectedVoiceId
                            ) {
                                selectVoice(voice)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    voiceToDelete = voice
                                    showFirstConfirmation = true
                                } label: {
                                    Label("Remove Forever", systemImage: "trash.fill")
                                }
                            }
                        }
                    } header: {
                        Text(britishVoices.isEmpty ? "All Voices" : "Other Voices")
                    }
                }

                // Show blocked voices section if any exist
                if !blockedVoices.blockedVoiceIds.isEmpty {
                    Section {
                        Text("\(blockedVoices.blockedVoiceIds.count) voice(s) permanently hidden")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Blocked voices will never appear again.")
                    }
                }
            }
            .navigationTitle("Select Voice (\(availableVoices.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // First confirmation
            .alert("Remove This Voice?", isPresented: $showFirstConfirmation) {
                Button("Cancel", role: .cancel) {
                    voiceToDelete = nil
                }
                Button("Yes, Remove It", role: .destructive) {
                    showSecondConfirmation = true
                }
            } message: {
                if let voice = voiceToDelete {
                    Text("This will permanently hide \"\(voice.name)\" from your voice list.")
                }
            }
            // Second confirmation - more serious
            .alert("Confirm Permanent Removal", isPresented: $showSecondConfirmation) {
                Button("Cancel", role: .cancel) {
                    voiceToDelete = nil
                }
                Button("PERMANENTLY REMOVE", role: .destructive) {
                    if let voice = voiceToDelete {
                        blockedVoices.blockVoice(id: voice.voice_id, name: voice.name)
                        // If this was the selected voice, clear selection
                        if selectedVoiceId == voice.voice_id {
                            selectedVoiceId = ""
                            selectedVoiceName = ""
                        }
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    voiceToDelete = nil
                }
            } message: {
                if let voice = voiceToDelete {
                    Text("Are you absolutely sure?\n\n\"\(voice.name)\" will NEVER appear in this app again.\n\nThis cannot be undone.")
                }
            }
        }
    }

    // Filter out blocked voices
    private var availableVoices: [ElevenLabsService.Voice] {
        voices.filter { !blockedVoices.isBlocked(id: $0.voice_id) }
    }

    private var britishVoices: [ElevenLabsService.Voice] {
        availableVoices.filter { voice in
            let accent = voice.labels?.accent?.lowercased() ?? ""
            let name = voice.name.lowercased()
            return accent.contains("british") || accent.contains("english") ||
                   name.contains("daniel") || name.contains("george") || name.contains("charlotte")
        }
    }

    private var otherVoices: [ElevenLabsService.Voice] {
        availableVoices.filter { voice in
            !britishVoices.contains(where: { $0.voice_id == voice.voice_id })
        }
    }

    // MARK: - Voice Selection with Immediate Playback

    private func selectVoice(_ voice: ElevenLabsService.Voice) {
        // Save the selection
        selectedVoiceId = voice.voice_id
        selectedVoiceName = voice.name

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Callback
        onSave?(voice.name)

        // Speak immediately with the new voice in the chosen personality
        Task {
            await speakAsPersonality(voiceId: voice.voice_id, voiceName: voice.name)
        }

        // Dismiss after a short delay to let voice start playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    private func speakAsPersonality(voiceId: String, voiceName: String) async {
        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
        guard !apiKey.isEmpty else { return }

        // Get the greeting for the current personality
        let greeting = getPersonalityGreeting(voiceName: voiceName)

        do {
            try await elevenLabsService.speak(greeting, apiKey: apiKey, voiceId: voiceId)
        } catch {
            print("❌ Voice preview failed: \(error)")
        }
    }

    private func getPersonalityGreeting(voiceName: String) -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Ah, \(voiceName) it is. A fine choice. I shall nag you with this voice from now on."
        case .sergent:
            return "\(voiceName) reporting for duty! This is my new voice, soldier!"
        case .cheerleader:
            return "Yay! I'm \(voiceName) now! This is going to be so great!"
        case .butler:
            return "Very good. I shall address you as \(voiceName) from this moment forward."
        case .coach:
            return "Alright! \(voiceName) is in the game! Let's win this!"
        case .zen:
            return "I am now \(voiceName). May this voice bring you peace and focus."
        case .parent:
            return "Hi sweetie, I'm using \(voiceName) now. Hope you like it!"
        case .bestie:
            return "Hey! I'm \(voiceName) now! What do you think?"
        case .robot:
            return "Voice module updated. \(voiceName) activated."
        case .therapist:
            return "I'll be using \(voiceName) from now on. How does that feel?"
        case .hypeFriend:
            return "\(voiceName.uppercased()) IS HERE! LET'S GOOO!"
        case .chillBuddy:
            return "Cool... I'm \(voiceName) now. No big deal."
        case .snarky:
            return "Oh great, now I'm \(voiceName). Try not to get too attached."
        case .gamer:
            return "New voice unlocked: \(voiceName)! Achievement: Voice Customization!"
        case .tiredParent:
            return "Okay, I'm \(voiceName) now. That was exhausting to set up."
        case .sage:
            return "The voice of \(voiceName) shall guide your path from this moment."
        case .rebel:
            return "\(voiceName) is my new voice. Time to fight distraction together."
        case .trickster:
            return "I'm \(voiceName) now... or AM I? Yes. Yes I am."
        case .stoic:
            return "\(voiceName). A suitable voice for the work ahead."
        case .pirate:
            return "Ahoy! Captain \(voiceName) at yer service, matey!"
        case .witch:
            return "The \(voiceName) transformation spell is complete, darling."
        }
    }
}

struct VoiceRow: View {
    let voice: ElevenLabsService.Voice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .foregroundStyle(.primary)

                    if let labels = voice.labels {
                        HStack(spacing: 8) {
                            if let accent = labels.accent {
                                Text(accent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let description = labels.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.themeAccent)
                }
            }
        }
    }
}

struct CheckInTimesView: View {
    @Binding var selectedTimes: [String]
    @State private var newTime = Date()

    var body: some View {
        Form {
            Section {
                if selectedTimes.isEmpty {
                    Text("No check-in times set")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTimes, id: \.self) { timeString in
                        HStack {
                            Text(formatTimeString(timeString))
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        let sorted = sortedTimes
                        for index in indexSet {
                            if let idx = selectedTimes.firstIndex(of: sorted[index]) {
                                selectedTimes.remove(at: idx)
                            }
                        }
                    }
                }
            } header: {
                Text("Current Check-in Times (\(selectedTimes.count))")
            }

            Section {
                DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)

                Button("Add Check-in Time") {
                    let timeString = timeToString(newTime)
                    if !selectedTimes.contains(timeString) {
                        selectedTimes.append(timeString)
                    }
                }
                .disabled(selectedTimes.contains(timeToString(newTime)))
            } header: {
                Text("Add New Time")
            } footer: {
                Text("The Gadfly will check in on your progress at these times each day.")
            }
        }
        .navigationTitle("Check-in Times")
    }

    private var sortedTimes: [String] {
        selectedTimes.sorted()
    }

    private func timeToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatTimeString(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"

        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        }
        return timeString
    }
}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        List {
            gettingStartedSection
            sharingSection
            focusSessionSection
            tipsSection
        }
        .navigationTitle("Help & Guide")
    }

    private var gettingStartedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HelpStep(number: 1, title: "Speak or Type", description: "Tap the microphone to speak your tasks naturally, or use the keyboard button to type.")
                HelpStep(number: 2, title: "AI Parses Your Words", description: "The Gadfly extracts tasks, events, and reminders from what you say.")
                HelpStep(number: 3, title: "Confirm & Save", description: "Review the parsed items and tap to add them to your calendar and reminders.")
                HelpStep(number: 4, title: "Get Nagged", description: "You'll receive persistent reminders until you mark tasks as done.")
            }
            .padding(.vertical, 8)
        } header: {
            Text("Getting Started")
        }
    }

    private var sharingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Step 1: Register", systemImage: "1.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Go to Settings → Your Profile. Enter your name and phone number, then tap 'Register with Gadfly Network'.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Step 2: Add Connections", systemImage: "2.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Go to Settings → Family & Friends → tap +. Enter their nickname, phone number, and relationship.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Label("Has App", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Label("SMS Only", systemImage: "message.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Step 3: Assign Tasks", systemImage: "3.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Go to Settings → Shared Tasks → tap +. Describe the task, select who to assign it to, and set the nag interval.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("How Recipients Get Nagged", systemImage: "bell.badge.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("• If they have Gadfly: Push notifications\n• If they don't: SMS text messages\n• Nagging continues until done!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Sharing Tasks with Family")
        } footer: {
            Text("Others can also assign tasks to you - check Shared Tasks.")
        }
    }

    private var focusSessionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HelpStep(number: 1, title: "Start a Focus Session", description: "Tap the eye icon on the main screen.")
                HelpStep(number: 2, title: "Set Your Interval", description: "Choose how often to get check-ins (5-30 min).")
                HelpStep(number: 3, title: "Stay Focused", description: "Get regular spoken reminders. Screen stays on.")
                HelpStep(number: 4, title: "End When Done", description: "Tap the eye icon again to stop.")
            }
            .padding(.vertical, 8)
        } header: {
            Text("Focus Sessions")
        }
    }

    private var tipsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "sparkles", title: "Generate Messages", tip: "Get fresh AI-written nag messages in Settings.")
                TipRow(icon: "person.2", title: "Personalities", tip: "Try different assistants - drill sergeant to zen master!")
                TipRow(icon: "bell.badge", title: "Persistent Nagging", tip: "Only 'Done' stops the reminders!")
            }
            .padding(.vertical, 8)
        } header: {
            Text("Pro Tips")
        }
    }
}

struct HelpStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.green))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(tip).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

// MARK: - Color Theme Button

struct ColorThemeButton: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Color preview circle
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 44, height: 44)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 50, height: 50)
                    }
                }

                // Theme name
                Text(theme.rawValue.replacingOccurrences(of: " ", with: "\n"))
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.accent.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Break Mode Button

struct BreakButton: View {
    let minutes: Int
    let appState: AppState

    var label: String {
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        Button {
            appState.startBreakMode(durationMinutes: minutes)
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .cornerRadius(8)
        }
    }
}

// MARK: - Version Button

struct VersionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.themeAccent : .secondary)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.themeAccent.opacity(0.15) : Color.themeSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.themeAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Toggle

struct FeatureToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isOn ? Color.themeAccent : .secondary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOn ? Color.themeAccent.opacity(0.15) : Color.themeSecondary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Health Disclaimer View

struct HealthDisclaimerView: View {
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)

                    Text("Health Disclaimer")
                        .font(.title.bold())
                        .foregroundStyle(themeColors.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                // Main Disclaimer
                VStack(alignment: .leading, spacing: 16) {
                    Text("Important Information")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)

                    Text("""
                    Gadfly is a productivity application designed to support individuals with attention differences. It is not intended to diagnose, treat, cure, or prevent ADHD or any medical condition.

                    This app is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.

                    If you have concerns about ADHD or any medical condition, please consult a qualified healthcare provider.
                    """)
                    .foregroundStyle(themeColors.subtext)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeSecondary)
                )

                // What Gadfly Does
                VStack(alignment: .leading, spacing: 16) {
                    Text("What Gadfly Does")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)

                    VStack(alignment: .leading, spacing: 12) {
                        DisclaimerBullet(icon: "checkmark.circle.fill", color: .green, text: "Helps you focus on one task at a time")
                        DisclaimerBullet(icon: "checkmark.circle.fill", color: .green, text: "Provides gentle reminders and encouragement")
                        DisclaimerBullet(icon: "checkmark.circle.fill", color: .green, text: "Tracks momentum without punishing missed days")
                        DisclaimerBullet(icon: "checkmark.circle.fill", color: .green, text: "Adapts to your energy levels")
                        DisclaimerBullet(icon: "checkmark.circle.fill", color: .green, text: "Offers self-care reminders")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeSecondary)
                )

                // What Gadfly Doesn't Do
                VStack(alignment: .leading, spacing: 16) {
                    Text("What Gadfly Does NOT Do")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)

                    VStack(alignment: .leading, spacing: 12) {
                        DisclaimerBullet(icon: "xmark.circle.fill", color: .red, text: "Diagnose ADHD or any condition")
                        DisclaimerBullet(icon: "xmark.circle.fill", color: .red, text: "Provide medical treatment")
                        DisclaimerBullet(icon: "xmark.circle.fill", color: .red, text: "Replace therapy or medication")
                        DisclaimerBullet(icon: "xmark.circle.fill", color: .red, text: "Offer medical advice")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeSecondary)
                )

                // Resources
                VStack(alignment: .leading, spacing: 16) {
                    Text("ADHD Resources")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)

                    Text("If you or someone you know needs help with ADHD:")
                        .foregroundStyle(themeColors.subtext)

                    Link(destination: URL(string: "https://chadd.org")!) {
                        ResourceLink(title: "CHADD", subtitle: "Children and Adults with ADHD")
                    }

                    Link(destination: URL(string: "https://www.additudemag.com")!) {
                        ResourceLink(title: "ADDitude Magazine", subtitle: "ADHD Information & Support")
                    }

                    Link(destination: URL(string: "https://add.org")!) {
                        ResourceLink(title: "ADDA", subtitle: "Attention Deficit Disorder Association")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeSecondary)
                )

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.themeBackground)
        .navigationTitle("Health Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DisclaimerBullet: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .foregroundStyle(Color.themeSubtext)
        }
    }
}

struct ResourceLink: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.themeAccent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.themeSubtext)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(Color.themeSubtext)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Self-Care Detail Views

struct SelfCareDetailView: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var isEnabled: Bool
    @Binding var intervalMinutes: Int
    let intervalOptions: [Int]

    var body: some View {
        Form {
            Section {
                Toggle("Enable \(title) Reminders", isOn: $isEnabled)
            }

            if isEnabled {
                Section {
                    Picker("Remind every", selection: $intervalMinutes) {
                        ForEach(intervalOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Frequency")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HyperfocusBreakSettingsView: View {
    @ObservedObject private var selfCareService = SelfCareService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Hyperfocus Check-ins", isOn: $selfCareService.hyperfocusSettings.isEnabled)
            }

            if selfCareService.hyperfocusSettings.isEnabled {
                Section {
                    Picker("Check-in every", selection: $selfCareService.hyperfocusSettings.intervalMinutes) {
                        Text("60 minutes").tag(60)
                        Text("90 minutes").tag(90)
                        Text("120 minutes").tag(120)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Frequency")
                } footer: {
                    Text("When hyperfocusing, it's easy to lose track of time. These gentle check-ins help you stay on the right task.")
                }

                Section {
                    Toggle("Protect Productive Flow", isOn: $selfCareService.hyperfocusSettings.protectProductiveFlow)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("When enabled, the check-in will ask if you want to continue before interrupting. Great for adults who are productively hyperfocusing.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle("Hyperfocus Breaks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MealSettingsView: View {
    @ObservedObject private var selfCareService = SelfCareService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Meal Reminders", isOn: $selfCareService.mealSettings.isEnabled)
            }

            if selfCareService.mealSettings.isEnabled {
                Section {
                    Stepper("Meals per day: \(selfCareService.mealSettings.mealCount)", value: $selfCareService.mealSettings.mealCount, in: 2...5)
                } header: {
                    Text("How Many Meals")
                }

                Section {
                    MealTimeRow(label: "Breakfast", time: $selfCareService.mealSettings.breakfastTime)

                    MealTimeRow(label: "Lunch", time: $selfCareService.mealSettings.lunchTime)

                    MealTimeRow(label: "Dinner", time: $selfCareService.mealSettings.dinnerTime)

                    if selfCareService.mealSettings.mealCount >= 4 {
                        MealTimeRow(
                            label: "Snack 1",
                            time: Binding(
                                get: { selfCareService.mealSettings.snackTime1 ?? "10:30" },
                                set: { selfCareService.mealSettings.snackTime1 = $0 }
                            )
                        )
                    }

                    if selfCareService.mealSettings.mealCount >= 5 {
                        MealTimeRow(
                            label: "Snack 2",
                            time: Binding(
                                get: { selfCareService.mealSettings.snackTime2 ?? "15:30" },
                                set: { selfCareService.mealSettings.snackTime2 = $0 }
                            )
                        )
                    }
                } header: {
                    Text("Meal Times")
                } footer: {
                    Text("Set when you typically eat. You'll get a reminder at these times.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle("Meal Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MealTimeRow: View {
    let label: String
    @Binding var time: String
    @State private var selectedDate = Date()

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        return formatter.date(from: time) ?? Date()
                    },
                    set: { newDate in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        time = formatter.string(from: newDate)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }
}

// MARK: - Personality Button

struct PersonalityButton: View {
    let personality: BotPersonality
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(personality.emoji)
                    .font(.title)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(personality.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(personality.selectionTagline)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.themeAccent : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.themeAccent)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
