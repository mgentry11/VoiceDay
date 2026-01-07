import Foundation
import AVFoundation
import UIKit

@MainActor
class BackgroundAudioManager: NSObject, ObservableObject {
    static let shared = BackgroundAudioManager()

    @Published var isBackgroundModeActive = false

    private var audioPlayer: AVAudioPlayer?
    private var focusTimer: Timer?
    private var idleTimer: Timer?
    private var checkInCount = 0
    private var recentMessageIndices: [Int] = []
    private let maxRecentMessages = 10
    private var lastUserActivityTime = Date()
    private var lastAppOpenDate: Date?
    private var hasDoneMorningBriefing = false

    // CalendarService for fetching live task counts
    private let calendarService = CalendarService()

    // Accountability and Goals integration
    private let accountabilityTracker = AccountabilityTracker.shared
    private let goalsService = GoalsService.shared

    // Haptic feedback generator
    private let hapticGenerator = UINotificationFeedbackGenerator()

    private let focusMessages = [
        "Focus check: Still productively engaged, I trust? Your task list isn't getting shorter by osmosis.",
        "Periodic surveillance report: How goes the battle against procrastination? The tasks await.",
        "Just checking in. Are we working, or have we wandered off to watch cat videos? One doesn't judge. Much.",
        "Focus audit: Your tasks remain incomplete. I assume you're making progress and not doom-scrolling?",
        "Time check: You've been 'working' for a while. Shall I assume actual work is occurring?",
        "Socrates questioned everything. I question whether you're actually working. Well?",
        "The Stoics believed in focusing on what we can control. You can control your productivity. Are you?",
        "At Oxford, we had reading weeks. This appears to be your scrolling week. Thoughts?",
        "Parmenides said change is an illusion. Your task list remaining unchanged supports his theory.",
        "Maxwell's demon sorted molecules. You can't even sort your priorities. Focus, please.",
        "The Copenhagen interpretation requires observation. I'm observing. Are you working?",
        "My thesis advisor at Balliol would conduct surprise office visits. Consider this yours.",
        "Popper said theories must be falsifiable. Your claim of 'working' is being tested.",
        "Hume was skeptical of causation. I'm skeptical of your claimed productivity. Prove me wrong.",
        "The anthropic principle suggests the universe exists because we observe it. Your tasks exist. Observe them. Do them.",
        "Spinoza believed in determinism. Is your distraction predetermined, or can we change course?",
        "Newton's first law: objects at rest stay at rest. You appear to be at rest. Your tasks require motion.",
        "Entropy increases in closed systems. Your productivity appears to be a closed system. Open it.",
        "Bertrand Russell spent years on Principia Mathematica. Surely you can spend minutes on your tasks?",
        "The heat death of the universe is inevitable. Your task completion, apparently, is not."
    ]

    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .ended {
            // Resume silent audio after interruption
            if isBackgroundModeActive {
                startSilentAudio()
            }
        }
    }

    @objc private func appDidEnterBackground() {
        // Always track when we entered background
        lastBackgroundTime = Date()
        print("📱 App entered background - tracking time away")

        // Keep audio alive during focus sessions
        if isBackgroundModeActive {
            startSilentAudio()
        }
    }

    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground")

        // Record app return for doomscroll detection
        accountabilityTracker.recordAppReturn()

        // Check how long user was away (works even outside focus sessions)
        checkTimeAway()

        // Check for morning briefing (includes goal reminders)
        checkMorningBriefing()

        // Update app badge
        updateAppBadge()

        // Start idle detection
        startIdleDetection()

        // Make sure the timer is still running during focus sessions
        ensureTimerRunning()

        // Reset activity time
        recordUserActivity()
    }

    private var lastBackgroundTime: Date?

    // MARK: - User Activity & Idle Detection

    /// Call this whenever the user interacts with the app
    func recordUserActivity() {
        lastUserActivityTime = Date()
    }

    private func startIdleDetection() {
        idleTimer?.invalidate()

        // Check for idle every 2 minutes
        idleTimer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForIdleUser()
            }
        }
        if let timer = idleTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopIdleDetection() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func checkForIdleUser() {
        let idleThreshold = UserDefaults.standard.object(forKey: "idle_threshold_minutes") as? Int ?? 5
        guard idleThreshold < 9999 else { return } // "Never" setting

        let idleMinutes = Int(Date().timeIntervalSince(lastUserActivityTime) / 60)

        if idleMinutes >= idleThreshold {
            Task {
                let taskCount = await calendarService.fetchReminders().count
                guard taskCount > 0 else { return } // Don't nag if no tasks

                let message = getIdleMessage(minutes: idleMinutes, taskCount: taskCount)
                print("😴 User idle for \(idleMinutes) minutes with \(taskCount) tasks")

                // Haptic feedback
                hapticGenerator.notificationOccurred(.warning)

                ConversationService.shared.addFocusCheckIn(message)
                await AppDelegate.shared?.speakMessage(message)

                // Reset so we don't nag continuously
                lastUserActivityTime = Date()
            }
        }
    }

    private let idleMessages = [
        "The app is open. You are present. And yet... nothing is happening. %d tasks await your attention.",
        "I detect a pulse but no productivity. You have %d tasks. Perhaps engage with one?",
        "Staring at the screen won't complete your %d tasks. Might I suggest... doing one?",
        "You've been idle for a while. Your %d tasks are getting lonely. Visit them.",
        "The Greeks had a word for this: akrasia. Weakness of will. You have %d tasks. Exercise your will.",
        "Screen time without productivity is just... screen time. %d tasks remain.",
        "I'm not saying you're procrastinating, but your %d tasks might disagree.",
        "The app is open. The tasks are visible. The user is... contemplating? %d tasks need action, not contemplation."
    ]

    private func getIdleMessage(minutes: Int, taskCount: Int) -> String {
        let template = idleMessages.randomElement() ?? "You have %d tasks waiting."
        return String(format: template, taskCount)
    }

    // MARK: - Morning Briefing

    private func checkMorningBriefing() {
        // Check if enabled
        let enabled = UserDefaults.standard.object(forKey: "morning_briefing_enabled") as? Bool ?? true
        guard enabled else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // Check if we've already done the briefing today
        if let lastOpen = lastAppOpenDate, Calendar.current.isDate(lastOpen, inSameDayAs: today) {
            return // Already opened today
        }

        lastAppOpenDate = today

        // Do morning briefing
        Task {
            // Small delay to let the app fully load
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            let tasks = await calendarService.fetchReminders()
            let events = calendarService.fetchUpcomingEvents(days: 1)
            let todayEvents = events.filter { Calendar.current.isDateInToday($0.startDate) }

            let message = getMorningBriefing(taskCount: tasks.count, eventCount: todayEvents.count)

            print("🌅 Morning briefing: \(tasks.count) tasks, \(todayEvents.count) events")

            hapticGenerator.notificationOccurred(.success)

            ConversationService.shared.addFocusCheckIn(message)
            await AppDelegate.shared?.speakMessage(message)
        }
    }

    private func getMorningBriefing(taskCount: Int, eventCount: Int) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String

        if hour < 12 {
            greeting = "Good morning"
        } else if hour < 17 {
            greeting = "Good afternoon"
        } else {
            greeting = "Good evening"
        }

        var parts: [String] = []

        // Check for goals scheduled today
        let activeGoals = goalsService.activeGoals
        let todayDayOfWeek = Calendar.current.component(.weekday, from: Date()) - 1 // 0-indexed Sun=0
        let goalsScheduledToday = activeGoals.filter { goal in
            if let preferredDays = goal.preferredDays {
                return preferredDays.contains(todayDayOfWeek)
            }
            return true // If no preferred days, assume every day
        }

        if taskCount == 0 && eventCount == 0 && goalsScheduledToday.isEmpty {
            return "\(greeting). Your slate is clean. No tasks, no events, no goals scheduled. A rare and suspicious occurrence. Enjoy it while it lasts."
        }

        if taskCount > 0 {
            parts.append("\(taskCount) task\(taskCount == 1 ? "" : "s") awaiting your attention")
        }

        if eventCount > 0 {
            parts.append("\(eventCount) event\(eventCount == 1 ? "" : "s") on your calendar today")
        }

        var message: String
        if parts.isEmpty {
            message = "\(greeting). "
        } else {
            let briefings = [
                "\(greeting). Daily briefing: You have \(parts.joined(separator: " and ")). ",
                "\(greeting). Status report: \(parts.joined(separator: ", ")). ",
                "\(greeting). Your agenda includes \(parts.joined(separator: " and ")). ",
                "\(greeting). The universe has granted you another day. You have \(parts.joined(separator: " and ")). "
            ]
            message = briefings.randomElement() ?? "\(greeting). You have things to do. "
        }

        // Add goal reminders
        if !goalsScheduledToday.isEmpty {
            if goalsScheduledToday.count == 1 {
                let goal = goalsScheduledToday[0]
                let timeText = goal.dailyTimeMinutes.map { "\($0) minutes" } ?? "some time"
                let milestoneText = goal.currentMilestone.map { "Focus on: \($0.title)." } ?? ""
                message += "Today's goal: '\(goal.title)' needs \(timeText). \(milestoneText)"
            } else {
                let goalTitles = goalsScheduledToday.prefix(2).map { $0.title }.joined(separator: "' and '")
                message += "Goals scheduled today: '\(goalTitles)'\(goalsScheduledToday.count > 2 ? " and \(goalsScheduledToday.count - 2) more" : "")."
            }

            // Check for neglected goals
            if let neglected = goalsService.mostNeglectedGoal, neglected.daysSinceLastProgress >= 3 {
                message += " Warning: '\(neglected.title)' has been neglected for \(neglected.daysSinceLastProgress) days."
            }
        }

        return message
    }

    // MARK: - App Badge

    func updateAppBadge() {
        Task {
            let taskCount = await calendarService.fetchReminders().count
            await MainActor.run {
                UNUserNotificationCenter.current().setBadgeCount(taskCount)
            }
            print("📛 App badge updated: \(taskCount) tasks")
        }
    }

    private func checkTimeAway() {
        guard let lastBackground = lastBackgroundTime else { return }

        let awayTime = Date().timeIntervalSince(lastBackground)
        let awayMinutes = Int(awayTime / 60)
        let awayHours = awayMinutes / 60
        let remainingMinutes = awayMinutes % 60

        // Record time away for accountability tracking
        accountabilityTracker.recordTimeAway(awayTime)

        // Get thresholds from settings (with defaults)
        let focusThreshold = UserDefaults.standard.object(forKey: "focus_time_away_threshold_minutes") as? Int ?? 3
        let normalThreshold = UserDefaults.standard.object(forKey: "time_away_threshold_minutes") as? Int ?? 10
        let threshold = isBackgroundModeActive ? focusThreshold : normalThreshold

        if awayMinutes >= threshold {
            Task {
                // Fetch live task count
                let liveTaskCount = await calendarService.fetchReminders().count

                // Check for doomscroll pattern (quick repeated returns)
                if accountabilityTracker.shortReturnPattern {
                    // Doomscrolling detected
                    var message = accountabilityTracker.getDoomscrollMessage()

                    if liveTaskCount > 0 {
                        message += " You have \(liveTaskCount) task\(liveTaskCount == 1 ? "" : "s") waiting."
                    }

                    // Add goal neglect if applicable
                    if let neglectedGoal = goalsService.mostNeglectedGoal, neglectedGoal.daysSinceLastProgress >= 3 {
                        message += " Meanwhile, '\(neglectedGoal.title)' has been neglected for \(neglectedGoal.daysSinceLastProgress) days."
                    }

                    print("📱 Doomscroll pattern detected - escalation level: \(accountabilityTracker.currentEscalationLevel)")

                    hapticGenerator.notificationOccurred(.error)

                    ConversationService.shared.addFocusCheckIn(message)
                    await AppDelegate.shared?.speakMessage(message)
                } else {
                    // Normal time-away message with escalation
                    var message = accountabilityTracker.getTimeAwayMessage(minutes: awayMinutes)

                    // Add task count
                    if liveTaskCount > 0 {
                        message += " You still have \(liveTaskCount) task\(liveTaskCount == 1 ? "" : "s") waiting."
                    } else {
                        message += " At least your task list is clear."
                    }

                    // Add goal neglect reminder for most neglected goal
                    if let neglectedGoal = goalsService.mostNeglectedGoal, neglectedGoal.daysSinceLastProgress >= 2 {
                        let neglectMessage = goalsService.getNeglectMessage(for: neglectedGoal)
                        message += " \(neglectMessage)"
                    }

                    print("📱 User returned after \(awayMinutes) minutes away - \(liveTaskCount) tasks pending, escalation: \(accountabilityTracker.currentEscalationLevel)")

                    hapticGenerator.notificationOccurred(.warning)

                    ConversationService.shared.addFocusCheckIn(message)
                    await AppDelegate.shared?.speakMessage(message)
                }
            }
        }

        lastBackgroundTime = nil
    }

    private func formatTimeAway(hours: Int, minutes: Int, totalMinutes: Int) -> String {
        if hours > 0 {
            if minutes > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") and \(minutes) minute\(minutes == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        } else {
            return "\(totalMinutes) minute\(totalMinutes == 1 ? "" : "s")"
        }
    }

    private let timeAwayMessages = [
        "Welcome back after %@. I trust that time was spent productively? No? I thought not.",
        "Ah, you've returned after %@. The algorithms had you in their grip, didn't they.",
        "%@ of your finite existence, gone. I hope whatever captured your attention was worth it. Spoiler: it wasn't.",
        "You've been away %@. Aristotle wrote entire treatises in less time. You watched videos of cats, I presume.",
        "Back after %@. Your tasks didn't complete themselves in your absence. Shocking, I know.",
        "%@ vanished into the digital void. Time you'll never recover. But I'm not here to judge. Much.",
        "Fascinating. %@ away. Heraclitus said you can't step in the same river twice. You can't get that time back either.",
        "You return after %@. The dopamine hits were satisfying, I assume? Your task list remains unsatisfied.",
        "%@ of wandering. Odysseus took 10 years to get home, but at least he had an excuse.",
        "Ah, %@ later and here you are. The infinite scroll released you from its embrace. Temporarily.",
        "%@ gone. Einstein proved time is relative. Relative to productivity, yours was wasted.",
        "Back from a %@ expedition. Did you discover anything useful? Or just more content to consume?"
    ]

    private let focusTimeAwayMessages = [
        "You left your focus session for %@. The irony is not lost on me.",
        "%@ away during a focus session. 'Focus' may not mean what you think it means.",
        "A focus session, interrupted for %@. Impressive lack of commitment.",
        "%@ of focus session... spent not focusing. Shall we redefine the term?",
        "You abandoned your focus session for %@. The tasks weep. Silently. Judgmentally."
    ]

    private func getTimeAwayMessage(timeString: String, duringFocus: Bool) -> String {
        let messages = duringFocus ? focusTimeAwayMessages : timeAwayMessages
        let template = messages.randomElement() ?? "You were away for %@."
        return String(format: template, timeString)
    }

    private let doomScrollMessages = [
        "Ah, you've returned after %d minutes. Let me guess - YouTube? Instagram? The algorithm had you, didn't it.",
        "Welcome back from your %d-minute expedition into the digital void. The dopamine was worth it, I hope?",
        "%d minutes. That's how long you were presumably doom-scrolling. Seneca would be disappointed. I certainly am.",
        "You've been gone %d minutes. Were you solving world hunger, or watching cat videos? My money's on cats.",
        "Fascinating. %d minutes of 'just checking my phone.' Aristotle's virtue of moderation weeps.",
        "%d minutes vanished into the algorithmic abyss. Your tasks remain. Unfinished. Judging you silently.",
        "Back from %d minutes of... research, was it? The infinite scroll claimed another victim.",
        "The focus session noted your %d-minute absence. Social media, I presume? It always is.",
        "%d minutes. Gone. Absorbed by the content machine. Your attention span has my sympathies.",
        "You wandered off for %d minutes. TikTok? Reddit? The modern Lotus-eaters await on every app.",
        "Returned after %d minutes in the digital wilderness. Your tasks missed you. I didn't.",
        "%d minutes of productive procrastination, no doubt. The irony isn't lost on me."
    ]

    private func getDoomScrollMessage(minutes: Int) -> String {
        let message = doomScrollMessages.randomElement() ?? "You were away for %d minutes. Interesting."
        return String(format: message, minutes)
    }

    // MARK: - Focus Session Control

    private var currentTaskCount: Int = 0
    private var currentIntervalMinutes: Int = 5
    private var gracePeriodTimer: Timer?
    private var hasCompletedGracePeriod: Bool = false
    private var lastCheckInTime: Date?

    func startFocusSession(intervalMinutes: Int, gracePeriodMinutes: Int, taskCount: Int) {
        // Stop any existing session first
        stopFocusSession()

        isBackgroundModeActive = true
        checkInCount = 0
        currentTaskCount = taskCount
        currentIntervalMinutes = intervalMinutes
        hasCompletedGracePeriod = false

        // Keep screen on during focus session
        UIApplication.shared.isIdleTimerDisabled = true
        print("🔆 Screen will stay on during focus session")

        // Start silent audio to keep app alive in background
        startSilentAudio()

        let gracePeriodSeconds = Double(max(gracePeriodMinutes, 1) * 60)
        let intervalSeconds = Double(intervalMinutes * 60)

        print("🎯 Focus session started - first check-in in \(gracePeriodMinutes) min, then every \(intervalMinutes) min")

        // Schedule grace period timer
        gracePeriodTimer = Timer(timeInterval: gracePeriodSeconds, repeats: false) { [weak self] _ in
            guard let self = self, self.isBackgroundModeActive else { return }
            Task { @MainActor in
                self.hasCompletedGracePeriod = true
                self.performCheckIn(taskCount: self.currentTaskCount)

                // Now start the repeating timer
                self.focusTimer?.invalidate()
                self.focusTimer = Timer(timeInterval: intervalSeconds, repeats: true) { [weak self] _ in
                    guard let self = self, self.isBackgroundModeActive else { return }
                    Task { @MainActor in
                        self.performCheckIn(taskCount: self.currentTaskCount)
                    }
                }
                if let timer = self.focusTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
        }
        if let timer = gracePeriodTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopFocusSession() {
        isBackgroundModeActive = false
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
        focusTimer?.invalidate()
        focusTimer = nil
        stopSilentAudio()
        checkInCount = 0
        hasCompletedGracePeriod = false
        lastCheckInTime = nil

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false
        print("🛑 Focus session stopped - screen will auto-lock normally")
    }

    // Restart the timer if it somehow stopped (called when app comes to foreground)
    func ensureTimerRunning() {
        guard isBackgroundModeActive, hasCompletedGracePeriod else { return }

        let intervalSeconds = Double(currentIntervalMinutes * 60)

        // Check if we missed a check-in while in background
        if let lastTime = lastCheckInTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed >= intervalSeconds {
                print("⚠️ Missed check-in (elapsed: \(Int(elapsed))s) - doing one now")
                performCheckIn(taskCount: currentTaskCount)
            }
        }

        // Check if timer is valid
        if focusTimer == nil || !(focusTimer?.isValid ?? false) {
            print("⚠️ Focus timer was stopped - restarting")
            focusTimer = Timer(timeInterval: intervalSeconds, repeats: true) { [weak self] _ in
                guard let self = self, self.isBackgroundModeActive else { return }
                Task { @MainActor in
                    self.performCheckIn(taskCount: self.currentTaskCount)
                }
            }
            if let timer = focusTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func getRandomMessage() -> String {
        var availableIndices = Array(0..<focusMessages.count).filter { !recentMessageIndices.contains($0) }

        // If we've used most messages, reset
        if availableIndices.isEmpty {
            recentMessageIndices = []
            availableIndices = Array(0..<focusMessages.count)
        }

        let selectedIndex = availableIndices.randomElement()!
        recentMessageIndices.append(selectedIndex)

        // Keep only the last N indices
        if recentMessageIndices.count > maxRecentMessages {
            recentMessageIndices.removeFirst()
        }

        return focusMessages[selectedIndex]
    }

    private func performCheckIn(taskCount: Int) {
        checkInCount += 1
        lastCheckInTime = Date()

        // Fetch the LIVE task count and upcoming events
        Task {
            let liveTaskCount = await calendarService.fetchReminders().count
            let upcomingEvents = calendarService.fetchUpcomingEvents(days: 1) // Today's remaining events
            let now = Date()
            let remainingEvents = upcomingEvents.filter { $0.startDate > now }
            let eventCount = remainingEvents.count

            let message = getRandomMessage()
            var statusParts: [String] = []

            if liveTaskCount > 0 {
                statusParts.append("\(liveTaskCount) task\(liveTaskCount == 1 ? "" : "s") remaining")
            }
            if eventCount > 0 {
                statusParts.append("\(eventCount) event\(eventCount == 1 ? "" : "s") today")
            }

            var fullMessage: String
            if statusParts.isEmpty {
                fullMessage = "\(message) All clear - no tasks or events pending!"
            } else {
                fullMessage = "\(message) You have \(statusParts.joined(separator: " and "))."
            }

            // Add goal reminder during focus sessions
            let activeGoals = goalsService.activeGoals
            if !activeGoals.isEmpty {
                // Remind about current milestone
                if let priorityGoal = activeGoals.first(where: { $0.currentMilestone != nil }) {
                    if let milestone = priorityGoal.currentMilestone {
                        fullMessage += " Current focus for '\(priorityGoal.title)': \(milestone.title)."
                    }
                }

                // Check for neglected goals
                if let neglected = goalsService.mostNeglectedGoal, neglected.daysSinceLastProgress >= 3 {
                    fullMessage += " '\(neglected.title)' needs attention - \(neglected.daysSinceLastProgress) days idle."
                }
            }

            print("🔔 Focus check-in #\(checkInCount): Speaking reminder at \(Date()) - Tasks: \(liveTaskCount), Events: \(eventCount)")

            // Haptic feedback
            hapticGenerator.notificationOccurred(.warning)

            // Log to conversation history
            ConversationService.shared.addFocusCheckIn(fullMessage)

            // Speak the reminder
            await AppDelegate.shared?.speakMessage(fullMessage)
        }
    }

    // MARK: - Silent Audio

    private func startSilentAudio() {
        // Create silent audio data (1 second of silence)
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)

        var audioData = Data()

        // WAV header
        let headerSize: UInt32 = 44
        let dataSize: UInt32 = UInt32(numSamples * 2)
        let fileSize: UInt32 = headerSize + dataSize - 8

        // RIFF header
        audioData.append(contentsOf: "RIFF".utf8)
        audioData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        audioData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        audioData.append(contentsOf: "fmt ".utf8)
        audioData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        audioData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        audioData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
        audioData.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) }) // sample rate
        audioData.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) }) // byte rate
        audioData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
        audioData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        audioData.append(contentsOf: "data".utf8)
        audioData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Silent samples (zeros)
        audioData.append(contentsOf: [UInt8](repeating: 0, count: Int(dataSize)))

        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.numberOfLoops = -1 // Loop forever
            audioPlayer?.volume = 0.01 // Nearly silent
            audioPlayer?.play()
            print("🔇 Silent audio started - app will stay alive in background")
        } catch {
            print("❌ Failed to start silent audio: \(error)")
        }
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        print("🔇 Silent audio stopped")
    }
}
