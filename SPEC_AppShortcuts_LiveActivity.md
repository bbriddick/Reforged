# Spec: App Shortcuts (Siri) + Live Activity streak

Goal: give users two more zero-friction daily-return surfaces, voice/Spotlight/Action-button entry into reading and verse review, and a lock-screen streak/review nudge. Both reuse what already exists (App Group, `reforged://` router, `ReadingStreakManager`, `MemoryVerse.isDueForReview`).

## 0. What exists today (verified in code)

| Piece | Where | Relevance |
|---|---|---|
| App Group `group.com.reforged.app` | app + `ReforgedWidget` entitlements | Shared storage already works |
| Streak data in App Group | `reforged_streak_dates`, `reforged_frozen_dates`, `settings.dayStartHour` | Widget re-implements `calculateStreak`; intents/Live Activity must reuse it |
| Deep-link router | `ReforgedApp.handleDeepLink`, hosts `panic`, `join`, `bible?reference=` | Extend with `review`, `read`, `plan` |
| Due verses | `MemoryVerse.isDueForReview` (`nextReviewDate <= Date()`) | **Stored in standard `UserDefaults` (`reforged_verses`), NOT the App Group**, extensions can't see it |
| Widget bundle | `ReforgedWidgetBundle`: VOTD, Streak, Panic | Live Activity widget is added to this bundle |
| Deployment target | app 16.0, some targets 17.0 | Live Activities need 16.1; App Shortcuts need 16.0. Gate with `#available(iOS 16.1, *)` |
| ActivityKit / AppIntents | none | Greenfield |

## 1. Prerequisite: mirror review state to the App Group

Neither feature works without this. Add a tiny `SharedReviewState` (Codable) written to the App Group by the app:

```
struct SharedReviewState: Codable {
    var dueCount: Int
    var nextDueDate: Date?      // earliest future nextReviewDate, for scheduling
    var nextVerseRef: String?   // first due verse reference, for display
    var updatedAt: Date
}
key: "reforged_shared_review_state"
```

