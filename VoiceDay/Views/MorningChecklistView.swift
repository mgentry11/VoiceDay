import SwiftUI
import EventKit

/// Bot-led morning checklist - one item at a time
/// Big buttons, voice prompts, no thinking required
struct MorningChecklistView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @ObservedObject private var checklistService = MorningChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var speechService = SpeechService()
    @EnvironmentObject var appState: AppState

    @State private var currentIndex = 0
    @State private var showingAllDone = false
    @State private var showingIntro = true  // Start with intro
    @State private var isListening = false
    @State private var listenHint = "Tap mic or say 'Done' / 'Skip'"
    @State private var hasStartedSession = false  // Track if we've already started

    // Keys for persisting check-in state
    private let savedIndexKey = "morning_checklist_current_index"
    private let savedDateKey = "morning_checklist_session_date"

    // Deep link states
    @State private var showCalendar = false
    @State private var showTasks = false
    @State private var showGoals = false
    @State private var showSettings = false
    @State private var showCustomCheck = false
    @State private var customCheckTitle = ""

    // Action/Schedule states (post-check options)
    @State private var showActionOptions = false
    @State private var isListeningForNote = false
    @State private var noteText = ""
    @State private var selectedScheduleTime: Date?
    @State private var showSchedulePicker = false
    @State private var showResetOptions = false

    private var activeChecks: [MorningChecklistService.SelfCheck] {
        checklistService.activeChecks
    }

    private var currentCheck: MorningChecklistService.SelfCheck? {
        guard currentIndex < activeChecks.count else { return nil }
        return activeChecks[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingIntro && !appState.isSimpleMode {
                // Pro mode - show intro screen
                introView
            } else if showingAllDone {
                allDoneView
            } else if showActionOptions, let check = currentCheck {
                // Action options after marking done
                actionOptionsView(for: check)
            } else if let check = currentCheck {
                checkView(for: check)
            } else {
                // No checks configured
                noChecksView
            }
        }
        .background(Color.themeBackground)
        .onAppear {
            // Only do initial setup once - don't reset when coming back from Settings
            guard !hasStartedSession else { return }
            hasStartedSession = true

            // Load saved position if from today's session
            loadSavedPosition()

            // Small delay to ensure audio session is configured before first speech
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if appState.isSimpleMode {
                    // In Simple mode, skip intro and go directly to current check
                    showingIntro = false
                    handleCurrentCheck()
                } else {
                    speakGreeting()
                }
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            // Save position for state restoration
            saveCurrentPosition(newIndex)

            // When moving to next check in Simple mode, auto-handle it
            if appState.isSimpleMode && !showingIntro && !showingAllDone {
                handleCurrentCheck()
            }
        }
        .onChange(of: appState.isSimpleMode) { _, isSimple in
            // When switching to Simple mode mid-session, skip intro and adapt
            if isSimple && showingIntro {
                showingIntro = false
                // Don't re-speak if we already have a check showing
                if currentCheck != nil && !showingAllDone {
                    handleCurrentCheck()
                }
            }
        }
        .sheet(isPresented: $showSchedulePicker) {
            ScheduleTimePickerSheet(
                selectedTime: $selectedScheduleTime,
                onSchedule: { time in
                    scheduleCurrentCheck(at: time)
                },
                onDismiss: {
                    showSchedulePicker = false
                    proceedToNext()
                }
            )
        }
        .sheet(isPresented: $showCalendar, onDismiss: {
            // Auto-mark done and move to next in Simple mode
            if appState.isSimpleMode {
                markDoneAndProceed()
            }
        }) {
            CalendarReviewSheet()
        }
        .sheet(isPresented: $showTasks, onDismiss: {
            // Auto-mark done and move to next in Simple mode
            if appState.isSimpleMode {
                markDoneAndProceed()
            }
        }) {
            TasksReviewSheet()
        }
        .sheet(isPresented: $showGoals, onDismiss: {
            // Auto-mark done and move to next in Simple mode
            if appState.isSimpleMode {
                markDoneAndProceed()
            }
        }) {
            GoalsReviewSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showResetOptions) {
            ResetOptionsSheet(
                onReset: { resetType in
                    performReset(type: resetType)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCustomCheck) {
            CustomCheckSheet(title: customCheckTitle, onMarkDone: {
                markDone()
                showCustomCheck = false
            })
        }
    }

    // MARK: - Custom Check Sheet

    struct CustomCheckSheet: View {
        let title: String
        let onMarkDone: () -> Void

        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss
        @State private var notes = ""

        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()

                    // The check item prominently displayed
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(themeColors.accent)

                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(themeColors.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Encouragement
                    Text("Take a moment to do this now")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)

                    // Optional notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)

                        TextField("Add a note...", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            // Save note if any
                            if !notes.isEmpty {
                                // Could save to a log/journal
                                print("Note for '\(title)': \(notes)")
                            }
                            onMarkDone()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done!")
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.themeAccent)
                            .cornerRadius(12)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Go back")
                                .font(.subheadline)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle("Check Item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .onAppear {
                SpeechService.shared.queueSpeech("Go ahead and \(title.lowercased()). Tap done when you're finished.")
            }
        }
    }

    // MARK: - Calendar Review Sheet

    struct CalendarReviewSheet: View {
        @StateObject private var calendarService = CalendarService()
        @StateObject private var openAIService = OpenAIService()
        @StateObject private var speechService = SpeechService()
        @ObservedObject private var themeColors = ThemeColors.shared
        @EnvironmentObject var appState: AppState
        @Environment(\.dismiss) private var dismiss
        @State private var events: [EKEvent] = []
        @State private var isLoading = true
        @State private var isAddingNew = false
        @State private var isListening = false

        // Walk-through/Spotlight mode
        @State private var isWalkingThrough = false
        @State private var currentEventIndex = 0
        @State private var isListeningForResponse = false
        @State private var showActionConfirmation = false
        @State private var confirmationMessage = ""

        // Post-walkthrough add new flow
        @State private var isAskingToAddNew = false
        @State private var isListeningForNewEvent = false
        @State private var isProcessingNewEvent = false
        @State private var newEventText = ""

        private var currentEvent: EKEvent? {
            guard currentEventIndex < events.count else { return nil }
            return events[currentEventIndex]
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView("Loading calendar...")
                        } else if events.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 50))
                                    .foregroundStyle(themeColors.accent)
                                Text("Nothing on your calendar today!")
                                    .font(.title3)
                                    .foregroundStyle(themeColors.text)
                                Text("Your day is wide open")
                                    .font(.subheadline)
                                    .foregroundStyle(themeColors.subtext)

                                // Action buttons for empty calendar
                                VStack(spacing: 12) {
                                    Button {
                                        startAddingNew()
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add something to my day")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(themeColors.accent)
                                        .cornerRadius(12)
                                    }

                                    Button {
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle")
                                            Text("Continue - I'm good!")
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(themeColors.accent)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding()
                        } else if isAskingToAddNew {
                            // Post-walkthrough: ask about adding new events
                            addNewEventView
                        } else if isWalkingThrough || (appState.isSimpleMode && !events.isEmpty) {
                            // Walk-through view - Simple mode goes directly here
                            spotlightView
                        } else {
                            // Pro mode - Regular list view with options
                            VStack(spacing: 12) {
                                // Walk-through button
                                Button {
                                    startWalkThrough()
                                } label: {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                        Text("Walk through my day")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(themeColors.accent)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)

                                ScrollView {
                                    VStack(spacing: 12) {
                                        ForEach(events, id: \.eventIdentifier) { event in
                                            eventCard(event)
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }

                        // Add new button (Pro mode only, not during walk-through)
                        if !isWalkingThrough && !appState.isSimpleMode {
                            Button {
                                startAddingNew()
                            } label: {
                                HStack {
                                    Image(systemName: isListening ? "waveform" : "plus.circle.fill")
                                        .symbolEffect(.pulse, isActive: isListening)
                                    Text(isListening ? "Listening... say an event" : "Add new event")
                                }
                                .font(.headline)
                                .foregroundStyle(isListening ? .red : themeColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.themeSecondary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }

                    // Action confirmation overlay
                    if showActionConfirmation {
                        VStack {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                Text(confirmationMessage)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(themeColors.accent)
                            .cornerRadius(20)
                            .shadow(radius: 10)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                    }
                }
                .animation(.spring(response: 0.3), value: showActionConfirmation)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if isWalkingThrough || isAskingToAddNew {
                            Button("List") {
                                isWalkingThrough = false
                                isAskingToAddNew = false
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .task {
                _ = await calendarService.requestCalendarAccess()
                events = calendarService.fetchUpcomingEvents(days: 1)

                // In Simple mode, set up walk-through state before showing
                if appState.isSimpleMode && !events.isEmpty {
                    currentEventIndex = 0
                    isWalkingThrough = true
                }

                isLoading = false

                // Speak appropriate message
                if appState.isSimpleMode && !events.isEmpty {
                    speakCurrentEvent()
                    // Auto-start listening after speaking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if !isListeningForResponse {
                            toggleListeningForResponse()
                        }
                    }
                } else if !appState.isSimpleMode {
                    speakCalendarSummary()
                }
            }
        }

        // MARK: - Spotlight View (Walk-through mode)

        private var spotlightView: some View {
            VStack(spacing: 24) {
                Spacer()

                // Big centered event card
                if let event = currentEvent {
                    VStack(spacing: 20) {
                        // Time - prominent display
                        VStack(spacing: 4) {
                            Text(event.startDate, style: .time)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColors.accent)

                            if let endDate = event.endDate, endDate != event.startDate {
                                HStack {
                                    Text("to")
                                        .foregroundStyle(themeColors.subtext)
                                    Text(endDate, style: .time)
                                        .foregroundStyle(themeColors.text)
                                }
                                .font(.title3)
                            }
                        }

                        // Event title - big and readable
                        Text(event.title ?? "Untitled Event")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(themeColors.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Location if available
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(themeColors.accent)
                                Text(location)
                                    .foregroundStyle(themeColors.subtext)
                            }
                            .font(.title3)
                        }

                        // Duration badge
                        if let end = event.endDate {
                            let duration = end.timeIntervalSince(event.startDate)
                            let minutes = Int(duration / 60)
                            let hours = minutes / 60
                            let remainingMinutes = minutes % 60

                            HStack {
                                Image(systemName: "clock")
                                if hours > 0 {
                                    Text("\(hours)h \(remainingMinutes > 0 ? "\(remainingMinutes)m" : "")")
                                } else {
                                    Text("\(minutes) min")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(themeColors.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(themeColors.accent.opacity(0.2))
                            .cornerRadius(20)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.themeSecondary)
                            .shadow(color: themeColors.accent.opacity(0.3), radius: 20)
                    )
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Voice command hint
                Text(isListeningForResponse ? "Listening..." : "Say: keep, reschedule, delete, or skip")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)

                // Voice button (large, centered)
                Button {
                    toggleListeningForResponse()
                } label: {
                    Image(systemName: isListeningForResponse ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(isListeningForResponse ? .red : themeColors.accent)
                        .symbolEffect(.pulse, isActive: isListeningForResponse)
                }
                .padding(.bottom, 16)

                // Manual action buttons - Pro mode only
                if !appState.isSimpleMode {
                    HStack(spacing: 12) {
                        // Keep/Next
                        Button {
                            moveToNextEvent()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                Text("Keep")
                                    .font(.caption)
                            }
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }

                        // Reschedule
                        Button {
                            if let event = currentEvent {
                                rescheduleEventSpotlight(event)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                Text("+1 hour")
                                    .font(.caption)
                            }
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }

                        // Delete
                        Button {
                            if let event = currentEvent {
                                deleteEventSpotlight(event)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash.circle")
                                    .font(.title2)
                                Text("Delete")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }

                        // Skip
                        Button {
                            skipEvent()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "forward.circle")
                                    .font(.title2)
                                Text("Skip")
                                    .font(.caption)
                            }
                            .foregroundStyle(themeColors.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer().frame(height: 16)
            }
        }

        // MARK: - Navigation Title

        private var navigationTitle: String {
            if isAskingToAddNew {
                return "Add New Events"
            } else if isWalkingThrough {
                return "Event \(currentEventIndex + 1) of \(events.count)"
            } else {
                return "Today's Calendar"
            }
        }

        // MARK: - Add New Event View (Post-walkthrough)

        private var addNewEventView: some View {
            VStack(spacing: 24) {
                Spacer()

                // Prompt
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(themeColors.accent)

                    Text("Anything else to add?")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(themeColors.text)

                    Text("Tell me about any events, meetings, or appointments you need to add today")
                        .font(.body)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if isProcessingNewEvent {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Processing...")
                            .foregroundStyle(themeColors.subtext)
                    }
                    .padding()
                }

                Spacer()

                // Voice hint
                Text(isListeningForNewEvent ? "Listening..." : "Tap the mic and tell me what to add")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)

                // Large mic button
                Button {
                    toggleListeningForNewEvent()
                } label: {
                    Image(systemName: isListeningForNewEvent ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(isListeningForNewEvent ? .red : themeColors.accent)
                        .symbolEffect(.pulse, isActive: isListeningForNewEvent)
                }
                .padding(.bottom, 8)

                // Bottom buttons
                HStack(spacing: 16) {
                    // Done - no more to add
                    Button {
                        finishAddingNew()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("All done!")
                        }
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeSecondary)
                        .cornerRadius(12)
                    }

                    // Add more
                    Button {
                        toggleListeningForNewEvent()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add event")
                        }
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeSecondary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }

        // MARK: - Walk-through Actions

        private func startWalkThrough() {
            currentEventIndex = 0
            isWalkingThrough = true
            speakCurrentEvent()
        }

        private func speakCurrentEvent() {
            guard let event = currentEvent else { return }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let time = formatter.string(from: event.startDate)

            SpeechService.shared.queueSpeech("\(event.title ?? "Event") at \(time). Keep, reschedule, delete, or skip?")
        }

        private func toggleListeningForResponse() {
            if isListeningForResponse {
                stopListeningAndProcessResponse()
            } else {
                do {
                    try speechService.startListening()
                    isListeningForResponse = true

                    // Auto-stop after 15 seconds (give user time to speak)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        if isListeningForResponse {
                            stopListeningAndProcessResponse()
                        }
                    }
                } catch {
                    print("Failed to start listening: \(error)")
                }
            }
        }

        private func stopListeningAndProcessResponse() {
            speechService.stopListening()
            isListeningForResponse = false

            let response = speechService.transcribedText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !response.isEmpty else { return }

            if response.contains("keep") || response.contains("next") || response.contains("good") || response.contains("okay") {
                moveToNextEvent()
            } else if response.contains("reschedule") || response.contains("push") || response.contains("move") || response.contains("later") {
                if let event = currentEvent {
                    rescheduleEventSpotlight(event)
                }
            } else if response.contains("delete") || response.contains("remove") || response.contains("cancel") {
                if let event = currentEvent {
                    deleteEventSpotlight(event)
                }
            } else if response.contains("skip") || response.contains("pass") {
                skipEvent()
            } else {
                SpeechService.shared.queueSpeech("I didn't catch that. Say keep, reschedule, delete, or skip.")
            }
        }

        private func moveToNextEvent() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            if currentEventIndex < events.count - 1 {
                currentEventIndex += 1
                speakCurrentEvent()

                // In Simple mode, auto-start listening for next event
                if appState.isSimpleMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if !isListeningForResponse && isWalkingThrough {
                            toggleListeningForResponse()
                        }
                    }
                }
            } else {
                // Done reviewing - transition to add new phase
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                isWalkingThrough = false
                isAskingToAddNew = true

                SpeechService.shared.queueSpeech("That's everything on your calendar. Anything else you need to add today?")

                // In Simple mode, auto-start listening for new event input
                if appState.isSimpleMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if !isListeningForNewEvent {
                            toggleListeningForNewEvent()
                        }
                    }
                }
            }
        }

        // MARK: - Add New Event Actions

        private func toggleListeningForNewEvent() {
            if isListeningForNewEvent {
                stopListeningAndProcessNewEvent()
            } else {
                do {
                    try speechService.startListening()
                    isListeningForNewEvent = true

                    // Auto-stop after 6 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        if isListeningForNewEvent {
                            stopListeningAndProcessNewEvent()
                        }
                    }
                } catch {
                    print("Failed to start listening: \(error)")
                }
            }
        }

        private func stopListeningAndProcessNewEvent() {
            speechService.stopListening()
            isListeningForNewEvent = false

            let text = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                SpeechService.shared.queueSpeech("I didn't catch that. Try again or tap All Done if you're finished.")
                return
            }

            // Check for "done" or "no" responses
            let lower = text.lowercased()
            if lower.contains("no") || lower.contains("done") || lower.contains("nothing") || lower.contains("that's it") || lower.contains("all set") {
                finishAddingNew()
                return
            }

            isProcessingNewEvent = true
            SpeechService.shared.queueSpeech("Got it, adding that for you.")

            Task {
                do {
                    let result = try await openAIService.processUserInput(text, apiKey: appState.claudeKey, personality: appState.selectedPersonality)

                    if !result.events.isEmpty {
                        let _ = try await calendarService.saveAllItems(from: result)
                        events = calendarService.fetchUpcomingEvents(days: 1)

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        let celebrations = [
                            "Added! Anything else?",
                            "Done! What else do you have?",
                            "Got it! More events to add?",
                            "Perfect! Anything else for today?"
                        ]
                        SpeechService.shared.queueSpeech(celebrations.randomElement()!)
                    } else {
                        SpeechService.shared.queueSpeech("I couldn't create an event from that. Can you try describing it differently?")
                    }
                } catch {
                    SpeechService.shared.queueSpeech("Something went wrong. Let's try again.")
                }

                isProcessingNewEvent = false
            }
        }

        private func finishAddingNew() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            let celebrations = [
                "Perfect! Your day is all set. You've got this!",
                "Awesome! Calendar is ready. Go crush it!",
                "All done! Your schedule is locked in.",
                "Great! You're organized and ready to roll!"
            ]
            SpeechService.shared.queueSpeech(celebrations.randomElement()!)

            isAskingToAddNew = false
        }

        private func rescheduleEventSpotlight(_ event: EKEvent) {
            // Haptic celebration
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            confirmationMessage = "Moved +1 hour!"
            withAnimation(.spring(response: 0.3)) {
                showActionConfirmation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showActionConfirmation = false
                }
            }

            Task {
                let newStart = event.startDate.addingTimeInterval(3600)
                let newEnd = event.endDate?.addingTimeInterval(3600)

                try? calendarService.updateEvent(
                    event,
                    title: event.title ?? "",
                    startDate: newStart,
                    endDate: newEnd ?? newStart.addingTimeInterval(3600),
                    location: event.location,
                    notes: event.notes
                )
                events = calendarService.fetchUpcomingEvents(days: 1)

                let celebrations = [
                    "Rescheduled! Giving yourself breathing room.",
                    "Moved! Smart time management.",
                    "Pushed back an hour. You're in control!"
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)

                // Move to next after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    moveToNextEvent()
                }
            }
        }

        private func deleteEventSpotlight(_ event: EKEvent) {
            // Haptic celebration
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            confirmationMessage = "Deleted!"
            withAnimation(.spring(response: 0.3)) {
                showActionConfirmation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showActionConfirmation = false
                }
            }

            Task {
                try? calendarService.deleteEvent(event)
                events = calendarService.fetchUpcomingEvents(days: 1)

                let celebrations = [
                    "Gone! That's off your calendar.",
                    "Deleted! More free time for you.",
                    "Cleared! Your schedule just got lighter."
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)

                // Adjust index if needed
                if currentEventIndex >= events.count && events.count > 0 {
                    currentEventIndex = events.count - 1
                }

                // Move to next or end
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if events.isEmpty {
                        isWalkingThrough = false
                        SpeechService.shared.queueSpeech("No more events today!")
                    } else {
                        speakCurrentEvent()
                    }
                }
            }
        }

        private func skipEvent() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            let responses = [
                "Skipped! Moving on.",
                "No problem, next one.",
                "Got it, we'll leave that one."
            ]
            SpeechService.shared.queueSpeech(responses.randomElement()!)
            moveToNextEvent()
        }

        private func startAddingNew() {
            if isListening {
                stopListeningAndProcess()
            } else {
                // Speak prompt FIRST, then start listening after speech finishes
                Task {
                    do {
                        // Speak the prompt
                        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
                        let voiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""
                        if !apiKey.isEmpty {
                            let service = ElevenLabsService()
                            try await service.speakWithBestVoice("What would you like to add to your calendar?", apiKey: apiKey, selectedVoiceId: voiceId)
                        }

                        // Now start listening
                        await MainActor.run {
                            do {
                                try speechService.startListening()
                                isListening = true
                            } catch {
                                print("Failed to start listening: \(error)")
                            }
                        }
                    } catch {
                        print("Failed to speak prompt: \(error)")
                    }
                }
            }
        }

        private func stopListeningAndProcess() {
            speechService.stopListening()
            isListening = false

            let text = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            Task {
                do {
                    let result = try await openAIService.processUserInput(text, apiKey: appState.claudeKey, personality: appState.selectedPersonality)
                    if !result.events.isEmpty {
                        let _ = try await calendarService.saveAllItems(from: result)
                        events = calendarService.fetchUpcomingEvents(days: 1)
                        SpeechService.shared.queueSpeech(result.summary ?? "Event added!")
                    } else {
                        SpeechService.shared.queueSpeech("I didn't catch an event. Try again?")
                    }
                } catch {
                    SpeechService.shared.queueSpeech("Sorry, something went wrong.")
                }
            }
        }

        private func eventCard(_ event: EKEvent) -> some View {
            HStack(spacing: 12) {
                // Time
                VStack(alignment: .trailing) {
                    Text(event.startDate, style: .time)
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)
                    if let endDate = event.endDate {
                        Text(endDate, style: .time)
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                }
                .frame(width: 70)

                // Divider
                Rectangle()
                    .fill(themeColors.accent)
                    .frame(width: 3)
                    .cornerRadius(2)

                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title ?? "Untitled")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundStyle(themeColors.subtext)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    // Reschedule (push 1 hour)
                    Button {
                        rescheduleEvent(event, hours: 1)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    // Delete
                    Button {
                        deleteEvent(event)
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }

        private func rescheduleEvent(_ event: EKEvent, hours: Int) {
            // Haptic celebration
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            Task {
                let newStart = event.startDate.addingTimeInterval(Double(hours * 3600))
                let newEnd = event.endDate?.addingTimeInterval(Double(hours * 3600))

                try? calendarService.updateEvent(
                    event,
                    title: event.title ?? "",
                    startDate: newStart,
                    endDate: newEnd ?? newStart.addingTimeInterval(3600),
                    location: event.location,
                    notes: event.notes
                )
                events = calendarService.fetchUpcomingEvents(days: 1)

                // Encouraging messages
                let celebrations = [
                    "Rescheduled! Giving yourself breathing room.",
                    "Moved! Smart time management.",
                    "Pushed back - you're in control!",
                    "Done! Your schedule, your rules."
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)
            }
        }

        private func deleteEvent(_ event: EKEvent) {
            // Haptic celebration
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            Task {
                try? calendarService.deleteEvent(event)
                events = calendarService.fetchUpcomingEvents(days: 1)

                // Satisfying messages
                let celebrations = [
                    "Gone! That's off your calendar.",
                    "Deleted! More free time for you.",
                    "Cleared! Your schedule just got lighter.",
                    "Boom! Event removed."
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)
            }
        }

        private func speakCalendarSummary() {
            if events.isEmpty {
                SpeechService.shared.queueSpeech("Your calendar is clear for today. Nothing scheduled!")
            } else if events.count == 1 {
                let event = events[0]
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let time = formatter.string(from: event.startDate)
                SpeechService.shared.queueSpeech("You have one thing today: \(event.title ?? "an event") at \(time).")
            } else {
                SpeechService.shared.queueSpeech("You have \(events.count) things on your calendar today. Let me walk you through them.")

                // Speak each event with a delay
                for (index, event) in events.enumerated() {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    let time = formatter.string(from: event.startDate)

                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1) * 2.5) {
                        SpeechService.shared.queueSpeech("\(event.title ?? "Event") at \(time).")
                    }
                }
            }
        }
    }

    // MARK: - Tasks Review Sheet

    struct TasksReviewSheet: View {
        @StateObject private var calendarService = CalendarService()
        @StateObject private var openAIService = OpenAIService()
        @StateObject private var speechService = SpeechService()
        @ObservedObject private var themeColors = ThemeColors.shared
        @EnvironmentObject var appState: AppState
        @Environment(\.dismiss) private var dismiss
        @State private var reminders: [EKReminder] = []
        @State private var isLoading = true
        @State private var isListening = false
        @State private var showPriorityPicker = false
        @State private var selectedReminder: EKReminder?
        @State private var isListeningForPriority = false

        // New task priority flow
        @State private var newlyAddedReminder: EKReminder?
        @State private var showNewTaskPriorityPicker = false

        // Walk-through mode
        @State private var isWalkingThrough = false
        @State private var currentTaskIndex = 0
        @State private var isListeningForResponse = false
        @State private var showPriorityConfirmation = false
        @State private var confirmationPriority = 0

        // Scheduling during walk-through
        @State private var showTaskSchedulePicker = false
        @State private var taskScheduleTime: Date = Date()

        // Post-walk-through add new flow
        @State private var isAskingToAddNew = false
        @State private var isListeningForNewTask = false
        @State private var isProcessingNewTask = false
        @State private var newTaskText = ""

        // Task detail view
        @State private var showTaskDetail = false
        @State private var taskToView: EKReminder?

        private var currentTask: EKReminder? {
            guard currentTaskIndex < reminders.count else { return nil }
            return reminders[currentTaskIndex]
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading tasks...")
                    } else if reminders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 50))
                                .foregroundStyle(themeColors.accent)
                            Text("No tasks right now!")
                                .font(.title3)
                                .foregroundStyle(themeColors.text)
                        }
                        .padding()
                    } else if isAskingToAddNew {
                        // Post-walk-through: ask about adding new tasks
                        addNewTaskView
                    } else if (isWalkingThrough || (appState.isSimpleMode && !reminders.isEmpty)), let task = currentTask {
                        // Walk-through mode - Simple mode goes directly here
                        walkThroughView(task)
                    } else {
                        // Pro mode - List view with options
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                                    taskRow(reminder)
                                }
                            }
                            .padding()
                        }

                        // Walk through button
                        Button {
                            startWalkThrough()
                        } label: {
                            HStack {
                                Image(systemName: "person.wave.2")
                                Text("Walk me through each task")
                            }
                            .font(.headline)
                            .foregroundStyle(themeColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Add new button (Pro mode only, not during walk-through)
                    if !isWalkingThrough && !appState.isSimpleMode {
                        Button {
                            startAddingNew()
                        } label: {
                            HStack {
                                Image(systemName: isListening ? "waveform" : "plus.circle.fill")
                                    .symbolEffect(.pulse, isActive: isListening)
                                Text(isListening ? "Listening... say a task" : "Add new task")
                            }
                            .font(.headline)
                            .foregroundStyle(isListening ? .red : themeColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .navigationTitle("Your Tasks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if isWalkingThrough {
                            Button("Back to list") {
                                isWalkingThrough = false
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .task {
                _ = await calendarService.requestReminderAccess()
                reminders = await calendarService.fetchReminders(includeCompleted: false)

                // In Simple mode, set up walk-through state before showing
                if appState.isSimpleMode && !reminders.isEmpty {
                    currentTaskIndex = 0
                    isWalkingThrough = true
                }

                isLoading = false

                // Speak appropriate message
                if appState.isSimpleMode && !reminders.isEmpty {
                    speakCurrentTask()
                    // Auto-start listening after speaking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if !isListeningForResponse && isWalkingThrough {
                            toggleListeningForResponse()
                        }
                    }
                } else if !appState.isSimpleMode {
                    speakTasksSummary()
                }
            }
            .sheet(isPresented: $showPriorityPicker) {
                if let reminder = selectedReminder {
                    PriorityPickerSheet(
                        reminder: reminder,
                        calendarService: calendarService,
                        speechService: speechService,
                        onUpdate: {
                            Task {
                                reminders = await calendarService.fetchReminders(includeCompleted: false)
                            }
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showNewTaskPriorityPicker) {
                if let reminder = newlyAddedReminder {
                    NewTaskPrioritySheet(
                        reminder: reminder,
                        calendarService: calendarService,
                        speechService: speechService,
                        onUpdate: {
                            Task {
                                reminders = await calendarService.fetchReminders(includeCompleted: false)
                            }
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
        }

        // MARK: - Walk Through View

        private func walkThroughView(_ task: EKReminder) -> some View {
            VStack(spacing: 20) {
                // Progress
                Text("\(currentTaskIndex + 1) of \(reminders.count)")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                ProgressView(value: Double(currentTaskIndex), total: Double(reminders.count))
                    .tint(themeColors.accent)
                    .padding(.horizontal)

                Spacer()

                // Current priority badge
                priorityBadge(for: task)
                    .scaleEffect(1.5)

                // Task title - tappable for details
                Button {
                    taskToView = task
                    showTaskDetail = true
                } label: {
                    VStack(spacing: 8) {
                        Text(task.title ?? "Untitled")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(themeColors.text)
                            .multilineTextAlignment(.center)

                        // Show notes preview if available
                        if let notes = task.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(themeColors.subtext)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }

                        // Tap hint
                        Text("Tap for details")
                            .font(.caption2)
                            .foregroundStyle(themeColors.subtext.opacity(0.6))
                    }
                    .padding(.horizontal)
                }

                // Due date if any
                if let dueDate = task.dueDateComponents?.date {
                    Text(dueDate, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(dueDate < Date() ? .red : themeColors.subtext)
                }

                // Priority confirmation overlay
                if showPriorityConfirmation {
                    let colors: [Color] = [.gray, .red, .orange, .yellow, .blue]
                    let labels = ["", "URGENT", "IMPORTANT", "LATER", "TOMORROW"]
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Priority \(confirmationPriority): \(labels[confirmationPriority])")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(colors[confirmationPriority])
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                    .transition(.scale.combined(with: .opacity))
                }

                // Voice status
                if isListeningForResponse {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse)
                        Text(speechService.transcribedText.isEmpty ? "Listening..." : speechService.transcribedText)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.themeSecondary)
                    .cornerRadius(10)
                }

                Spacer()

                // Voice hint
                Text(isListeningForResponse ? "Listening..." : "Say priority 1-4, next, or push")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)

                // Voice button - larger in Simple mode
                Button {
                    toggleListeningForResponse()
                } label: {
                    Image(systemName: isListeningForResponse ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: appState.isSimpleMode ? 70 : 50))
                        .foregroundStyle(isListeningForResponse ? .red : themeColors.accent)
                        .symbolEffect(.pulse, isActive: isListeningForResponse)
                }
                .padding(.bottom, 16)

                // Priority buttons - show in BOTH Simple and Pro mode
                HStack(spacing: 12) {
                    priorityButton(1, "URGENT", .red, task)
                    priorityButton(2, "IMPORT", .orange, task)
                    priorityButton(3, "LATER", .yellow, task)
                    priorityButton(4, "TMRW", .blue, task)
                }
                .padding(.horizontal)

                // Navigation buttons - show in BOTH Simple and Pro mode
                HStack(spacing: 12) {
                    // Done button - marks task complete and moves on
                    Button {
                        markReminderComplete(task)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Done")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                    }

                    // Next/Skip button
                    Button {
                        moveToNextTask()
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeColors.accent)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Pro mode only - Scheduling buttons, extra navigation
                if !appState.isSimpleMode {

                    // Scheduling quick buttons
                    HStack(spacing: 12) {
                        Button {
                            showTaskSchedulePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("Schedule")
                            }
                            .font(.caption)
                            .foregroundStyle(themeColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.themeSecondary)
                            .cornerRadius(8)
                        }

                        Button {
                            scheduleTaskIn(minutes: 30, task: task)
                        } label: {
                            Text("In 30 min")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.themeSecondary)
                                .cornerRadius(8)
                        }

                        Button {
                            scheduleTaskIn(minutes: 60, task: task)
                        } label: {
                            Text("In 1 hour")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.themeSecondary)
                                .cornerRadius(8)
                        }
                    }

                    // Navigation buttons
                    HStack(spacing: 16) {
                        Button {
                            pushTask(task)
                            moveToNextTask()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right")
                                Text("Push")
                            }
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }

                        Button {
                            moveToNextTask()
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeColors.accent)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer().frame(height: 16)
            }
            .sheet(isPresented: $showTaskSchedulePicker) {
                TaskSchedulePickerSheet(
                    task: task,
                    calendarService: calendarService,
                    onSchedule: { time in
                        scheduleTaskAt(time, task: task)
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showTaskDetail) {
                if let task = taskToView {
                    TaskDetailSheet(
                        task: task,
                        calendarService: calendarService,
                        onUpdate: {
                            Task {
                                reminders = await calendarService.fetchReminders(includeCompleted: false)
                            }
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }

        private func priorityButton(_ number: Int, _ label: String, _ color: Color, _ task: EKReminder) -> some View {
            Button {
                setPriority(number, for: task)
            } label: {
                VStack(spacing: 2) {
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 60, height: 50)
                .background(color)
                .cornerRadius(8)
            }
        }

        private func startWalkThrough() {
            currentTaskIndex = 0
            isWalkingThrough = true
            speakCurrentTask()
        }

        private func speakCurrentTask() {
            guard let task = currentTask else { return }
            let (num, _, label) = priorityInfo(for: task)
            SpeechService.shared.queueSpeech("\(task.title ?? "Task"). Priority \(num), \(label). Change priority or say next.")
        }

        private func moveToNextTask() {
            // Light haptic for progress
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            if currentTaskIndex < reminders.count - 1 {
                currentTaskIndex += 1
                speakCurrentTask()

                // In Simple mode, auto-start listening for next task
                if appState.isSimpleMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if !isListeningForResponse && isWalkingThrough {
                            startListeningForResponse()
                        }
                    }
                }
            } else {
                // Celebration for finishing!
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                // Transition to add-new flow
                isWalkingThrough = false
                isAskingToAddNew = true
                SpeechService.shared.queueSpeech("Great job reviewing your tasks! Anything else you need to add?")

                // In Simple mode, auto-start listening for new task input
                if appState.isSimpleMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        if !isListeningForNewTask {
                            startListeningForNewTask()
                        }
                    }
                }
            }
        }

        private func markReminderComplete(_ reminder: EKReminder) {
            Task {
                do {
                    // Mark the reminder as complete
                    try await calendarService.completeReminder(reminder)

                    // Celebrate!
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    let celebrations = ["Done!", "Nice work!", "Checked off!", "Completed!", "Great job!"]
                    SpeechService.shared.queueSpeech(celebrations.randomElement()!)

                    // Refresh the list
                    reminders = await calendarService.fetchReminders(includeCompleted: false)

                    // Move to next or finish
                    if currentTaskIndex < reminders.count {
                        speakCurrentTask()
                    } else if reminders.isEmpty {
                        isWalkingThrough = false
                        SpeechService.shared.queueSpeech("All tasks complete! You're crushing it!")
                    } else {
                        currentTaskIndex = max(0, currentTaskIndex - 1)
                        speakCurrentTask()
                    }
                } catch {
                    print("Error completing reminder: \(error)")
                }
            }
        }

        // MARK: - Scheduling Methods

        private func scheduleTaskIn(minutes: Int, task: EKReminder) {
            let scheduleTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
            scheduleTaskAt(scheduleTime, task: task)
        }

        private func scheduleTaskAt(_ time: Date, task: EKReminder) {
            Task {
                do {
                    // Use calendarService's updateReminder method
                    try await calendarService.updateReminder(
                        task,
                        title: task.title ?? "",
                        notes: task.notes,
                        dueDate: time,
                        priority: task.priority
                    )

                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    let timeString = formatter.string(from: time)

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    SpeechService.shared.queueSpeech("Scheduled for \(timeString)")

                    // Refresh the list
                    reminders = await calendarService.fetchReminders(includeCompleted: false)
                } catch {
                    print("Error scheduling task: \(error)")
                }
            }
        }

        private func toggleListeningForResponse() {
            if isListeningForResponse {
                stopListeningForResponse()
            } else {
                startListeningForResponse()
            }
        }

        private func startListeningForResponse() {
            do {
                try speechService.startListening()
                isListeningForResponse = true

                // Auto-stop after 15 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if isListeningForResponse {
                        stopListeningForResponse()
                    }
                }
            } catch {
                print("Failed to listen: \(error)")
            }
        }

        private func stopListeningForResponse() {
            speechService.stopListening()
            isListeningForResponse = false

            let text = speechService.transcribedText.lowercased()
            guard !text.isEmpty, let task = currentTask else { return }

            // Check for priority numbers
            if text.contains("1") || text.contains("one") || text.contains("urgent") {
                setPriority(1, for: task)
            } else if text.contains("2") || text.contains("two") || text.contains("important") {
                setPriority(2, for: task)
            } else if text.contains("3") || text.contains("three") || text.contains("later") {
                setPriority(3, for: task)
            } else if text.contains("4") || text.contains("four") || text.contains("tomorrow") {
                setPriority(4, for: task)
            } else if text.contains("next") || text.contains("skip") {
                moveToNextTask()
            } else if text.contains("push") || text.contains("delay") {
                pushTask(task)
                moveToNextTask()
            } else if text.contains("delete") || text.contains("remove") {
                deleteTask(task)
                Task {
                    reminders = await calendarService.fetchReminders(includeCompleted: false)
                    if currentTaskIndex >= reminders.count {
                        currentTaskIndex = max(0, reminders.count - 1)
                    }
                    if reminders.isEmpty {
                        isWalkingThrough = false
                    } else {
                        speakCurrentTask()
                    }
                }
            } else {
                SpeechService.shared.queueSpeech("Say a number 1 to 4, or next, push, or delete.")
            }
        }

        private func setPriority(_ priority: Int, for task: EKReminder) {
            let ekPriority: Int
            switch priority {
            case 1: ekPriority = 1
            case 2: ekPriority = 4
            case 3: ekPriority = 5
            case 4: ekPriority = 8
            default: ekPriority = 5
            }

            // Haptic confirmation - double tap for satisfaction
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.impactOccurred()
            }

            // Visual confirmation
            confirmationPriority = priority
            withAnimation(.spring(response: 0.3)) {
                showPriorityConfirmation = true
            }

            // Hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showPriorityConfirmation = false
                }
            }

            Task {
                try? await calendarService.updateReminder(
                    task,
                    title: task.title ?? "",
                    notes: task.notes,
                    dueDate: task.dueDateComponents?.date,
                    priority: ekPriority
                )
                reminders = await calendarService.fetchReminders(includeCompleted: false)

                // Celebratory messages per priority
                let celebrations: [[String]] = [
                    [], // 0 - unused
                    ["Locked in! Urgent - get it done!", "Top priority! You've got this!", "Urgent mode activated!"],
                    ["Nice! Important - it's on your radar.", "Good choice! Important stuff first.", "Important - you're prioritizing well!"],
                    ["Smart! Later is fine.", "No rush - it can wait.", "Later works! Good planning."],
                    ["Tomorrow it is! Focus on today.", "Pushed - that's smart scheduling.", "Tomorrow! One less thing now."]
                ]
                let message = celebrations[priority].randomElement() ?? "Got it!"
                SpeechService.shared.queueSpeech(message)
            }
        }

        private func startAddingNew() {
            if isListening {
                stopListeningAndProcess()
            } else {
                // Speak prompt FIRST, then start listening after speech finishes
                Task {
                    do {
                        // Speak the prompt
                        let apiKey = KeychainService.load(key: "elevenlabs_api_key") ?? ""
                        let voiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""
                        if !apiKey.isEmpty {
                            let service = ElevenLabsService()
                            try await service.speakWithBestVoice("What task do you want to add?", apiKey: apiKey, selectedVoiceId: voiceId)
                        }

                        // Now start listening
                        await MainActor.run {
                            do {
                                try speechService.startListening()
                                isListening = true
                            } catch {
                                print("Failed to start listening: \(error)")
                            }
                        }
                    } catch {
                        print("Failed to speak prompt: \(error)")
                    }
                }
            }
        }

        private func stopListeningAndProcess() {
            speechService.stopListening()
            isListening = false

            let text = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            Task {
                do {
                    let result = try await openAIService.processUserInput(text, apiKey: appState.claudeKey, personality: appState.selectedPersonality)
                    if !result.tasks.isEmpty {
                        let _ = try await calendarService.saveAllItems(from: result)
                        reminders = await calendarService.fetchReminders(includeCompleted: false)

                        // Find the newly added task to prompt for priority
                        if let taskTitle = result.tasks.first?.title {
                            // Find the reminder that matches
                            if let newReminder = reminders.first(where: { $0.title?.lowercased() == taskTitle.lowercased() }) {
                                newlyAddedReminder = newReminder
                                // Small delay then show priority picker
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showNewTaskPriorityPicker = true
                                }
                            } else {
                                SpeechService.shared.queueSpeech(result.summary ?? "Task added!")
                            }
                        } else {
                            SpeechService.shared.queueSpeech(result.summary ?? "Task added!")
                        }
                    } else {
                        SpeechService.shared.queueSpeech("I didn't catch a task. Try again?")
                    }
                } catch {
                    SpeechService.shared.queueSpeech("Sorry, something went wrong.")
                }
            }
        }

        private func taskRow(_ reminder: EKReminder) -> some View {
            HStack(spacing: 12) {
                // Priority indicator (tap to open picker)
                Button {
                    selectedReminder = reminder
                    showPriorityPicker = true
                    // Speak current priority
                    let (num, _, label) = priorityInfo(for: reminder)
                    SpeechService.shared.queueSpeech("Current priority is \(num), \(label). Say a number 1 to 4, or tap to change.")
                } label: {
                    priorityBadge(for: reminder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title ?? "Untitled")
                        .font(.body)
                        .foregroundStyle(themeColors.text)

                    if let dueDate = reminder.dueDateComponents?.date {
                        Text(dueDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(dueDate < Date() ? .red : themeColors.subtext)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    // Push to later/tomorrow
                    Button {
                        pushTask(reminder)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    // Delete
                    Button {
                        deleteTask(reminder)
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(10)
        }

        private func priorityBadge(for reminder: EKReminder) -> some View {
            let (number, color, label) = priorityInfo(for: reminder)
            return VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 44, height: 44)
            .background(color)
            .cornerRadius(8)
        }

        private func priorityInfo(for reminder: EKReminder) -> (Int, Color, String) {
            // Map EKReminder priority (1-9) to our 1-4 scale
            // EKReminder: 1-4 = high, 5 = medium, 6-9 = low, 0 = none
            switch reminder.priority {
            case 1...2:
                return (1, .red, "URGENT")
            case 3...4:
                return (2, .orange, "IMPORT")
            case 5...6:
                return (3, .yellow, "LATER")
            case 7...9:
                return (4, .blue, "TMRW")
            default:
                return (3, .gray, "NONE")
            }
        }

        private func cyclePriority(_ reminder: EKReminder) {
            // Cycle through priorities: 1 (urgent) -> 2 (important) -> 3 (later) -> 4 (tomorrow) -> 1
            let newPriority: Int
            switch reminder.priority {
            case 1...2:
                newPriority = 4  // Move to Important
            case 3...4:
                newPriority = 5  // Move to Later
            case 5...6:
                newPriority = 8  // Move to Tomorrow
            default:
                newPriority = 1  // Move to Urgent
            }

            Task {
                reminder.priority = newPriority
                try? await calendarService.updateReminder(
                    reminder,
                    title: reminder.title ?? "",
                    notes: reminder.notes,
                    dueDate: reminder.dueDateComponents?.date,
                    priority: newPriority
                )
                reminders = await calendarService.fetchReminders(includeCompleted: false)

                let (num, _, label) = priorityInfo(for: reminder)
                SpeechService.shared.queueSpeech("Priority \(num): \(label)")
            }
        }

        private func pushTask(_ reminder: EKReminder) {
            // Haptic celebration
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            Task {
                // Push to tomorrow at 9am
                try? await calendarService.pushToTomorrow(reminder)
                reminders = await calendarService.fetchReminders(includeCompleted: false)

                // Encouraging messages
                let celebrations = [
                    "Smart move! Pushed to tomorrow.",
                    "Good call! That can wait.",
                    "Tomorrow it is! One less thing today.",
                    "Nice! Giving yourself space.",
                    "Pushed! You're managing your load well."
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)
            }
        }

        private func deleteTask(_ reminder: EKReminder) {
            // Haptic celebration
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            Task {
                try? await calendarService.deleteReminder(reminder)
                reminders = await calendarService.fetchReminders(includeCompleted: false)

                // Satisfying delete messages
                let celebrations = [
                    "Gone! Feels good right?",
                    "Deleted! Less clutter, more clarity.",
                    "Bye bye! That's off your plate.",
                    "Poof! One less thing to think about.",
                    "Cleared! Your list is lighter."
                ]
                SpeechService.shared.queueSpeech(celebrations.randomElement()!)
            }
        }

        private func speakTasksSummary() {
            let incomplete = reminders.filter { !$0.isCompleted }
            if incomplete.isEmpty {
                SpeechService.shared.queueSpeech("You have no pending tasks. Nice work!")
            } else if incomplete.count == 1 {
                SpeechService.shared.queueSpeech("You have one task: \(incomplete[0].title ?? "something to do").")
            } else if incomplete.count <= 3 {
                SpeechService.shared.queueSpeech("You have \(incomplete.count) tasks. Here they are:")
                for (index, task) in incomplete.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1) * 2) {
                        SpeechService.shared.queueSpeech(task.title ?? "A task")
                    }
                }
            } else {
                SpeechService.shared.queueSpeech("You have \(incomplete.count) tasks today. The top ones are \(incomplete[0].title ?? "task 1") and \(incomplete[1].title ?? "task 2").")
            }
        }

        // MARK: - Add New Task View (post walk-through)

        private var addNewTaskView: some View {
            VStack(spacing: 24) {
                Spacer()

                // Prompt
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeColors.accent)

                    Text("Anything else to add?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)

                    Text("Say what you need to do, or tap Done if you're all set")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Processing indicator
                if isProcessingNewTask {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(themeColors.accent)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                    .padding()
                }

                // Voice input status
                if isListeningForNewTask {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse)
                        Text(speechService.transcribedText.isEmpty ? "Listening..." : speechService.transcribedText)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.themeSecondary)
                    .cornerRadius(10)
                }

                Spacer()

                // Voice button - big and centered
                Button {
                    toggleListeningForNewTask()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: isListeningForNewTask ? "mic.fill" : "mic")
                            .font(.system(size: 48))
                            .foregroundStyle(isListeningForNewTask ? .red : themeColors.accent)
                            .symbolEffect(.pulse, isActive: isListeningForNewTask)
                        Text(isListeningForNewTask ? "Listening..." : "Tap to speak")
                            .font(.headline)
                            .foregroundStyle(isListeningForNewTask ? .red : themeColors.subtext)
                    }
                    .frame(width: 140, height: 120)
                    .background(Color.themeSecondary)
                    .cornerRadius(20)
                }

                // Done button
                Button {
                    finishTasksReview()
                } label: {
                    Text("All Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }

        private func toggleListeningForNewTask() {
            if isListeningForNewTask {
                stopListeningForNewTask()
            } else {
                startListeningForNewTask()
            }
        }

        private func startListeningForNewTask() {
            do {
                try speechService.startListening()
                isListeningForNewTask = true

                // Auto-stop after 15 seconds (give user time to speak)
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if isListeningForNewTask {
                        stopListeningForNewTask()
                    }
                }
            } catch {
                print("Failed to start listening: \(error)")
            }
        }

        private func stopListeningForNewTask() {
            speechService.stopListening()
            isListeningForNewTask = false

            let text = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            newTaskText = text
            isProcessingNewTask = true

            Task {
                do {
                    let result = try await openAIService.processUserInput(text, apiKey: appState.claudeKey, personality: appState.selectedPersonality)
                    if !result.tasks.isEmpty {
                        let _ = try await calendarService.saveAllItems(from: result)
                        reminders = await calendarService.fetchReminders(includeCompleted: false)

                        // Find the newly added task to prompt for priority
                        if let taskTitle = result.tasks.first?.title {
                            if let newReminder = reminders.first(where: { $0.title?.lowercased() == taskTitle.lowercased() }) {
                                newlyAddedReminder = newReminder
                                isProcessingNewTask = false
                                showNewTaskPriorityPicker = true
                            } else {
                                isProcessingNewTask = false
                                SpeechService.shared.queueSpeech(result.summary ?? "Task added! Anything else?")
                            }
                        } else {
                            isProcessingNewTask = false
                            SpeechService.shared.queueSpeech(result.summary ?? "Task added! Anything else?")
                        }
                    } else {
                        isProcessingNewTask = false
                        SpeechService.shared.queueSpeech("I didn't catch a task. Try again, or tap Done.")
                    }
                } catch {
                    isProcessingNewTask = false
                    SpeechService.shared.queueSpeech("Sorry, something went wrong.")
                }
            }
        }

        private func finishTasksReview() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            SpeechService.shared.queueSpeech("Great! Your tasks are all set.")
            dismiss()
        }
    }

    // MARK: - Task Schedule Picker Sheet

    struct TaskSchedulePickerSheet: View {
        let task: EKReminder
        let calendarService: CalendarService
        let onSchedule: (Date) -> Void

        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss
        @State private var selectedTime = Date()

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text(task.title ?? "Task")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)
                        .padding(.top)

                    // Quick time buttons
                    HStack(spacing: 12) {
                        quickTimeButton("9 AM", hour: 9)
                        quickTimeButton("12 PM", hour: 12)
                        quickTimeButton("3 PM", hour: 15)
                        quickTimeButton("6 PM", hour: 18)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Date/Time picker
                    DatePicker(
                        "Schedule for",
                        selection: $selectedTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                    // Schedule button
                    Button {
                        onSchedule(selectedTime)
                        dismiss()
                    } label: {
                        Text("Schedule")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeColors.accent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .navigationTitle("Schedule Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }

        private func quickTimeButton(_ label: String, hour: Int) -> some View {
            Button {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = hour
                components.minute = 0
                if let time = Calendar.current.date(from: components) {
                    // If the time is in the past, use tomorrow
                    if time < Date() {
                        selectedTime = Calendar.current.date(byAdding: .day, value: 1, to: time) ?? time
                    } else {
                        selectedTime = time
                    }
                }
            } label: {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(themeColors.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.themeSecondary)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Task Detail Sheet

    struct TaskDetailSheet: View {
        let task: EKReminder
        let calendarService: CalendarService
        let onUpdate: () -> Void

        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss
        @State private var editedTitle: String = ""
        @State private var editedNotes: String = ""
        @State private var editedDueDate: Date = Date()
        @State private var hasDueDate = false
        @State private var isEditing = false

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)

                            if isEditing {
                                TextField("Task title", text: $editedTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(task.title ?? "Untitled")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(themeColors.text)
                            }
                        }
                        .padding(.horizontal)

                        // Notes section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)

                            if isEditing {
                                TextEditor(text: $editedNotes)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color.themeSecondary)
                                    .cornerRadius(8)
                            } else if let notes = task.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.body)
                                    .foregroundStyle(themeColors.text)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.themeSecondary)
                                    .cornerRadius(8)
                            } else {
                                Text("No notes")
                                    .font(.body)
                                    .foregroundStyle(themeColors.subtext)
                                    .italic()
                            }
                        }
                        .padding(.horizontal)

                        // Due date section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)

                            if isEditing {
                                Toggle("Has due date", isOn: $hasDueDate)
                                if hasDueDate {
                                    DatePicker("Due", selection: $editedDueDate, displayedComponents: [.date, .hourAndMinute])
                                }
                            } else if let dueDate = task.dueDateComponents?.date {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(dueDate < Date() ? .red : themeColors.accent)
                                    Text(dueDate, style: .date)
                                    Text("at")
                                        .foregroundStyle(themeColors.subtext)
                                    Text(dueDate, style: .time)
                                }
                                .font(.body)
                                .foregroundStyle(dueDate < Date() ? .red : themeColors.text)
                            } else {
                                Text("No due date")
                                    .font(.body)
                                    .foregroundStyle(themeColors.subtext)
                                    .italic()
                            }
                        }
                        .padding(.horizontal)

                        // Priority section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priority")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)

                            let (num, color, label) = priorityInfo(for: task)
                            HStack {
                                Text("\(num)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(color)
                                    .cornerRadius(6)
                                Text(label)
                                    .font(.body)
                                    .foregroundStyle(themeColors.text)
                            }
                        }
                        .padding(.horizontal)

                        // Calendar info
                        if let calendar = task.calendar {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("List")
                                    .font(.caption)
                                    .foregroundStyle(themeColors.subtext)

                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 12, height: 12)
                                    Text(calendar.title)
                                        .font(.body)
                                        .foregroundStyle(themeColors.text)
                                }
                            }
                            .padding(.horizontal)
                        }

                        Spacer()
                    }
                    .padding(.top)
                }
                .navigationTitle("Task Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if isEditing {
                            Button("Save") {
                                saveChanges()
                            }
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                        }
                    }
                }
            }
            .onAppear {
                editedTitle = task.title ?? ""
                editedNotes = task.notes ?? ""
                if let dueDate = task.dueDateComponents?.date {
                    editedDueDate = dueDate
                    hasDueDate = true
                }
            }
        }

        private func priorityInfo(for reminder: EKReminder) -> (Int, Color, String) {
            switch reminder.priority {
            case 1...2: return (1, .red, "URGENT")
            case 3...4: return (2, .orange, "IMPORTANT")
            case 5...6: return (3, .yellow, "LATER")
            case 7...9: return (4, .blue, "TOMORROW")
            default: return (3, .gray, "NONE")
            }
        }

        private func startEditing() {
            editedTitle = task.title ?? ""
            editedNotes = task.notes ?? ""
            isEditing = true
        }

        private func saveChanges() {
            Task {
                do {
                    try await calendarService.updateReminder(
                        task,
                        title: editedTitle,
                        notes: editedNotes.isEmpty ? nil : editedNotes,
                        dueDate: hasDueDate ? editedDueDate : nil,
                        priority: task.priority
                    )
                    onUpdate()
                    await MainActor.run {
                        isEditing = false
                    }
                } catch {
                    print("Error saving task: \(error)")
                }
            }
        }
    }

    // MARK: - New Task Priority Sheet

    struct NewTaskPrioritySheet: View {
        let reminder: EKReminder
        let calendarService: CalendarService
        let speechService: SpeechService
        let onUpdate: () -> Void

        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss
        @State private var isListening = false
        @State private var showConfirmation = false
        @State private var selectedPriority = 0
        @State private var confirmationMessage = ""

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    // Success header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                        Text("Task Added!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(themeColors.text)
                    }
                    .padding(.top)

                    // Task name
                    Text(reminder.title ?? "New Task")
                        .font(.headline)
                        .foregroundStyle(themeColors.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Confirmation overlay
                    if showConfirmation {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                            Text(confirmationMessage)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColors.text)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Priority prompt
                        Text("What priority is this?")
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)

                        // Priority options - horizontal for quick selection
                        HStack(spacing: 12) {
                            priorityButton(1, "1", "URGENT", .red)
                            priorityButton(2, "2", "IMPORT", .orange)
                            priorityButton(3, "3", "LATER", .yellow)
                            priorityButton(4, "4", "TMRW", .blue)
                        }
                        .padding(.horizontal)

                        // Voice button
                        Button {
                            toggleListening()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isListening ? "waveform" : "mic")
                                    .symbolEffect(.pulse, isActive: isListening)
                                Text(isListening ? "Say 1, 2, 3, or 4..." : "Or say priority")
                            }
                            .font(.headline)
                            .foregroundStyle(isListening ? .red : themeColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Skip option
                        Button {
                            SpeechService.shared.queueSpeech("Okay, keeping default priority.")
                            dismiss()
                        } label: {
                            Text("Skip - use default")
                                .font(.subheadline)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }

                    Spacer()
                }
                .navigationTitle("Set Priority")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .onAppear {
                SpeechService.shared.queueSpeech("Task added! What priority? Say 1 for urgent, 2 for important, 3 for later, or 4 for tomorrow.")
            }
        }

        private func priorityButton(_ number: Int, _ numText: String, _ label: String, _ color: Color) -> some View {
            Button {
                setPriority(number)
            } label: {
                VStack(spacing: 4) {
                    Text(numText)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 70, height: 70)
                .background(color)
                .cornerRadius(12)
            }
        }

        private func setPriority(_ priority: Int) {
            let ekPriority: Int
            let labels = ["", "Urgent", "Important", "Later", "Tomorrow"]

            switch priority {
            case 1: ekPriority = 1
            case 2: ekPriority = 4
            case 3: ekPriority = 5
            case 4: ekPriority = 8
            default: ekPriority = 5
            }

            selectedPriority = priority
            confirmationMessage = "Priority \(priority): \(labels[priority])"

            // Double haptic for extra satisfaction
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.impactOccurred()
            }

            // Visual confirmation
            withAnimation(.spring(response: 0.3)) {
                showConfirmation = true
            }

            // Celebratory voice confirmation
            let celebrations: [[String]] = [
                [], // 0 - unused
                ["Boom! Urgent - let's do this!", "Urgent locked in! You've got this!", "Priority 1 - game on!"],
                ["Nice choice! Important - it's on the list.", "Important - you're prioritizing like a pro!", "Good one! Important it is."],
                ["Smart! Later works fine.", "Later - no rush, no stress.", "Good call! Later is perfect."],
                ["Tomorrow it is! Focus on today.", "Pushed! That's smart planning.", "Tomorrow - you're managing your load well!"]
            ]
            let message = celebrations[priority].randomElement() ?? "Got it!"
            SpeechService.shared.queueSpeech(message)

            // Save and dismiss
            Task {
                try? await calendarService.updateReminder(
                    reminder,
                    title: reminder.title ?? "",
                    notes: reminder.notes,
                    dueDate: reminder.dueDateComponents?.date,
                    priority: ekPriority
                )
                onUpdate()

                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 sec
                dismiss()
            }
        }

        private func toggleListening() {
            if isListening {
                stopListeningAndProcess()
            } else {
                startListening()
            }
        }

        private func startListening() {
            do {
                try speechService.startListening()
                isListening = true

                // Auto-stop after 15 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if isListening {
                        stopListeningAndProcess()
                    }
                }
            } catch {
                print("Failed to listen: \(error)")
            }
        }

        private func stopListeningAndProcess() {
            speechService.stopListening()
            isListening = false

            let text = speechService.transcribedText.lowercased()
            guard !text.isEmpty else { return }

            if text.contains("1") || text.contains("one") || text.contains("urgent") {
                setPriority(1)
            } else if text.contains("2") || text.contains("two") || text.contains("important") {
                setPriority(2)
            } else if text.contains("3") || text.contains("three") || text.contains("later") {
                setPriority(3)
            } else if text.contains("4") || text.contains("four") || text.contains("tomorrow") {
                setPriority(4)
            } else if text.contains("skip") || text.contains("default") {
                SpeechService.shared.queueSpeech("Okay, keeping default priority.")
                dismiss()
            } else {
                SpeechService.shared.queueSpeech("Say 1, 2, 3, or 4.")
            }
        }
    }

    // MARK: - Priority Picker Sheet

    struct PriorityPickerSheet: View {
        let reminder: EKReminder
        let calendarService: CalendarService
        let speechService: SpeechService
        let onUpdate: () -> Void

        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss
        @State private var isListening = false
        @State private var showConfirmation = false
        @State private var selectedPriority = 0
        @State private var confirmationMessage = ""

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    // Current task
                    Text(reminder.title ?? "Task")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top)

                    // Confirmation overlay
                    if showConfirmation {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            Text(confirmationMessage)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColors.text)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Priority options
                        VStack(spacing: 12) {
                            priorityOption(1, "URGENT", "Do it now - this can't wait", .red)
                            priorityOption(2, "IMPORTANT", "Do today - make time for this", .orange)
                            priorityOption(3, "LATER", "Can wait - but don't forget", .yellow)
                            priorityOption(4, "TOMORROW", "Push it - handle another day", .blue)
                        }
                        .padding(.horizontal)

                        // Voice button
                        Button {
                            toggleListening()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isListening ? "waveform" : "mic")
                                    .symbolEffect(.pulse, isActive: isListening)
                                Text(isListening ? "Say 1, 2, 3, or 4..." : "Or say priority")
                            }
                            .font(.headline)
                            .foregroundStyle(isListening ? .red : themeColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.themeSecondary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .navigationTitle("Set Priority")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                let (num, _, label) = currentPriorityInfo()
                SpeechService.shared.queueSpeech("Current priority is \(num), \(label). Pick a new priority or say a number.")
            }
        }

        private func priorityOption(_ number: Int, _ title: String, _ description: String, _ color: Color) -> some View {
            Button {
                setPriority(number)
            } label: {
                HStack(spacing: 12) {
                    // Number badge
                    Text("\(number)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(color)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(themeColors.text)
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }

                    Spacer()

                    // Checkmark if current
                    if isCurrentPriority(number) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(color)
                    }
                }
                .padding()
                .background(Color.themeSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentPriority(number) ? color : Color.clear, lineWidth: 2)
                )
            }
        }

        private func isCurrentPriority(_ number: Int) -> Bool {
            let (current, _, _) = currentPriorityInfo()
            return current == number
        }

        private func currentPriorityInfo() -> (Int, Color, String) {
            switch reminder.priority {
            case 1...2: return (1, .red, "Urgent")
            case 3...4: return (2, .orange, "Important")
            case 5...6: return (3, .yellow, "Later")
            case 7...9: return (4, .blue, "Tomorrow")
            default: return (3, .gray, "None")
            }
        }

        private func setPriority(_ priority: Int) {
            let ekPriority: Int
            let labels = ["", "Urgent", "Important", "Later", "Tomorrow"]

            switch priority {
            case 1: ekPriority = 1
            case 2: ekPriority = 4
            case 3: ekPriority = 5
            case 4: ekPriority = 8
            default: ekPriority = 5
            }

            selectedPriority = priority
            confirmationMessage = "Priority \(priority): \(labels[priority])"

            // Double haptic for satisfaction
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.impactOccurred()
            }

            // Visual confirmation
            withAnimation(.spring(response: 0.3)) {
                showConfirmation = true
            }

            // Celebratory voice confirmation
            let celebrations: [[String]] = [
                [], // 0 - unused
                ["Urgent! Let's knock this out!", "Priority 1 - you're on it!", "Urgent mode - no messing around!"],
                ["Important - that's solid prioritizing!", "Nice! Important - on your radar.", "Good choice! Important locked in."],
                ["Later it is! No rush.", "Smart - later works perfectly.", "Later - giving yourself space!"],
                ["Tomorrow! Focus on today's wins.", "Pushed - excellent planning!", "Tomorrow - that's smart scheduling!"]
            ]
            let message = celebrations[priority].randomElement() ?? "Got it!"
            SpeechService.shared.queueSpeech(message)

            // Save and dismiss after brief delay
            Task {
                try? await calendarService.updateReminder(
                    reminder,
                    title: reminder.title ?? "",
                    notes: reminder.notes,
                    dueDate: reminder.dueDateComponents?.date,
                    priority: ekPriority
                )
                onUpdate()

                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 sec
                dismiss()
            }
        }

        private func toggleListening() {
            if isListening {
                stopListeningAndProcess()
            } else {
                startListening()
            }
        }

        private func startListening() {
            do {
                try speechService.startListening()
                isListening = true

                // Auto-stop after 15 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if isListening {
                        stopListeningAndProcess()
                    }
                }
            } catch {
                print("Failed to listen: \(error)")
            }
        }

        private func stopListeningAndProcess() {
            speechService.stopListening()
            isListening = false

            let text = speechService.transcribedText.lowercased()
            guard !text.isEmpty else { return }

            if text.contains("1") || text.contains("one") || text.contains("urgent") {
                setPriority(1)
            } else if text.contains("2") || text.contains("two") || text.contains("important") {
                setPriority(2)
            } else if text.contains("3") || text.contains("three") || text.contains("later") {
                setPriority(3)
            } else if text.contains("4") || text.contains("four") || text.contains("tomorrow") {
                setPriority(4)
            } else {
                SpeechService.shared.queueSpeech("Say 1, 2, 3, or 4 to set priority.")
            }
        }
    }

    // MARK: - Goals Review Sheet

    struct GoalsReviewSheet: View {
        @ObservedObject private var goalsService = GoalsService.shared
        @ObservedObject private var themeColors = ThemeColors.shared
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    if goalsService.activeGoals.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 50))
                                .foregroundStyle(themeColors.accent)
                            Text("No active goals")
                                .font(.title3)
                                .foregroundStyle(themeColors.text)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(goalsService.activeGoals) { goal in
                                    goalCard(goal)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Your Goals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .onAppear {
                speakGoalsSummary()
            }
        }

        private func goalCard(_ goal: Goal) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(themeColors.text)

                ProgressView(value: goal.progressPercentage, total: 100)
                    .tint(themeColors.accent)

                Text("\(Int(goal.progressPercentage))% complete")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }

        private func speakGoalsSummary() {
            let goals = goalsService.activeGoals
            if goals.isEmpty {
                SpeechService.shared.queueSpeech("You don't have any active goals right now.")
            } else if goals.count == 1 {
                let goal = goals[0]
                SpeechService.shared.queueSpeech("Your goal is \(goal.title). You're \(Int(goal.progressPercentage)) percent there!")
            } else {
                SpeechService.shared.queueSpeech("You have \(goals.count) active goals. Keep pushing!")
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Personality indicator with change button
            VStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 80))

                // Who's talking - clear and prominent
                HStack(spacing: 8) {
                    Text("I'm")
                        .font(.title3)
                        .foregroundStyle(themeColors.subtext)
                    Text(appState.selectedPersonality.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.accent)
                }

                // Change personality button - easy access
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("Not me? Change")
                            .font(.subheadline)
                    }
                    .foregroundStyle(themeColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeColors.accent.opacity(0.15))
                    .cornerRadius(20)
                }
            }

            // Greeting
            Text(getGreetingText())
                .font(.title3)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Check count - simple, not overwhelming
            VStack(spacing: 8) {
                Text("\(activeChecks.count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(themeColors.accent)
                Text("quick checks")
                    .font(.title3)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(16)

            Spacer()

            // Start button - BIG and inviting
            Button {
                startChecklist()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Let's Go!")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.themeAccent)
                .cornerRadius(16)
            }
            .padding(.horizontal)

            // Skip option
            Button {
                onSkip()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding(.bottom, 24)
        }
    }

    private func getGreetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")

        switch appState.selectedPersonality {
        case .pemberton:
            return "Good \(timeOfDay). Shall we review your essentials?"
        case .sergent:
            return "Rise and shine! Morning briefing time!"
        case .cheerleader:
            return "Good \(timeOfDay) superstar! Ready to start amazing?"
        case .hypeFriend:
            return "GOOD \(timeOfDay.uppercased())! Let's CRUSH this routine!"
        case .chillBuddy:
            return "Hey... \(timeOfDay). Quick check-in time."
        case .tiredParent:
            return "\(timeOfDay.capitalized). Let's just get through these."
        default:
            return "Good \(timeOfDay)! Ready for your check-in?"
        }
    }

    // MARK: - State Persistence

    private func saveCurrentPosition(_ index: Int) {
        UserDefaults.standard.set(index, forKey: savedIndexKey)
        UserDefaults.standard.set(Date(), forKey: savedDateKey)
    }

    private func loadSavedPosition() {
        // Only restore if saved today
        guard let savedDate = UserDefaults.standard.object(forKey: savedDateKey) as? Date,
              Calendar.current.isDateInToday(savedDate) else {
            // Clear old data and start fresh
            clearSavedPosition()
            return
        }

        let savedIndex = UserDefaults.standard.integer(forKey: savedIndexKey)

        // Make sure it's a valid index
        if savedIndex > 0 && savedIndex < activeChecks.count {
            currentIndex = savedIndex
            // If we were past intro, stay past intro
            showingIntro = false
            print("📍 Restored check-in position: \(savedIndex)")
        }
    }

    private func clearSavedPosition() {
        UserDefaults.standard.removeObject(forKey: savedIndexKey)
        UserDefaults.standard.removeObject(forKey: savedDateKey)
    }

    private func startChecklist() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3)) {
            showingIntro = false
        }

        // Speak first question after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            speakFirstQuestion()
        }
    }

    private func speakFirstQuestion() {
        guard let check = currentCheck else { return }
        let question = getQuestion(for: check)
        SpeechService.shared.queueSpeech("\(question) \(check.title)?")
    }

    // MARK: - Check View

    private func checkView(for check: MorningChecklistService.SelfCheck) -> some View {
        VStack(spacing: 24) {
            // Header with prominent personality/settings access
            VStack(spacing: 8) {
                HStack {
                    // Personality indicator - tap to change
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(appState.selectedPersonality.emoji)
                                .font(.title2)
                            Text(appState.selectedPersonality.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColors.text)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(themeColors.subtext)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeColors.accent.opacity(0.15))
                        .cornerRadius(20)
                    }

                    Spacer()

                    Text("\(currentIndex + 1) of \(activeChecks.count)")
                        .font(.caption)
                        .foregroundStyle(themeColors.accent)

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(themeColors.accent)
                    }
                    .padding(.leading, 12)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Show hint on first check only
                if currentIndex == 0 {
                    Text("Wrong voice? Tap above to change")
                        .font(.caption2)
                        .foregroundStyle(themeColors.subtext)
                }
            }

            // Progress bar
            ProgressView(value: Double(currentIndex), total: Double(activeChecks.count))
                .tint(Color.themeAccent)
                .padding(.horizontal)

            Spacer()

            // Bot asking
            VStack(spacing: 16) {
                Text(getQuestion(for: check))
                    .font(.title3)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // The check item - BIG and TAPPABLE
            Button {
                openRelevantView(for: check)
            } label: {
                HStack {
                    Text(check.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeColors.text)
                        .multilineTextAlignment(.center)

                    Spacer()

                    // Arrow to indicate it's tappable
                    Image(systemName: getIconForCheck(check))
                        .font(.title2)
                        .foregroundStyle(themeColors.accent)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.themeSecondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeColors.accent.opacity(0.3), lineWidth: 2)
                )
            }
            .padding(.horizontal)

            // Hint that it's tappable
            Text("Tap to open")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)

            // Voice listening indicator
            if isListening {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: true)
                    Text(speechService.transcribedText.isEmpty ? "Listening..." : speechService.transcribedText)
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Microphone button for voice response
            Button {
                toggleListening()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundStyle(isListening ? .red : themeColors.accent)
                        .symbolEffect(.pulse, isActive: isListening)
                    Text(isListening ? "Listening..." : "Tap to speak")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.themeSecondary)
                )
            }
            .padding(.bottom, 8)

            // Response buttons - BIG and easy
            VStack(spacing: 12) {
                // Done button
                Button {
                    markDone()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                        Text("Done")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.themeAccent)
                    .cornerRadius(14)
                }

                // Skip / Not today button
                Button {
                    skipCurrent()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themeSecondary)
                        .cornerRadius(10)
                }

                // Reset button - easy access
                Button {
                    showResetOptions = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset & Start Fresh")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    enum ResetType {
        case morning
        case calendar
        case tasks
        case clearNotifications
    }

    /// Reset and start from a specific point
    private func performReset(type: ResetType) {
        // Stop any speech
        SpeechService.shared.stopSpeaking()

        // Cancel all pending notifications
        NotificationService.shared.cancelAllNotifications()

        // Reset morning checklist state
        MorningChecklistService.shared.resetForTesting()

        // Clear saved position
        clearSavedPosition()

        // Reset view state
        currentIndex = 0
        showingIntro = false
        showingAllDone = false
        showActionOptions = false
        hasStartedSession = false

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Handle based on reset type
        switch type {
        case .morning:
            SpeechService.shared.queueSpeech("Starting morning check-in fresh.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasStartedSession = true
                if appState.isSimpleMode {
                    handleCurrentCheck()
                } else {
                    speakGreeting()
                }
            }

        case .calendar:
            SpeechService.shared.queueSpeech("Let's check your calendar.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showCalendar = true
            }

        case .tasks:
            SpeechService.shared.queueSpeech("Let's look at your tasks.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showTasks = true
            }

        case .clearNotifications:
            SpeechService.shared.queueSpeech("All notifications cleared.")
        }
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration
            Text("🎉")
                .font(.system(size: 80))

            Text("Morning check-in complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(themeColors.text)

            Text(getCelebrationMessage())
                .font(.body)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Summary
            VStack(spacing: 8) {
                Text("\(checklistService.completedCount) of \(activeChecks.count) items done")
                    .font(.headline)
                    .foregroundStyle(themeColors.accent)

                if checklistService.completedCount == activeChecks.count {
                    Text("Perfect start to the day!")
                        .font(.caption)
                        .foregroundStyle(themeColors.success)
                }
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)

            Spacer()

            // Done button
            Button {
                speakGoodbye()
                onComplete()
            } label: {
                Text("Let's go!")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - No Checks View

    private var noChecksView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 60))

            Text("No morning checks set up yet")
                .font(.title3)
                .foregroundStyle(themeColors.text)

            Text("Add some in Settings to build your morning routine")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                onSkip()
            } label: {
                Text("Got it")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Action Options View (Post-check)

    private func actionOptionsView(for check: MorningChecklistService.SelfCheck) -> some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("What's next?")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            // Completed badge
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)

                Text(check.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)

                Text("Done! Want to schedule or add a note?")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding()

            Spacer()

            // Voice for notes
            if isListeningForNote {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: true)
                    Text(speechService.transcribedText.isEmpty ? "Listening for note..." : speechService.transcribedText)
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }

            // Action buttons grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Schedule button
                Button {
                    showScheduleOptions()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title2)
                        Text("Schedule")
                            .font(.subheadline)
                    }
                    .foregroundStyle(themeColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // Add Note button
                Button {
                    toggleListeningForNote()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: isListeningForNote ? "waveform" : "note.text")
                            .font(.title2)
                            .symbolEffect(.pulse, isActive: isListeningForNote)
                        Text(isListeningForNote ? "Listening..." : "Add Note")
                            .font(.subheadline)
                    }
                    .foregroundStyle(isListeningForNote ? .red : .orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // Quick schedules
                Button {
                    scheduleIn(minutes: 30)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "30.circle")
                            .font(.title2)
                        Text("In 30 min")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }

                // In 1 hour
                Button {
                    scheduleIn(minutes: 60)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "1.circle")
                            .font(.title2)
                        Text("In 1 hour")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeSecondary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // Just continue button
            Button {
                proceedToNext()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle")
                    Text("Just continue")
                }
                .font(.headline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.themeSecondary)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions

    private func markDone() {
        guard let check = currentCheck else { return }

        checklistService.markCompleted(id: check.id)

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Speak acknowledgment
        speakAcknowledgment()

        // Show action options instead of moving on
        withAnimation(.spring(response: 0.3)) {
            showActionOptions = true
        }

        // Ask about scheduling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            SpeechService.shared.queueSpeech("Want to schedule this or add a note?")
        }
    }

    private func proceedToNext() {
        // Reset action state
        showActionOptions = false
        noteText = ""
        selectedScheduleTime = nil

        // Move to next check
        moveToNext()
    }

    /// Mark done and proceed immediately (for "do together" checks in Simple mode)
    private func markDoneAndProceed() {
        guard let check = currentCheck else { return }

        checklistService.markCompleted(id: check.id)

        // Light haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Move to next without showing action options
        moveToNext()
    }

    private func showScheduleOptions() {
        showSchedulePicker = true
        SpeechService.shared.queueSpeech("When should I remind you?")
    }

    private func scheduleIn(minutes: Int) {
        guard let check = currentCheck else { return }

        let scheduleTime = Date().addingTimeInterval(Double(minutes * 60))

        // Create a reminder for this
        Task {
            let calendarService = CalendarService()
            _ = await calendarService.requestReminderAccess()

            let parsedReminder = ParsedReminder(
                title: check.title,
                triggerDate: scheduleTime
            )
            _ = try? calendarService.createReminder(parsedReminder)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            let timeString = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour"
            SpeechService.shared.queueSpeech("Reminder set for \(timeString) from now!")

            proceedToNext()
        }
    }

    private func scheduleCurrentCheck(at time: Date) {
        guard let check = currentCheck else { return }

        Task {
            let calendarService = CalendarService()
            _ = await calendarService.requestReminderAccess()

            let parsedReminder = ParsedReminder(
                title: check.title,
                triggerDate: time
            )
            _ = try? calendarService.createReminder(parsedReminder)

            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: time)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            SpeechService.shared.queueSpeech("Scheduled for \(timeString)!")
        }
    }

    private func toggleListeningForNote() {
        if isListeningForNote {
            stopListeningForNote()
        } else {
            startListeningForNote()
        }
    }

    private func startListeningForNote() {
        do {
            try speechService.startListening()
            isListeningForNote = true
            SpeechService.shared.queueSpeech("Go ahead, I'm listening.")

            // Auto-stop after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isListeningForNote {
                    stopListeningForNote()
                }
            }
        } catch {
            print("Failed to start listening for note: \(error)")
        }
    }

    private func stopListeningForNote() {
        speechService.stopListening()
        isListeningForNote = false

        let note = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            noteText = note

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            SpeechService.shared.queueSpeech("Got it! Note saved.")

            // TODO: Save note to check or create a reminder with the note
            // For now just acknowledge
        }
    }

    private func skipCurrent() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        speakSkip()
        moveToNext()
    }

    private func moveToNext() {
        // Stop listening if active
        if isListening {
            speechService.stopListening()
            isListening = false
        }

        if currentIndex < activeChecks.count - 1 {
            withAnimation(.spring(response: 0.3)) {
                currentIndex += 1
            }
            // Small delay then speak next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                speakNextQuestion()
            }
        } else {
            withAnimation(.spring(response: 0.3)) {
                showingAllDone = true
            }
            speakAllDone()
        }
    }

    // MARK: - Deep Link Helpers

    private func getIconForCheck(_ check: MorningChecklistService.SelfCheck) -> String {
        let title = check.title.lowercased()

        if title.contains("calendar") || title.contains("schedule") || title.contains("appointment") {
            return "calendar"
        } else if title.contains("task") || title.contains("todo") || title.contains("to-do") || title.contains("list") {
            return "checklist"
        } else if title.contains("goal") {
            return "target"
        } else if title.contains("email") || title.contains("message") || title.contains("mail") {
            return "envelope"
        } else if title.contains("medication") || title.contains("medicine") || title.contains("pill") {
            return "pills"
        } else if title.contains("eat") || title.contains("breakfast") || title.contains("food") || title.contains("meal") {
            return "fork.knife"
        } else if title.contains("exercise") || title.contains("workout") || title.contains("gym") {
            return "figure.run"
        } else if title.contains("water") || title.contains("drink") || title.contains("hydrate") {
            return "drop"
        } else {
            return "arrow.right.circle"
        }
    }

    private func openRelevantView(for check: MorningChecklistService.SelfCheck) {
        let title = check.title.lowercased()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if title.contains("calendar") || title.contains("schedule") || title.contains("appointment") {
            showCalendar = true
        } else if title.contains("task") || title.contains("todo") || title.contains("to-do") || title.contains("list") {
            showTasks = true
        } else if title.contains("goal") {
            showGoals = true
        } else if title.contains("email") || title.contains("message") || title.contains("mail") {
            // Open Mail app
            if let url = URL(string: "message://") {
                UIApplication.shared.open(url)
            }
        } else if title.contains("medication") || title.contains("medicine") || title.contains("pill") {
            // Open Health app
            if let url = URL(string: "x-apple-health://") {
                UIApplication.shared.open(url)
            }
        } else {
            // Custom check - show a dedicated view
            customCheckTitle = check.title
            showCustomCheck = true
        }
    }

    // MARK: - Voice Listening

    private func toggleListening() {
        if isListening {
            stopListeningAndProcess()
        } else {
            startListening()
        }
    }

    private func startListening() {
        do {
            try speechService.startListening()
            isListening = true

            // Auto-stop after 3 seconds of listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if isListening {
                    stopListeningAndProcess()
                }
            }
        } catch {
            print("Failed to start listening: \(error)")
        }
    }

    private func stopListeningAndProcess() {
        speechService.stopListening()
        isListening = false

        let text = speechService.transcribedText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check for done/yes responses
        let doneWords = ["done", "yes", "yep", "yeah", "did", "finished", "complete", "check", "got it"]
        if doneWords.contains(where: { text.contains($0) }) {
            markDone()
            return
        }

        // Check for skip/no responses
        let skipWords = ["skip", "no", "nope", "not", "didn't", "next", "pass"]
        if skipWords.contains(where: { text.contains($0) }) {
            skipCurrent()
            return
        }

        // Unclear response - ask again
        SpeechService.shared.queueSpeech("Sorry, I didn't catch that. Say 'done' or 'skip'.")
    }

    // MARK: - Voice

    private func speakGreeting() {
        let personality = appState.selectedPersonality
        let count = activeChecks.count

        let greeting: String
        switch personality {
        case .pemberton:
            greeting = "Good morning. Let's review your \(count) morning essentials, shall we?"
        case .sergent:
            greeting = "Rise and shine! \(count) items on your morning briefing. Let's go!"
        case .cheerleader:
            greeting = "Good morning superstar! Let's check in on your \(count) morning things!"
        case .hypeFriend:
            greeting = "GOOD MORNING! Let's crush this morning routine! \(count) quick checks!"
        case .chillBuddy:
            greeting = "Hey... morning. Just \(count) quick things to check on. No rush."
        case .tiredParent:
            greeting = "Morning. Let's just get through these \(count) things. You got this."
        default:
            greeting = "Good morning! Let's go through your \(count) morning checks."
        }

        SpeechService.shared.queueSpeech(greeting)
    }

    private func speakCurrentCheck() {
        guard let check = currentCheck else { return }
        let question = getQuestion(for: check)
        SpeechService.shared.queueSpeech(question)
    }

    /// Handle the current check - speak it and auto-open if it's a "do together" type
    private func handleCurrentCheck() {
        guard let check = currentCheck else { return }

        // Speak the question
        speakCurrentCheck()

        // In Simple mode, auto-open "do together" checks after a brief delay
        if isDoTogetherCheck(check) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                openRelevantView(for: check)
            }
        }
    }

    private func speakNextQuestion() {
        guard let check = currentCheck else { return }
        SpeechService.shared.queueSpeech("Next: \(check.title)?")
    }

    private func speakAcknowledgment() {
        // More celebratory responses for dopamine
        let responses = [
            "Nice work!",
            "Boom! Done!",
            "Check! You're on fire!",
            "Crushed it!",
            "That's what I'm talking about!",
            "Yes! Keep going!",
            "Awesome!",
            "You're unstoppable!",
            "Perfect!",
            "Way to go!"
        ]
        if let response = responses.randomElement() {
            SpeechService.shared.queueSpeech(response)
        }
    }

    private func speakSkip() {
        // Still encouraging even when skipping
        let responses = [
            "No worries! Moving on.",
            "That's okay! Next one.",
            "Skipped - no judgment here.",
            "All good! Let's keep rolling.",
            "Got it, we'll circle back if needed."
        ]
        if let response = responses.randomElement() {
            SpeechService.shared.queueSpeech(response)
        }
    }

    private func speakAllDone() {
        let completed = checklistService.completedCount
        let total = activeChecks.count

        if completed == total {
            SpeechService.shared.queueSpeech("Perfect! All \(total) items done. You're ready for the day!")
        } else {
            SpeechService.shared.queueSpeech("Morning check-in done. \(completed) of \(total) complete. Let's have a good day!")
        }
    }

    private func speakGoodbye() {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            SpeechService.shared.queueSpeech("Carry on then. Make it count.")
        case .sergent:
            SpeechService.shared.queueSpeech("Mission briefing complete. Execute!")
        case .cheerleader:
            SpeechService.shared.queueSpeech("You're going to have an AMAZING day!")
        case .hypeFriend:
            SpeechService.shared.queueSpeech("LET'S GOOO! Crush it today!")
        default:
            SpeechService.shared.queueSpeech("Have a great day!")
        }
    }

    // MARK: - Message Helpers

    private func getQuestion(for check: MorningChecklistService.SelfCheck) -> String {
        let title = check.title.lowercased()

        // For calendar/tasks checks - use "Let's" phrasing (we'll do it together)
        if title.contains("calendar") || title.contains("schedule") || title.contains("appointment") {
            return "Let's check your calendar."
        } else if title.contains("task") || title.contains("todo") || title.contains("to-do") || title.contains("list") {
            return "Let's look at your tasks."
        } else if title.contains("goal") {
            return "Let's review your goals."
        }

        // For personal checks - use personality-appropriate "Did you" phrasing
        let personality = appState.selectedPersonality
        switch personality {
        case .pemberton:
            return "Have you attended to:"
        case .sergent:
            return "Status report on:"
        case .cheerleader:
            return "Did you do this?"
        case .therapist:
            return "How are we feeling about:"
        case .bestie:
            return "Did you get to:"
        case .hypeFriend:
            return "Did you CRUSH this?"
        case .chillBuddy:
            return "Did you maybe do:"
        default:
            return "Did you do this?"
        }
    }

    /// Check if this is a "do it together" type check (calendar, tasks, goals)
    private func isDoTogetherCheck(_ check: MorningChecklistService.SelfCheck) -> Bool {
        let title = check.title.lowercased()
        return title.contains("calendar") || title.contains("schedule") || title.contains("appointment") ||
               title.contains("task") || title.contains("todo") || title.contains("to-do") || title.contains("list") ||
               title.contains("goal")
    }

    private func getCelebrationMessage() -> String {
        let personality = appState.selectedPersonality
        let completed = checklistService.completedCount
        let total = activeChecks.count

        if completed == total {
            switch personality {
            case .pemberton:
                return "A thoroughly adequate start to the day."
            case .sergent:
                return "Full marks, soldier! Ready for action!"
            case .cheerleader:
                return "OH MY GOSH you're amazing! Perfect morning!"
            case .hypeFriend:
                return "UNSTOPPABLE! You're literally crushing life right now!"
            case .tiredParent:
                return "Hey, you actually did everything. That's... impressive."
            default:
                return "Great start! You're set up for success."
            }
        } else {
            return "You've checked in on what matters. That's what counts."
        }
    }
}

