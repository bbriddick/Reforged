#!/usr/bin/env python3
"""Generate Reforged study-data JSON from public-domain CrossWire SWORD modules.

Pipeline: download each module's rawzip from crosswire.org -> extract with `mod2imp`
(from libsword; `brew install sword`) -> clean OSIS/ThML markup to plain text (scripture
refs are reduced to their readable text so BibleReferenceScanner re-links them on the Swift
side) -> write JSON keyed by verse ("Genesis 1:1") for commentaries or by headword/topic for
dictionaries and topical works.

Small reference works are written to Reforged/Resources/ to be bundled. The four large
commentaries are written to Scripts/dist/ instead — they are hosted on a CDN and downloaded
on demand by CommentaryDownloadManager, so they are NOT bundled.

EXCLUDED by license (do not add — bundling reformatted copies is disallowed):
  NETnotesfree (NET Bible notes, © Biblical Studies Press — "cannot be decomposed/
  reconstructed in any other format"), SBLGNTApp (© Logos + SBL), VarApp (SBL/ABS material).

Usage:
  brew install sword
  python3 Scripts/generate_sword_modules.py            # all modules
  python3 Scripts/generate_sword_modules.py Easton     # one module
"""

import html
import json
import os
import re
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Reforged" / "Resources"
DIST = ROOT / "Scripts" / "dist"
WORK = ROOT / "Scripts" / ".sword-work"

RAWZIP = "https://crosswire.org/ftpmirror/pub/sword/packages/rawzip/{}.zip"

# module -> ("commentary" | "reference", bundled?)
MODULES = {
    "Scofield": ("commentary", True),
    "Easton": ("reference", True),
    "AbbottSmith": ("reference", True),
    "Nave": ("reference", True),
    "TCR": ("reference", True),
    "MHC": ("commentary", False),
    "Barnes": ("commentary", False),
    "TDavid": ("commentary", False),
    "CalvinCommentaries": ("commentary", False),
}

ROMAN = {"I": "1", "II": "2", "III": "3"}

REF_RE = re.compile(r"<reference[^>]*>(.*?)</reference>", re.I | re.S)
REF2_RE = re.compile(r"<ref\b[^>]*>(.*?)</ref>", re.I | re.S)
TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"[ \t]+")
NL_RE = re.compile(r"\n{3,}")
VERSE_KEY_RE = re.compile(r"^(I{1,3}) (.+ \d+:\d+)$")


def clean(text):
    text = REF_RE.sub(lambda m: m.group(1), text)
    text = REF2_RE.sub(lambda m: m.group(1), text)
    text = re.sub(r"</p\s*>", "\n\n", text, flags=re.I)
    text = re.sub(r"<p\b[^>]*>", "", text, flags=re.I)
    text = re.sub(r"<lb\s*/?>|<br\s*/?>", "\n", text, flags=re.I)
    text = TAG_RE.sub("", text)
    text = html.unescape(text)
    text = WS_RE.sub(" ", text)
    text = NL_RE.sub("\n\n", text)
    return text.strip()


def normalize_verse_key(key):
    """Map SWORD book names to BibleData.books, e.g. 'I Corinthians 1:1' -> '1 Corinthians 1:1',
    'Revelation of John 1:1' -> 'Revelation 1:1'. (CommentaryService also does this at load time.)"""
    if key.startswith("Revelation of John "):
        key = "Revelation " + key[len("Revelation of John "):]
    m = VERSE_KEY_RE.match(key)
    if m and m.group(1) in ROMAN:
        return f"{ROMAN[m.group(1)]} {m.group(2)}"
    return key


def extract(name, kind):
    zpath = WORK / f"{name}.zip"
    if not zpath.exists():
        WORK.mkdir(parents=True, exist_ok=True)
        print(f"  downloading {name} ...")
        urllib.request.urlretrieve(RAWZIP.format(name), zpath)
    dest = WORK / name
    if not dest.exists():
        with zipfile.ZipFile(zpath) as z:
            z.extractall(dest)

    conf = next((dest / "mods.d").glob("*.conf"))
    conf_text = conf.read_text(encoding="utf-8", errors="ignore")
    modname = re.search(r"^\s*\[([^\]]+)\]", conf_text, re.M).group(1)
    enc_m = re.search(r"^\s*Encoding\s*=\s*(\S+)", conf_text, re.M)
    enc = "utf-8" if (enc_m and enc_m.group(1).lower().startswith("utf")) else "latin-1"

    env = dict(os.environ, SWORD_PATH=str(dest))
    raw = subprocess.run(["mod2imp", modname], env=env, capture_output=True).stdout
    stdout = raw.decode(enc, errors="replace")

    entries = {}
    key, buf = None, []
    for line in stdout.splitlines():
        if line.startswith("$$$"):
            if key is not None:
                entries[key] = clean("\n".join(buf))
            key = line[3:].strip()
            if kind == "commentary":
                key = normalize_verse_key(key)
            buf = []
        else:
            buf.append(line)
    if key is not None:
        entries[key] = clean("\n".join(buf))
    return {k: v for k, v in entries.items() if v}


def main():
    wanted = sys.argv[1:] or list(MODULES)
    RESOURCES.mkdir(parents=True, exist_ok=True)
    DIST.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        kind, bundled = MODULES[name]
        entries = extract(name, kind)
        out_dir = RESOURCES if bundled else DIST
        path = out_dir / f"{name}.json"
        blob = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
        path.write_text(blob, encoding="utf-8")
        mb = len(blob.encode("utf-8")) / 1_048_576
        where = "bundled" if bundled else "dist (host on CDN)"
        print(f"{name:20} {len(entries):>7} entries  {mb:>7.2f} MB  -> {where}")


if __name__ == "__main__":
    main()
