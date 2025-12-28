import Foundation

/// Tracks recently spoken phrases to avoid repetition - ADHD users hate hearing the same thing twice
@MainActor
class RecentlySpokenService: ObservableObject {
    static let shared = RecentlySpokenService()

    // MARK: - Properties

    /// Recently spoken phrases with timestamps
    private var recentPhrases: [String: Date] = [:]

    /// How long before a phrase can be repeated (in seconds)
    private let repeatCooldown: TimeInterval = 300 // 5 minutes

    /// Maximum phrases to track
    private let maxTrackedPhrases = 100

    /// Count of times each phrase category has been used today
    private var dailyUsage: [String: Int] = [:]

    /// Last reset date for daily usage
    private var lastResetDate: Date = Date()

    // MARK: - Phrase Categories

    enum PhraseCategory: String {
        case greeting = "greeting"
        case celebration = "celebration"
        case encouragement = "encouragement"
        case transition = "transition"
        case question = "question"
        case checkInIntro = "checkin_intro"
        case taskPrompt = "task_prompt"
        case error = "error"
    }

    // MARK: - Initialization

    private init() {
        loadState()
        resetDailyIfNeeded()
    }

    // MARK: - Public Methods

    /// Check if a phrase was recently spoken
    func wasRecentlySpoken(_ phrase: String) -> Bool {
        let key = normalizePhrase(phrase)
        guard let lastSpoken = recentPhrases[key] else { return false }
        return Date().timeIntervalSince(lastSpoken) < repeatCooldown
    }

    /// Mark a phrase as spoken
    func markSpoken(_ phrase: String, category: PhraseCategory? = nil) {
        let key = normalizePhrase(phrase)
        recentPhrases[key] = Date()

        // Track category usage
        if let category = category {
            dailyUsage[category.rawValue, default: 0] += 1
        }

        // Cleanup old phrases
        cleanupOldPhrases()
        saveState()

        print("🗣️ Marked spoken: \(phrase.prefix(30))...")
    }

    /// Get a non-repeated phrase from alternatives
    func getUnspokenAlternative(from alternatives: [String], fallback: String? = nil) -> String {
        // Shuffle to add randomness
        let shuffled = alternatives.shuffled()

        // Find one that wasn't recently spoken
        for phrase in shuffled {
            if !wasRecentlySpoken(phrase) {
                return phrase
            }
        }

        // If all were recently spoken, return fallback or random
        return fallback ?? alternatives.randomElement() ?? ""
    }

    /// Check if user has heard too many of a category today (fatigue detection)
    func isFatigued(category: PhraseCategory, threshold: Int = 10) -> Bool {
        resetDailyIfNeeded()
        return dailyUsage[category.rawValue, default: 0] >= threshold
    }

    /// Get usage count for a category
    func usageCount(for category: PhraseCategory) -> Int {
        resetDailyIfNeeded()
        return dailyUsage[category.rawValue, default: 0]
    }

    /// Should we skip the intro based on fatigue?
    func shouldSkipIntro(for category: PhraseCategory) -> Bool {
        // Skip after 3 uses of same intro category
        return usageCount(for: category) >= 3
    }

    /// Clear all tracking (for testing or reset)
    func clearAll() {
        recentPhrases.removeAll()
        dailyUsage.removeAll()
        saveState()
    }

    // MARK: - Celebration Variety

    /// Get a celebration message that hasn't been used recently
    func getCelebration(intensity: CelebrationIntensity = .standard) -> String {
        let messages = celebrationMessages(for: intensity)
        let result = getUnspokenAlternative(from: messages)
        markSpoken(result, category: .celebration)
        return result
    }

    enum CelebrationIntensity {
        case micro, standard, major, epic
    }

    private func celebrationMessages(for intensity: CelebrationIntensity) -> [String] {
        switch intensity {
        case .micro:
            return [
                "Nice!", "Done!", "Check!", "Got it!", "Boom!",
                "Yes!", "Sweet!", "Cool!", "Okay!", "Right on!"
            ]
        case .standard:
            return [
                "Great job!", "You did it!", "Awesome work!", "Nicely done!",
                "That's the way!", "Killed it!", "Nailed it!", "Perfect!",
                "Way to go!", "You're crushing it!", "Look at you go!",
                "That's what I'm talking about!", "Fantastic!", "Brilliant!"
            ]
        case .major:
            return [
                "Incredible work!", "You're on fire!", "Absolutely amazing!",
                "That was impressive!", "You're unstoppable!", "Legendary!",
                "Outstanding!", "Phenomenal!", "You're a rockstar!",
                "That deserves a celebration!", "Mind blown!", "Epic win!"
            ]
        case .epic:
            return [
                "HOLY COW! You actually did it!", "This is HUGE!",
                "I am SO proud of you right now!", "You just made history!",
                "Stop everything - we need to celebrate this!",
                "This calls for confetti!", "You absolute legend!",
                "I can't believe you pulled that off!", "Champion status!"
            ]
        }
    }

