import Foundation
import SwiftUI

// MARK: - Body Doubling Service

/// Virtual co-working for ADHD focus
/// Body doubling: working alongside someone (even virtually) for accountability
@MainActor
class BodyDoublingService: ObservableObject {
    static let shared = BodyDoublingService()

    // MARK: - Published State

    @Published var isSessionActive = false
    @Published var currentSession: BodyDoublingSession?
    @Published var availablePartners: [VirtualPartner] = []
    @Published var sessionHistory: [SessionLog] = []

    // MARK: - Session Types

    enum SessionType: String, CaseIterable, Codable {
        case solo = "solo"              // Virtual presence (AI companion)
        case async = "async"            // See others working on similar tasks
        case scheduled = "scheduled"    // Scheduled co-working room

        var displayName: String {
            switch self {
            case .solo: return "Solo Focus"
            case .async: return "Work Together"
            case .scheduled: return "Scheduled Room"
            }
        }

        var icon: String {
            switch self {
            case .solo: return "person.fill"
            case .async: return "person.2.fill"
            case .scheduled: return "calendar.badge.clock"
            }
        }

        var description: String {
            switch self {
            case .solo: return "AI companion keeps you company while you work"
            case .async: return "See others working on similar tasks right now"
            case .scheduled: return "Join a scheduled co-working session"
            }
        }
    }

    // MARK: - Session Model

    struct BodyDoublingSession: Identifiable {
        let id: UUID
        let type: SessionType
        let startTime: Date
        var taskTitle: String?
        var partner: VirtualPartner?
        var checkInCount: Int = 0
        var focusScore: Double = 1.0  // 0-1, decreases if user leaves app

        var duration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }

        var durationString: String {
            let minutes = Int(duration / 60)
            if minutes >= 60 {
                return "\(minutes / 60)h \(minutes % 60)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Virtual Partner

    struct VirtualPartner: Identifiable, Codable {
        let id: UUID
        let name: String
        let avatar: String  // SF Symbol name
        let currentTask: String?
        let sessionDuration: TimeInterval
        let isOnline: Bool

        static let aiCompanion = VirtualPartner(
            id: UUID(),
            name: "Focus Buddy",
            avatar: "cpu.fill",
            currentTask: "Here to keep you company",
            sessionDuration: 0,
            isOnline: true
        )

        static let samplePartners: [VirtualPartner] = [
            VirtualPartner(id: UUID(), name: "Alex", avatar: "person.circle.fill", currentTask: "Writing report", sessionDuration: 45 * 60, isOnline: true),
            VirtualPartner(id: UUID(), name: "Sam", avatar: "person.circle.fill", currentTask: "Email cleanup", sessionDuration: 22 * 60, isOnline: true),
            VirtualPartner(id: UUID(), name: "Jordan", avatar: "person.circle.fill", currentTask: "Project planning", sessionDuration: 90 * 60, isOnline: true)
        ]
    }

    // MARK: - Session Log

    struct SessionLog: Identifiable, Codable {
        let id: UUID
        let type: SessionType
        let startTime: Date
        let endTime: Date
        let taskTitle: String?
        let focusScore: Double
        let checkInCount: Int

        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }

    // MARK: - Encouragement Messages

    private let checkInMessages = [
        "You're doing great! Keep it up.",
        "Still here with you. Stay focused!",
        "Nice progress! What's next?",
        "Taking a quick breath? That's okay.",
        "You've got this. One step at a time.",
        "Impressive focus! Keep going.",
        "We're in this together. Stay on track.",
        "Great work! Almost there."
    ]

    private let returnMessages = [
        "Welcome back! Ready to continue?",
        "Good to see you! Let's refocus.",
        "No worries, we all take breaks. Back to it?",
        "You're here! That's what matters. Let's go."
    ]

    // MARK: - Persistence

    private let historyKey = "body_doubling_history"

    // MARK: - Initialization

    init() {
        loadHistory()
        loadSamplePartners()
    }

    // MARK: - Session Control

    func startSession(type: SessionType, taskTitle: String? = nil) {
        let session = BodyDoublingSession(
            id: UUID(),
            type: type,
            startTime: Date(),
            taskTitle: taskTitle,
            partner: type == .solo ? .aiCompanion : availablePartners.first
        )

        currentSession = session
        isSessionActive = true

        // Start periodic check-ins
        startCheckInTimer()

        // Start timesheet tracking
        TimesheetService.shared.startTracking(taskName: taskTitle ?? "Focus Session")

        print("🤝 Body doubling session started: \(type.displayName)")
    }

    func endSession() {
        guard let session = currentSession else { return }

        // Log the session
        let log = SessionLog(
            id: session.id,
            type: session.type,
            startTime: session.startTime,
            endTime: Date(),
            taskTitle: session.taskTitle,
            focusScore: session.focusScore,
            checkInCount: session.checkInCount
        )
        sessionHistory.append(log)
        saveHistory()

        currentSession = nil
        isSessionActive = false

        // Stop check-in timer
        checkInTimer?.invalidate()
        checkInTimer = nil

        // Stop timesheet tracking
        TimesheetService.shared.stopTracking()

        print("🤝 Body doubling session ended after \(log.duration / 60) minutes")
    }

    // MARK: - Check-ins

    private var checkInTimer: Timer?

    private func startCheckInTimer() {
        // Check in every 10 minutes
        checkInTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCheckIn()
            }
        }
    }

    private func performCheckIn() {
        guard var session = currentSession else { return }

        session.checkInCount += 1
        currentSession = session

        // Send encouraging notification
        sendCheckInNotification()
    }

    private func sendCheckInNotification() {
        let message = checkInMessages.randomElement() ?? "Keep going!"

        let content = UNMutableNotificationContent()
        content.title = "Focus Check-in"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "body_doubling_checkin_\(UUID().uuidString)",
            content: content,
            trigger: nil  // Immediate
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Focus Tracking

    /// Called when app goes to background
    func appDidEnterBackground() {
        guard var session = currentSession else { return }
        // Reduce focus score slightly when user leaves
        session.focusScore = max(0.5, session.focusScore - 0.1)
        currentSession = session
    }

    /// Called when app returns to foreground
    func appDidBecomeActive() {
        guard isSessionActive else { return }
        // Send welcome back message
        let message = returnMessages.randomElement() ?? "Welcome back!"
        print("🤝 \(message)")
    }

    // MARK: - Statistics

    var totalSessionTime: TimeInterval {
        sessionHistory.reduce(0) { $0 + $1.duration }
    }

    var averageFocusScore: Double {
        guard !sessionHistory.isEmpty else { return 0 }
        return sessionHistory.reduce(0) { $0 + $1.focusScore } / Double(sessionHistory.count)
    }

    var sessionCount: Int {
        sessionHistory.count
    }

    // MARK: - Sample Data

    private func loadSamplePartners() {
        // In a real app, this would fetch from a server
        availablePartners = VirtualPartner.samplePartners
    }

    // MARK: - Persistence

    private func saveHistory() {
        // Keep last 50 sessions
        let recentHistory = Array(sessionHistory.suffix(50))
        if let data = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([SessionLog].self, from: data) {
            sessionHistory = history
        }
    }
}
