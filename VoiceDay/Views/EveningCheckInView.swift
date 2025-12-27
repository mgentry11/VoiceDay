import SwiftUI
import AVFoundation

/// End of day check-in - take emotional temperature
/// Light questions about changeable behaviors, not deep therapy
struct EveningCheckInView: View {
    let completedTaskCount: Int
    let morningIntention: String?  // What they said they wanted to accomplish
    let onComplete: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState

    @State private var showingIntro = true
    @State private var currentStep: CheckInStep = .mood
    @State private var selectedMood: Mood?
    @State private var selectedFactors: Set<DownFactor> = []

    enum CheckInStep {
        case mood
        case factors      // Only if mood is low
        case suggestion   // Actionable advice
        case celebration  // If mood is good or after suggestions
    }

    enum Mood: String, CaseIterable {
        case great = "Great"
        case good = "Good"
        case okay = "Okay"
        case low = "Not great"
        case rough = "Rough"

        var emoji: String {
            switch self {
            case .great: return "😄"
            case .good: return "🙂"
            case .okay: return "😐"
            case .low: return "😔"
            case .rough: return "😢"
            }
        }

        var color: Color {
            switch self {
            case .great: return .green
            case .good: return .mint
            case .okay: return .yellow
            case .low: return .orange
            case .rough: return .red
            }
        }

        var needsFollowUp: Bool {
            self == .low || self == .rough
        }
    }

    enum DownFactor: String, CaseIterable {
        case socialMedia = "Too much scrolling"
        case news = "Upsetting news/videos"
        case sleep = "Didn't sleep well"
        case skippedMeals = "Skipped meals"
        case noExercise = "No movement today"
        case isolation = "Felt isolated"
        case overwhelmed = "Too much to do"
        case comparison = "Comparing myself to others"

        var icon: String {
            switch self {
            case .socialMedia: return "iphone"
            case .news: return "tv"
            case .sleep: return "moon.zzz"
            case .skippedMeals: return "fork.knife"
            case .noExercise: return "figure.walk"
            case .isolation: return "person.slash"
            case .overwhelmed: return "list.bullet"
            case .comparison: return "person.2"
            }
        }

        var suggestion: String {
            switch self {
            case .socialMedia:
                return "Try setting a 30-min daily limit on social apps. Your brain will thank you."
            case .news:
                return "Consider a news break tomorrow. You can't fix the world, but you can protect your peace."
            case .sleep:
                return "Tonight, try no screens 30 mins before bed. It really helps."
            case .skippedMeals:
                return "Set a reminder to eat. Your brain needs fuel to function."
            case .noExercise:
                return "Even a 10-minute walk counts. Movement changes everything."
            case .isolation:
                return "Text one person tomorrow. Connection matters more than we think."
            case .overwhelmed:
                return "Tomorrow, pick just ONE important thing. The rest can wait."
            case .comparison:
                return "Everyone's highlight reel looks better than your behind-the-scenes. You're doing fine."
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            if showingIntro {
                introView
            } else {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStepIndex ? Color.themeAccent : Color.themeSecondary)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top)

                Spacer()

                // Content based on step
                switch currentStep {
                case .mood:
                    moodSelectionView
                case .factors:
                    factorsView
                case .suggestion:
                    suggestionView
                case .celebration:
                    celebrationView
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.themeBackground)
        .onAppear {
            speakIntroGreeting()
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Personality emoji
            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 80))

