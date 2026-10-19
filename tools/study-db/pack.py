#!/usr/bin/env python3
"""Pack out/reforged-study.sqlite into the app resource out/reforged-study.rsdb.

    python3 -I tools/study-db/pack.py            # writes out/reforged-study.rsdb
    python3 -I tools/study-db/pack.py --install  # also copies it to Reforged/Resources/

Container (little-endian):
    8 bytes   magic  b"RSDB1\\0\\0\\0"
    u32       header JSON length, then the JSON: data_version, schema_version, raw_bytes, sha256,
              chunk_size, chunks
    per chunk u32 compressed length, u32 raw length, raw-DEFLATE bytes (what Apple's
              Compression `.zlib` decodes), 2 MiB of raw data per chunk

Chunking lets the app decompress with a few MB of memory instead of holding 67 MB twice.
"""
import hashlib
import json
import shutil
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
CHUNK = 2 * 1024 * 1024
MAGIC = b"RSDB1\0\0\0"


def pack(src: Path, manifest: dict, dst: Path) -> dict:
    raw = src.read_bytes()
    chunks = [raw[i:i + CHUNK] for i in range(0, len(raw), CHUNK)]
    header = {
        "data_version": manifest["data_version"], "schema_version": manifest["schema_version"],
        "raw_bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
        "chunk_size": CHUNK, "chunks": len(chunks),
    }
    hj = json.dumps(header, sort_keys=True).encode()
    with open(dst, "wb") as f:
        f.write(MAGIC + struct.pack("<I", len(hj)) + hj)
        for c in chunks:
            co = zlib.compressobj(9, zlib.DEFLATED, -15)
            z = co.compress(c) + co.flush()
            f.write(struct.pack("<II", len(z), len(c)) + z)
    return header


def main() -> int:
    src = OUT / "reforged-study.sqlite"
    manifest = json.loads((OUT / "manifest.json").read_text())
    if hashlib.sha256(src.read_bytes()).hexdigest() != manifest["sha256"]:
        sys.exit("manifest.json does not match reforged-study.sqlite; run build.py first")
    dst = OUT / "reforged-study.rsdb"
    h = pack(src, manifest, dst)
    print(f"packed {h['raw_bytes'] / 1e6:.1f} MB -> {dst.stat().st_size / 1e6:.1f} MB "
          f"({h['chunks']} chunks, data_version {h['data_version']})")
    if "--install" in sys.argv:
        target = HERE.parent.parent / "Reforged" / "Resources" / "reforged-study.rsdb"
        shutil.copyfile(dst, target)
        print(f"installed {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
