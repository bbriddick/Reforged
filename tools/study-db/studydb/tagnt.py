"""Accented Greek forms from STEPBible TAGNT (CC BY 4.0), used only to attach `surface_accented`
to Textus Receptus tokens. TAGNT lists every word from every edition with edition flags, so we keep
the words flagged TR and align them to the byztxt TR tokens by unaccented form.
"""
import difflib
import re
import unicodedata
from pathlib import Path

from . import books
from .strongsnum import norm

REF_RE = re.compile(r"^([1-3]?[A-Za-z]+)\.(\d+)\.(\d+)#(\d+)=(\S+)$")
TRANSLIT_RE = re.compile(r"\s*\([^)]*\)\s*$")


def strip_marks(s: str) -> str:
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return s.lower().replace("ς", "σ")


def clean_word(s: str) -> str:
    s = TRANSLIT_RE.sub("", s).strip()
    # trim trailing/leading punctuation (· ; , . etc.) but keep letters and combining marks
    s = re.sub(r"^[^\w]+|[^\w]+$", "", s, flags=re.UNICODE)
    return unicodedata.normalize("NFC", s)


def parse_files(paths):
    """Return {(book_id, chapter, verse): [(accented, strongs), ...]} for words flagged TR."""
    out: dict = {}
    for path in paths:
        for raw in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
            if not raw or raw[0] == "#" or "\t" not in raw:
                continue
            cols = raw.split("\t")
            m = REF_RE.match(cols[0])
            if not m or len(cols) < 6:
                continue
            b = books.BY_TAGNT.get(m.group(1))
            if not b:
                continue
            editions = cols[5]
            if not any(e.split("»")[0] == "TR" for e in editions.split("+")):
                continue
            dstrongs = cols[3].split("=")[0]
            form = clean_word(cols[1])
            # `Tyn+TR: εἶπον ;` in the spelling-variants column is the TR's own spelling.
            if len(cols) > 7 and cols[7].strip():
                for entry in cols[7].split(";"):
                    if ":" not in entry:
                        continue
                    eds, spelling = entry.split(":", 1)
                    if any(e.split("»")[0] == "TR" for e in eds.strip().split("+")) and spelling.strip():
                        form = clean_word(spelling.strip().split()[0])
                        break
            out.setdefault((b["book_id"], int(m.group(2)), int(m.group(3))), []).append(
                (form, norm(dstrongs, "G")))
    return out


def _align_verse(tr_tokens, words):
    """Return ({tr_position: word_index}, used_word_indexes) for one verse."""
    a = [strip_marks(t.surface) for t in tr_tokens]
    b = [strip_marks(w[0]) for w in words]
    mapping = {}
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                mapping[tr_tokens[i1 + k].position] = j1 + k
        elif tag == "replace" and (i2 - i1) == (j2 - j1):
            for k in range(i2 - i1):
                if tr_tokens[i1 + k].strongs and tr_tokens[i1 + k].strongs == words[j1 + k][1]:
                    mapping[tr_tokens[i1 + k].position] = j1 + k
    # leftovers within the verse: same unaccented form, nearest position (word-order variants)
    used = set(mapping.values())
    for t in tr_tokens:
        if t.position in mapping:
            continue
        cands = [j for j in range(len(words)) if j not in used and b[j] == strip_marks(t.surface)]
        if cands:
            j = min(cands, key=lambda j: abs(j - (t.position - 1)))
            mapping[t.position] = j
            used.add(j)
    return mapping, used


def build_accents(tr_by_verse, tagnt_by_verse):
    """Return {(book, ch, vs): {tr_position: accented_form}}.

    Pass 1 aligns verse by verse. Pass 2 lets still-unmatched TR words claim unused TAGNT words
    anywhere in the same chapter, which covers verse-division differences between editions.
    """
    result = {}
    leftovers = {}   # (book, ch) -> list of (normalized_form, accented, verse)
    for key, toks in tr_by_verse.items():
        words = tagnt_by_verse.get(key, [])
        mapping, used = _align_verse(toks, words)
        result[key] = {pos: words[j][0] for pos, j in mapping.items()}
        for j, w in enumerate(words):
            if j not in used:
                leftovers.setdefault(key[:2], []).append([strip_marks(w[0]), w[0], key[2], False])
    for key, toks in tr_by_verse.items():
        pool = leftovers.get(key[:2])
        if not pool:
            continue
        for t in toks:
            if t.position in result[key]:
                continue
            norm_form = strip_marks(t.surface)
            cands = [c for c in pool if not c[3] and c[0] == norm_form]
            if cands:
                c = min(cands, key=lambda c: abs(c[2] - key[2]))
                c[3] = True
                result[key][t.position] = c[1]
    return result
