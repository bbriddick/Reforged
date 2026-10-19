"""Parse the CrossWire KJV (KJV2003, Strong's + Robinson + TR lemma) module.

Input is the output of `mod2imp KJV`: `$$$<Book> <c>:<v>` header lines each followed by an
OSIS fragment. Every English word ends up in exactly one token, so a tapped word always has a
home: tagged phrases (`<w>`), supplied/italic words (`transChange added`) and plain untagged words.
"""
import re
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

from . import books
from .strongsnum import norm

HEAD_RE = re.compile(r"^\$\$\$(.+) (\d+):(\d+)$")
ROBINSON_RE = re.compile(r"robinson:([^\s]+)")
STRONG_RE = re.compile(r"strong:([GH]\d+[a-z]?)")
LEMMA_TR_RE = re.compile(r"lemma\.TR:(\S+)")
WORD_RE = re.compile(r"\S+")
ALNUM_RE = re.compile(r"\w", re.UNICODE)

# Elements whose text is never part of the verse as displayed.
SKIP_TAGS = {"note", "rdg", "catchWord", "reference", "index"}


@dataclass
class Token:
    position: int = 0
    word: str = ""                  # displayed English, e.g. 'the servants'
    strongs: list = field(default_factory=list)   # ['G3588', 'G3056'], may hold several
    morphs: list = field(default_factory=list)    # Robinson codes, one per Greek word (NT only)
    srcs: list = field(default_factory=list)      # 1-based TR word indexes, one per Greek word
    lemmas: list = field(default_factory=list)    # unaccented TR forms, one per Greek word
    added: bool = False             # supplied (italic) word
    in_title: bool = False          # Psalm preverse title
    word_index: int = -1            # index of first word in verse text (title words = -1)
    word_count: int = 0
    start: int = 0                  # char offsets in the working string, internal
    end: int = 0


def per_strongs(values: list, strongs: list, i: int):
    """The value belonging to strongs[i]: index-aligned when the counts match, the single value
    when there is exactly one, otherwise unknown (None)."""
    if len(values) == len(strongs):
        return values[i]
    if len(values) == 1:
        return values[0]
    return None


@dataclass
class Verse:
    book_id: int
    chapter: int
    verse: int
    text: str = ""
    tokens: list = field(default_factory=list)
    title: str = ""


def run_mod2imp(module_root: Path, out_path: Path) -> None:
    import os
    env = dict(os.environ, SWORD_PATH=str(module_root))
    with open(out_path, "wb") as f:
        subprocess.run(["mod2imp", "KJV"], env=env, stdout=f, stderr=subprocess.DEVNULL, check=True)


def iter_imp(path: Path):
    key, buf = None, []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("$$$"):
                if key is not None:
                    yield key, "\n".join(buf)
                key, buf = line, []
            else:
                buf.append(line)
    if key is not None:
        yield key, "\n".join(buf)


class _Builder:
    """Walks a verse fragment and produces plain text plus tagged spans."""

    def __init__(self):
        self.parts: list[str] = []
        self.len = 0
        self.spans: list[dict] = []   # {start,end,kind,meta}
        self.title_parts: list[str] = []

    def add(self, text: str):
        if text:
            self.parts.append(text)
            self.len += len(text)

    def walk(self, el, ctx):
        tag = el.tag.split("}")[-1]
        if tag in SKIP_TAGS:
            return
        if tag == "title":
            canonical = el.get("canonical") == "true" and el.get("type") == "psalm"
            if not canonical:
                return
            ctx = dict(ctx, title=True)
        if tag == "transChange" and el.get("type") == "added":
            ctx = dict(ctx, added=True)
        if tag == "w":
            start = self.len
            inner_ctx = dict(ctx, in_w=True)
            self._text(el.text, inner_ctx)
            for child in el:
                self.walk(child, inner_ctx)
                self._text(child.tail, inner_ctx)
            lemma = el.get("lemma", "")
            strongs = list(dict.fromkeys(s for s in (norm(x) for x in STRONG_RE.findall(lemma)) if s))
            srcs = [int(x) for x in (el.get("src") or "").split() if x.isdigit()]
            self.spans.append(dict(
                start=start, end=self.len, kind="w", strongs=strongs,
                morphs=ROBINSON_RE.findall(el.get("morph", "")),
                srcs=srcs,
                lemmas=LEMMA_TR_RE.findall(lemma),
                added=bool(ctx.get("added")), title=bool(ctx.get("title")),
            ))
            return
        # generic container: recurse
        self._text(el.text, ctx)
        for child in el:
            self.walk(child, ctx)
            self._text(child.tail, ctx)

    def _text(self, text, ctx):
        if not text:
            return
        start = self.len
        self.add(text)
        if not ctx.get("in_w"):
            self.spans.append(dict(start=start, end=self.len, kind="plain",
                                   added=bool(ctx.get("added")), title=bool(ctx.get("title"))))


