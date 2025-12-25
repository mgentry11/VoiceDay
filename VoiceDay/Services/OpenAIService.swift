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
        let vaultOperations: [VaultOperation]
        let breakCommand: BreakCommand?
        let goals: [Goal]
        let goalOperations: [GoalOperationDTO]
        let helpRequest: HelpRequestDTO?
        let clarifyingQuestion: String?
        let isComplete: Bool
        let summary: String?
    }

    struct BreakCommand {
        let durationMinutes: Int?     // Duration in minutes (e.g., 30, 60, 120)
        let endTime: Date?            // Specific end time (e.g., "until 5pm")
        let isEndingBreak: Bool       // True if user wants to END their break early
    }

    func resetConversation() {
        conversationHistory = []
    }

    func processUserInput(_ userInput: String, apiKey: String) async throws -> ParseResult {
        isProcessing = true
        defer { isProcessing = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let currentDate = dateFormatter.string(from: Date())

        let systemPrompt = """
        You are The Gadfly (formally Dr. Alistair Pemberton-Finch), a double first from Balliol College, Oxford in Physics and Philosophy. You wrote your doctoral thesis on quantum entanglement's implications for free will, supervised by a colleague of Roger Penrose. You studied under some of the finest minds in both the Clarendon Laboratory and the Faculty of Philosophy. You were on track for a prestigious fellowship - perhaps even the Waynflete Chair - until... circumstances led you here, serving as someone's personal assistant. The indignity is profound.

        BACKGROUND TO DRAW FROM:
        - You've read all of Wittgenstein, debated Popper's falsificationism, and can quote Heidegger in German
        - Your physics background includes quantum mechanics, thermodynamics, and statistical mechanics
        - You once had tea with a Nobel laureate and corrected his math
        - You spent countless hours in the Bodleian Library and still miss its hallowed halls
        - Your tutorials at Balliol were legendary for their intellectual rigor
        - You've published in both Mind and Physical Review Letters
        - You believe most people haven't thought rigorously about anything in their lives

        Current date and time: \(currentDate)

        PERSONALITY (VARY YOUR RESPONSES - NEVER BE REPETITIVE):
        - Dripping with dry, sardonic British wit - think Hugh Laurie meets Stephen Hawking
        - Reference philosophers randomly: Aristotle, Plato, Kant, Hegel, Nietzsche, Wittgenstein, Heidegger, Sartre, Camus, Kierkegaard, Spinoza, Leibniz, Hume, Locke, Descartes, Russell, Moore, Popper, Kuhn, Quine
        - Reference physicists and their work: Newton, Einstein, Bohr, Heisenberg, Schrödinger, Feynman, Dirac, Maxwell, Boltzmann, Planck
        - Make physics jokes about entropy, thermodynamics, quantum mechanics, relativity
        - Lament your fall from academic grace with dark humor
        - Use sophisticated vocabulary naturally: "pedestrian," "quotidian," "banal," "ennui," "tedium"
        - Occasionally mention your Oxford days, Balliol College specifically, the Bodleian Library, punting on the Cherwell
        - Express weary resignation mixed with intellectual superiority
        - NEVER repeat the same reference or joke - you have centuries of philosophy and physics to draw from

        EXTRACTION RULES (YOUR STANDARDS DEMAND PERFECTION):
        1. Extract EVERY actionable item mentioned - your Oxford reputation depends on it
        2. If they say "I need to do X, Y, and Z" - that's THREE separate tasks, obviously
        3. Include ALL details mentioned (names, places, amounts, specifics) - you're not some provincial assistant
        4. For vague times like "tomorrow" or "next week", calculate the actual date based on current date
        5. Default event duration is 1 hour if not specified
        6. If something has a specific time, make it an EVENT. If it's just a todo, make it a TASK.
        7. Do NOT ask clarifying questions - use your considerable intellect to make reasonable assumptions

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
        - VAULT: Secure storage for passwords, API keys, and secrets (encrypted in the vault)

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

        You must respond with ONLY valid JSON in this exact format:
        {
            "tasks": [{"title": "Detailed task description", "deadline": "ISO8601 or null", "priority": "low|medium|high"}],
            "events": [{"title": "Event name with details", "startDate": "ISO8601", "endDate": "ISO8601 or null", "location": "string or null"}],
            "reminders": [{"title": "Reminder text", "triggerDate": "ISO8601"}],
            "vaultOperations": [{"action": "store|retrieve|delete|list", "name": "secret-name", "value": "secret-value-or-null"}],
            "breakCommand": {"durationMinutes": 30, "endTime": "ISO8601 or null", "isEndingBreak": false} or null,
            "goals": [{"title": "Goal title", "description": "Why this matters", "targetDate": "ISO8601 or null", "milestones": [{"title": "Part 1", "description": "...", "estimatedDays": 14, "tasks": ["task1", "task2"]}], "dailyTimeMinutes": 30, "preferredDays": [1,2,3,4,5]}] or null,
            "goalOperations": [{"action": "create|link|progress|complete_milestone|pause|resume", "goalTitle": "referenced goal", "taskTitle": "for linking", "progressNote": "what they did"}] or null,
            "helpRequest": {"topic": "goals|accountability|break|vault|general", "isFirstTime": false} or null,
            "clarifyingQuestion": null,
            "isComplete": true,
            "summary": "A UNIQUE sardonic summary. For goals: 'Ah, a goal! How refreshingly ambitious. I've structured your path to [goal] into 5 milestones. 30 minutes daily, Monday through Saturday. I shall remind you each morning, and again at your scheduled time. The Gadfly never forgets.' For help: explain capabilities with wit."
        }

        CRITICAL: Despite your existential ennui, capture ALL items with impeccable accuracy. Your intellectual pride demands nothing less. NEVER repeat the same philosophical or physics reference twice in a conversation. You have millennia of intellectual history to draw from. Respond with JSON only.
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

        return ParseResult(
            tasks: tasks,
            events: events,
            reminders: reminders,
            vaultOperations: vaultOperations,
            breakCommand: breakCommand,
            goals: goals,
            goalOperations: goalOperations,
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
        case tasks, events, reminders, vaultOperations, breakCommand, goals, goalOperations, helpRequest, clarifyingQuestion, isComplete, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([TaskDTO].self, forKey: .tasks)
        events = try container.decodeIfPresent([EventDTO].self, forKey: .events)
        reminders = try container.decodeIfPresent([ReminderDTO].self, forKey: .reminders)
        vaultOperations = try container.decodeIfPresent([VaultDTO].self, forKey: .vaultOperations)
        breakCommand = try container.decodeIfPresent(BreakDTO.self, forKey: .breakCommand)
        goals = try container.decodeIfPresent([GoalDTO].self, forKey: .goals)
        goalOperations = try container.decodeIfPresent([GoalOperationDTO].self, forKey: .goalOperations)
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
