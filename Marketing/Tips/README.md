# Reforged Tips: motion graphics + in-app section

Eight 30 to 40 second tips (two per category), each built in After Effects as a
16:9 master and a 9:16 social cut. The same content powers the new **Tips** screen
in the app (Home → Tips card).

## Folder

```
Marketing/Tips/
  tips.json                 single source of truth (titles, hooks, steps, VO)
  build.py                  re-generates ae/Build_Reforged_Tips.jsx after editing tips.json
  ae/Build_Reforged_Tips.jsx   run this in After Effects
  ae/template.jsx           script template (edit design here, then run build.py)
  ae/logo-mark.png          charcoal R mark
  ae/fonts/                 Archivo Black (titles), Libre Baskerville, Roboto (install before running)
  broll/                    Higgsfield clips (not used in the tip videos; spare footage for social)
  screens/                  your iPhone screen recordings (see shot list)
  vo/                       optional voiceover: <tip-id>.mp3
  renders/                  After Effects output lands here
```

## Run it

1. Install the fonts in `ae/fonts` (double-click, Install). Archivo Black is required for the titles.
2. In After Effects: **File → Scripts → Run Script File…** → `ae/Build_Reforged_Tips.jsx`.
   (If it complains about file access: Settings → Scripting & Expressions →
   *Allow Scripts to Write Files and Access Network*.)
3. It builds 16 comps in a new project folder and queues them for render
   (H.264 to `renders/` when your AE version supports it, otherwise .mov).
   An alert lists any missing screen recordings; placeholders are used until you add them.
4. Re-run any time after adding recordings or VO; each run builds a fresh folder.

## Video structure (16:9 master)

| Time | Beat |
|---|---|
| 0 to 5.3s | Full-screen charcoal title card: category rule, eyebrow, ALL-CAPS Archivo Black title, hook line |
| 5.3s | Paper wipe up; eyebrow and Archivo Black title top-left, phone slides in |
| 7 to 28s | Three steps, 7s each; active step leads, finished steps dim |
| 28.4s | Outro: R mark, "Read it. Memorize it. Live it.", coral "Free on iOS and Android" pill |

The 9:16 cut uses the same beats with the phone centered and one step caption at a time.
Timings live in the `T` block at the top of `template.jsx`.

## Screen recording shot list

Record on iPhone (Control Center → Screen Recording), light mode, clean status bar,
~10 to 12s each, and save into `screens/` with these exact names (.mov or .mp4).
The first plays during steps 1 and 2, the second takes over for step 3.

| Tip | First recording | Second recording |
|---|---|---|
| 01 Spaced repetition | `memory-add` tap a verse → Memory | `memory-due` Memory tab → clear Verses Due |
| 02 Six practice modes | `memory-modes` flip through practice modes | `memory-journey` scroll the Memory journey path |
| 03 Original languages | `reader-strongs` press and hold a word → Strong's | `reader-study` tap verse → Study sheet |
| 04 Make it yours | `reader-actions` Highlight, Note, Share card | `reader-audio` play audio, change speed |
| 05 Protect your streak | `habits-streak` Home streak card | `habits-freeze` streak sheet → Buy Freeze |
| 06 Start your day | `habits-widgets` Home Screen widgets | `habits-morning` Morning Routine |
| 07 Study classics | `study-library` Study Library hub | `study-offline` commentary downloads |
| 08 Guard your focus | `study-shield` Focus & Purity Shield | `study-sos` I'm Being Tempted flow |

## Voiceover (optional)

The `vo` field in `tips.json` has a ~20s script per tip. Drop `vo/<tip-id>.mp3`
(e.g. `vo/memory-spaced.mp3`) and re-run the script; it's placed at 5.2s.

## Publishing to the app

The app streams the 16:9 renders from Supabase Storage. Create a **public** bucket
named `tips` and upload the renders with their render-queue names, e.g.
`01_memory-spaced_16x9.mp4`. Until a file exists, the tip screen just shows the steps.

## Editing tips

Edit `tips.json`, run `python3 build.py` from this folder, and mirror the change
in `Reforged/Views/Home/TipsView.swift` (`TipsLibrary.all`).
