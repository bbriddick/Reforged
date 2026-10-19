"""KJV usage frequency per Strong's number (spec 6.4).

A tagged phrase is reduced to the translation the lexicon itself lists. The Strong's `kjv_def`
is split into translation items ("bond(-man), servant" -> bond, bondman, servant;
"be vexed" stays a two-word item) and a phrase is assigned to the most specific item whose
stemmed words all occur in the phrase, so `hath`, `had`, `having` all count under `have` and
`the servants` under `servant`. Phrases that match no item are reduced by stripping function
words; phrases that are only function words (`of`, `unto`, `the`) are not a translation and
are not counted (that is how G1401 totals 127 rather than its 140 tagged tokens).
"""
import re
from collections import Counter, defaultdict

from .kjv import per_strongs

STOP_FUNC = set("""
a an the of to unto in into on upon at by for with from and or but nor yet o oh is are was were
be been being am art wast wert do doth did done have hath had shall will would should may might
can could not no nay though although as so if then than there here such also even only more most
very too out up down over under about after before through while whiles when where whence
thence whereof wherein
""".split())
# Translations of a pronoun Strong's number are themselves pronouns ("my", "us", "thy"), so these
# only count as function words for tokens that are not pronouns.
STOP_PRON = set("""
that which who whom whose what thou thee thy thine he his him she her hers they them their
theirs it its i me my mine we us our ours ye you your yours this these those
""".split())
STOP = STOP_FUNC | STOP_PRON
_PRONOUN_MORPH = set("PFSRDKIXCQ")

_IRREGULAR = {
    # to be
    "is": "be", "are": "be", "was": "be", "were": "be", "been": "be", "being": "be", "am": "be",
    "art": "be", "wast": "be", "wert": "be", "beest": "be",
    # to have / do
    "has": "have", "hath": "have", "had": "have", "having": "have", "hast": "have",
    "does": "do", "doth": "do", "doeth": "do", "did": "do", "done": "do", "doing": "do", "didst": "do", "doest": "do",
    # common irregulars
    "said": "say", "saith": "say", "saying": "say", "says": "say", "saidst": "say", "sayest": "say",
    "went": "go", "gone": "go", "goeth": "go", "going": "go", "goest": "go",
    "came": "come", "cometh": "come", "coming": "come", "comest": "come",
    "made": "make", "maketh": "make", "making": "make", "makest": "make",
    "took": "take", "taken": "take", "taketh": "take", "taking": "take",
    "gave": "give", "given": "give", "giveth": "give", "giving": "give", "gavest": "give",
    "saw": "see", "seen": "see", "seeth": "see", "seeing": "see", "sawest": "see",
    "knew": "know", "known": "know", "knoweth": "know", "knowing": "know", "knowest": "know",
    "spake": "speak", "spoken": "speak", "speaketh": "speak", "speaking": "speak", "spakest": "speak",
    "heard": "hear", "heareth": "hear", "hearing": "hear", "hearest": "hear",
    "wrote": "write", "written": "write", "writeth": "write",
    "brought": "bring", "bringeth": "bring", "bringing": "bring",
    "sent": "send", "sendeth": "send", "sending": "send",
    "set": "set", "setteth": "set", "setting": "set",
    "found": "find", "findeth": "find", "finding": "find",
    "left": "leave", "leaveth": "leave", "leaving": "leave",
    "stood": "stand", "standeth": "stand", "standing": "stand",
    "sat": "sit", "sitteth": "sit", "sitting": "sit",
    "rose": "rise", "risen": "rise", "riseth": "rise", "rising": "rise",
    "fell": "fall", "fallen": "fall", "falleth": "fall", "falling": "fall",
    "told": "tell", "telleth": "tell", "telling": "tell",
    "kept": "keep", "keepeth": "keep", "keeping": "keep",
    "ate": "eat", "eaten": "eat", "eateth": "eat", "eating": "eat",
    "drank": "drink", "drunk": "drink", "drunken": "drink", "drinketh": "drink",
    "slew": "slay", "slain": "slay", "died": "die", "dieth": "die", "dying": "die",
    "men": "man", "women": "woman", "children": "child", "feet": "foot", "teeth": "tooth",
    "oxen": "ox", "lives": "life", "wives": "wife", "loaves": "loaf", "knives": "knife",
    "thieves": "thief", "leaves": "leaf", "selves": "self"}
PUNCT = re.compile(r"[^\w\s'’-]", re.UNICODE)


def stem(word: str) -> str:
    """Aggressive normaliser so inflected/archaic forms of one word compare equal."""
    w = word.lower().strip("-'’")
    if w in _IRREGULAR:
        w = _IRREGULAR[w]
    else:
        for suf in ("eth", "est", "ing", "ed", "es", "s", "d", "en", "th"):
            if len(w) - len(suf) >= 3 and w.endswith(suf) and not (suf == "s" and w.endswith("ss")):
                w = w[: -len(suf)]
                break
    # the same ending normalisation for every path, so `have`, `having`, `hath` all land on one stem
    if w.endswith("ie") and len(w) > 3:
        w = w[:-2] + "y"
    elif w.endswith("i") and len(w) > 3:
        w = w[:-1] + "y"
    if w.endswith("e") and len(w) > 3:
        w = w[:-1]
    if len(w) > 3 and w[-1] == w[-2] and w[-1] not in "aeiouls":
        w = w[:-1]
    return w


