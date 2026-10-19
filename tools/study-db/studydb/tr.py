"""Parse Robinson's byztxt Textus Receptus (parsed/*.UTR) into per-verse token lists.

Format per verse:  `1:1 paulov 3972 {N-NSM} klhtov 2822 {A-NSM} ...` wrapped over lines.
Words are Latin-letter BETA with `v` = final sigma and no accents. A word is followed by one or
more numbers (the first is the Strong's number; extras such as 5723 are tense/mood tags) and a
{PARSING} code. Variant brackets `[ ]` and `(` `)` may wrap words.
"""
import re
from dataclasses import dataclass
from pathlib import Path

from . import books
from .strongsnum import norm

_BETA = {
    "a": "α", "b": "β", "g": "γ", "d": "δ", "e": "ε", "z": "ζ", "h": "η", "q": "θ", "i": "ι",
    "k": "κ", "l": "λ", "m": "μ", "n": "ν", "c": "χ", "o": "ο", "p": "π", "r": "ρ", "s": "σ",
    "v": "ς", "t": "τ", "u": "υ", "f": "φ", "x": "ξ", "y": "ψ", "w": "ω",
}
VERSE_RE = re.compile(r"^(\d+):(\d+)\s+(.*)$")
CODE_RE = re.compile(r"^\{([^}]+)\}$")
NUM_RE = re.compile(r"^\d+$")


def beta_to_greek(word: str) -> str:
    return "".join(_BETA.get(ch, ch) for ch in word.lower())


@dataclass
class TRToken:
    position: int          # 1-based, matches KJV `src`
    beta: str
    surface: str           # unaccented Greek
    strongs: str           # primary Strong's (G####)
    extra_numbers: list    # tense/mood tags such as 5723
    morph: str


def parse_book(path: Path):
    """Yield (chapter, verse, [TRToken...]) for one UTR file."""
    verses: list[tuple[int, int, str]] = []
    cur = None
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        m = VERSE_RE.match(line)
        if m:
            if cur:
                verses.append(tuple(cur))
            cur = [int(m.group(1)), int(m.group(2)), m.group(3)]
        elif cur:
            cur[2] += " " + line
    if cur:
        verses.append(tuple(cur))

    for ch, vs, body in verses:
        toks: list[TRToken] = []
        word = None
        nums: list[str] = []
        pos = 0
        # `| A | B |` marks two textual readings; the first reading is kept (matches the
        # CrossWire KJV module's `src` numbering), the second is dropped.
        alt = None   # None = outside a variant group, else 0/1 = which reading we are in
        for p in body.split():
            if p == "|":
                alt = 0 if alt is None else (alt + 1 if alt == 0 else None)
                continue
            if alt == 1:
                continue
            cm = CODE_RE.match(p)
            if cm:
                if word is not None and nums:
                    pos += 1
                    prim = norm(nums[0], "G")
                    toks.append(TRToken(pos, word, beta_to_greek(word), prim or "", nums[1:], cm.group(1)))
                word, nums = None, []
            elif NUM_RE.match(p):
                nums.append(p)
            else:
                w = p.strip("[]()")
                if w:
                    word, nums = w, []
        yield ch, vs, toks


def parse_all(tr_dir: Path):
    """Return {(book_id, chapter, verse): [TRToken, ...]}."""
    out = {}
    for code, b in books.BY_TR.items():
        path = tr_dir / f"{code}.UTR"
        if not path.exists():
            raise FileNotFoundError(path)
        for ch, vs, toks in parse_book(path):
            out[(b["book_id"], ch, vs)] = toks
    return out
