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
    @State private var showPersonalitySaved = false
    @State private var savedPersonalityName = ""
    @State private var showVoiceSaved = false
    @State private var savedVoiceName = ""

    // Personality change confirmation
    @State private var showPersonalityConfirmation = false
    @State private var pendingPersonality: BotPersonality?

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
                Button("Register with VoiceDay Network") {
                    Task {
                        do {
                            try await VoiceDayAPIService.shared.register(
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
                    Label("Connected to VoiceDay Network", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Your Profile")
        } footer: {
            Text("Register to share tasks and nag family members who also use VoiceDay.")
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
                Text("How should I talk to you?")
            }
        } footer: {
            Text("Tap to select, then confirm to apply changes.")
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
            Text("Keep Screen On prevents auto-lock so VoiceDay stays active and can speak reminders. Focus Sessions also keep the screen on automatically.")
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
                        Text("\(VoiceDayAPIService.shared.connections.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    SharedTasksView()
                } label: {
                    HStack {
                        Text("Shared Tasks")
                        Spacer()
                        Text("\(VoiceDayAPIService.shared.sharedTasks.count)")
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
    @StateObject private var blockedVoices = BlockedVoicesManager.shared

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
                                    selectedVoiceId = voice.voice_id
                                    selectedVoiceName = voice.name
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    onSave?(voice.name)
                                    dismiss()
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
                                selectedVoiceId = voice.voice_id
                                selectedVoiceName = voice.name
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                onSave?(voice.name)
                                dismiss()
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
                    Text("Go to Settings → Your Profile. Enter your name and phone number, then tap 'Register with VoiceDay Network'.")
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
                    Text("• If they have VoiceDay: Push notifications\n• If they don't: SMS text messages\n• Nagging continues until done!")
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

// MARK: - Missing Views Consolidated

// MARK: - VoiceRecordingView

struct VoiceRecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var voiceService = VoiceCloningService.shared
    @State private var currentPhraseIndex = 0
    @State private var showingCloneConfirm = false
    @State private var voiceName = ""
    @State private var showingSuccess = false
    @State private var showingDeleteConfirm = false
    @State private var showingAddPhrase = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                Text("Clone Voice").tag(0)
                Text("My Phrases").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                if selectedTab == 0 {
                    voiceCloneTab
                } else {
                    customPhrasesTab
                }
            }
        }
        .navigationTitle("Your Voice")
        .alert("Create Voice Clone", isPresented: $showingCloneConfirm) {
            TextField("Your Name", text: $voiceName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createVoiceClone()
            }
        } message: {
            Text("This will create a custom voice that sounds like you! Enter your name:")
        }
        .alert("Voice Created!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Your voice clone is ready! All reminders will now use your voice.")
        }
        .alert("Delete Voice?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVoice()
            }
        } message: {
            Text("This will delete your custom voice clone. You can always record a new one.")
        }
    }

    private var voiceCloneTab: some View {
        VStack(spacing: 24) {
            headerSection
            if let voiceName = voiceService.customVoiceName {
                currentVoiceCard(name: voiceName)
            }
            recordingSection
            progressSection
            recordedSamplesSection
            if voiceService.recordings.count >= 3 {
                createVoiceButton
            }
        }
        .padding()
    }

    private var customPhrasesTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.themeAccent)
                Text("Your Custom Messages").font(.title3.bold())
                Text("Add your own phrases that will be spoken in your cloned voice.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()

            Button { showingAddPhrase = true } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Phrase")
                }
                .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding().background(Color.themeAccent).cornerRadius(12)
            }
            .padding(.horizontal)

            if voiceService.customPhrases.isEmpty {
                Text("No custom phrases yet").font(.subheadline).foregroundStyle(.secondary).padding()
            } else {
                ForEach(VoiceCloningService.CustomPhrase.PhraseCategory.allCases, id: \.self) { category in
                    let phrases = voiceService.customPhrases.filter { $0.category == category }
                    if !phrases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue).font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(phrases) { phrase in
                                CustomPhraseRow(phrase: phrase) {
                                    voiceService.togglePhrase(phrase.id)
                                } onDelete: {
                                    voiceService.deleteCustomPhrase(phrase.id)
                                }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 50)
        }
        .sheet(isPresented: $showingAddPhrase) { AddCustomPhraseView() }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 60)).foregroundStyle(Color.themeAccent)
            Text("Record Your Voice").font(.title2.bold())
            Text("Record yourself saying these phrases to create a voice clone.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }

    private func currentVoiceCard(name: String) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.themeAccent).font(.title2)
            VStack(alignment: .leading) {
                Text("Active Voice: \(name)").font(.headline)
                Text("Your voice is being used for all reminders").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showingDeleteConfirm = true } label: { Image(systemName: "trash").foregroundStyle(.red) }
        }
        .padding().background(Color.themeAccent.opacity(0.1)).cornerRadius(12)
    }

    private var recordingSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Phrase \(currentPhraseIndex + 1) of \(voiceService.suggestedPhrases.count)").font(.caption).foregroundStyle(.secondary)
                Text("\"\(voiceService.suggestedPhrases[currentPhraseIndex])\"").font(.headline).multilineTextAlignment(.center).padding().frame(maxWidth: .infinity).background(Color.themeSecondary).cornerRadius(12)
            }
            Button {
                if voiceService.isRecording { voiceService.stopRecording(phraseIndex: currentPhraseIndex) }
                else { try? voiceService.startRecording(phraseIndex: currentPhraseIndex) }
            } label: {
                ZStack {
                    Circle().fill(voiceService.isRecording ? Color.red : Color.themeAccent).frame(width: 80, height: 80)
                    if voiceService.isRecording {
                        Circle().trim(from: 0, to: voiceService.recordingProgress).stroke(Color.white, lineWidth: 4).frame(width: 90, height: 90).rotationEffect(.degrees(-90))
                    }
                    Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill").font(.system(size: 30)).foregroundStyle(.white)
                }
            }
            Text(voiceService.isRecording ? "Recording... Tap to stop" : "Tap to record").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { if currentPhraseIndex > 0 { currentPhraseIndex -= 1 } } label: { Image(systemName: "chevron.left"); Text("Previous") }
                .disabled(currentPhraseIndex == 0 || voiceService.isRecording)
                Spacer()
                Button { if currentPhraseIndex < voiceService.suggestedPhrases.count - 1 { currentPhraseIndex += 1 } } label: { Text("Next"); Image(systemName: "chevron.right") }
                .disabled(currentPhraseIndex >= voiceService.suggestedPhrases.count - 1 || voiceService.isRecording)
            }
            .padding(.horizontal)
        }
        .padding().background(Color.themeSecondary).cornerRadius(16)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recording Progress").font(.subheadline.bold())
                Spacer()
                Text("\(voiceService.recordings.count)/\(voiceService.suggestedPhrases.count)").font(.subheadline).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(voiceService.recordings.count), total: Double(voiceService.suggestedPhrases.count)).tint(Color.themeAccent)
        }
    }

    private var recordedSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded Samples").font(.subheadline.bold())
            if voiceService.recordings.isEmpty {
                Text("No recordings yet.").font(.caption).foregroundStyle(.secondary).padding()
            } else {
                ForEach(voiceService.recordings.sorted(by: { $0.phraseIndex < $1.phraseIndex })) { recording in
                    RecordingSampleRow(recording: recording) {
                        voiceService.playRecording(at: recording.phraseIndex)
                    } onDelete: {
                        voiceService.deleteRecording(at: recording.phraseIndex)
                    } onRerecord: {
                        currentPhraseIndex = recording.phraseIndex
                    }
                }
            }
        }
    }

    private var createVoiceButton: some View {
        VStack {
            Button {
                voiceName = appState.userName.isEmpty ? "Parent" : appState.userName
                showingCloneConfirm = true
            } label: {
                HStack {
                    if voiceService.isProcessing { ProgressView().tint(.white) }
                    else { Image(systemName: "waveform.badge.plus") }
                    Text(voiceService.isProcessing ? "Creating Voice Clone..." : "Create My Voice Clone")
                }
                .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding().background(Color.themeAccent).cornerRadius(12)
            }
            .disabled(voiceService.isProcessing || !appState.hasValidElevenLabsKey)
        }
    }

    private func createVoiceClone() {
        Task {
            do {
                _ = try await voiceService.createVoiceClone(name: voiceName, apiKey: appState.elevenLabsKey)
                showingSuccess = true
            } catch { voiceService.error = error.localizedDescription }
        }
    }

    private func deleteVoice() {
        Task { try? await voiceService.deleteVoiceClone(apiKey: appState.elevenLabsKey) }
    }
}

