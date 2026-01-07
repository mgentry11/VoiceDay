import Foundation
import SwiftUI
import AVFoundation
import EventKit

/// Proactively monitors aging tasks and helps users understand blockers
/// The bot does the thinking - user just responds
@MainActor
class TaskAgingService: ObservableObject {
    static let shared = TaskAgingService()

    // MARK: - Published State

    @Published var agingTask: AgingTaskPrompt?
    @Published var isShowingPrompt = false

    // MARK: - Configuration

    /// Hours before a task is considered "aging" and needs attention
    private let agingThresholdHours: Double = 24

    /// Hours before task is "critical" - red hot
    private let criticalThresholdHours: Double = 72


    // MARK: - Models

    struct AgingTaskPrompt: Identifiable {
        let id = UUID()
        let taskTitle: String
        let taskId: String
        let hoursOld: Double
        let severity: Severity

        enum Severity {
            case aging      // 24-48 hours
            case old        // 48-72 hours
            case critical   // 72+ hours

            var color: Color {
                switch self {
                case .aging: return .orange
                case .old: return .red.opacity(0.7)
                case .critical: return .red
                }
            }
        }
    }

    enum BlockerReason: String, CaseIterable {
        case tooHard = "It feels too hard"
        case unclear = "I don't know where to start"
        case noTime = "Haven't had time"
        case waiting = "Waiting on something"
        case dontWant = "I just don't want to"
        case forgot = "I forgot about it"

        var icon: String {
            switch self {
            case .tooHard: return "mountain.2.fill"
            case .unclear: return "questionmark.circle.fill"
            case .noTime: return "clock.fill"
            case .waiting: return "hourglass"
            case .dontWant: return "hand.raised.fill"
            case .forgot: return "brain.head.profile"
            }
        }

        var helpResponse: String {
            switch self {
            case .tooHard:
                return "Let's break this into tiny pieces. What's the smallest first step?"
            case .unclear:
                return "No worries! Let me help you figure out where to start."
            case .noTime:
                return "Want to schedule a specific time, or push it to tomorrow?"
            case .waiting:
                return "Got it. Want me to remind you to follow up?"
            case .dontWant:
                return "Totally valid. Is this actually important, or can we delete it?"
            case .forgot:
                return "Happens to everyone! Ready to tackle it now, or push to later?"
            }
        }
    }

    // MARK: - Check for Aging Tasks

    func checkForAgingTasks(reminders: [EKReminder]) {
        let now = Date()

        for reminder in reminders where !reminder.isCompleted {
            guard let creationDate = reminder.creationDate else { continue }

            let hoursOld = now.timeIntervalSince(creationDate) / 3600

            if hoursOld >= agingThresholdHours {
                let severity: AgingTaskPrompt.Severity
                if hoursOld >= criticalThresholdHours {
                    severity = .critical
                } else if hoursOld >= 48 {
                    severity = .old
                } else {
                    severity = .aging
                }

                // Only show one at a time
                agingTask = AgingTaskPrompt(
                    taskTitle: reminder.title ?? "Untitled task",
                    taskId: reminder.calendarItemIdentifier,
                    hoursOld: hoursOld,
                    severity: severity
                )
                isShowingPrompt = true
                break // Only show first aging task
            }
        }
    }

    // MARK: - Voice Prompts

    func speakAgingPrompt(personality: BotPersonality) {
        guard let task = agingTask else { return }

        let message = getAgingMessage(for: personality, task: task)
        speak(message)
    }

    private func getAgingMessage(for personality: BotPersonality, task: AgingTaskPrompt) -> String {
        let taskName = task.taskTitle
        let days = Int(task.hoursOld / 24)

        switch personality {
        case .pemberton:
            return "I notice '\(taskName)' has been languishing for \(days) days. Perhaps we should discuss what's impeding progress?"
        case .sergent:
            return "Soldier! '\(taskName)' has been sitting for \(days) days! What's the hold up?"
        case .cheerleader:
            return "Hey! I noticed '\(taskName)' has been waiting for a bit. What's getting in the way? I'm here to help!"
        case .butler:
            return "If I may, Sir. '\(taskName)' has been pending for \(days) days. Might I inquire what assistance you require?"
        case .coach:
            return "Time out! '\(taskName)' has been on the bench for \(days) days. What's the game plan here?"
        case .zen:
            return "I observe '\(taskName)' has been present for \(days) days. What energy is keeping it from flowing?"
        case .parent:
            return "Sweetie, I noticed '\(taskName)' has been there a while. What's making it hard? No judgment, just want to help."
        case .bestie:
            return "Okay so '\(taskName)' has been sitting there for like \(days) days. What's up with that?"
        case .robot:
            return "Task '\(taskName)' age: \(days) days. Status update required."
        case .therapist:
            return "I see '\(taskName)' has been with us for \(days) days. How are you feeling about it?"
        case .hypeFriend:
            return "Yo! '\(taskName)' is still hanging out! What's blocking your legendary progress?!"
        case .chillBuddy:
            return "So '\(taskName)' has been there for a bit... no stress, but what's the deal?"
        case .snarky:
            return "So '\(taskName)' has been there for \(days) days. Shocking. What's the story?"
        case .gamer:
            return "Quest '\(taskName)' has been in your log for \(days) days! What's the blocker?"
        case .tiredParent:
            return "'\(taskName)' has been there for \(days) days. I get it. What's in the way?"
        case .sage:
            return "'\(taskName)' has waited \(days) days. What wisdom can unlock its completion?"
        case .rebel:
            return "'\(taskName)' has been stuck for \(days) days. What's the system putting in your way?"
        case .trickster:
            return "'\(taskName)' has been avoiding you for \(days) days... or have you been avoiding IT?"
        case .stoic:
            return "'\(taskName)' has been present for \(days) days. What virtue will help you complete it?"
        case .pirate:
            return "Arr! '\(taskName)' be sitting in the hold for \(days) days! What's delaying the voyage?"
        case .witch:
            return "'\(taskName)' has been brewing for \(days) days. What ingredient is missing from the potion?"
        }
    }

    func speakBlockerResponse(reason: BlockerReason) {
        speak(reason.helpResponse)
    }

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    // MARK: - Actions

    func dismissPrompt() {
        isShowingPrompt = false
        agingTask = nil
    }

    func handleBreakdown() {
        // Will trigger the focus session with breakdown
        dismissPrompt()
    }

    func handlePushToLater() {
        // Push 3 hours
        dismissPrompt()
    }

    func handlePushToTomorrow() {
        // Push to tomorrow morning
        dismissPrompt()
    }

    func handleDelete() {
        // Confirm and delete
        dismissPrompt()
    }
}
