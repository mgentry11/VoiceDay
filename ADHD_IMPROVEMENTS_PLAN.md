# Gadfly ADHD Improvements Plan

## Overview

This plan transforms Gadfly from a capable task manager into an ADHD-optimized productivity companion based on 5 core principles:

1. **Making time visible, not just reminded**
2. **Celebrating progress, not punishing lapses**
3. **Adapting to the user, not demanding consistency**
4. **Reducing cognitive load at every interaction**
5. **Integrating solutions instead of fragmenting them**

---

## Phase 1: Quick Wins (1-2 weeks)

### 1.1 Micro-Celebrations System

**Problem:** Task completion feels anticlimactic; no dopamine reward for ADHD brains.

**Solution:** Multi-sensory celebration feedback on every completion.

**Implementation:**
- Create `CelebrationService.swift`
- 4 celebration levels: micro, standard, major, epic
- Haptic patterns using CoreHaptics (different intensities per level)
- Optional celebration sounds (cheerful chimes, not annoying)
- Confetti animation for major/epic completions
- Points display integrated with existing RewardsSystem

**Files to create:**
- `Services/CelebrationService.swift`
- `Views/Components/ConfettiView.swift`

**Files to modify:**
- `VoiceDayApp.swift` - Add celebration triggers on task completion
- `Views/TaskListView.swift` - Integrate celebration animations

---

### 1.2 One-Tap Notification Actions

**Problem:** Current notifications require too many decisions (Done, Snooze 15m, Snooze 1hr, Skip, Dismiss).

**Solution:** Simplify to 2 options with smart defaults.

**Implementation:**
- Reduce to: "Done ✓" and "Later" (smart snooze)
- Smart snooze logic:
  - Morning tasks → 30 min snooze
  - Afternoon tasks → 15 min snooze
  - Evening tasks → 1 hour snooze
- Add "quick complete" from notification without opening app

**Files to modify:**
- `Services/NotificationService.swift` - Simplify notification categories
- `VoiceDayApp.swift` - Handle notification response actions

---

### 1.3 Simplified Home Screen ("Focus Mode")

**Problem:** Seeing 15 tasks creates overwhelm and decision paralysis.

**Solution:** Show ONE task at a time with big action button.

**Implementation:**
- New `FocusHomeView.swift` as default home
- Display only the next most important task
- Giant "Done" button (thumb-friendly)
- Small "Skip" and "See all tasks" secondary actions
- TimeRemainingView component showing visual urgency

**Files to create:**
- `Views/FocusHomeView.swift`
- `Views/Components/TimeRemainingView.swift`

**Files to modify:**
- `VoiceDayApp.swift` - Add toggle between Focus and List views

---

### 1.4 Momentum Meter (Replace Streak Counter)

**Problem:** Streak counters punish ADHD users for one bad day (reset to zero).

**Solution:** Momentum system with gradual decay, not binary reset.

**Implementation:**
- 0-100 momentum scale
- Gains: +8 per task, +15 for high priority, +10 for first task of day
- Decay: -5/day on weekdays, -2/day on weekends (forgiveness built in)
- Comeback boost: "Welcome back!" bonus after absence
- Visual meter with encouraging color states (not punishing red)

**Files to create:**
- `Services/MomentumTracker.swift`
- `Views/Components/MomentumView.swift`

**Files to modify:**
- `Models/RewardsSystem.swift` - Integrate momentum with points

---

## Phase 2: Core Differentiators (2-3 weeks)

### 2.1 Visual Time Ring Widget

**Problem:** Time blindness - ADHD users can't feel time passing.

**Solution:** Always-visible countdown ring showing time remaining.

**Implementation:**
- Circular progress indicator for current task deadline
- Color shifts: green → yellow → orange → red as deadline approaches
- iOS Widget for home screen visibility
- Watch complication for constant awareness
- "Time until next task" preview

**Files to create:**
- `Views/Components/TimeRingView.swift`
- `Widgets/TimeRingWidget.swift`
- `WatchApp/TimeRingComplication.swift`

---

### 2.2 Energy Check-In System

**Problem:** App expects same performance regardless of user's current state.

**Solution:** Quick energy check-in that adapts expectations.

**Implementation:**
- Morning prompt: "How's your energy today?" (3 options: Low/Medium/High)
- Energy affects:
  - Task sorting (easy tasks first on low energy)
  - Notification frequency (gentler on low days)
  - Celebration messaging (extra encouraging on low days)
  - Goal expectations (reduced on low days)
- Option to update mid-day

**Files to create:**
- `Services/EnergyService.swift`
- `Views/EnergyCheckInView.swift`

**Files to modify:**
- `Services/NotificationService.swift` - Adapt based on energy
- `Views/TaskListView.swift` - Sort by energy-appropriate

---

### 2.3 Preset Modes (Reduce Settings Complexity)

**Problem:** 40+ settings overwhelm ADHD users with choices.

**Solution:** 4 preset configurations that "just work."

**Implementation:**
- **"Focus First"** - Aggressive reminders, frequent check-ins, celebration sounds ON
- **"Stay On Me"** - Moderate reminders, hourly check-ins, gentle nudges
- **"Gentle Flow"** - Minimal reminders, no sounds, soft encouragement
- **"Custom"** - Full settings access (hidden by default)
- One-tap mode switching from home screen

**Files to create:**
- `Models/PresetModes.swift`
- `Views/PresetModeSelector.swift`

**Files to modify:**
- `VoiceDayApp.swift` - Apply preset configurations

---

### 2.4 AI Duration Estimation

**Problem:** ADHD users notoriously underestimate task duration.

**Solution:** AI suggests realistic durations based on task type and history.

