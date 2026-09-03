#!/usr/bin/env python3
"""Generate Reforged/Resources/SpurgeonMorningEvening.json from the CrossWire SME module.

C. H. Spurgeon's "Morning and Evening: Daily Readings" (public domain, via CCEL). Extracted
with `mod2imp` (libsword) like the other SWORD data. Each of the 366 daily entries (keyed
"MM.DD") has an `.am` (Morning) and `.pm` (Evening) section; we parse each into a title, the
opening verse quote, its scripture reference, and the body prose. Scripture references are
reduced to their readable text so `LinkedScriptureText` re-links them in the reader.

Usage:
  brew install sword
  python3 Scripts/generate_spurgeon_devotional.py
"""

import html
import json
import os
import re
import subprocess
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Reforged" / "Resources" / "SpurgeonMorningEvening.json"
WORK = ROOT / "Scripts" / ".sword-work"
RAWZIP = "https://crosswire.org/ftpmirror/pub/sword/packages/rawzip/SME.zip"

MONTHS = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]

REF_RE = re.compile(r"<reference[^>]*>(.*?)</reference>", re.I | re.S)
HI_RE = re.compile(r"<hi\b[^>]*>(.*?)</hi>", re.I | re.S)
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
SECTION_RE = re.compile(r'<div type="section" osisID="[^"]*\.(am|pm)">(.*?)</div>', re.I | re.S)
P_RE = re.compile(r"<p\b[^>]*>(.*?)</p>", re.I | re.S)
TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"[ \t]+")


def strip_tags(text):
    text = REF_RE.sub(lambda m: m.group(1), text)   # keep readable reference text
    text = HI_RE.sub(lambda m: m.group(1), text)     # keep italic/small-caps inner text
    text = TAG_RE.sub("", text)
    text = html.unescape(text)
    return WS_RE.sub(" ", text).strip()


def parse_section(body):
    title = strip_tags(TITLE_RE.search(body).group(1)) if TITLE_RE.search(body) else ""
    paragraphs = P_RE.findall(body)
    verse, reference = "", ""
    if paragraphs:
        first = paragraphs[0]
        hi = HI_RE.search(first)
        if hi:
            verse = strip_tags(hi.group(1))
        ref = REF_RE.search(first)
        if ref:
            reference = strip_tags(ref.group(1))
    prose = [strip_tags(p) for p in paragraphs[1:]]
    prose = [p for p in prose if p]
    return {"title": title, "verse": verse, "reference": reference,
            "body": "\n\n".join(prose)}


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    zpath = WORK / "SME.zip"
    if not zpath.exists():
        print(f"downloading {RAWZIP} ...")
        urllib.request.urlretrieve(RAWZIP, zpath)
    dest = WORK / "SME"
    if not dest.exists():
        with zipfile.ZipFile(zpath) as z:
            z.extractall(dest)

    env = dict(os.environ, SWORD_PATH=str(dest))
    raw = subprocess.run(["mod2imp", "SME"], env=env, capture_output=True).stdout.decode("utf-8", "replace")

    days = []
    key, buf = None, []

    def flush():
        if key is None:
            return
        blob = "\n".join(buf)
        month, day = key.split(".")
        label = f"{MONTHS[int(month) - 1]} {int(day)}"
        sections = {kind: sec for kind, sec in SECTION_RE.findall(blob)}
        days.append({
            "key": key,
            "label": label,
            "morning": parse_section(sections.get("am", "")),
            "evening": parse_section(sections.get("pm", "")),
        })

    for line in raw.splitlines():
        if line.startswith("$$$"):
            flush()
            key, buf = line[3:].strip(), []
        else:
            buf.append(line)
    flush()

    days.sort(key=lambda d: d["key"])
    for i, d in enumerate(days, start=1):
        d["day"] = i

    OUTPUT.write_text(json.dumps({"days": days}, ensure_ascii=False, separators=(",", ":")),
                      encoding="utf-8")
    mb = OUTPUT.stat().st_size / 1_048_576
    print(f"Wrote {OUTPUT} ({mb:.2f} MB): {len(days)} days")


if __name__ == "__main__":
    main()
