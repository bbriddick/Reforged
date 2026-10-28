# Reforged Bible ↔ Honor, v1

The Bible app implements the requested App Group contract in `Reforged/Services/HonorLink.swift`. Existing App Group key names and writes remain intact. No Honor repository or CloudKit record types were changed.

## Wire behavior and points for the Honor agent

- Key names, Codable property names, and wire types match v1. `link.v1.version` is JSON Data containing `1`; Bible writes it at launch as the contract explicitly requires, alongside its own namespace and the shared partner. Bible never writes `link.v1.honor.*`.
- All link values use JSONEncoder/JSONDecoder with `.iso8601` dates. Day keys use the user's current calendar and time zone. Activity export includes today and the preceding 89 calendar days, excludes future days, and contains only `reading`, `memory`, `lesson`.
- Bible posts `com.reforged.link.changed` after every link write or reading-key removal. It observes this Darwin notification and reloads on foreground. Honor installation is determined by `canOpenURL(reforgedshield://)`, never the persisted install date.
- Clearing the partner exports a **timestamped LinkPartner with empty name/phone**, retaining newest-updatedAt-wins semantics. A bare JSON null or missing key has no timestamp, so cannot supersede a local record. Honor should use the same empty-record convention for a synchronized deletion. This clarifies the nullable-partner ambiguity without adding a field or changing its wire type.
- Legacy memory verses without a stored translation use ESV, matching the existing memory reader. ESV export uses `esvText` when present, otherwise the verse's saved `text`. Exports sort by actual nextReviewDate, with a reference tie-break, and cap at 50.
- Today's reading mirrors ReadingPlanService's existing self-paced active-entry selection, with the current local calendar day and plan name. It refreshes on plan saves, launch, foreground, and calendar-day notifications; no active plan removes the key.
- The App Store URL remains an explicitly marked TODO in HonorLink until Honor has a published product URL. The current placeholder opens the App Store landing page.

## Blocking ownership

Bible asks once before handoff. Consent persists `honorOwnsBlocking` in the App Group, clears its own named ManagedSettings stores, and stops only its own schedule/session/social-limit/unlock-gate monitors. Schedule and blocking preferences remain saved. The active timed focus session is ended, not resurrected later.

The Scripture unlock gate is included in handoff: leaving it running would allow Bible to re-lock apps while Honor owns blocking. This extends the enumerated blocking-store list, not the wire contract. Foreground services and DeviceActivity extension callbacks respect the persisted pause. No Honor ManagedSettings stores or activities are cleared.

If Honor becomes uninstalled or explicitly reports inactive protection, Bible offers restoration. It never silently restores. “Keep Paused” leaves settings paused and makes the restore action available on both status screens. Restoration re-applies saved Bible blocking and schedules; it does not recreate the ended timed session.

## Changed files

- `Reforged/Services/HonorLink.swift`: contract, codecs, JSON I/O, Darwin signaling, installation/deep links, partner ordering, exports, blocking consent state.
- `Reforged/Services/AppState.swift`: export memory verses after every array mutation, including load/merge.
- `Reforged/Services/ReadingStreakManager.swift`: export activity alongside existing persistence.
- `Reforged/Services/ReadingPlanService.swift`: refresh reading on plan saves.
- `Reforged/Services/AccountabilityPartnerService.swift`: dual-write partner edits; adopt newer shared records without echoing.
- `Reforged/Services/FocusBlockingService.swift`: respect ownership pause.
- `Reforged/Services/FocusSessionService.swift`: consent-driven session shutdown and pause guard.
- `Reforged/Services/ScheduledBlockingService.swift`: pause/resume monitoring while retaining schedules.
- `Reforged/Services/SocialLimitService.swift`: stop own monitor/store and prevent rearming while paused.
- `Reforged/Services/UnlockGateService.swift`: stop own gate/monitor and prevent rearming while paused.
- `ReforgedActivityMonitor/DeviceActivityMonitorExtension.swift`: prevent paused callbacks from applying Bible blocking.
- `Reforged/ContentView.swift`: launch/foreground refresh, consent/restore alerts, SOS handoff.
- `Reforged/ReforgedApp.swift`: panic URL handoff.
- `Reforged/AppDelegate.swift`: notification-action handoff with existing pending-SOS fallback.
- `Reforged/Views/Discipleship/DiscipleshipView.swift`: shared Honor status card and SOS handoff.
- `Reforged/Views/Discipleship/FocusBlockingView.swift`: Honor status card and SOS handoff.
- `Reforged/Info.plist`: allow querying the Honor URL scheme.
- `Reforged.xcodeproj/project.pbxproj`: add HonorLink to the app target.
- `Scripts/validate_honor_link.swift`: executable unit validation in the existing regression-runner style.
- `docs/honor-link-v1.md`: implementation and compatibility handoff notes.

## Validation

Run the new contract checks from the repo root:

```sh
swiftc -module-cache-path /tmp/reforged-swift-cache Reforged/Services/HonorLink.swift Scripts/validate_honor_link.swift -o /tmp/validate-honor-link
/tmp/validate-honor-link
```

Checks cover every v1 type and collection, optional fields/nulls, an Honor-authored ISO 8601 fixture, local-day/DST behavior, 90-day activity boundaries, allowed activity kinds, and partner timestamp ordering. The existing cleanup regression runner was also executed successfully against the real Foundation models/helpers, extracting its shared formatter/logger dependencies into temporary files.

The unsigned generic iOS build **succeeded**, including all app extensions, using an identical temporary source/project copy at `/tmp/reforged-honor-build-workspace` (all Swift/plist/entitlement contents verified against the working repo). The original project location stalled inside macOS NSFileCoordinator, so the temporary copy bypassed that environmental issue. The pre-existing package cache also had a missing Git tree; the build used a fresh checkout of the project's already pinned YouVersion 5.5.0 dependency, without changing Package.resolved. Build log: `/tmp/reforged-honor-build-copy.log`.

Physical-device validation with both apps remains necessary for URL routing, Darwin delivery between signed processes, and Screen Time enforcement. No device installation or two-app interaction was performed here.
