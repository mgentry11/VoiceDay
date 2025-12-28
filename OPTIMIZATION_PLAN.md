# VoiceDay ADHD Companion App - Optimization Plan

## Vision
A smooth, effortless day companion that walks ADHD users through their day with voice guidance, customizable structure, and appropriate nagging - while allowing sharing with parents/teams for accountability.

---

## Core Principles

1. **Voice-First, Visual-Big** - Everything spoken aloud with large, clear visuals
2. **Customizable Everything** - User controls their experience
3. **Smooth & Effortless** - Complex features feel simple
4. **Non-Offensive Guidance** - Helpful, not annoying
5. **Accountable but Flexible** - Can share with others, but can pause when needed

---

## Phase 1: Onboarding Redesign

### 1.1 New Onboarding Flow

```
Step 1: Voice Selection
├── Show voice options with preview
├── Big "Play" buttons to hear each voice
└── "This will be your companion's voice"

Step 2: Personality Selection
├── Show 5 main personalities (hide extras)
├── Personality speaks intro greeting
├── "This is how I'll talk to you"
└── Option: "Show more personalities"

Step 3: Your Daily Structure
├── "Let's set up your day"
├── Morning Routine (toggle ON/OFF, customize items)
├── Midday Check-in (toggle ON/OFF, set time)
├── Evening Wind-down (toggle ON/OFF)
├── Bedtime Checklist (toggle ON/OFF, customize items)
└── Each section expandable to customize

Step 4: How Much Help?
├── Nagging Level: Gentle / Moderate / Persistent
├── Self-Care Reminders: ON/OFF
├── Break Reminders: ON/OFF
├── "You can change these anytime in Settings"

Step 5: Sharing (Optional)
├── "Want someone to help keep you accountable?"
├── Add Parent/Partner/Team
├── Set what they can see/do
└── Skip option available

Step 6: Let's Start!
├── Voice walkthrough of first check-in
├── Big visual demonstration
└── "Tap anywhere when ready to begin"
```

### 1.2 Customizable Check-ins

Each check-in should be:
- **Toggleable** - ON/OFF for the whole check-in
- **Time-settable** - When to trigger
- **Item-customizable** - Add/remove/reorder items
- **Voice-announced** - Speaks each item aloud
- **Saveable** - Persists across restarts

**Morning Check-in Items (Defaults):**
- Check calendar
- Review tasks
- Take medication
- Eat breakfast
- Set daily intention

**Bedtime Check-in Items (Defaults):**
- Keys location
- Wallet location
- Phone charging
- Alarm set
- Door locked
- Stove off

---

## Phase 2: Day Walkthrough Experience

### 2.1 The Day Flow

```
Morning (Triggered by app open or time)
├── Greeting: "[Name], good morning! Ready to start your day?"
├── Energy Check: "How's your energy? [Low/Medium/High]"
├── Morning Checklist: One item at a time, spoken aloud
├── Calendar Preview: "Here's what's on your calendar today"
├── Task Preview: "You have X tasks. Here's the most important one."
└── Daily Intention: "What's your one big thing today?"

Midday (Triggered by time)
├── "Hey! Quick midday check-in"
├── Progress Review: "You've completed X tasks!"
├── Energy Recheck: "How's your energy now?"
├── Gentle Redirect: "Still working on [task]? Need help?"
└── Self-Care Nudge: "Have you had water/food/break?"

Evening (Triggered by time)
├── "Winding down time!"
├── Day Review: "You completed X of Y tasks today"
├── Mood Check: "How are you feeling?"
├── Tomorrow Prep: "Anything to prepare for tomorrow?"
└── Bedtime Checklist: Walk through items

Throughout Day (As needed)
├── Task Completion Celebrations
├── Break Reminders (if enabled)
├── Gentle Nudges for overdue tasks
└── Self-Care Reminders (water, food, movement)
```

### 2.2 Visual Design Principles

- **One thing at a time** - Never show overwhelming lists
- **Big text** - 24pt minimum for key info
- **High contrast** - Easy to read at a glance
- **Progress indicators** - Visual feedback on completion
- **Celebration animations** - Confetti, haptics, sounds

### 2.3 Voice Design Principles

- **Natural pacing** - Pauses between items
- **Confirm understanding** - "Got it?" after instructions
- **Personality-consistent** - Voice matches chosen personality
- **Interruptible** - User can tap to skip/stop
- **Repeatable** - "Say that again" option

---

## Phase 3: Nagging & Self-Care System

### 3.1 Nagging Levels

**Level 1: Gentle**
- Single reminder per task
- No repeat until next day
- Soft encouragement tone
- "When you're ready, [task] is waiting"

**Level 2: Moderate** (Default)
- Reminder + 1 follow-up (30 min later)
- Daily task summary
- Supportive persistence
- "Hey! [Task] is still on your list. You've got this!"

**Level 3: Persistent**
- Multiple reminders (configurable intervals)
- Escalating urgency for deadlines
- Accountability partner notifications
- "This is important! [Task] is overdue. Let's tackle it!"

### 3.2 Self-Care Nagging

**Configurable Reminders:**
- Water intake (every X hours)
- Food/meals (breakfast, lunch, dinner times)
- Movement breaks (every X minutes of focus)
- Medication (specific times)
- Sleep reminder (bedtime warning)

**User Controls:**
- Toggle each type ON/OFF
- Set frequency/times
- Snooze options (15min, 1hr, rest of day)
- "I'm hyperfocusing - pause all" mode

### 3.3 Hyperfocus Protection