            // Greeting
            Text(getEveningGreeting())
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Task summary if any
            if completedTaskCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("You completed \(completedTaskCount) task\(completedTaskCount == 1 ? "" : "s") today")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                }
                .padding()
                .background(Color.themeSecondary)
                .cornerRadius(12)
            }

            // What this check-in covers
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick check-in:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.subtext)

                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text("How are you feeling?")
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Quick tips for tomorrow")
                        .font(.subheadline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.themeSecondary)
            .cornerRadius(12)

            Spacer()

            // Start button
            Button {
                startCheckIn()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Let's Check In")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.themeAccent)
                .cornerRadius(16)
            }

            // Skip option
            Button {
                onComplete()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding(.bottom, 8)
        }
    }

    private func getEveningGreeting() -> String {
        switch appState.selectedPersonality {
        case .pemberton:
            return "Good evening. Time to take stock of the day."
        case .sergent:
            return "End of day debrief! How'd we do today?"
        case .cheerleader:
            return "Hey superstar! Let's reflect on your amazing day!"
        case .hypeFriend:
            return "YO! Day's almost done! How you feeling?!"
        case .chillBuddy:
            return "Hey... day's winding down. Quick check-in?"
        case .tiredParent:
            return "Almost bedtime. Let's see how today went."
        default:
            return "Good evening! Quick end-of-day check-in?"
        }
    }

    private func startCheckIn() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3)) {
            showingIntro = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            speakMoodQuestion()
        }
    }

    private func speakIntroGreeting() {
        let greeting = getEveningGreeting()
        speak(greeting)
    }

    private var totalSteps: Int {
        selectedMood?.needsFollowUp == true ? 4 : 2
    }

    private var currentStepIndex: Int {
        switch currentStep {
        case .mood: return 0
        case .factors: return 1
        case .suggestion: return 2
        case .celebration: return selectedMood?.needsFollowUp == true ? 3 : 1
        }
    }

    // MARK: - Mood Selection

    private var moodSelectionView: some View {
        VStack(spacing: 24) {
            // Personality greeting
            VStack(spacing: 12) {
                Text(appState.selectedPersonality.emoji)
                    .font(.system(size: 60))

                Text(getMoodQuestion())
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
            }

            // Day summary
            if completedTaskCount > 0 {
                Text("You completed \(completedTaskCount) task\(completedTaskCount == 1 ? "" : "s") today")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext)
            }

            // Mood buttons - BIG
            VStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        selectMood(mood)
                    } label: {
                        HStack(spacing: 16) {
                            Text(mood.emoji)
                                .font(.title)
                            Text(mood.rawValue)
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundStyle(themeColors.text)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.themeSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(mood.color, lineWidth: selectedMood == mood ? 3 : 0)
                        )
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Factors View (why feeling down)

    private var factorsView: some View {
        VStack(spacing: 24) {
            Text("Any of these happen today?")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(themeColors.text)

            Text("(Tap any that apply)")
                .font(.caption)
                .foregroundStyle(themeColors.subtext)

            // Factor buttons - 2 per row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(DownFactor.allCases, id: \.self) { factor in
                    Button {
                        toggleFactor(factor)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: factor.icon)
                                .font(.title2)
                            Text(factor.rawValue)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(selectedFactors.contains(factor) ? .white : themeColors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(selectedFactors.contains(factor) ? Color.orange : Color.themeSecondary)
                        .cornerRadius(12)
                    }
                }
            }

            // Continue button
            Button {
                withAnimation {
                    currentStep = .suggestion
                }
                speakSuggestion()
            } label: {
                Text(selectedFactors.isEmpty ? "Nothing specific" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Suggestion View

    private var suggestionView: some View {
        VStack(spacing: 24) {
            Text(appState.selectedPersonality.emoji)
                .font(.system(size: 50))

            if let factor = selectedFactors.first {
                VStack(spacing: 16) {
                    Text("One small thing for tomorrow:")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    Text(factor.suggestion)
                        .font(.body)
                        .foregroundStyle(themeColors.text)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.themeSecondary)
                        .cornerRadius(12)
                }
            } else {
                Text(getGenericEncouragement())
                    .font(.body)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
            }

            // Empathetic close
            Text(getEmpathyMessage())
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .italic()
                .multilineTextAlignment(.center)

            Button {
                withAnimation {
                    currentStep = .celebration
                }
            } label: {
                Text("Thanks")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Celebration View

    private var celebrationView: some View {
        VStack(spacing: 24) {
            // Different based on mood
            if selectedMood?.needsFollowUp == true {
                // Gentle close for tough days
                VStack(spacing: 16) {
                    Text("🌙")
                        .font(.system(size: 60))

                    Text("Tomorrow is a fresh start")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColors.text)

                    Text("Rest well. You did your best today.")
                        .font(.body)
                        .foregroundStyle(themeColors.subtext)
                }
            } else {
                // Celebration for good days
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 60))

                    Text(getCelebrationMessage())
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColors.text)

                    if let intention = morningIntention {
                        VStack(spacing: 8) {
                            Text("Your intention was:")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                            Text(intention)
                                .font(.body)
                                .foregroundStyle(themeColors.text)
                                .italic()
                        }
                        .padding()
                        .background(Color.themeSecondary)
                        .cornerRadius(12)
                    }
                }
            }

            Button {
                onComplete()
            } label: {
                Text("Good night")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Actions

    private func selectMood(_ mood: Mood) {
        selectedMood = mood
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation {
            if mood.needsFollowUp {
                currentStep = .factors
                speakFactorsQuestion()
            } else {
                currentStep = .celebration
                speakCelebration()
            }
        }
    }

    private func toggleFactor(_ factor: DownFactor) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if selectedFactors.contains(factor) {
            selectedFactors.remove(factor)
        } else {
            selectedFactors.insert(factor)
        }
    }

    // MARK: - Voice

    private func speak(_ text: String) {
        SpeechService.shared.queueSpeech(text)
    }

    private func speakMoodQuestion() {
        speak(getMoodQuestion())
    }

    private func speakFactorsQuestion() {
        speak("Did any of these happen today?")
    }

    private func speakSuggestion() {
        if let factor = selectedFactors.first {
            speak("Here's one small thing for tomorrow. \(factor.suggestion)")
        }
    }

    private func speakCelebration() {
        speak(getCelebrationMessage())
    }

    // MARK: - Messages

    private func getMoodQuestion() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Well then, how did today's endeavors leave you feeling?"
        case .sergent:
            return "End of day report! How are you holding up, soldier?"
        case .cheerleader:
            return "Hey superstar! How are you feeling after today?"
        case .therapist:
            return "Let's check in. How are you feeling right now?"
        case .tiredParent:
            return "End of day. How are we doing?"
        default:
            return "How are you feeling at the end of today?"
        }
    }

    private func getCelebrationMessage() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "A satisfactory day. Perhaps there's hope for you yet."
        case .cheerleader:
            return "You're AMAZING! Another great day in the books!"
        case .hypeFriend:
            return "CRUSHED IT! You're literally unstoppable!"
        case .tiredParent:
            return "We made it through another day. That's a win."
        default:
            return "Great job today! Rest well."
        }
    }

    private func getGenericEncouragement() -> String {
        "Tough days happen. What matters is you're here, reflecting, trying. That's more than most people do."
    }

    private func getEmpathyMessage() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Even Sisyphus had rough days. Tomorrow offers another attempt."
        case .cheerleader:
            return "Every day can't be perfect, and that's totally okay! I believe in you!"
        case .therapist:
            return "It's okay to have hard days. Being aware of what affects you is powerful."
        case .tiredParent:
            return "We're all just doing our best. That's enough."
        default:
            return "Tomorrow is a new day. Be gentle with yourself."
        }
    }
}

#Preview {
    EveningCheckInView(
        completedTaskCount: 5,
        morningIntention: "Finish the quarterly report",
        onComplete: {}
    )
    .environmentObject(AppState())
}