- Write from `AppState.saveToLocalStorage()` (already the single persistence point), then `WidgetCenter.shared.reloadAllTimelines()`.
- Put the struct in a file added to **both** the app and widget targets (the widget can't import the app target, same constraint noted in `ReforgedWidget.swift`). Remember to add the new file to `project.pbxproj` for each target.
- Do **not** move `reforged_verses` itself to the App Group; mirror a summary only.
- Extract the streak calculation into a shared file used by app + widget + intents so the three copies can't drift (today the widget duplicates `calculateCurrentStreak`).

## 2. App Shortcuts

### Intents (v1)

| Intent | Phrase examples | Behavior | `openAppWhenRun` |
|---|---|---|---|
| `ReviewVersesIntent` | "Review my verses in Reforged" | Opens app at the due-review flow | true |
| `ReadTodayIntent` | "Read the Bible in Reforged" | Opens reader at Continue Reading position (`ContinueReading.swift`) | true |
| `OpenReadingPlanIntent` | "Open my reading plan" | Opens today's plan day | true |
| `StreakStatusIntent` | "What's my Reforged streak?" | **Runs in background**, speaks/returns streak + due count from App Group, no app launch | false |
| `VerseOfTheDayIntent` | "Verse of the day in Reforged" | Background; returns verse text + reference from `reforged_widget_daily_insight` | false |
| `OpenTemptedSOSIntent` | "I'm tempted" / "Reforged SOS" | Opens the existing panic flow (`showTemptedSOS`). Good Action-button candidate. | true |

The two background intents return `.result(value:dialog:)` with an `IntentDialog`, they work in Siri, Spotlight and Shortcuts without opening the app. Note: they read only App Group data (§1), so they stay correct offline.

### Wiring

- New file `Reforged/Intents/ReforgedShortcuts.swift` (main app target) containing the intents and an `AppShortcutsProvider` with `AppShortcut(intent:phrases:shortTitle:systemImageName:)`. Every phrase must include `\(.applicationName)`.
- Foreground intents don't call app code directly. They post a pending route into the App Group (`reforged_pending_route`: `"review"`, `"read"`, `"plan"`) and the app consumes it on `scenePhase == .active`, this handles cold launch where `NotificationCenter` observers aren't registered yet. Alternative: have `perform()` open a `reforged://` URL via `OpenURLIntent` (iOS 18+ only; the pending-route key works on 16+).
- Extend `handleDeepLink` with `reforged://review`, `reforged://read`, `reforged://plan` mapping to the same actions, so widgets, notifications and intents share one router. Today only `panic`, `join`, `bible` exist.
- Review route: reuse whatever `HomeView`'s "due" tile launches (`HomeView.swift:369` counts `isDueForReview`), find that entry point rather than building a new one. Open question: confirm the due-review flow can be presented from the root without first visiting the Memory tab.
- Add `NSUserActivityTypes` is **not** needed; App Shortcuts need no Info.plist entry.

### Done when
- All six phrases appear in Shortcuts app / Spotlight with no user setup.
- Siri streak answer matches Home and the streak widget for a user with a freeze-covered gap and a non-zero `dayStartHour`.
- Cold-launch from "Review my verses" lands on review, not Home.

## 3. Live Activity: "Streak at risk" + review nudge

### Scope decision (recommend)

Apple limits Live Activities to ~8 hours of active time (up to 12 hours on the Lock Screen after ending), and apps may not start them silently from the background without push-to-start. So this is **not** an all-day streak counter. Recommended design:

1. **Evening "streak at risk" activity.** If the user has a streak > 0 and no activity today (`ReadingStreakManager.isStreakAtRisk`), start an activity around the user's reminder time or 7pm local. It shows streak count, hours left, and due-verse count. It ends as soon as `recordActivity` runs, or at the day boundary (respect `dayStartHour`).
2. **Active practice session activity** (optional v2): while in a memory review session, show progress (e.g. 4/10 verses) on the lock screen/Dynamic Island.

### Starting it, the hard part

An activity must be started while the app is in the foreground, or by push (`push-to-start`, iOS 17.2+). Options:

| Approach | Needs | Verdict |
|---|---|---|
| Start when app last backgrounded, in the evening | nothing new | Only works if user opens the app that day, **useless for the at-risk case** (they didn't open it) |
| Background task (`BGAppRefreshTask`) | unreliable; cannot start activities from background | No |
| **Push-to-start via APNs** | server (Supabase edge function + cron), APNs key, push-to-start token upload | The only reliable method; iOS 17.2+ |
| Tap-to-start from notification | existing local notification | Weak: still requires opening the app |

**Recommendation:** ship v1 as App Shortcuts (§2) plus the in-session activity (2). Treat push-to-start as v2 because it needs backend work (Supabase is Lovable-managed, so edge functions deploy via a Lovable prompt, per project notes) and server-side knowledge of each user's streak state. Do not promise an "at-risk" Live Activity before that infrastructure exists.

### Implementation (in-session activity, v1)

- `ReviewSessionAttributes: ActivityAttributes`, static: session title. `ContentState`: `completed: Int`, `total: Int`, `streak: Int`, `currentRef: String`. Shared file in app + widget targets.
- `ReviewSessionLiveActivity` widget added to `ReforgedWidgetBundle` with lock-screen layout and Dynamic Island (compact: flame + count; expanded: ref + progress bar; minimal: flame).
- Start in the review flow's entry (`MemoryReviewView`), update per verse, end on completion with a `dismissalPolicy` of `.after(now + 5 min)` showing the final streak.
- Info.plist (main app): `NSSupportsLiveActivities = YES`. Add `NSSupportsLiveActivitiesFrequentUpdates` only if updating more than a few times/hour (not needed here).
- Guard everything with `ActivityAuthorizationInfo().areActivitiesEnabled`; fail silently.
- Style: reuse the streak widget's colors; remember navy/charcoal tokens vanish on dark backgrounds, use `adaptiveNavyText`-equivalent logic or gold/coral literals (Live Activities render on both backgrounds).
- Copy: no gambling language ("jackpot", coins). XP/level phrasing is fine.

### Done when
- Starting a review shows the lock-screen activity within 1s; progress updates per verse; ends on completion and on abandon.
- Disabling Live Activities in Settings causes no crash and no UI change.
- Streak value in the activity equals `ReadingStreakManager.currentStreak`.

## 4. Risks / open questions

1. **Notification spam policy**, project rule: all reminder toggles default false. Any push-to-start or new reminder must be opt-in and added to `scheduleDailyReminder()` as the single scheduling source.
2. **Privacy**, Siri/Shortcuts responses speak aloud. Streak/verse are low sensitivity; do NOT add intents that expose Shield/focus/tamper or partner-report data.
3. **Target membership**, shared files must be added to both targets in `project.pbxproj` manually.
4. **CloudKit signing trap**, test on a signed build (`CODE_SIGNING_ALLOWED=NO` crashes on launch). Live Activity and App Group behavior must be verified on a signed simulator/device build.
5. **Verification**, Siri phrase recognition and the Dynamic Island are best checked on a real device; the simulator supports Shortcuts and Live Activity previews but not Siri voice.
6. **Confirm** whether the review flow can be presented directly from the root (see §2).

## 5. Suggested order of work

1. `SharedReviewState` + shared streak calculation (½ day)
2. Router additions + pending-route consumption (½ day)
3. Six App Shortcuts + provider (1 day)
4. In-session Live Activity + Dynamic Island (1–2 days)
5. *(Later)* push-to-start "streak at risk" with Supabase cron + APNs (backend, several days)
