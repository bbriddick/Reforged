"""Strong's dictionaries: Greek (morphgnt XML, public domain) and Hebrew/Aramaic
(openscriptures HebrewLexicon HebrewStrong.xml; text public domain, markup CC BY 4.0)."""
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from .strongsnum import norm

WS = re.compile(r"\s+")


@dataclass
class Entry:
    strongs: str
    language: str            # 'grc' | 'hbo' | 'arc'
    lemma: str
    translit: str = ""
    pron: str = ""
    definition: str = ""
    kjv_def: str = ""
    derivation: str = ""
    pos: str = ""


def _ln(el):
    return el.tag.split("}")[-1]


def _clean(s: str) -> str:
    s = WS.sub(" ", s).strip()
    s = re.sub(r"\s+([;,.:])", r"\1", s)        # no space before punctuation
    return s


def _render(el, lemma_for, prefix) -> str:
    """Flatten mixed content; strong's refs become the referenced lemma."""
    out = [el.text or ""]
    for child in el:
        name = _ln(child)
        if name == "strongsref":
            num = norm(child.get("strongs", ""), "G" if child.get("language") == "GREEK" else "H")
            word = lemma_for(num) if num else ""
            out.append(f" {word or num or ''} ")
        elif name == "greek":
            out.append(f" {child.get('unicode', '')} ")
        elif name == "w":                        # Hebrew: <w src="H7218">7218</w>
            src = norm(child.get("src", ""))
            word = lemma_for(src) if src else ""
            out.append(f" {word or ''.join(child.itertext())} ")
        elif name == "pronunciation":
            out.append(f" ({child.get('strongs', '')}) ")
        else:
            out.append(_render(child, lemma_for, prefix))
        out.append(child.tail or "")
    return "".join(out)


def load_greek(path: Path) -> dict[str, Entry]:
    root = ET.parse(path).getroot()
    entries: dict[str, Entry] = {}
    raw: list = []
    for el in root.iter():
        if _ln(el) != "entry" or not el.get("strongs"):
            continue
        num = norm(el.get("strongs"), "G")
        if not num:
            continue
        g = next((c for c in el if _ln(c) == "greek"), None)
        pr = next((c for c in el if _ln(c) == "pronunciation"), None)
        entries[num] = Entry(
            strongs=num, language="grc",
            lemma=(g.get("unicode") if g is not None else "") or "",
            translit=(g.get("translit") if g is not None else "") or "",
            pron=(pr.get("strongs") if pr is not None else "") or "")
        raw.append((num, el))

    def lemma_for(n):
        e = entries.get(n)
        return e.lemma if e else ""

    for num, el in raw:
        e = entries[num]
        for c in el:
            n = _ln(c)
            if n == "strongs_def":
                e.definition = _clean(_render(c, lemma_for, "G"))
            elif n == "strongs_derivation":
                e.derivation = _clean(_render(c, lemma_for, "G")).rstrip(";").strip()
            elif n == "kjv_def":
                t = _clean(_render(c, lemma_for, "G"))
                e.kjv_def = re.sub(r"^:--\s*", "", t).rstrip(".").strip()
    return entries


def load_hebrew(path: Path) -> dict[str, Entry]:
    root = ET.parse(path).getroot()
    entries: dict[str, Entry] = {}
    raw = []
    for el in root.iter():
        if _ln(el) != "entry" or not el.get("id"):
            continue
        num = norm(el.get("id"))
        if not num or not num.startswith("H"):
            continue
        w = next((c for c in el if _ln(c) == "w"), None)
        if w is None or num in entries:
            continue
        lang = (w.get("{http://www.w3.org/XML/1998/namespace}lang") or "heb")
        entries[num] = Entry(
            strongs=num, language="arc" if lang.startswith("arc") or lang == "x-aram" else "hbo",
            lemma="".join(w.itertext()).strip(), translit=w.get("xlit", ""), pron=w.get("pron", ""),
            pos=w.get("pos", ""))
        raw.append((num, el))

    def lemma_for(n):
        e = entries.get(n)
        return e.lemma if e else ""

    for num, el in raw:
        e = entries[num]
        for c in el:
            n = _ln(c)
            if n == "meaning":
                e.definition = _clean(_render(c, lemma_for, "H"))
            elif n == "usage":
                e.kjv_def = _clean(_render(c, lemma_for, "H")).rstrip(".").strip()
            elif n == "source":
                e.derivation = _clean(_render(c, lemma_for, "H")).rstrip(";").strip()
    return entries
