# VoiceDay User Flow Map

## Overview
This document maps how users move through the VoiceDay ADHD companion app.

---

## 1. App Launch Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         APP LAUNCHES                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Has ElevenLabs API Key?│
                    └───────────────────────┘
                         │            │
                        YES          NO
                         │            │
                         ▼            ▼
            ┌────────────────┐  ┌─────────────────┐
            │Completed Setup?│  │ Go to Settings  │
            └────────────────┘  │(Tab 4) for API  │
                 │        │     └─────────────────┘
                YES      NO
                 │        │
                 ▼        ▼
         ┌──────────┐  ┌─────────────────────┐
         │Focus Home│  │   ONBOARDING FLOW   │
         │ (Tab 0)  │  │    (5 Steps)        │
         └──────────┘  └─────────────────────┘
```

---

## 2. Onboarding Flow (5 Steps)

```
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 1: VOICE SELECTION                       │
│  • Shows list of ElevenLabs voices                               │
│  • Tap to preview each voice                                     │
│  • Select and continue                                           │
│  • Voice: "Choose Your Voice"                                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                 STEP 2: PERSONALITY SELECTION                    │
│  • Shows 5 main personalities (+Show More option)                │
│  • Each personality speaks intro greeting when tapped            │
│  • Options: Cheerleader, Pemberton, Sage, Coach, Gentle          │
│  • Voice: "This is how I'll talk to you"                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  STEP 3: DAILY STRUCTURE                         │
│  • Toggle ON/OFF each check-in:                                  │
│    - Morning Check-in (customize items)                          │
│    - Midday Check-in (time picker)                               │
│    - Evening Wind-down (time picker)                             │
│    - Bedtime Checklist (customize items)                         │
│  • Tap to expand and customize each                              │
│  • Voice: "Let's set up your daily structure"                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   STEP 4: NAGGING LEVEL                          │
│  • Choose: Gentle / Moderate / Persistent                        │
│  • Toggle self-care reminders:                                   │
│    - Water reminders                                             │
│    - Food reminders                                              │
│    - Break reminders                                             │
│    - Sleep reminder                                              │
│  • Voice: "How much help do you want?"                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   STEP 5: START CHOICE                           │
│  • Simple Mode / Pro Mode toggle                                 │
│  • Choose where to start:                                        │
│    - Morning Check-in                                            │
│    - Mid-day Check-in                                            │
│    - Evening Check-in                                            │
│    - Bedtime Checklist                                           │
│    - Jump to Tasks                                               │
│    - Focus Mode                                                  │
│    - Voice Record                                                │
│    - Settings                                                    │
│  • Voice: "Where would you like to start?"                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   MAIN APP (Tabs)     │
                    └───────────────────────┘
```

---

## 3. Main App Structure (Tab View)

```
┌─────────────────────────────────────────────────────────────────┐
│                         TAB BAR                                  │
├──────────┬──────────┬──────────┬──────────┬──────────┤
│  Focus   │  Record  │  Tasks   │  Goals   │ Settings │
│  (0)     │  (1)     │  (2)     │  (3)     │  (4)     │
└──────────┴──────────┴──────────┴──────────┴──────────┘
```

### Tab 0: Focus Home
```
┌─────────────────────────────────────────────────────────────────┐
│                       FOCUS HOME VIEW                            │
├─────────────────────────────────────────────────────────────────┤
│  • Shows ONE task at a time (reduces overwhelm)                  │
│  • Preset Mode Selector (top):                                   │
│    - Focus First (deep work)                                     │
│    - Stay On Me (persistent reminders)                           │
│    - Gentle Flow (low pressure)                                  │
│                                                                  │
│  • Current Task Display (center):                                │
│    - Task title (large text)                                     │
│    - Time ring showing deadline                                  │
│    - Priority indicator                                          │
│                                                                  │
│  • Action Buttons:                                               │
│    - DONE (complete task)                                        │
│    - How? (get help starting)                                    │
│    - Think (clarify task)                                        │
│    - Split (break into subtasks)                                 │
│    - Push (reschedule)                                           │
│    - Skip (next task)                                            │
│                                                                  │
│  • Triggers check-ins based on time of day                       │
└─────────────────────────────────────────────────────────────────┘
```

### Tab 1: Record
```
┌─────────────────────────────────────────────────────────────────┐
│                      RECORDING VIEW                              │
├─────────────────────────────────────────────────────────────────┤
│  • Big microphone button (center)                                │
│  • Tap to speak task/reminder/event                              │
│  • AI parses natural language                                    │
│  • Creates task/reminder/event automatically                     │
│  • Shows confirmation of what was captured                       │
└─────────────────────────────────────────────────────────────────┘
```

### Tab 2: Tasks
```
┌─────────────────────────────────────────────────────────────────┐
│                      TASKS LIST VIEW                             │
├─────────────────────────────────────────────────────────────────┤
│  • Full task list (scrollable)                                   │
│  • Filter options: All / Today / Overdue / Upcoming              │
│  • Sort by: Priority / Due Date / Created                        │
│  • Swipe actions: Complete / Push / Delete                       │
│  • Tap to edit task details                                      │
│  • Add button for new tasks                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Tab 3: Goals
```
┌─────────────────────────────────────────────────────────────────┐
│                        GOALS VIEW                                │
├─────────────────────────────────────────────────────────────────┤
│  • Long-term goals list                                          │
│  • Progress tracking for each goal                               │
│  • Milestones and sub-goals                                      │
│  • Visual progress indicators                                    │
│  • Celebration for completed milestones                          │
└─────────────────────────────────────────────────────────────────┘
```

