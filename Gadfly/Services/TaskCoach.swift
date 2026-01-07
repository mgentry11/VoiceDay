import Foundation
import SwiftUI

// MARK: - Task Coach

/// Bot that asks clarifying questions to help user think through tasks
/// Acts as external executive function for ADHD users
@MainActor
class TaskCoach: ObservableObject {
    static let shared = TaskCoach()

    // MARK: - Question Types

    enum QuestionType: String, CaseIterable {
        case whatDoneLooksLike = "what_done"
        case whatsBlocking = "whats_blocking"
        case realPriority = "real_priority"
        case needAnythingFirst = "need_first"
        case howLong = "how_long"
        case breakItDown = "break_down"
        case whyImportant = "why_important"
        case whenBestTime = "when_best"

        var question: String {
            switch self {
            case .whatDoneLooksLike:
                return "Hey, what would 'done' actually look like here?"
            case .whatsBlocking:
                return "What's getting in the way of just starting?"
            case .realPriority:
                return "Real talk - how important is this, 1 to 10?"
            case .needAnythingFirst:
                return "Do you need anything before you can dive in?"
            case .howLong:
                return "Roughly how long do you think? Just ballpark it"
            case .breakItDown:
                return "What's the tiniest first step you could take?"
            case .whyImportant:
                return "Why does this one matter to you?"
            case .whenBestTime:
                return "When would be a good time for this?"
            }
        }

        var icon: String {
            switch self {
            case .whatDoneLooksLike: return "checkmark.circle"
            case .whatsBlocking: return "hand.raised"
            case .realPriority: return "exclamationmark.circle"
            case .needAnythingFirst: return "tray.and.arrow.down"
            case .howLong: return "clock"
            case .breakItDown: return "square.grid.2x2"
            case .whyImportant: return "heart"
            case .whenBestTime: return "calendar"
            }
        }

        var followUpHint: String {
            switch self {
            case .whatDoneLooksLike:
                return "Paint me a picture"
            case .whatsBlocking:
                return "No judgment, just curious"
            case .realPriority:
                return "Be honest with yourself"
            case .needAnythingFirst:
                return "Sometimes we forget stuff we need"
            case .howLong:
                return "Doesn't have to be perfect"
            case .breakItDown:
                return "Like, ridiculously small"
            case .whyImportant:
                return "Sometimes it helps to remember"
            case .whenBestTime:
                return "There's no wrong answer"
            }
        }
    }

    // MARK: - Coaching Session

    struct CoachingSession: Identifiable {
        let id = UUID()
        let task: GadflyTask
        var questions: [AskedQuestion]
        var insights: [TaskInsight]
        var isComplete: Bool

        struct AskedQuestion {
            let type: QuestionType
            var answer: String?
            let askedAt: Date
        }

        struct TaskInsight {
            let icon: String
            let text: String
        }
    }

    // MARK: - State

    @Published var currentSession: CoachingSession?
    @Published var currentQuestion: QuestionType?
    @Published var suggestedQuestions: [QuestionType] = []

    // MARK: - Start Coaching

    func startCoaching(for task: GadflyTask) {
        let questions = determineQuestions(for: task)

        currentSession = CoachingSession(
            task: task,
            questions: [],
            insights: [],
            isComplete: false
        )

        suggestedQuestions = questions

        // Ask first question
        if let first = questions.first {
            askQuestion(first)
        }
    }

    // MARK: - Determine Questions

    private func determineQuestions(for task: GadflyTask) -> [QuestionType] {
        var questions: [QuestionType] = []
        let titleLower = task.title.lowercased()

        // Vague tasks need clarification
        let vagueWords = ["stuff", "things", "something", "finish", "work on", "deal with"]
        let isVague = vagueWords.contains { titleLower.contains($0) }

        if isVague {
            questions.append(.whatDoneLooksLike)
        }

        // Check if task seems complex
        let complexWords = ["project", "plan", "organize", "complete", "prepare", "entire", "all"]
        let isComplex = complexWords.contains { titleLower.contains($0) }

        if isComplex {
            questions.append(.breakItDown)
        }

        // No due date? Ask about timing
        if task.dueDate == nil {
            questions.append(.whenBestTime)
        }

        // Low priority marked but might be important
        if task.priority == .low {
            questions.append(.whyImportant)
        }

        // Always useful questions
        questions.append(.needAnythingFirst)
        questions.append(.whatsBlocking)

        // Limit to 3 questions max to not overwhelm
        return Array(questions.prefix(3))
    }

