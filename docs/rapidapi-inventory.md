# RapidAPI / Complete Study Bible inventory (Step 0)

Written 2026-10-10 for `reforged-study-data-spec.md`. Nothing in this document has been implemented yet.

## 1. Where the API is used

The Complete Study Bible API (`complete-study-bible.p.rapidapi.com`) is called from three codebases. All three share the same three endpoint shapes.

| Codebase | Path | Client | Key source |
|---|---|---|---|
| iOS (this repo) | `Reforged/Services/StrongsLexiconService.swift` | `StudyBibleConfig` + `fetchFromAPI` | **Hardcoded string literal, line 6** |
| Mac | `~/Documents/GitHub/Reforged Mac/Reforged/Services/StrongsLexiconService.swift` | Same file, copied | **Hardcoded string literal, line 6** (same key) |
| Android (Kotlin native) | `~/Documents/GitHub/Reforged_Bible_App1/app/src/main/java/com/reforged/app/data/remote/StrongsApi.kt` and `data/repository/StrongsRepository.kt` | Retrofit + OkHttp interceptor | `BuildConfig.STRONGS_API_KEY` from `local.properties` (untracked, but baked into the APK) |

Not affected: `reforged-mobile` (Expo) and `reforged-web` have no hits. `ReforgedAndroid` and `Reforged Android (Michael)` have no hits.

## 2. Endpoints