### Tab 4: Settings
```
┌─────────────────────────────────────────────────────────────────┐
│                      SETTINGS VIEW                               │
├─────────────────────────────────────────────────────────────────┤
│  Sections:                                                       │
│  • Simple/Pro Mode Toggle                                        │
│  • Appearance (themes)                                           │
│  • Profile                                                       │
│  • Personality Selection                                         │
│  • Voice Selection (Pro only)                                    │
│  • Morning Checklist Settings                                    │
│  • Location-based Checklists                                     │
│  • Celebration Settings (Pro only)                               │
│  • Self-Care Settings (Pro only)                                 │
│  • End-of-Day Check Settings                                     │
│  • Reward Breaks (Pro only)                                      │
│  • About & Legal                                                 │
│  • RESTART FROM BEGINNING (at bottom)                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Check-in Flows

### Morning Check-in Flow
```
┌─────────────────────────────────────────────────────────────────┐
│ Trigger: App open in morning OR scheduled time OR manual start  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INTRO SCREEN                                  │
│  • Personality greeting                                          │
│  • "Ready to start your morning routine?"                        │
│  • Begin / Skip buttons                                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│               STEP-BY-STEP ITEMS (One at a time)                 │
│  • Voice speaks each item                                        │
│  • Large visual display                                          │
│  • Done / Skip buttons                                           │
│                                                                  │
│  Default items:                                                  │
│  1. Check my calendar → Opens calendar review                    │
│  2. Review my tasks → Opens tasks review                         │
│  3. Take medication                                              │
│  4. Eat breakfast                                                │
│  5. Set daily intention                                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CALENDAR REVIEW                               │
│  • Shows today's events                                          │
│  • Voice reads summary                                           │
│  • "Add to calendar?" voice recording                            │
│  • Continue to tasks                                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     TASKS REVIEW                                 │
│  • Shows task list for today                                     │
│  • Voice reads each task                                         │
│  • Done / Skip / Push for each                                   │
│  • "Add anything?" voice recording                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETION                                    │
│  • Celebration animation                                         │
│  • "You're all set! Have a great day!"                           │
│  • Returns to Focus Home                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Evening Check-in Flow
```
┌─────────────────────────────────────────────────────────────────┐
│        Trigger: Scheduled time OR manual start                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INTRO SCREEN                                  │
│  • "Winding down time!"                                          │
│  • Task completion summary                                       │
│  • Begin / Skip buttons                                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MOOD CHECK                                    │
│  • "How are you feeling?"                                        │
│  • 5 mood options: Great → Rough                                 │
│  • Big emoji buttons                                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                       (if low mood)
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FACTOR CHECK                                    │
│  • "What might be affecting you?"                                │
│  • Options: Scrolling, News, Sleep, Food, etc.                   │
│  • Multi-select                                                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  SUGGESTION                                      │
│  • Actionable tip based on factors                               │
│  • Gentle, supportive message                                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETION                                    │
│  • "Rest well! Tomorrow is a new day"                            │
│  • Option: Start bedtime checklist                               │
└─────────────────────────────────────────────────────────────────┘
```

