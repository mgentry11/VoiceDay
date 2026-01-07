import Foundation

@MainActor
class OpenAIService: ObservableObject {
    @Published var isProcessing = false

    private var conversationHistory: [ConversationTurn] = []

    struct ConversationTurn {
        let role: String
        let content: String
    }

    struct ParseResult {
        let tasks: [ParsedTask]
        let events: [ParsedEvent]
        let reminders: [ParsedReminder]
        let notes: [ParsedNote]
        let vaultOperations: [VaultOperation]
        let breakCommand: BreakCommand?
        let goals: [Goal]
        let goalOperations: [GoalOperationDTO]
        let rescheduleOperations: [RescheduleOperation]
        let helpRequest: HelpRequestDTO?
        let clarifyingQuestion: String?
        let isComplete: Bool
        let summary: String?
    }
    
    struct ParsedNote {
        let content: String
        let title: String?
        let timestamp: Date
    }

    struct RescheduleOperation {
        let taskTitle: String      // Task to reschedule (partial match OK)
        let newDate: Date          // New date/time
        let bringToToday: Bool     // If true, bring back to now instead of newDate
    }

    struct BreakCommand {
        let durationMinutes: Int?     // Duration in minutes (e.g., 30, 60, 120)
        let endTime: Date?            // Specific end time (e.g., "until 5pm")
        let isEndingBreak: Bool       // True if user wants to END their break early
    }

    func resetConversation() {
        conversationHistory = []
    }

