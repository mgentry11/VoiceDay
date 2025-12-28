import Foundation

/// Manages session state for soft restart - remembers where user left off
@MainActor
class SessionStateService: ObservableObject {
    static let shared = SessionStateService()

    // MARK: - Session State

    struct SessionState: Codable {
        var lastActiveScreen: ActiveScreen
        var lastActiveTab: Int
        var checkInProgress: CheckInProgress?
        var lastActiveTime: Date
        var wasInterrupted: Bool

        init() {
            self.lastActiveScreen = .focusHome
            self.lastActiveTab = 0
            self.checkInProgress = nil
            self.lastActiveTime = Date()
            self.wasInterrupted = false
        }
    }

    enum ActiveScreen: String, Codable {
        case focusHome
        case morningCheckIn
        case middayCheckIn
        case eveningCheckIn
        case bedtimeCheckIn
        case tasksList
        case recording
        case goals
        case settings
        case onboarding
        case hyperfocus
    }

    struct CheckInProgress: Codable {
        var type: CheckInType
        var currentItemIndex: Int
        var totalItems: Int
        var completedItems: [String] // IDs of completed items
        var startTime: Date

        enum CheckInType: String, Codable {
            case morning, midday, evening, bedtime
        }
    }

    // MARK: - Published Properties

    @Published var currentState: SessionState = SessionState()
    @Published var hasInterruptedSession: Bool = false

    // MARK: - Initialization

    private init() {
        loadState()
        checkForInterruptedSession()
    }

    // MARK: - Public Methods

    /// Update current screen
    func setActiveScreen(_ screen: ActiveScreen) {
        currentState.lastActiveScreen = screen
        currentState.lastActiveTime = Date()
        currentState.wasInterrupted = false
        saveState()
    }

    /// Update current tab
    func setActiveTab(_ tab: Int) {
        currentState.lastActiveTab = tab
        currentState.lastActiveTime = Date()
        saveState()
    }

    /// Start tracking a check-in
    func startCheckIn(type: CheckInProgress.CheckInType, totalItems: Int) {
        currentState.checkInProgress = CheckInProgress(
            type: type,
            currentItemIndex: 0,
            totalItems: totalItems,
            completedItems: [],
            startTime: Date()
        )
        saveState()
        print("📍 Session: Started \(type.rawValue) check-in with \(totalItems) items")
    }

    /// Update check-in progress
    func updateCheckInProgress(currentIndex: Int, completedItemId: String? = nil) {
        guard var progress = currentState.checkInProgress else { return }

        progress.currentItemIndex = currentIndex
        if let itemId = completedItemId {
            progress.completedItems.append(itemId)
        }

        currentState.checkInProgress = progress
        saveState()
    }

    /// Complete check-in
    func completeCheckIn() {
        currentState.checkInProgress = nil
        currentState.wasInterrupted = false
        saveState()
        print("📍 Session: Check-in completed")
    }

    /// Mark session as interrupted (app going to background or crashing)
    func markInterrupted() {
        if currentState.checkInProgress != nil {
            currentState.wasInterrupted = true
            saveState()
            print("📍 Session: Marked as interrupted")
        }
    }

    /// Clear interrupted state (user chose to start fresh)
    func clearInterruption() {
        currentState.wasInterrupted = false
        currentState.checkInProgress = nil
        hasInterruptedSession = false
        saveState()
        print("📍 Session: Interruption cleared")
    }

    /// Get resume info for display
    func getResumeInfo() -> (screen: String, progress: String)? {
        guard currentState.wasInterrupted,
              let progress = currentState.checkInProgress else {
            return nil
        }

        let screenName: String
        switch progress.type {
        case .morning: screenName = "Morning Check-in"
        case .midday: screenName = "Midday Check-in"
        case .evening: screenName = "Evening Check-in"
        case .bedtime: screenName = "Bedtime Checklist"
        }

        let progressText = "\(progress.currentItemIndex + 1) of \(progress.totalItems) items"

        return (screenName, progressText)
    }

    /// Check if session is recent enough to resume (within 30 minutes)
    var canResume: Bool {
        guard currentState.wasInterrupted,
              currentState.checkInProgress != nil else {
            return false
        }

        let timeSinceActive = Date().timeIntervalSince(currentState.lastActiveTime)
        return timeSinceActive < 30 * 60 // 30 minutes
    }

    // MARK: - Auto-Save Timer

    private var autoSaveTimer: Timer?

    func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveState()
            }
        }
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Private Methods

    private func checkForInterruptedSession() {
        if currentState.wasInterrupted && canResume {
            hasInterruptedSession = true
            print("📍 Session: Found interrupted session that can be resumed")
        }
    }

    // MARK: - Persistence

    private let stateKey = "sessionState_current"

    private func saveState() {
        if let data = try? JSONEncoder().encode(currentState) {
            UserDefaults.standard.set(data, forKey: stateKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(SessionState.self, from: data) {
            currentState = state
        }
    }
}