struct RecordingSampleRow: View {
    let recording: VoiceRecording
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onRerecord: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) { Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Color.themeAccent) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Phrase \(recording.phraseIndex + 1)").font(.subheadline.bold())
                Text(recording.phrase).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: onRerecord) { Image(systemName: "arrow.counterclockwise").foregroundStyle(.orange) }
            Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.red) }
        }
        .padding().background(Color.themeSecondary).cornerRadius(8)
    }
}

struct CustomPhraseRow: View {
    let phrase: VoiceCloningService.CustomPhrase
    let onToggle: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) { Image(systemName: phrase.isActive ? "checkmark.circle.fill" : "circle").foregroundStyle(phrase.isActive ? Color.themeAccent : .secondary) }
            Text(phrase.text).font(.subheadline).foregroundStyle(phrase.isActive ? .primary : .secondary).lineLimit(2)
            Spacer()
            Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.red).font(.caption) }
        }
        .padding().background(Color.themeSecondary).cornerRadius(8).padding(.horizontal)
    }
}

struct AddCustomPhraseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceService = VoiceCloningService.shared
    @State private var phraseText = ""
    @State private var selectedCategory: VoiceCloningService.CustomPhrase.PhraseCategory = .nag
    var body: some View {
        NavigationStack {
            Form {
                Section("Your Message") { TextField("What do you want to say?", text: $phraseText, axis: .vertical).lineLimit(3...6) }
                Section("Category") {
                    Picker("Type", selection: $selectedCategory) {
                        ForEach(VoiceCloningService.CustomPhrase.PhraseCategory.allCases, id: \.self) { category in Text(category.rawValue).tag(category) }
                    }.pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Phrase").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        voiceService.addCustomPhrase(phraseText, category: selectedCategory)
                        dismiss()
                    }.disabled(phraseText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - ManagerDashboardView

struct ManagerDashboardView: View {
    @StateObject private var rewardsService = RewardsService.shared
    @StateObject private var apiService = VoiceDayAPIService.shared
    @State private var selectedTab = 0
    @State private var showingAddReward = false
    @State private var showingTeamSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Team").tag(0)
                    Text("Rewards").tag(1)
                    Text("Pending").tag(2)
                }.pickerStyle(.segmented).padding()
                TabView(selection: $selectedTab) {
                    teamOverviewTab.tag(0)
                    rewardsConfigTab.tag(1)
                    pendingRedemptionsTab.tag(2)
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.themeBackground)
            .navigationTitle("Manager Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingTeamSetup = true } label: { Label("Team Settings", systemImage: "gearshape") }
                        Button { showingAddReward = true } label: { Label("Add Reward", systemImage: "plus.circle") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showingAddReward) { AddRewardView() }
            .sheet(isPresented: $showingTeamSetup) { TeamSetupView() }
        }
    }

    private var teamOverviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Team Members", value: "\(apiService.connections.count)", icon: "person.3.fill", color: .blue)
                    StatCard(title: "Active Tasks", value: "\(apiService.sharedTasks.filter { !$0.isCompleted }.count)", icon: "checklist", color: .orange)
                }.padding(.horizontal)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Leaderboard").font(.headline).padding(.horizontal)
                    if apiService.connections.isEmpty { Text("No members").padding() }
                    else {
                        ForEach(Array(apiService.connections.enumerated()), id: \.element.id) { index, connection in
                            LeaderboardRow(rank: index + 1, name: connection.nickname, points: 0, tasksCompleted: 0)
                        }
                    }
                }
            }.padding(.vertical)
        }
    }

    private var rewardsConfigTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let team = rewardsService.currentTeam { PointRulesCard(rules: team.pointRules).padding(.horizontal) }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Available Rewards").font(.headline); Spacer(); Button { showingAddReward = true } label: { Image(systemName: "plus.circle.fill").foregroundStyle(Color.themeAccent) } }
                    if let rewards = rewardsService.currentTeam?.rewards { ForEach(rewards) { reward in RewardConfigRow(reward: reward) } }
                }.padding(.horizontal)
            }.padding(.vertical)
        }
    }

    private var pendingRedemptionsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if rewardsService.pendingRedemptions.isEmpty { Text("No pending redemptions").padding(.top, 60) }
                else {
                    ForEach(rewardsService.pendingRedemptions.filter { $0.status == .pending }) { redemption in
                        PendingRedemptionCard(redemption: redemption) { rewardsService.approveRedemption(redemption) } onFulfill: { rewardsService.fulfillRedemption(redemption) } onDeny: { }
                    }
                }
            }.padding()
        }
    }
}

struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(color); Spacer() }
            HStack { Text(value).font(.system(size: 28, weight: .bold)); Spacer() }
            HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer() }
        }.padding().background(Color.themeSecondary).cornerRadius(12)
    }
}

struct LeaderboardRow: View {
    let rank: Int; let name: String; let points: Int; let tasksCompleted: Int
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(Color.themeAccent.opacity(0.2)).frame(width: 32, height: 32); Text("\(rank)").font(.caption.bold()) }
            VStack(alignment: .leading, spacing: 2) { Text(name).font(.subheadline.weight(.medium)); Text("\(tasksCompleted) tasks completed").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text("\(points)").font(.headline).foregroundStyle(Color.themeAccent)
        }.padding(.horizontal).padding(.vertical, 8)
    }
}

struct PointRulesCard: View {
    let rules: PointRules
    var body: some View {
        VStack(spacing: 12) {
            HStack { Label("High Priority", systemImage: "exclamationmark.circle.fill").foregroundStyle(.red); Spacer(); Text("+\(rules.pointsPerHighPriority) pts").font(.headline) }
            HStack { Label("Medium Priority", systemImage: "minus.circle.fill").foregroundStyle(.yellow); Spacer(); Text("+\(rules.pointsPerMediumPriority) pts").font(.headline) }
            HStack { Label("Low Priority", systemImage: "arrow.down.circle.fill").foregroundStyle(Color.themeAccent); Spacer(); Text("+\(rules.pointsPerLowPriority) pts").font(.headline) }
        }.padding().background(Color.themeSecondary).cornerRadius(12)
    }
}

