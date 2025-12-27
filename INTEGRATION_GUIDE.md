# Gadfly ADHD Improvements - Integration Guide

This guide walks through integrating all the new ADHD-optimized features into the VoiceDay/Gadfly app.

---

## Step 1: Add New Files to Xcode Project

### Services (add to `VoiceDay/Services/`)
```
CelebrationService.swift
MomentumTracker.swift
EnergyService.swift
DurationEstimator.swift
NotificationIntelligence.swift
MedicationWindowService.swift
BodyDoublingService.swift
SmartScheduler.swift
```

### Views (add to `VoiceDay/Views/`)
```
FocusHomeView.swift
EnergyCheckInView.swift
PresetModeSelector.swift
MedicationWindowView.swift
BodyDoublingView.swift
SmartSchedulerView.swift
```

### Components (create `VoiceDay/Views/Components/` folder)
```
ConfettiView.swift
MomentumView.swift
TimeRingView.swift
```

### Models (add to `VoiceDay/Models/`)
```
PresetModes.swift
```

---

## Step 2: Update AppDelegate for App Lifecycle

Add these to `AppDelegate.swift` to track focus and body doubling:

```swift
// In applicationDidEnterBackground or sceneDidEnterBackground
func applicationDidEnterBackground(_ application: UIApplication) {
    Task { @MainActor in
        BodyDoublingService.shared.appDidEnterBackground()
    }
}

// In applicationDidBecomeActive or sceneDidBecomeActive
func applicationDidBecomeActive(_ application: UIApplication) {
    Task { @MainActor in
        BodyDoublingService.shared.appDidBecomeActive()
        MomentumTracker.shared.applyComebackBoost()
    }
}
```

---

## Step 3: Update VoiceDayApp.swift

Add environment objects and check for energy prompt:

```swift
@main
struct VoiceDayApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var energyService = EnergyService.shared
    @StateObject private var modeService = PresetModeService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Check for morning energy check-in
                    energyService.checkIfNeedsCheckIn()
                }
        }
    }
}
```

---

## Step 4: Wire Up Notification Response Handling

In your notification delegate (likely `AppDelegate.swift` or a dedicated class):

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let notificationId = response.notification.request.identifier

        Task { @MainActor in
            switch actionId {
            case "DONE_ACTION":
                // Record completion for intelligence
                NotificationIntelligence.shared.recordResponse(
                    notificationId: notificationId,
                    action: .completed
                )
                // Handle task completion...

            case "SMART_SNOOZE_ACTION":
                NotificationIntelligence.shared.recordResponse(
                    notificationId: notificationId,
                    action: .snoozed
                )
                // Reschedule with smart delay
                let delay = NotificationService.shared.smartSnoozeDuration()
                // Reschedule notification...

            case UNNotificationDismissActionIdentifier:
                NotificationIntelligence.shared.recordResponse(
                    notificationId: notificationId,
                    action: .dismissed
                )

            default:
                break
            }
        }

        completionHandler()
    }
}
```

---

## Step 5: Update Task Completion Flow

When a task is completed, update all services:

```swift
func completeTask(_ task: SomeTaskType) async {
    let taskTitle = task.title
    let priority = task.priority  // ItemPriority enum

    // 1. Update momentum
    MomentumTracker.shared.recordTaskCompletion(priority: priority)

    // 2. Trigger celebration
    let level = CelebrationService.shared.levelFor(priority: priority)
    let points = calculatePoints(for: priority)
    CelebrationService.shared.celebrate(
        level: level,
        taskTitle: taskTitle,
        priority: priority,
        points: points
    )

    // 3. Record for smart scheduling
    SmartScheduler.shared.recordCompletion(
        taskTitle: taskTitle,
        completedAt: Date(),
        durationMinutes: task.duration,
        deadline: task.deadline
    )

    // 4. Record for duration learning
    if let startTime = task.startTime {
        DurationEstimator.shared.recordCompletion(
            taskTitle: taskTitle,
            estimatedMinutes: task.estimatedMinutes ?? 15,
            startTime: startTime,
            endTime: Date()
        )
    }
}
```

---

## Step 6: Add Navigation to New Features

### Option A: Add to Tab Bar (ContentView.swift already updated)

The Focus tab is already the first tab. Add more tabs if desired:

```swift
// In ContentView
BodyDoublingView()
    .tabItem {
        Label("Co-work", systemImage: "person.2.fill")
    }
    .tag(5)