When user enters hyperfocus mode:
- All notifications paused
- Visual timer shows duration
- Gentle break suggestions at 1hr, 2hr marks
- Can set auto-exit time
- "Emerge" button when ready

---

## Phase 4: Sharing & Accountability

### 4.1 Sharing Roles

**Parent/Guardian Mode:**
- See child's task list
- See completion status
- Receive daily summary
- Can add tasks
- Can send encouragement messages
- Cannot modify child's settings

**Partner/Buddy Mode:**
- Mutual visibility (both see each other)
- Shared celebrations
- Can send nudges
- Body doubling availability status

**Team/Manager Mode:**
- See team members' goals
- Track goal progress
- Cannot see personal tasks (privacy)
- Team celebrations
- Assign team goals

### 4.2 What Can Be Shared

| Data | Parent | Partner | Team |
|------|--------|---------|------|
| Task List | ✓ | ✓ | ✗ |
| Task Status | ✓ | ✓ | ✗ |
| Goals | ✓ | ✓ | ✓ |
| Goal Progress | ✓ | ✓ | ✓ |
| Calendar | Optional | Optional | ✗ |
| Mood | ✗ | Optional | ✗ |
| Streaks | ✓ | ✓ | ✓ |

### 4.3 Accountability Features

**For the User:**
- "Someone's watching" indicator (optional)
- Shared celebration when completing tasks
- Partner can send voice messages of encouragement
- Option to request a nudge

**For the Watcher:**
- Daily digest email/notification
- Alert for overdue critical tasks
- Celebration notifications
- "Send encouragement" quick action

---

## Phase 5: Customizable Rewards

### 5.1 Reward Types

**Built-in Rewards:**
- Confetti animation
- Sound effects (variety pack)
- Haptic patterns
- Voice celebrations
- Points/XP system
- Badges/achievements

**Customizable Rewards:**
- Choose celebration style per task type
- Set point values for different tasks
- Create custom rewards ("After 5 tasks, I get coffee")
- Connect to real rewards (future: integrations)

### 5.2 Reward Frequency

**User Controls:**
- Celebrate every task
- Celebrate milestone tasks only (every 3rd, 5th)
- Celebrate difficult tasks more
- Daily summary celebration
- Weekly achievements

### 5.3 Reward Intensity

- **Subtle** - Small haptic + quiet sound
- **Standard** - Confetti + medium sound + voice
- **Big** - Full celebration + long confetti + loud voice

---

## Phase 6: Prioritization & Decision Support

### 6.1 Task Prioritization Help

**"Help me decide" Feature:**
- User taps "I don't know what to do"
- App asks 3 quick questions:
  1. "What's due soonest?"
  2. "What's most important?"
  3. "What can you do in 5 minutes?"
- Suggests top task based on answers

**Auto-Prioritization:**
- Deadline-based sorting
- Energy-matched suggestions ("Low energy? Try this easy one")
- Time-of-day optimization ("Morning = hard tasks")

### 6.2 Task Breakdown Support

**"This feels too big" Feature:**
- User flags task as overwhelming
- App asks "What's the tiniest first step?"
- Or suggests automatic breakdown
- Creates sub-tasks from big task

### 6.3 "Pick for me" Mode

- Random task selection
- Wheel spin animation (fun!)
- "Trust the app" for decision-paralyzed moments

---

## Implementation Order

### Sprint 1: Foundation (This Week)
1. [ ] Redesign onboarding flow with customizable check-ins
2. [ ] Add nagging level selector to settings
3. [ ] Save check-in customizations
4. [ ] Voice walkthrough for first-time use

### Sprint 2: Day Flow (Next Week)
5. [ ] Unified morning flow with energy check
6. [ ] Unified evening flow (merge evening + bedtime)
7. [ ] Midday check-in with progress review
8. [ ] Self-care reminder system

### Sprint 3: Sharing (Week 3)
9. [ ] Parent/partner invite system
10. [ ] Shared view of tasks/goals
11. [ ] Daily digest notifications
12. [ ] Encouragement messaging

### Sprint 4: Polish (Week 4)
13. [ ] Customizable rewards
14. [ ] "Help me decide" feature
15. [ ] "Pick for me" random selector
16. [ ] Hyperfocus protection mode

---

## Technical Considerations

### New Services Needed
- `NaggingLevelService` - Manages nagging preferences
- `SharingService` - Handles user connections
- `RewardCustomizationService` - Custom reward settings
- `DayFlowService` - Orchestrates daily check-ins

### Data to Persist
- Check-in configurations (items, times, enabled)
- Nagging level preferences
- Sharing connections
- Reward preferences
- Daily state (which check-ins completed)

### Backend Requirements (Future)
- User accounts for sharing
- Push notifications for accountability
- Sync across devices
- Team/family groups

---

## Success Metrics

1. **Onboarding completion rate** - Target: 90%+
2. **Daily check-in completion** - Target: 70%+
3. **Task completion rate** - Target: 60%+ of created tasks
4. **User retention** - Target: 50% still using after 30 days
5. **Sharing adoption** - Target: 30% connect with someone

---

## Summary

Transform VoiceDay from a feature-rich but complex app into a **smooth, personalized day companion** that:

1. **Guides** users through their day with voice + visuals
2. **Adapts** to their preferences (nagging level, rewards, structure)
3. **Connects** them with accountability partners
4. **Respects** their autonomy (pause, customize, control)
5. **Celebrates** their wins appropriately

All while feeling **effortless** despite the underlying complexity.