| # | Endpoint | Returns | iOS call site | Android call site |
|---|---|---|---|---|
| 1 | `GET /{book}/{ch}/{v}/{v}/KJV-Strongs/` | `kjv_json[]`: KJV English phrases with `data_nums` (Strong's numbers) | `fetchKJVStrongs` | `StrongsApi.getVerseInterlinear` |
| 2 | `GET /{book}/{ch}/{v}/{v}/ORIG/` | `orig_json[]`: Greek (TR) or Hebrew (WLC) phrases with `data_nums` | `fetchORIG` | `StrongsApi.getVerseOriginal` |
| 3 | `GET /{book}/{ch}/KJV-Strongs/` | Same as 1, whole chapter | `fetchKJVStrongsChapter` (used by `prefetchChapter`) | not used |
| 4 | `GET /{book}/{ch}/ORIG/` | Same as 2, whole chapter | `fetchORIGChapter` (used by `prefetchChapter` and Hebrew concordance) | not used |
| 5 | `GET /strongs-detail/{number}/` | One lexicon record, fields below | `getStrongsDetail` | `StrongsApi.getStrongsDetail` |

Book names are sent as lowercase with spaces removed (`1samuel`, `songofsolomon`) via `BibleBook.studyBibleAPIName`.

### Fields of `strongs-detail` actually consumed

| API field | Used for (iOS `WordLookupResult`) | UI element |
|---|---|---|
| `original_word` | `lexicalForm`, fallback `originalWord` | Lexical Form |
| `number` | `strongsNumber` | Strong's chip, concordance |
| `strong_definition` (HTML stripped) | `strongsDefinition` | Definition |
| `mounce_definition` | `mounceDefinition` | **"Mounce's Dictionary" card (not in the spec)** |
| `thayers_definition` (Greek) / `bdb_definition` (Hebrew), HTML stripped, truncated to 800 chars | `detailedDefinition` | "Thayer's Lexicon" / "Brown-Driver-Briggs" card |
| `transliteration` | `transliteration` | Lexical Form row |
| `phonetics` | `pronunciation` | Lexical Form row |
| `kjv_usage` | `kjvUsage` | KJV Translations |
| `linked_derivation` (HTML stripped) | `derivation` | Origin |
| `count` | `occurrenceCount` | "N occurrences", "Find all N uses" |
| `translation_counts[]` (`trans_link`/`trans`, `count`) | `translationCounts` | Usage Frequency, concordance KJV mode, Gemini prompt |

Fields in the response model but **not consumed**: `helps_word_studies`, `teach_jesus_def`, `lxx_only`, `places`, `id`.

## 3. Screens and features that depend on it

| Screen / feature | File | Calls |
|---|---|---|
| Word Study sheet (tap a KJV word) | `Views/Bible/BibleView.swift` ~2595-2631, `Views/Bible/VerseStudySheet.swift` 277-289 | `lookupWord` (endpoints 1, 2, 5) |
| Long-press a TR word | same | `lookupByStrongsNumber` (endpoint 5) |
| Long-press a WLC Hebrew word | `BibleView.swift` ~2620 | `lookupWLCWord` (endpoints 1/2 via verse cache, then 5). **Hebrew has no local Strong's tags, so this is fully API-dependent.** |
| Chapter prefetch on every English chapter load | `Views/Bible/ChapterScrollCoordinator.swift` ~313 | `prefetchChapter` (endpoints 3, 4). **Fires on every chapter shown, fire-and-forget.** |
| "Search G####" for Hebrew | `Views/Bible/ConcordanceSearchView.swift` 310 -> `searchHebrewOccurrencesByStrongs` | Endpoint 4 **once per OT chapter (up to 929 calls for one search)** |
| "Search G####" for Greek | same | Local. Already uses bundled TR tokens, no API call |
| AI Summary (Gemini) | `Services/GeminiService.swift` 285-302 | Reads `WordLookupResult` only; no direct API call |
| Home search Strong's by English word | `Views/Home/HomeSearchView.swift` 309-310 | Bundled dictionaries only |
| Dictionaries & Topics (Abbott-Smith etc.) | `Services/ReferenceWorkService.swift` | Already local |

Android equivalents are in `ui/AppStateViewModel.kt` lines 1232, 1262, 1290, 2195 (`searchDefinitions`, `lookupByNumber`, `lookupByOriginalWord`, `lookupWord`).

## 4. What already exists locally (iOS)

Bundled in `Reforged/Resources/`:

| File | Content | Has Strong's? |
|---|---|---|
| `trparsed.json` (3.9 MB) | TR, 7,958 verses, `word Gnnnn MORPH` triples. Unbound Bible "Stephens 1550 with Scrivener 1894 variants". **Unaccented only** (no `δοῦλοι`) | Yes, + Robinson morph |
| `wlc.json` (6.7 MB) | WLC, 23,213 verses, plain pointed Hebrew | **No** |
| `kjvpce.json` (6.3 MB) | KJV Pure Cambridge Edition, 31,102 verses, plain text | **No** |
| `StrongGreekDictionary.json` (1.9 MB) | 5,523 entries | n/a |
| `StrongHebrewDictionary.json` (3.1 MB) | 8,674 entries | n/a |
| `AbbottSmith.json` (1.7 MB) | 5,886 entries keyed by uppercase lemma | n/a |

Android bundles the two Strong's dictionaries, Abbott-Smith and `kjv_bundle.json`, but **not** the TR or WLC.

## 5. Findings the spec did not anticipate

1. **The RapidAPI key is exposed.** The iOS repo `github.com/bbriddick/Reforged` is **public** and the key has been committed since `c0c3d28`. The Mac repo has the same key. The key also ships in the iOS binary. Anyone can burn the ULTRA quota or run up overage. Rotating it in the RapidAPI dashboard is worth doing now, independent of this migration (see 6.1 for the catch).
2. **Mounce's Dictionary is shown today but is not in the spec's table.** The API's `mounce_definition` feeds its own card and the Gemini prompt. No source in spec section 5 provides it.
3. **Hebrew word study has no local path at all.** The WLC bundle has no Strong's numbers. The spec covers this with morphhb, but it is a larger piece of work than Greek, and the Hebrew concordance search is the single biggest quota consumer (up to 929 calls per search).
4. **Thayer's is shown today** under "Thayer's Lexicon" for Greek. Spec open question 14.1 stands. If no source is found, that card disappears for Greek unless Abbott-Smith fills the slot.
5. **Bundled Greek dictionary `pron` equals `xlit`.** For G1401 the bundled file has `pron: "doûlos"`, not `doo'-los`. The spec's golden test expects `doo'-los`, so the `strongs_entries` source must be chosen to satisfy that (or the golden value revised).
6. **The bundled TR is not byzantine.** Spec 6.3 asks which TR edition `byztxt/greektext-textus-receptus` is. The one already in the app is Stephens 1550 with Scrivener variants (Unbound Bible), which is also what CrossWire's KJV tagging targets, so it may be the better alignment source than a new download.
7. **The user-facing credit text is wrong.** `AboutSection.swift:151` and `:424` say BDB/Thayer's come "via the Bolls.life Bible API". They come from the RapidAPI service.
8. **Android also uses a different RapidAPI service**: IQ Bible (`iq-bible.p.rapidapi.com`) for KJV audio narration, in `BibleRepository.kt` 243-249 and `IqBibleApi.kt`. It is a separate subscription and is out of the Word Study scope, but it conflicts with the spec's definition of done ("No code path in either app calls RapidAPI"). iOS has no IQ Bible call.
9. **The spec says "both apps" but there are three** (iOS, Android, Mac), and Android lives in a different GitHub account (`admiralseth2007-ctrl/Reforged_Bible_App1`).
10. **Existing local caches hold API-shaped data.** iOS stores `strongs_verse_interlinear_cache` and `strongs_detail_cache` in UserDefaults; Android stores them in Room (`StrongsCache`). The cutover should clear them so stale API data is not served.

## 6. Decisions (Boaz, 2026-10-10)

- Leave the RapidAPI key as is for now. Rotation happens at cutover.
- Mac app is out of scope for this pass. Revisit later.
- `tools/study-db/` lives inside this repo.
- IQ Bible audio (Android) does not feed Word Study, so it is out of scope. iOS does not use it.
- Mounce is dropped. The Greek long-definition card becomes Abbott-Smith (relabelled honestly, not "Thayer's"). Thayer's stays on the roadmap via the CC0 Internet Archive scan.

## 7. Sourcing research: Thayer's and Mounce (2026-10-10)

### Mounce: no open source exists

- Mounce's Concise Greek-English Dictionary and the Complete Expository Dictionary are modern copyrighted works (William D. Mounce, Zondervan). Searches found no GitHub release, no CC BY-SA statement, and no CrossWire module. Distribution is commercial only (Accordance, Logos, Zondervan).
- The API was presumably licensed to serve it. Reforged cannot redistribute it by building its own database.
- Options: drop the Mounce card, or contact the rights holder for a license. Dropping is the only zero-cost path.

### Thayer's: public domain text exists, but no clean Strong's-keyed digital copy found

| Candidate | Result |
|---|---|
| CrossWire SWORD library | **No Thayer module.** `ModInfo?modName=Thayer` returns "No module found", and the raw `mods.d` listing has no file containing "thayer". Bible-Discovery's page claims a CrossWire Thayer's, but it is not in the current repo. |
| STEPBible-Data (TBESG/TBESH/TFLSJ) | No Thayer or Mounce. TBESG is a brief Greek lexicon built on corrected Abbott-Smith, CC BY 4.0, keyed to extended Strong's. |
| openscriptures | No Thayer's repo. |
| Internet Archive `thayer-lexicon` | 1889 scan, CC0 1.0. OCR text only (djvu.txt, PDF, EPUB). **No Strong's keying stated.** Needs OCR cleanup and entry parsing. |
| openbibles `LXX-Strongs-and-RMA-Codes` | A TheWord module "Thayer's Greek + Various Authors". Format is TheWord, license not stated, and it mixes other authors, so provenance is unclear. Not safe under the spec's "unclear license" rule. |
| Blue Letter Bible | Displays Thayer's but no download, no stated digitizer, no data license. Not usable. |

### Usable alternatives already inside the spec's licence bar

| Source | License | Strong's-keyed | Notes |
|---|---|---|---|
| Dodson Greek-English Lexicon (`dodson.conf`) | Public domain | Yes | Short glosses and definitions, good fit for the Thayer's slot. Not in the spec yet. |
| AbbottSmithStrongs (`abbottsmithstrongs.conf`) | Public domain | Yes | Already bundled in the app by lemma. This would add direct Strong's keying and fixes lemma-matching misses. |
| STEPBible TBESG | CC BY 4.0 | Yes (extended) | In spec already. |
| BDB (HebrewLexicon) | CC BY 4.0 markup, PD text | Yes | Replaces the Hebrew "Brown-Driver-Briggs" card. In spec already. |

### Recommendation

1. Drop the Mounce card.
2. For the Greek long-form slot, use Abbott-Smith (Strong's-keyed module) first and add Dodson as the short gloss. Relabel the card honestly rather than calling it Thayer's.
3. Keep Thayer's on the roadmap. The path is the CC0 Internet Archive scan, OCR cleanup, and entry-to-Strong's mapping. That is a separate cleanup task with real parsing risk, not something to bundle into this migration.

## 8. Pipeline status (2026-10-10)

Built and passing: `tools/study-db/` (see its README). Output is `out/reforged-study.sqlite`,
67.7 MB raw and 21.5 MB zipped, so it ships bundled. All 12 golden cases pass, including the
spec's Philippians 1:1 "servants" (G1401, 127 occurrences: servant 120, bond 6, bondman 1).

Live-API comparison (40 sampled words, 2026-10-10): lemma 100%, definition 100%, kjv_def 100%,
original word 100%, Strong's number 95%. Not scaled to 300 because the API plan is
**1,500 requests per month** and the comparison had already used about 190 of them
(1,311 remaining at 19:15 local on 2026-10-10, resets in about 30 days). The live app draws on
the same pool.

Open for Boaz:
- Confirm the CrossWire KJV license wording (conf says GPL, About text says any purpose).
- Credits screen additions: CrossWire, Robinson, Open Scriptures (Hebrew, HebrewLexicon),
  Abbott-Smith, and STEP Bible (TAGNT accents, CC BY 4.0). Also correct the "via Bolls.life" line.
- Next phase (not started): `StudyDataSource` protocol and `LocalStudyDataSource` in iOS and
  Android, wired behind `useLocalStudyData`, then clearing the old API-shaped caches.

## 9. iOS integration (2026-10-10)

Done and building: local data source behind `StrongsLexiconService`, bundled `reforged-study.rsdb`
(21.7 MB), launch warm-up, UI labels ("Abbott-Smith Lexicon", Aramaic chip, match badge) and the
Word Study credits. Verified with a standalone macOS harness that compiles the real Swift data
layer and runs the golden lookups (fresh install 0.9 s, lookups about 1 ms, Hebrew concordance for
H430 in 33 ms instead of up to 929 API calls). The simulator was not driven, so on-screen layout
of the sheet is compile-verified only.

Not done: Android (`Reforged_Bible_App1`), removing the API code and key (after cutover), the
minimum-version prompt for old app versions (spec 12.7), and the store release.
