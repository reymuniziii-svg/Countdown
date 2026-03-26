# COUNTDOWN

A macOS menu bar app that plays a dramatic soundtrack with a full-screen countdown overlay before your meetings start.

Inspired by [@rtwlz](https://x.com/rtwlz/status/1903156553894416614) who made his computer play BBC News music before every meeting.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What It Does

- Sits in your menu bar showing a live countdown to your next meeting
- At T-minus [your clip length], a cinematic full-screen overlay appears with a pulsing countdown number
- Your chosen audio track fades in smoothly over 3 seconds
- Hit **Join** to open the video call, **Snooze** for 1 minute, or **Escape** to dismiss

## Features

- **Menu bar countdown** — live "Team Sync in 23m" ticking down
- **Up to 3 audio clips** — upload MP3/WAV/M4A/AIFF, select which one plays
- **Smart timing** — countdown duration matches your clip length (up to 30 seconds). Clips longer than 30s play just the last 30 seconds (preserves the climax)
- **Fade-in audio** — starts silent, fades to full volume over 3 seconds
- **Full-screen overlay** — dark translucent background, huge pulsing countdown number, meeting title, join button
- **Multi-monitor** — overlay appears on all connected screens
- **Calendar integration** — reads from all calendars via EventKit (Apple Calendar, Google Calendar, Outlook — any account added in System Settings)
- **Video link detection** — auto-detects Zoom, Google Meet, Microsoft Teams, Webex, and Slack Huddle links
- **On/off toggle** — quick enable/disable from the menu bar dropdown
- **Launch at login** — optional, via Settings

## Install

### From Source (Swift Package Manager)

Requires **Xcode 15+** and **macOS 13 Ventura** or later.

```bash
git clone https://github.com/yourusername/Countdown.git
cd Countdown
swift build -c release
```

The built binary will be at `.build/release/Countdown`. Move it to `/Applications` or run directly.

### From Source (Xcode)

```bash
git clone https://github.com/yourusername/Countdown.git
cd Countdown
open Package.swift
```

This opens the project in Xcode. Hit **Cmd+R** to build and run.

## Quick Start

1. **Launch Countdown** — a calendar icon appears in your menu bar
2. **Grant calendar access** — click the menu bar icon and approve the permission prompt
3. **Add a soundtrack** — click the menu bar icon → click "Add soundtrack" → pick an audio file
4. **Wait for a meeting** — the countdown triggers automatically at T-minus [clip length] before any meeting with a video link

## How It Works

```
Menu Bar: "Team Sync in 23m" ← ticking live
                  │
                  ▼ (at T-minus clip length)
┌─────────────────────────────────────────┐
│                                         │
│                 18                      │ ← pulsing countdown
│                                         │
│            Team Sync                    │
│             12:00 PM                    │
│                                         │
│     [ Join Zoom ]  [ Snooze ]  [ × ]    │
└─────────────────────────────────────────┘
         + audio fading in from silence
```

## Menu Bar Dropdown

```
┌─────────────────────────────┐
│ COUNTDOWN           [ON/OFF]│
├─────────────────────────────┤
│ Next: Team Sync      in 23m │
│ 1:1 with Alex        2:00p │
├─────────────────────────────┤
│ 🔊 Soundtrack               │
│  ● BBC News Theme    [20s]  │
│  ○ Epic Horns        [15s]  │
│  + Add another              │
├─────────────────────────────┤
│ Preferences...              │
│ Quit Countdown              │
└─────────────────────────────┘
```

## Settings

Access via **Preferences...** in the dropdown:

| Tab | What |
|-----|------|
| **General** | Launch at login |
| **Audio** | Manage 3 audio slots — preview, delete, replace |
| **Calendars** | Enable/disable specific calendars |

## Audio Behavior

| Clip Length | What Happens |
|-------------|--------------|
| ≤ 30 seconds | Plays full clip. Countdown = clip length |
| > 30 seconds | Seeks to last 30 seconds. Countdown = 30s |

Audio always fades in from silence over the first 3 seconds.

## Calendar Integration

Countdown uses **EventKit** (Apple's native calendar framework). It reads events from any calendar account you've added in **System Settings → Internet Accounts**:

- Apple Calendar (iCloud)
- Google Calendar
- Microsoft Outlook / Exchange
- Yahoo
- Any CalDAV provider

No OAuth setup needed — if it shows up in Apple Calendar, Countdown can see it.

## Project Structure

```
Countdown/
├── CountdownApp.swift          # App entry, MenuBarExtra, overlay coordinator
├── Models/
│   ├── MeetingEvent.swift      # EKEvent wrapper
│   └── AudioTrack.swift        # Audio clip model
├── Services/
│   ├── CalendarService.swift   # EventKit integration
│   ├── MeetingMonitor.swift    # Meeting trigger logic
│   ├── AudioManager.swift      # AVAudioPlayer, fade-in, clip storage
│   └── VideoLinkDetector.swift # Meeting link regex
└── Views/
    ├── MenuBarView.swift       # Dropdown UI
    ├── OverlayWindow.swift     # Multi-monitor NSPanel
    ├── OverlayView.swift       # Full-screen countdown
    └── SettingsView.swift      # Preferences window
```

## Credits

- Inspired by [@rtwlz](https://x.com/rtwlz) and the BBC News theme energy
- Calendar/overlay patterns adapted from [nilBora/meeting-reminder](https://github.com/nilBora/meeting-reminder) (MIT)

## License

MIT — see [LICENSE](LICENSE)
