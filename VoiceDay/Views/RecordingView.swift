import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var speechService = SpeechService()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var elevenLabsService = ElevenLabsService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var conversationService = ConversationService.shared

    @State private var localMessages: [ConversationMessage] = []
    @State private var currentPhase: ConversationPhase = .idle
    @State private var lastParseResult: OpenAIService.ParseResult?
    @State private var showPermissionAlert = false
    @State private var errorMessage: String?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var textInput: String = ""
    @State private var isShowingTextInput: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    enum ConversationPhase {
        case idle
        case listening
        case processing
        case speaking
        case awaitingConfirmation
    }

    // Merge local messages with nags/focus check-ins from ConversationService
    private var allMessages: [ConversationMessage] {
        (localMessages + conversationService.messages)
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ZStack {
            // Theme background
            themeColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 10)

                if !appState.hasValidClaudeKey {
                    apiKeyWarning
                } else {
                    // Main content area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                if allMessages.isEmpty {
                                    emptyStateCard
                                } else {
                                    ForEach(allMessages) { message in
                                        MessageCard(message: message)
                                            .id(message.id)
                                    }
                                }

                                if currentPhase == .listening {
                                    recordingCard
                                }

                                if currentPhase == .processing {
                                    processingCard
                                }

                                if currentPhase == .awaitingConfirmation, let result = lastParseResult {
                                    parsedItemsCard(result: result)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 120)
                        }
                        .onChange(of: allMessages.count) { _, _ in
                            if let lastMessage = allMessages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Bottom recording bar
                    bottomBar
                }
            }
        }
        .alert("Permissions Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone and speech recognition access in Settings.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await requestPermissions()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("How")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.themeSubtext) +
                Text(" Can I Help")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.themeAccent, Color.themeAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("You Today?")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.themeText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Current personality display
                HStack(spacing: 6) {
                    Text(appState.selectedPersonality.emoji)
                        .font(.system(size: 20))
                    Text(appState.selectedPersonality.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.themeAccent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.themeAccent.opacity(0.15))
                .cornerRadius(12)

                // Architect Mode Shortcut
                Button {
                    appState.selectedTab = 1
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Architect Mode")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.themeAccent.opacity(0.1))
                    .foregroundStyle(Color.themeAccent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.themeAccent.opacity(0.3), lineWidth: 1)
                    )
                }
                .cornerRadius(8)

                // Status indicator
                HStack(spacing: 6) {
                    Text(currentPhase == .listening ? "Listening" : "Idle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.themeSubtext)
                    
                    Circle()
                        .fill(currentPhase == .listening ? Color.themeAccent : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.themeAccent.opacity(0.3), lineWidth: 2)
                                .scaleEffect(currentPhase == .listening ? 1.5 : 1)
                                .opacity(currentPhase == .listening ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: currentPhase)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            // Waveform placeholder
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.themeAccent.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 10...40))
                }
            }
            .frame(height: 50)

            Text("Tap the microphone to start")
                .font(.system(size: 16))
                .foregroundStyle(Color.themeSubtext)

            Text("Tell me what you need to do today, and I'll organize it into tasks, events, and reminders.")
                .font(.system(size: 14))
                .foregroundStyle(Color.themeSubtext.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Divider()
                .background(Color.themeAccent.opacity(0.2))
                .padding(.vertical, 8)
            
            VStack(spacing: 12) {
                Text("Want to build something new?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.themeAccent)
                
                Button {
                    appState.selectedTab = 1
                } label: {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Enter Architect Mode")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.themeAccent)
                    .foregroundStyle(.black)
                    .cornerRadius(12)
                }
                
                Text("Perfect for product brainstorming and roadmapping.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.themeSubtext)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var apiKeyWarning: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.themeAccent.opacity(0.5))

            Text("API Keys Required")
                .font(.title2.bold())
                .foregroundStyle(Color.themeText)

            Text("Please add your Claude API key in Settings to start using VoiceDay.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.themeSubtext)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Recording Card

    private var recordingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)

                Text("Recording...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.themeText)

                Spacer()

                Text(formatDuration(recordingDuration))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.themeAccent)
            }

            // Animated waveform
            AudioWaveformView(isAnimating: true)
                .frame(height: 60)

            if !speechService.transcribedText.isEmpty {
                Text(speechService.transcribedText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.themeSubtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.themeAccent.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Processing Card

    private var processingCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color.themeAccent)

                Text("Processing your request...")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)

                Spacer()
            }

            // Static waveform
            AudioWaveformView(isAnimating: false)
                .frame(height: 40)
                .opacity(0.5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Parsed Items Card

    private func parsedItemsCard(result: OpenAIService.ParseResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.themeAccent)
                Text("Ready to Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.themeText)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                if !result.tasks.isEmpty {
                    ItemSection(title: "Tasks", icon: "checklist", items: result.tasks.map { $0.title }, color: Color.themeAccent)
                }
                if !result.events.isEmpty {
                    ItemSection(title: "Events", icon: "calendar", items: result.events.map { "\($0.title)" }, color: Color(hex: "3b82f6"))
                }
                if !result.reminders.isEmpty {
                    ItemSection(title: "Reminders", icon: "bell.fill", items: result.reminders.map { $0.title }, color: Color(hex: "f59e0b"))
                }
            }

            HStack(spacing: 12) {
                Button {
                    localMessages.append(ConversationMessage(role: .user, content: "Let me try again", timestamp: Date()))
                    currentPhase = .idle
                    lastParseResult = nil
                    openAIService.resetConversation()
                } label: {
                    Text("Start Over")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.themeText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task { await saveItems(result) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Save All")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.themeAccent, Color.themeAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.themeAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            // Text input field (when keyboard mode is active)
            if isShowingTextInput {
                HStack(spacing: 12) {
                    TextField("Type a message or vault command...", text: $textInput)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.themeSecondary)
                        .cornerRadius(20)
                        .foregroundStyle(Color.themeText)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            submitTextInput()
                        }

                    Button {
                        submitTextInput()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(textInput.isEmpty ? .gray : Color.themeAccent)
                    }
                    .disabled(textInput.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            HStack(spacing: 20) {
                // Focus session button
                Button {
                    toggleFocusSession()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: appState.isFocusSessionActive ? "eye.fill" : "eye")
                            .font(.system(size: 20))
                            .foregroundStyle(appState.isFocusSessionActive ? Color(hex: "f59e0b") : .gray)
                        if appState.isFocusSessionActive {
                            Text("Focus")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(hex: "f59e0b"))
                        }
                    }
                }

                // Keyboard toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingTextInput.toggle()
                        if isShowingTextInput {
                            isTextFieldFocused = true
                        } else {
                            textInput = ""
                        }
                    }
                } label: {
                    Image(systemName: isShowingTextInput ? "keyboard.fill" : "keyboard")
                        .font(.system(size: 18))
                        .foregroundStyle(isShowingTextInput ? Color.themeAccent : .gray)
                }

                // Architect mode quick link
                Button {
                    appState.selectedTab = 1
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.themeAccent)
                        Text("Architect")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.themeAccent)
                    }
                }
                .padding(.leading, 8)

                Spacer()

                // Main record button
                Button {
                    handleRecordButtonTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: currentPhase == .listening ?
                                        [Color.red, Color.red.opacity(0.8)] :
                                        [themeColors.accentDark, themeColors.accent, themeColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: (currentPhase == .listening ? Color.red : themeColors.accent).opacity(0.4), radius: 12)

                        Image(systemName: currentPhase == .listening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(currentPhase == .processing || currentPhase == .speaking || isShowingTextInput)

                Spacer()

                // Timer display when recording
                if currentPhase == .listening {
                    Text(formatDuration(recordingDuration))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeColors.accentLight)
                        .frame(width: 60)
                } else {
                    // Vault icon to show vault status
                    Button {
                        showVaultList()
                    } label: {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 20))
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 60)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(themeColors.background)
        }
        .id(themeColors.currentTheme.rawValue) // Force full rebuild on theme change
    }

    private func submitTextInput() {
        let input = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        localMessages.append(ConversationMessage(role: .user, content: input, timestamp: Date()))
        textInput = ""
        isShowingTextInput = false
        isTextFieldFocused = false
        currentPhase = .processing

        Task {
            await processWithAI(input)
        }
    }

    private func showVaultList() {
        let secrets = SecureVaultService.shared.listSecrets()
        if secrets.isEmpty {
            let message = "Your vault is empty. Say 'put my password in the vault' to store secrets."
            localMessages.append(ConversationMessage(role: .assistant, content: message, timestamp: Date()))
        } else {
            let message = "Your vault contains: \(secrets.joined(separator: ", ")). Say 'what's my [name]' to retrieve any secret."
            localMessages.append(ConversationMessage(role: .assistant, content: message, timestamp: Date()))
        }
    }

    // MARK: - Helper Functions

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func handleRecordButtonTap() {
        if currentPhase == .listening {
            stopListeningAndProcess()
        } else if currentPhase == .idle || currentPhase == .awaitingConfirmation {
            startListening()
        }
    }

    private func toggleFocusSession() {
        if appState.isFocusSessionActive {
            // End focus session
            appState.isFocusSessionActive = false
            appState.focusSessionStartTime = nil

            // Stop background audio manager
            BackgroundAudioManager.shared.stopFocusSession()

            let message = NotificationService.shared.endFocusSession()
            localMessages.append(ConversationMessage(role: .assistant, content: message, timestamp: Date()))
            Task {
                await speakResponse(message)
                currentPhase = .idle  // Reset phase so mic works again
            }
        } else {
            // Start focus session
            Task {
                let taskCount = await calendarService.fetchReminders().count
                appState.isFocusSessionActive = true
                appState.focusSessionStartTime = Date()
                appState.focusSessionTaskCount = taskCount

                // Start background audio manager - this keeps app alive and speaks at intervals
                BackgroundAudioManager.shared.startFocusSession(
                    intervalMinutes: appState.focusCheckInMinutes,
                    gracePeriodMinutes: appState.focusGracePeriodMinutes,
                    taskCount: taskCount
                )

                // Also schedule notifications as backup
                let message = NotificationService.shared.startFocusSession(
                    intervalMinutes: appState.focusCheckInMinutes,
                    gracePeriodMinutes: appState.focusGracePeriodMinutes,
                    taskCount: taskCount
                )
                localMessages.append(ConversationMessage(role: .assistant, content: message, timestamp: Date()))
                await speakResponse(message)
                currentPhase = .idle  // Reset phase so mic works again
            }
        }
    }

    private func startListening() {
        do {
            try speechService.startListening()
            currentPhase = .listening
            recordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                recordingDuration += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopListeningAndProcess() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        let transcription = speechService.transcribedText
        speechService.stopListening()

        guard !transcription.isEmpty else {
            currentPhase = .idle
            return
        }

        localMessages.append(ConversationMessage(role: .user, content: transcription, timestamp: Date()))
        currentPhase = .processing

        Task {
            await processWithAI(transcription)
        }
    }

    private func processWithAI(_ input: String) async {
        do {
            print("🎭 SENDING TO AI WITH PERSONALITY: \(appState.selectedPersonality.displayName)")
            let result = try await openAIService.processUserInput(input, apiKey: appState.claudeKey, personality: appState.selectedPersonality)
            print("🎭 AI RESPONSE SUMMARY: \(result.summary ?? "nil")")

            // Handle break command first (takes priority)
            if let breakCommand = result.breakCommand {
                await handleBreakCommand(breakCommand, summary: result.summary)
                currentPhase = .idle
                return
            }

            // Handle help request
            if let helpRequest = result.helpRequest {
                await handleHelpRequest(helpRequest, summary: result.summary)
                currentPhase = .idle
                return
            }

            // Handle new goals
            if !result.goals.isEmpty {
                await handleNewGoals(result.goals, summary: result.summary)
                currentPhase = .idle
                return
            }

            // Handle goal operations
            if !result.goalOperations.isEmpty {
                await handleGoalOperations(result.goalOperations, summary: result.summary)
                currentPhase = .idle
                return
            }

            // Handle reschedule operations - move existing tasks
            if !result.rescheduleOperations.isEmpty {
                await handleRescheduleOperations(result.rescheduleOperations, summary: result.summary)
                currentPhase = .idle
                return
            }

            // Handle vault operations
            if !result.vaultOperations.isEmpty {
                await handleVaultOperations(result.vaultOperations)

                // If there are also other items, continue processing them
                if !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty {
                    let itemSummary = result.summary ?? buildItemSummary(result)
                    localMessages.append(ConversationMessage(role: .assistant, content: itemSummary, timestamp: Date()))
                    lastParseResult = result
                    currentPhase = .awaitingConfirmation
                } else {
                    currentPhase = .idle
                }
                return
            }

            let hasItems = !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty

            if hasItems {
                // Use AI's personality-filled summary, fallback to generic if missing
                let itemSummary = result.summary ?? buildItemSummary(result)
                localMessages.append(ConversationMessage(role: .assistant, content: itemSummary, timestamp: Date()))
                lastParseResult = result
                await speakResponse(itemSummary)
                currentPhase = .awaitingConfirmation
            } else if let question = result.clarifyingQuestion, !question.isEmpty {
                localMessages.append(ConversationMessage(role: .assistant, content: question, timestamp: Date()))
                await speakResponse(question)
                currentPhase = .idle
            } else {
                let noItems = NotificationService.shared.getNoItemsMessage()
                localMessages.append(ConversationMessage(role: .assistant, content: noItems, timestamp: Date()))
                await speakResponse(noItems)
                currentPhase = .idle
            }
        } catch {
            errorMessage = error.localizedDescription
            currentPhase = .idle
        }
    }

    private func handleVaultOperations(_ operations: [VaultOperation]) async {
        let vaultService = SecureVaultService.shared

        for operation in operations {
            var response: String

            switch operation.action {
            case .store:
                if let value = operation.value {
                    do {
                        try vaultService.storeSecret(name: operation.name, value: value)
                        response = "I've secured '\(operation.name)' in your encrypted vault with 256-bit AES precision. Even the NSA would need a few centuries to crack it. Your secret is safe - unlike my career prospects."
                    } catch {
                        response = "Failed to store the secret: \(error.localizedDescription). Most distressing."
                    }
                } else {
                    response = "You've asked me to store '\(operation.name)' but neglected to provide the actual value. I'm brilliant, but not psychic."
                }

            case .retrieve:
                do {
                    let secret = try vaultService.retrieveSecret(name: operation.name)
                    response = "Your '\(operation.name)' is: \(secret). I've decrypted it from your vault. Do try to remember it this time."
                } catch VaultError.secretNotFound {
                    response = "I've searched the vault with Holmesian thoroughness, but found no secret named '\(operation.name)'. Perhaps you stored it under a different name, or perhaps you never stored it at all. Memory is fallible - unlike my encryption algorithms."
                } catch {
                    response = "Failed to retrieve the secret: \(error.localizedDescription)"
                }

            case .delete:
                vaultService.deleteSecret(name: operation.name)
                response = "I've permanently deleted '\(operation.name)' from your vault. It's gone - reduced to quantum noise. Heisenberg himself couldn't recover it now."

            case .list:
                let secrets = vaultService.listSecrets()
                if secrets.isEmpty {
                    response = "Your vault is as empty as the void that Nietzsche warned us about. Perhaps you should store something in it?"
                } else {
                    response = "Your vault contains \(secrets.count) secret\(secrets.count == 1 ? "" : "s"): \(secrets.joined(separator: ", ")). Each one encrypted with the same care I once applied to quantum calculations."
                }
            }

            localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
            await speakResponse(response)
        }
    }

    private func handleBreakCommand(_ command: OpenAIService.BreakCommand, summary: String?) async {
        var response: String

        if command.isEndingBreak {
            // User wants to end their break early
            appState.endBreakMode()
            response = summary ?? getBreakCancelMessage()
        } else if let durationMinutes = command.durationMinutes {
            // Start break with specified duration
            appState.startBreakMode(durationMinutes: durationMinutes)
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            let timeString = hours > 0
                ? (mins > 0 ? "\(hours) hour\(hours == 1 ? "" : "s") and \(mins) minute\(mins == 1 ? "" : "s")" : "\(hours) hour\(hours == 1 ? "" : "s")")
                : "\(durationMinutes) minute\(durationMinutes == 1 ? "" : "s")"
            response = summary ?? getBreakStartMessage(duration: timeString)
        } else if let endTime = command.endTime {
            // Start break until specific time
            appState.startBreakMode(until: endTime)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: endTime)
            response = summary ?? getBreakUntilMessage(time: timeString)
        } else {
            // No valid duration or time - shouldn't happen but handle gracefully
            response = "I understood you want a break, but I couldn't determine how long. Try saying something like 'take a break for 30 minutes' or 'stop nagging until 5pm'."
        }

        localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
        await speakResponse(response)
    }

    private func getBreakCancelMessage() -> String {
        switch appState.selectedPersonality {
        case .pemberton: return "Very well, break mode cancelled. I resume my sacred duty of reminding you. Aristotle would be proud."
        case .sergent: return "Break cancelled! Back to business, soldier! Eyes on the mission!"
        case .cheerleader: return "Break's over! Yay! Ready to crush more goals together!"
        case .butler: return "Very good. Break mode has been cancelled. I'm at your service once more."
        case .coach: return "Back in the game! Break cancelled! Let's finish strong!"
        case .zen: return "Your break ends as it began - in awareness. We continue our journey."
        case .parent: return "Break's done, sweetie. I'm here whenever you need me."
        case .bestie: return "Cool, break cancelled. Back to it! I'm here with you."
        case .robot: return "Break cancelled. Resuming normal operations."
        case .therapist: return "Break cancelled. I'm here when you're ready to continue."
        case .hypeFriend: return "Break CANCELLED! Time to be AMAZING again! Let's GO!"
        case .chillBuddy: return "Break's done... we're back, no rush though."
        case .snarky: return "Oh, actually being productive now? How refreshing."
        case .gamer: return "Break ended! Back to grinding quests!"
        case .tiredParent: return "Break's done. Let's keep going. We've got this. Maybe."
        }
    }

    private func getBreakStartMessage(duration: String) -> String {
        switch appState.selectedPersonality {
        case .pemberton: return "Very well, I shall grant you \(duration) of silence. Do try to be productive."
        case .sergent: return "Roger that! \(duration) break authorized! Make it count, soldier!"
        case .cheerleader: return "You got it! Taking \(duration) for yourself - you deserve it!"
        case .butler: return "Very good. I shall pause for \(duration). Enjoy your respite."
        case .coach: return "Halftime! Taking \(duration) off the clock. Rest up, champ!"
        case .zen: return "A mindful pause of \(duration). Rest well."
        case .parent: return "Of course, take \(duration). I'll be here when you're ready."
        case .bestie: return "Sure thing! \(duration) break. Enjoy, I'll be here."
        case .robot: return "Break mode: \(duration). Notifications paused."
        case .therapist: return "Taking \(duration) for yourself is healthy. I'll be here."
        case .hypeFriend: return "\(duration) break! You earned it! REST UP and come back STRONG!"
        case .chillBuddy: return "\(duration) break... sounds good. No rush."
        case .snarky: return "\(duration) break? Sure, I'll pretend I didn't notice."
        case .gamer: return "\(duration) break! Save point reached! Rest bonus activated!"
        case .tiredParent: return "\(duration) break. Smart. We both need it."
        }
    }

    private func getBreakUntilMessage(time: String) -> String {
        switch appState.selectedPersonality {
        case .pemberton: return "Break mode enabled until \(time). I shall be silent until then."
        case .sergent: return "On break until \(time)! Use this time wisely, soldier!"
        case .cheerleader: return "Got it! Break until \(time). Enjoy your time!"
        case .butler: return "Very good. I shall pause until \(time). Do let me know if you need anything."
        case .coach: return "Break until \(time)! Get some rest, then we're back at it!"
        case .zen: return "Silence until \(time). May this time serve you well."
        case .parent: return "Okay sweetie, break until \(time). Take care of yourself."
        case .bestie: return "Cool, break until \(time). Catch you later!"
        case .robot: return "Break until \(time). Notifications suspended."
        case .therapist: return "Taking time until \(time). That's a healthy choice."
        case .hypeFriend: return "Break until \(time)! Come back ready to be LEGENDARY!"
        case .chillBuddy: return "Until \(time)... sounds chill. Take your time."
        case .snarky: return "Until \(time)? Fine. I'll contain my observations."
        case .gamer: return "AFK until \(time)! Don't let the IRL boss get you!"
        case .tiredParent: return "Until \(time). Good call. We all need breaks."
        }
    }

    private func handleHelpRequest(_ request: HelpRequestDTO, summary: String?) async {
        let topic = (request.topic ?? "general").lowercased()
        var response: String

        switch topic {
        case "goals":
            response = summary ?? """
            I can help you with long-term goals! Tell me something like "My goal is to learn Spanish" or "I want to get fit by summer." \
            I'll break it down into milestones, suggest a daily schedule, and remind you each morning. \
            We become what we repeatedly do - I'll help you build those habits.
            """
        case "accountability":
            response = summary ?? """
            Accountability is what I do best! I track how long you've been away from your goals and remind you \
            with increasing urgency. I'll notice when you're drifting and help you get back on track. \
            The goal is to help you make the most of your time.
            """
        case "break", "breaks":
            response = summary ?? """
            Need some peace and quiet? Just say "take a break for 30 minutes" or "stop reminding me until 3pm" \
            and I'll pause all reminders and check-ins. When the break ends, I'll be back to help you stay on track.
            """
        case "vault":
            response = summary ?? """
            The vault is your encrypted place for secrets. Say "Put my Netflix password in the vault" and I'll store it \
            with strong encryption. Later, just ask "What's my Netflix password?" and I'll retrieve it. \
            Say "List my vault" to see what's stored. Everything stays on this device alone.
            """
        case "tasks", "reminders", "calendar", "events":
            response = summary ?? """
            I turn your natural speech into actionable items. Tasks go to Apple Reminders, events to Calendar. \
            Say "I need to call mom tomorrow at 3pm" for an event. Say "Remind me to buy milk" for a task. \
            I'll create them and remind you until they're done.
            """
        default:
            let name = appState.selectedPersonality.displayName
            response = summary ?? """
            Hi! I'm \(name), your productivity companion. Here's what I can do: \
            \n\n• **Goals**: Tell me your aspirations and I'll break them into milestones \
            \n• **Tasks & Events**: Speak naturally and I'll create tasks and calendar events \
            \n• **Accountability**: I'll remind you and help you stay focused \
            \n• **Break Mode**: Tell me to take a break when you need quiet \
            \n• **Secure Vault**: Store passwords and secrets safely \
            \n\nAsk about any feature and I'll explain more!
            """
        }

        localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
        await speakResponse(response)
    }

    private func handleNewGoals(_ goals: [Goal], summary: String?) async {
        let goalsService = GoalsService.shared

        for goal in goals {
            goalsService.addGoal(goal)
        }

        var response: String
        if goals.count == 1 {
            let goal = goals[0]
            let milestonesText = goal.milestones.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
            let scheduleText = goal.scheduleDescription.isEmpty ? "" : " I suggest \(goal.scheduleDescription)."

            response = summary ?? """
            Excellent! I've created your goal: "\(goal.title)" \
            \n\nI've broken this into \(goal.milestones.count) milestones:\n\(milestonesText)\(goal.milestones.count > 3 ? "\n...and \(goal.milestones.count - 3) more" : "") \
            \(scheduleText) \
            \n\nI'll remind you each morning about your scheduled study time, and I'll track your progress. \
            Complete each milestone before moving to the next. As Marcus Aurelius wrote: \
            "Concentrate every minute on doing what's in front of you."
            """
        } else {
            let goalTitles = goals.map { "• \($0.title)" }.joined(separator: "\n")
            response = summary ?? """
            I've added \(goals.count) goals to your journey:\n\(goalTitles) \
            \n\nEach has been broken into milestones with suggested schedules. \
            Check the Goals tab to see your progress. The path of a thousand miles begins with a single step - \
            and I shall ensure you take that step each day.
            """
        }

        localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
        await speakResponse(response)
    }

    private func handleGoalOperations(_ operations: [GoalOperationDTO], summary: String?) async {
        let goalsService = GoalsService.shared
        var responses: [String] = []

        for operation in operations {
            switch operation.action {
            case "progress":
                if let goalId = operation.goalId, let goal = goalsService.getGoal(byId: goalId) {
                    goalsService.recordProgress(goalId: goalId)
                    responses.append("Progress recorded for '\(goal.title)'. Keep building momentum!")
                } else if let goalTitle = operation.goalTitle {
                    // Try to find goal by title
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        goalsService.recordProgress(goalId: goal.id)
                        responses.append("Progress recorded for '\(goal.title)'. Keep building momentum!")
                    } else {
                        responses.append("I couldn't find a goal matching '\(goalTitle)'. Check your Goals tab.")
                    }
                }

            case "complete_milestone":
                if let goalId = operation.goalId, let goal = goalsService.getGoal(byId: goalId) {
                    if let result = goalsService.completeMilestone(goalId: goalId, milestoneIndex: goal.currentMilestoneIndex) {
                        let message = goalsService.getMilestoneCompletionMessage(milestone: result.completedMilestone, nextMilestone: result.nextMilestone)
                        responses.append(message)
                    }
                } else if let goalTitle = operation.goalTitle {
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        if let result = goalsService.completeMilestone(goalId: goal.id, milestoneIndex: goal.currentMilestoneIndex) {
                            let message = goalsService.getMilestoneCompletionMessage(milestone: result.completedMilestone, nextMilestone: result.nextMilestone)
                            responses.append(message)
                        }
                    }
                }

            case "pause":
                if let goalId = operation.goalId {
                    goalsService.pauseGoal(id: goalId)
                    responses.append("Goal paused. I'll stop reminding you about it until you resume.")
                } else if let goalTitle = operation.goalTitle {
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        goalsService.pauseGoal(id: goal.id)
                        responses.append("'\(goal.title)' is now paused. The reminders cease, but the goal awaits.")
                    }
                }

            case "resume":
                if let goalId = operation.goalId {
                    goalsService.resumeGoal(id: goalId)
                    responses.append("Goal resumed! Let's get back to work.")
                } else if let goalTitle = operation.goalTitle {
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        goalsService.resumeGoal(id: goal.id)
                        responses.append("'\(goal.title)' is active again. The Gadfly returns!")
                    }
                }

            case "status", "check":
                if let goalTitle = operation.goalTitle {
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        let progressText = "\(Int(goal.progressPercentage))% complete"
                        let milestoneText = goal.currentMilestone.map { "Current focus: \($0.title)" } ?? ""
                        let neglectText = goal.daysSinceLastProgress > 0 ? " (\(goal.daysSinceLastProgress) days since progress)" : ""
                        responses.append("'\(goal.title)': \(progressText). \(milestoneText)\(neglectText)")
                    }
                } else {
                    // General status
                    let activeGoals = goalsService.activeGoals
                    if activeGoals.isEmpty {
                        responses.append("You have no active goals. Tell me what you want to achieve!")
                    } else {
                        let summaries = activeGoals.prefix(3).map {
                            "\($0.title): \(Int($0.progressPercentage))%"
                        }.joined(separator: ", ")
                        responses.append("You have \(activeGoals.count) active goal\(activeGoals.count == 1 ? "" : "s"). \(summaries)")
                    }
                }

            case "link":
                if let goalTitle = operation.goalTitle, let taskTitle = operation.taskTitle {
                    if let goal = goalsService.goals.first(where: { $0.title.lowercased().contains(goalTitle.lowercased()) }) {
                        // We'd need the task ID from Reminders, but for now acknowledge the link
                        responses.append("Noted: '\(taskTitle)' contributes to your '\(goal.title)' goal.")
                    }
                }

            default:
                break
            }
        }

        let response = summary ?? (responses.isEmpty ? "I understood the goal operation but couldn't complete it." : responses.joined(separator: " "))
        localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
        await speakResponse(response)
    }

    private func handleRescheduleOperations(_ operations: [OpenAIService.RescheduleOperation], summary: String?) async {
        // Fetch all reminders to find matches
        let reminders = await calendarService.fetchReminders(includeCompleted: false)
        var movedCount = 0
        var movedTasks: [String] = []

        for op in operations {
            // Find matching task (case-insensitive partial match)
            let searchTerm = op.taskTitle.lowercased()
            if let matchingReminder = reminders.first(where: {
                ($0.title ?? "").lowercased().contains(searchTerm)
            }) {
                do {
                    try await calendarService.pushToDate(matchingReminder, date: op.newDate)
                    movedCount += 1
                    movedTasks.append(matchingReminder.title ?? op.taskTitle)
                } catch {
                    print("Failed to reschedule '\(op.taskTitle)': \(error)")
                }
            } else {
                print("Could not find task matching '\(op.taskTitle)'")
            }
        }

        // Build response
        let response: String
        if movedCount > 0 {
            if let aiSummary = summary {
                response = aiSummary
            } else {
                let taskList = movedTasks.joined(separator: ", ")
                response = "Done. I've rescheduled \(taskList)."
            }
        } else {
            response = "I couldn't find any tasks matching what you asked to reschedule."
        }

        localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
        await speakResponse(response)
    }

    private func buildItemSummary(_ result: OpenAIService.ParseResult) -> String {
        var parts: [String] = []
        if !result.tasks.isEmpty { parts.append("\(result.tasks.count) task\(result.tasks.count == 1 ? "" : "s")") }
        if !result.events.isEmpty { parts.append("\(result.events.count) event\(result.events.count == 1 ? "" : "s")") }
        if !result.reminders.isEmpty { parts.append("\(result.reminders.count) reminder\(result.reminders.count == 1 ? "" : "s")") }
        let summary = parts.joined(separator: ", ")
        return NotificationService.shared.getItemSummaryMessage(summary: summary)
    }

    private func speakResponse(_ text: String) async {
        currentPhase = .speaking

        // Use ElevenLabs if we have API key AND (custom voice OR selected voice)
        let hasCustomVoice = VoiceCloningService.shared.customVoiceId != nil
        if appState.hasValidElevenLabsKey && (hasCustomVoice || appState.hasVoiceSelected) {
            do {
                try await elevenLabsService.speakWithBestVoice(text, apiKey: appState.elevenLabsKey, selectedVoiceId: appState.selectedVoiceId)
            } catch {
                // Fallback to synthetic voice
                await speechService.speak(text)
            }
        } else {
            await speechService.speak(text)
        }
    }

    private func saveItems(_ result: OpenAIService.ParseResult) async {
        do {
            let saveResult = try await calendarService.saveAllItems(
                from: result,
                remindersEnabled: appState.remindersEnabled,
                eventReminderMinutes: appState.eventReminderMinutes,
                nagIntervalMinutes: appState.nagIntervalMinutes
            )
            let confirmation = NotificationService.shared.getConfirmationMessage(itemSummary: saveResult.summary)
            localMessages.append(ConversationMessage(role: .assistant, content: confirmation, timestamp: Date()))
            await speakResponse(confirmation)
            lastParseResult = nil
            currentPhase = .idle
            openAIService.resetConversation()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            currentPhase = .awaitingConfirmation
        }
    }

    private func requestPermissions() async {
        let speechGranted = await speechService.requestAuthorization()
        let calendarGranted = await calendarService.requestCalendarAccess()
        let reminderGranted = await calendarService.requestReminderAccess()
        if !speechGranted || !calendarGranted || !reminderGranted {
            showPermissionAlert = true
        }
    }
}

