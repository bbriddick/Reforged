#!/usr/bin/env python3
"""Spec 10.2: compare the local database to the live Complete Study Bible API.

    python3 -I tools/study-db/snapshot.py --n 40        # small first batch
    python3 -I tools/study-db/snapshot.py --n 300 --resume

The API key is read from the iOS source at runtime (or STRONGS_API_KEY) and is never written
to disk. Responses are cached in snapshots/ (git-ignored: they contain third-party text), so a
re-run only fetches what is missing. Prints a report and writes snapshots/report.json.
"""
import argparse
import json
import os
import random
import re
import sqlite3
import sys
import time
import unicodedata
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from studydb import books, query  # noqa: E402

SNAP = HERE / "snapshots"
HOST = "complete-study-bible.p.rapidapi.com"
SWIFT = HERE.parent.parent / "Reforged" / "Services" / "StrongsLexiconService.swift"
STOP = {"the", "a", "an", "of", "and", "to", "in", "is", "that", "he", "his", "i", "it", "for", "with"}

_remaining = None


def api_key() -> str:
    k = os.environ.get("STRONGS_API_KEY")
    if k:
        return k
    m = re.search(r'static let apiKey = "([^"]+)"', SWIFT.read_text())
    if not m:
        sys.exit("no API key found")
    return m.group(1)


