# VoiceDay - ADHD Focus & Productivity App

## Overview

VoiceDay is an iOS app designed to help users (especially those with ADHD) stay focused and complete tasks. It uses voice input to capture tasks naturally, AI to parse and organize them, and persistent nagging to ensure things get done.

## Core Features

### 1. Voice-Powered Task Capture
- Speak naturally: "I need to pick up groceries, call mom tomorrow, and finish the report by Friday"
- Claude AI parses your stream of consciousness into structured tasks, events, and reminders
- No manual typing required (though keyboard input is available)

### 2. Dr. Pemberton-Finch - Your Sardonic Assistant
- A witty Oxford Mathematics PhD who serves as your personal productivity nag
- 100+ unique messages drawing from philosophy, literature, and mathematics
- Generate unlimited new messages using AI so he never repeats himself
- Speaks reminders aloud using ElevenLabs voice or system TTS

### 3. Persistent Nagging System
- **Tasks nag until done**: Once you create a task, VoiceDay will remind you at your chosen interval (5, 10, 15, or 30 minutes) until you mark it complete
- **Only "Done" stops the nagging**: Tapping, dismissing, or ignoring notifications just schedules another reminder
- **Focus Sessions**: Start a focus session and get regular check-ins to keep you on track

### 4. Family Nagging (Multi-User)
- Connect with family members or friends who also use VoiceDay
- Assign tasks to others: "Remind Junior to clean his room"
- They'll receive persistent nags until the task is done
- Works even if they don't have the app (via SMS)

## How It Works

### Task Flow
```
You speak → AI parses → Tasks created → Reminders scheduled → Nags until done
```

### Nagging Logic
1. When a notification fires, it automatically schedules the next one
2. When you tap a notification (not "Done"), another nag is scheduled
3. When you dismiss a notification, another nag is scheduled
4. Only tapping "Done" stops the nagging chain

### Focus Sessions
1. Tap the eye icon on the main screen
2. Choose your check-in interval (5-30 minutes)
3. Set a grace period before first reminder
4. Dr. Pemberton-Finch checks in regularly until you end the session

## Multi-User / Family Nagging

### Setup
1. Go to Settings → Your Profile
2. Enter your name and phone number
3. Tap "Register with VoiceDay Network"

### Adding Connections
1. Go to Settings → Family & Friends
2. Tap + to add a connection
3. Enter their nickname, phone number, and relationship
4. The app will check if they have VoiceDay installed

### Assigning Tasks
1. Go to Settings → Shared Tasks
2. Tap + to create a new shared task
3. Select who to assign it to
4. Set the nag interval and priority
5. They'll receive persistent reminders until they mark it done

### How It Works for Recipients
- **If they have VoiceDay**: They see the task in their app and get push notifications
- **If they don't have VoiceDay**: They receive SMS reminders

## Settings

### Personality
Choose from 6 assistant personalities:
- **Dr. Pemberton-Finch**: Sardonic Oxford don (default)
- **Sergeant Focus**: Drill instructor
- **Sunny**: Enthusiastic cheerleader
- **Alfred**: Formal butler
- **Coach Max**: Sports coach
- **Master Kai**: Zen master

### Reminder Settings
- **Nag Interval**: How often to remind you (5-30 minutes)
- **Event Reminder**: How early to remind you of appointments
- **Daily Check-ins**: Scheduled times for daily productivity reviews
- **Focus Check-ins**: How often to check in during focus sessions
- **Grace Period**: How long before first focus session reminder

### Message Variety
- View total available messages
- Generate 20 new AI-written messages (uses Claude API)
- Messages are stored and never repeat for 10+ reminders

## API Keys Required

### Claude AI (Required)
- Get from: console.anthropic.com
- Used for: Task parsing, message generation

### ElevenLabs (Optional)
- Get from: elevenlabs.io
- Used for: Premium AI voice responses
- Falls back to system voice if not configured

## Backend Architecture

### VoiceDay Network (bigoil-backend)
- Flask backend on Render
- Supabase (PostgreSQL) database
- Handles: User registration, connections, shared tasks, nag tracking

### Database Tables
- `voiceday_users`: Registered users with device IDs
- `voiceday_connections`: Family/friend relationships
- `voiceday_shared_tasks`: Tasks assigned between users
- `voiceday_nags`: History of nag messages sent

## Technical Notes

### iOS Requirements
- iOS 17.0+
- Microphone access (for voice input)
- Speech recognition access
- Notification permissions
- Calendar/Reminders access (optional)

### Notification Limits
- iOS allows max 64 pending notifications
- Focus sessions schedule 30 at a time and refill automatically
- Task nags chain indefinitely (each one schedules the next)

### Conversation History
- All nags are logged to the conversation with timestamps
- Shows: "[2:30 PM] Nag for 'Clean room': [message]"
- History is persisted between app launches

## Privacy

- Voice recordings are processed locally, then sent to Claude for parsing
- API keys stored in iOS Keychain (encrypted)
- User data stored in Supabase with Row Level Security
- Device ID (not personal info) used for identification

## Troubleshooting

### Notifications not working
1. Check Settings → Notifications → VoiceDay is enabled
2. Try the "Test Notification" button in app settings
3. Ensure app has notification permissions

### Voice not speaking
1. Check if ElevenLabs key is configured
2. Ensure device volume is up
3. Falls back to system voice if ElevenLabs fails

### Family nagging not working
1. Ensure you're registered in Settings
2. Check recipient's phone number is correct
3. Verify backend is running (bigoil-backend.onrender.com)