// MARK: - Schedule Time Picker Sheet

struct ScheduleTimePickerSheet: View {
    @Binding var selectedTime: Date?
    let onSchedule: (Date) -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    @State private var pickerTime = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When do you want to be reminded?")
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                    .padding(.top)

                // Quick time options
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    quickTimeButton(minutes: 15, label: "15 min")
                    quickTimeButton(minutes: 30, label: "30 min")
                    quickTimeButton(minutes: 60, label: "1 hour")
                    quickTimeButton(minutes: 120, label: "2 hours")
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Custom time picker
                Text("Or pick a specific time:")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)

                DatePicker("Time", selection: $pickerTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Button {
                    onSchedule(pickerTime)
                    dismiss()
                } label: {
                    Text("Set Reminder")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color.themeBackground)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func quickTimeButton(minutes: Int, label: String) -> some View {
        Button {
            let time = Date().addingTimeInterval(Double(minutes * 60))
            onSchedule(time)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "\(minutes < 60 ? minutes : minutes/60).circle")
                    .font(.title2)
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(themeColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Reset Options Sheet

struct ResetOptionsSheet: View {
    let onReset: (MorningChecklistView.ResetType) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    private var timeBasedSuggestion: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "It's morning - start fresh with your routine"
        } else if hour < 17 {
            return "It's afternoon - jump to calendar or tasks"
        } else {
            return "It's evening - quick check on what's left"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(timeBasedSuggestion)
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
                    .padding(.top)

                VStack(spacing: 12) {
                    resetButton(
                        icon: "sun.horizon.fill",
                        title: "Morning Check-in",
                        subtitle: "Start from the beginning",
                        color: .orange
                    ) {
                        dismiss()
                        onReset(.morning)
                    }

                    resetButton(
                        icon: "calendar",
                        title: "Calendar Review",
                        subtitle: "Jump to your schedule",
                        color: .blue
                    ) {
                        dismiss()
                        onReset(.calendar)
                    }

                    resetButton(
                        icon: "checklist",
                        title: "Task Review",
                        subtitle: "Jump to your tasks",
                        color: .green
                    ) {
                        dismiss()
                        onReset(.tasks)
                    }

                    Divider().padding(.vertical, 8)

                    resetButton(
                        icon: "bell.slash",
                        title: "Clear Old Notifications",
                        subtitle: "Stop old personality interrupting",
                        color: .red
                    ) {
                        dismiss()
                        onReset(.clearNotifications)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color.themeBackground)
            .navigationTitle("Start Fresh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func resetButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(themeColors.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(themeColors.subtext)
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }
    }
}

#Preview {
    MorningChecklistView(
        onComplete: {},
        onSkip: {}
    )
    .environmentObject(AppState())
}
