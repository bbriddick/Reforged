# Reforged onboarding plan

Status: **approved 2026-10-09**. Decisions resolved (§10). Interactive mock: `design/onboarding-mock/index.html` (run `onboarding-mock` from `.claude/launch.json`). No app code written yet.
Built with the Reforged design system, Apple UI design principles, and Impeccable's onboarding playbook.

---

## 1. The problem today

What exists now (`Views/Onboarding/OnboardingFlowView.swift`, 2,600 lines):

| # | Step | Notes |
|---|------|-------|
| 0–5 | Welcome, Reader, Memory, Discipleship, Walk Talks, Original Languages | Six marketing screens before anything is asked of you |
| 6 | Auth (Apple, email) | Sign-in is buried at step 7 of 16 |
| 7–14 | Name, Avatar, Goals, Translation, Display, AI, Notifications, Study Library | Eight setup screens |
| 15 | Final | |

Then `AppTour` takes over (30 contextual cards across Bible, Memory, Discipleship, Home).

**Where it hurts**

1. **Returning users wade through marketing to reach "Welcome Back".** Sign-in is the 7th screen.
2. **Email returning users get the full setup again.** Only Apple users with a CloudKit profile hit `onExistingUser` and skip ahead. Email/Supabase users hit `onNext()`, so they redo avatar, goals, translation, display, AI, notifications and library.
3. **A new device doesn't look like your device.** Translation, theme, font, reading format, reminders and AI choice live in local `UserDefaults`. iCloud KVS only syncs your reading position. Email users get no CloudKit restore at all (it is gated on Sign in with Apple), so memory verses, highlights and notes don't follow them.
4. **The tour replays on a new device.** `AppTour` state is local, so a restored account gets "Hold to define…" again.
5. **New users learn by reading, not doing.** Four feature slideshows, then eight settings, and the first verse isn't learned until well after onboarding. The "aha" (a verse that sticks) is never reached inside onboarding.
6. **Friends' own first-run** (consent screens) keys off a local flag per account, so it can re-appear on a new device.

---

## 2. Principles (what "best" means here)

From `PRODUCT.md`, the design system, Apple's HIG-style rules and Impeccable's onboarding playbook:

1. **Time to value.** Get to the moment that proves the app works: *you learned a verse.* Not "you read about learning a verse."
2. **Show, don't tell.** Real functionality inside onboarding, never a separate tutorial mode. The existing `AppTour` is the teaching layer; onboarding is not.
3. **Returning users are first-class.** Recognised in one tap, restored without questions, and never asked to redo anything the cloud already knows.
4. **One primary action per screen.** Progressive disclosure. Everything else waits for the moment it's needed.
5. **Respect the user.** Calm, no guilt, no dark patterns. Reminders and notifications are opt-in and default off. No fabricated social proof, ratings or user counts (none exist yet).
6. **Ask for the minimum, explain why.** Name, goals and translation have a visible payoff; everything else is deferred.
7. **Honest about time.** Say how long it takes ("About a minute").
8. **Skippable but never dead-ended.** Every optional step has an equal-weight "Not now".
9. **Privacy first.** Sign in with Apple is the leading option. Account creation can wait until the user has felt value, unless they're returning.

---

## 3. Three journeys

### A. New user (first install, no account yet)

Goal: **first verse learned in about 90 seconds**, minimal typing, **account deferred until after the first verse**.

```
Welcome ─► Bible ─► First verse ─► First review ─► First win ─► Walk Talks ─► Reminder ─► Keep it safe ─► Bible (+ app tour)
 (1 tap)  (KJV set)  (pick one)    (do 1 card)   (celebrate)   (partner)    (1 tap)     (Apple/skip)
```

| Step | Purpose | Primary action | Secondary |
|------|---------|----------------|-----------|
| **1. Welcome** | Promise + honest time | **Get started** | **Sign in** (a secondary button; the fast lane, always visible) |
| **2. Your Bible** | **KJV is selected automatically**, so most people just tap Continue. Others can switch; each shows John 3:16 live in the Scripture serif. | Continue | |
| **3. First verse** (toward the "aha") | Three verses from the learning path as large tappable cards (KJV text, bundled, so it works offline). Picking one adds it to Memory and goes straight into **one real flashcard** | Pick a verse | Skip for now |
| **4. First review** | The real Memory flashcard, not a mock. Tap to reveal, then "Not yet" or "Got it" (this honest answer schedules the next review) | Got it | Not yet |
| **5. First win** | "Your first verse. It comes back tomorrow, right when you're about to forget it." +XP, one pop, honest time ("You did that in 0:47") | Continue | |
| **6. Walk Talks** | The Southland Christian Camp partnership: what it is, plus an opt-in **"Notify me about new episodes"** toggle (default off). Kept in onboarding because they are a partner | Continue | |
| **7. Reminder** | One daily reminder at a time they choose. **This is the single system notification prompt**: it appears once, only if they said yes here or turned on Walk Talks notifications | Remind me at 7:30 AM | Not now (equal weight) |
| **8. Keep your progress safe** | Why an account: sync across devices, back up your streak, friends. **Sign in with Apple** first, email second. Never blocks | Continue with Apple | Maybe later |
| **9. Hand-off** | **First-timers always land in the Bible**, and the app tour begins right there (§6). Home's "Make Reforged yours" checklist is waiting when they get there | | |