struct RewardConfigRow: View {
    let reward: RewardConfig
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reward.type.icon).font(.title2).foregroundStyle(Color.themeAccent).frame(width: 40)
            VStack(alignment: .leading, spacing: 2) { Text(reward.name).font(.subheadline.weight(.medium)); Text(reward.description).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            Spacer()
            Text("\(reward.pointCost)").font(.headline)
        }.padding().background(Color.themeSecondary).cornerRadius(8)
    }
}

struct PendingRedemptionCard: View {
    let redemption: RewardRedemption; let onApprove: () -> Void; let onFulfill: () -> Void; let onDeny: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(redemption.rewardName).font(.headline); Spacer(); Text("-\(redemption.pointsSpent) pts").foregroundStyle(.orange) }
            HStack(spacing: 12) {
                Button("Deny", action: onDeny).buttonStyle(.bordered).tint(.red)
                Button("Approve & Fulfill", action: onFulfill).buttonStyle(.borderedProminent).tint(Color.themeAccent)
            }
        }.padding().background(Color.themeSecondary).cornerRadius(12)
    }
}

struct AddRewardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var type: RewardType = .custom; @State private var pointCost = 100
    var body: some View {
        NavigationStack {
            Form {
                Section("Reward Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) { ForEach(RewardType.allCases, id: \.self) { type in Label(type.displayName, systemImage: type.icon).tag(type) } }
                    Stepper("Points: \(pointCost)", value: $pointCost, in: 10...1000, step: 10)
                }
            }
            .scrollContentBackground(.hidden).background(Color.themeBackground)
            .navigationTitle("Add Reward").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { RewardsService.shared.addReward(RewardConfig(name: name, type: type, pointCost: pointCost)); dismiss() }.disabled(name.isEmpty) }
            }
        }
    }
}

