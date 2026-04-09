# Gadfly — Requirements

## Target User

Adults, teens, and children with ADHD or executive function challenges who struggle with task initiation, time blindness, task switching, and follow-through. The app is designed to replace the need for a human external accountability partner.

---

## Functional Requirements

### Voice Capture
- Continuous speech recognition using Apple Speech framework
- Single voice input must be parseable into multiple output types simultaneously (tasks + events + reminders in one utterance)
- Voice output must use ElevenLabs API exclusively — no system TTS fallback
- Audio must route to speaker unless Bluetooth/wired headphones are detected

### AI Parsing (OpenAI)
- Parse free-form voice input into: tasks, calendar events, reminders, notes, goals, vault operations, break commands, reschedule operations
- Support multi-turn clarifying dialogue (conversation history maintained per session)
- Personality-aware prompting (tone adapts to selected bot personality)
- Support goal creation, editing, and completion via voice

### Task Management
- Create, edit, complete, and delete tasks by voice or touch
- Task aging: flag tasks that have been open too long
- Task breakdown: split tasks into subtasks via Task Coach dialogue
- Duration estimation per task
- Smart scheduling: assign tasks to time slots based on energy and priority
- Timesheet: log time spent per task

### Apple Watch
- Full WatchConnectivity sync with iPhone
- Voice capture on Watch
- Task list visible and interactable from Watch
- Speech output on Watch

### Coaching & Executive Function
- Task Coach asks 8 question types: what done looks like, what's blocking, real priority, what's needed first, time estimate, break it down, why important, best time
- Coaching sessions triggered manually or automatically on task selection
- Hyperfocus mode: single-task lock-in with distraction minimization

### Accountability & Motivation
- Body doubling: virtual co-working session mode
- Accountability contacts: designated person receives status updates
- Nagging system: escalating reminders at configurable intensity levels
- Rewards system: points for task completion, redeemable rewards
- Momentum tracking: streaks, daily/weekly stats
- Celebration: confetti and audio on milestone completions

### Check-ins & Health
- Morning intention setting
- Morning checklist
- Energy check-in (morning, midday, evening)
- Evening review
- Self-check / mood tracking
- Medication window: tracks dosing schedule with alerts
- Self-care tracking

### Goals
- Create and track long-term goals
- Goals linked to daily tasks
- Goal detail view with progress tracking
- Goal completion celebration

### Calendar & Scheduling
- EventKit integration: read and write calendar events
- Calendar list view
- Smart Scheduler: AI-suggested task/event placement
- Reschedule tasks by voice

### Notifications
- Intelligent notification scheduling (avoid notification fatigue)
- Nagging notifications at escalating intervals
- Medication window alerts
- Morning and evening check-in prompts

### Settings & Personalization
- App version selection: Kids / Teens / Adults
- 40+ color themes
- Bot personality selection (multiple personas)
- Voice selection (ElevenLabs voices + voice cloning)
- Custom dictionary for speech recognition correction
- Preset modes (context profiles)
- Backup and restore

### Security
- API keys stored in Keychain (never in UserDefaults or source)
- Secure Vault: encrypted notes storage via Keychain
- No plaintext credential storage

---

## Non-Functional Requirements

| Requirement | Specification |
|---|---|
| Platform | iOS 17+, watchOS 10+ |
| Language | Swift 5.9+, SwiftUI |
| Speech latency | Voice recognition must start within 1s of tap |
| AI response time | OpenAI parse result target < 3s on LTE |
| TTS latency | ElevenLabs audio must begin within 2s of response |
| Offline mode | Task creation and viewing must work without network; AI features require connectivity |
| Privacy | No voice audio stored or transmitted beyond Apple Speech and OpenAI APIs |
| Accessibility | VoiceOver compatible; primary flow fully usable without vision |

---

## External API Dependencies

| Service | Purpose | Required |
|---|---|---|
| OpenAI GPT | Voice input parsing, task coaching responses | Yes |
| ElevenLabs | Text-to-speech voice output | Yes |
| Apple Speech | On-device + cloud speech recognition | Yes (system) |
| EventKit | Calendar read/write | Yes (permission) |
| DoorDash | In-app meal ordering | Optional |

---

## Permissions Required

- Microphone — voice capture
- Speech Recognition — transcription
- Notifications — reminders and nagging
- Calendar — event read/write
- Location — location-based reminders
- Health (optional) — energy/mood correlation

---

## Out of Scope

- Android version
- Web interface
- Multi-user / shared task lists
- Backend server (app is fully client-side except API calls)