def words_of(phrase: str) -> list[str]:
    s = phrase.lower().replace("’s", "").replace("'s", "")
    s = PUNCT.sub(" ", s)
    return [w.strip("-'’") for w in s.split() if w.strip("-'’")]


def _top_level_split(s: str) -> list[str]:
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        if ch in ",;" and depth == 0:
            parts.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))
    return parts


def _join(base: str, suffix: str) -> str:
    """bond + man -> bondman; love + ed -> loved; serve + ice -> service."""
    if base.endswith("e") and suffix[:1] in "aeiouy":
        return base[:-1] + suffix
    return base + suffix


def kjv_items(kjv_def: str) -> list[str]:
    """Candidate translation items from a Strong's kjv_def, e.g. 'bond(-man), servant'."""
    if not kjv_def:
        return []
    s = kjv_def.lower()
    for junk in ("×", "[idiom]", "[phrase]", "+", "*", "…", "etc."):
        s = s.replace(junk, " ")
    items: list[str] = []
    for part in _top_level_split(s):
        part = part.strip()
        if not part:
            continue
        cands = set()
        # word(-suffix): bond(-man) -> bond, bondman
        for m in re.finditer(r"([a-z'’-]+)\(((?:\s*-[a-z]+\s*,?)+)\)", part):
            cands.add(m.group(1))
            for suf in re.findall(r"-([a-z]+)", m.group(2)):
                cands.add(_join(m.group(1), suf))
        plain = re.sub(r"\(\s*-[a-z][a-z, -]*\)", " ", part)
        groups = re.findall(r"\(([^)]*)\)", plain)
        cands.add(re.sub(r"\([^)]*\)", " ", plain))                 # parentheticals removed
        cands.add(re.sub(r"\(([^)]*)\)", r" \1 ", plain))           # parentheticals inlined
        for g in groups:                                              # right (hand, side)
            base = re.sub(r"\([^)]*\)", " ", plain).strip()
            for alt in re.split(r"[,;]", g):
                if alt.strip():
                    cands.add(f"{base} {alt}")
                    cands.add(alt)
        for c in cands:
            ws = [w.strip("-'’") for w in re.split(r"[^a-z'’-]+", c) if w.strip("-'’") and w != "etc"]
            # drop words whose stem repeats ("god gods" -> "god")
            kept, seen_st = [], set()
            for w in ws:
                if stem(w) not in seen_st:
                    seen_st.add(stem(w)); kept.append(w)
            if 0 < len(kept) <= 4:
                items.append(" ".join(kept))
    seen, out = set(), []
    for it in items:
        if it not in seen:
            seen.add(it); out.append(it)
    return out


def _item_stems(item: str) -> tuple:
    return tuple(stem(w) for w in item.split())


def translation_word(phrase: str, items: list[str], pronoun: bool = False) -> str | None:
    ws = words_of(phrase)
    if not ws:
        return None
    wset = set(ws)
    pstems = {stem(w) for w in ws}
    best, best_key = None, None
    for it in items:
        st = _item_stems(it)
        if not all(x in pstems for x in st):
            continue
        # exact surface match beats a stem match; then the most specific (most words) item
        exact = all(w in wset for w in it.split())
        key = (exact, len(st))
        if best_key is None or key > best_key:
            best, best_key = it, key
    if best:
        return best
    stop = STOP_FUNC if pronoun else STOP
    content = [w for w in ws if w not in stop and stem(w) not in stop]
    if not content:
        return None
    return " ".join(content[:-1] + [_singular(content[-1])])


def _singular(w: str) -> str:
    if w.endswith("selves"):
        return w[:-3] + "f"
    if len(w) <= 3 or not w.endswith("s") or w.endswith(("ss", "us", "is", "ous")):
        return w
    if w.endswith("ies") and len(w) > 4:
        return w[:-3] + "y"
    if w.endswith(("shes", "ches", "xes", "zes", "sses")):
        return w[:-2]
    return w[:-1]


def _display(phrase: str, word: str) -> str:
    for raw in re.split(r"\s+", PUNCT.sub(" ", phrase.replace("’s", "").replace("'s", ""))):
        r = raw.strip("-'’")
        if r and (r.lower() == word or stem(r) == stem(word)):
            return r
    return word


def compute(verses, entries):
    """Return ({strongs: Counter(word->count)}, {strongs: set(verse_key)}).

    Capitalised when most occurrences were ("God", "Lord"), so the UI shows the word as the
    KJV prints it.
    """
    usage = defaultdict(Counter)
    caps = defaultdict(Counter)
    occ = defaultdict(set)
    items_cache = {}
    for v in verses:
        key = (v.book_id, v.chapter, v.verse)
        for t in v.tokens:
            for idx, s in enumerate(t.strongs):
                occ[s].add(key)
                morph = per_strongs(t.morphs, t.strongs, idx) or ""
                if s not in items_cache:
                    e = entries.get(s)
                    items_cache[s] = kjv_items(e.kjv_def) if e else []
                e = entries.get(s)
                pron = (morph[:1] in _PRONOUN_MORPH and "-" in morph) \
                    or "pron" in ((e.pos if e else "") or "")
                w = translation_word(t.word, items_cache[s], pron)
                if w:
                    usage[s][w] += 1
                    if len(w.split()) == 1 and _display(t.word, w)[:1].isupper():
                        caps[s][w] += 1
    final = {}
    for s, c in usage.items():
        out = Counter()
        for w, n in c.items():
            shown = w[:1].upper() + w[1:] if caps[s][w] * 2 > n else w
            out[shown] += n
        final[s] = out
    return final, occ
