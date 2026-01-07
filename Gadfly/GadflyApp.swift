import SwiftUI
import UIKit

@main
struct GadflyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var watchConnectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.selectedTheme.colorScheme)
                .id(appState.selectedColorTheme.rawValue) // Force rebuild when theme changes
                .task {
                    // Request notification permissions
                    await NotificationService.shared.requestAuthorization()
                    // Activate Watch Connectivity
                    PhoneConnectivityManager.shared.activate()
                }
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - App Version (Kids/Teens/Adults)

enum AppVersion: String, CaseIterable, Identifiable {
    case kids = "kids"
    case teens = "teens"
    case adults = "adults"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kids: return "Kids"
        case .teens: return "Teens"
        case .adults: return "Adults"
        }
    }

    var description: String {
        switch self {
        case .kids: return "Simple & fun"
        case .teens: return "School & life"
        case .adults: return "Full features"
        }
    }
}

// MARK: - Color Themes

enum ColorTheme: String, CaseIterable, Identifiable {
    // Original
    case gadfly = "Gadfly"
    // 39+ Themes from fitness app
    case defaultBlue = "Default"
    case emerald = "Emerald"
    case orange = "Orange"
    case gold = "Gold"
    case ocean = "Ocean"
    case slate = "Slate"
    case rose = "Rose"
    case crimson = "Crimson"
    case bronze = "Bronze"
    case sunset = "Sunset"
    case olive = "Olive"
    case steel = "Steel"
    case charcoal = "Charcoal"
    case maroon = "Maroon"
    case atom = "Atom"
    case aubergine = "Aubergine"
    case forest = "Forest"
    case onyx = "Onyx"
    case cyan = "Cyan"
    case coral = "Coral"
    case nord = "Nord"
    case navy = "Navy"
    case amber = "Amber"
    case midnight = "Midnight"
    case matrix = "Matrix"
    case lemon = "Lemon"
    case cobalt = "Cobalt"
    case silver = "Silver"
    case tropical = "Tropical"
    case arctic = "Arctic"
    case blush = "Blush"
    case sunflower = "Sunflower"
    case cream = "Cream"
    case cloud = "Cloud"
    case royal = "Royal"
    case lavender = "Lavender"
    case electric = "Electric"
    case tangerine = "Tangerine"
    case pastel = "Pastel"
    case neon = "Neon"

    var id: String { self.rawValue }

    // MARK: - Primary Accent Colors (from fitness app themes)

    var accent: Color {
        switch self {
        case .gadfly: return Color(hex: "FFBF00")
        case .defaultBlue: return Color(hex: "0ea5e9")
        case .emerald: return Color(hex: "20A271")
        case .orange: return Color(hex: "E96825")
        case .gold: return Color(hex: "DEA900")
        case .ocean: return Color(hex: "0E9DD3")
        case .slate: return Color(hex: "EF3E75")
        case .rose: return Color(hex: "EF3E75")
        case .crimson: return Color(hex: "E60A00")
        case .bronze: return Color(hex: "A36B31")
        case .sunset: return Color(hex: "F08000")
        case .olive: return Color(hex: "7a9c0f")
        case .steel: return Color(hex: "5294E2")
        case .charcoal: return Color(hex: "999999")
        case .maroon: return Color(hex: "FFC627")
        case .atom: return Color(hex: "98C379")
        case .aubergine: return Color(hex: "1164A3")
        case .forest: return Color(hex: "E7C12e")
        case .onyx: return Color(hex: "38978D")
        case .cyan: return Color(hex: "0ba8ca")
        case .coral: return Color(hex: "F2777A")
        case .nord: return Color(hex: "a3be8c")
        case .navy: return Color(hex: "73AD0D")
        case .amber: return Color(hex: "F7941E")
        case .midnight: return Color(hex: "00B993")
        case .matrix: return Color(hex: "13C217")
        case .lemon: return Color(hex: "efd213")
        case .cobalt: return Color(hex: "FFC600")
        case .silver: return Color(hex: "3873AE")
        case .tropical: return Color(hex: "4EBDA6")
        case .arctic: return Color(hex: "2D9EE0")
        case .blush: return Color(hex: "F0A2B8")
        case .sunflower: return Color(hex: "E72D25")
        case .cream: return Color(hex: "F3951D")
        case .cloud: return Color(hex: "0070d2")
        case .royal: return Color(hex: "f0b31a")
        case .lavender: return Color(hex: "9B4DCA")
        case .electric: return Color(hex: "F7A800")
        case .tangerine: return Color(hex: "FF3300")
        case .pastel: return Color(hex: "b19cd9")
        case .neon: return Color(hex: "f9fc00")
        }
    }

