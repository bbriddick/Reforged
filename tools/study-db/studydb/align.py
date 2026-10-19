"""Align KJV tokens to original-language tokens (spec 6.3).

NT: the KJV module's `src` index plus its `lemma.TR` string pins the Greek word; when the
module's TR snapshot differs from the byztxt TR we fall back to Strong's number, then Robinson
morph, then relative word order. OT: Strong's number, then relative word order (nth occurrence
of S in the KJV verse maps to the nth occurrence in the Hebrew pool).

match_quality:
  exact         single candidate, or lemma/morph confirmed
  strongs_only  Strong's matched but position chosen by order
  none          no original-language token carries that Strong's number
"""
from collections import defaultdict

from .kjv import per_strongs


def align_nt(verse, tr_tokens):
    """tr_tokens: list of studydb.tr.TRToken (positions 1-based). Returns list of row tuples."""
    rows = []
    by_strongs = defaultdict(list)
    for i, t in enumerate(tr_tokens):
        if t.strongs:
            by_strongs[t.strongs].append(i)
    used = set()
    last = -1
    for tok in verse.tokens:
        if not tok.strongs:
            continue
        for idx, s in enumerate(tok.strongs):
            src = per_strongs(tok.srcs, tok.strongs, idx)
            lemma = per_strongs(tok.lemmas, tok.strongs, idx)
            morph = per_strongs(tok.morphs, tok.strongs, idx)
            j = None
            if src is not None and lemma:
                i = src - 1
                if 0 <= i < len(tr_tokens) and tr_tokens[i].surface == lemma:
                    j = i
                else:
                    cands = [k for k, t2 in enumerate(tr_tokens) if t2.surface == lemma]
                    free = [k for k in cands if k not in used] or cands
                    if free:
                        j = min(free, key=lambda k: abs(k - (src - 1)))
            if j is not None:
                q = "exact" if tr_tokens[j].strongs == s else "strongs_only"
                rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, "TR", j, q))
                used.add(j)
                last = j
                continue
            cands = by_strongs.get(s, [])
            if not cands:
                rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, None, None, "none"))
                continue
            if len(cands) == 1:
                k, q = cands[0], "exact"
            else:
                by_morph = [k for k in cands if morph and tr_tokens[k].morph == morph and k not in used]
                free = [k for k in cands if k not in used]
                if len(by_morph) == 1:
                    k, q = by_morph[0], "exact"
                elif free:
                    after = [k for k in free if k > last]
                    k, q = (after or free)[0], "strongs_only"
                else:
                    k, q = cands[0], "strongs_only"
            rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, "TR", k, q))
            used.add(k)
            last = k
    return rows


def align_ot(verse, heb_tokens):
    """heb_tokens: list of studydb.hebrew.HebToken (0-based positions)."""
    rows = []
    kjv_count = defaultdict(int)
    for tok in verse.tokens:
        for s in tok.strongs:
            kjv_count[s] += 1
    heb_by = defaultdict(list)
    for i, h in enumerate(heb_tokens):
        for s in ([h.strongs] if h.strongs else []) + list(h.others):
            if s:
                heb_by[s].append(i)
    seen = defaultdict(int)
    for tok in verse.tokens:
        for s in tok.strongs:
            cands = heb_by.get(s, [])
            n = seen[s]
            seen[s] += 1
            if not cands:
                rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, None, None, "none"))
            elif len(cands) == 1 and kjv_count[s] == 1:
                rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, "WLC", cands[0], "exact"))
            else:
                k = cands[min(n, len(cands) - 1)]
                rows.append((verse.book_id, verse.chapter, verse.verse, tok.position, s, "WLC", k, "strongs_only"))
    return rows