What moves out of onboarding and into context (progressive setup, §5): name/avatar (profile, after the first streak day), display preferences (reader's AA menu), AI opt-in (first time an AI feature is tapped), study library downloads (first time a commentary is opened), original languages (surfaces at first word-tap), notification types beyond the daily reminder (Settings). **There is no goals or "what do you want" question**: the first-verse suggestions come from the learning path.

### B. Returning user (new device or reinstall), "the fast lane"

Goal: **3 taps or fewer, under about 15 seconds, no questions.**

```
Welcome ─► (auto-detect or sign in) ─► "Welcome back, Sam" restore ─► Home
```

1. **Entry points** (all lead to the same restore):
   - **Welcome → "I already have an account"** (one tap, no marketing).
   - **Auto-recognition:** on first launch, if the Keychain holds an Apple credential or Supabase session (reinstall, restored backup, same iCloud Keychain) and it's still valid, skip straight to the restore screen with a "Not you?" escape.
   - **Sign-in screen:** Apple (one tap) first, email second, minimal fields.
2. **Restore screen** ("Welcome back, Sam"): shows what's coming back in a calm checklist that fills in as it loads: *Your streak · Memory verses · Notes and highlights · Reading plans · Friends*. Honest progress, 5–10 seconds, then it dismisses itself. Includes "Continue now" once the profile is in (the rest can finish in the background).
3. **The rule:** if the cloud has a profile for this identity (Apple/CloudKit **or** Supabase), set `onboardingCompleted = true`, **skip every setup screen**, apply the synced preferences, and land on Home. This fixes today's email gap.
4. **"Finish setting up this device"** (non-blocking card on Home, max 3 items, dismissible, never reappears once dismissed):
   - **Turn on reminders** (permission is per device; shows their saved time/choices)
   - **Add the home-screen widget**
   - **Download for offline** (their last translation and any commentaries they'd downloaded)
   - Shown only if relevant. A user who had Focus Shield on sees "Re-enable Focus Shield on this device".
5. **No tour replay.** `tourState` restores with the account. A restored account gets one dismissible line ("New to this device? Take a 60-second tour") instead of the full tour.

### C. Edge and recovery paths

| Situation | Behavior |
|-----------|----------|
| Session expired on an existing device | Inline "Sign in again" sheet, local data kept, no onboarding |
| Apple user but no CloudKit data (different iCloud account) | Treated as new but keeps their Apple name/email; skips name |
| Email sign-in needs confirmation | "Check your email" screen with resend and an open-Mail button; resumes where they left off |
| Offline on first launch | Works as a guest with the bundled KJV/learning path; "Sign in when you're online"; syncs later; restore re-runs on reconnect |
| No iCloud on the device | Account via email; clear note that sync needs an account |
| Reinstall, same account | Auto-recognition (journey B) |
| Under 13 | Age gate stays where it is today (Friends/Groups only); no change to onboarding |
| Account deletion | Existing flow; a deleted account returns to journey A cleanly |
| Sign out on a shared iPad | "Sign out" returns to Welcome without wiping the device until confirmed |

---

## 4. Screen design

All screens use the Reforged design system. Apple-style clarity and restraint; Impeccable's "operate" mode (first-run is a task flow, brand shows in details).

### Visual language
- **Canvas** warm off-white `#FAF8F5`, white cards, charcoal text; the Welcome screen keeps the existing charcoal launch screen with the cream "R" mark so the app opens as it always has. Full dark and AMOLED support through the existing adaptive colors.
- **Action color:** coral `#E94560` for the one primary pill per screen. **Gold** `#D4A574` only for reward/Scripture moments (the verse reference, the celebration). Not both on the same control.
- **Type:** system/SF for UI, **Libre Baskerville** for every Scripture line (the translation preview, the first-verse cards, the flashcard). Screen titles bold, sentence case, tight tracking. Dynamic Type supported.
- **Spacing:** 24 px gutters, base-8 rhythm, 16 px card padding, generous vertical whitespace; content column max ~440 px on iPhone and a centered ~560 px column on iPad (no stretched layouts).
- **Components:** 52 pt pill primary button, text-style "Not now" under it (≥ 44 pt tap target), soft cards with 16–20 px radii and the warm 0.06 shadow, a thin step indicator (dots, not "Step 3 of 7" arithmetic), `scale(0.97)` press.
- **Motion:** 0.3 s ease, `fadeUp` on content, a gentle spring on the single celebration. Everything respects **Reduce Motion**. No looping decoration.
- **Icons:** SF Symbols only. No emoji in app chrome; a single 🙏 or 🔥 is allowed in celebration microcopy.

### Voice (from the brand guide)
Warm, sincere, never guilt-driven, sentence case, short sentences. Examples:
- Welcome: **Reforged**, then *"Read it. Memorize it. Live it."* · *"About a minute to set up."*
- Your Bible: *"Your Bible."* · *"King James is selected. Change it any time."*
- First verse: *"Pick one to start. We'll bring it back right before you'd forget it."*
- Walk Talks: *"Reforged partners with Southland Christian Camp to bring you Walk Talks."*
- Reminder: *"Remind you each day at a time you choose. Change or turn it off any time."* · "Not now" never shames. (No "nudge" language anywhere in onboarding.)
- Account: *"Keep your streak and verses safe, and use Reforged on every device."*
- Restore: *"Welcome back, Sam. Getting everything ready."*

### Accessibility
44 pt targets; VoiceOver labels on every control and a logical order; contrast ≥ 4.5:1 in light and dark (mind the navy/charcoal token trap, use `adaptiveNavyText`); Dynamic Type through the largest sizes without truncating primary actions; Reduce Motion alternatives; text options live in the reader's AA menu (including the dyslexia-friendly font), not in onboarding.

### iPad
Same flow, centered column, larger type; the first-verse cards sit side by side; restore screen uses the full-width calm layout. Landscape supported.

---

## 5. Progressive setup (everything removed from onboarding, and when it returns)

| Was in onboarding | Now appears | Trigger |
|-------------------|-------------|---------|
| Name, avatar | Profile prompt | After the first streak day, or when opening Profile |
| Goals | **Removed.** No goals question; first-verse suggestions come from the learning path | n/a |
| Display preferences (theme, font, format) | Reader AA menu, with a "Make reading comfortable" hint | First reader open; tour step `textOptions` already exists |
| AI opt-in | Consent sheet | First tap on an AI feature (Gemini features send text to Google, so consent belongs at point of use) |
| Notifications (types) | Reminder step (daily) + Walk Talks toggle in onboarding; everything else in Settings | Per-type opt-in stays off by default |
| Study library downloads | "Download for offline" card | First commentary/dictionary open |
| Original languages demo | Word-study tour step | First word tap |
| Walk Talks partnership | **Stays in onboarding** (step 6, partner commitment) and keeps its permanent home in Discipleship | n/a |
| Feature slideshows | **Removed.** `AppTour` teaches them in place | n/a |

A small **"Make Reforged yours"** checklist lives on Home for the first week (max 4 rows, collapsible, auto-hides when empty). It is the only place deferred items collect.

---

## 6. How the existing tour fits

`AppTour` stays the teaching layer, with three changes:

1. **New users start in the Bible, and the tour starts there.** This is how the app already behaves (`completeOnboarding` lands on tab 2 and `AppTour` begins at "Hold any word to define it"), and it stays. The walkthrough then continues through Memory, Discipleship and Home exactly as the tour does today, tab by tab. Original-language word study stays a tour moment at the first word-tap.
2. **Tour is aware of onboarding.** Skip cards for things the user already did (no "Add a verse" card if they added one during the first-verse step).
3. **Tour state syncs** with the account (`tourSectionsDone`, `tourDisabled`) so a restored user does not replay it. Offer "Take the app tour" in Settings as today.

Friends' own first-run follows the same rule: its "done" flag moves from a local default to account state (the server already knows `consent_at`), so it never re-appears on a second device.

---

## 7. What has to change in the code

**Restructure (new/split files, not one 2,600-line file)**

- `OnboardingCoordinator` (state machine): `.welcome → .translation → .firstVerse → .firstReview → .win → .walkTalks → .reminder → .account → .done`, plus `.signIn`, `.recognized` and `.restore` for the returning branch. Replaces the linear `OnboardingStep` enum and the `skippableWithAppleSignIn` hack.
- `AccountRestoreService`: one place that, given a signed-in identity, fetches the profile (CloudKit and/or Supabase), applies synced preferences, imports streak history, memory verses, notes, highlights and tour state, and reports progress for the restore screen.
- `DevicePreferences` / `SyncedPreferences` (Codable): translation, theme, font family/size/spacing, reading format, reminder choices, AI opt-in, tour state, Friends-onboarding done. Stored in the CloudKit profile record and a `preferences` JSON column on the Supabase profile.
- `DeviceSetupChecklist` (Home card) and `MakeItYoursChecklist`.
- Step views split out, one file each, reusing the design-system components.

**Behavior fixes (quick wins that don't need the redesign)**

1. In `AuthStepView`, when a Supabase email sign-in returns an **existing** profile, call `onExistingUser` (same as Apple), not `onNext`.
2. Add **"I already have an account"** to the Welcome screen, jumping to the sign-in step.
3. Suppress the `AppTour` auto-start when the account was restored.
4. Detect a valid Keychain session at launch and offer the restore screen.

**Sync changes**

- **Decouple CloudKit from Sign in with Apple** (decided): every signed-in user with iCloud gets memory verses, highlights, notes and preferences on every device. `syncToCloud` currently requires `appleSignIn.isSignedIn`; change the gate to "signed in with any provider and iCloud available". Users without iCloud keep email-only profile sync.
- Add the `preferences` payload to profile save/load (both stores). **Default translation for new installs is KJV** (set automatically; no choice required).
- Make the Friends/tour "done" flags account-level.

**Backend (Lovable prompt, when we get there)**
- `profiles.preferences jsonb` plus read/write via the existing profile upsert.
- Optionally `profiles.restore_summary` view (counts for the restore screen) if CloudKit can't provide them quickly.

---

## 8. Phases

| Phase | Scope | Why this order |
|-------|-------|----------------|
| **0. Quick wins** (small) | Email returning users skip setup; "I already have an account" on Welcome; no tour replay for restored accounts; Keychain auto-recognition | Fixes the sharpest pain today without a redesign |
| **1. Restore + sync** | `AccountRestoreService`, restore screen, synced preferences, CloudKit for email users, account-level tour/Friends flags, device-setup checklist | Makes "new device looks like your device" true |
| **2. New-user flow** | Coordinator, new Welcome → Your Bible (KJV) → First verse → First review → First win → Walk Talks → Reminder → Account, hand-off to the shorter tour | The big redesign, built on Phase 1 plumbing |
| **3. Progressive setup** | Move name/avatar/display/AI/library into context; "Make Reforged yours" checklist | Safe to do once onboarding no longer asks for them |
| **4. Polish and QA** | Accessibility, iPad, dark/AMOLED, Reduce Motion, copy review, device matrix | Impeccable `critique`, `audit`, `polish` passes |

Each phase ships on its own; Phase 0 and 1 are worth shipping before Phase 2.

---

## 9. Acceptance criteria

| Journey | Target |
|---------|--------|
| Returning user, Apple, same iCloud | 1–2 taps to Home, restore ≤ 15 s, **zero** setup screens |
| Returning user, email, new device | Email + password, then restore, **zero** setup screens, memory and notes present |
| New user | First flashcard reviewed within ~90 s (steps 1–4); account asked only after the first verse; one system notification prompt at most; every optional step has a visible skip |
| Returning user's tour | Does not replay; one optional "quick tour" line |
| New device preferences | Same translation, theme, font, reading format, reminder time; permission re-requested on this device only |
| Offline first launch | Usable as guest; restores on reconnect |
| Accessibility | Dynamic Type XXL no truncation of primary actions; VoiceOver completes the whole flow; Reduce Motion honored |
| Visual | Light, dark and AMOLED; iPhone SE to iPad Pro 13" |

**Test matrix:** new / returning-Apple-with-CloudKit / returning-Apple-without / returning-email / reinstall / expired session / offline / no iCloud / iPad landscape.

**Measuring success without analytics:** the product promises privacy, so no tracking. Use TestFlight timing runs (stopwatch), a short feedback form, and an on-device-only counter shown in a debug menu.

---

## 10. Decisions (resolved 2026-10-09)

| # | Question | Decision |
|---|----------|----------|
| 1 | Account timing | **Defer sign-up until after the first verse** |
| 2 | Cloud sync for email users | **Yes.** Extend CloudKit sync to every signed-in user with iCloud |
| 3 | Walk Talks partnership | **Keep in onboarding** (partner). Step 6, with its opt-in notification toggle |
| 4 | Intention / goals question | **Removed.** Flow updated above |
| 5 | Original-language preview | Stays a tour/word-tap moment (not in onboarding) |
| 6 | Default translation | **KJV, selected automatically** |
| 7 | Reminder copy | No "gentle nudge" wording: plain "remind you each day at a time you choose" |
| 8 | Interactive mock | Built: `design/onboarding-mock/index.html` |

Plan approved. Next: Phase 0 quick wins, then Phase 1.
