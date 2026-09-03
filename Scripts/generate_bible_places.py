#!/usr/bin/env python3
"""Generate Reforged/Resources/BiblePlaces.json from openbible.info's Bible Geocoding data.

Source: https://raw.githubusercontent.com/openbibleinfo/Bible-Geocoding-Data/master/data/ancient.jsonl
(CC BY). One JSON object per line, one per ancient place. We keep the fields the app needs:
a display name, a lat/long, and the verses that mention the place (normalized to the app's
"Book C:V" convention so they match BibleData.books and CrossReferences.json).

Usage:
  python3 Scripts/generate_bible_places.py [path/to/ancient.jsonl]

Without an argument, downloads the current dataset. Output schema:
  {"places":[{"id":"abana","name":"Abana","lat":33.51,"lon":36.31,
              "verses":["2 Kings 5:12"]}, ...],
   "versePlaces":{"2 Kings 5:12":["abana", ...]}}
"""

import json
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

DATA_URL = ("https://raw.githubusercontent.com/openbibleinfo/"
            "Bible-Geocoding-Data/master/data/ancient.jsonl")
OUTPUT = Path(__file__).resolve().parent.parent / "Reforged" / "Resources" / "BiblePlaces.json"

MAX_VERSES_PER_PLACE = 40

# OSIS book code -> BibleData.books name (Reforged/Models/BibleModels.swift). Order matches
# the canonical 66-book sequence.
OSIS_TO_NAME = dict(zip(
    ["Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam",
     "1Kgs", "2Kgs", "1Chr", "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov",
     "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel", "Amos",
     "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal", "Matt",
     "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil",
     "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas",
     "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev"],
    ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges",
     "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles",
     "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
     "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
     "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
     "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew",
     "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
     "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
     "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
     "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude",
     "Revelation"],
))

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def osis_to_reference(osis):
    """'2Kgs.5.12' -> '2 Kings 5:12', or None if unparseable/chapter-only."""
    osis = osis.split("-")[0]  # drop the tail of any range
    parts = osis.split(".")
    if len(parts) != 3:
        return None
    book_code, chapter, verse = parts
    name = OSIS_TO_NAME.get(book_code)
    if name is None or not chapter.isdigit() or not verse.isdigit():
        return None
    return f"{name} {int(chapter)}:{int(verse)}"


def best_lonlat(record):
    """Return (lat, lon) from the highest-confidence identification, or None."""
    for identification in record.get("identifications", []):
        for resolution in identification.get("resolutions", []):
            lonlat = resolution.get("lonlat")
            if not lonlat:
                continue
            try:
                lon, lat = (float(x) for x in lonlat.split(","))
            except ValueError:
                continue
            return round(lat, 5), round(lon, 5)
    return None


def slug(name, taken):
    base = _SLUG_RE.sub("-", name.lower()).strip("-") or "place"
    candidate, n = base, 2
    while candidate in taken:
        candidate, n = f"{base}-{n}", n + 1
    taken.add(candidate)
    return candidate


def main():
    if len(sys.argv) > 1:
        raw = Path(sys.argv[1]).read_text(encoding="utf-8")
    else:
        print(f"Downloading {DATA_URL} ...")
        with urllib.request.urlopen(DATA_URL) as resp:
            raw = resp.read().decode("utf-8")

    places = []
    verse_places = defaultdict(list)
    taken_slugs = set()
    skipped = 0

    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        record = json.loads(line)
        name = record.get("friendly_id")
        coords = best_lonlat(record)
        if not name or coords is None:
            skipped += 1
            continue
        lat, lon = coords

        references = []
        for verse in record.get("verses", []):
            ref = osis_to_reference(verse.get("osis", ""))
            if ref and ref not in references:
                references.append(ref)
            if len(references) >= MAX_VERSES_PER_PLACE:
                break

        place_id = slug(name, taken_slugs)
        places.append({"id": place_id, "name": name, "lat": lat, "lon": lon,
                       "verses": references})
        for ref in references:
            verse_places[ref].append(place_id)

    OUTPUT.write_text(
        json.dumps({"places": places, "versePlaces": verse_places},
                   ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    size_mb = OUTPUT.stat().st_size / 1_048_576
    print(f"Wrote {OUTPUT} ({size_mb:.2f} MB): {len(places)} places, "
          f"{len(verse_places)} indexed verses, {skipped} skipped (no name/coords)")


if __name__ == "__main__":
    main()
