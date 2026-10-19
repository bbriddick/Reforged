#!/usr/bin/env python3
"""Build out/reforged-study.sqlite and out/manifest.json (spec section 6).

    python3 -I tools/study-db/fetch.py     # once, or when sources.json changes
    python3 -I tools/study-db/build.py
"""
import collections
import hashlib
import json
import sys
import time
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from studydb import (align, books, golden, hebrew, kjv, lexicons, morph, query, strongs,  # noqa: E402
                     tagnt, tr, usage, writer)

SRC = HERE / "sources"
OUT = HERE / "out"
SCHEMA_VERSION = 1
DATA_VERSION = "2026.10.2"
EXPECTED_VERSES = 31102


class BuildError(Exception):
    pass


def nfc(x):
    """Greek tonos/oxia and Hebrew combining-mark order differ between sources; store NFC."""
    return unicodedata.normalize("NFC", x) if isinstance(x, str) and x else x


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def main() -> int:
    OUT.mkdir(exist_ok=True)
    errors: list[str] = []

    # ---- 1. KJV with Strong's -------------------------------------------------------------
    imp = SRC / "crosswire-KJV" / "kjv.imp"
    log("extracting CrossWire KJV with mod2imp")
    kjv.run_mod2imp(SRC / "crosswire-KJV" / "module", imp)
    verses = list(kjv.parse_module(imp))
    log(f"KJV verses: {len(verses)}")
    kjv_keys_ot = {(v.book_id, v.chapter, v.verse) for v in verses if v.book_id <= 39}

    # ---- 2. original-language texts ------------------------------------------------------
    tr_tokens = tr.parse_all(SRC / "tr" / "parsed")
    log(f"TR verses: {len(tr_tokens)}")
    tagnt_words = tagnt.parse_files(sorted((SRC / "stepbible" / "Translators Amalgamated OT+NT").glob("TAGNT*.txt")))
    accents = tagnt.build_accents(tr_tokens, tagnt_words)
    heb, wlc = hebrew.build_hebrew(SRC / "morphhb" / "wlc", kjv_keys_ot)
    log(f"Hebrew pools: {len(heb)}")

    # ---- 3. lexicons -----------------------------------------------------------------------
    entries = {}
    entries.update(strongs.load_greek(SRC / "strongs_grk" / "strongsgreek.xml"))
    entries.update(strongs.load_hebrew(SRC / "hebrewlex" / "HebrewStrong.xml"))
    lex = []
    lex += lexicons.load_abbott(SRC / "abbott" / "abbott-smith.tei.xml")
    lex += lexicons.load_bdb(SRC / "hebrewlex" / "BrownDriverBriggs.xml", SRC / "hebrewlex" / "LexicalIndex.xml")
    # STEPBible TBESG/TBESH are derived from Abbott-Smith and BDB, which are already loaded in
    # full, so they are not stored (lexicons.load_step remains available if that changes).
    log(f"Strong's entries: {len(entries)}  lexicon entries: {len(lex)}")

    # ---- 4. align, usage -----------------------------------------------------------------
    align_rows = []
    for v in verses:
        key = (v.book_id, v.chapter, v.verse)
        if v.book_id >= 40:
            align_rows += align.align_nt(v, tr_tokens.get(key, []))
        else:
            align_rows += align.align_ot(v, heb.get(key, []))
    use, occ = usage.compute(verses, entries)
    # Verses holding a Strong's number include the original-language words, not only the KJV
    # tags: the KJV tagging is sparse for particles (H3588 is tagged 46 times, occurs ~4,480).
    orig_count = collections.Counter()
    for toks in tr_tokens.values():
        for t in toks:
            if t.strongs:
                orig_count[t.strongs] += 1
    for key, toks in heb.items():
        for t in toks:
            for s in ([t.strongs] if t.strongs else []) + list(t.others):
                orig_count[s] += 1
                occ[s].add(key)
    for key, toks in tr_tokens.items():
        for t in toks:
            if t.strongs:
                occ[t.strongs].add(key)
    # "N occurrences": the KJV translation total (G1401 = 127), or the number of original-language
    # words when the KJV tagging is sparser than the text (H3588).
    occurrences = {s: max(sum(c.values()), orig_count.get(s, 0)) for s, c in use.items()}
    for s, n in orig_count.items():
        occurrences.setdefault(s, n)

    cov = {"NT": collections.Counter(), "OT": collections.Counter()}
    for r in align_rows:
        cov["NT" if r[0] >= 40 else "OT"][r[-1]] += 1
    coverage = {}
    for t, c in cov.items():
        tot = sum(c.values())
        coverage[t] = {k: c[k] for k in ("exact", "strongs_only", "none")}
        coverage[t]["total"] = tot
        coverage[t]["matched_pct"] = round(100 * (c["exact"] + c["strongs_only"]) / tot, 2)
        coverage[t]["exact_pct"] = round(100 * c["exact"] / tot, 2)
    log(f"alignment coverage: {json.dumps(coverage)}")

    # ---- 5. morph codes ------------------------------------------------------------------
    morph_rows = {}
    robinson = {t.morph for toks in tr_tokens.values() for t in toks} | \
               {m for v in verses for t in v.tokens for m in t.morphs}
    for c in sorted(robinson):
        morph_rows[c] = ("robinson", morph.expand_robinson(c))
    oshb = morph.load_oshb(SRC / "morphhb" / "parsing" / "Oshm.xml")
    # Oshm.xml is only a cross-check: every code it lists must parse with the generator, which
    # is what produces the stored expansions (one consistent format for all codes).
    for c in oshb:
        try:
            morph.expand_oshb(c)
        except morph.MorphError:
            errors.append(f"OSHB code in Oshm.xml not understood by generator: {c!r}")
    for toks in heb.values():
        for t in toks:
            if t.morph and t.morph not in morph_rows:
                try:
                    morph_rows[t.morph] = ("oshb", morph.expand_oshb(t.morph))
                except morph.MorphError:
                    errors.append(f"unparseable OSHB morph code {t.morph!r}")

    # ---- 6. write SQLite -------------------------------------------------------------------
    db_path = OUT / "reforged-study.sqlite"
    con = writer.create(db_path)
    chapters = collections.defaultdict(int)
    for v in verses:
        chapters[v.book_id] = max(chapters[v.book_id], v.chapter)
    con.executemany("INSERT INTO books VALUES (?,?,?,?,?)",
                    [(b["book_id"], b["osis"], b["name"], b["testament"], chapters[b["book_id"]]) for b in books.BOOKS])
    vid = books.verse_id
    con.executemany("INSERT INTO kjv_verses VALUES (?,?,?,?,?,?)",
                    [(vid(v.book_id, v.chapter, v.verse), v.book_id, v.chapter, v.verse, v.text, v.title or None)
                     for v in verses])
    # alignment results keyed by (verse key, kjv position, strongs)
    amap = {(r[0], r[1], r[2], r[3], r[4]): (r[5], r[6], r[7]) for r in align_rows}
    tok_rows = []
    for v in verses:
        base = vid(v.book_id, v.chapter, v.verse)
        for t in v.tokens:
            head = (base, t.position)
            tail = (t.word_index, t.word_count, int(t.added), int(t.in_title))
            if not t.strongs:
                tok_rows.append(head + ("", t.word, None) + tail + (None, None, None))
            for idx, sn in enumerate(t.strongs):
                ed, op, q = amap[(v.book_id, v.chapter, v.verse, t.position, sn)]
                tok_rows.append(head + (sn, t.word, kjv.per_strongs(t.morphs, t.strongs, idx)) + tail + (ed, op, q))
    con.executemany("INSERT INTO kjv_tokens VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", tok_rows)

    orig_rows = []
    for (b, c, vs), toks in tr_tokens.items():
        acc = accents.get((b, c, vs), {})
        for t in toks:
            orig_rows.append((vid(b, c, vs), t.position - 1, "grc", "TR", nfc(t.surface),
                              nfc(acc.get(t.position)), t.strongs or "", t.morph, None, None))
    for (b, c, vs), toks in heb.items():
        for t in toks:
            own_ref = f"{books.BY_ID[b]['osis']}.{c}.{vs}"
            orig_rows.append((vid(b, c, vs), t.position, "hbo", "WLC", nfc(t.surface), None,
                              t.strongs, t.morph or None, " ".join(t.others) or None,
                              t.src_ref if t.src_ref != own_ref else None))
    con.executemany("INSERT INTO original_tokens VALUES (?,?,?,?,?,?,?,?,?,?)", orig_rows)
    con.executemany("INSERT INTO morph_codes VALUES (?,?,?)", [(c, s, e) for c, (s, e) in morph_rows.items()])
    con.executemany("INSERT INTO strongs_entries VALUES (?,?,?,?,?,?,?,?,?)",
                    [(e.strongs, e.language, nfc(e.lemma), nfc(e.translit), nfc(e.pron), nfc(e.definition),
                      nfc(e.kjv_def), nfc(e.derivation), occurrences.get(e.strongs, 0))
                     for e in entries.values()])
    con.executemany("INSERT INTO lexicon_entries VALUES (?,?,?,?,?,?)",
                    [(e.source, e.strongs, nfc(e.lemma), nfc(e.headword), nfc(e.body_html), nfc(e.body_text))
                     for e in lex])
    con.executemany("INSERT INTO strongs_usage VALUES (?,?,?)",
                    [(s, w, n) for s, c in use.items() for w, n in c.items()])
    con.executemany("INSERT INTO strongs_occurrences VALUES (?,?)",
                    [(s, vid(*k)) for s, ks in occ.items() for k in ks])
    meta = {"schema_version": str(SCHEMA_VERSION), "data_version": DATA_VERSION,
            "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "kjv_module_version": "KJV 3.1 (2023-07-19)"}
    lock = json.loads((HERE / "sources.lock.json").read_text())
    for k, v in lock.items():
        meta[f"source.{k}"] = v.get("commit") or v.get("sha256")
    con.executemany("INSERT INTO meta VALUES (?,?)", list(meta.items()))
    writer.finish(con)
    log(f"wrote {db_path} ({db_path.stat().st_size / 1e6:.1f} MB)")

    # ---- 7. validate -----------------------------------------------------------------------
    errors += validate(db_path, coverage)

    # ---- 8. manifest -----------------------------------------------------------------------
    data = db_path.read_bytes()
    manifest = {
        "schema_version": SCHEMA_VERSION, "data_version": DATA_VERSION,
        "built_at": meta["built_at"], "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
        "sources": lock, "coverage": coverage,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    if errors:
        print("\nBUILD FAILED:")
        for e in errors:
            print("  -", e)
        return 1
    log("build OK")
    return 0


def validate(db_path: Path, coverage: dict) -> list[str]:  # noqa: C901
    errs = []
    con = query.connect(db_path)
    n = con.execute("SELECT COUNT(*) FROM kjv_verses").fetchone()[0]
    if n != EXPECTED_VERSES:
        errs.append(f"verse count {n} != {EXPECTED_VERSES}")
    q = con.execute("""SELECT t.strongs, COUNT(*) c FROM kjv_tokens t LEFT JOIN strongs_entries e ON e.strongs=t.strongs
                       WHERE t.strongs <> '' AND e.strongs IS NULL GROUP BY t.strongs""").fetchall()
    if q:
        errs.append(f"{len(q)} KJV Strong's numbers missing from strongs_entries: {[tuple(r) for r in q[:8]]}")
    q = con.execute("""SELECT DISTINCT t.morph FROM kjv_tokens t LEFT JOIN morph_codes m ON m.code=t.morph
                       WHERE t.morph IS NOT NULL AND m.code IS NULL""").fetchall()
    if q:
        errs.append(f"KJV morph codes missing from morph_codes: {[r[0] for r in q[:8]]}")
    q = con.execute("""SELECT DISTINCT o.morph FROM original_tokens o LEFT JOIN morph_codes m ON m.code=o.morph
                       WHERE o.morph IS NOT NULL AND m.code IS NULL""").fetchall()
    if q:
        errs.append(f"original morph codes missing from morph_codes: {[r[0] for r in q[:8]]}")
    if con.execute("SELECT COUNT(*) FROM lexicon_entries WHERE trim(body_text)=''").fetchone()[0]:
        errs.append("empty lexicon bodies")
    if coverage["NT"]["matched_pct"] < 97:
        errs.append(f"NT alignment coverage {coverage['NT']['matched_pct']}% < 97%")

    for case in golden.CASES:
        pos = query.find_position(con, case["verse"], case["word"], case.get("occurrence", 0))
        if pos is None:
            errs.append(f"golden '{case['name']}': word {case['word']!r} not found")
            continue
        ws = query.word_study(con, case["verse"], pos)
        if ws is None:
            errs.append(f"golden '{case['name']}': no word study")
            continue
        for path, want in case["expect"].items():
            cur = ws
            for part in path.split("."):
                if cur is None:
                    break
                cur = cur[int(part)] if isinstance(cur, list) else cur.get(part)
            ok = want(cur) if callable(want) else nfc(cur) == nfc(want)
            if not ok:
                errs.append(f"golden '{case['name']}': {path} = {cur!r}, expected {want if not callable(want) else 'predicate'}")
    return errs


if __name__ == "__main__":
    sys.exit(main())