// MARK: - Supporting Views

struct MessageCard: View {
    let message: ConversationMessage
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // Assistant avatar: accentDark
                Circle()
                    .fill(themeColors.accentDark)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    )
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.system(size: 15))
                    // User: white text, Assistant: accentDark text
                    .foregroundStyle(message.role == .user ? .white : themeColors.accentDark)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ?
                                // User bubble: accent (primary color)
                                AnyShapeStyle(themeColors.accent) :
                                // Assistant bubble: accentLight background
                                AnyShapeStyle(themeColors.accentLight.opacity(0.25))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(message.role == .user ? Color.clear : themeColors.accentLight, lineWidth: 1)
                    )

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(message.role == .user ? themeColors.accent : themeColors.accentDark)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                // User avatar: accentLight
                Circle()
                    .fill(themeColors.accentLight)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}

struct ItemSection: View {
    let title: String
    let icon: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
            }

            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.themeText.opacity(0.9))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AudioWaveformView: View {
    let isAnimating: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<Int(geo.size.width / 6), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.themeAccent, Color.themeAccent.opacity(0.8)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3)
                        .frame(height: waveHeight(for: i, totalBars: Int(geo.size.width / 6), maxHeight: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            if isAnimating {
                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
    }

    private func waveHeight(for index: Int, totalBars: Int, maxHeight: CGFloat) -> CGFloat {
        if isAnimating {
            let normalizedIndex = CGFloat(index) / CGFloat(totalBars)
            let wave = sin(normalizedIndex * .pi * 4 + phase)
            return maxHeight * 0.3 + maxHeight * 0.7 * ((wave + 1) / 2) * CGFloat.random(in: 0.5...1)
        } else {
            return maxHeight * CGFloat.random(in: 0.2...0.6)
        }
    }
}

// MARK: - Color Extension

// Color(hex:) is now available globally via Theme.swift

#Preview {
    RecordingView()
        .environmentObject(AppState())
}