    // MARK: - Encouragement Variety

    /// Get an encouragement message that hasn't been used recently
    func getEncouragement(context: EncouragementContext = .general) -> String {
        let messages = encouragementMessages(for: context)
        let result = getUnspokenAlternative(from: messages)
        markSpoken(result, category: .encouragement)
        return result
    }

    enum EncouragementContext {
        case general, struggling, starting, continuing, almostDone
    }

    private func encouragementMessages(for context: EncouragementContext) -> [String] {
        switch context {
        case .general:
            return [
                "You've got this!", "Keep going!", "You're doing great!",
                "One step at a time!", "Progress, not perfection!",
                "Every little bit counts!", "You're making it happen!"
            ]
        case .struggling:
            return [
                "It's okay to take a break.", "Be gentle with yourself.",
                "This is hard, and that's okay.", "You don't have to be perfect.",
                "Just do what you can.", "Tomorrow is a new day.",
                "You're doing your best, and that's enough."
            ]
        case .starting:
            return [
                "Let's do this!", "Here we go!", "Time to shine!",
                "Ready when you are!", "Let's get started!",
                "One small step...", "You've already begun!"
            ]
        case .continuing:
            return [
                "Keep that momentum!", "You're in the zone!",
                "Look at you go!", "Don't stop now!",
                "You're making progress!", "Almost there!"
            ]
        case .almostDone:
            return [
                "So close!", "Just a little more!", "The finish line is in sight!",
                "You can taste victory!", "Final push!", "Nearly there!"
            ]
        }
    }

    // MARK: - Skip Prompts

    /// Get a "skip" response that isn't repetitive
    func getSkipResponse() -> String {
        let messages = [
            "No worries, moving on!",
            "Skipped - no judgment here.",
            "That's okay! Next one.",
            "Got it, we'll circle back if needed.",
            "All good! Let's keep going.",
            "Understood. What's next?",
            "No problem at all.",
            "Skipping ahead!"
        ]
        let result = getUnspokenAlternative(from: messages)
        markSpoken(result, category: .transition)
        return result
    }

    /// Get a "done" acknowledgment that isn't repetitive
    func getDoneResponse() -> String {
        let messages = [
            "Done!", "Checked off!", "Complete!", "Finished!",
            "That's done!", "All set!", "Marked complete!",
            "Off the list!", "Accomplished!"
        ]
        let result = getUnspokenAlternative(from: messages)
        markSpoken(result, category: .celebration)
        return result
    }

    // MARK: - Private Methods

    private func normalizePhrase(_ phrase: String) -> String {
        // Normalize for comparison (lowercase, trimmed)
        return phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanupOldPhrases() {
        let cutoff = Date().addingTimeInterval(-repeatCooldown * 2)
        recentPhrases = recentPhrases.filter { $0.value > cutoff }

        // Limit total tracked
        if recentPhrases.count > maxTrackedPhrases {
            let sorted = recentPhrases.sorted { $0.value > $1.value }
            recentPhrases = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(maxTrackedPhrases)))
        }
    }

    private func resetDailyIfNeeded() {
        if !Calendar.current.isDateInToday(lastResetDate) {
            dailyUsage.removeAll()
            lastResetDate = Date()
            saveState()
            print("📅 Daily phrase usage reset")
        }
    }

    // MARK: - Persistence

    private let recentPhrasesKey = "recentlySpoken_phrases"
    private let dailyUsageKey = "recentlySpoken_daily"
    private let lastResetKey = "recentlySpoken_lastReset"

    private func saveState() {
        let defaults = UserDefaults.standard

        // Convert dates to timestamps for storage
        let timestamps = recentPhrases.mapValues { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(timestamps) {
            defaults.set(data, forKey: recentPhrasesKey)
        }

        if let data = try? JSONEncoder().encode(dailyUsage) {
            defaults.set(data, forKey: dailyUsageKey)
        }

        defaults.set(lastResetDate.timeIntervalSince1970, forKey: lastResetKey)
    }

    private func loadState() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: recentPhrasesKey),
           let timestamps = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            recentPhrases = timestamps.mapValues { Date(timeIntervalSince1970: $0) }
        }

        if let data = defaults.data(forKey: dailyUsageKey),
           let usage = try? JSONDecoder().decode([String: Int].self, from: data) {
            dailyUsage = usage
        }

        if let timestamp = defaults.object(forKey: lastResetKey) as? TimeInterval {
            lastResetDate = Date(timeIntervalSince1970: timestamp)
        }
    }
}
