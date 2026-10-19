# study-db

Builds `out/reforged-study.sqlite`, the offline replacement for the Complete Study Bible API
(spec: `reforged-study-data-spec.md`). Python 3.11+, standard library only (no lxml needed).
`mod2imp` from `brew install sword` is required to read the CrossWire KJV module.

```bash
python3 -I tools/study-db/fetch.py      # download pinned sources into sources/ (git-ignored)
python3 -I tools/study-db/build.py      # build, validate, write out/manifest.json
python3 -I tools/study-db/pack.py --install   # pack to a 21.7 MB resource in Reforged/Resources/
python3 -I tools/study-db/snapshot.py   # optional: compare against the live API (uses quota, see below)
```

The build fails if any check fails: verse count 31,102, every Strong's and morph code resolves,
no empty lexicon bodies, NT alignment at least 97%, and the 12 golden cases in
`studydb/golden.py` (Philippians 1:1 "servants" is the spec's golden case).

## Sources (all pinned in `sources.json`, hashes in `sources.lock.json`)

| Data | Source | License |
|---|---|---|
| KJV with Strong's, Robinson morph, TR lemma and word index | CrossWire KJV 3.1 (SWORD) | See "License to confirm" |
| Greek TR with Strong's and Robinson parsing | byztxt/greektext-textus-receptus | Public domain (repo README) |
| Accented Greek forms | STEPBible TAGNT | CC BY 4.0 |
| Strong's Greek | morphgnt/strongs-dictionary-xml | Public domain |
| Strong's Hebrew + BDB | openscriptures/HebrewLexicon | Text PD, markup CC BY 4.0 |
| Hebrew OT with lemma and morph + VerseMap | openscriptures/morphhb | CC BY 4.0 |
| Abbott-Smith | translatable-exegetical-tools/Abbott-Smith | Public domain |

## How a tapped word resolves

`kjv_tokens` has one row per (token, Strong's number). Every English word belongs to exactly one
token, tagged or not. The alignment to the original word sits on the same row
(`orig_edition`, `orig_position`, `match_quality`); `alignments` is a view over it.

- NT: the KJV module's `src` index plus its `lemma.TR` string pin the Greek word. If the module's
  TR snapshot differs from the byztxt TR (0.4% of tagged words), fall back to Strong's number,
  then Robinson morph, then word order.
- OT: Strong's number, then nth occurrence. Hebrew verses are remapped to KJV numbering with
  morphhb's `VerseMap.xml`; Psalm title verses fold into KJV verse 1 (where the KJV module
  carries the title). `original_tokens.src_ref` records the WLC reference when they differ.

`studydb/query.py` is the executable contract for the Swift and Kotlin data sources
(`find_position`, `strongs_for_token`, `word_study`, `occurrences`).

## Deviations from the spec schema

| Spec | Built | Why |
|---|---|---|
| separate `alignments` table | columns on `kjv_tokens` + `alignments` view | removes 20 MB of duplicated keys; the view keeps the interface |
| `kjv_tokens.strongs` NULL when untagged | `''` | lets the table be `WITHOUT ROWID` |
| `idx_kjv_tokens_strongs`, `idx_orig_strongs` | omitted | `strongs_occurrences` already answers "where is G1401" |
| TBESG/TBESH lexicons | not stored | derived from Abbott-Smith and BDB, which are stored in full (10 MB saved) |
| Hebrew `surface_accented` | NULL | cantillation is not displayed; saves 9 MB. `surface` is pointed Hebrew |
| `expansion` joined with `, ` in golden text | joined with ` · ` | matches the existing app (`OriginalLanguageService.expandMorph`) |
| NT surface "as printed" with accents from byztxt | accents from TAGNT | byztxt TR files are unaccented BETA code |

Added columns: `kjv_verses.title`, `kjv_tokens.word_index/word_count/added/in_title`,
`original_tokens.alt_strongs/src_ref`.

## Size and speed

68.5 MB raw, 21.7 MB packed (spec threshold 60 MB zipped, so it is bundled). Word study median
0.2 ms, occurrences page 0.1 ms on this machine.

## Coverage (see `out/manifest.json`)

| | exact | strongs_only | none |
|---|---|---|---|
| NT | 99.86% | 0.08% | 0.06% |
| OT | 81.12% | 18.23% | 0.65% |

Greek accented form present for 97.03% of TR words. Abbott-Smith covers 96% of Greek entries,
BDB 100% of Hebrew.

## Known data quirks

- A few KJV phrases span a punctuation boundary because the module tagged them that way, e.g.
  Psalm 3:1 `me! many` is one tagged token.
- 3% of TR words have no accented form (verse-division and spelling-variant differences between
  TR editions). `surface` is always present.
- Usage counts follow the lexicon's `kjv_def` headwords and will not match the API for words the
  API groups idiosyncratically (it lists G4771 "thou" 178 times; the text has ~2,900).

## License to confirm

The CrossWire KJV `.conf` says `DistributionLicense=GPL`, while its About text grants "a general
public license to use this text for any purpose". The base KJV is public domain; the question is
the CrossWire Strong's/morphology tagging. Worth a one-line confirmation with CrossWire
(modules@crosswire.org) before shipping, since GPL data inside an app is a different obligation.

## Live-API comparison (`snapshot.py`)

The API plan is **1,500 requests per month** (`X-RateLimit-All-Endpoints-Limit`). A 40-word run
costs about 120 requests and the live app shares that pool, so run it deliberately.
Snapshots are git-ignored because they contain third-party lexicon text.

## App integration (iOS)

`Reforged/Services/StudyDatabase.swift` expands `reforged-study.rsdb` into Application Support on
first launch or when the data changes (SHA-256 verified, excluded from backup, 0.9 s), then opens
it read-only. `StudyDataSource.swift` holds the `StudyDataSource` protocol and
`LocalStudyDataSource`, which fills the existing `WordLookupResult`, so the Word Study UI and
every call site are unchanged. `StrongsLexiconService` tries the local source first and gates
`fetchFromAPI`, the single choke point for network calls, so the API is never reached while the
database is open. The `useLocalStudyData` UserDefaults key (default on) switches back to the API
path until it is deleted after cutover.

After a data change: `build.py`, then `pack.py --install`, then bump `DATA_VERSION` in `build.py`.