    // MARK: - Ask Question

    func askQuestion(_ type: QuestionType) {
        currentQuestion = type

        guard var session = currentSession else { return }

        let asked = CoachingSession.AskedQuestion(
            type: type,
            answer: nil,
            askedAt: Date()
        )

        session.questions.append(asked)
        currentSession = session
    }

    // MARK: - Answer Question

    func answerQuestion(_ answer: String) {
        guard var session = currentSession,
              let questionType = currentQuestion else { return }

        // Find and update the question
        if let index = session.questions.lastIndex(where: { $0.type == questionType }) {
            session.questions[index].answer = answer
        }

        // Generate insight from answer
        let insight = generateInsight(from: answer, for: questionType)
        if let insight = insight {
            session.insights.append(insight)
        }

        currentSession = session

        // Move to next question or complete
        moveToNextQuestion()
    }

    // MARK: - Skip Question

    func skipQuestion() {
        moveToNextQuestion()
    }

    // MARK: - Move to Next

    private func moveToNextQuestion() {
        guard let session = currentSession else { return }

        // Find unanswered questions from suggested list
        let answeredTypes = Set(session.questions.compactMap { $0.answer != nil ? $0.type : nil })
        let remaining = suggestedQuestions.filter { !answeredTypes.contains($0) }

        if let next = remaining.first {
            askQuestion(next)
        } else {
            // Coaching complete
            currentQuestion = nil
            currentSession?.isComplete = true
        }
    }

    // MARK: - Generate Insight

    private func generateInsight(from answer: String, for question: QuestionType) -> CoachingSession.TaskInsight? {
        let answerLower = answer.lowercased()

        switch question {
        case .whatDoneLooksLike:
            return CoachingSession.TaskInsight(
                icon: "checkmark.circle.fill",
                text: "Done = \(answer)"
            )

        case .whatsBlocking:
            if answerLower.contains("nothing") || answerLower.contains("don't know") {
                return CoachingSession.TaskInsight(
                    icon: "arrow.right.circle.fill",
                    text: "No blockers - ready to start!"
                )
            } else {
                return CoachingSession.TaskInsight(
                    icon: "exclamationmark.triangle.fill",
                    text: "Blocker: \(answer)"
                )
            }

        case .realPriority:
            if let number = Int(answer.filter { $0.isNumber }) {
                if number >= 8 {
                    return CoachingSession.TaskInsight(
                        icon: "flame.fill",
                        text: "High priority (\(number)/10)"
                    )
                } else if number >= 5 {
                    return CoachingSession.TaskInsight(
                        icon: "circle.fill",
                        text: "Medium priority (\(number)/10)"
                    )
                } else {
                    return CoachingSession.TaskInsight(
                        icon: "minus.circle.fill",
                        text: "Lower priority (\(number)/10) - maybe skip?"
                    )
                }
            }
            return nil

        case .needAnythingFirst:
            if answerLower.contains("no") || answerLower.contains("nothing") {
                return CoachingSession.TaskInsight(
                    icon: "checkmark.circle.fill",
                    text: "All set to start"
                )
            } else {
                return CoachingSession.TaskInsight(
                    icon: "tray.and.arrow.down.fill",
                    text: "Need first: \(answer)"
                )
            }

        case .howLong:
            return CoachingSession.TaskInsight(
                icon: "clock.fill",
                text: "Estimated: \(answer)"
            )

        case .breakItDown:
            return CoachingSession.TaskInsight(
                icon: "1.circle.fill",
                text: "First step: \(answer)"
            )

        case .whyImportant:
            return CoachingSession.TaskInsight(
                icon: "heart.fill",
                text: "Matters because: \(answer)"
            )

        case .whenBestTime:
            return CoachingSession.TaskInsight(
                icon: "calendar.circle.fill",
                text: "Best time: \(answer)"
            )
        }
    }

