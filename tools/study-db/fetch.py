#!/usr/bin/env python3
"""Fetch every pinned source into sources/<name>/ and write sources.lock.json.

Downloaded content is treated as data only. Nothing here is executed.
Run:  python3 -I tools/study-db/fetch.py
"""
import hashlib
import json
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / "sources"
PINS = json.loads((HERE / "sources.json").read_text())
LOCK = {}


def run(args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True, stdout=subprocess.DEVNULL)


def fetch_git(name, spec):
    dest = SRC / name
    commit = spec["commit"]
    if not (dest / ".git").exists():
        dest.mkdir(parents=True, exist_ok=True)
        run(["git", "init", "-q"], cwd=dest)
        run(["git", "remote", "add", "origin", f"https://github.com/{spec['repo']}.git"], cwd=dest)
        if spec.get("sparse"):
            run(["git", "config", "core.sparseCheckout", "true"], cwd=dest)
            (dest / ".git" / "info").mkdir(exist_ok=True)
            (dest / ".git" / "info" / "sparse-checkout").write_text("\n".join(spec["sparse"]) + "\n")
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=dest, capture_output=True, text=True).stdout.strip()
    if head != commit:
        run(["git", "fetch", "--depth", "1", "-q", "origin", commit], cwd=dest)
        run(["git", "checkout", "-q", "FETCH_HEAD"], cwd=dest)
    if spec.get("sparse"):
        (dest / ".git" / "info" / "sparse-checkout").write_text("\n".join(spec["sparse"]) + "\n")
        run(["git", "read-tree", "-mu", "HEAD"], cwd=dest)
    LOCK[name] = {"repo": spec["repo"], "commit": commit}
    print(f"  {name:12s} {spec['repo']} @ {commit[:10]}")


def fetch_crosswire(name, spec):
    dest = SRC / f"crosswire-{name}"
    dest.mkdir(parents=True, exist_ok=True)
    zpath = dest / f"{name}.zip"
    if not zpath.exists():
        urllib.request.urlretrieve(spec["url"], zpath)
    digest = hashlib.sha256(zpath.read_bytes()).hexdigest()
    pinned = spec.get("sha256")
    if pinned and pinned != digest:
        sys.exit(f"SHA-256 mismatch for {name}: expected {pinned}, got {digest}")
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest / "module")
    LOCK[f"crosswire-{name}"] = {"url": spec["url"], "sha256": digest, "bytes": zpath.stat().st_size}
    print(f"  crosswire-{name:5s} sha256 {digest[:16]}  {zpath.stat().st_size:,} bytes")


def main():
    SRC.mkdir(exist_ok=True)
    print("Fetching pinned sources")
    for name, spec in PINS["git"].items():
        fetch_git(name, spec)
    for name, spec in PINS["crosswire"].items():
        fetch_crosswire(name, spec)
    (HERE / "sources.lock.json").write_text(json.dumps(LOCK, indent=2, sort_keys=True) + "\n")
    print("Wrote sources.lock.json")


if __name__ == "__main__":
    main()
