"""Long-form lexicon entries: Abbott-Smith (TEI), BDB (OpenScriptures), STEPBible TBESG/TBESH.

Every entry is reduced to minimal sanitized HTML (p, div, b, i, sup, br, span.grc/span.heb) and
a plain-text twin used for previews and AI input.
"""
import html
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from .strongsnum import norm

WS = re.compile(r"\s+")


@dataclass
class LexEntry:
    source: str
    strongs: str | None
    lemma: str
    headword: str
    body_html: str
    body_text: str


def _ln(el):
    return el.tag.split("}")[-1]


def _esc(s: str) -> str:
    return html.escape(s, quote=False)


# ---------------------------------------------------------------- generic TEI / BDB converter

_BLOCK = {"sense", "etym", "re", "p", "div", "entry"}
_ITALIC = {"gloss", "emph", "em", "foreign", "def"}
_DROP = {"status", "pb", "page", "lb", "head", "note"}


def _to_html(el, lang_of=None) -> str:
    out = [_esc(el.text or "")]
    for ch in el:
        name = _ln(ch)
        if name in _DROP:
            out.append(_esc(ch.tail or ""))
            continue
        inner = _to_html(ch)
        if name == "orth":
            out.append(f"<b>{inner}</b>")
        elif name == "foreign" or name == "w":
            lang = ch.get("{http://www.w3.org/XML/1998/namespace}lang", "")
            cls = "heb" if lang.startswith("heb") else ("grc" if lang.startswith("grc") else "")
            out.append(f'<span class="{cls}">{inner}</span>' if cls else inner)
        elif name in ("gloss", "emph", "em", "def"):
            out.append(f"<i>{inner}</i>")
        elif name == "hi":
            out.append(f"<sup>{inner}</sup>" if ch.get("rend") == "superscript" else inner)
        elif name in _BLOCK:
            n = ch.get("n")
            label = f"<b>{_esc(n)}</b> " if (name == "sense" and n) else ""
            out.append(f"<div>{label}{inner}</div>")
        else:
            out.append(inner)
        out.append(_esc(ch.tail or ""))
    return "".join(out)


def _to_text(html_str: str) -> str:
    s = re.sub(r"</div>|<br\s*/?>", "\n", html_str)
    s = re.sub(r"<[^>]+>", "", s)
    s = html.unescape(s)
    s = "\n".join(WS.sub(" ", line).strip() for line in s.split("\n"))
    return re.sub(r"\n{2,}", "\n", s).strip()


def _tidy_html(h: str) -> str:
    h = re.sub(r"\s+", " ", h)
    h = re.sub(r"<div>\s*</div>", "", h)
    return h.strip()


# ---------------------------------------------------------------- Abbott-Smith

def load_abbott(path: Path) -> list[LexEntry]:
    root = ET.parse(path).getroot()
    out = []
    for el in root.iter():
        if _ln(el) != "entry" or not el.get("n") or "|" not in el.get("n"):
            continue
        lemma, key = el.get("n").split("|", 1)
        strongs = norm(key.split(",")[0], "G")
        body = _tidy_html(_to_html(el))
        text = _to_text(body)
        if not text:
            continue
        orth = next((c for c in el.iter() if _ln(c) == "orth"), None)
        out.append(LexEntry("abbott-smith", strongs, lemma,
                            "".join(orth.itertext()).strip() if orth is not None else lemma, body, text))
    return out


# ---------------------------------------------------------------- BDB

def load_bdb(bdb_path: Path, index_path: Path) -> list[LexEntry]:
    """BDB entries keyed to Strong's via LexicalIndex.xml cross-references."""
    idx = ET.parse(index_path).getroot()
    wanted: dict[str, list[str]] = {}      # bdb id -> [H numbers]
    for el in idx.iter():
        if _ln(el) == "xref" and el.get("bdb") and el.get("strong"):
            n = norm("H" + el.get("strong"))
            if n:
                wanted.setdefault(el.get("bdb"), []).append(n)
    root = ET.parse(bdb_path).getroot()
    out = []
    for el in root.iter():
        if _ln(el) != "entry" or el.get("id") not in wanted:
            continue
        body = _tidy_html(_to_html(el))
        text = _to_text(body)
        if not text:
            continue
        w = next((c for c in el.iter() if _ln(c) == "w"), None)
        head = "".join(w.itertext()).strip() if w is not None else ""
        for s in wanted[el.get("id")]:
            out.append(LexEntry("bdb", s, head, head, body, text))
    return out


# ---------------------------------------------------------------- STEPBible TBESG / TBESH

def _step_html(raw: str) -> str:
    s = raw.replace("<BR />", "<br>").replace("<BR/>", "<br>").replace("<BR>", "<br>")
    s = re.sub(r"<ref='[^']*'>(.*?)</ref>", r"\1", s, flags=re.I | re.S)
    s = re.sub(r"<(?!/?(?:b|i|br)\b)[^>]+>", "", s, flags=re.I)     # keep only b, i, br
    s = re.sub(r"<(/?)B>", r"<\1b>", s)
    s = re.sub(r"<(/?)I>", r"<\1i>", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def load_step(path: Path, source: str, prefix: str) -> list[LexEntry]:
    out = []
    for line in path.read_text(encoding="utf-8-sig").split("\n"):
        if not re.match(rf"^{prefix}\d", line):
            continue
        c = line.split("\t")
        if len(c) < 8:
            continue
        strongs = norm(c[0], prefix)
        body = _step_html(c[7])
        text = re.sub(r"<[^>]+>", " ", body.replace("<br>", "\n"))
        text = "\n".join(WS.sub(" ", t).strip() for t in html.unescape(text).split("\n")).strip()
        if not strongs or not text:
            continue
        gloss = c[6].strip()
        if gloss:
            body = f"<b>{_esc(gloss)}</b><br>" + body
            text = gloss + "\n" + text
        out.append(LexEntry(source, strongs, c[3].strip(), c[3].strip(), body, text))
    return out