struct TeamSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamName = ""; @State private var isFamily = true
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Team Name", text: $teamName); Picker("Type", selection: $isFamily) { Text("Family").tag(true); Text("Work Team").tag(false) }.pickerStyle(.segmented) }
            }
            .scrollContentBackground(.hidden).background(Color.themeBackground)
            .navigationTitle("Set Up Team").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { RewardsService.shared.createTeam(name: teamName); dismiss() }.disabled(teamName.isEmpty) }
            }
        }
    }
}

// MARK: - MyRewardsView

struct MyRewardsView: View {
    @StateObject private var rewardsService = RewardsService.shared
    @State private var showingRedemptionAlert = false
    @State private var selectedReward: RewardConfig?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                pointsCard
                if let team = rewardsService.currentTeam { rewardsSection(rewards: team.rewards) }
                else { rewardsSection(rewards: Team.defaultRewards()) }
                if !rewardsService.pendingRedemptions.isEmpty { redemptionsSection }
            }.padding()
        }
        .background(Color.themeBackground)
        .navigationTitle("My Rewards")
        .alert("Redeem Reward", isPresented: $showingRedemptionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Redeem") { if let reward = selectedReward { rewardsService.redeemReward(reward) } }
        } message: { if let reward = selectedReward { Text("Spend \(reward.pointCost) points to redeem \(reward.name)?") } }
    }

    private var pointsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text("Your Points").font(.subheadline).foregroundStyle(.secondary); Text("\(rewardsService.myPoints)").font(.system(size: 48, weight: .bold)).foregroundStyle(Color.themeAccent) }
                Spacer(); Image(systemName: "star.circle.fill").font(.system(size: 60)).foregroundStyle(Color.themeAccent.opacity(0.8))
            }
        }.padding().background(Color.themeSecondary).cornerRadius(16)
    }

    private func rewardsSection(rewards: [RewardConfig]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Rewards").font(.headline)
            ForEach(rewards.filter { $0.isActive }) { reward in
                RewardRow(reward: reward, canAfford: rewardsService.myPoints >= reward.pointCost) { selectedReward = reward; showingRedemptionAlert = true }
            }
        }
    }

    private var redemptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Redemptions").font(.headline)
            ForEach(rewardsService.pendingRedemptions) { redemption in RedemptionRow(redemption: redemption) }
        }
    }
}

struct RewardRow: View {
    let reward: RewardConfig; let canAfford: Bool; let onRedeem: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(Color.themeAccent.opacity(0.2)).frame(width: 44, height: 44); Image(systemName: reward.type.icon).foregroundStyle(Color.themeAccent) }
            VStack(alignment: .leading, spacing: 2) { Text(reward.name).font(.subheadline.weight(.medium)); Text(reward.description).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            Spacer()
            Button(action: onRedeem) {
                Text("\(reward.pointCost) pts").font(.headline).foregroundStyle(canAfford ? .black : .secondary).padding(.horizontal, 16).padding(.vertical, 8).background(canAfford ? Color.themeAccent : Color.gray.opacity(0.3)).cornerRadius(8)
            }.disabled(!canAfford)
        }.padding().background(Color.themeSecondary).cornerRadius(12)
    }
}

struct RedemptionRow: View {
    let redemption: RewardRedemption
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill").foregroundStyle(.orange).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) { Text(redemption.rewardName).font(.subheadline.weight(.medium)); Text(redemption.status.rawValue).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Text("-\(redemption.pointsSpent) pts").font(.caption).foregroundStyle(.secondary)
        }.padding().background(Color.themeSecondary).cornerRadius(8)
    }
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