def fetch(path: str, key: str):
    global _remaining
    cache = SNAP / (re.sub(r"[^A-Za-z0-9_.-]", "_", path) + ".json")
    if cache.exists():
        return json.loads(cache.read_text())
    req = urllib.request.Request(f"https://{HOST}/{path}", headers={"x-rapidapi-key": key, "x-rapidapi-host": HOST})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                _remaining = r.headers.get("x-ratelimit-requests-remaining", _remaining)
                data = json.loads(r.read())
                cache.write_text(json.dumps(data, ensure_ascii=False))
                time.sleep(0.15)
                return data
        except Exception as e:  # noqa: BLE001
            if "429" in str(e):
                time.sleep(3 * (attempt + 1))
            else:
                return None
    return None


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(s):
    """Whitespace/punctuation/accents/case folded, for 'acceptable difference' comparison."""
    s = unicodedata.normalize("NFD", nfc(s))
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"<[^>]+>", " ", s).lower().replace("ς", "σ")
    s = re.sub(r"[^\w]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def nospace(s):
    return re.sub(r"\s+", "", fold(s))


def api_markers(s):
    """The API rewrites Strong's '×'/'+' as '[idiom]'/'[phrase]' and inlines 'G1234 (lemma)'."""
    s = (s or "").replace("[idiom]", "×").replace("[phrase]", "+")
    return re.sub(r"\b[GH]\d+\s*\(([^)]*)\)", r"\1", s)


def strip_html(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"')):
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s).strip()


def sample(con, n, seed):
    rnd = random.Random(seed)
    rows = con.execute("""
        SELECT t.verse_id, t.position, t.strongs, t.word, v.book_id FROM kjv_tokens t
        JOIN kjv_verses v ON v.verse_id=t.verse_id
        WHERE t.strongs <> '' AND t.strongs NOT IN ('G3588','H853') AND t.match_quality IN ('exact','strongs_only')
          AND t.word <> '' AND t.added = 0 AND t.in_title = 0""").fetchall()
    # weight NT x2 and the best-known books x3 (Gen, Ps, Isa, Matt, John, Rom, Heb, Rev)
    popular = {1, 19, 23, 40, 43, 45, 58, 66}
    weighted = [(r, (2 if r["book_id"] >= 40 else 1) * (3 if r["book_id"] in popular else 1)) for r in rows]
    picks, seen = [], set()
    pool = [r for r, w in weighted for _ in range(w)]
    while len(picks) < n and pool:
        r = rnd.choice(pool)
        k = (r["verse_id"], r["strongs"])
        if k not in seen:
            seen.add(k)
            picks.append(r)
    return picks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=20261010)
    a = ap.parse_args()
    SNAP.mkdir(exist_ok=True)
    key = api_key()
    con = query.connect(HERE / "out" / "reforged-study.sqlite")
    picks = sample(con, a.n, a.seed)
    stats = {"samples": 0, "api_missing": 0}
    fields = ["strongs", "lemma", "definition", "kjv_def", "count", "usage", "derivation", "original"]
    res = {f: {"exact": 0, "acceptable": 0, "mismatch": 0, "api_empty": 0} for f in fields}
    mismatches = []

    def record(field, ours, theirs, ctx, soft=None):
        r = res[field]
        if theirs in (None, "", 0, []):
            r["api_empty"] += 1
            return
        if ours == theirs:
            r["exact"] += 1
        elif fold(str(ours)) == fold(str(theirs)) or (soft and soft(ours, theirs)):
            r["acceptable"] += 1
        else:
            r["mismatch"] += 1
            mismatches.append({"field": field, "ours": ours, "api": theirs, **ctx})

    for r in picks:
        vid, pos, s = r["verse_id"], r["position"], r["strongs"]
        b, ch, vs = vid // 1_000_000, (vid // 1000) % 1000, vid % 1000
        book = books.BY_ID[b]["name"].lower().replace(" ", "")
        ctx = {"verse": f"{books.BY_ID[b]['name']} {ch}:{vs}", "word": r["word"], "strongs": s}
        kj = fetch(f"{book}/{ch}/{vs}/{vs}/KJV-Strongs/", key)
        orig = fetch(f"{book}/{ch}/{vs}/{vs}/ORIG/", key)
        det = fetch(f"strongs-detail/{s}/", key)
        if not (kj and orig and det):
            stats["api_missing"] += 1
            continue
        stats["samples"] += 1
        d = det[0]
        ws = query.word_study(con, vid, pos, s)
        e = ws["entry"] or {}
        # what the API says the tapped phrase's Strong's numbers are
        api_nums = [n for ph in kj[0]["kjv_json"] if ph["phrase"].strip().lower().strip(".,;:!? ") == r["word"].lower().strip(".,;:!? ")
                    for n in (ph.get("data_nums") or [])]
        # a token can carry several Strong's numbers; the API may list the phrase under any of them
        all_api = [n for ph in kj[0]["kjv_json"] for n in (ph.get("data_nums") or [])]
        record("strongs", s, s if (not api_nums or s in api_nums or s in all_api) else api_nums[0], ctx)
        record("lemma", e.get("lemma"), d["original_word"], ctx)
        record("definition", api_markers(e.get("definition")), api_markers(strip_html(d["strong_definition"])), ctx,
               soft=lambda o, t: nospace(t).startswith(nospace(o)[:40]) or nospace(o).startswith(nospace(t)[:40]))
        record("kjv_def", api_markers(e.get("kjv_def")), api_markers(strip_html(d["kjv_usage"])).rstrip("."), ctx,
               soft=lambda o, t: nospace(o) == nospace(t))
        record("count", ws["occurrences"], d.get("count"), ctx, soft=lambda o, t: abs(o - t) <= max(2, int(t * 0.10)))
        api_use = {fold(x.get("trans_link") or x.get("trans") or ""): int(x["count"]) for x in (d.get("translation_counts") or [])}
        our_use = {fold(w): c for w, c in ws["usage"]}
        top = sorted(((w, c) for w, c in api_use.items() if w and not w.startswith(("miscellaneous", "not tr"))),
                     key=lambda kv: -kv[1])[:3]
        record("usage", [(w, our_use.get(w, 0)) for w, _ in top], top, ctx,
               soft=lambda o, t: all(abs(c1 - c2) <= max(2, int(c2 * 0.15)) for (_, c1), (_, c2) in zip(o, t)))
        # the API drops the space after 'from' (the bug the spec fixes), so compare without spaces
        record("derivation", e.get("derivation"), strip_html(d["linked_derivation"]).rstrip(";"), ctx,
               soft=lambda o, t: nospace(o) == nospace(t) or nospace(o) in nospace(t) or nospace(t) in nospace(o))
        # original-language word as used in the verse
        # the API maps a Strong's number to its FIRST occurrence in the verse; ours follows the
        # KJV word, so accept any occurrence the API lists for the number
        api_forms = [ph["phrase"].strip() for ph in orig[0]["orig_json"] if s in (ph.get("data_nums") or [])]
        ours_orig = (ws["original"] or {}).get("accented") or (ws["original"] or {}).get("surface") or ""
        first = api_forms[0] if api_forms else ""
        any_hit = next((f for f in api_forms if fold(f) == fold(ours_orig) or nospace(f) == nospace(ours_orig)), None)
        record("original", ours_orig, any_hit or first, ctx, soft=lambda o, t: fold(o) == fold(t))
    print(f"samples compared: {stats['samples']} (api failures: {stats['api_missing']}); API requests remaining header: {_remaining}")
    for f, c in res.items():
        tot = sum(c.values()) - c["api_empty"]
        good = c["exact"] + c["acceptable"]
        print(f"  {f:11s} exact {c['exact']:4d}  acceptable {c['acceptable']:4d}  MISMATCH {c['mismatch']:4d}  api-empty {c['api_empty']:4d}"
              f"   match {100 * good / tot:.1f}%" if tot else f"  {f:11s} (no data)")
    (SNAP / "report.json").write_text(json.dumps({"stats": stats, "fields": res, "mismatches": mismatches}, ensure_ascii=False, indent=1))
    print(f"{len(mismatches)} mismatches written to snapshots/report.json")


if __name__ == "__main__":
    main()
