# Reforged

A gamified iOS Bible reading, study, and Scripture memory app built with SwiftUI.

Reforged helps believers build a daily habit of engaging with God's Word through structured reading, interactive learning tracks, and spaced-repetition memory practice — all wrapped in a rewarding progression system.

## Features

### Bible Reader
- **5 Translations** — ESV, KJV, CSB, NKJV, and NASB
- **Audio Playback** — Listen to ESV Scripture with configurable speed (0.75x–2x) and skip intervals
- **Search** — Full-text search across all supported translations
- **Highlights & Notes** — Color-coded verse highlighting and personal annotations
- **Word Study** — Tap any word for Strong's lexicon definitions (Hebrew/Greek)
- **Verse Sharing** — Generate shareable image cards with Unsplash backgrounds
- **Customizable Display** — Font type (serif, sans-serif, dyslexia-friendly), font size, line spacing, verse-by-verse or paragraph layout

### Scripture Memory
- **6 Practice Modes** — Flashcard, Tap to Reveal, Drag & Drop, Fill in the Blank, First Letter, and Typing
- **Spaced Repetition** — SM-2 algorithm schedules reviews at optimal intervals
- **5 Mastery Levels** — Learning → Familiar → Known → Well-known → Mastered
- **Review Tracking** — Accuracy scores, mode-specific stats, and next review dates

### Learning Tracks
- Structured doctrine and devotional study tracks with lessons organized by topic
- Lesson content includes Scripture passages, explanations, quizzes (multiple choice & fill-in-the-blank), and reflection prompts
- XP rewards for each completed lesson

### Gamification
- **XP & Leveling** — Earn XP from lessons, memory reviews, and daily reading
- **Reading Streaks** — Track consecutive days with milestone celebrations at 7, 14, 30, 60, 90, 180, and 365 days
- **Streak Freezes** — Protect your streak when you miss a day (4 free monthly, buy more with XP)
- **Badges** — Achievement badges for various milestones
- **Daily Insights** — Auto-generated Scripture suggestions refreshed each day

### Profile & Sync
- **Custom Profile Photos** — Upload from photo library or take with camera
- **Emoji Avatars** — 12 curated avatar options
- **Sign in with Apple** — Secure authentication
- **iCloud Sync** — Profile, progress, memory verses, highlights, and notes sync across devices via CloudKit

### Home Screen Widget
- At-a-glance reading streak and daily status on your home screen

## Screenshots

*Coming soon*

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Min Target | iOS 16.0 |
| Architecture | MVVM with singleton services |
| State | `@MainActor` ObservableObjects |
| Auth | Sign in with Apple |
| Cloud | CloudKit (private database) |
| Caching | UserDefaults with 30-day staleness |
| Bible APIs | ESV API, Bible API (KJV), API.Bible (CSB/NKJV/NASB) |
| Images | Unsplash API |
| Lexicon | Bundled Strong's Concordance data |
| Widget | WidgetKit |

## Project Structure

```
Reforged/
├── Models/              # Data models (UserProfile, MemoryVerse, Track, Lesson, etc.)
├── Services/            # Singleton services
│   ├── AppState          # Central state manager
│   ├── ESVService        # ESV Bible API
│   ├── KJVService        # KJV Bible API
│   ├── ApiBibleService   # API.Bible (CSB, NKJV, NASB)
│   ├── CloudKitSyncService
│   ├── AppleSignInService
│   ├── ReadingStreakManager
│   ├── StrongsLexiconService
│   ├── UnsplashService
│   └── ...
├── Views/
│   ├── Home/            # Dashboard with stats, insight, quick actions
│   ├── Bible/           # Scripture reader, search, audio, word study
│   ├── Memory/          # Spaced-repetition practice modes
│   ├── Tracks/          # Learning path curriculum
│   ├── Profile/         # User profile, streak sharing
│   ├── Settings/        # 8 settings sections
│   ├── Onboarding/      # First-run experience
│   └── Components/      # Reusable UI (ProfileAvatarView, FlowLayout)
├── Data/                # Doctrine & devotional track content
├── Theme.swift          # Colors, spacing, adaptive theming
└── ContentView.swift    # Tab navigation & root view
```

## Building

```bash
xcodebuild \
  -project Reforged.xcodeproj \
  -scheme Reforged \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Design

**Brand Colors**
- Navy `#333333` — Primary text and UI
- Gold `#D4A574` — Accent highlights and progress
- Coral `#E94560` — Notifications and streaks
- Cream `#E8E4DC` — Light mode background
- Full light/dark mode support with adaptive color system

## License

All rights reserved. This project is proprietary software.

## Copyright Notices

Reforged includes Scripture content from multiple Bible translations used under license. Individual translation copyrights are displayed within the app's About section. Verse sharing background images are provided by [Unsplash](https://unsplash.com) under the Unsplash License.
