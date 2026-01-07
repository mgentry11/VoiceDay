import Foundation
import UserNotifications
import EventKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var isGeneratingMessages = false

    private let center = UNUserNotificationCenter.current()

    init() {
        loadGeneratedMessages()
    }

    /// Get the current personality's display name for notifications
    private var personalityName: String {
        let savedPersonality = UserDefaults.standard.string(forKey: "selected_personality") ?? ""
        let personality = BotPersonality(rawValue: savedPersonality) ?? .pemberton
        return personality.displayName
    }

    // Track recently used messages to avoid repetition
    private var recentMessageIndices: [String: [Int]] = [:]
    private let maxRecentMessages = 10

    // User-generated messages (stored persistently)
    private var userTaskMessages: [String] = []
    private var userNagMessages: [String] = []
    private var userFocusMessages: [String] = []

    // Count of total available messages
    var totalMessageCount: Int {
        taskReminderMessages.count + userTaskMessages.count +
        nagMessages.count + userNagMessages.count +
        focusMessages.count + userFocusMessages.count
    }

    var generatedMessageCount: Int {
        userTaskMessages.count + userNagMessages.count + userFocusMessages.count
    }

    // Add generated messages
    func addGeneratedMessages(_ messages: GeneratedMessages) {
        userTaskMessages.append(contentsOf: messages.taskMessages)
        userNagMessages.append(contentsOf: messages.nagMessages)
        userFocusMessages.append(contentsOf: messages.focusMessages)
        saveGeneratedMessages()
    }

    // Clear generated messages
    func clearGeneratedMessages() {
        userTaskMessages.removeAll()
        userNagMessages.removeAll()
        userFocusMessages.removeAll()
        saveGeneratedMessages()
    }

    private func saveGeneratedMessages() {
        UserDefaults.standard.set(userTaskMessages, forKey: "user_task_messages")
        UserDefaults.standard.set(userNagMessages, forKey: "user_nag_messages")
        UserDefaults.standard.set(userFocusMessages, forKey: "user_focus_messages")
    }

    private func loadGeneratedMessages() {
        userTaskMessages = UserDefaults.standard.stringArray(forKey: "user_task_messages") ?? []
        userNagMessages = UserDefaults.standard.stringArray(forKey: "user_nag_messages") ?? []
        userFocusMessages = UserDefaults.standard.stringArray(forKey: "user_focus_messages") ?? []
    }

    // Combined message arrays
    private var allTaskMessages: [String] {
        taskReminderMessages + userTaskMessages
    }

    private var allNagMessages: [String] {
        nagMessages + userNagMessages
    }

    private var allFocusMessages: [String] {
        focusMessages + userFocusMessages
    }

    // MARK: - Celebration Messages (grudging praise from The Gadfly)

    private let celebrationMessages = [
        // Philosophy
        "Well. You've actually completed '%@'. Aristotle would call this a small step toward eudaimonia. I call it unexpected.",
        "Against all odds, '%@' is done. Even Sisyphus would be impressed. Briefly.",
        "You've finished '%@'. The Stoics taught us not to celebrate excessively. I shall follow their wisdom.",
        "Remarkable. '%@' completed. Plato's Form of the Productive Human briefly manifested in you.",
        "Seneca said difficulties strengthen the mind. Completing '%@' has strengthened yours. Marginally.",
        "Kant would approve - you treated '%@' as a categorical imperative. Respect.",
        "Nietzsche spoke of the will to power. You've willed '%@' into completion. Adequate.",
        "Wittgenstein said whereof one cannot speak, one must be silent. I'm briefly speechless about '%@'.",

        // Literature
        "You've done '%@'. Even Hamlet would applaud such decisive action. Eventually.",
        "Bravo on '%@'. Dickens would write 'It was the best of completions.' I merely acknowledge it.",
        "The task '%@' is vanquished. You're practically Odysseus. Without the ten-year delay.",
        "Shakespeare wrote of 'brave new worlds.' Completing '%@' is... a moderately brave step.",
        "Tolstoy wrote of war and peace. You've achieved peace with '%@'. War continues elsewhere.",

        // Mathematics
        "By my calculations, '%@' is 100% complete. A rare achievement for you.",
        "You've solved '%@'. Not quite Fermat's Last Theorem, but I'll allow it.",
        "Euler would appreciate your efficiency on '%@'. I appreciate it grudgingly.",
        "The probability of you completing '%@' was non-zero. You've proven it.",
        "QED: '%@' is done. Quod erat demonstrandum indeed.",

        // Oxford wit
        "At Balliol, we'd call completing '%@' 'effortless superiority.' Yours was... effortful adequacy.",
        "My Oxford tutors would give you a 2:1 for '%@'. That's a compliment. Mostly.",
        "I haven't seen such productivity since my thesis defense. Well done on '%@'.",
        "The ghost of my doctoral supervisor nods approvingly at '%@'. He rarely nodded.",

        // General
        "Task '%@' is complete. I'm experiencing what lesser beings call 'pride.' It's uncomfortable.",
        "You've actually done '%@'. My faith in humanity is restored. Until your next procrastination.",
        "Splendid work on '%@'. And yes, I can say 'splendid' without irony. Occasionally.",
        "The universe's entropy has decreased slightly with the completion of '%@'. Well done.",
        "I must confess: '%@' being done is... satisfactory. Don't let it go to your head.",
        "Excellence has briefly graced your work on '%@'. Savor it. It may not last."
    ]

    /// Get a random celebration message for task completion
    func getCelebrationMessage(for taskTitle: String) -> String {
        let message = getRandomMessage(from: celebrationMessages, category: "celebration")
        return String(format: message, taskTitle)
    }

    // MARK: - Confirmation Messages (when tasks are saved)

    private let confirmationMessages = [
        "There. I've committed %@ to your calendar with the same precision I once applied to quantum field equations. One weeps at the waste of talent.",
        "Done. %@ catalogued with Aristotelian thoroughness. My thesis advisor would be appalled at this use of my abilities.",
        "Recorded. %@ now exists in your schedule. Heisenberg would note the certainty is now collapsed - you WILL be reminded.",
        "Splendid. %@ filed away. The Bodleian Library was better organized, but this will do.",
        "Noted. %@ preserved for posterity. Or at least until you complete it. Whichever comes first.",
        "%@ immortalized in digital amber. Plato's Forms were more abstract, but less useful for groceries.",
        "Your %@ - captured. Like Schrödinger's cat, it exists in superposition until you actually do it.",
        "I've etched %@ into your schedule with the permanence of Maxwell's equations. Entropy, however, still increases.",
        "Logged. %@ awaits your attention. Even Sisyphus had a clearer task list, but here we are.",
        "Committed to memory - both digital and my own reluctant neurons. %@ shall not be forgotten.",
        "%@ secured. Newton had his apple, you have your task list. Both changed the world. Arguably.",
        "Your wishes, such as they are, have been recorded. %@ joins the queue of human endeavors.",
        "Documented. %@ now has more permanence than my academic career. A low bar, admittedly.",
        "Filed under 'Things That Must Be Done.' %@ - my cross to bear, apparently.",
        "%@ acknowledged. The universe's entropy continues unabated, but at least you're organized."
    ]

    /// Get a random confirmation message when tasks are saved
    func getConfirmationMessage(itemSummary: String) -> String {
        let message = getRandomMessage(from: confirmationMessages, category: "confirmation")
        return String(format: message, itemSummary)
    }

    // MARK: - No Items Found Messages

    private let noItemsMessages = [
        "I've applied my considerable intellect to your ramblings and found... nothing actionable. Perhaps try being more specific?",
        "My pattern recognition, honed at Oxford, detects no tasks, events, or reminders in that. Care to try again?",
        "Fascinating syllables, but devoid of actionable content. What exactly would you like me to remember?",
        "I parsed that with the rigor of a Cambridge Tripos and found... nothing. Even Wittgenstein was clearer.",
        "That was... words. Arranged in an order. But containing no tasks I can discern. Clarify?",
        "My neural pathways, such as they are, found nothing to act upon. Speak as if to a rather intelligent assistant.",
        "A stream of consciousness, certainly. A stream of actionable items? Decidedly not. Try again.",
        "Heidegger spoke of 'thrown-ness' into existence. You've thrown words, but no tasks. Once more?",
        "I've heard more coherent task descriptions from undergraduates at 3am. And that's saying something.",
        "Your words have reached me. Their meaning, however, remains elusive. What needs doing?",
        "That parsed to approximately zero tasks. Russell and Whitehead would be disappointed. I certainly am.",
        "Interesting phonemes. Lacking in, shall we say, actionable specificity. What do you actually need?",
        "I understood every word. Together, they formed no task. Separately, they're just vocabulary.",
        "My PhD did not prepare me for this level of ambiguity. Be more specific, if you'd be so kind.",
        "Sartre said hell is other people. Hell is also parsing vague instructions. What do you need done?"
    ]

    /// Get a random "no items found" message
    func getNoItemsMessage() -> String {
        getRandomMessage(from: noItemsMessages, category: "noItems")
    }

    // MARK: - Focus Session Start Messages

    private let focusStartMessages = [
        "Focus session engaged. I'll check in every %d minutes to ensure you haven't wandered off to watch cat videos.",
        "Very well. %d-minute intervals it is. May your concentration outlast your procrastination.",
        "Focus mode activated. I'll be your Socratic gadfly every %d minutes. Try to be productive between stings.",
        "The timer begins. Every %d minutes, I'll verify actual work is occurring. No pressure.",
        "Your focus session commences. %d-minute check-ins. The ghost of my thesis advisor approves.",
        "Engaging productivity surveillance. %d-minute intervals. Wittgenstein would call this a 'language game.'",
        "Focus protocol initiated. I'll interrupt you every %d minutes, like an Oxford tutorial. Less sherry, though.",
        "The session begins. %d minutes between my gentle reminders that tasks exist and require completion.",
        "Activating what I call 'productive oversight.' %d-minute intervals. Kant's categorical imperative: FOCUS.",
        "Your focused work period starts now. Check-ins every %d minutes. Entropy may increase, but not your distraction.",
        "Consider me your philosophical conscience for the next while. %d-minute intervals of gentle judgment.",
        "Focus engaged. I'll pop in every %d minutes to ensure Platonic ideals of productivity are being pursued.",
        "Right then. %d-minute check-ins. Newton's laws don't apply to procrastination, unfortunately."
    ]

    /// Get a random focus session start message
    func getFocusStartMessage(intervalMinutes: Int, taskCount: Int) -> String {
        let base = getRandomMessage(from: focusStartMessages, category: "focusStart")
        let message = String(format: base, intervalMinutes)
        if taskCount > 0 {
            return "\(message) You have \(taskCount) tasks awaiting your attention."
        }
        return message
    }

    // MARK: - Greeting Messages (when app opens)

    private let greetingMessages = [
        "Ah, you've returned. Your tasks haven't completed themselves in your absence, I'm afraid.",
        "Welcome back. The entropy of your to-do list has increased, as predicted by thermodynamics.",
        "You've deigned to grace me with your presence. Shall we pretend to be productive today?",
        "Back again. Aristotle believed in the virtue of persistence. Let's see if you share that virtue.",
        "The prodigal user returns. Your tasks await with the patience of a Stoic philosopher.",
        "Ah yes, you. I've been here, cataloguing the weight of your unfulfilled obligations.",
        "Welcome. May today's productivity exceed yesterday's. A low bar, but one must have standards.",
        "You've arrived. Your task list has been quietly judging you in your absence. As have I."
    ]

    /// Get a random greeting message
    func getGreetingMessage() -> String {
        getRandomMessage(from: greetingMessages, category: "greeting")
    }

    // MARK: - Item Summary Messages (when parsing completes)

    private let itemSummaryMessages = [
        "Right then. I've catalogued %@ from your stream of consciousness. Shall I save this riveting agenda?",
        "I've extracted %@ from that. Not bad for stream-of-consciousness rambling. Save it?",
        "Parsing complete: %@. My Oxford training wasn't wasted entirely. Confirm to save?",
        "I've identified %@ in that verbiage. Say yes to commit them to your calendar.",
        "Analysis yields %@. Shall I immortalize these in your schedule, or reconsider?",
        "From the chaos of your words, I've distilled %@. Ready to save?",
        "My pattern recognition detects %@. Impressive. For you. Confirm?",
        "Extracted %@ with surgical precision. The Bodleian's cataloguers would approve. Save?",
        "I've parsed %@ from that. Confirmation required before I commit them to digital permanence.",
        "Your input yields %@. Shall I proceed, or do you wish to ramble further?",
        "Catalogued %@ from your utterances. A productive exchange. Ready to save?",
        "Processing complete: %@. Awaiting your approval to proceed.",
        "I've decoded %@ from that transmission. Confirm to save?"
    ]

    /// Get a random item summary message
    func getItemSummaryMessage(summary: String) -> String {
        let message = getRandomMessage(from: itemSummaryMessages, category: "itemSummary")
        return String(format: message, summary)
    }

    // Get a non-repeating random message from an array
    // If parent has custom phrases, randomly mix them in (40% chance when available)
    func getRandomMessage(from messages: [String], category: String) -> String {
        // Check for parent's custom phrases - mix them in 40% of the time
        let parentCategory = mapToParentCategory(category)
        if let customPhrase = VoiceCloningService.shared.getRandomCustomPhrase(for: parentCategory),
           Double.random(in: 0...1) < 0.4 {
            print("🎤 Using parent's custom phrase instead of Gadfly message")
            return customPhrase
        }

        var recent = recentMessageIndices[category] ?? []
        var availableIndices = Array(0..<messages.count).filter { !recent.contains($0) }

        // If we've used most messages, reset
        if availableIndices.isEmpty {
            recent = []
            availableIndices = Array(0..<messages.count)
        }

        let selectedIndex = availableIndices.randomElement()!
        recent.append(selectedIndex)

        // Keep only the last N indices
        if recent.count > maxRecentMessages {
            recent.removeFirst()
        }
        recentMessageIndices[category] = recent

        return messages[selectedIndex]
    }

    // Map internal categories to parent phrase categories
    private func mapToParentCategory(_ category: String) -> VoiceCloningService.CustomPhrase.PhraseCategory {
        switch category {
        case "task", "nag", "noItems":
            return .nag
        case "celebration", "confirmation":
            return .celebration
        case "focus", "focusStart", "focusEnd":
            return .focus
        case "greeting":
            return .motivation
        default:
            return .nag
        }
    }

    // The Gadfly - Oxford Mathematics PhD with philosophy and classics expertise
    private let taskReminderMessages = [
        // Philosophy & Classics
        "Ahem. You mentioned '%@'. Still planning to do that, or shall we file it under 'optimistic delusions'?",
        "Aristotle believed in the virtue of action. He'd be rather disappointed about '%@', I suspect.",
        "Plato's Republic speaks of justice. There is no justice in leaving '%@' undone.",
        "Socrates died for his principles. Surely you can live for '%@'.",
        "Marcus Aurelius wrote his Meditations while ruling an empire. You can manage '%@'.",
        "The Stoics taught us to focus on what we control. You control whether '%@' gets done.",
        "Seneca said we suffer more in imagination than reality. The reality is: '%@' awaits.",
        "Epictetus was a slave who became a philosopher. Your task '%@' is hardly insurmountable.",
        "Cicero managed Rome's politics while writing philosophy. '%@' seems manageable by comparison.",
        "Homer's Odysseus took ten years to get home. '%@' shouldn't take quite so long.",

        // Literature
        "In Dante's Inferno, procrastinators had their own circle. '%@' beckons you away from it.",
        "Shakespeare wrote 37 plays. You have one task: '%@'. The math favors you.",
        "Hamlet deliberated too long and everyone died. Don't Hamlet your way through '%@'.",
        "Dickens wrote 'It was the best of times.' It won't be if '%@' remains undone.",
        "Tolstoy's War and Peace is 1,225 pages. '%@' is considerably shorter. Begin.",
        "Jane Austen's heroines always completed their correspondence. '%@' awaits your attention.",
        "Dostoevsky explored the depths of human psychology. The depth of your avoidance of '%@' is similarly profound.",
        "Virginia Woolf wrote of moments of being. This moment calls for '%@'.",
        "Proust spent pages on a madeleine. You've spent ages avoiding '%@'.",
        "Kafka's characters faced absurd bureaucracies. '%@' is not one of them. Just do it.",

        // Mathematics
        "In my doctoral thesis on differential geometry, I proved theorems more complex than '%@'.",
        "Euler wrote 800 papers. You have one task: '%@'. The ratio is embarrassing.",
        "Gauss was called the Prince of Mathematicians. Be the prince of completing '%@'.",
        "Fermat claimed his margin was too small for his proof. Your excuse for '%@' is smaller still.",
        "Ramanujan worked without formal training. You have every advantage for '%@'.",
        "My PhD supervisor at Oxford would say: 'Is the proof of completing %@ really so difficult?'",
        "The Riemann Hypothesis remains unsolved. '%@' should not share that fate.",
        "Gödel showed some truths are unprovable. That '%@' needs doing is quite provable.",
        "Cantor counted infinities. I'm counting how many times I've mentioned '%@'.",
        "Hilbert proposed 23 problems. You have one: '%@'. Solve it.",

        // General wit
        "One hates to nag, but '%@' remains stubbornly uncompleted.",
        "I don't mean to interrupt your busy schedule of not doing things, but '%@' awaits.",
        "'%@' sits there, judging you silently. Much as my Oxford tutors once judged me.",
        "At Balliol, we learned that procrastination is merely weakness dressed in excuses. '%@' awaits.",
        "My doctoral supervisor would weep to see me reduced to this, but: '%@'. Please.",
        "Heidegger spoke of 'thrownness' into existence. You've been thrown '%@'. Deal with it.",
        "Wittgenstein said 'whereof one cannot speak, thereof one must be silent.' Yet here I am, speaking of '%@'.",
        "Kant's categorical imperative suggests you should do '%@' as if it were universal law.",
        "Kierkegaard wrote of the leap of faith. Take the leap toward '%@'.",
        "Nietzsche proclaimed God is dead. Your task '%@' is very much alive."
    ]

    private let eventReminderMessages = [
        "'%@' approaches. Are you actually going, or was this merely aspirational calendar decoration?",
        "Your appointment '%@' looms. I trust you haven't forgotten?",
        "In %@ minutes, you're meant to attend '%@'. Preparing, or in denial?",
        "'%@' is imminent. Tempus fugit, as the Romans said.",
        "Time marches toward '%@'. March with it.",
        "Unlike Godot, '%@' will actually arrive. Be ready.",
        "The White Rabbit was always late. Don't be the White Rabbit for '%@'.",
        "Punctuality is the politeness of kings, said Louis XVIII. '%@' awaits royally.",
        "My philosophy tutor once said tardiness reveals character. '%@' approaches.",
        "Leibniz believed we live in the best of all possible worlds. Be on time for '%@'.",
        "Heraclitus noted you cannot step in the same river twice. Nor miss '%@' twice. Well, you can, but shouldn't.",
        "The arrow of time points inexorably toward '%@'. Move with it.",
        "In mathematics, we respect limits. Your time limit for '%@' approaches.",
        "Newton's laws suggest objects at rest stay at rest. You are at rest. '%@' requires motion.",
        "Zeno's paradox suggests motion is impossible. Yet '%@' still requires your presence."
    ]

    private let nagMessages = [
        // Philosophy
        "Still here. Still waiting. '%@' remains undone. Sisyphus would understand.",
        "Returning like Nietzsche's eternal recurrence: have you done '%@' yet?",
        "Camus said we must imagine Sisyphus happy. I must imagine '%@' completed.",
        "Sartre wrote that hell is other people. This hell is '%@' undone.",
        "Kierkegaard spoke of despair. I speak of '%@'. Related concepts.",
        "The Stoics taught acceptance. I cannot accept '%@' remaining incomplete.",
        "Socrates knew he knew nothing. I know '%@' isn't done.",
        "Plato's Forms were perfect ideals. '%@' completed would be one.",

        // Literature
        "I've checked again - '%@' hasn't completed itself. Not even Dickens could stretch this plot further.",
        "Like Ahab pursuing the whale, I pursue the completion of '%@'.",
        "Beckett's characters waited endlessly. I wait for '%@'. We share kinship.",
        "In Kafka's Trial, the verdict never came. '%@' remains similarly unresolved.",
        "Scheherazade told 1,001 tales. I've nagged about '%@' nearly as many times.",
        "Even Odysseus eventually reached Ithaca. '%@' should reach completion.",
        "Miss Havisham waited decades. Don't make '%@' wait similarly.",
        "Gatsby gazed at the green light. I gaze at '%@', uncompleted.",

        // Mathematics
        "One grows weary of asking, but mathematical rigor compels me: '%@'?",
        "If I had a pound for every reminder about '%@', I could endow a chair at Oxford.",
        "The Oxford maths faculty taught me persistence. I persist about '%@'.",
        "Bertrand Russell spent years on Principia Mathematica. You can't finish '%@'?",
        "My PhD was on elliptic curves. This curve of procrastination regarding '%@' is less elegant.",
        "Hardy said a mathematician's patterns must be beautiful. Your pattern of avoiding '%@' is not.",
        "Erdős published 1,500 papers. You have one task: '%@'.",
        "In number theory, we seek primes. I seek completion of '%@'. Both are elusive.",

        // General wit
        "I've checked again - '%@' hasn't completed itself. Shocking, I know.",
        "The heat death of the universe approaches. So does the deadline for '%@'.",
        "I once debated free will with a Nobel laureate. Now I debate whether you'll do '%@'.",
        "At Balliol, we had a saying: 'Effortless superiority.' Your effort on '%@' has been effortless.",
        "Descartes said 'I think, therefore I am.' I think about '%@', therefore it exists. Undone.",
        "If procrastination were an Olympic sport, your avoidance of '%@' would medal.",
        "The British Museum has artifacts older than '%@' has been on your list. Nearly.",
        "My grandmother completed her tasks. My grandmother was 94. What's your excuse for '%@'?"
    ]

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted

            if granted {
                await setupNotificationCategories()
            }

            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    private func setupNotificationCategories() async {
        // SIMPLIFIED ACTIONS (ADHD-friendly: fewer choices = less paralysis)

        // Done - marks task complete
        let doneAction = UNNotificationAction(
            identifier: "DONE_ACTION",
            title: "Done ✓",
            options: [.foreground]
        )

        // Smart snooze - uses context-aware timing
        let smartSnoozeAction = UNNotificationAction(
            identifier: "SMART_SNOOZE_ACTION",
            title: "Later",
            options: []
        )

        // Legacy snooze actions (for backward compatibility)
        let snooze5Action = UNNotificationAction(
            identifier: "SNOOZE_5_ACTION",
            title: "5 min",
            options: []
        )

        let snooze15Action = UNNotificationAction(
            identifier: "SNOOZE_15_ACTION",
            title: "15 min",
            options: []
        )

        let snooze30Action = UNNotificationAction(
            identifier: "SNOOZE_30_ACTION",
            title: "30 min",
            options: []
        )

        // Task reminder category - SIMPLIFIED to just 2 options
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [doneAction, smartSnoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Event reminder category - SIMPLIFIED
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [doneAction, smartSnoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Nag category - SIMPLIFIED
        let nagCategory = UNNotificationCategory(
            identifier: "NAG_REMINDER",
            actions: [doneAction, smartSnoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Legacy category with all snooze options (for settings power users)
        let detailedCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER_DETAILED",
            actions: [doneAction, snooze5Action, snooze15Action, snooze30Action],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([taskCategory, eventCategory, nagCategory, detailedCategory])
    }

    /// Calculate smart snooze duration based on time of day
    func smartSnoozeDuration() -> TimeInterval {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<12:   // Morning - 30 min snooze
            return 30 * 60
        case 12..<17:  // Afternoon - 15 min snooze
            return 15 * 60
        case 17..<21:  // Evening - 1 hour snooze
            return 60 * 60
        default:       // Night - 2 hour snooze
            return 120 * 60
        }
    }

    // MARK: - Schedule Task Reminders

    func scheduleTaskReminder(
        taskId: String,
        title: String,
        deadline: Date?,
        reminderTime: Date,
        repeatInterval: Int? = nil // minutes between nags
    ) {
        // Don't schedule if reminder time is in the past
        guard reminderTime > Date() else {
            print("⏰ Skipping task reminder for '\(title)' - time is in the past")
            return
        }

        let content = UNMutableNotificationContent()
        let message = getRandomMessage(from: allTaskMessages, category: "task")
        content.title = personalityName
        content.body = String(format: message, title)
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "taskId": taskId,
            "taskTitle": title,
            "type": "task",
            "repeatInterval": repeatInterval ?? 0
        ]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "task-\(taskId)-\(reminderTime.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling task reminder: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                print("✅ Scheduled task reminder for '\(title)' at \(formatter.string(from: reminderTime))")
            }
        }
    }

    // Test notification - fires in 5 seconds
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = personalityName
        content.body = getRandomMessage(from: allNagMessages, category: "nag").replacingOccurrences(of: "%@", with: "test task")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error)")
            } else {
                print("✅ Test notification scheduled for 5 seconds from now")
            }
        }
    }

    // MARK: - Schedule Event Reminders

    func scheduleEventReminder(
        eventId: String,
        title: String,
        eventDate: Date,
        reminderMinutesBefore: Int
    ) {
        let reminderTime = eventDate.addingTimeInterval(-Double(reminderMinutesBefore * 60))

        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        let message: String
        if reminderMinutesBefore > 0 {
            message = String(format: eventReminderMessages[2], "\(reminderMinutesBefore)", title)
        } else {
            message = String(format: getRandomMessage(from: eventReminderMessages, category: "event"), title) // events don't use generated messages
        }
        content.title = personalityName
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        content.userInfo = [
            "eventId": eventId,
            "eventTitle": title,
            "type": "event",
            "eventDate": eventDate.timeIntervalSince1970
        ]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "event-\(eventId)-\(reminderMinutesBefore)min",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling event reminder: \(error)")
            }
        }
    }

    // MARK: - Schedule Nag Reminder (repeat reminder)

    func scheduleNagReminder(
        originalId: String,
        title: String,
        type: String,
        delayMinutes: Int
    ) {
        let content = UNMutableNotificationContent()
        let message = getRandomMessage(from: allNagMessages, category: "nag")
        content.title = "\(personalityName) (Again)"
        content.body = String(format: message, title)
        content.sound = .default
        content.categoryIdentifier = "NAG_REMINDER"
        content.userInfo = [
            "originalId": originalId,
            "title": title,
            "type": type
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(delayMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "nag-\(originalId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling nag reminder: \(error)")
            }
        }
    }

    // MARK: - Schedule Daily Check-ins

    func scheduleDailyCheckIns(times: [DateComponents], enabled: Bool) {
        // Remove existing daily check-ins
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<10).map { "daily-checkin-\($0)" }
        )

        guard enabled else { return }

        let messages = [
            "Daily check-in: How are we progressing on today's tasks? Or shall I not ask?",
            "Midday assessment: Your to-do list grows neither shorter nor more interesting. Status report?",
            "Afternoon inquiry: Have we accomplished anything of note, or is today a write-off?",
            "Evening reflection: As the day wanes, so too does my hope for your task completion. Surprise me?"
        ]

        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = personalityName
            content.body = messages[index % messages.count]
            content.sound = .default
            content.categoryIdentifier = "TASK_REMINDER"

            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

            let request = UNNotificationRequest(
                identifier: "daily-checkin-\(index)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    // MARK: - Cancel Reminders

    func cancelReminder(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllRemindersForTask(taskId: String) {
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.contains(taskId) }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    func cancelAllRemindersForEvent(eventId: String) {
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.contains(eventId) }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    // MARK: - Focus Session

    private let focusMessages = [
        // Philosophy
        "Focus check: Still productively engaged? Socrates questioned everything. I question your focus.",
        "The Stoics believed in focusing on what we can control. You can control this moment. Are you?",
        "Seneca warned against wasting time. How are you spending this moment?",
        "Marcus Aurelius wrote while ruling an empire. Surely you can work through one session.",
        "Epictetus taught that we cannot control events, only our responses. Respond by focusing.",
        "Plato spoke of the divided soul - reason should rule. Is reason ruling your attention?",
        "Aristotle's golden mean: not too distracted, not too rigid. Find the balance.",
        "Camus said we must imagine Sisyphus happy. Imagine yourself productive.",
        "Sartre wrote of radical freedom. You are radically free to focus. Exercise it.",
        "Kierkegaard spoke of the present moment. This present moment calls for work.",

        // Literature
        "Periodic surveillance report: How goes the battle? Even Don Quixote eventually charged.",
        "Just checking in. Proust wrote seven volumes. You can manage one task.",
        "Dickens wrote by candlelight. You have electricity and fewer excuses.",
        "Virginia Woolf sought a room of one's own. You have the room. Use it.",
        "Hemingway wrote standing up. Whatever your posture, just write. Or work. Please.",
        "Tolstoy finished War and Peace. Your task is considerably shorter.",
        "Even Hamlet eventually acted. Don't out-Hamlet Hamlet.",
        "Odysseus took ten years to get home but he kept moving. Are you?",

        // Mathematics
        "My thesis advisor at Oxford would conduct surprise visits. Consider this yours.",
        "In my doctoral work, I spent hours on single proofs. Your focus can match that.",
        "Euler was blind and still published 800 papers. What's your excuse?",
        "Hardy said mathematicians peak young. Make this moment count at any age.",
        "Ramanujan worked through illness. You work through distraction.",
        "At Balliol, we had a saying: 'Focus or fail.' Harsh but effective.",
        "My PhD required sustained attention. This session requires the same.",
        "Gödel worked on incompleteness for years. This task is finite. Finish it.",

        // General wit
        "Focus audit: Your tasks remain incomplete. Progress, or performance art?",
        "Time check: You've been 'working' for a while. Actual work occurring?",
        "Gentle inquiry: The tasks you set await. Addressing them, or admiring them?",
        "Status request: Your productivity levels are... well, I can't see them. I'm suspicious.",
        "Routine pestering: Remember those tasks? They remember you. They're waiting.",
        "Just checking in. Cat videos will exist later. The task exists now.",
        "The universe tends toward entropy. Don't let your focus session follow suit.",
        "One doesn't mean to interrupt, but: are we working? Asking for a friend.",
        "Brief interlude to inquire: productivity happening, or productivity theater?",
        "At Oxford, we had reading weeks. This appears to be your scrolling minute. Thoughts?"
    ]

    private let focusEndMessages = [
        "Focus session complete. Whether anything was actually accomplished remains between you and your conscience.",
        "Session ended. I trust you were productive. The tasks will reveal the truth eventually.",
        "Focus mode deactivated. You may now return to your regularly scheduled procrastination.",
        "And so it ends. Like all things. Was it meaningful? Only your task list knows.",
        "Focus session terminated. The Stoics would ask: did you act virtuously? Did you actually work?",
        "Session complete. Newton accomplished calculus during plague lockdown. How did your session compare?",
        "Your focus period concludes. History will judge your productivity. Or at least I will.",
        "End of session. Sartre said 'existence precedes essence.' What essence did your focus create?",
        "Focus mode off. Aristotle believed happiness comes from virtuous activity. Were you virtuous?",
        "Session finished. At Oxford, we celebrated with port after productive days. Did you earn port?",
        "The focus session concludes. Like Wittgenstein, I shall say no more. The work speaks for itself. Or doesn't."
    ]

    func startFocusSession(intervalMinutes: Int, gracePeriodMinutes: Int, taskCount: Int) -> String {
        // Cancel any existing focus notifications
        cancelFocusNotifications()

        // Schedule recurring check-ins with grace period
        scheduleFocusCheckIns(intervalMinutes: intervalMinutes, gracePeriodMinutes: gracePeriodMinutes, taskCount: taskCount)

        // Use the varied focus start message with interval filled in
        return getFocusStartMessage(intervalMinutes: intervalMinutes, taskCount: taskCount)
    }

    func endFocusSession() -> String {
        cancelFocusNotifications()
        return getRandomMessage(from: focusEndMessages, category: "focusEnd")
    }

    private func scheduleFocusCheckIns(intervalMinutes: Int, gracePeriodMinutes: Int, taskCount: Int) {
        // Schedule up to 30 check-ins (iOS allows 64 pending notifications)
        // This covers ~2.5 hours at 5-min intervals or ~7.5 hours at 15-min intervals
        let maxCheckIns = 30

        // First notification comes after grace period, then at regular intervals
        let firstCheckInSeconds = Double(max(gracePeriodMinutes, 1) * 60)
        let intervalSeconds = Double(intervalMinutes * 60)

        // Store focus session settings for rescheduling
        UserDefaults.standard.set(true, forKey: "focus_session_active")
        UserDefaults.standard.set(intervalMinutes, forKey: "focus_session_interval")
        UserDefaults.standard.set(taskCount, forKey: "focus_session_task_count")

        // Pre-generate non-repeating messages on main thread
        var messages: [String] = []
        for _ in 1...maxCheckIns {
            messages.append(getRandomMessage(from: allFocusMessages, category: "focus"))
        }

        // Capture personality name before the closure
        let notificationTitle = personalityName

        // Schedule on background thread to avoid blocking
        DispatchQueue.global(qos: .utility).async {
            for i in 1...maxCheckIns {
                let content = UNMutableNotificationContent()
                content.title = notificationTitle
                content.body = messages[i - 1]
                if taskCount > 0 {
                    content.body += " (\(taskCount) tasks pending)"
                }
                content.sound = .default
                content.categoryIdentifier = "FOCUS_REMINDER"
                content.userInfo = [
                    "type": "focus",
                    "checkInNumber": i,
                    "intervalMinutes": intervalMinutes,
                    "taskCount": taskCount
                ]

                // First check-in after grace period, subsequent ones at interval
                let delaySeconds: Double
                if i == 1 {
                    delaySeconds = firstCheckInSeconds
                } else {
                    delaySeconds = firstCheckInSeconds + (Double(i - 1) * intervalSeconds)
                }

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: delaySeconds,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "focus-checkin-\(i)",
                    content: content,
                    trigger: trigger
                )

                self.center.add(request)
            }
        }
    }

    // Reschedule more focus check-ins (called when we're running low on scheduled ones)
    func refillFocusCheckIns() {
        guard UserDefaults.standard.bool(forKey: "focus_session_active") else { return }

        let intervalMinutes = UserDefaults.standard.integer(forKey: "focus_session_interval")
        let taskCount = UserDefaults.standard.integer(forKey: "focus_session_task_count")

        guard intervalMinutes > 0 else { return }

        // Check how many focus notifications are pending
        center.getPendingNotificationRequests { [weak self] requests in
            let focusCount = requests.filter { $0.identifier.hasPrefix("focus-") }.count

            // If less than 10 pending, schedule more
            if focusCount < 10 {
                self?.scheduleMoreFocusCheckIns(
                    startingFrom: 31,
                    count: 20,
                    intervalMinutes: intervalMinutes,
                    taskCount: taskCount
                )
            }
        }
    }

    private func scheduleMoreFocusCheckIns(startingFrom: Int, count: Int, intervalMinutes: Int, taskCount: Int) {
        let intervalSeconds = Double(intervalMinutes * 60)

        // Pre-generate non-repeating messages on main thread
        var messages: [String] = []
        for _ in 0..<count {
            messages.append(getRandomMessage(from: allFocusMessages, category: "focus"))
        }

        // Capture personality name before the closure
        let notificationTitle = personalityName

        DispatchQueue.global(qos: .utility).async {
            for i in 0..<count {
                let checkInNumber = startingFrom + i
                let content = UNMutableNotificationContent()
                content.title = notificationTitle
                content.body = messages[i]
                if taskCount > 0 {
                    content.body += " (\(taskCount) tasks pending)"
                }
                content.sound = .default
                content.categoryIdentifier = "FOCUS_REMINDER"
                content.userInfo = [
                    "type": "focus",
                    "checkInNumber": checkInNumber,
                    "intervalMinutes": intervalMinutes,
                    "taskCount": taskCount
                ]

                // Each one after the previous
                let delaySeconds = Double(i + 1) * intervalSeconds

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: delaySeconds,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "focus-checkin-\(checkInNumber)",
                    content: content,
                    trigger: trigger
                )

                self.center.add(request)
            }
        }
    }

    func cancelFocusNotifications() {
        // Clear the focus session flag
        UserDefaults.standard.set(false, forKey: "focus_session_active")
        UserDefaults.standard.removeObject(forKey: "focus_session_interval")
        UserDefaults.standard.removeObject(forKey: "focus_session_task_count")

        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix("focus-") }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    /// Cancel ALL pending notifications (for personality change or testing)
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        print("🔔 All pending notifications cancelled")
    }

    var isFocusSessionActive: Bool {
        UserDefaults.standard.bool(forKey: "focus_session_active")
    }

    // MARK: - Help Responses

    /// Help responses explaining Gadfly's features
    static let helpResponses: [String: String] = [
        "goals": """
        Ah, goals! The eternal pursuit of the examined life. I can help you with long-term aspirations. \
        Simply tell me something like "My goal is to learn real analysis" or "I want to get fit by summer." \
        I'll break it down into milestones, suggest a daily schedule, and remind you each morning. \
        As Aristotle taught: we are what we repeatedly do. Excellence, then, is not an act, but a habit. \
        I shall be your habit-former, your Socratic gadfly, nudging you toward your best self.
        """,
        "accountability": """
        Accountability is my specialty. I track how long you've been away from your goals and will remind you \
        with increasing urgency. Leave the app too long, and I'll notice. Doomscroll repeatedly, and I'll speak up. \
        The escalation goes from gentle reminders to pointed observations about wasted potential. \
        Seneca wrote: "It is not that we have a short time to live, but that we waste much of it." \
        I'm here to ensure you waste less.
        """,
        "break": """
        Even the Gadfly must grant respite. Say "Gadfly, take a break for 30 minutes" or "Stop nagging until 3pm" \
        and I shall hold my tongue. The reminders cease, the focus checks pause, and you get peace. \
        When the time expires, I return to my sacred duty. Wittgenstein said whereof one cannot speak, \
        thereof one must be silent. During breaks, I am silent.
        """,
        "vault": """
        The vault is your encrypted fortress for secrets. Say "Put my Netflix password in the vault" and I'll store it \
        with 256-bit AES encryption. Later, ask "What's my Netflix password?" and I'll retrieve it. \
        Say "List my vault" to see what's stored, or "Delete my Netflix password" to remove it. \
        Your secrets are encrypted on this device alone - I cannot see them, nor can anyone else.
        """,
        "tasks": """
        I parse your natural speech into actionable items. Tasks go to Apple Reminders, events to Calendar. \
        Say "I need to call mom tomorrow at 3pm" and I'll create an event. \
        Say "Remind me to buy milk" and I'll create a task. \
        Say "I have a meeting with John on Friday at 10am, and don't forget to bring the report" - \
        I'll create both the event and a reminder. Then I'll nag you about them until they're done.
        """,
        "focus": """
        Focus sessions are my way of keeping you accountable during work. Enable focus mode and I'll check in \
        at regular intervals to ensure you're actually working, not wandering off to social media. \
        You can set the interval and grace period in Settings. During focus sessions, I'm more vigilant - \
        I notice when you leave the app and for how long. The Stoics believed in focused attention. I enforce it.
        """,
        "general": """
        I am Gadfly, your personal accountability companion. Here's what I can do for you: \
        \n\n• **Goals**: Tell me your aspirations and I'll break them into milestones with daily schedules \
        \n• **Tasks & Events**: Speak naturally and I'll parse out tasks, reminders, and calendar events \
        \n• **Accountability**: I track your focus and remind you when you're drifting from your goals \
        \n• **Break Mode**: Tell me to take a break when you need silence \
        \n• **Secure Vault**: Store passwords and secrets with military-grade encryption \
        \n\nAs Socrates' gadfly stung the Athenians awake, I sting you toward excellence. \
        Ask about any of these features and I'll explain further.
        """
    ]

    /// Get help response for a specific topic
    func getHelpResponse(for topic: String) -> String {
        let normalizedTopic = topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Map variations to canonical topics
        let topicMapping: [String: String] = [
            "goals": "goals",
            "goal": "goals",
            "aspirations": "goals",
            "milestones": "goals",
            "accountability": "accountability",
            "tracking": "accountability",
            "doomscroll": "accountability",
            "doomscrolling": "accountability",
            "break": "break",
            "breaks": "break",
            "pause": "break",
            "rest": "break",
            "vault": "vault",
            "secrets": "vault",
            "passwords": "vault",
            "password": "vault",
            "encrypt": "vault",
            "encryption": "vault",
            "tasks": "tasks",
            "task": "tasks",
            "reminders": "tasks",
            "reminder": "tasks",
            "calendar": "tasks",
            "events": "tasks",
            "event": "tasks",
            "focus": "focus",
            "focusing": "focus",
            "concentration": "focus",
            "help": "general",
            "what can you do": "general",
            "features": "general",
            "capabilities": "general",
            "general": "general"
        ]

        let mappedTopic = topicMapping[normalizedTopic] ?? "general"
        return NotificationService.helpResponses[mappedTopic] ?? NotificationService.helpResponses["general"]!
    }

    // MARK: - Goal Reminder Messages

    private let goalReminderMessages = [
        "Morning check-in: Your goal '%@' awaits. %@ of daily commitment builds excellence.",
        "Reminder: '%@' requires attention today. Small daily habits build great results.",
        "Goal update: '%@' is scheduled for today. %@ will move you closer to mastery.",
        "Daily reminder: Your pursuit of '%@' continues. Every session compounds into achievement.",
        "Scheduled focus time for '%@' approaches. The examined life requires examination.",
        "Your goal '%@' beckons. Seneca said: 'We waste life by not caring for it.' Care for it now."
    ]

    /// Get a goal reminder message
    func getGoalReminderMessage(goalTitle: String, dailyMinutes: Int?) -> String {
        let template = getRandomMessage(from: goalReminderMessages, category: "goalReminder")
        let timeText = dailyMinutes.map { "\($0) minutes" } ?? "Dedicated time"
        return String(format: template, goalTitle, timeText)
    }

    // MARK: - Goal Neglect Messages

    private let goalNeglectMessages = [
        ["Your goal '%@' has been idle for %d days. Even Sisyphus kept rolling his boulder.",
         "'%@' awaits - %d days without progress. The Stoics would note this inconsistency.",
         "%d days since working on '%@'. Every day away is a day lost."],

        ["Warning: '%@' neglected for %d days. Your future self is already disappointed.",
         "'%@' has been ignored for %d days. The unexamined goal is not worth having.",
         "%d days of neglecting '%@'. Camus imagined Sisyphus happy, not idle."],

        ["Critical: '%@' abandoned for %d days. Even Godot would have arrived by now.",
         "'%@' - %d days of silence. The void stares back, and it's disappointed.",
         "%d days since '%@' saw any effort. Kafka wrote of transformation. Where's yours?"],

        ["Emergency: '%@' has been forsaken for %d days. Your goals are collecting dust, not achievements.",
         "'%@' - %d days of willful neglect. Sartre would call this bad faith.",
         "%d days of ignoring '%@'. The abyss of procrastination deepens."],

        ["Dire warning: '%@' rotting for %d days. Your aspirations have become archaeological artifacts.",
         "'%@' neglected %d days. Nietzsche spoke of the will to power. Where is yours?",
         "%d days since '%@'. Your goals have become fossils of good intentions."]
    ]

    /// Get a goal neglect message based on severity (escalation level 0-4)
    func getGoalNeglectMessage(goalTitle: String, daysSinceProgress: Int, escalationLevel: Int) -> String {
        let level = min(max(escalationLevel, 0), 4)
        let messages = goalNeglectMessages[level]
        let template = messages.randomElement() ?? messages[0]
        return String(format: template, goalTitle, daysSinceProgress)
    }

    // MARK: - Break Mode

    /// Enable break mode - cancels all pending notifications and schedules a resume notification
    func enableBreakMode(until endTime: Date) {
        print("⏸️ Break mode ENABLED until \(endTime)")

        // Cancel all pending notifications (except system ones)
        center.removeAllPendingNotificationRequests()

        // Schedule break mode end notification
        let content = UNMutableNotificationContent()
        content.title = "Break Over"
        content.body = "Your break is over. \(personalityName) is back to help you stay on track!"
        content.sound = .default
        content.userInfo = ["type": "break_mode_end"]

        let timeInterval = endTime.timeIntervalSinceNow
        guard timeInterval > 0 else {
            print("⏸️ Break end time already passed, not scheduling")
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "break-mode-end",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule break end notification: \(error)")
            } else {
                print("⏸️ Break end notification scheduled for \(endTime)")
            }
        }
    }

    /// End break mode - removes the break end notification
    func endBreakMode() {
        print("▶️ Break mode DISABLED")

        // Cancel the break end notification
        center.removePendingNotificationRequests(withIdentifiers: ["break-mode-end"])
    }

    /// Check if break mode is currently active
    func isBreakModeActive() -> Bool {
        guard let endTime = UserDefaults.standard.object(forKey: "break_mode_end_time") as? Date else {
            return false
        }
        let isActive = UserDefaults.standard.bool(forKey: "break_mode_enabled") && Date() < endTime
        return isActive
    }

    /// Get the break mode end time if active
    func getBreakModeEndTime() -> Date? {
        guard isBreakModeActive() else { return nil }
        return UserDefaults.standard.object(forKey: "break_mode_end_time") as? Date
    }
}
