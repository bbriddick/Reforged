# Reforged — App Store Distribution Checklist

This tracks everything needed to ship Reforged to the App Store. Items marked ✅
are done in-repo; ☐ items are actions you complete in App Store Connect / Apple
Developer portal.

## In-repo readiness (done in code)

- ✅ **Privacy manifest** (`Reforged/PrivacyInfo.xcprivacy`) declares the required-reason
  API used: `UserDefaults` (reason `CA92.1`). Re-audit if you add APIs in the
  "required reason" categories (file timestamp, disk space, system boot time,
  active keyboards).
- ✅ **Export compliance** — `ITSAppUsesNonExemptEncryption = false` added to
  `Info.plist` (app only uses standard HTTPS). Skips the per-upload prompt.
  ⚠️ If you ever add non-standard/custom encryption, change this and file the
  annual self-classification report.
- ✅ **Removed legacy `UIRequiredDeviceCapabilities = armv7`** (contradictory on a
  64-bit-only app).
- ✅ **Account deletion** path exists (`AccountSettingsSection.swift`) — satisfies
  App Store Guideline 5.1.1(v) for apps with account creation.
- ✅ **Networking** all HTTPS; no ATS exceptions; no third-party analytics/crash SDKs.
- ✅ **App icon** uses the modern single 1024 set with dark + tinted variants.
- ✅ **Universal** — `TARGETED_DEVICE_FAMILY = 1,2` (iPhone + iPad); adaptive
  sidebar (iPad) / tab bar (iPhone) navigation.
- ✅ **Family Controls** entitlement distribution request — **already approved** by Apple.

## App Store Connect actions (you do these)

- ☐ **App Privacy "nutrition label"** — fill out the privacy questionnaire. Reforged
  collects/handles, at minimum:
  - **Sign in with Apple** → user identifier (and relayed email if user shares it).
  - **User content** (journal entries, memory verses, profile photo) synced via
    **CloudKit** (user's own iCloud — generally *not* "collected by developer") and
    sent to your **Supabase** backend + **Gemini proxy** for AI features (this *is*
    collected by you). Declare accordingly.
  - Confirm none of it is used for tracking (manifest sets `NSPrivacyTracking = false`).
- ☐ **Privacy Policy URL** — required (you have accounts + a backend). Host one and
  add the link in App Store Connect *and* in-app (Settings/About).
- ☐ **Age rating** questionnaire.
- ☐ **Screenshots** — required sizes: 6.9" iPhone (1320×2868) and 13" iPad
  (2064×2752). Capture in light + dark if you want.
- ☐ **App description, keywords, subtitle, promotional text.**
- ☐ **Support URL** (required) and Marketing URL (optional).
- ☐ **Demo account** for review — Family Controls / account-gated features need a
  reviewer-usable login, or clear notes in "App Review Information."
- ☐ **Review notes** — explain the Screen Time / Family Controls usage (focus
  blocking for discipleship) so review understands the entitlement.
- ☐ **Bump build number** before each upload (`CURRENT_PROJECT_VERSION`, currently 16;
  `MARKETING_VERSION` 2.0).

## Pre-upload build steps

- ☐ Archive a **Release** build (Xcode → Product → Archive) — Release config uses
  `Reforged.entitlements` (production), Debug uses `ReforgedDebug.entitlements`.
- ☐ Validate the archive in the Organizer before distributing.
- ☐ Confirm all 4 targets (app, Widget, Shield, ActivityMonitor) sign with the
  production team & matching App Group `group.com.reforged.app`.

## Dependency cleanup (done in code)

- ✅ **Removed the unused `YouVersionPlatform` SPM dependency.** It was linked into
  the app but never imported or referenced in any source file (dead since commit
  e4bae1e). Removing it:
  - Resolved the **iOS 17 deployment-target mismatch** — it was the only thing
    requiring iOS 17, so the app now builds clean against its 16.0 target with no
    dependency warnings (no need to bump the deployment target).
  - Dropped dead binary weight and one third-party SDK from the privacy story.
  - Note: a separate codesign "detritus" error (macOS Sequoia `com.apple.provenance`
    xattr) still affects CLI builds of the app's *own* `.appex` extensions — this is
    environmental and harmless in the **Xcode GUI**, which is what you archive with.

## Device adaptivity (done in code)

- ✅ Replaced all `UIScreen.main.bounds` usage (8 sites) with a new `AppWindow`
  helper (`Theme.swift`) that returns the **app window** size — correct under iPad
  Split View / Slide Over / Stage Manager, where `UIScreen` is the physical screen.
- ✅ Bible reader already constrains to 800pt max width on iPad (regular size class).
- ☐ *Optional polish:* apply `.readableContentWidth()` to other long-form screens
  (Home, Profile, Settings, Journal) so they don't stretch edge-to-edge on iPad.

## Accessibility (done in code)

- ✅ Added `scaledFont(...)` Dynamic-Type primitive in `Theme.swift` (SwiftUI's
  `.system(size:)` ignores the accessibility text-size slider; this respects it).
- ✅ VoiceOver labels/hints on the Bible reader's icon-only buttons (search, audio,
  text options, prev/next chapter, chapter picker). Tab bar already used `Label`.
- ☐ *Optional polish:* extend `scaledFont` + VoiceOver labels to remaining chrome
  (Home, Memory, Profile) for full coverage.

## Notes / nice-to-haves

- The Supabase URL + anon key live in `Info.plist`. The anon key is public by design
  (RLS protects data), so this is acceptable — just ensure Row Level Security is
  enforced on every Supabase table.
- ✅ All 108 `print()` statements converted to `debugLog(...)`, a no-op in Release
  builds (keeps diagnostics — including an APNs device-token print — out of shipping
  device logs).