    var accentDark: Color {
        // Darker variant of accent
        switch self {
        case .gadfly: return Color(hex: "CC9900")
        case .defaultBlue: return Color(hex: "0284c7")
        case .emerald: return Color(hex: "178F65")
        case .orange: return Color(hex: "DC540C")
        case .gold: return Color(hex: "B8860B")
        case .ocean: return Color(hex: "0071A4")
        case .slate: return Color(hex: "6b6c6e")
        case .rose: return Color(hex: "FF81AA")
        case .crimson: return Color(hex: "B30000")
        case .bronze: return Color(hex: "8B5A2B")
        case .sunset: return Color(hex: "CC6600")
        case .olive: return Color(hex: "648200")
        case .steel: return Color(hex: "4080C0")
        case .charcoal: return Color(hex: "666666")
        case .maroon: return Color(hex: "8C1D40")
        case .atom: return Color(hex: "80A2BE")
        case .aubergine: return Color(hex: "0E5A8A")
        case .forest: return Color(hex: "9C2E33")
        case .onyx: return Color(hex: "2A7A72")
        case .cyan: return Color(hex: "088A9C")
        case .coral: return Color(hex: "66CCCC")
        case .nord: return Color(hex: "4f5b66")
        case .navy: return Color(hex: "003E6B")
        case .amber: return Color(hex: "507DAA")
        case .midnight: return Color(hex: "008B6B")
        case .matrix: return Color(hex: "0FA012")
        case .lemon: return Color(hex: "59c77f")
        case .cobalt: return Color(hex: "0085FF")
        case .silver: return Color(hex: "2A5A8A")
        case .tropical: return Color(hex: "3A9A86")
        case .arctic: return Color(hex: "1A7AB0")
        case .blush: return Color(hex: "8EEADB")
        case .sunflower: return Color(hex: "000000")
        case .cream: return Color(hex: "DA3D61")
        case .cloud: return Color(hex: "005AA0")
        case .royal: return Color(hex: "6044db")
        case .lavender: return Color(hex: "7A3CA0")
        case .electric: return Color(hex: "00A8E1")
        case .tangerine: return Color(hex: "CC2900")
        case .pastel: return Color(hex: "89cff0")
        case .neon: return Color(hex: "ec34ff")
        }
    }

    var accentLight: Color {
        // Lighter variant of accent
        switch self {
        case .gadfly: return Color(hex: "FFD54F")
        case .defaultBlue: return Color(hex: "38bdf8")
        case .emerald: return Color(hex: "4aa889")
        case .orange: return Color(hex: "eb9268")
        case .gold: return Color(hex: "FFD738")
        case .ocean: return Color(hex: "5AC8FA")
        case .slate: return Color(hex: "FF6B8A")
        case .rose: return Color(hex: "FFC4D9")
        case .crimson: return Color(hex: "FF4040")
        case .bronze: return Color(hex: "ADBA4E")
        case .sunset: return Color(hex: "FFA040")
        case .olive: return Color(hex: "9cbe30")
        case .steel: return Color(hex: "7AB4F0")
        case .charcoal: return Color(hex: "BBBBBB")
        case .maroon: return Color(hex: "94E864")
        case .atom: return Color(hex: "ABB2BF")
        case .aubergine: return Color(hex: "2BAC76")
        case .forest: return Color(hex: "ee6030")
        case .onyx: return Color(hex: "fc7459")
        case .cyan: return Color(hex: "EB4D5C")
        case .coral: return Color(hex: "99CC99")
        case .nord: return Color(hex: "bf616a")
        case .navy: return Color(hex: "F15340")
        case .amber: return Color(hex: "FFB963")
        case .midnight: return Color(hex: "52eb7b")
        case .matrix: return Color(hex: "229725")
        case .lemon: return Color(hex: "fa575d")
        case .cobalt: return Color(hex: "2CDB00")
        case .silver: return Color(hex: "69AA4E")
        case .tropical: return Color(hex: "E5613B")
        case .arctic: return Color(hex: "60D156")
        case .blush: return Color(hex: "F9C6D6")
        case .sunflower: return Color(hex: "FFF09E")
        case .cream: return Color(hex: "F26328")
        case .cloud: return Color(hex: "4bca81")
        case .royal: return Color(hex: "FFD700")
        case .lavender: return Color(hex: "C490E4")
        case .electric: return Color(hex: "FFD54F")
        case .tangerine: return Color(hex: "FF6640")
        case .pastel: return Color(hex: "FEC8D8")
        case .neon: return Color(hex: "66ed00")
        }
    }