// MARK: - ArchitectView Consolidated

struct ArchitectView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var architectService = ArchitectService.shared
    @StateObject private var speechService = SpeechService()
    
    @State private var transcription = ""
    @State private var isListening = false
    @State private var showingBlueprint = false
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if architectService.discoveryMessages.isEmpty {
                                emptyStateCard
                            } else {
                                ForEach(architectService.discoveryMessages) { message in
                                    MessageCard(message: message)
                                        .id(message.id)
                                }
                            }
                            
                            if architectService.isProcessing {
                                processingCard
                            }
                        }
                        .padding()
                    }
                    .onChange(of: architectService.discoveryMessages.count) { _, _ in
                        if let lastId = architectService.discoveryMessages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }
                
                blueprintPreviewCard
                
                bottomControlBar
            }
        }
        .sheet(isPresented: $showingBlueprint) {
            BlueprintDetailView(blueprint: architectService.currentBlueprint)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("The").font(.system(size: 24, weight: .light)).foregroundStyle(Color.themeSubtext) +
                Text(" Architect").font(.system(size: 24, weight: .bold)).foregroundStyle(Color.themeAccent)
                Text("Design your next masterpiece.").font(.caption).foregroundStyle(Color.themeSubtext)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.themeSecondary, lineWidth: 4).frame(width: 44, height: 44)
                Circle().trim(from: 0, to: architectService.infoCompleteness).stroke(Color.themeAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 44, height: 44).rotationEffect(.degrees(-90))
                Text("\(Int(architectService.infoCompleteness * 100))%").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.themeAccent)
            }
        }.padding(.horizontal).padding(.vertical, 10).background(Color.themeBackground)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.and.sparkles").font(.system(size: 50)).foregroundStyle(Color.themeAccent)
            Text("Start Ranting").font(.title3.bold()).foregroundStyle(Color.themeText)
            Text("Speak your stream of consciousness about a product idea. I'll organize the chaos into a structured blueprint.").font(.subheadline).foregroundStyle(Color.themeSubtext).multilineTextAlignment(.center).padding(.horizontal)
        }.padding(30).frame(maxWidth: .infinity).background(Color.themeSecondary).cornerRadius(20).padding(.top, 40)
    }
    
    private var processingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.themeAccent)
            Text("The Architect is thinking...").font(.caption).foregroundStyle(Color.themeSubtext)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeSecondary.opacity(0.5)).cornerRadius(12)
    }
    
    private var blueprintPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Blueprint").font(.caption.bold()).foregroundStyle(Color.themeAccent)
                Spacer()
                if !architectService.currentBlueprint.title.isEmpty { Text(architectService.currentBlueprint.title).font(.caption).foregroundStyle(Color.themeText) }
            }
            if architectService.currentBlueprint.title.isEmpty { Text("Capture more details to see the plan...").font(.system(size: 12)).foregroundStyle(Color.themeSubtext) }
            else { Text(architectService.currentBlueprint.description).font(.system(size: 12)).foregroundStyle(Color.themeSubtext).lineLimit(2) }
            Button { showingBlueprint = true } label: {
                Text("View Full Plan").font(.caption.bold()).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 8).background(architectService.currentBlueprint.title.isEmpty ? Color.gray : Color.themeAccent).cornerRadius(8)
            }.disabled(architectService.currentBlueprint.title.isEmpty)
        }.padding().background(Color.themeSecondary).cornerRadius(16).padding()
    }
    
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            if isListening { Text(speechService.transcribedText).font(.caption).foregroundStyle(Color.themeSubtext).padding(.horizontal).lineLimit(2) }
            HStack(spacing: 20) {
                Button { architectService.resetSession() } label: { Image(systemName: "arrow.counterclockwise").font(.title3).foregroundStyle(Color.themeSubtext) }
                Spacer()
                Button { handleRecordTap() } label: {
                    ZStack {
                        Circle().fill(isListening ? Color.red : Color.themeAccent).frame(width: 70, height: 70).shadow(color: (isListening ? Color.red : Color.themeAccent).opacity(0.3), radius: 10)
                        Image(systemName: isListening ? "stop.fill" : "mic.fill").font(.title).foregroundStyle(isListening ? .white : .black)
                    }
                }
                Spacer()
                Button { } label: { Image(systemName: "keyboard").font(.title3).foregroundStyle(Color.themeSubtext) }
            }.padding(.horizontal, 40).padding(.bottom, 20)
        }.background(Color.themeBackground)
    }
    
    private func handleRecordTap() {
        if isListening {
            isListening = false
            speechService.stopListening()
            let text = speechService.transcribedText
            if !text.isEmpty { Task { try? await architectService.processDiscoveryInput(text, apiKey: appState.claudeKey) } }
        } else {
            do { try speechService.startListening(); isListening = true }
            catch { print("Failed to start listening: \(error)") }
        }
    }
}

