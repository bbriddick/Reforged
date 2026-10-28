# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

<!-- Native SwiftUI, iOS 16.0 minimum.
Universal app: iPhone-primary with iPad as a fully supported, first-class experience
(NavigationSplitView sidebar, multi-column Home dashboard, study-tools rail in the reader).
No Mac Catalyst build is enabled. Not `adaptive`: there is no Android/other design
language; iPad is iOS design scaled up. -->

## Users

Christians of any tradition who want to make Scripture a daily habit but struggle
with consistency. The core person *wants* to read and remember the Bible, yet it
slips when life gets busy. Reforged speaks to them as a thoughtful friend, not a
marketer or a teacher scolding from the front: someone who wants to grow
spiritually and needs a calm, rewarding reason to return each day.

Deliberately **non-denominational**: welcomes all Christians and takes no
denominational position. Classic public-domain study resources (Calvin, Matthew
Henry, Barnes commentaries; Tyndale materials; Spurgeon) are offered as historical
study tools, not as a confessional stance. The name "Reforged" signals personal
renewal, not a Reformed-tradition gate.

A secondary audience is camp and youth-ministry communities: the app carries the
Walk Talks podcast (in partnership with Southland Christian Camp) and a dedicated
Southland 2026 camp-verse memory track.

## Product Purpose

Reforged turns Bible reading, study, and Scripture memory into a lasting daily
habit. It exists because most Bible apps help you *read* a verse but not *retain*
it: verses fade by the next day. Success is a believer who opens the app daily,
keeps a streak alive, and moves verses into genuine long-term memory, carrying
God's Word with them through the day. "Read it. Memorize it. Live it."

It is intentionally a **calm, ad-free, privacy-respecting** space. Free to use and
reader-supported; it is not an ad or subscription funnel.

## Positioning

