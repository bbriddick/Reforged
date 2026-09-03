#!/usr/bin/env python3
"""Generate Reforged/Resources/TopicalVerses.json from openbible.info's Topical Bible data.

Source: https://a.openbible.info/data/topic-votes.txt (CC BY, updated weekly).
Format: TSV `Topic \t Start Verse ID \t End Verse ID \t Votes`, verse ID = bbcccvvv
(book 01=Genesis .. 66=Revelation, 3-digit chapter, 3-digit verse). End ID empty
for single verses. Rows per topic are pre-sorted by descending votes.

Usage:
  python3 Scripts/generate_topical_verses.py [path/to/topic-votes.txt]

Without an argument, downloads the current dataset. Output schema:
  {"topics": {topic: [{"reference": "Exodus 20:1-26", "votes": 302}, ...]},
   "verseTopics": {"Exodus 20:3": ["10 commandments", ...], ...}}
"""

import json
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

DATA_URL = "https://a.openbible.info/data/topic-votes.txt"
OUTPUT = Path(__file__).resolve().parent.parent / "Reforged" / "Resources" / "TopicalVerses.json"

MAX_VERSES_PER_TOPIC = 20
MIN_VOTES = 3
MIN_ENTRIES_PER_TOPIC = 3
REVERSE_RANGE_CAP = 5   # expand at most this many verses of a range into verseTopics
MAX_TOPICS_PER_VERSE = 8

# Must match BibleData.books names in Reforged/Models/BibleModels.swift exactly
# (verified against CrossReferences.json key conventions, e.g. "Psalms 1:1").
BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
    "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts",
    "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
    "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
]


def decode(verse_id):
    """bbcccvvv -> (book_index, chapter, verse) or None if malformed."""
    if len(verse_id) != 8 or not verse_id.isdigit():
        return None
    book = int(verse_id[:2])
    chapter = int(verse_id[2:5])
    verse = int(verse_id[5:])
    if not (1 <= book <= 66) or chapter < 1 or verse < 1:
        return None
    return book, chapter, verse


def main():
    if len(sys.argv) > 1:
        raw = Path(sys.argv[1]).read_text(encoding="utf-8")
    else:
        print(f"Downloading {DATA_URL} ...")
        with urllib.request.urlopen(DATA_URL) as resp:
            raw = resp.read().decode("utf-8")

    topics = defaultdict(list)
    skipped = 0
    for line in raw.splitlines():
        if not line or line.startswith("Topic\t"):
            continue
        fields = line.split("\t")
        if len(fields) < 4:
            skipped += 1
            continue
        topic, start_id, end_id, votes = (f.strip() for f in fields[:4])
        # The header row carries a trailing comment column; data rows may too.
        votes = votes.split("#")[0].strip()
        start = decode(start_id)
        if topic == "" or start is None or not votes.isdigit():
            skipped += 1
            continue
        votes = int(votes)
        if votes < MIN_VOTES or len(topics[topic]) >= MAX_VERSES_PER_TOPIC:
            continue

        book, chapter, verse = start
        end = decode(end_id) if end_id else None
        if end and end[0] == book and end[1] == chapter and end[2] > verse:
            reference = f"{BOOKS[book - 1]} {chapter}:{verse}-{end[2]}"
            last_verse = end[2]
        else:
            # single verse, or a (rare) cross-chapter range truncated to its start
            reference = f"{BOOKS[book - 1]} {chapter}:{verse}"
            last_verse = verse
        topics[topic].append(
            {"reference": reference, "votes": votes,
             "_span": (book, chapter, verse, last_verse)}
        )

    topics = {t: entries for t, entries in topics.items()
              if len(entries) >= MIN_ENTRIES_PER_TOPIC}

    # Reverse index: verse reference -> topics, ranked by that entry's votes.
    verse_votes = defaultdict(dict)   # ref -> {topic: best votes}
    for topic, entries in topics.items():
        for entry in entries:
            book, chapter, v1, v2 = entry["_span"]
            for v in range(v1, min(v2, v1 + REVERSE_RANGE_CAP - 1) + 1):
                ref = f"{BOOKS[book - 1]} {chapter}:{v}"
                prev = verse_votes[ref].get(topic, 0)
                verse_votes[ref][topic] = max(prev, entry["votes"])

    verse_topics = {
        ref: [t for t, _ in sorted(by_topic.items(), key=lambda kv: -kv[1])
              ][:MAX_TOPICS_PER_VERSE]
        for ref, by_topic in verse_votes.items()
    }

    for entries in topics.values():
        for entry in entries:
            del entry["_span"]

    OUTPUT.write_text(
        json.dumps({"topics": topics, "verseTopics": verse_topics},
                   ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    size_mb = OUTPUT.stat().st_size / 1_048_576
    print(f"Wrote {OUTPUT} ({size_mb:.1f} MB): {len(topics)} topics, "
          f"{len(verse_topics)} indexed verses, {skipped} rows skipped")


if __name__ == "__main__":
    main()