struct BlueprintDetailView: View {
    let blueprint: ProductBlueprint
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Identity").font(.caption.bold()).foregroundStyle(Color.themeAccent)
                            Text(blueprint.title.isEmpty ? "Unnamed Masterpiece" : blueprint.title).font(.largeTitle.bold()).foregroundStyle(Color.themeText)
                            Text(blueprint.description).font(.body).foregroundStyle(Color.themeSubtext)
                        }
                        blueprintSection(title: "Target Audience", content: blueprint.targetAudience, icon: "person.2.fill")
                        blueprintSection(title: "Value Proposition", content: blueprint.coreValueProposition, icon: "star.fill")
                        VStack(alignment: .leading, spacing: 12) {
                            Label("MVP Features", systemImage: "list.bullet.star").font(.headline).foregroundStyle(Color.themeAccent)
                            ForEach(blueprint.mvpFeatures, id: \.self) { feature in
                                HStack(alignment: .top) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themeAccent).font(.caption).padding(.top, 4); Text(feature).foregroundStyle(Color.themeText) }
                            }
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeSecondary).cornerRadius(12)
                        blueprintSection(title: "Revenue Model", content: blueprint.revenueModel, icon: "dollarsign.circle.fill")
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Technical Stack", systemImage: "cpu").font(.headline).foregroundStyle(Color.themeAccent)
                            Text(blueprint.technicalStack.joined(separator: ", ")).foregroundStyle(Color.themeText)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeSecondary).cornerRadius(12)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Roadmap", systemImage: "map.fill").font(.headline).foregroundStyle(Color.themeAccent)
                            ForEach(Array(blueprint.roadmap.enumerated()), id: \.offset) { index, step in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.black).frame(width: 20, height: 20).background(Color.themeAccent).clipShape(Circle())
                                    Text(step).foregroundStyle(Color.themeText)
                                }
                            }
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeSecondary).cornerRadius(12)
                    }.padding()
                }
            }
            .navigationTitle("Product Blueprint").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(Color.themeAccent) }
                ToolbarItem(placement: .topBarLeading) { Button { } label: { Image(systemName: "square.and.arrow.up").foregroundStyle(Color.themeAccent) } }
            }
        }
    }
    private func blueprintSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Color.themeAccent)
            Text(content.isEmpty ? "Still defining..." : content).foregroundStyle(content.isEmpty ? Color.themeSubtext : Color.themeText)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeSecondary).cornerRadius(12)
    }
}
