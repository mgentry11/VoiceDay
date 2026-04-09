# Gadfly

An ADHD-first voice-driven productivity assistant for iPhone and Apple Watch.

Gadfly acts as external executive function — it listens, parses, schedules, nags, coaches, and celebrates. The entire interaction model is voice-in / voice-out, removing the friction that kills follow-through for ADHD users.

---

## What It Does

**Speak your day.** Say "I need to call the dentist at 3, pick up the kids at 5, and remind me to take my medication at noon" — Gadfly parses it into tasks, calendar events, and reminders in a single voice capture.

**Gets coached through hard tasks.** The Task Coach asks clarifying questions ("What would done actually look like?" / "What's the tiniest first step?") to help users break through initiation paralysis.

**Nags, but nicely.** Configurable nagging levels remind users of overdue tasks. Accountability contacts can be looped in.

**Celebrates wins.** Momentum tracking, rewards system, and confetti animations reinforce completion.

**Runs on Apple Watch.** Core voice capture and task interaction available from the wrist.

---

## Key Features

| Feature | Description |
|---|---|
| Voice Capture | Continuous speech recognition via Apple Speech framework |
| AI Parsing | OpenAI parses voice input into tasks, events, reminders, notes, goals |
| ElevenLabs TTS | Cloned or preset voices read responses aloud (no robotic system voice) |
| Apple Watch App | WatchConnectivity sync, wrist-based voice capture |
| Task Coach | Socratic question engine — acts as external executive function |
| Hyperfocus Mode | Locks in on a single task, minimizes distractions |
| Body Doubling | Virtual co-working presence for focus accountability |
| Energy & Mood Check-ins | Morning, midday, evening state tracking |
| Medication Window | Tracks dosing windows and alerts |
| Smart Scheduler | AI-assisted task scheduling based on energy and priority |
| Goals System | Long-term goal tracking with DAG-style dependency awareness |
| Rewards System | Points and streaks for completed tasks |
| Nagging System | Escalating reminders with configurable intensity levels |
| Accountability Contacts | Loop in a person to receive status nudges |
| Preset Modes | Profiles for different contexts (work, school, home) |
| Secure Vault | Keychain-backed encrypted storage for sensitive notes |
| Timesheet | Tracks time spent on tasks |
| DoorDash Integration | Meal ordering from within the app |
| 40+ Color Themes | Full theming system with Kids / Teens / Adults app versions |

---

## Tech Stack

- **Platform**: iOS 17+ / watchOS 10+
- **Language**: Swift / SwiftUI
- **AI**: OpenAI GPT (voice parsing, coaching responses)
- **TTS**: ElevenLabs API (voice cloning + preset voices)
- **Speech Recognition**: Apple Speech framework (on-device + cloud)
- **Watch Sync**: WatchConnectivity framework
- **Storage**: UserDefaults + Keychain (SecureVaultService)
- **Notifications**: UserNotifications framework
- **Calendar**: EventKit

---

## Project Structure

```
Gadfly/
├── Models/          — Data models (GadflyTask, Goals, Rewards, PresetModes, ParsedItem)
├── Services/        — All business logic (40+ service classes)
├── Views/           — SwiftUI views and components
├── Utilities/       — Keychain, Theme, AsyncTimeout helpers
Gadfly Watch App/    — watchOS companion app
```

---

## Setup

1. Clone the repo and open `Gadfly.xcodeproj` in Xcode
2. Add your API keys in Settings within the app:
   - **OpenAI API Key** — required for voice parsing and task coaching
   - **ElevenLabs API Key** — required for voice output
3. Select a target device (iPhone or Simulator) and build
4. On first launch, grant permissions: Speech Recognition, Microphone, Notifications, Calendar, Location

---

## App Versions

Gadfly ships with three audience modes, selectable in Settings:

- **Kids** — simplified interface, fun tone
- **Teens** — school and social context, moderate features
- **Adults** — full feature set, professional tone