    // MARK: - Semantic Colors (shared across themes)

    var taskColor: Color { accentDark }
    var eventColor: Color { accentLight }
    var successColor: Color { Color(hex: "22c55e") }
    var warningColor: Color { Color(hex: "FF9500") }
    var errorColor: Color { Color(hex: "FF3B30") }

    // MARK: - Priority Colors

    var priorityHigh: Color { errorColor }
    var priorityMedium: Color { warningColor }
    var priorityLow: Color { successColor }

    // MARK: - Background Colors

    /// Whether this theme has a custom (non-system) background
    var hasCustomBackground: Bool {
        switch self {
        case .crimson, .bronze, .sunset, .steel, .charcoal, .atom, .aubergine,
             .forest, .onyx, .cyan, .nord, .navy, .midnight, .matrix, .cobalt,
             .royal, .electric, .pastel, .neon, .amber, .sunflower, .cream:
            return true
        default:
            return false
        }
    }

    /// Light-background themes need dark text
    var isLightBackground: Bool {
        switch self {
        case .amber, .sunflower, .cream:
            return true
        default:
            return false
        }
    }

    var background: Color {
        switch self {
        // Special light-colored backgrounds
        case .amber: return Color(hex: "F7941E")
        case .sunflower: return Color(hex: "FDE13A")
        case .cream: return Color(hex: "F3E3CD")
        // Custom dark backgrounds
        case .crimson: return Color(hex: "323232")
        case .bronze: return Color(hex: "2F2C2F")
        case .sunset: return Color(hex: "000020")
        case .steel: return Color(hex: "373D48")
        case .charcoal: return Color(hex: "383838")
        case .atom: return Color(hex: "121417")
        case .aubergine: return Color(hex: "3F0E40")
        case .forest: return Color(hex: "194234")
        case .onyx: return Color(hex: "222222")
        case .cyan: return Color(hex: "1d1d1d")
        case .nord: return Color(hex: "2b303b")
        case .navy: return Color(hex: "000020")
        case .midnight: return Color(hex: "020623")
        case .matrix: return Color(hex: "2C2C26")
        case .cobalt: return Color(hex: "193549")
        case .royal: return Color(hex: "6044db")
        case .electric: return Color(hex: "00A8E1")
        case .pastel: return Color(hex: "b19cd9")
        case .neon: return Color(hex: "2b2b2b")
        // System-adaptive themes (follow dark/light mode)
        default:
            return Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                    UIColor(hex: "000000") : UIColor(hex: "F2F2F7")
            })
        }
    }

    var secondary: Color {
        switch self {
        case .amber: return Color(hex: "ffa940")
        case .sunflower: return Color(hex: "fff09e")
        case .cream: return Color(hex: "ead5b5")
        case .crimson, .charcoal: return Color(hex: "3a3a3a")
        case .bronze: return Color(hex: "3a3a3a")
        case .atom: return Color(hex: "2F343D")
        case .nord: return Color(hex: "343d46")
        case .sunset, .navy: return Color(hex: "1a1a3a")
        case .steel: return Color(hex: "4A5664")
        case .aubergine: return Color(hex: "4a1a4b")
        case .forest: return Color(hex: "2a5443")
        case .onyx: return Color(hex: "333333")
        case .cyan: return Color(hex: "2a2a2a")
        case .midnight: return Color(hex: "1a1e3a")
        case .matrix: return Color(hex: "3a3a32")
        case .cobalt: return Color(hex: "2a4a5a")
        case .royal: return Color(hex: "5038c5")
        case .electric: return Color(hex: "0098d0")
        case .pastel: return Color(hex: "a590cc")
        case .neon: return Color(hex: "3a3a3a")
        // System-adaptive themes
        default:
            return Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                    UIColor(hex: "1C1C1E") : UIColor(hex: "FFFFFF")
            })
        }
    }

    var secondaryMid: Color {
        switch self {
        case .amber, .sunflower, .cream: return secondary.opacity(0.8)
        case .crimson, .charcoal, .neon: return Color(hex: "4a4a4a")
        case .bronze, .atom, .nord: return Color(hex: "3F3C3F")
        default: return Color(hex: "2C2C2E")
        }
    }

    var secondaryLight: Color {
        switch self {
        case .amber, .sunflower, .cream: return secondary.opacity(0.6)
        case .crimson, .charcoal, .neon: return Color(hex: "5a5a5a")
        default: return Color(hex: "3A3A3C")
        }
    }

    // MARK: - Text Colors

    var textPrimary: Color {
        switch self {
        // Light background themes need dark text
        case .amber: return Color(hex: "110000")
        case .sunflower: return Color(hex: "000000")
        case .cream: return Color(hex: "183E1C")
        // Custom dark themes with specific text colors
        case .atom: return Color(hex: "ABB2BF")
        case .bronze: return Color(hex: "D2D6D6")
        case .nord: return Color(hex: "c0c5ce")
        // Custom dark themes with white text
        case .crimson, .sunset, .steel, .charcoal, .aubergine, .forest, .onyx,
             .cyan, .navy, .midnight, .matrix, .cobalt, .royal, .electric,
             .pastel, .neon:
            return Color.white
        // System-adaptive themes
        default:
            return Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                    .white : UIColor(hex: "1C1917")
            })
        }
    }

    var textSecondary: Color {
        switch self {
        // Light background themes
        case .amber: return Color(hex: "110000").opacity(0.7)
        case .sunflower: return Color(hex: "000000").opacity(0.6)
        case .cream: return Color(hex: "183E1C").opacity(0.7)
        // Custom dark themes
        case .atom: return Color(hex: "6a7080")
        case .bronze: return Color(hex: "a0a0a0")
        case .nord: return Color(hex: "a7adba")
        case .aubergine: return Color(hex: "CD2553")
        case .forest: return Color(hex: "80a090")
        case .navy: return Color(hex: "D37C71")
        case .midnight: return Color(hex: "41465c")
        case .matrix: return Color(hex: "229725")
        case .cobalt: return Color(hex: "1D425D")
        case .crimson, .sunset, .steel, .charcoal, .onyx, .cyan, .royal,
             .electric, .pastel, .neon:
            return Color(hex: "a0a0a0")
        // System-adaptive themes
        default:
            return Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                    UIColor(hex: "8E8E93") : UIColor(hex: "6B7280")
            })
        }
    }

    var description: String {
        rawValue // Just use the theme name
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selected_theme")
        }
    }

    @Published var selectedColorTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(selectedColorTheme.rawValue, forKey: "selected_color_theme")
        }
    }

    @Published var claudeKey: String {
        didSet {
            KeychainService.save(key: "claude_api_key", value: claudeKey)
        }
    }

    @Published var elevenLabsKey: String {
        didSet {
            KeychainService.save(key: "elevenlabs_api_key", value: elevenLabsKey)
        }
    }

    @Published var selectedVoiceId: String {
        didSet {
            UserDefaults.standard.set(selectedVoiceId, forKey: "selected_voice_id")
            UserDefaults.standard.synchronize()
            print("🎤 VOICE ID SAVED: \(selectedVoiceId)")
        }
    }

    @Published var selectedVoiceName: String {
        didSet {
            UserDefaults.standard.set(selectedVoiceName, forKey: "selected_voice_name")
            UserDefaults.standard.synchronize()
            print("🎤 VOICE NAME SAVED: \(selectedVoiceName)")
        }
    }

    // MARK: - Reminder Settings

    @Published var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: "reminders_enabled")
        }
    }

    @Published var nagIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(nagIntervalMinutes, forKey: "nag_interval_minutes")
        }
    }

    @Published var eventReminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(eventReminderMinutes, forKey: "event_reminder_minutes")
        }
    }

    @Published var dailyCheckInsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailyCheckInsEnabled, forKey: "daily_checkins_enabled")
        }
    }

    @Published var dailyCheckInTimes: [String] { // Times as "HH:mm" strings (e.g., ["09:30", "12:00", "17:15"])
        didSet {
            UserDefaults.standard.set(dailyCheckInTimes, forKey: "daily_checkin_times_v2")
        }
    }

    @Published var focusCheckInMinutes: Int {
        didSet {
            UserDefaults.standard.set(focusCheckInMinutes, forKey: "focus_checkin_minutes")
        }
    }

    @Published var focusGracePeriodMinutes: Int { // How long before first reminder
        didSet {
            UserDefaults.standard.set(focusGracePeriodMinutes, forKey: "focus_grace_period_minutes")
        }
    }

    @Published var timeAwayThresholdMinutes: Int { // How long away before chiding
        didSet {
            UserDefaults.standard.set(timeAwayThresholdMinutes, forKey: "time_away_threshold_minutes")
        }
    }

    @Published var focusTimeAwayThresholdMinutes: Int { // Shorter threshold during focus
        didSet {
            UserDefaults.standard.set(focusTimeAwayThresholdMinutes, forKey: "focus_time_away_threshold_minutes")
        }
    }

    @Published var idleThresholdMinutes: Int { // How long idle before nudge
        didSet {
            UserDefaults.standard.set(idleThresholdMinutes, forKey: "idle_threshold_minutes")
        }
    }

    @Published var morningBriefingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(morningBriefingEnabled, forKey: "morning_briefing_enabled")
        }
    }

    // MARK: - Personality

    @Published var selectedPersonality: BotPersonality {
        didSet {
            let rawValue = selectedPersonality.rawValue
            UserDefaults.standard.set(rawValue, forKey: "selected_personality")
            UserDefaults.standard.synchronize() // Force immediate save
            print("🎭 PERSONALITY SAVED: \(rawValue)")
        }
    }

    // MARK: - App Version (Kids/Teens/Adults)

    @Published var appVersion: AppVersion {
        didSet {
            UserDefaults.standard.set(appVersion.rawValue, forKey: "app_version")
        }
    }

    // Feature toggles for adults mode
    @Published var featureWork: Bool {
        didSet { UserDefaults.standard.set(featureWork, forKey: "feature_work") }
    }
    @Published var featureSchool: Bool {
        didSet { UserDefaults.standard.set(featureSchool, forKey: "feature_school") }
    }
    @Published var featureHealth: Bool {
        didSet { UserDefaults.standard.set(featureHealth, forKey: "feature_health") }
    }
    @Published var featureHome: Bool {
        didSet { UserDefaults.standard.set(featureHome, forKey: "feature_home") }
    }
    @Published var featureCreative: Bool {
        didSet { UserDefaults.standard.set(featureCreative, forKey: "feature_creative") }
    }
    @Published var featureSocial: Bool {
        didSet { UserDefaults.standard.set(featureSocial, forKey: "feature_social") }
    }

    // MARK: - Simple/Pro Mode

    @Published var isSimpleMode: Bool {
        didSet { UserDefaults.standard.set(isSimpleMode, forKey: "is_simple_mode") }
    }

    // MARK: - Reward Breaks

    @Published var rewardBreaksEnabled: Bool {
        didSet { UserDefaults.standard.set(rewardBreaksEnabled, forKey: "reward_breaks_enabled") }
    }

    @Published var rewardBreakDuration: Int { // in minutes
        didSet { UserDefaults.standard.set(rewardBreakDuration, forKey: "reward_break_duration") }
    }

    @Published var autoSuggestBreaks: Bool {
        didSet { UserDefaults.standard.set(autoSuggestBreaks, forKey: "auto_suggest_breaks") }
    }

    // MARK: - Onboarding Triggers (not persisted)

    @Published var triggerMorningChecklist = false
    @Published var triggerEveningChecklist = false
    @Published var triggerMiddayChecklist = false

    // MARK: - User Profile

    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "user_name")
        }
    }

    @Published var userPhone: String {
        didSet {
            UserDefaults.standard.set(userPhone, forKey: "user_phone")
        }
    }

    @Published var isRegistered: Bool {
        didSet {
            UserDefaults.standard.set(isRegistered, forKey: "is_registered")
        }
    }

    // MARK: - Focus Session State

    @Published var isFocusSessionActive: Bool = false
    @Published var focusSessionStartTime: Date?
    @Published var focusSessionTaskCount: Int = 0

    // MARK: - Break Mode State

    @Published var breakModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(breakModeEnabled, forKey: "break_mode_enabled")
        }
    }

    @Published var breakModeEndTime: Date? {
        didSet {
            if let date = breakModeEndTime {
                UserDefaults.standard.set(date, forKey: "break_mode_end_time")
            } else {
                UserDefaults.standard.removeObject(forKey: "break_mode_end_time")
            }
        }
    }

    /// Check if break mode is currently active (enabled and not expired)
    var isBreakModeActive: Bool {
        guard breakModeEnabled, let endTime = breakModeEndTime else { return false }
        return Date() < endTime
    }

    /// Start break mode for a specified duration in minutes
    func startBreakMode(durationMinutes: Int) {
        let endTime = Date().addingTimeInterval(Double(durationMinutes * 60))
        startBreakMode(until: endTime)
    }

    /// Start break mode until a specific time
    func startBreakMode(until endTime: Date) {
        breakModeEnabled = true
        breakModeEndTime = endTime
        NotificationService.shared.enableBreakMode(until: endTime)
        print("⏸️ Break mode activated until \(endTime)")
    }

    /// End break mode manually
    func endBreakMode() {
        breakModeEnabled = false
        breakModeEndTime = nil
        NotificationService.shared.endBreakMode()
        print("▶️ Break mode ended")
    }

    /// Check and clear expired break mode on app launch
    func checkBreakModeExpiry() {
        if breakModeEnabled, let endTime = breakModeEndTime, Date() >= endTime {
            breakModeEnabled = false
            breakModeEndTime = nil
            print("⏸️ Break mode expired, cleared")
        }
    }

    // MARK: - Keep Alive Settings

    @Published var keepScreenOn: Bool {
        didSet {
            UserDefaults.standard.set(keepScreenOn, forKey: "keep_screen_on")
            UIApplication.shared.isIdleTimerDisabled = keepScreenOn
        }
    }

    private static let defaultClaudeKey = ""
    private static let defaultElevenLabsKey = ""

    init() {
        // Theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selected_theme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .dark // Default to dark as per original design
        }

        // Color Theme
        if let savedColorTheme = UserDefaults.standard.string(forKey: "selected_color_theme"),
           let colorTheme = ColorTheme(rawValue: savedColorTheme) {
            self.selectedColorTheme = colorTheme
        } else {
            self.selectedColorTheme = .gadfly // Default to original amber
        }

        // Use defaults - they contain the API keys
        self.claudeKey = Self.defaultClaudeKey
        self.elevenLabsKey = Self.defaultElevenLabsKey
        let loadedVoiceId = UserDefaults.standard.string(forKey: "selected_voice_id") ?? ""
        let loadedVoiceName = UserDefaults.standard.string(forKey: "selected_voice_name") ?? "Default"
        print("🎤 LOADING VOICE - ID: '\(loadedVoiceId)', Name: '\(loadedVoiceName)'")
        self.selectedVoiceId = loadedVoiceId
        self.selectedVoiceName = loadedVoiceName

        // Reminder settings
        self.remindersEnabled = UserDefaults.standard.object(forKey: "reminders_enabled") as? Bool ?? true
        self.nagIntervalMinutes = UserDefaults.standard.object(forKey: "nag_interval_minutes") as? Int ?? 5
        self.eventReminderMinutes = UserDefaults.standard.object(forKey: "event_reminder_minutes") as? Int ?? 15
        self.dailyCheckInsEnabled = UserDefaults.standard.object(forKey: "daily_checkins_enabled") as? Bool ?? false
        self.dailyCheckInTimes = UserDefaults.standard.object(forKey: "daily_checkin_times_v2") as? [String] ?? ["09:00", "12:00", "17:00"]
        self.focusCheckInMinutes = UserDefaults.standard.object(forKey: "focus_checkin_minutes") as? Int ?? 15
        self.focusGracePeriodMinutes = UserDefaults.standard.object(forKey: "focus_grace_period_minutes") as? Int ?? 5
        self.timeAwayThresholdMinutes = UserDefaults.standard.object(forKey: "time_away_threshold_minutes") as? Int ?? 10
        self.focusTimeAwayThresholdMinutes = UserDefaults.standard.object(forKey: "focus_time_away_threshold_minutes") as? Int ?? 3
        self.idleThresholdMinutes = UserDefaults.standard.object(forKey: "idle_threshold_minutes") as? Int ?? 5
        self.morningBriefingEnabled = UserDefaults.standard.object(forKey: "morning_briefing_enabled") as? Bool ?? true

        // Personality
        let savedPersonality = UserDefaults.standard.string(forKey: "selected_personality") ?? ""
        print("🎭 LOADING PERSONALITY - saved value: '\(savedPersonality)'")
        let loadedPersonality = BotPersonality(rawValue: savedPersonality) ?? .pemberton
        print("🎭 LOADED PERSONALITY: \(loadedPersonality.rawValue)")
        self.selectedPersonality = loadedPersonality

        // App Version
        let savedVersion = UserDefaults.standard.string(forKey: "app_version") ?? ""
        self.appVersion = AppVersion(rawValue: savedVersion) ?? .adults

        // Feature toggles (default most on for adults)
        self.featureWork = UserDefaults.standard.object(forKey: "feature_work") as? Bool ?? true
        self.featureSchool = UserDefaults.standard.object(forKey: "feature_school") as? Bool ?? true
        self.featureHealth = UserDefaults.standard.object(forKey: "feature_health") as? Bool ?? true
        self.featureHome = UserDefaults.standard.object(forKey: "feature_home") as? Bool ?? true
        self.featureCreative = UserDefaults.standard.object(forKey: "feature_creative") as? Bool ?? false
        self.featureSocial = UserDefaults.standard.object(forKey: "feature_social") as? Bool ?? false

        // Simple/Pro Mode (default to Pro mode = false)
        self.isSimpleMode = UserDefaults.standard.object(forKey: "is_simple_mode") as? Bool ?? false

        // Reward breaks
        self.rewardBreaksEnabled = UserDefaults.standard.object(forKey: "reward_breaks_enabled") as? Bool ?? false
        self.rewardBreakDuration = UserDefaults.standard.object(forKey: "reward_break_duration") as? Int ?? 15
        self.autoSuggestBreaks = UserDefaults.standard.object(forKey: "auto_suggest_breaks") as? Bool ?? true

        // User profile
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.userPhone = UserDefaults.standard.string(forKey: "user_phone") ?? ""
        self.isRegistered = UserDefaults.standard.bool(forKey: "is_registered")

        // Keep alive settings
        self.keepScreenOn = UserDefaults.standard.bool(forKey: "keep_screen_on")

        // Break mode state
        self.breakModeEnabled = UserDefaults.standard.bool(forKey: "break_mode_enabled")
        self.breakModeEndTime = UserDefaults.standard.object(forKey: "break_mode_end_time") as? Date

        // Apply screen setting
        if self.keepScreenOn {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // Check for expired break mode
        checkBreakModeExpiry()

        // Save to keychain
        KeychainService.save(key: "claude_api_key", value: self.claudeKey)
        KeychainService.save(key: "elevenlabs_api_key", value: self.elevenLabsKey)
    }

    var hasValidClaudeKey: Bool {
        !claudeKey.isEmpty
    }

    var hasValidElevenLabsKey: Bool {
        !elevenLabsKey.isEmpty
    }

    var hasVoiceSelected: Bool {
        !selectedVoiceId.isEmpty
    }
}

