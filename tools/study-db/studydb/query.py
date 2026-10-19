"""Reference implementation of the read API the apps need (spec section 9).

The Swift and Kotlin `LocalStudyDataSource` implementations mirror these queries; the golden
tests run against this module so the contract stays executable.
"""
import sqlite3
from pathlib import Path


def connect(path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(path)}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    return con


def verse_id(book_id: int, chapter: int, verse: int) -> int:
    return book_id * 1_000_000 + chapter * 1_000 + verse


def find_position(con, vid: int, word: str, occurrence: int = 0):
    """Locate the token a user tapped. `word` is matched case/punctuation-insensitively against
    the words of each token; `occurrence` disambiguates repeats within the verse."""
    import re
    target = re.sub(r"[^\w'’-]", "", word.lower())
    hits = []
    for r in con.execute("SELECT DISTINCT position, word FROM kjv_tokens WHERE verse_id=? ORDER BY position", (vid,)):
        ws = [re.sub(r"[^\w'’-]", "", w.lower()) for w in r["word"].split()]
        if target in ws:
            hits.append(r["position"])
    return hits[occurrence] if occurrence < len(hits) else (hits[-1] if hits else None)


# Function-word tags that ride along with a content word in the same phrase: the Greek article
# ("the Word" carries G3588 + G3056) and the Hebrew object marker. Never the one the reader meant.
_FUNCTION_TAGS = ("G3588", "H853")


def strongs_for_token(con, vid: int, position: int) -> list[str]:
    """Every Strong's number on a token, best candidate first."""
    rows = con.execute("""
        SELECT strongs, match_quality FROM kjv_tokens
        WHERE verse_id=? AND position=? AND strongs <> ''""", (vid, position)).fetchall()
    rank = {"exact": 0, "strongs_only": 1, "none": 2, None: 2}
    rows.sort(key=lambda r: (r["strongs"] in _FUNCTION_TAGS, rank[r["match_quality"]], r["strongs"]))
    return [r["strongs"] for r in rows]


def _pick_strongs(con, vid, position):
    cands = strongs_for_token(con, vid, position)
    return cands[0] if cands else None


def word_study(con, vid: int, position: int, strongs: str | None = None) -> dict | None:
    strongs = strongs or _pick_strongs(con, vid, position)
    if not strongs:
        return None
    tok = con.execute("SELECT word, morph FROM kjv_tokens WHERE verse_id=? AND position=? AND strongs=?",
                      (vid, position, strongs)).fetchone()
    entry = con.execute("SELECT * FROM strongs_entries WHERE strongs=?", (strongs,)).fetchone()
    al = con.execute("SELECT * FROM alignments WHERE verse_id=? AND kjv_position=? AND strongs=?",
                     (vid, position, strongs)).fetchone()
    orig = None
    if al and al["orig_position"] is not None:
        orig = con.execute("""SELECT o.*, m.expansion FROM original_tokens o
                              LEFT JOIN morph_codes m ON m.code=o.morph
                              WHERE o.verse_id=? AND o.edition=? AND o.position=?""",
                           (vid, al["orig_edition"], al["orig_position"])).fetchone()
    usage = [(r["english_word"], r["count"]) for r in con.execute(
        "SELECT english_word, count FROM strongs_usage WHERE strongs=? ORDER BY count DESC, english_word", (strongs,))]
    greek = strongs.startswith("G")
    long_source = "abbott-smith" if greek else "bdb"
    long_entries = con.execute("SELECT source, headword, body_text, body_html FROM lexicon_entries "
                               "WHERE strongs=? AND source=?", (strongs, long_source)).fetchall()
    return {
        "strongs": strongs,
        "language": ("Greek" if greek else "Hebrew") if not entry or entry["language"] != "arc" else "Aramaic",
        "tapped_word": tok["word"] if tok else None,
        "kjv_morph": tok["morph"] if tok else None,
        "match_quality": al["match_quality"] if al else None,
        "original": None if not orig else {
            "edition": orig["edition"], "surface": orig["surface"], "accented": orig["surface_accented"],
            "morph": orig["morph"], "morph_expansion": orig["expansion"]},
        "entry": None if not entry else dict(entry),
        "long_entries": [dict(r) for r in long_entries],
        "usage": usage,
        "occurrences": entry["occurrences"] if entry else sum(c for _, c in usage),
    }


def occurrences(con, strongs: str, limit: int = 50, offset: int = 0) -> list[int]:
    return [r[0] for r in con.execute(
        "SELECT verse_id FROM strongs_occurrences WHERE strongs=? ORDER BY verse_id LIMIT ? OFFSET ?",
        (strongs, limit, offset))]