def parse_verse(book_id: int, chapter: int, verse: int, fragment: str) -> Verse:
    v = Verse(book_id, chapter, verse)
    xml = "<r>" + fragment + "</r>"
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        # Fall back to a tag-stripped plain text verse with no tokens rather than lose it.
        v.text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", fragment)).strip()
        return v
    b = _Builder()
    b._text(root.text, {})
    for child in root:
        b.walk(child, {})
        b._text(child.tail, {})
    raw = "".join(b.parts)

    # Collapse whitespace while keeping every span offset valid: build an index map.
    out_chars: list[str] = []
    index_map = [0] * (len(raw) + 1)
    prev_space = True
    for i, ch in enumerate(raw):
        index_map[i] = len(out_chars)
        if ch.isspace():
            if not prev_space:
                out_chars.append(" ")
            prev_space = True
        else:
            out_chars.append(ch)
            prev_space = False
    index_map[len(raw)] = len(out_chars)
    clean = "".join(out_chars)

    toks: list[Token] = []
    for sp in b.spans:
        s, e = index_map[sp["start"]], index_map[sp["end"]]
        seg = clean[s:e]
        if sp["kind"] == "w":
            toks.append(Token(word=seg.strip(), strongs=sp["strongs"], morphs=sp["morphs"], srcs=sp["srcs"],
                              lemmas=sp["lemmas"], added=sp["added"], in_title=sp["title"],
                              start=s, end=e))
        else:
            for m in WORD_RE.finditer(seg):
                w = m.group(0)
                if not ALNUM_RE.search(w):
                    continue
                toks.append(Token(word=w, added=sp["added"], in_title=sp["title"],
                                  start=s + m.start(), end=s + m.end()))
    toks.sort(key=lambda t: (t.start, t.end))

    # Displayed text excludes the Psalm title. Title characters are masked with spaces (not
    # removed) so token offsets stay valid while word indexes are counted over the body only.
    masked = list(clean)
    title_chars = []
    for sp in b.spans:
        if sp["title"]:
            for i in range(index_map[sp["start"]], index_map[sp["end"]]):
                title_chars.append((i, clean[i]))
                masked[i] = " "
    full_body = "".join(masked)
    v.text = re.sub(r"\s+", " ", full_body).strip()
    v.title = re.sub(r"\s+", " ", "".join(c for _, c in sorted(set(title_chars)))).strip()

    word_spans = [(m.start(), m.end()) for m in WORD_RE.finditer(full_body)]
    for i, t in enumerate(toks):
        t.position = i
        if t.in_title or t.end <= t.start:
            t.word_index, t.word_count = (-1, 0)
            continue
        idxs = [wi for wi, (ws, we) in enumerate(word_spans) if ws < t.end and we > t.start]
        t.word_index, t.word_count = (idxs[0], len(idxs)) if idxs else (-1, 0)
    v.tokens = toks
    return v


def parse_module(imp_path: Path):
    """Yield Verse objects for every real verse (chapter >= 1, verse >= 1) in Bible order."""
    for header, fragment in iter_imp(imp_path):
        m = HEAD_RE.match(header)
        if not m:
            continue
        name, c, vs = m.group(1), int(m.group(2)), int(m.group(3))
        b = books.BY_KJV_NAME.get(name)
        if not b or c < 1 or vs < 1:
            continue
        yield parse_verse(b["book_id"], c, vs, fragment)