```

### Option B: Add to Settings Navigation

Add navigation links in SettingsView:

```swift
Section {
    NavigationLink {
        MedicationWindowView()
    } label: {
        Label("Focus Windows", systemImage: "clock.badge.checkmark")
    }

    NavigationLink {
        BodyDoublingView()
    } label: {
        Label("Body Doubling", systemImage: "person.2.fill")
    }

    NavigationLink {
        SmartSchedulerView()
    } label: {
        Label("Smart Scheduling", systemImage: "calendar.badge.clock")
    }
} header: {
    Text("ADHD Tools")
}
```

---

## Step 7: Add Celebration Sounds (Optional)

Add these sound files to your Xcode project (drag into project, check "Copy items if needed"):

- `completion_ding.mp3` - Light tap sound for standard completions
- `completion_chime.mp3` - Pleasant chime for major completions
- `completion_fanfare.mp3` - Celebratory sound for epic completions

Or let CelebrationService fall back to system sounds automatically.

---

## Step 8: Update Info.plist (if needed)

If you want medication window reminders to work in background:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## Step 9: Test Checklist

### Phase 1: Celebrations & Momentum
- [ ] Complete a low priority task → micro haptic only
- [ ] Complete a medium priority task → double-tap haptic
- [ ] Complete a high priority task → crescendo haptic + confetti
- [ ] Check momentum meter increases
- [ ] Close app for a day, reopen → momentum decayed slightly (not reset)
- [ ] Complete 3 tasks → "three in a row" bonus

### Phase 2: Energy & Modes
- [ ] First app launch of day → energy check-in appears
- [ ] Select "Low Energy" → verify gentler notifications
- [ ] Switch to "Focus First" mode → verify settings updated
- [ ] Tap time remaining → shows time ring view
- [ ] Add task → see AI duration estimate

### Phase 3: Intelligence
- [ ] Complete tasks at different hours → patterns recorded
- [ ] View Smart Scheduling → see productivity chart
- [ ] Start medication window → track phases
- [ ] Start body doubling session → see timer and check-ins
- [ ] End body doubling → rate focus

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     FocusHomeView                            │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ EnergyBadge │  │ PresetMode   │  │ MomentumMeter      │  │
│  └─────────────┘  └──────────────┘  └────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                Current Task Card                      │   │
│  │  ┌─────────────┐  ┌────────────────┐                 │   │
│  │  │ TimeRing    │  │ Duration Est.  │                 │   │
│  │  └─────────────┘  └────────────────┘                 │   │
│  │                                                       │   │
│  │              [ DONE ✓ ]                              │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               CelebrationOverlay                      │   │
│  │  (Confetti + Points Badge)                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Services                              │
│                                                              │
│  ┌───────────────┐  ┌────────────────┐  ┌───────────────┐  │
│  │ Celebration   │  │ Momentum       │  │ Energy        │  │
│  │ Service       │  │ Tracker        │  │ Service       │  │
│  └───────────────┘  └────────────────┘  └───────────────┘  │
│                                                              │
│  ┌───────────────┐  ┌────────────────┐  ┌───────────────┐  │
│  │ Duration      │  │ Notification   │  │ Smart         │  │
│  │ Estimator     │  │ Intelligence   │  │ Scheduler     │  │
│  └───────────────┘  └────────────────┘  └───────────────┘  │
│                                                              │
│  ┌───────────────┐  ┌────────────────┐  ┌───────────────┐  │
│  │ Medication    │  │ Body Doubling  │  │ Preset Mode   │  │
│  │ Window        │  │ Service        │  │ Service       │  │
│  └───────────────┘  └────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

```
User completes task
        │
        ▼
┌───────────────────┐
│ MomentumTracker   │──► +8 points, update level
└───────────────────┘
        │
        ▼
┌───────────────────┐
│ CelebrationService│──► Haptic + Sound + Confetti
└───────────────────┘
        │
        ▼
┌───────────────────┐
│ DurationEstimator │──► Learn actual duration
└───────────────────┘
        │
        ▼
┌───────────────────┐
│ SmartScheduler    │──► Record hour/category pattern
└───────────────────┘
        │
        ▼
┌───────────────────┐
│ NotificationIntel │──► Record response for learning
└───────────────────┘
```

---

## Troubleshooting

### Haptics not working
- Must test on real device (simulator doesn't support haptics)
- Check `CHHapticEngine.capabilitiesForHardware().supportsHaptics`

### Confetti not showing
- Ensure `CelebrationOverlay` is added as overlay in your view hierarchy
- Check `celebrationAnimationsEnabled` setting

### Energy check-in not appearing
- Check `EnergyService.shared.checkIfNeedsCheckIn()` is called on app launch
- Verify it's a new day since last check-in

### Smart scheduling not learning
- Need 10+ task completions before patterns emerge
- Check `SmartScheduler.shared.isLearning` status

---

## Future Enhancements

1. **iOS Widget** - Add TimeRingView to WidgetKit extension
2. **Watch App** - Sync momentum and celebrations to Apple Watch
3. **Siri Shortcuts** - "Start focus window" / "Start body doubling"
4. **Backend Integration** - Real async body doubling with other users
5. **Notification Intelligence** - ML model for better timing predictions
6. **Focus Mode Integration** - Tie into iOS Focus modes

---

## Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| CelebrationService.swift | ~280 | Haptics, sounds, confetti |
| MomentumTracker.swift | ~200 | Forgiving streak system |
| EnergyService.swift | ~230 | Daily energy tracking |
| DurationEstimator.swift | ~200 | AI task duration |
| NotificationIntelligence.swift | ~280 | Learn response patterns |
| MedicationWindowService.swift | ~300 | Focus window tracking |
| BodyDoublingService.swift | ~250 | Virtual co-working |
| SmartScheduler.swift | ~280 | Productivity patterns |
| FocusHomeView.swift | ~360 | Main simplified UI |
| TimeRingView.swift | ~250 | Visual countdown |
| ConfettiView.swift | ~180 | Celebration animation |
| MomentumView.swift | ~200 | Momentum display |
| EnergyCheckInView.swift | ~280 | Energy modal |
| PresetModeSelector.swift | ~350 | Mode switcher |
| PresetModes.swift | ~180 | Mode configurations |
| MedicationWindowView.swift | ~320 | Window UI |
| BodyDoublingView.swift | ~350 | Co-working UI |
| SmartSchedulerView.swift | ~280 | Insights UI |

**Total: ~4,750 lines of new code**
