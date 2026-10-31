# Reforged — Web (React) Feature List

A complete, implementation-oriented catalog of every feature in the current iOS/SwiftUI app, translated to what the **online React web version** needs to build. Derived from the Swift source (`Reforged/`), not just the README — the app is substantially larger than the README describes.

Each feature is tagged:

- ✅ **Direct port** — maps cleanly to web.
- 🔄 **Needs replacement** — iOS-specific tech; a web equivalent exists but must be re-architected.
- ⚠️ **No web equivalent** — depends on native OS capabilities (Screen Time, WidgetKit); reimagine or defer.

Priority tags: **P0** (core MVP), **P1** (fast follow), **P2** (later).

---

## 0. Platform & Foundation

The iOS app is built on Apple-only services. The web version must swap these out up front — they touch every feature.

| iOS approach | Web replacement | Notes |
|---|---|---|
| CloudKit private DB (sync) | 🔄 **Supabase** (Postgres + Row Level Security) | Repo already has `supabase/` with a Gemini proxy edge function and migrations — extend it into the primary backend. |
| Sign in with Apple + `SupabaseAuthService` | ✅ Supabase Auth (Apple JS + email/OAuth) | Sign in with Apple works on the web via Apple's JS SDK. |
| `UserDefaults` + 30-day cache | 🔄 `localStorage` / IndexedDB | Cache Bible text, lexicon, insights. |
| WidgetKit home-screen widget | ⚠️ PWA + Web Push (or drop for MVP) | No true web widget; a PWA install + daily push is the closest analog. |
| Local notifications | 🔄 Web Push (requires PWA + service worker) | Daily reminders, personalized reminders, weekly check-ins. |
| Bundled offline data (Strong's, commentaries, KJV) | 🔄 Service Worker + IndexedDB caching | Serve JSON from CDN; cache for offline. |
| Haptics | 🔄 Vibration API (mobile) / drop | Cosmetic. |

**Cross-cutting foundation work (P0):**
- Responsive layout system — the iOS app already forks **sidebar (iPad/Mac / desktop)** vs **bottom tabs (iPhone / mobile)**. Mirror this: sidebar nav on desktop, bottom tab bar on mobile.
- Full **light/dark mode** with the adaptive color system (brand: Navy `#333333`, Gold `#D4A574`, Coral `#E94560`, Cream `#E8E4DC`).
- **Unlockable themes** (Midnight, Parchment, Forest, Royal Purple) layered on top of light/dark.
- Accessibility: font scaling, dyslexia-friendly font option, semantic color contrast.
- Offline-first PWA shell.

---

## 1. Bible Reader — **P0**

The centerpiece. Default landing section.

### Reading
- ✅ **Chapter reader** with verse-by-verse or paragraph layout toggle.
- ✅ **Multi-translation support** — 8 reading translations:
  - **KJV**, **ESV**, **NET**, **NLT**, **NKJV**, **CSB**, **NASB**, **RVR1960** (Spanish).
  - ⚠️ Licensing: ESV/CSB/NKJV/NASB/NLT/RVR1960 are licensed and API-gated (ESV API, API.Bible). Confirm each license permits web delivery before shipping. KJV is public domain (bundled `kjvpce.json`).
- ✅ **Original-language texts** (hidden behind a setting): **TR** (Textus Receptus Greek), **SBLGNT** (SBL Greek NT), **WLC** (Westminster Leningrad Codex Hebrew).
- ✅ **Chapter navigation** — book/chapter/verse picker (the iOS "navigation wheel" → dropdown/modal on web), with a quick-jump and an elevation-shadowed verse picker.
- ✅ Per-verse copyright/attribution display (required by translation licenses — see `SettingsModels.swift`).

### Audio — **P1** 🔄
- **Audio playback** for **ESV** and **KJV** only.
- Configurable **playback speed 0.75×–2×**, skip-forward/back intervals.
- "Now Playing" screen + mini-player.
- 🔄 Offline audio download (KJV public-domain audio) → cache via service worker; ESV streams from API.
- Web: HTML5 `<audio>` / Web Audio API. Background playback via Media Session API.
- 🔄 **TTS fallback** (`TTSVoiceService`) — Web Speech API for translations without recorded audio.

### Study tools
- ✅ **Word Study / Strong's lexicon** — tap any word → Hebrew/Greek Strong's definition sheet (bundled concordance data).
- ✅ **Concordance search** — find every occurrence of a Strong's number / original form / lexical form / KJV usage.
- ✅ **Original-language view** — interlinear-style Strong's tagging (`OriginalLanguageService`).
- 🔄 **Commentaries** (bundled, public domain — `Barnes.json`, `CalvinCommentaries.json`, `MHC` = Matthew Henry, `TDavid` = Treasury of David). Show verse-linked commentary in a side panel/sheet. Large payloads (5–13 MB each) → lazy-load per book from CDN.
- ✅ **Cross-references** per verse.

### Search — **P0/P1**
- ✅ **Full-text search** with scopes: single version, **all versions**, **Strong's number**, **original form**, **lexical form**, **KJV usage** (`BibleSearchHistoryScope`).
- ✅ **Search history** (synced).
- 🔄 **AI Smart Search** (`GeminiService.smartBibleSearch`) — natural-language → verse results.
- 🔄 **Antioch semantic search** (`AntiochSearchService`, external API `bible-search.antioch.tech`) — "find verses about…" semantic lookup.

### Annotation & personalization
- ✅ **Highlights** — 6 colors (yellow, green, blue, pink, orange, purple), synced.
- ✅ **Notes** — per-verse personal notes (`TakeNoteView`), synced.
- ✅ **Verse Collections** — user-curated named sets of verses with translation + timestamps (`VerseCollection`).
- ✅ **Verse Sharing** — generate a shareable **image card** with an Unsplash background. Web: render to `<canvas>` → download / **Web Share API**.

### Reader settings (Display) — **P0**
- ✅ Font type: **serif, sans-serif, dyslexia-friendly**.
- ✅ Font size, line spacing.
- ✅ Verse-by-verse vs paragraph layout.
- ✅ Red-letter (words of Christ) — data present in `WordsOfChristData.swift`.

### Reading Plans — **P1**
- ✅ Structured plans: **Foundation**, **Character**, **Discipleship**, **Bible in a Year**, **New Testament in a Year**.
- ✅ Daily reading assignment, completion tracking, current-day tracking (`ReadingPlanService`, `BibleReadingPlan`).

### Bible Progress — **P1**
- ✅ **Chapters-read tracking** across the whole canon with a visual progress view (`BibleProgressView`) — by book/testament/category (Law, History, Poetry, Prophets, Gospels, Letters, Prophecy).
- ✅ Marks chapters read → feeds streaks, XP, and stats.

### Offline — **P2** 🔄
- Bible downloads for offline reading (`BibleDownloadManager`, `BibleDownloadsSection`) → service-worker precache + IndexedDB.

---

## 2. Scripture Memory — **P0**

Spaced-repetition Scripture memorization.

### Practice modes (9 total)
- ✅ **Flashcard** — flip to reveal.
- ✅ **Tap to Reveal** — reveal phrase by phrase.
- ✅ **Drag & Drop** — drag words into blanks.
- ✅ **Fill in the Blank** — type missing words.
- ✅ **First Letter** — first letters as hints.
- ✅ **Typing** — type the whole verse (tracks best WPM).
- ✅ **Matching Game** (`MatchingGameView`).
- ✅ **Complete the Verse** (`CompleteTheVerseView`).
- ✅ **Deep Drill** (`DeepDrillView`) — intensive multi-mode drill.

### Engine
- ✅ **SM-2 spaced repetition** (ease factor, interval, review count, quality 0–5) — port the algorithm directly from `MemoryVerse.updateReview`.
- ✅ **5 mastery levels** by interval: Learning → Familiar → Known → Well-Known → Mastered.
- ✅ **Review scheduling** — "due for review" queue surfaced on Home and in Memory.
- ✅ **Per-mode stats** — attempts, accuracy, confidence, best WPM.
- ✅ **Mark as Mastered** shortcut.

### Organization & extras
- ✅ **Add verses to memorize** (from reader, collections, or suggested list — `SuggestedVerses`).
- ✅ **Memory Collections** — group verses (`CollectionBuilderView`, `CollectionDetailView`).
- ✅ **Reflection notes** per verse (`ReflectionNoteSheet`).
- 🔄 **Memory audio player** (`MemoryAudioPlayer`) — hear the verse while memorizing.
- ✅ Memory settings section (review load, defaults).

> Note: the app also exposes memory verses via an MCP integration (`add_memory_verse`, `get_my_memory_verses`) — the web version should share the same Supabase-backed store so verses stay in sync across app, web, and integrations.

---

## 3. Discipleship — **P1**

Hub for structured growth, resources, and (native-only) focus tools.

### Learning Tracks / Learning Path — **P1** ✅
- **Doctrine tracks**: God (The Trinity), God the Father, God the Son, God the Holy Spirit, Salvation, Humanity & Sin, Satan, Creation, The Bible, Christian Community, Faithful Living, Foundations of Faith.
- **Devotional tracks** (catalog exposed via `list_devotional_tracks` MCP too).
- **Lesson content types**: Scripture passage, Explanation, **Quiz** (multiple-choice + fill-in-the-blank with explanations), **Reflection** prompt.
- **XP rewards** per completed lesson; completion tracking; per-track progress bars.
- Learning-path map UI (`LearningPathView`).

### Podcasts ("Walk Talks") — **P2** 🔄
- ✅ Podcast **feed** parsing, episode list, series grouping, descriptions, durations.
- 🔄 Audio player for episodes (HTML5 audio + Media Session).

### Share the Gospel — **P1** ✅
- A shareable gospel-presentation card/tool (`ShareGospelCard`).

### Focus / Accountability tools — ⚠️ **No direct web equivalent**
These use iOS **Screen Time / FamilyControls / DeviceActivity** APIs and the `ReforgedShield` + `ReforgedActivityMonitor` app extensions. The browser cannot block other apps.
- ⚠️ **Focus Shield** — block distracting apps (`FocusBlockingService`).
- ⚠️ **Social-media daily limit** with lock screen (`SocialLimitService`).
- ⚠️ **NSFW blocking**.
- ⚠️ **Accountability Lock** — PIN-protected settings (`AccountabilityLockService`).
- ⚠️ **Refocus verse** — show a Scripture prompt when a limit is hit.

**Web strategy:** Drop from MVP. Optionally reimagine later as (a) a **focus timer / "reading mode"** inside the web app, (b) a **browser extension** for site blocking, or (c) marketing that points to the native app for this. Do **not** promise app-blocking on web.

---

## 4. Home / Dashboard — **P0** ✅

Personalized daily hub. All ✅ direct ports.

- **Welcome header** — greeting, avatar, streak + XP badges.
- **Stats cards** — streak, XP, level, chapters read, verses memorized.
- **Daily Insight card** — auto-generated Scripture suggestion, refreshed daily (`KnowledgeBase` + optional AI reflection via Gemini).
- **Today's Reading card** — active reading-plan assignment.
- **Continue Learning** — resume current track/lesson.
- **Review Due** — memory verses due today.
- **Quick Actions** — jump into reader / memory / plan.
- **Bible Progress card** — canon completion at a glance.
- **Share the Gospel card**.
- **Celebrations/overlays**: XP-gain toast, **Level-Up** animation, **Streak Milestone** celebration, **Badge Earned** celebration.
- **Buy Me a Coffee** support button.
- Two-column layout on desktop, single column on mobile.

---

## 5. Gamification — **P0/P1** ✅

Threaded through the whole app.

- ✅ **XP system** with sources: lessons, memory reviews, chapters read, reflections written. `addXP` + `XPActivity` log.
- ✅ **30 levels** with fixed XP thresholds (port the `currentLevel` table from `UserProfile`).
- ✅ **Reading streaks** — consecutive active days, longest streak.
- ✅ **Streak milestones** — celebrations at **7, 14, 30, 60, 90, 180, 365** days.
- ✅ **Streak Freezes** — protect a missed day; **4 free/month** (auto-replenish), buy more with XP; "unprotected streak" nudge.
- ✅ **Badges** — many, across categories: reading (First Steps, Bookworm, Avid Reader, Century Reader, Bible Scholar), memory (Word in Heart, Memory Builder, Scripture Keeper, Living Library, Perfect Recall), streaks (Week Warrior, Fortnight Focus, Monthly Devotion, Century Streak, Year of Faith), XP/level (Rising Star, Shining Light, Radiant Glory), learning (Student, Dedicated Learner, Track Master), journaling (Reflector, Thoughtful Writer), and Mode Master.
- ✅ **Perks / Shop** — unlockable via level/streak/badge/XP conditions:
  - **Profile borders**: Gold, Flame, Royal (crown), Diamond.
  - **Themes**: Midnight, Parchment, Forest, Royal Purple.
  - **XP multiplier**, avatar unlocks.
- ✅ **Weekly activity tracking** — lessons, verses reviewed, chapters read, reflections, XP earned per day (`WeeklyActivity`).

---

## 6. Profile — **P0** ✅

- ✅ **Profile photo** — upload from library or **camera** (web: `<input type=file>` + `getUserMedia`); stored in Supabase Storage.
- ✅ **Emoji avatars** — 12 curated (Lion, Dove, Lamb, Eagle, Fish, Star, Flame, Cross, Heart, Book, Crown, Olive Branch).
- ✅ **Active profile border** + **active theme** (from perks).
- ✅ **Stats overview** — level, XP, streaks, badges grid.
- ✅ **Streak Share Card** — generate a shareable streak image (canvas + Web Share).
- ✅ **Goals** — chosen during onboarding (learn the storyline, grow in doctrine, daily habit, memorize, big picture, walk with Christ).

### Journal — **P1** ✅
- ✅ **Rich-text journal** (`RichTextEditorView` → a web rich-text editor, e.g. TipTap/Lexical).
- ✅ **Tags**.
- ✅ **Linked entities** — link a journal entry to verse(s), a lesson, or a daily insight.
- 🔄 **AI journal prompts** (`GeminiService.generateJournalPrompts`) + static prompt library.
- ✅ Journal export (`ExportService`) → PDF/text download on web.

---

## 7. Settings — **P0/P1** ✅

Mirror the 9 iOS settings sections:
- ✅ **Display** — theme, font type/size, line spacing, layout.
- ✅ **Bible Reading** — default translation, red-letter, reading prefs.
- ✅ **Audio** — voice, speed, skip interval, TTS.
- 🔄 **Bible Downloads** — offline caching controls.
- ✅ **Memory** — review load, default practice mode.
- 🔄 **Notifications** — daily reminder time, personalized reminders, weekly check-in (web push).
- 🔄 **AI Settings** — enable/disable AI features, API key/managed-service toggle (`AISettingsSection`, Gemini via Supabase proxy).
- ✅ **Account** — profile, sign-out, **delete account**.
- ✅ **About** — version, translation copyrights/attributions, licenses, What's New, support links.

---

## 8. AI Features (Gemini via Supabase proxy) — **P1** 🔄

All routed through a **managed Supabase edge function** (`supabase/functions/gemini-proxy`) so no API key ships client-side. Port the proxy; call it from React.
- **Word-study summaries** — plain-language explanation of a Greek/Hebrew word.
- **Smart Bible search** — natural language → verses.
- **Journal prompts** — personalized reflection prompts.
- **Daily insight reflection** — devotional note on the daily verse.
- **Daily reading notifications** — personalized reminder copy.
- **Shield encouragements** — (native-only context; skip on web).
- **Verse reference parsing / resolution** — turn free text into structured references.

---

## 9. Onboarding — **P0** ✅
- ✅ Multi-step first-run flow (`OnboardingFlowView`): welcome → name → **goal selection** → avatar → sign-in → done.
- Sets initial profile, goals, and defaults.

## 10. Notifications & Engagement — **P1** 🔄
- 🔄 **Daily reading reminder** (configurable time).
- 🔄 **Personalized reading reminders** (AI-generated, once/day).
- 🔄 **Weekly check-in** (`WeeklyCheckinService`, Supabase-driven).
- ✅ **What's New** modal on version update.
- ✅ **Donation prompts** at usage milestones + **Buy Me a Coffee** link.
- ⚠️ App Store review prompt → replace with a web feedback/review nudge.

---

## Web-Specific Additions to Consider
- **PWA install** + offline shell (replaces widget/native feel).
- **Deep links / shareable URLs** — every verse, plan, track, and collection should be a real URL (huge web advantage the native app lacks; also SEO for Bible content).
- **SEO** for public Bible/commentary/track content (server-render or static-generate where licensing allows — KJV + public-domain commentaries are safe to index).
- **Keyboard shortcuts** for the reader (next/prev chapter, search).

---

## Suggested Build Phases

**Phase 0 — Foundation:** Supabase backend + auth, data models, responsive shell (sidebar/tabs), theming (light/dark + unlockable), PWA scaffold, sync.

**Phase 1 — MVP (P0):** Bible Reader (read, translations, chapter nav, highlights, notes, search, word study), Scripture Memory (all modes + SM-2), Home dashboard, Gamification (XP/levels/streaks/freezes/badges), Profile, core Settings, Onboarding.

**Phase 2 — P1:** Learning Tracks, Reading Plans, Bible Progress, Journal, Verse Collections, Commentaries, Audio playback, AI features, Notifications, Share cards, perks/shop.

**Phase 3 — P2:** Podcasts, offline Bible downloads, TTS, deep original-language tooling, and a *reimagined* (non-blocking) focus/reading-mode feature.

**Explicitly out of scope for web:** native Focus Shield / app-blocking / Screen Time limits / accountability PIN lock (⚠️ no browser equivalent), and the iOS home-screen widget (⚠️ approximate with PWA + push).

---

## Translation & Licensing Quick Reference

| Code | Name | Web-shippable? |
|---|---|---|
| KJV | King James (PCE bundled) | ✅ Public domain |
| ESV | English Standard | ⚠️ Licensed (ESV API) — **no CC/translation redistribution** |
| NET | New English Translation | ⚠️ Licensed, permissive quoting |
| NLT | New Living | ⚠️ Licensed (Tyndale) |
| NKJV | New King James | ⚠️ Licensed (Thomas Nelson) |
| CSB | Christian Standard | ⚠️ Licensed (Holman) |
| NASB | New American Standard | ⚠️ Licensed (Lockman) |
| RVR1960 | Reina-Valera (Spanish) | ⚠️ Licensed (UBS) |
| TR | Textus Receptus (Greek) | ✅ Public domain |
| SBLGNT | SBL Greek NT | ✅ CC BY 4.0 (attribution) |
| WLC | Westminster Leningrad (Hebrew) | ✅ Public domain |
| Commentaries | Barnes, Calvin, Matthew Henry, Treasury of David | ✅ Public domain |

> **Action item:** confirm each licensed translation's API terms explicitly permit browser/web delivery (not just native apps) before exposing it on the web. Attribution strings are already authored in `SettingsModels.swift` — reuse them verbatim.