### Bedtime Checklist Flow
```
┌─────────────────────────────────────────────────────────────────┐
│       Trigger: After evening OR scheduled time OR manual        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              CHECKLIST ITEMS (One at a time)                     │
│  • Voice asks each question                                      │
│  • Big YES / NO buttons                                          │
│  • Optional "Where is it?" for item location                     │
│                                                                  │
│  Default items:                                                  │
│  1. Do you know where your keys are?                             │
│  2. Is your wallet where you can find it?                        │
│  3. Is your phone charging?                                      │
│  4. Is your alarm set?                                           │
│  5. Is the door locked?                                          │
│  6. Is the stove off?                                            │
│  (+ custom items user added)                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETION                                    │
│  • "Perfect! Everything is accounted for!"                       │
│  • "You're all set for tomorrow!"                                │
│  • Celebration animation                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Helper Flows

### "How?" (Task Attack) Flow
```
When user taps "How?" on a task:
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TASK ATTACK VIEW                               │
│  • "Here's how to start:"                                        │
│  • Suggested tiny first step                                     │
│  • Alternative approaches                                        │
│  • "Just do 2 minutes" option                                    │
└─────────────────────────────────────────────────────────────────┘
```

### "Think" (Task Coach) Flow
```
When user taps "Think" on a task:
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TASK COACH VIEW                                │
│  • Clarifying questions:                                         │
│    - "What does DONE look like?"                                 │
│    - "What's the first step?"                                    │
│    - "Do you need anything first?"                               │
│  • User answers via voice or text                                │
│  • AI refines the task                                           │
└─────────────────────────────────────────────────────────────────┘
```

### "Split" (Task Breakdown) Flow
```
When user taps "Split" on a task:
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                 TASK BREAKDOWN VIEW                              │
│  • AI suggests subtasks                                          │
│  • User can edit/add/remove                                      │
│  • Creates separate tasks from breakdown                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Special Modes

### Hyperfocus Mode
```
┌─────────────────────────────────────────────────────────────────┐
│                   HYPERFOCUS VIEW                                │
│  • Timer counting up                                             │
│  • Color progresses through stages:                              │
│    - Stage 1 (0-30 min): Green                                   │
│    - Stage 2 (30-60 min): Blue                                   │
│    - Stage 3 (60-90 min): Purple                                 │
│    - Stage 4 (90-120 min): Orange                                │
│    - Stage 5 (120+ min): Red (break suggested)                   │
│  • All notifications paused                                      │
│  • "Emerge" button when ready                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Simple Mode vs Pro Mode
```
SIMPLE MODE:
• Voice-guided step-by-step flows
• Auto-proceeds after actions
• Minimal settings visible
• Focus on core features only
• Intro screens skipped

PRO MODE:
• Full settings access
• Manual control over all features
• Custom check-in times
• Celebration settings
• Message generation
• API key management
• Advanced integrations
```

---

## 7. Navigation & Escape Routes

### From ANY Screen:
```
• Tab bar always visible → Tap any tab to navigate
• Settings always accessible via Tab 4
• "Restart from Beginning" in Settings (bottom)
```

### Sheet/Modal Dismissal:
```
• Swipe down to dismiss most sheets
• X button on full-screen covers
• Back button (<) on navigation stacks
• "Skip" option on all check-ins
```

### Restart Options:
```
SOFT RESTART (not yet implemented):
• Remembers current position
• Resumes where user left off

FULL RESTART (implemented):
• Goes back to Voice Selection (onboarding)
• Preserves API keys
• Clears other settings
```

---

## 8. Notification Triggers

```
┌────────────────────────────────────────────────────────────────┐
│                    NOTIFICATION TYPES                           │
├────────────────────────────────────────────────────────────────┤
│  • Morning check-in reminder (scheduled time)                   │
│  • Midday check-in reminder (scheduled time)                    │
│  • Evening check-in reminder (scheduled time)                   │
│  • Bedtime checklist reminder (scheduled time)                  │
│  • Task due reminders (based on deadline)                       │
│  • Overdue task nags (based on nagging level)                   │
│  • Self-care reminders (water, food, breaks)                    │
│  • Sleep reminder (before bedtime)                              │
│  • Location-based checkout (when leaving saved location)        │
└────────────────────────────────────────────────────────────────┘
```

---

## 9. Data Persistence

### Saved in UserDefaults:
```
• Onboarding completion status
• Selected voice ID
• Selected personality
• Simple/Pro mode
• Daily structure settings (check-ins enabled, times, items)
• Nagging level preferences
• Self-care reminder settings
• Theme preferences
• Morning checklist items
• Bedtime checklist items
• Custom items added by user
```

### Saved in Keychain:
```
• ElevenLabs API key
• OpenAI API key
```

### Saved in iOS Calendars/Reminders:
```
• Calendar events
• Reminders/Tasks
```

---

## 10. Known Issues to Address

1. **No "soft restart"** - Cannot resume from where user left off
2. **No universal escape route** - Some screens may trap users
3. **Potential repeat content** - Check for duplicate announcements
4. **No "overwhelmed" panic button** - Missing emergency help
5. **Settings access not consistent** - Should be reachable from anywhere
