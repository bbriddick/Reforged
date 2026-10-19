"""Parse morphhb (Westminster Leningrad Codex + OSHB morphology) and remap to KJV verses.

The WLC uses Hebrew versification. KJV verse X collects the WLC verses that VerseMap.xml sends
there; for Psalms every Hebrew title verse folds into KJV verse 1 (the KJV module carries the
title as a pre-verse of verse 1).
"""
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

from . import books
from .strongsnum import norm

CANTILLATION_RE = re.compile("[֑-֯]")
NUMSEG_RE = re.compile(r"^(\d+)(?:\s+[a-z])?\+?$")


@dataclass
class HebToken:
    position: int = 0
    surface: str = ""            # pointed, no cantillation
    surface_accented: str = ""   # with cantillation
    strongs: str = ""            # head word, 'H7225'
    others: list = field(default_factory=list)
    morph: str = ""              # OSHB code, e.g. 'HR/Ncfsa'
    aramaic: bool = False
    src_ref: str = ""            # WLC reference this word came from


def _ln(el):
    return el.tag.split("}")[-1]


def _parse_word(w) -> HebToken | None:
    # ignore words that live inside notes (qere readings, variants)
    text = "".join(w.itertext()).replace("/", "")
    text = re.sub(r"\s+", "", text)
    if not text:
        return None
    nums = []
    for seg in (w.get("lemma") or "").split("/"):
        m = NUMSEG_RE.match(seg.strip())
        if m:
            n = norm("H" + m.group(1))
            if n:
                nums.append(n)
    morph = w.get("morph") or ""
    return HebToken(surface=CANTILLATION_RE.sub("", text), surface_accented=text,
                    strongs=nums[-1] if nums else "", others=nums[:-1] if nums else [],
                    morph=morph, aramaic=morph.startswith("A"))


def parse_book(path: Path):
    """Return {(chapter, verse): [HebToken]} in WLC (Hebrew) numbering."""
    out = {}
    root = ET.parse(path).getroot()
    for verse in root.iter():
        if _ln(verse) != "verse" or not verse.get("osisID"):
            continue
        parts = verse.get("osisID").split(".")
        ch, vs = int(parts[-2]), int(parts[-1])
        toks = []

        def walk(el, in_note=False):
            for child in el:
                name = _ln(child)
                if name == "note":
                    continue
                if name == "w" and not in_note:
                    t = _parse_word(child)
                    if t:
                        toks.append(t)
                else:
                    walk(child, in_note)
        walk(verse)
        out[(ch, vs)] = toks
    return out


def load_versemap(path: Path):
    """Return list of (wlc_osis, kjv_osis, type)."""
    rows = []
    root = ET.parse(path).getroot()
    for el in root.iter():
        if _ln(el) == "verse" and el.get("wlc") and el.get("kjv"):
            rows.append((el.get("wlc"), el.get("kjv"), el.get("type")))
    return rows


def _key(osis_ref: str):
    ref = osis_ref.split("!")[0]
    book, ch, vs = ref.split(".")
    b = books.BY_OSIS.get(book)
    if not b:
        raise KeyError(f"unmapped OSIS book in VerseMap: {book}")
    return (b["book_id"], int(ch), int(vs))


def build_hebrew(morphhb_wlc_dir: Path, kjv_keys: set):
    """Return {kjv_verse_key: [HebToken]} with positions renumbered per KJV verse."""
    wlc = {}
    for b in books.BOOKS:
        if b["testament"] != "OT":
            continue
        path = morphhb_wlc_dir / f"{b['osis']}.xml"
        if not path.exists():
            raise FileNotFoundError(path)
        for (ch, vs), toks in parse_book(path).items():
            wlc[(b["book_id"], ch, vs)] = toks

    # kjv_key -> ordered list of wlc keys
    targets: dict = {}
    claimed = set()
    sources = set()
    vm = load_versemap(morphhb_wlc_dir / "VerseMap.xml")
    for wlc_ref, kjv_ref, typ in vm:
        wk, kk = _key(wlc_ref), _key(kjv_ref)
        sources.add(wk)
        claimed.add(kk)
        lst = targets.setdefault(kk, [])
        if wk not in lst:
            lst.append(wk)

    # Psalm titles: any WLC verses before the one mapped to KJV verse 1 are title material.
    for kk in list(targets):
        if kk[0] == 19 and kk[2] == 1:
            first = min(targets[kk], key=lambda k: k[2])
            titles = [(19, kk[1], n) for n in range(1, first[2]) if (19, kk[1], n) in wlc]
            targets[kk] = titles + [k for k in targets[kk] if k not in titles]
            sources.update(titles)

    for wk in wlc:
        if wk in sources:
            continue
        if wk in kjv_keys and wk not in claimed:
            targets.setdefault(wk, []).append(wk)
        elif wk in kjv_keys and wk in claimed:
            # identity target is taken by a mapped verse; this verse has no KJV home
            targets.setdefault(wk, [])  # kept empty, reported by the validator

    # Partial-verse splits (1 Kgs 18:34, Isa 63:19 ...) leave a KJV verse with no mapped Hebrew
    # verse; the Hebrew verse with the same reference holds its words.
    for kk in kjv_keys:
        if not targets.get(kk) and kk in wlc:
            targets[kk] = [kk]

    out = {}
    for kk, wks in targets.items():
        if kk not in kjv_keys:
            continue
        toks = []
        for wk in wks:
            ref = f"{books.BY_ID[wk[0]]['osis']}.{wk[1]}.{wk[2]}"
            for t in wlc.get(wk, []):
                nt = HebToken(**{**t.__dict__, "src_ref": ref, "others": list(t.others)})
                toks.append(nt)
        for i, t in enumerate(toks):
            t.position = i
        out[kk] = toks
    return out, wlc