// MARK: - Theme Manager (Observable)

class ThemeColors: ObservableObject {
    static let shared = ThemeColors()
    private let lock = NSLock()

    @Published var currentTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selected_color_theme")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selected_color_theme"),
           let theme = ColorTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .gadfly
        }
    }

    // Convenience accessors
    var accent: Color { currentTheme.accent }
    var accentDark: Color { currentTheme.accentDark }
    var accentLight: Color { currentTheme.accentLight }
    var background: Color { currentTheme.background }
    var secondary: Color { currentTheme.secondary }
    var secondaryMid: Color { currentTheme.secondaryMid }
    var secondaryLight: Color { currentTheme.secondaryLight }
    var taskColor: Color { currentTheme.taskColor }
    var eventColor: Color { currentTheme.eventColor }
    var success: Color { currentTheme.successColor }
    var warning: Color { currentTheme.warningColor }
    var error: Color { currentTheme.errorColor }
    var priorityHigh: Color { currentTheme.priorityHigh }
    var priorityMedium: Color { currentTheme.priorityMedium }
    var priorityLow: Color { currentTheme.priorityLow }
    var text: Color { currentTheme.textPrimary }
    var subtext: Color { currentTheme.textSecondary }
}

// MARK: - Theme (Static accessors for convenience)