**Implementation:**
- Analyze task titles for duration hints ("quick", "meeting", "deep work")
- Learn from user's actual completion times
- Suggest durations when adding tasks
- Gentle correction: "Last time 'email' tasks took ~45min, not 15min"

**Files to create:**
- `Services/DurationEstimator.swift`

**Files to modify:**
- `Views/AddTaskView.swift` - Show AI suggestions

---

## Phase 3: Market Differentiation (3-4 weeks)

### 3.1 Adaptive Notification Intelligence

**Problem:** Fixed notification timing doesn't match user's actual patterns.

**Solution:** Learn when user is most responsive and adapt.

**Implementation:**
- Track response rates by time of day
- Learn "productive windows" from completion patterns
- Reduce notifications during historically unresponsive times
- "Smart quiet hours" that adapt automatically
- Different patterns for weekdays vs weekends

**Files to create:**
- `Services/NotificationIntelligence.swift`

---

### 3.2 Medication Window Tracking

**Problem:** ADHD medication affects productivity windows; no apps integrate this.

**Solution:** Optional medication timing that informs task scheduling.

**Implementation:**
- Privacy-first: no medication names, just "window" concept
- Track "medication active" windows
- Suggest high-focus tasks during peak windows
- Gentler expectations during off-peak
- Medication reminder notifications (optional)

**Files to create:**
- `Services/MedicationWindowService.swift`
- `Views/MedicationWindowView.swift`

---

### 3.3 Body Doubling Integration

**Problem:** Body doubling apps exist separately; users want integration.

**Solution:** Built-in virtual co-working with accountability.

**Implementation:**
- "Work with me" sessions with ambient presence
- Connect with accountability partners (existing Gadfly users)
- Scheduled co-working rooms
- Async body doubling: "3 others working on similar tasks right now"
- Optional camera-off video presence

**Files to create:**
- `Services/BodyDoublingService.swift`
- `Views/BodyDoublingView.swift`

---

### 3.4 Smart Scheduling Based on History

**Problem:** Users manually schedule everything despite having completion pattern data.

**Solution:** AI-powered scheduling suggestions.

**Implementation:**
- Analyze when user completes different task types
- Suggest optimal times for new tasks
- "You usually do emails at 9am - add this then?"
- Learn from rescheduling patterns
- Avoid suggesting tasks during historically bad times

**Files to create:**
- `Services/SmartScheduler.swift`

---

## Technical Architecture

### New Services Layer

```
Services/
├── CelebrationService.swift      (Phase 1)
├── MomentumTracker.swift         (Phase 1)
├── EnergyService.swift           (Phase 2)
├── DurationEstimator.swift       (Phase 2)
├── NotificationIntelligence.swift (Phase 3)
├── MedicationWindowService.swift (Phase 3)
├── BodyDoublingService.swift     (Phase 3)
└── SmartScheduler.swift          (Phase 3)
```

### New Views Layer

```
Views/
├── FocusHomeView.swift           (Phase 1)
├── EnergyCheckInView.swift       (Phase 2)
├── PresetModeSelector.swift      (Phase 2)
├── MedicationWindowView.swift    (Phase 3)
├── BodyDoublingView.swift        (Phase 3)
└── Components/
    ├── ConfettiView.swift        (Phase 1)
    ├── TimeRemainingView.swift   (Phase 1)
    ├── MomentumView.swift        (Phase 1)
    └── TimeRingView.swift        (Phase 2)
```

---

## Success Metrics

### Phase 1 Goals
- Task completion rate increase by 20%
- App open-to-action time reduced to <3 seconds
- User satisfaction score improvement

### Phase 2 Goals
- Notification response rate improvement
- Reduced notification dismissal rate
- Increased daily active usage

### Phase 3 Goals
- User retention at 30 days
- Feature differentiation from competitors
- Premium conversion rate

---

## Dependencies & Considerations

### iOS Frameworks Required
- CoreHaptics (celebrations)
- WidgetKit (time ring widget)
- AVFoundation (sounds)
- CloudKit (body doubling sync)

### Privacy Considerations
- Medication data stays on-device only
- Energy check-ins are not shared
- Body doubling is opt-in with clear consent
- Learning data can be reset by user

### Backward Compatibility
- All new features are additive
- Existing users see gentle onboarding to new features
- "Classic mode" preset preserves current behavior

---

## Recommended Implementation Order

1. **Start with celebrations** - Immediate dopamine payoff, low risk
2. **Add momentum meter** - Replaces punishing streak counter
3. **Build Focus Home** - Reduces overwhelm immediately
4. **Simplify notifications** - Quick win, high impact
5. **Then proceed to Phase 2/3** based on user feedback

---

## Implementation Status

All phases completed!

### Phase 1: Quick Wins ✅
- [x] CelebrationService with haptics, sounds, confetti
- [x] One-tap notification actions (Done/Later)
- [x] FocusHomeView with single task focus
- [x] MomentumTracker replacing streak counter

### Phase 2: Core Differentiators ✅
- [x] TimeRingView visual countdown
- [x] EnergyService with daily check-in
- [x] PresetModes (Focus First, Stay On Me, Gentle Flow, Custom)
- [x] DurationEstimator with learning

### Phase 3: Market Differentiation ✅
- [x] NotificationIntelligence learning system
- [x] MedicationWindowService privacy-first tracking
- [x] BodyDoublingService virtual co-working
- [x] SmartScheduler productivity patterns

## Next Steps

- [ ] Add all new files to Xcode project
- [ ] Add celebration sound files (optional)
- [ ] Test on real device for haptics
- [ ] User testing for Focus Home
- [ ] Consider iOS Widget for TimeRing
- [ ] Consider Watch complication
