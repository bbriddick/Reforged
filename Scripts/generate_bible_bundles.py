#!/usr/bin/env python3
"""
Reforged — Bible Bundle Generator
==================================
Fetches every chapter from each translation's API and writes one JSON file
per translation.  Upload the resulting files to a GitHub Release (or any CDN)
then update BibleBundleConfig.baseURL in BibleDownloadManager.swift.

Usage
-----
    python3 Scripts/generate_bible_bundles.py

Output
------
    bible_bundles/
        esv.json    (~8 MB)
        kjv.json    (~5 MB)
        csb.json    (~5 MB)
        nkjv.json   (~5 MB)
        nasb.json   (~5 MB)

Requirements
------------
    Python 3.8+  —  no third-party packages needed.

GitHub Release upload (one-time)
---------------------------------
    gh release create bible-bundles-v1 bible_bundles/*.json \\
        --title "Bible Bundles v1" --notes "Pre-built offline Bible bundles"

Then set BibleBundleConfig.baseURL to:
    https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/bible-bundles-v1
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

# ── API credentials (must match the app) ────────────────────────────────────
ESV_API_KEY      = "e966ccd42b0de2053ab75c913d3dd61586c098c2"
APIBIBLE_API_KEY = "UUTCGJADLTugGkW5aXiIt"

BIBLE_IDS: dict[str, str] = {
    "csb":  "a556c5305ee15c3f-01",
    "nkjv": "63097d2a0a2f7db3-01",
    "nasb": "b8ee27bcd1cae43a-01",
}

# ── 66 books with chapter counts (must match BibleData.books) ───────────────
BOOKS: list[tuple[str, int]] = [
    ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36),
    ("Deuteronomy", 34), ("Joshua", 24), ("Judges", 21), ("Ruth", 4),
    ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
    ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10),
    ("Nehemiah", 13), ("Esther", 10), ("Job", 42), ("Psalms", 150),
    ("Proverbs", 31), ("Ecclesiastes", 12), ("Song of Solomon", 8),
    ("Isaiah", 66), ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48),
    ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9),
    ("Obadiah", 1), ("Jonah", 4), ("Micah", 7), ("Nahum", 3),
    ("Habakkuk", 3), ("Zephaniah", 3), ("Haggai", 2), ("Zechariah", 14),
    ("Malachi", 4), ("Matthew", 28), ("Mark", 16), ("Luke", 24),
    ("John", 21), ("Acts", 28), ("Romans", 16), ("1 Corinthians", 16),
    ("2 Corinthians", 13), ("Galatians", 6), ("Ephesians", 6),
    ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5),
    ("2 Thessalonians", 3), ("1 Timothy", 6), ("2 Timothy", 4),
    ("Titus", 3), ("Philemon", 1), ("Hebrews", 13), ("James", 5),
    ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5), ("2 John", 1),
    ("3 John", 1), ("Jude", 1), ("Revelation", 22),
]

# 3-letter API.Bible book IDs (must match ApiBibleService.bookIdMap)
BOOK_IDS: dict[str, str] = {
    "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV",
    "Numbers": "NUM", "Deuteronomy": "DEU", "Joshua": "JOS",
    "Judges": "JDG", "Ruth": "RUT", "1 Samuel": "1SA",
    "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
    "1 Chronicles": "1CH", "2 Chronicles": "2CH", "Ezra": "EZR",
    "Nehemiah": "NEH", "Esther": "EST", "Job": "JOB",
    "Psalms": "PSA", "Proverbs": "PRO", "Ecclesiastes": "ECC",
    "Song of Solomon": "SNG", "Isaiah": "ISA", "Jeremiah": "JER",
    "Lamentations": "LAM", "Ezekiel": "EZK", "Daniel": "DAN",
    "Hosea": "HOS", "Joel": "JOL", "Amos": "AMO", "Obadiah": "OBA",
    "Jonah": "JON", "Micah": "MIC", "Nahum": "NAM", "Habakkuk": "HAB",
    "Zephaniah": "ZEP", "Haggai": "HAG", "Zechariah": "ZEC",
    "Malachi": "MAL", "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK",
    "John": "JHN", "Acts": "ACT", "Romans": "ROM",
    "1 Corinthians": "1CO", "2 Corinthians": "2CO", "Galatians": "GAL",
    "Ephesians": "EPH", "Philippians": "PHP", "Colossians": "COL",
    "1 Thessalonians": "1TH", "2 Thessalonians": "2TH",
    "1 Timothy": "1TI", "2 Timothy": "2TI", "Titus": "TIT",
    "Philemon": "PHM", "Hebrews": "HEB", "James": "JAS",
    "1 Peter": "1PE", "2 Peter": "2PE", "1 John": "1JN",
    "2 John": "2JN", "3 John": "3JN", "Jude": "JUD", "Revelation": "REV",
}

# KJV: bible-api.com uses run-together names for some books
KJV_BOOK_NAMES: dict[str, str] = {
    "1 Samuel": "1Samuel", "2 Samuel": "2Samuel",
    "1 Kings": "1Kings", "2 Kings": "2Kings",
    "1 Chronicles": "1Chronicles", "2 Chronicles": "2Chronicles",
    "Song of Solomon": "SongOfSolomon",
    "1 Corinthians": "1Corinthians", "2 Corinthians": "2Corinthians",
    "1 Thessalonians": "1Thessalonians", "2 Thessalonians": "2Thessalonians",
    "1 Timothy": "1Timothy", "2 Timothy": "2Timothy",
    "1 Peter": "1Peter", "2 Peter": "2Peter",
    "1 John": "1John", "2 John": "2John", "3 John": "3John",
}

OUTPUT_DIR    = "bible_bundles"
TOTAL_CHAPTERS = sum(c for _, c in BOOKS)

# Per-source delays (seconds between successful requests)
DELAY_ESV      = 0.75   # ESV allows ~5 000 req/day; ~0.75 s keeps us well under
DELAY_KJV      = 0.20   # bible-api.com is generous
DELAY_APIBIBLE = 0.40   # API.Bible free tier: 5 000 req/day

# Retry settings for 429 / 5xx
MAX_RETRIES  = 6
BACKOFF_BASE = 2.0      # seconds; doubles each retry (2 → 4 → 8 → 16 → 32 → 64)

# Where the script saves its progress so it can resume after a crash or 429 abort
PROGRESS_FILE = os.path.join(OUTPUT_DIR, ".progress.json")


# ── Helpers ──────────────────────────────────────────────────────────────────

def get(url: str, headers: dict[str, str] | None = None) -> Any:
    """HTTP GET with automatic retry + exponential back-off on 429 / 5xx."""
    for attempt in range(MAX_RETRIES + 1):
        req = urllib.request.Request(url, headers=headers or {})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                wait = BACKOFF_BASE ** attempt
                # Honour Retry-After header when present
                retry_after = e.headers.get("Retry-After")
                if retry_after:
                    try:
                        wait = max(wait, float(retry_after))
                    except ValueError:
                        pass
                if attempt < MAX_RETRIES:
                    print(f"\n  [HTTP {e.code}] Waiting {wait:.0f}s before retry {attempt + 1}/{MAX_RETRIES}…",
                          flush=True)
                    time.sleep(wait)
                    continue
            raise RuntimeError(f"HTTP {e.code} for {url}") from e
    raise RuntimeError(f"Exceeded {MAX_RETRIES} retries for {url}")


def clean(text: str) -> str:
    """Collapse whitespace and strip surrounding space."""
    return re.sub(r"\s+", " ", text).strip()


def parse_verse_marker_text(content: str, book: str, chapter: int) -> list[dict]:
    """
    Parse text containing [N] verse markers into a list of verse dicts.
    Matches the logic in ApiBibleService.parseChapterContent and ESV parsing.
    """
    text = content.strip()
    matches = list(re.finditer(r"\[(\d+)\]", text))
    if not matches:
        return [{"number": 1,
                 "text": clean(text),
                 "reference": f"{book} {chapter}:1"}]
    verses = []
    for i, m in enumerate(matches):
        num = int(m.group(1))
        start = m.end()
        end   = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        verse_text = clean(text[start:end])
        if verse_text:
            verses.append({"number": num, "text": verse_text,
                            "reference": f"{book} {chapter}:{num}"})
    return verses


def cache_key_esv_kjv(book: str, chapter: int) -> str:
    return f"{book}_{chapter}"


def cache_key_apibible(bible_id: str, book: str, chapter: int) -> str:
    return f"{bible_id}_{book}_{chapter}"


def show_progress(done: int, total: int, label: str) -> None:
    pct = done / total * 100
    bar = "#" * int(pct / 2)
    sys.stdout.write(f"\r  [{bar:<50}] {pct:5.1f}%  {done}/{total}  {label:<30}")
    sys.stdout.flush()


def _load_partial(filename: str) -> dict[str, Any]:
    """Load a partially-written bundle file so the run can resume."""
    path = os.path.join(OUTPUT_DIR, filename)
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            print(f"  ↩  Resuming from existing file ({len(data)} chapters already done)")
            return data
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def _save(bundle: dict, filename: str, *, final: bool = False) -> None:
    """Write bundle to disk.  Called after every book (incremental) and at the end."""
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(bundle, f, ensure_ascii=False, separators=(",", ":"))
    if final:
        size_mb = os.path.getsize(path) / 1_048_576
        print(f"\n  ✓  Saved {filename}  ({len(bundle)} chapters, {size_mb:.1f} MB)")


# ── ESV ──────────────────────────────────────────────────────────────────────

def generate_esv() -> None:
    import urllib.parse
    filename = "esv.json"
    print(f"\n── ESV ──────────────────────────────────────────────────────────")
    bundle = _load_partial(filename)
    total  = TOTAL_CHAPTERS
    done   = 0

    for book, chapter_count in BOOKS:
        for ch in range(1, chapter_count + 1):
            done += 1
            key = cache_key_esv_kjv(book, ch)
            if key in bundle:
                show_progress(done, total, f"{book} {ch} (cached)")
                continue

            ref = f"{book} {ch}"
            url = (
                "https://api.esv.org/v3/passage/text/"
                f"?q={urllib.parse.quote(ref)}"
                "&include-verse-numbers=true"
                "&include-footnotes=false"
                "&include-headings=false"
                "&include-short-copyright=false"
                "&include-passage-references=false"
                "&include-first-verse-numbers=true"
                "&indent-paragraphs=0"
                "&indent-poetry=false"
                "&indent-poetry-lines=0"
                "&indent-declares=0"
                "&indent-psalm-doxology=0"
                "&line-length=0"
            )
            data     = get(url, headers={"Authorization": f"Token {ESV_API_KEY}"})
            passages = data.get("passages", [])
            raw      = passages[0] if passages else ""
            canonical = data.get("canonical", ref)
            verses   = parse_verse_marker_text(raw, book, ch)

            bundle[key] = {
                "book":      book,
                "chapter":   ch,
                "passages":  raw,
                "canonical": canonical,
                "cachedAt":  0.0,
                "verses":    verses,
            }
            show_progress(done, total, f"{book} {ch}")
            time.sleep(DELAY_ESV)

        # Flush to disk after every book so progress isn't lost on interrupt
        _save(bundle, filename)

    _save(bundle, filename, final=True)


# ── KJV ──────────────────────────────────────────────────────────────────────

def generate_kjv() -> None:
    filename = "kjv.json"
    print(f"\n\n── KJV ──────────────────────────────────────────────────────────")
    bundle = _load_partial(filename)
    total  = TOTAL_CHAPTERS
    done   = 0

    for book, chapter_count in BOOKS:
        api_book = KJV_BOOK_NAMES.get(book, book).replace(" ", "+")
        for ch in range(1, chapter_count + 1):
            done += 1
            key = cache_key_esv_kjv(book, ch)
            if key in bundle:
                show_progress(done, total, f"{book} {ch} (cached)")
                continue

            url  = f"https://bible-api.com/{api_book}+{ch}?translation=kjv"
            data = get(url)
            canonical  = f"{book} {ch}"
            raw_text   = data.get("text", "")
            kjv_verses = data.get("verses", [])
            verses = [
                {
                    "number":    v["verse"],
                    "text":      clean(v["text"]),
                    "reference": f"{book} {ch}:{v['verse']}",
                }
                for v in sorted(kjv_verses, key=lambda x: x["verse"])
            ]

            bundle[key] = {
                "book":      book,
                "chapter":   ch,
                "passages":  raw_text,
                "canonical": canonical,
                "cachedAt":  0.0,
                "verses":    verses,
            }
            show_progress(done, total, f"{book} {ch}")
            time.sleep(DELAY_KJV)

        _save(bundle, filename)

    _save(bundle, filename, final=True)


# ── API.Bible (CSB / NKJV / NASB) ────────────────────────────────────────────

def generate_apibible(translation: str) -> None:
    bible_id = BIBLE_IDS[translation]
    filename = f"{translation}.json"
    print(f"\n\n── {translation.upper()} ───────────────────────────────────────────────")
    bundle = _load_partial(filename)
    total  = TOTAL_CHAPTERS
    done   = 0

    headers = {
        "api-key": APIBIBLE_API_KEY,
        "Accept":  "application/json",
    }

    for book, chapter_count in BOOKS:
        book_code = BOOK_IDS.get(book)
        if not book_code:
            print(f"\n  [WARN] No book ID for '{book}' — skipping")
            done += chapter_count
            continue

        for ch in range(1, chapter_count + 1):
            done += 1
            key = cache_key_apibible(bible_id, book, ch)
            if key in bundle:
                show_progress(done, total, f"{book} {ch} (cached)")
                continue

            chapter_id = f"{book_code}.{ch}"
            url = (
                f"https://rest.api.bible/v1/bibles/{bible_id}/chapters/{chapter_id}"
                "?content-type=text"
                "&include-verse-numbers=true"
                "&include-titles=false"
                "&include-chapter-numbers=false"
                "&include-verse-spans=false"
            )
            data      = get(url, headers=headers)
            content   = data["data"]["content"]
            canonical = f"{book} {ch}"
            verses    = parse_verse_marker_text(content, book, ch)

            bundle[key] = {
                "book":          book,
                "chapter":       ch,
                "translationId": bible_id,
                "canonical":     canonical,
                "cachedAt":      0.0,
                "verses":        verses,
            }
            show_progress(done, total, f"{book} {ch}")
            time.sleep(DELAY_APIBIBLE)

        _save(bundle, filename)

    _save(bundle, filename, final=True)


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Reforged Bible Bundle Generator")
    print(f"Output → {os.path.abspath(OUTPUT_DIR)}/")
    print(f"Total chapters per translation: {TOTAL_CHAPTERS}")

    translations_arg = sys.argv[1:] or ["esv", "kjv", "csb", "nkjv", "nasb"]

    for t in translations_arg:
        t = t.lower()
        if t == "esv":
            generate_esv()
        elif t == "kjv":
            generate_kjv()
        elif t in BIBLE_IDS:
            generate_apibible(t)
        else:
            print(f"Unknown translation '{t}'. Valid: esv kjv csb nkjv nasb")

    print("\n\nDone!  Next steps:")
    print("  1. gh release create bible-bundles-v1 bible_bundles/*.json \\")
    print("         --title 'Bible Bundles v1' --notes 'Pre-built offline Bible bundles'")
    print("  2. Update BibleBundleConfig.baseURL in BibleDownloadManager.swift")


if __name__ == "__main__":
    main()