struct Theme {
    static var background: Color { ThemeColors.shared.background }
    static var secondary: Color { ThemeColors.shared.secondary }
    static var secondaryMid: Color { ThemeColors.shared.secondaryMid }
    static var secondaryLight: Color { ThemeColors.shared.secondaryLight }
    static var accent: Color { ThemeColors.shared.accent }
    static var accentDark: Color { ThemeColors.shared.accentDark }
    static var accentLight: Color { ThemeColors.shared.accentLight }
    static var taskColor: Color { ThemeColors.shared.taskColor }
    static var eventColor: Color { ThemeColors.shared.eventColor }
    static var success: Color { ThemeColors.shared.success }
    static var warning: Color { ThemeColors.shared.warning }
    static var error: Color { ThemeColors.shared.error }
    static var priorityHigh: Color { ThemeColors.shared.priorityHigh }
    static var priorityMedium: Color { ThemeColors.shared.priorityMedium }
    static var priorityLow: Color { ThemeColors.shared.priorityLow }
    static var text: Color { ThemeColors.shared.text }
    static var subtext: Color { ThemeColors.shared.subtext }
}

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Color {
    static var themeBackground: Color { Theme.background }
    static var themeSecondary: Color { Theme.secondary }
    static var themeAccent: Color { Theme.accent }
    static var themeText: Color { Theme.text }
    static var themeSubtext: Color { Theme.subtext }

    static var themeSuccess: Color { Theme.success }
    static var themeWarning: Color { Theme.warning }
    static var themeError: Color { Theme.error }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - PhoneConnectivityManager

import WatchConnectivity

@MainActor
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable = false
    @Published var isWatchPaired = false

    private var session: WCSession?

    override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("📱 WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 Phone Connectivity activating...")
    }

    // MARK: - Send to Watch

    /// Send current tasks to Watch
    func syncTasks(_ tasks: [ParsedTask]) {
        guard let session = session, session.isPaired else { return }

        let watchTasks = tasks.map { task in
            WatchTaskDTO(
                id: task.id,
                title: task.title,
                deadline: task.deadline,
                priority: task.priority.rawValue,
                isCompleted: task.isCompleted
            )
        }

        do {
            let data = try JSONEncoder().encode(watchTasks)
            let message: [String: Any] = [
                "action": "syncTasks",
                "tasks": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil)
                print("⌚ Sent \(watchTasks.count) tasks to Watch")
            } else {
                try session.updateApplicationContext(message)
                print("⌚ Queued \(watchTasks.count) tasks for Watch")
            }
        } catch {
            print("❌ Failed to encode tasks for Watch: \(error)")
        }
    }

    /// Send a spoken message to the Watch
    func speakOnWatch(_ text: String) {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(
            ["action": "speak", "text": text],
            replyHandler: nil
        )
        print("⌚ Sent speech to Watch: \(text.prefix(50))...")
    }

    /// Notify Watch that a task was removed
    func notifyTaskRemoved(taskId: String) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "action": "taskRemoved",
            "taskId": taskId
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    /// Send a new task to Watch
    func sendTaskToWatch(_ task: ParsedTask) {
        guard let session = session else { return }

        let watchTask = WatchTaskDTO(
            id: task.id,
            title: task.title,
            deadline: task.deadline,
            priority: task.priority.rawValue,
            isCompleted: task.isCompleted
        )

        do {
            let data = try JSONEncoder().encode(watchTask)
            let message: [String: Any] = [
                "action": "newTask",
                "task": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil)
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("❌ Failed to send task to Watch: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            print("📱 Phone session activated: \(activationState.rawValue)")
            isWatchPaired = session.isPaired
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 Phone session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("📱 Phone session deactivated")
        // Reactivate for switching watches
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
        }
    }

    // Receive messages from Watch
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleWatchMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleWatchMessage(applicationContext)
        }
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "taskCompleted":
            if let taskId = message["taskId"] as? String {
                print("⌚ Watch marked task complete: \(taskId)")
                // Post notification for the app to handle
                NotificationCenter.default.post(
                    name: .watchTaskCompleted,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }

        case "snooze":
            if let minutes = message["minutes"] as? Int,
               let taskId = message["taskId"] as? String,
               let title = message["title"] as? String {
                print("⌚ Watch snoozed task: \(title) for \(minutes) min")
                NotificationService.shared.scheduleNagReminder(
                    originalId: taskId,
                    title: title,
                    type: "task",
                    delayMinutes: minutes
                )
            }

        case "newTask":
            if let text = message["text"] as? String {
                print("⌚ Watch created new task: \(text)")
                // Post notification for the app to process with AI
                NotificationCenter.default.post(
                    name: .watchNewTask,
                    object: nil,
                    userInfo: ["text": text]
                )
            }

        case "syncRequest":
            print("⌚ Watch requested sync")
            // Post notification for app to send current tasks
            NotificationCenter.default.post(
                name: .watchSyncRequested,
                object: nil
            )

        default:
            break
        }
    }
}

// MARK: - DTO for Watch

struct WatchTaskDTO: Codable {
    let id: UUID
    let title: String
    let deadline: Date?
    let priority: String
    let isCompleted: Bool
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchTaskCompleted = Notification.Name("watchTaskCompleted")
    static let watchNewTask = Notification.Name("watchNewTask")
    static let watchSyncRequested = Notification.Name("watchSyncRequested")
}