The differentiating mechanism is **retention, not just reading**: spaced-repetition
Scripture memory (SM-2) on a Duolingo-style journey path, with a per-verse difficulty
ladder, guided daily lessons, and spoken recitation, wrapped in a daily-habit layer
(XP, levels, streaks, streak freezes, badges, earned crowns, milestone celebrations).
Where competitors ship a verse-of-the-day, Reforged is a serious study *and* memory
tool (eight English/Spanish translations plus Greek and Hebrew texts, offline
Strong's word study, audio, a study library, guided tracks) that still feels calm and
unhurried. It also adds what reading apps lack: **memorizing and reading together
with friends** without any chat feed, and Screen Time-based protection for
purity and focus. A "verse-a-day" app cannot truthfully claim the memory system or the
study depth; a heavyweight study app cannot truthfully claim the ad-free, habit-first calm.

## Operating Context

- **Daily, personal, devotional use**, often in short sessions (five minutes counts).
  Frequently one-handed on iPhone; also lean-back study sessions on iPad.
- Rituals that pull the user back daily: reading streak, a guided Morning Routine,
  home-screen widgets, daily insight, due spaced-repetition reviews, "My Disciplines"
  checklist, and friend activity (shared streaks, read-together plans).
- Reading, highlighting, note-taking, word study, and memory practice are the
  recurring tasks. Study happens both in-passage (tap a word, open a commentary) and
  in dedicated practice sessions.
- Moments of temptation are a real use context: the "I'm Being Tempted" SOS flow is
  reachable from the Discipleship tab and a home-screen widget.
- Reader support happens in-app through an Apple IAP **tip jar** (StoreKit 2
  consumables); the old external Buy Me a Coffee link was removed to satisfy App Store
  rule 3.1.1. Physical merch is sold via a Printful store opened in Safari (physical
  goods are outside IAP).

## Capabilities and Constraints

**Navigation:** iPhone tab bar is Home, Discipleship, Bible, Memory, Friends. Profile is
reached from the Home avatar (no Profile tab). The iPad sidebar lists the same five plus
Profile and Settings.

**Core, shipping capabilities:**
- **Bible reader**
  - Translations: KJV (default, bundled offline), ESV, NET, NLT, NKJV, CSB, NASB,
    RVR1960 (Spanish). Original-language texts TR and SBLGNT (Greek NT) and WLC (Hebrew
    OT) are hidden until enabled in Manage Bibles. Manage Bibles also reorders and
    hides translations in the switcher and manages offline downloads.
  - TextKit 2 reader on a stable whole-Bible chapter spine; poetry layout and section
    titles; verse-by-verse or paragraph mode; customizable display (font family incl.
    dyslexia-friendly, size, spacing).
  - Audio: ESV narrated audio, KJV narrated audio (streamed or downloaded for offline),
    device text-to-speech for CSB, NKJV, NASB, RVR1960, and NLT; no audio for NET or the
    original-language texts. Speed/skip controls, Now Playing.
  - Full-text search, concordance, Word Locator, color highlights, personal notes,
    verse image-card sharing, tappable Scripture references.
  - Tap-any-word Strong's Hebrew/Greek word study served from a **bundled offline
    study database** (no network needed).
  - iPad/large screens: trailing study-tools rail with expandable panel.
  - "Continue" button shared by Home and the Bible navigator: next reading-plan entry,
    or last reading position.
- **Scripture memory**
  - Memory Journey: Duolingo-style skill-tree path over a bundled 15-unit, 150-verse
    KJV curriculum (works offline), review-first.
  - SM-2 spaced repetition; five mastery levels; six practice modes (flashcard, tap to
    reveal, drag & drop, fill in the blank, first letter, type it out) assigned by a
    per-verse difficulty ladder; due reviews run a swipe flashcard deck, then
    graduated exercises.
  - Guided daily lesson (listen, phrase by phrase, drag & drop, fill blank, say it back).
  - **Say It Back**: spoken recitation checked live with on-device speech recognition.
  - Deep drill, matching game, complete-the-verse, custom verse collections, memory audio.
  - Southland 2026 "Take Courage" camp-verse track with its own rewards.
  - Import from YouVersion: paste or share references/bible.com links to bring saved
    verses over and set a reading-plan position (YouVersion has no export).
- **Discipleship tab**
  - Guided tracks / learning path (lessons with passages, quizzes, reflection).
  - Reading plans, including Spurgeon Morning & Evening and build-your-own plans.
  - **My Disciplines**: self-built daily rule-of-life checklist (habits to keep,
    temptations to avoid, weekday schedules, real per-item reminders) plus
    social-media time-off windows.
  - **Notes**: Apple Notes-style library over journal entries and Bible notes
    (folders, categories, pin/move, rich editor with styles, checklists, highlight).
    Journal entries are encrypted on device.
  - Study Library: Bible atlas (MapKit), commentaries, dictionaries, topical resources
    (SWORD modules; several large commentaries download on demand), cross-reference map.
  - Walk Talks podcast; "Share the Gospel" (The Four P's).
- **Morning Routine**: once-a-day guided flow from Home (Scripture, prayer, AI-generated
  gratitude questions, memory review, completion); prayer and gratitude are saved to the
  encrypted journal.
- **Focus & Purity Shield** (Screen Time / FamilyControls, with Shield, ShieldAction,
  DeviceActivity monitor, and Report extensions)
  - Adult-content and app blocking, schedules, focus sessions, protected-day streak,
    insights.
  - Scripture unlock gate (social apps stay shielded until one discipline is done
    that day) and a social daily limit where time is earned through disciplines.
  - Accountability PIN set by a trusted partner (salted hash only) so protection
    cannot be lowered alone; tamper log and partner reports.
  - "I'm Being Tempted" SOS: slow down, name it, fight with Scripture (KJV), one concrete
    step, pray and tell someone; a separate confession-and-grace path if the user fell.
  - Shield-screen encouragements are pre-generated by Gemini and cached to the App Group.
- **Friends** (replaces Groups as the visible community surface)
  - Add friends by invite code, QR code, deep link, or opt-in contact discovery
    (hashed contacts); friend requests; mute/remove.
  - Memorize a verse together with a shared pair streak; send and take verse quizzes.
  - Read a plan or passage together and see when a friend has read today.
  - "Challenge a friend" verse links (`reforged://memorize`) that open straight to the verse.
  - Preset push nudges only; **no free-text chat**. Opt-in activity sharing with a
    consent version; age-gated features; full friend-data deletion.
- **Gamification**
  - XP and levels (Armor of God progression), reading streak with milestone
    celebrations and streak freezes, badges, daily insights; celebration overlays at
    the app root.
  - **Crowns**: an earned-only currency (never sold, no random draws, fixed prices with
    previews) spent in the Crown Shop on cosmetics: app themes, avatar frames, emblems,
    verse-card styles, widget styles, highlighter palettes, and reader extras
    (synthesized ambient sounds, illuminated capitals).
- **Home**: Today group with one hero next step, progress, daily insight, pull-down
  search across Scripture, notes, journal, lessons, topics, and in-app destinations, with
  an optional AI overview; Tips (short feature walkthroughs with streamed videos);
  Reforged Shop card.
- **Onboarding**: new users learn a real verse in about a minute (welcome, pick Bible,
  first verse, first review, first win, Walk Talks, reminder, deferred account), then a
  guided app tour that hovers over each tab and can be restarted from Settings.
  Returning users get a fast lane that recognizes them and restores their account.
- **Profile, accounts & sync**: Sign in with Apple or email/password (Supabase), with
  account creation deferred until after the first win. Private CloudKit sync of profile,
  progress, memory verses, highlights, notes, cosmetics, and synced preferences (display,
  reading choices, reminder choices, tour progress). A "Finish setting up this device"
  card handles per-device items after a restore (notifications, widgets, commentary
  downloads, focus protection). Custom/emoji avatars; streak share card.
- **Widgets**: Verse of the Day (small/medium, style chosen in Settings), Reading Streak
  (small/medium/large), and "I'm Being Tempted" panic widget.
- **AI (Gemini)**: daily insight reflections, smart Bible search and AI overview, word
  study summaries, journal prompts, gratitude prompts, atlas place insights, shield
  encouragements, daily reading notification copy. Users can supply their own API key;
  responses carry a "verify with Scripture" disclaimer.

**Built but not surfaced:**
- **Groups** community (prayer, shared lessons, read-side Learn tracks) is still in the
  codebase but its tab and sidebar row are commented out; it is reachable only through a
  `reforged://join?code=` deep link. Do not present it as a current feature.
- App Shortcuts / Live Activities exist only as a spec (`SPEC_AppShortcuts_LiveActivity.md`);
  no AppIntents or ActivityKit code ships.

**Constraints & terminology:**
- iOS 16.0 minimum; MVVM with singleton services (`static let shared`); `@MainActor`
  ObservableObjects.
- Bible text sources: ESV API; bible-api.com / bundled text (KJV); NET service;
  Tyndale's api.nlt.to (NLT); API.Bible (CSB, NKJV, RVR1960; NASB pending a YouVersion
  Platform path that is wired but not switched on). Some publisher-restricted
  translations carry their own API key.
- Licensing caps shape the product: ESV and NLT cannot be stored beyond 500 verses on
  device, so they are not bulk-downloaded; NKJV audio is not licensable; NASB full
  download is off pending license confirmation.
- Backend: Supabase (Lovable-managed) for accounts, Friends, the shop catalog edge
  function, the Apple token relay, and Tips video storage; CloudKit for private sync.
- App Store name of record: **"Reforged: Bible Study & Memory."**
- App Store rules govern money: tips are Apple IAP consumables
  (`com.reforged.app.tip.{small,medium,large}`); crowns are never purchasable; merch
  checkout is external because it is physical goods.

## Brand Commitments

- **Name:** Reforged (App Store: "Reforged: Bible Study & Memory").
- **Voice:** warm, sincere, and quietly confident. Encouraging, never preachy or
  guilt-driven. Reads like a thoughtful friend, not a marketer. Sentence case, minimal
  emoji. No em dashes in user-facing copy. No gambling language ("jackpot", coins);
  playful learning language (XP, level up, crowns) is fine. Taglines in use: "Read it.
  Memorize it. Live it." / "Build a daily habit with God's Word." / "The Bible app that
  helps it actually stick."
- **Brand colors** (from Theme.swift / README): Navy `#333333` (primary text/UI,
  actually charcoal; see note), Gold `#D4A574` (accent/progress), Coral `#E94560`
  (notifications/streaks), Cream `#E8E4DC` (light background). Full light/dark support
  via an adaptive color system.
  - *Known trap:* the tokens named "navy"/"dark blue" are charcoal greys; navy-named
    accents must use `adaptiveNavyText(scheme)` or they vanish on dark cards. Only
    gold/coral/purple are safe as literals in both modes.
- **Identity:** the "R" wordmark/logo (cream on charcoal launch screen).
- **Ethos as brand commitment:** free, ad-free, reader-supported, privacy-respecting,
  single-maker. These are promises to the user, not just business facts.

## Evidence on Hand

- Real, feature-complete shipping app at version 2.4 (build 21); about 223 first-party
  Swift files across the app, widget, and four Screen Time extension targets.
- Marketing/product docs in-repo: `README.md`, `DESIGN.md`, `ONBOARDING_PLAN.md`,
  `Reforged_Welcome_Email.md`, `Reforged_Growth_and_Business_Plan.docx`,
  `Reforged_Ad_Copy_and_Creative_Pack.docx`, `APP_STORE_CHECKLIST.md`,
  `LOVABLE_PROMPTS_*.md`; `Marketing/Tips/` (After Effects tip-video pipeline and
  `tips.json`); three App Store screenshot JPGs; `website-source.zip`.
- Bundled study data: offline study database (`reforged-study.rsdb`, Strong's lexicons
  and original-language data), KJV text, memory curriculum, doctrine/devotional tracks,
  SWORD commentaries and dictionaries, Bible-places atlas data, Spurgeon devotional.
- **Absences future work must not fabricate:** no public ratings, reviews, testimonials,
  user counts, or press yet. Do not invent social proof, customer quotes, download
  numbers, or benchmarks. Single founder ("the maker of Reforged"); do not invent a
  team, company, or funding. The Southland/Walk Talks relationship is a real content
  partnership; do not overstate it as an endorsement or sponsorship.

## Product Principles

1. **Retention over exposure.** The product's reason to exist is that Scripture *sticks*;
   every feature should serve reading, remembering, and living the Word, not vanity metrics.
2. **Calm, ad-free, and unhurried.** Depth without noise. Never trade the peaceful,
   focused feeling for engagement pressure, ads, or dark patterns.
3. **Habit by gentle pull, not guilt.** Streaks, reminders, and celebrations invite the
   user back; the voice encourages and never scolds. Every reminder toggle defaults off
   unless the user opts in per type. Self-paced plans never surface missed days as debt.
4. **Together without noise.** Social features are encouragement (shared streaks,
   read-together, preset nudges), never a chat feed or a follower count.
5. **For all Christians.** Welcome every tradition; offer classic study resources without
   taking a denominational side.
6. **Respect the user's trust.** Privacy-first (private CloudKit, encrypted journal,
   hashed contact discovery, hashed accountability PIN), honest about being
   reader-supported, earned-only rewards, and faithful to Apple's rules.

## Accessibility & Inclusion

- Dyslexia-friendly font option, adjustable font size and line spacing, and
  verse-by-verse vs. paragraph layouts are shipping reading-accessibility affordances.
- Audio for most translations (narrated or text-to-speech) and spoken recitation in
  Say It Back support listening- and speaking-first learners.
- Full light/dark mode via an adaptive color system; contrast must hold in both
  (see the navy/charcoal token trap above).
- Spanish reading is available (RVR1960); the app UI itself is English only.
- No formal external standard has been established as a binding requirement yet;
  treat legible contrast, Dynamic Type friendliness, and the dyslexia option as the
  current bar to preserve and extend.