    // MARK: - Quick Question

    /// Single quick question without full session
    func quickQuestion(for task: GadflyTask) -> QuestionType {
        let titleLower = task.title.lowercased()

        // Vague task
        if titleLower.contains("stuff") || titleLower.contains("things") {
            return .whatDoneLooksLike
        }

        // Complex task
        if titleLower.contains("project") || titleLower.contains("plan") {
            return .breakItDown
        }

        // Default
        return .whatsBlocking
    }

    // MARK: - End Session

    func endSession() {
        currentSession = nil
        currentQuestion = nil
        suggestedQuestions = []
    }
}

// MARK: - Coaching View

struct TaskCoachView: View {
    let task: GadflyTask
    @Binding var isPresented: Bool
    let onComplete: ([TaskCoach.CoachingSession.TaskInsight]) -> Void

    @StateObject private var coach = TaskCoach.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Task reminder
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Current question
                if let question = coach.currentQuestion {
                    questionCard(question)
                } else if coach.currentSession?.isComplete == true {
                    completionView
                }

                Spacer()

                // Insights gathered
                if let session = coach.currentSession, !session.insights.isEmpty {
                    insightsView(session.insights)
                }
            }
            .padding()
            .navigationTitle("Let's figure this out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let insights = coach.currentSession?.insights ?? []
                        coach.endSession()
                        onComplete(insights)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                coach.startCoaching(for: task)
            }
        }
    }

    // MARK: - Question Card

    @ViewBuilder
    private func questionCard(_ question: TaskCoach.QuestionType) -> some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: question.icon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            // Question
            Text(question.question)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Hint
            Text(question.followUpHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Voice input button (primary)
            VoiceAnswerButton { answer in
                coach.answerQuestion(answer)
            }

            // Skip option
            Button {
                coach.skipQuestion()
            } label: {
                Text("Skip this question")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Completion View

    @ViewBuilder
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Nice, you've got this!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sometimes just talking it through helps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Insights View

    @ViewBuilder
    private func insightsView(_ insights: [TaskCoach.CoachingSession.TaskInsight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What we figured out")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(insights.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: insights[index].icon)
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text(insights[index].text)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Voice Answer Button

struct VoiceAnswerButton: View {
    let onAnswer: (String) -> Void

    @State private var isRecording = false
    @State private var answer = ""

    var body: some View {
        VStack(spacing: 12) {
            // Record button
            Button {
                // Toggle recording (would connect to speech recognition)
                isRecording.toggle()

                if !isRecording && !answer.isEmpty {
                    onAnswer(answer)
                    answer = ""
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 64, height: 64)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            Text(isRecording ? "Tap to stop" : "Tap to answer")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Text fallback
            if !isRecording {
                TextField("Or type here...", text: $answer)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !answer.isEmpty {
                            onAnswer(answer)
                            answer = ""
                        }
                    }
            }
        }
    }
}

// MARK: - Quick Coach Button

/// Inline button to start coaching for a task
struct QuickCoachButton: View {
    let task: GadflyTask
    @State private var showCoaching = false

    var body: some View {
        Button {
            showCoaching = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Talk it through")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .sheet(isPresented: $showCoaching) {
            TaskCoachView(
                task: task,
                isPresented: $showCoaching,
                onComplete: { _ in }
            )
        }
    }
}

// MARK: - Preview

#Preview("Task Coaching") {
    TaskCoachView(
        task: GadflyTask(
            title: "Work on project stuff",
            dueDate: nil,
            priority: .medium
        ),
        isPresented: .constant(true),
        onComplete: { _ in }
    )
}
