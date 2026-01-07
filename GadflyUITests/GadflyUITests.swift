import XCTest

/// UI Test suite that simulates a user's complete day journey through Gadfly
/// Captures screenshots at each step for documentation and review
final class GadflyUITests: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0
    let screenshotFolder = "uitest_screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        setupScreenshotDirectory()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Helpers

    func setupScreenshotDirectory() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let screenshotPath = documentsPath.appendingPathComponent(screenshotFolder)

        try? fileManager.createDirectory(at: screenshotPath, withIntermediateDirectories: true)
    }

    func captureScreen(_ name: String, description: String = "") {
        screenshotCounter += 1
        let paddedNumber = String(format: "%03d", screenshotCounter)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(paddedNumber)_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        if !description.isEmpty {
            print("📸 [\(paddedNumber)] \(name): \(description)")
        } else {
            print("📸 [\(paddedNumber)] \(name)")
        }
    }

    // MARK: - Full Day Simulation Test

    /// Simulates a complete user day from wake-up to bedtime
    func testFullDayUserJourney() throws {
        app.launch()
        sleep(2) // Wait for launch animation

        // Check if we're on onboarding or main app
        if app.staticTexts["Choose Your Voice"].waitForExistence(timeout: 3) {
            try completeOnboarding()
        }

        captureScreen("main_home", description: "Main home screen after launch/onboarding")

        // === MORNING ROUTINE ===
        try simulateMorningRoutine()

        // === MID-MORNING WORK ===
        try simulateMidMorningWork()

        // === MIDDAY CHECK-IN ===
        try simulateMiddayCheckIn()

        // === AFTERNOON FOCUS ===
        try simulateAfternoonFocus()

        // === EVENING WIND-DOWN ===
        try simulateEveningWindDown()

        // === BEDTIME CHECKLIST ===
        try simulateBedtimeChecklist()

        print("✅ Full day simulation complete! \(screenshotCounter) screenshots captured.")
    }

    // MARK: - Onboarding Flow

    func completeOnboarding() throws {
        captureScreen("onboarding_01_voice", description: "Voice selection screen")

        // Select Quick Start with Defaults
        if app.buttons["Quick Start with Defaults"].exists {
            app.buttons["Quick Start with Defaults"].tap()
            sleep(1)
        } else {
            // Tap first voice option and continue
            app.cells.firstMatch.tap()
            sleep(0.5)
        }

        // Personality selection (step 2)
        if app.staticTexts["Choose Your Personality"].waitForExistence(timeout: 2) {
            captureScreen("onboarding_02_personality", description: "Personality selection")

            // Tap Next button
            if app.buttons["Next: Daily Structure"].exists {
                app.buttons["Next: Daily Structure"].tap()
            } else {
                tapBottomButton()
            }
            sleep(1)
        }

        // Daily Structure (step 3)
        if app.staticTexts["Your Daily Structure"].waitForExistence(timeout: 2) {
            captureScreen("onboarding_03_daily_structure", description: "Daily check-in times")
            tapBottomButton()
            sleep(1)
        }

        // Continue through remaining onboarding steps
        for step in 4...5 {
            sleep(1)
            captureScreen("onboarding_0\(step)_step", description: "Onboarding step \(step)")
            tapBottomButton()
        }

        sleep(2) // Wait for main screen to load
    }

    // MARK: - Morning Routine

    func simulateMorningRoutine() throws {
        print("\n🌅 === MORNING ROUTINE ===")

        // Check if morning check-in modal appears
        if app.staticTexts["Morning Check-in"].waitForExistence(timeout: 2) {
            captureScreen("morning_checkin_modal", description: "Morning check-in prompt")

            // Complete morning items
            let checkItems = app.cells.matching(identifier: "checkInItem")
            for i in 0..<min(checkItems.count, 5) {
                checkItems.element(boundBy: i).tap()
                sleep(0.3)
            }

            captureScreen("morning_checkin_progress", description: "Completing morning items")

            // Dismiss or complete
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            }
        }

        // Navigate to Tasks tab
        tapTab(index: 2) // Tasks tab
        sleep(1)
        captureScreen("tasks_empty", description: "Tasks view")

        // Add a morning task
        try addTask(title: "Review emails", notes: "Check inbox and respond to urgent items")
        captureScreen("task_added", description: "First task added")
    }

    // MARK: - Mid-Morning Work

    func simulateMidMorningWork() throws {
        print("\n☀️ === MID-MORNING WORK ===")

        // Add more tasks
        try addTask(title: "Team standup meeting", notes: "Daily sync at 10am")
        try addTask(title: "Complete project report", notes: "Q4 summary due today")

        captureScreen("tasks_multiple", description: "Multiple tasks added")

        // Navigate to Focus/Home tab
        tapTab(index: 0)
        sleep(1)
        captureScreen("focus_home", description: "Focus home view")

        // Start a focus session if button exists
        if app.buttons["Start Focus"].exists || app.buttons["Begin Focus"].exists {
            let focusButton = app.buttons["Start Focus"].exists ? app.buttons["Start Focus"] : app.buttons["Begin Focus"]
            focusButton.tap()
            sleep(2)
            captureScreen("focus_session_active", description: "Focus session in progress")

            // End focus session
            if app.buttons["End"].exists {
                app.buttons["End"].tap()
            } else if app.buttons["Stop"].exists {
                app.buttons["Stop"].tap()
            }
            sleep(1)
        }
    }

    // MARK: - Midday Check-in

    func simulateMiddayCheckIn() throws {
        print("\n🌞 === MIDDAY CHECK-IN ===")

        // Look for midday check-in or trigger it
        if app.staticTexts["Midday Check-in"].waitForExistence(timeout: 2) ||
           app.staticTexts["Energy Check"].waitForExistence(timeout: 1) {
            captureScreen("midday_checkin", description: "Midday energy/progress check")

            // Select energy level if prompted
            if app.buttons["High"].exists {
                app.buttons["Medium"].tap() // Select medium energy
            }

            captureScreen("midday_energy_selected", description: "Energy level selected")

            if app.buttons["Continue"].exists {
                app.buttons["Continue"].tap()
            }
        }

        // Review and update tasks
        tapTab(index: 2) // Tasks
        sleep(1)

        // Mark a task complete
        if app.cells.count > 0 {
            let firstTask = app.cells.firstMatch
            // Try to find and tap checkbox
            if firstTask.buttons.firstMatch.exists {
                firstTask.buttons.firstMatch.tap()
                sleep(0.5)
                captureScreen("task_completed", description: "Task marked complete")
            }
        }
    }

    // MARK: - Afternoon Focus

    func simulateAfternoonFocus() throws {
        print("\n🌤️ === AFTERNOON FOCUS ===")

        // Add an afternoon task
        try addTask(title: "Client call prep", notes: "Prepare slides for 3pm call")
        captureScreen("afternoon_task", description: "Afternoon task added")

        // Navigate to Goals tab if it exists
        tapTab(index: 3) // Goals
        sleep(1)
        captureScreen("goals_view", description: "Goals overview")

        // Navigate to Recording tab
        tapTab(index: 1)
        sleep(1)
        captureScreen("recording_view", description: "Voice recording view")
    }

    // MARK: - Evening Wind-Down

    func simulateEveningWindDown() throws {
        print("\n🌆 === EVENING WIND-DOWN ===")

        // Check for evening check-in
        if app.staticTexts["Evening Wind-down"].waitForExistence(timeout: 2) ||
           app.staticTexts["Evening Check-in"].waitForExistence(timeout: 1) {
            captureScreen("evening_checkin", description: "Evening wind-down prompt")

            // Answer mood/energy questions
            if app.buttons["Good"].exists {
                app.buttons["Good"].tap()
            }

            captureScreen("evening_mood", description: "Evening mood selection")

            if app.buttons["Continue"].exists || app.buttons["Done"].exists {
                (app.buttons["Continue"].exists ? app.buttons["Continue"] : app.buttons["Done"]).tap()
            }
        }

        // Review day's accomplishments
        tapTab(index: 2) // Tasks
        sleep(1)
        captureScreen("tasks_end_of_day", description: "Tasks at end of day")

        // Navigate to Settings
        tapTab(index: 4) // Settings
        sleep(1)
        captureScreen("settings_view", description: "Settings screen")
    }

    // MARK: - Bedtime Checklist

    func simulateBedtimeChecklist() throws {
        print("\n🌙 === BEDTIME CHECKLIST ===")

        // Check for bedtime checklist modal
        if app.staticTexts["Bedtime Checklist"].waitForExistence(timeout: 2) ||
           app.staticTexts["Before You Sleep"].waitForExistence(timeout: 1) {
            captureScreen("bedtime_checklist_start", description: "Bedtime checklist")

            // Complete checklist items
            let checkItems = app.cells.matching(identifier: "checkInItem")
            for i in 0..<min(checkItems.count, 6) {
                checkItems.element(boundBy: i).tap()
                sleep(0.3)
            }

            captureScreen("bedtime_checklist_done", description: "Bedtime items completed")

            if app.buttons["Done"].exists || app.buttons["Good Night"].exists {
                (app.buttons["Done"].exists ? app.buttons["Done"] : app.buttons["Good Night"]).tap()
            }
        }

        // Final home screen
        tapTab(index: 0)
        sleep(1)
        captureScreen("home_end_of_day", description: "Home screen at day's end")
    }

    // MARK: - Helper Methods

    func tapTab(index: Int) {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let buttons = tabBar.buttons
            if buttons.count > index {
                buttons.element(boundBy: index).tap()
            }
        }
    }

    func tapBottomButton() {
        // Find and tap the primary action button at bottom of screen
        let buttons = ["Continue", "Next", "Done", "Get Started", "Let's Go"]
        for buttonText in buttons {
            if app.buttons[buttonText].exists {
                app.buttons[buttonText].tap()
                return
            }
        }

        // Fallback: tap the last button in the view
        let allButtons = app.buttons.allElementsBoundByIndex
        if let lastButton = allButtons.last, lastButton.isHittable {
            lastButton.tap()
        }
    }

    func addTask(title: String, notes: String = "") throws {
        // Look for add task button
        let addButtons = ["Add Task", "Add", "+", "New Task"]
        for buttonText in addButtons {
            if app.buttons[buttonText].exists {
                app.buttons[buttonText].tap()
                break
            }
        }

        // If there's a floating action button
        if app.buttons.matching(identifier: "addTaskButton").firstMatch.exists {
            app.buttons.matching(identifier: "addTaskButton").firstMatch.tap()
        }

        sleep(0.5)

        // Fill in task details
        let titleField = app.textFields["Task title"].exists ? app.textFields["Task title"] : app.textFields.firstMatch
        if titleField.exists {
            titleField.tap()
            titleField.typeText(title)
        }

        // Add notes if field exists
        if !notes.isEmpty {
            let notesField = app.textViews["Notes"].exists ? app.textViews["Notes"] : app.textViews.firstMatch
            if notesField.exists {
                notesField.tap()
                notesField.typeText(notes)
            }
        }

        // Save the task
        if app.buttons["Save"].exists {
            app.buttons["Save"].tap()
        } else if app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        } else if app.navigationBars.buttons["Done"].exists {
            app.navigationBars.buttons["Done"].tap()
        }

        sleep(0.5)
    }

    // MARK: - Individual Screen Tests

    func testCaptureAllMainScreens() throws {
        app.launch()
        sleep(2)

        // Skip onboarding if present
        if app.buttons["Quick Start with Defaults"].waitForExistence(timeout: 3) {
            app.buttons["Quick Start with Defaults"].tap()
            sleep(1)

            // Tap through remaining onboarding
            for _ in 0..<5 {
                tapBottomButton()
                sleep(0.5)
            }
            sleep(2)
        }

        // Capture all main tabs
        let tabNames = ["Home", "Recording", "Tasks", "Goals", "Settings"]

        for (index, name) in tabNames.enumerated() {
            tapTab(index: index)
            sleep(1)
            captureScreen("tab_\(index)_\(name.lowercased())", description: "\(name) tab")
        }

        print("✅ Captured \(screenshotCounter) main screens")
    }

    // MARK: - Custom Check-in Test

    func testCustomCheckInFlow() throws {
        app.launch()
        sleep(2)

        // Navigate to Settings
        tapTab(index: 4)
        sleep(1)
        captureScreen("settings_for_custom_checkin", description: "Settings before adding custom check-in")

        // Look for Custom Check-ins section
        if app.cells["Custom Check-ins"].exists {
            app.cells["Custom Check-ins"].tap()
            sleep(1)
            captureScreen("custom_checkins_list", description: "Custom check-ins management")

            // Add new custom check-in
            if app.buttons["Add Custom Check-in"].exists {
                app.buttons["Add Custom Check-in"].tap()
                sleep(1)
                captureScreen("add_custom_checkin", description: "Add custom check-in form")
            }
        }
    }
}
