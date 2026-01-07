import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var speechService = SpeechService()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var elevenLabsService = ElevenLabsService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var conversationService = ConversationService.shared
    @ObservedObject private var dayStructure = DayStructureService.shared

    @State private var localMessages: [ConversationMessage] = []
    @State private var currentPhase: ConversationPhase = .idle
    @State private var isInCheckInSetup = false
    @State private var checkInSetupStep: CheckInSetupStep = .askIfWant
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
        case checkInSetup
    }
    
    enum CheckInSetupStep {
        case askIfWant
        case askMorning
        case askMorningTime
        case askAfternoon
        case askAfternoonTime
        case askEvening
        case askEveningTime
        case done
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

            Text("Please add your Claude API key in Settings to start using Gadfly.")
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
        
        if currentPhase == .awaitingConfirmation {
            Task {
                await handleConfirmationResponse(transcription)
            }
            return
        }
        
        currentPhase = .processing

        Task {
            await processWithAI(transcription)
        }
    }
    
    private func handleConfirmationResponse(_ input: String) async {
        let lowered = input.lowercased()
        let isYes = lowered.contains("yes") || lowered.contains("yeah") || lowered.contains("yep") || 
                    lowered.contains("sure") || lowered.contains("okay") || lowered.contains("ok") ||
                    lowered.contains("confirm") || lowered.contains("save") || lowered.contains("do it")
        let isNo = lowered.contains("no") || lowered.contains("nope") || lowered.contains("cancel") ||
                   lowered.contains("start over") || lowered.contains("try again") || lowered.contains("nevermind")
        
        if isYes, let result = lastParseResult {
            await saveItems(result)
        } else if isNo {
            lastParseResult = nil
            currentPhase = .idle
            let response = "No problem, let's start over. What would you like to add?"
            localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
            await speakResponse(response)
            currentPhase = .idle
        } else {
            let clarify = "I didn't catch that. Say yes to save or no to start over."
            localMessages.append(ConversationMessage(role: .assistant, content: clarify, timestamp: Date()))
            await speakResponse(clarify)
        }
    }

    private func processWithAI(_ input: String) async {
        if isInCheckInSetup {
            await handleCheckInSetupResponse(input)
            return
        }
        
        do {
            print("🎭 SENDING TO AI WITH PERSONALITY: \(appState.selectedPersonality.displayName)")
            let result = try await openAIService.processUserInput(input, apiKey: appState.claudeKey, personality: appState.selectedPersonality)
            print("🎭 AI PARSED: \(result.tasks.count) tasks, \(result.events.count) events, \(result.reminders.count) reminders")
            print("🎭 AI SUMMARY: \(result.summary ?? "nil")")

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

                // If there are also other items, save them too
                if !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty {
                    await saveItems(result)
                } else {
                    currentPhase = .idle
                }
                return
            }

            let hasItems = !result.tasks.isEmpty || !result.events.isEmpty || !result.reminders.isEmpty

            if hasItems {
                lastParseResult = result
                currentPhase = .awaitingConfirmation
                
                let preview = buildPreviewMessage(result)
                localMessages.append(ConversationMessage(role: .assistant, content: preview, timestamp: Date()))
                await speakResponse(preview)
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
        case .sage: return "The pause ends. Wisdom resumes its gentle guidance."
        case .rebel: return "Break over. Back to taking control of your day."
        case .trickster: return "Plot twist: break cancelled! Did you expect that? I didn't either."
        case .stoic: return "Break concluded. Duty calls once more."
        case .pirate: return "Arr! Shore leave be over! Back to huntin' treasure!"
        case .witch: return "The spell of silence breaks. Let us continue our work."
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
        case .sage: return "A \(duration) respite. Even the wisest need rest."
        case .rebel: return "\(duration) break. Taking control of your time. I respect that."
        case .trickster: return "\(duration) break? Or is it? It is. ...Or is it? It is."
        case .stoic: return "\(duration) of peace. Rest is part of the work."
        case .pirate: return "\(duration) shore leave granted! Rest yer sea legs!"
        case .witch: return "A \(duration) potion of rest. Let it brew."
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
        case .sage: return "Rest until \(time). The path will be here when you return."
        case .rebel: return "Off the grid until \(time). Your time, your rules."
        case .trickster: return "Vanishing until \(time)! Now you see me, now you don't!"
        case .stoic: return "Silence until \(time). Use this time with purpose."
        case .pirate: return "Anchored until \(time)! The treasure ain't goin' anywhere!"
        case .witch: return "A silence spell until \(time). The magic will wait."
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

    private func buildPreviewMessage(_ result: OpenAIService.ParseResult) -> String {
        var lines: [String] = ["Here's what I'll create:"]
        
        for task in result.tasks {
            var taskLine = "Task: \(task.title)"
            if let deadline = task.deadline {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                taskLine += " (due \(formatter.string(from: deadline)))"
            }
            lines.append(taskLine)
        }
        
        for event in result.events {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            var eventLine = "Event: \(event.title) at \(formatter.string(from: event.startDate))"
            if let location = event.location {
                eventLine += " - \(location)"
            }
            lines.append(eventLine)
        }
        
        for reminder in result.reminders {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lines.append("Reminder: \(reminder.title) at \(formatter.string(from: reminder.triggerDate))")
        }
        
        lines.append("Save these? Say yes to confirm or no to start over.")
        return lines.joined(separator: "\n")
    }

    private func speakResponse(_ text: String) async {
        currentPhase = .speaking

        let hasCustomVoice = VoiceCloningService.shared.customVoiceId != nil
        if appState.hasValidElevenLabsKey && (hasCustomVoice || appState.hasVoiceSelected) {
            do {
                try await elevenLabsService.speakWithBestVoice(text, apiKey: appState.elevenLabsKey, selectedVoiceId: appState.selectedVoiceId)
            } catch {
                await speechService.speak(text)
            }
        } else {
            await speechService.speak(text)
        }
        
        speechService.prepareForRecording()
    }

    private var hasAnyCheckInsEnabled: Bool {
        dayStructure.morningCheckInEnabled || 
        dayStructure.middayCheckInEnabled || 
        dayStructure.bedtimeCheckInEnabled
    }
    
    private func saveItems(_ result: OpenAIService.ParseResult) async {
        print("💾 SAVING: \(result.tasks.count) tasks, \(result.events.count) events, \(result.reminders.count) reminders")
        
        do {
            let saveResult = try await calendarService.saveAllItems(
                from: result,
                remindersEnabled: appState.remindersEnabled,
                eventReminderMinutes: appState.eventReminderMinutes,
                nagIntervalMinutes: appState.nagIntervalMinutes
            )
            print("✅ SAVED: \(saveResult.summary)")
            let confirmation = NotificationService.shared.getConfirmationMessage(itemSummary: saveResult.summary)
            localMessages.append(ConversationMessage(role: .assistant, content: confirmation, timestamp: Date()))
            await speakResponse(confirmation)
            lastParseResult = nil
            openAIService.resetConversation()
            
            if !hasAnyCheckInsEnabled && !dayStructure.hasDeclinedCheckInSetup {
                await promptForCheckInSetup()
            } else {
                currentPhase = .idle
            }
        } catch {
            print("❌ SAVE FAILED: \(error.localizedDescription)")
            let errorMsg = "Couldn't save - \(error.localizedDescription)"
            localMessages.append(ConversationMessage(role: .assistant, content: errorMsg, timestamp: Date()))
            await speakResponse("Sorry, I couldn't save those items. Please try again.")
            currentPhase = .idle
        }
    }
    
    private func promptForCheckInSetup() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let prompt = getCheckInSetupPrompt()
        localMessages.append(ConversationMessage(role: .assistant, content: prompt, timestamp: Date()))
        await speakResponse(prompt)
        
        isInCheckInSetup = true
        checkInSetupStep = .askIfWant
        currentPhase = .checkInSetup
    }
    
    private func getCheckInSetupPrompt() -> String {
        switch appState.selectedPersonality {
        case .pemberton:
            return "By the way, would you like me to check in with you throughout the day? A morning review, perhaps an afternoon nudge, and an evening reflection? It helps keep one... accountable."
        case .sergent:
            return "Soldier! Want me to run daily check-ins? Morning briefing, afternoon status report, evening debrief. Keeps you mission-ready!"
        case .cheerleader:
            return "Hey! Want me to check in with you during the day? Like a morning pep talk, afternoon boost, and evening celebration? It's so helpful!"
        case .butler:
            return "If I may suggest, Sir - daily check-ins can be most beneficial. A morning review, afternoon touch-base, and evening summary. Shall I arrange these?"
        case .coach:
            return "Want to set up daily check-ins? Morning game plan, halftime check, and end-of-day review. Keeps you winning!"
        case .zen:
            return "Would you find value in gentle daily reminders? A morning intention, midday pause, and evening reflection can bring mindful structure."
        case .parent:
            return "Sweetie, would you like me to check in on you during the day? Just a morning hello, afternoon peek-in, and evening chat?"
        case .bestie:
            return "Oh! Want me to check in with you? Like a morning hey, afternoon vibe check, and evening catch-up? Super helpful honestly."
        case .robot:
            return "Query: Enable daily check-in protocol? Options: morning, afternoon, evening intervals. Optimizes task completion rates."
        case .therapist:
            return "Would you find it helpful to have structured check-ins? A morning intention-setting, afternoon progress pause, and evening reflection can support your goals."
        case .hypeFriend:
            return "YO! Want daily check-ins?! Morning HYPE, afternoon ENERGY BOOST, evening VICTORY LAP! Let's DO THIS!"
        case .chillBuddy:
            return "Hey... wanna set up some chill check-ins? Morning vibes, afternoon break, evening wind-down. No pressure though."
        case .snarky:
            return "So... want me to nag you at specific times? Morning, afternoon, evening? I promise to be... supportive. Mostly."
        case .gamer:
            return "Want to unlock Daily Check-ins? Morning Quest Log, Afternoon Status Check, Evening XP Review! Achievement hunting made easy!"
        case .tiredParent:
            return "Want me to check in during the day? Morning, afternoon, evening. Helps us both stay on track. Maybe."
        case .sage:
            return "The wise establish rhythms. Would you walk this path with morning reflection, midday pause, and evening contemplation?"
        case .rebel:
            return "Check-ins aren't about control - they're about taking YOUR power back. Morning, afternoon, evening. Want in?"
        case .trickster:
            return "What if... you had reminders that HELPED instead of annoyed? Morning, afternoon, evening. Plot twist: they work!"
        case .stoic:
            return "Structure serves virtue. Shall we establish morning, afternoon, and evening check-ins to support your duty?"
        case .pirate:
            return "Arr! Want a ship's log routine? Morning chart review, afternoon heading check, evening treasure count! What say ye?"
        case .witch:
            return "Care to brew a daily ritual? Morning awakening, afternoon stirring, evening reflection. The magic is in the routine..."
        }
    }
    
    private func handleCheckInSetupResponse(_ input: String) async {
        let lowered = input.lowercased()
        let isYes = lowered.contains("yes") || lowered.contains("sure") || lowered.contains("okay") || 
                    lowered.contains("ok") || lowered.contains("yeah") || lowered.contains("yep") ||
                    lowered.contains("please") || lowered.contains("sounds good") || lowered.contains("let's do")
        let isNo = lowered.contains("no") || lowered.contains("skip") || lowered.contains("later") ||
                   lowered.contains("not now") || lowered.contains("nah") || lowered.contains("nope")
        
        switch checkInSetupStep {
        case .askIfWant:
            if isNo {
                dayStructure.hasDeclinedCheckInSetup = true
                let response = "No problem! You can always set up check-ins later from the home screen."
                localMessages.append(ConversationMessage(role: .assistant, content: response, timestamp: Date()))
                await speakResponse(response)
                endCheckInSetup()
            } else if isYes {
                await askAboutMorningCheckIn()
            } else {
                let clarify = "Just say yes or no - would you like daily check-ins?"
                localMessages.append(ConversationMessage(role: .assistant, content: clarify, timestamp: Date()))
                await speakResponse(clarify)
            }
            
        case .askMorning:
            if isYes {
                dayStructure.morningCheckInEnabled = true
                await askAboutMorningTime()
            } else {
                dayStructure.morningCheckInEnabled = false
                await askAboutAfternoonCheckIn()
            }
            
        case .askMorningTime:
            if let time = parseTime(from: input) {
                dayStructure.morningCheckInTime = time
            }
            await askAboutAfternoonCheckIn()
            
        case .askAfternoon:
            if isYes {
                dayStructure.middayCheckInEnabled = true
                await askAboutAfternoonTime()
            } else {
                dayStructure.middayCheckInEnabled = false
                await askAboutEveningCheckIn()
            }
            
        case .askAfternoonTime:
            if let time = parseTime(from: input) {
                dayStructure.middayCheckInTime = time
            }
            await askAboutEveningCheckIn()
            
        case .askEvening:
            if isYes {
                dayStructure.bedtimeCheckInEnabled = true
                await askAboutEveningTime()
            } else {
                dayStructure.bedtimeCheckInEnabled = false
                await finishCheckInSetup()
            }
            
        case .askEveningTime:
            if let time = parseTime(from: input) {
                dayStructure.bedtimeCheckInTime = time
            }
            await finishCheckInSetup()
            
        case .done:
            endCheckInSetup()
        }
    }
    
    private func askAboutMorningCheckIn() async {
        checkInSetupStep = .askMorning
        let msg = "Would you like a morning check-in to start your day? Say yes or no."
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func askAboutMorningTime() async {
        checkInSetupStep = .askMorningTime
        let msg = "What time works for morning? Say something like '7 AM' or 'eight thirty'."
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func askAboutAfternoonCheckIn() async {
        checkInSetupStep = .askAfternoon
        let msg = "How about an afternoon check-in? Yes or no."
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func askAboutAfternoonTime() async {
        checkInSetupStep = .askAfternoonTime
        let msg = "What time for the afternoon check-in?"
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func askAboutEveningCheckIn() async {
        checkInSetupStep = .askEvening
        let msg = "And an evening check-in to wind down? Yes or no."
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func askAboutEveningTime() async {
        checkInSetupStep = .askEveningTime
        let msg = "What time for evening?"
        localMessages.append(ConversationMessage(role: .assistant, content: msg, timestamp: Date()))
        await speakResponse(msg)
    }
    
    private func finishCheckInSetup() async {
        checkInSetupStep = .done
        dayStructure.scheduleCheckInNotifications()
        
        var summary = "All set! I'll check in with you"
        var parts: [String] = []
        if dayStructure.morningCheckInEnabled {
            parts.append("in the morning at \(formatTime(dayStructure.morningCheckInTime))")
        }
        if dayStructure.middayCheckInEnabled {
            parts.append("in the afternoon at \(formatTime(dayStructure.middayCheckInTime))")
        }
        if dayStructure.bedtimeCheckInEnabled {
            parts.append("in the evening at \(formatTime(dayStructure.bedtimeCheckInTime))")
        }
        
        if parts.isEmpty {
            summary = "No check-ins set. You can always add them later from the home screen."
        } else if parts.count == 1 {
            summary += " \(parts[0])."
        } else {
            summary += " \(parts.dropLast().joined(separator: ", ")), and \(parts.last!)."
        }
        
        localMessages.append(ConversationMessage(role: .assistant, content: summary, timestamp: Date()))
        await speakResponse(summary)
        endCheckInSetup()
    }
    
    private func endCheckInSetup() {
        isInCheckInSetup = false
        checkInSetupStep = .askIfWant
        currentPhase = .idle
    }
    
    private func parseTime(from input: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        
        let formats = ["h:mm a", "h:mma", "h a", "ha", "HH:mm", "H:mm"]
        let cleaned = input.lowercased()
            .replacingOccurrences(of: "o'clock", with: "")
            .replacingOccurrences(of: "oclock", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: date)
                return calendar.date(from: components)
            }
        }
        
        let numberWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, 
                          "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12]
        
        for (word, hour) in numberWords {
            if cleaned.contains(word) {
                var finalHour = hour
                if cleaned.contains("pm") || cleaned.contains("p.m") || cleaned.contains("afternoon") || cleaned.contains("evening") {
                    if hour < 12 { finalHour += 12 }
                } else if cleaned.contains("am") || cleaned.contains("a.m") || cleaned.contains("morning") {
                    if hour == 12 { finalHour = 0 }
                } else if hour < 7 {
                    finalHour += 12
                }
                
                var minute = 0
                if cleaned.contains("thirty") || cleaned.contains("30") { minute = 30 }
                if cleaned.contains("fifteen") || cleaned.contains("15") { minute = 15 }
                if cleaned.contains("forty-five") || cleaned.contains("45") { minute = 45 }
                
                let calendar = Calendar.current
                return calendar.date(from: DateComponents(hour: finalHour, minute: minute))
            }
        }
        
        return nil
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

#Preview {
    RecordingView()
        .environmentObject(AppState())
}