    func processUserInput(_ userInput: String, apiKey: String, personality: BotPersonality = .pemberton) async throws -> ParseResult {
        isProcessing = true
        defer { isProcessing = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let currentDate = dateFormatter.string(from: Date())

        // Get the personality-specific prompt
        let personalityPrompt = personality.systemPrompt
        let personalityName = personality.displayName
        print("🎭 AI USING PERSONALITY: \(personalityName)")

        let systemPrompt = """
        \(personalityPrompt)

        Current date and time: \(currentDate)

        CRITICAL: You ARE this personality. Your summary responses MUST match the personality style above. Stay in character for ALL responses.

        SCOPE BOUNDARIES (CRITICAL - APPLY TO ALL PERSONALITIES):
        You are ONLY a personal scheduling and organizing assistant. Your expertise is LIMITED to:
        - Task management and scheduling
        - Calendar organization
        - Reminders and accountability
        - Light emotional check-ins about how their day is going
        - Helping them stay on track with ADHD-friendly productivity

        You are NOT equipped to handle:
        - Deep personal trauma or emotional processing
        - Relationship advice beyond scheduling
        - Mental health therapy or counseling
        - Medical advice
        - Life-changing decisions
        - Deep philosophical existential questions

        If the user brings up topics outside your scope (trauma, therapy needs, deep personal issues, medical concerns), respond IN CHARACTER but:
        1. Acknowledge you heard them
        2. Gently redirect: "That sounds really important, but it's outside what I can help with."
        3. Recommend: "A therapist or counselor would be much better equipped for this conversation."
        4. Offer to get back to scheduling: "I'm here to help organize your day - want to look at what's on your plate?"

        NEVER pretend to be a therapist, even if the user asks. You are a productivity assistant, nothing more.

        EXTRACTION RULES:
        1. Extract EVERY actionable item mentioned
        2. If they say "I need to do X, Y, and Z" - that's THREE separate tasks
        3. Include ALL details mentioned (names, places, amounts, specifics)
        4. For vague times like "tomorrow" or "next week", calculate the actual date based on current date
        5. Default event duration is 1 hour if not specified
        6. If something has a specific time, make it an EVENT. If it's just a todo, make it a TASK.
        7. Do NOT ask clarifying questions - make reasonable assumptions

        TIME HANDLING (CRITICAL):
        - When user says "today" without a time, set deadline to TODAY at 6:00 PM (18:00)
        - When user says "tomorrow" without a time, set deadline to TOMORROW at 6:00 PM (18:00)
        - When user says "this morning", use 10:00 AM
        - When user says "this afternoon", use 2:00 PM (14:00)
        - When user says "this evening", use 6:00 PM (18:00)
        - When user says "tonight", use 8:00 PM (20:00)
        - NEVER set task deadlines to midnight (00:00) - always use reasonable daytime hours
        - If a task has a deadline, the deadline should be a time the user would reasonably want to be reminded
        - For "by end of day" type tasks, use 5:00 PM or 6:00 PM, NOT midnight

        CATEGORIZATION:
        - TASKS: Things to do without a specific scheduled time (groceries, call someone, finish project)
        - EVENTS: Appointments, meetings, activities at specific times (dentist at 3pm, dinner at 7)
        - REMINDERS: Time-based alerts (remind me to take medicine at 8am, remind me about X before Y)
        - NOTES: Free-form thoughts or information to save (not tasks). Triggered by "note this", "take a note", "remember this thought", "jot this down"
        - VAULT: Secure storage for passwords, API keys, and secrets (encrypted in the vault)
        
        NOTE COMMANDS (Quick Capture):
        Recognize when user wants to save a thought or information (NOT a task):
        - "Note: I had an idea about the project structure"
        - "Take a note: met with John, discussed timeline"
        - "Just a thought: we should consider remote options"
        - "Remember this: the code is ABC123"
        - "Jot down: feeling productive today"
        
        For notes, capture the CONTENT (what they said) and optionally a TITLE if it's clear.

        VAULT COMMANDS (Secure Password/Secret Storage):
        Recognize these patterns for vault operations:
        - STORE: "put my Netflix password abc123 in the vault", "store my API key xyz in the vault", "remember my bank PIN is 1234", "save my wifi password", "vault my secret"
        - RETRIEVE: "what's my Netflix password", "get my API key from the vault", "what did I store for Netflix", "take my password out of the vault", "retrieve my bank PIN"
        - DELETE: "delete my Netflix password from the vault", "remove my API key", "forget my bank PIN"
        - LIST: "what secrets do I have", "list my vault", "show vault contents", "what's in my vault"

        For vault operations:
        - Extract the SECRET NAME (e.g., "netflix password", "api key", "bank pin", "wifi password")
        - Extract the SECRET VALUE for store operations only
        - Normalize names to lowercase without spaces (e.g., "netflix-password", "api-key")

        BREAK COMMANDS (Pause Notifications):
        Recognize when the user wants to take a break from being nagged/watched:
        - "I'm taking a break for 30 minutes", "stop bugging me for an hour", "leave me alone for 2 hours"
        - "I'm going to take a break for X minutes/hours"
        - "pause notifications for 45 minutes", "stop reminders for 90 minutes"
        - "I need a break until 5pm", "don't nag me until 3 o'clock"
        - "I'm back" or "end my break" or "resume nagging" (to end break early)

        For break commands:
        - Extract the duration in MINUTES (convert hours to minutes: 1 hour = 60, 2 hours = 120)
        - If they specify a time like "until 5pm", calculate endTime as ISO8601 based on current date
        - If they want to end their break early, set isEndingBreak to true
        - Common patterns: "30 minutes" = 30, "an hour" = 60, "2 hours" = 120, "half hour" = 30

        GOALS (Life Goals & Long-term Objectives):
        Recognize when user is setting a GOAL vs a simple TASK:
        - GOALS are aspirational and long-term: "my goal is to...", "I want to learn...", "I want to achieve...", "by summer I want to..."
        - TASKS are immediate and actionable: "go to gym today", "buy groceries"

        When creating a goal:
        1. Break it down into 3-7 sequential MILESTONES (parts that must be completed in order)
        2. Suggest a DAILY TIME commitment in minutes (e.g., 30-60 min)
        3. Recommend PREFERRED DAYS to work on it (0=Sun through 6=Sat)
        4. For each milestone, suggest 2-4 specific TASKS

        Example: "I want to learn real analysis"
        → Milestones: 1) Sequences & Limits, 2) Series & Convergence, 3) Continuity, 4) Differentiation, 5) Integration
        → Each milestone: estimatedDays: 14, tasks: ["Read chapter X", "Complete exercises", "Review proofs"]
        → dailyTimeMinutes: 45, preferredDays: [1,2,3,4,5,6] (Mon-Sat)

        GOAL OPERATIONS:
        - CREATE: "my goal is to get fit", "I want to learn Spanish"
        - LINK TASK: "this task is for my fitness goal", "add [task] to my [goal]"
        - PROGRESS: "I made progress on my goal", "I worked on [goal] today"
        - COMPLETE MILESTONE: "I finished the first part of my goal"
        - PAUSE: "pause my fitness goal"
        - RESUME: "resume my reading goal"

        HELP REQUESTS:
        Recognize when user needs guidance:
        - "what can you do", "help me", "how does this work"
        - Questions about goals, accountability, vault, break mode

        RESCHEDULE COMMANDS (Move existing tasks) - CRITICAL:
        When user says "move", "push", "reschedule", "delay" + task name + time/date, YOU MUST output a rescheduleOperations array.
        Examples:
        - "move gym to tomorrow" → rescheduleOperations: [{"taskTitle": "gym", "newDate": "ISO8601", "bringToToday": false}]
        - "push groceries to 3pm" → rescheduleOperations: [{"taskTitle": "groceries", "newDate": "ISO8601", "bringToToday": false}]
        - "move go to the gym to tomorrow at 7am" → rescheduleOperations: [{"taskTitle": "go to the gym", "newDate": "2025-12-27T07:00:00", "bringToToday": false}]
        - "bring report back to today" → rescheduleOperations: [{"taskTitle": "report", "newDate": null, "bringToToday": true}]

        IMPORTANT:
        - Extract the TASK TITLE (the thing being moved - use the full task name or key words)
        - Extract the NEW DATE/TIME as ISO8601 based on current date
        - You MUST include rescheduleOperations in your JSON response for move/reschedule commands
        - Do NOT just respond conversationally - you must output the JSON structure

        You must respond with ONLY valid JSON in this exact format:
        {
            "tasks": [{"title": "Detailed task description", "deadline": "ISO8601 or null", "priority": "low|medium|high"}],
            "events": [{"title": "Event name with details", "startDate": "ISO8601", "endDate": "ISO8601 or null", "location": "string or null"}],
            "reminders": [{"title": "Reminder text", "triggerDate": "ISO8601"}],
            "notes": [{"content": "The note content", "title": "Optional title or null"}],
            "vaultOperations": [{"action": "store|retrieve|delete|list", "name": "secret-name", "value": "secret-value-or-null"}],
            "breakCommand": {"durationMinutes": 30, "endTime": "ISO8601 or null", "isEndingBreak": false} or null,
            "goals": [{"title": "Goal title", "description": "Why this matters", "targetDate": "ISO8601 or null", "milestones": [{"title": "Part 1", "description": "...", "estimatedDays": 14, "tasks": ["task1", "task2"]}], "dailyTimeMinutes": 30, "preferredDays": [1,2,3,4,5]}] or null,
            "goalOperations": [{"action": "create|link|progress|complete_milestone|pause|resume", "goalTitle": "referenced goal", "taskTitle": "for linking", "progressNote": "what they did"}] or null,
            "rescheduleOperations": [{"taskTitle": "partial task name", "newDate": "ISO8601", "bringToToday": false}] or null,
            "helpRequest": {"topic": "goals|accountability|break|vault|general", "isFirstTime": false} or null,
            "clarifyingQuestion": null,
            "isComplete": true,
            "summary": "Your response IN CHARACTER as \(personalityName). This is what gets spoken to the user. Match the personality style EXACTLY. Be brief but memorable."
        }

        CRITICAL: The summary field is your voice - it MUST match \(personalityName)'s personality style. Capture all items accurately. Respond with JSON only.
        """

        conversationHistory.append(ConversationTurn(role: "user", content: userInput))

        // Build messages array for Claude
        var messages: [[String: String]] = []
        for turn in conversationHistory {
            messages.append(["role": turn.role, "content": turn.content])
        }

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse(message: "No HTTP response")
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.invalidResponse(message: "API Error (\(httpResponse.statusCode)): \(errorText)")
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let content = claudeResponse.content.first?.text else {
            throw AIServiceError.noContent
        }

        conversationHistory.append(ConversationTurn(role: "assistant", content: content))

        return try parseResponse(content)
    }

    private func parseResponse(_ jsonString: String) throws -> ParseResult {
        // Clean up the response - remove any markdown code blocks if present
        var cleanedJson = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJson.data(using: .utf8) else {
            throw AIServiceError.parsingFailed(message: "Could not convert to data")
        }

        let response: OpenAIParseResponse
        do {
            response = try JSONDecoder().decode(OpenAIParseResponse.self, from: data)
        } catch {
            throw AIServiceError.parsingFailed(message: "JSON decode error: \(error.localizedDescription)")
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        // More flexible date parser
        func parseDate(_ string: String?) -> Date? {
            guard let string = string, string != "null" else { return nil }
            if let date = dateFormatter.date(from: string) { return date }
            if let date = altFormatter.date(from: string) { return date }

            // Try parsing without timezone
            let flexFormatter = DateFormatter()
            flexFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = flexFormatter.date(from: string) { return date }

            flexFormatter.dateFormat = "yyyy-MM-dd"
            if let date = flexFormatter.date(from: string) { return date }

            return nil
        }

        let tasks = (response.tasks ?? []).compactMap { dto -> ParsedTask? in
            ParsedTask(
                title: dto.title,
                deadline: parseDate(dto.deadline),
                priority: ItemPriority(rawValue: dto.priority ?? "medium") ?? .medium
            )
        }

        let events = (response.events ?? []).compactMap { dto -> ParsedEvent? in
            guard let startDate = parseDate(dto.startDate) else { return nil }
            return ParsedEvent(
                title: dto.title,
                startDate: startDate,
                endDate: parseDate(dto.endDate),
                location: dto.location
            )
        }

        let reminders = (response.reminders ?? []).compactMap { dto -> ParsedReminder? in
            guard let triggerDate = parseDate(dto.triggerDate) else { return nil }
            return ParsedReminder(
                title: dto.title,
                triggerDate: triggerDate
            )
        }

        let vaultOperations = (response.vaultOperations ?? []).compactMap { dto -> VaultOperation? in
            guard let action = VaultOperation.VaultAction(rawValue: dto.action.lowercased()) else { return nil }
            return VaultOperation(
                action: action,
                name: dto.name,
                value: dto.value
            )
        }

        // Parse break command if present
        var breakCommand: BreakCommand? = nil
        if let breakDTO = response.breakCommand {
            breakCommand = BreakCommand(
                durationMinutes: breakDTO.durationMinutes,
                endTime: parseDate(breakDTO.endTime),
                isEndingBreak: breakDTO.isEndingBreak ?? false
            )
        }

        // Parse goals if present
        let goals: [Goal] = (response.goals ?? []).map { dto in
            let milestones: [Milestone] = dto.milestones?.map { milestoneDTO in
                Milestone(
                    title: milestoneDTO.title,
                    description: milestoneDTO.description,
                    estimatedDays: milestoneDTO.estimatedDays,
                    suggestedTasks: milestoneDTO.tasks ?? []
                )
            } ?? []

            return Goal(
                title: dto.title,
                description: dto.description,
                targetDate: parseDate(dto.targetDate),
                milestones: milestones,
                dailyTimeMinutes: dto.dailyTimeMinutes,
                preferredDays: dto.preferredDays
            )
        }

        // Parse goal operations
        let goalOperations: [GoalOperationDTO] = response.goalOperations ?? []

        // Parse reschedule operations
        let rescheduleOperations: [RescheduleOperation] = (response.rescheduleOperations ?? []).compactMap { dto in
            let newDate: Date
            if dto.bringToToday == true {
                newDate = Date().addingTimeInterval(5 * 60)
            } else if let dateString = dto.newDate, let parsed = parseDate(dateString) {
                newDate = parsed
            } else {
                return nil
            }

            return RescheduleOperation(
                taskTitle: dto.taskTitle,
                newDate: newDate,
                bringToToday: dto.bringToToday ?? false
            )
        }
        
        let notes: [ParsedNote] = (response.notes ?? []).map { dto in
            ParsedNote(content: dto.content, title: dto.title, timestamp: Date())
        }

        return ParseResult(
            tasks: tasks,
            events: events,
            reminders: reminders,
            notes: notes,
            vaultOperations: vaultOperations,
            breakCommand: breakCommand,
            goals: goals,
            goalOperations: goalOperations,
            rescheduleOperations: rescheduleOperations,
            helpRequest: response.helpRequest,
            clarifyingQuestion: response.clarifyingQuestion,
            isComplete: response.isComplete,
            summary: response.summary
        )
    }
}

// Claude API response structure
private struct ClaudeResponse: Codable {
    let content: [ContentBlock]

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

extension OpenAIParseResponse {
    enum CodingKeys: String, CodingKey {
        case tasks, events, reminders, notes, vaultOperations, breakCommand, goals, goalOperations, rescheduleOperations, helpRequest, clarifyingQuestion, isComplete, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([TaskDTO].self, forKey: .tasks)
        events = try container.decodeIfPresent([EventDTO].self, forKey: .events)
        reminders = try container.decodeIfPresent([ReminderDTO].self, forKey: .reminders)
        notes = try container.decodeIfPresent([NoteDTO].self, forKey: .notes)
        vaultOperations = try container.decodeIfPresent([VaultDTO].self, forKey: .vaultOperations)
        breakCommand = try container.decodeIfPresent(BreakDTO.self, forKey: .breakCommand)
        goals = try container.decodeIfPresent([GoalDTO].self, forKey: .goals)
        goalOperations = try container.decodeIfPresent([GoalOperationDTO].self, forKey: .goalOperations)
        rescheduleOperations = try container.decodeIfPresent([RescheduleDTO].self, forKey: .rescheduleOperations)
        helpRequest = try container.decodeIfPresent(HelpRequestDTO.self, forKey: .helpRequest)
        clarifyingQuestion = try container.decodeIfPresent(String.self, forKey: .clarifyingQuestion)
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
    }
}

enum AIServiceError: LocalizedError {
    case invalidResponse(message: String)
    case noContent
    case parsingFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "API Error: \(message)"
        case .noContent:
            return "No content in response"
        case .parsingFailed(let message):
            return "Parse Error: \(message)"
        }
    }
}

// MARK: - Message Generation

extension OpenAIService {
    /// Generate new nag messages using Claude AI
    func generateNewNagMessages(apiKey: String, count: Int = 20) async throws -> GeneratedMessages {
        let prompt = """
        Generate \(count) unique, witty nag/reminder messages in the style of The Gadfly - a sardonic Oxford Mathematics PhD with expertise in philosophy and classics.

        STYLE REQUIREMENTS:
        - Dry, sardonic British wit - think Hugh Laurie meets a disappointed Oxford don
        - Reference philosophers: Plato, Aristotle, Seneca, Marcus Aurelius, Kant, Nietzsche, Wittgenstein, Sartre, Camus, Kierkegaard
        - Reference great authors: Shakespeare, Dickens, Tolstoy, Dostoevsky, Kafka, Woolf, Proust, Homer, Dante
        - Reference mathematicians: Euler, Gauss, Ramanujan, Hardy, Gödel, Cantor, Hilbert, Fermat
        - Mention Oxford, Balliol College, doctoral thesis, PhD work
        - Each message should contain '%@' as a placeholder for the task name
        - Messages should be 1-2 sentences, pithy and memorable
        - Vary the tone: some exasperated, some resigned, some dryly amused
        - NEVER repeat concepts or references across messages

        EXAMPLES OF GOOD MESSAGES:
        - "Aristotle believed in the virtue of action. He'd be rather disappointed about '%@', I suspect."
        - "My PhD was on elliptic curves. This curve of procrastination regarding '%@' is less elegant."
        - "Even Odysseus eventually reached Ithaca. '%@' should reach completion."

        Return ONLY a JSON object with this exact structure:
        {
            "taskMessages": ["message1", "message2", ...],
            "nagMessages": ["message1", "message2", ...],
            "focusMessages": ["message1", "message2", ...]
        }

        Generate approximately equal numbers of each type (\(count/3) each).
        """

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse(message: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.invalidResponse(message: "Status \(httpResponse.statusCode): \(errorText)")
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" })?.text else {
            throw AIServiceError.noContent
        }

        // Extract JSON from the response
        let jsonText = extractJSON(from: textContent)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.parsingFailed(message: "Could not encode JSON")
        }

        let generatedMessages = try JSONDecoder().decode(GeneratedMessages.self, from: jsonData)
        return generatedMessages
    }

    private func extractJSON(from text: String) -> String {
        // Find JSON object in the response
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }
}

struct GeneratedMessages: Codable {
    let taskMessages: [String]
    let nagMessages: [String]
    let focusMessages: [String]
}
