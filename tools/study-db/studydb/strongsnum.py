"""Strong's number normalisation shared by every parser."""
import re

_RE = re.compile(r"^([GgHh])?0*(\d+)([a-zA-Z]?)$")


def norm(raw: str, prefix: str | None = None, keep_suffix: bool = False) -> str | None:
    """'H07225' -> 'H7225', 'G0040H' -> 'G40', '1401' + prefix 'G' -> 'G1401'.

    Suffix letters (STEPBible extended Strong's, Open Scriptures lemma types) are dropped unless
    keep_suffix is set. Returns None for anything that is not a Strong's number.
    """
    raw = raw.strip()
    m = _RE.match(raw)
    if not m:
        return None
    pre = (m.group(1) or prefix or "").upper()
    if not pre:
        return None
    num = int(m.group(2))
    if num == 0:
        return None
    return f"{pre}{num}" + (m.group(3).lower() if keep_suffix else "")
