# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

<!-- Native SwiftUI, iOS 16.0 minimum. Universal app: iPhone-primary with iPad as a
fully supported, first-class experience (split-view sidebar, study-tools rail).
Not `adaptive` — there is no Android/other design language; iPad is iOS design scaled up. -->

## Users

Christians of any tradition who want to make Scripture a daily habit but struggle
with consistency. The core person *wants* to read and remember the Bible, yet it
slips when life gets busy. Reforged speaks to them as a thoughtful friend, not a
marketer or a teacher scolding from the front — someone who wants to grow
spiritually and needs a calm, rewarding reason to return each day.

Deliberately **non-denominational**: welcomes all Christians and takes no
denominational position. Classic public-domain study resources (Calvin, Matthew
Henry, Barnes commentaries; Tyndale materials) are offered as historical study
tools, not as a confessional stance. The name "Reforged" signals personal renewal,
not a Reformed-tradition gate.

## Product Purpose

Reforged turns Bible reading, study, and Scripture memory into a lasting daily
habit. It exists because most Bible apps help you *read* a verse but not *retain*
it — verses fade by the next day. Success is a believer who opens the app daily,
keeps a streak alive, and moves verses into genuine long-term memory, carrying
God's Word with them through the day. "Read it. Memorize it. Live it."

It is intentionally a **calm, ad-free, privacy-respecting** space. Free to use and
reader-supported; it is not an ad or subscription funnel.

## Positioning

The differentiating mechanism is **retention, not just reading**: spaced-repetition
Scripture memory (SM-2) across six distinct practice modes, wrapped in a daily-habit
gamification layer (XP, levels, streaks, streak freezes, badges, milestone
celebrations). Where competitors ship a verse-of-the-day, Reforged is a serious
study *and* memory tool — five translations, Strong's Hebrew/Greek word study, audio
playback, a study library (atlas, commentaries, dictionaries, devotionals), and
guided learning tracks — that still feels calm and unhurried. A neighboring
"verse-a-day" app cannot truthfully claim the memory-retention system or the study
depth; a heavyweight study app cannot truthfully claim the ad-free, habit-first calm.

## Operating Context

- **Daily, personal, devotional use**, often in short sessions (five minutes counts).
  Frequently one-handed on iPhone; also lean-back study sessions on iPad.
- Rituals that pull the user back daily: reading streak, home-screen widget, daily
  insight/verse, and due spaced-repetition reviews.
- Reading, highlighting, note-taking, word study, and memory practice are the
  recurring tasks. Study happens both in-passage (tap a word, open a commentary) and
  in dedicated practice sessions.
- Reader-support (donations/tips) is driven primarily **outside** the app (website,
  social, email → Buy Me a Coffee), constrained by Apple's IAP rules; in-app donation
  surfaces must respect those rules.

## Capabilities and Constraints

**Core, shipping capabilities:**
- **Bible reader** — 5 translations (ESV, KJV, CSB, NKJV, NASB); whole-Bible stable
  chapter spine; audio playback (ESV) with speed/skip controls; full-text search;
  color highlights and personal notes; tap-any-word Strong's lexicon; verse image-card
  sharing; customizable display (font family incl. dyslexia-friendly, size, spacing,
  verse-by-verse or paragraph).
- **Scripture memory** — spaced repetition (SM-2); six practice modes (flashcard, tap
  to reveal, drag & drop, fill in the blank, first letter, typing); five mastery levels;
  review tracking and progression.
- **Discipleship & Study Library** — guided doctrine/devotional learning tracks
  (lessons with passages, quizzes, reflection); reading plans (incl. Spurgeon
  Morning & Evening devotional); study library spanning Bible atlas, commentaries,
  dictionaries, and devotionals.
- **Focus & Purity Shield** — Screen Time-based adult-content blocking with protected-day
  streaks, focus sessions, encouragements, and accountability/partner reporting.
- **Gamification** — XP & levels, reading streaks with milestone celebrations and streak
  freezes, badges, daily insights.
- **Profile & sync** — Sign in with Apple; private CloudKit sync of profile, progress,
  memory verses, highlights, and notes; custom/emoji avatars; home-screen widget.

**Secondary / not positioned as core:**
- **Groups community** — community tab (prayer, shared lessons) is built and present but
  is treated as a secondary capability, not a headline pillar of the product.

**Constraints & terminology:**
- iOS 16.0 minimum; MVVM with singleton services; `@MainActor` ObservableObjects.
- Bible text via ESV API, Bible API (KJV), and API.Bible (CSB/NKJV/NASB); some
  publisher-restricted translations carry their own API key. NKJV audio is not licensable.
- App Store name of record: **"Reforged: Bible Study & Memory."**
- App Store rules govern in-app money asks (tips = Apple IAP only; charitable donation
  links belong outside the app).

## Brand Commitments

- **Name:** Reforged (App Store: "Reforged: Bible Study & Memory").
- **Voice:** warm, sincere, and quietly confident. Encouraging, never preachy or
  guilt-driven. Reads like a thoughtful friend, not a marketer. Sentence case, minimal
  emoji. Taglines in use: "Read it. Memorize it. Live it." / "Build a daily habit with
  God's Word." / "The Bible app that helps it actually stick."
- **Brand colors** (from Theme.swift / README): Navy `#333333` (primary text/UI —
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

- Real, feature-complete shipping app (627 Swift files; live on the maker's device/TestFlight path).
- Marketing/product docs in-repo: `README.md`, `Reforged_Welcome_Email.md`,
  `Reforged_Growth_and_Business_Plan.docx`, `Reforged_Ad_Copy_and_Creative_Pack.docx`,
  `APP_STORE_CHECKLIST.md`; three App Store screenshot JPGs; `website-source.zip`.
- Bundled study data: Strong's lexicon, doctrine/devotional tracks, SWORD commentaries
  & dictionaries, Bible-places atlas data, Spurgeon devotional.
- **Absences future work must not fabricate:** no public ratings, reviews, testimonials,
  user counts, or press yet ("screenshots: coming soon" era). Do not invent social proof,
  customer quotes, download numbers, or benchmarks. Single founder ("the maker of
  Reforged") — do not invent a team, company, or funding.

## Product Principles

1. **Retention over exposure.** The product's reason to exist is that Scripture *sticks*;
   every feature should serve reading, remembering, and living the Word, not vanity metrics.
2. **Calm, ad-free, and unhurried.** Depth without noise. Never trade the peaceful,
   focused feeling for engagement pressure, ads, or dark patterns.
3. **Habit by gentle pull, not guilt.** Streaks, reminders, and celebrations invite the
   user back; the voice encourages and never scolds. Reminders default off unless the
   user opts in per type.
4. **For all Christians.** Welcome every tradition; offer classic study resources without
   taking a denominational side.
5. **Respect the user's trust.** Privacy-first (Sign in with Apple, private CloudKit),
   honest about being reader-supported, and faithful to Apple's rules.

## Accessibility & Inclusion

- Dyslexia-friendly font option, adjustable font size and line spacing, and
  verse-by-verse vs. paragraph layouts are shipping reading-accessibility affordances.
- Full light/dark mode via an adaptive color system; contrast must hold in both
  (see the navy/charcoal token trap above).
- No formal external standard has been established as a binding requirement yet;
  treat legible contrast, Dynamic Type friendliness, and the dyslexia option as the
  current bar to preserve and extend.
