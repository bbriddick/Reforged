"""Morphology code expansion: Robinson (Greek NT) and Open Scriptures OSHB (Hebrew OT)."""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

SEP = " · "

_CASE = {"N": "Nominative", "G": "Genitive", "D": "Dative", "A": "Accusative", "V": "Vocative"}
_NUM = {"S": "Singular", "P": "Plural"}
_GEN = {"M": "Masculine", "F": "Feminine", "N": "Neuter"}
_PERSON = {"1": "1st Person", "2": "2nd Person", "3": "3rd Person"}
_TENSE = {"P": "Present", "I": "Imperfect", "F": "Future", "2F": "Second Future", "A": "Aorist",
          "2A": "Second Aorist", "R": "Perfect", "2R": "Second Perfect", "L": "Pluperfect",
          "2L": "Second Pluperfect", "X": "No Tense Stated"}
_VOICE = {"A": "Active", "M": "Middle", "P": "Passive", "E": "Middle or Passive",
          "D": "Middle Deponent", "O": "Passive Deponent", "N": "Middle or Passive Deponent",
          "Q": "Impersonal Active", "X": "No Voice Stated"}
_MOOD = {"I": "Indicative", "S": "Subjunctive", "O": "Optative", "M": "Imperative", "N": "Infinitive",
         "P": "Participle", "R": "Imperative Participle"}
_POS = {"N": "Noun", "A": "Adjective", "T": "Article", "V": "Verb", "P": "Personal Pronoun",
        "R": "Relative Pronoun", "C": "Reciprocal Pronoun", "D": "Demonstrative Pronoun",
        "K": "Correlative Pronoun", "I": "Interrogative Pronoun", "X": "Indefinite Pronoun",
        "Q": "Correlative or Interrogative Pronoun", "F": "Reflexive Pronoun", "S": "Possessive Pronoun"}
_WORDS = {"ADV": "Adverb", "CONJ": "Conjunction", "COND": "Conditional", "PREP": "Preposition",
          "PRT": "Particle", "INJ": "Interjection", "ARAM": "Aramaic Transliterated Word",
          "HEB": "Hebrew Transliterated Word"}
_SUFFIX = {"S": "Superlative", "C": "Comparative", "K": "Crasis", "I": "Interrogative",
           "N": "Negative", "ATT": "Attic Form", "ABB": "Abbreviated", "P": "Proper Name",
           "M": "Middle Significance", "L": "Location", "T": "Title"}
_INDECL = {"PRI": "Proper Name Indeclinable", "LI": "Letter Indeclinable",
           "OI": "Other Indeclinable", "NUI": "Numeral Indeclinable", "NUI ": "Numeral Indeclinable"}


class MorphError(ValueError):
    pass


def _cng(s: str, out: list, require=True):
    """case, number, gender; any may be absent for infinitives and indeclinables."""
    if not s:
        return
    if len(s) < 2 or s[0] not in _CASE or s[1] not in _NUM or (len(s) > 2 and s[2] not in _GEN) or len(s) > 3:
        raise MorphError(s)
    out.append(_CASE[s[0]]); out.append(_NUM[s[1]])
    if len(s) == 3:
        out.append(_GEN[s[2]])


def expand_robinson(code: str) -> str:
    code = code.strip()
    if code in _WORDS:
        return _WORDS[code]
    parts = code.split("-")
    head = parts[0]
    if head in _WORDS:               # ADV-C, CONJ-N, PRT-I, COND-K ...
        out = [_WORDS[head]]
        for suf in parts[1:]:
            if suf not in _SUFFIX:
                raise MorphError(code)
            out.append(_SUFFIX[suf])
        return SEP.join(out)
    if head not in _POS:
        raise MorphError(code)
    out = [_POS[head]]
    rest = parts[1:]
    suffixes = []
    while rest and rest[-1] in _SUFFIX and len(rest) > 1:
        suffixes.insert(0, rest.pop())
    body = rest[0] if rest else ""
    if head == "V":
        m = re.match(r"^(2?[PIFARLX])([AMPEDONQX])([ISOMNPR])$", body)
        if not m:
            raise MorphError(code)
        out += [_TENSE[m.group(1)], _VOICE[m.group(2)], _MOOD[m.group(3)]]
        tail = rest[1] if len(rest) > 1 else ""
        if tail:
            if re.match(r"^[123][SP]$", tail):
                out += [_PERSON[tail[0]], _NUM[tail[1]]]
            else:
                _cng(tail, out)
        if len(rest) > 2:
            raise MorphError(code)
    elif head in ("P", "F"):
        # person-case-number[-gender]: P-1NS, P-GSM, F-1APM
        if body and body[0] in _PERSON:
            out.append(_PERSON[body[0]])
            body = body[1:]
        _cng(body, out)
    elif head == "S":
        m = re.match(r"^([123])([SP])([NGDAV])([SP])([MFN])$", body)
        if not m:
            raise MorphError(code)
        out += [_PERSON[m.group(1)], "Possessor " + _NUM[m.group(2)],
                _CASE[m.group(3)], _NUM[m.group(4)], _GEN[m.group(5)]]
    else:
        if body in _INDECL:
            out.append(_INDECL[body])
        elif body:
            _cng(body, out)
    for s in suffixes:
        out.append(_SUFFIX[s])
    return SEP.join(out)


def load_oshb(path: Path) -> dict[str, str]:
    """{code: expansion} from morphhb/parsing/Oshm.xml (TEI entryFree n=code)."""
    out = {}
    root = ET.parse(path).getroot()
    for el in root.iter():
        if el.tag.split("}")[-1] == "entryFree" and el.get("n"):
            text = re.sub(r"\s+", " ", "".join(el.itertext())).strip()
            if text:
                out[el.get("n")] = text
    return out


# ---- OSHB (Hebrew / Aramaic) generator, scheme per morphhb/parsing/HebrewMorphologyCodes.html ----
_H_STEM = {"q": "Qal", "N": "Niphal", "p": "Piel", "P": "Pual", "h": "Hiphil", "H": "Hophal",
           "t": "Hithpael", "o": "Polel", "O": "Polal", "r": "Hithpolel", "m": "Poel", "M": "Poal",
           "k": "Palel", "K": "Pulal", "Q": "Qal Passive", "l": "Pilpel", "L": "Polpal",
           "f": "Hithpalpel", "D": "Nithpael", "j": "Pealal", "i": "Pilel", "u": "Hothpaal",
           "c": "Tiphil", "v": "Hishtaphel", "w": "Nithpalel", "y": "Nithpoel", "z": "Hithpoel"}
_A_STEM = {"q": "Peal", "Q": "Peil", "u": "Hithpeel", "p": "Pael", "P": "Ithpaal", "M": "Hithpaal",
           "a": "Aphel", "h": "Haphel", "s": "Saphel", "e": "Shaphel", "H": "Hophal", "i": "Ithpeel",
           "t": "Hishtaphel", "v": "Ishtaphel", "w": "Hithaphel", "o": "Polel", "z": "Ithpoel",
           "r": "Hithpolel", "f": "Hithpalpel", "b": "Hephal", "c": "Tiphel", "m": "Poel",
           "l": "Palpel", "L": "Ithpalpel", "O": "Ithpolel", "G": "Ittaphal"}
_H_VTYPE = {"p": "Perfect", "q": "Sequential Perfect", "i": "Imperfect", "w": "Sequential Imperfect",
            "h": "Cohortative", "j": "Jussive", "v": "Imperative", "r": "Participle Active",
            "s": "Participle Passive", "a": "Infinitive Absolute", "c": "Infinitive Construct"}
_H_ATYPE = {"a": "", "c": "Cardinal Number", "g": "Gentilic", "o": "Ordinal Number"}
_H_NTYPE = {"c": "Common", "g": "Gentilic", "p": "Proper Name"}
_H_PTYPE = {"d": "Demonstrative", "f": "Indefinite", "i": "Interrogative", "p": "Personal", "r": "Relative"}
_H_STYPE = {"d": "Directional He", "h": "Paragogic He", "n": "Paragogic Nun", "p": "Pronominal"}
_H_TTYPE = {"a": "Affirmation", "d": "Definite Article", "e": "Exhortation", "i": "Interrogative",
            "j": "Interjection", "m": "Demonstrative", "n": "Negative", "o": "Direct Object Marker",
            "r": "Relative"}
_H_PERSON = {"1": "1st Person", "2": "2nd Person", "3": "3rd Person"}
_H_GENDER = {"b": "Both", "c": "Common", "f": "Feminine", "m": "Masculine"}
_H_NUMBER = {"d": "Dual", "p": "Plural", "s": "Singular"}
_H_STATE = {"a": "Absolute", "c": "Construct", "d": "Determined"}


def _pick(table, ch, code):
    if ch == "x":
        return None
    if ch not in table:
        raise MorphError(code)
    return table[ch]


def _oshb_segment(seg: str, aramaic: bool, code: str) -> str:
    if not seg:
        raise MorphError(code)
    pos, rest = seg[0], seg[1:]
    out: list = []

    def take(table):
        nonlocal rest
        if not rest:
            return
        v = _pick(table, rest[0], code)
        rest = rest[1:]
        if v:
            out.append(v)

    if pos == "A":
        out.append("Adjective"); take(_H_ATYPE); take(_H_GENDER); take(_H_NUMBER); take(_H_STATE)
    elif pos == "C":
        out.append("Conjunction")
    elif pos == "D":
        out.append("Adverb")
    elif pos == "N":
        out.append("Noun"); take(_H_NTYPE); take(_H_GENDER); take(_H_NUMBER); take(_H_STATE)
    elif pos == "P":
        out.append("Pronoun"); take(_H_PTYPE); take(_H_PERSON); take(_H_GENDER); take(_H_NUMBER)
    elif pos == "R":
        out.append("Preposition")
        if rest:
            take({"d": "Definite Article"})
    elif pos == "S":
        out.append("Suffix"); take(_H_STYPE); take(_H_PERSON); take(_H_GENDER); take(_H_NUMBER)
    elif pos == "T":
        out.append("Particle"); take(_H_TTYPE)
    elif pos == "V":
        out.append("Verb")
        take(_A_STEM if aramaic else _H_STEM)
        vt = rest[0] if rest else ""
        take(_H_VTYPE)
        if vt in ("r", "s"):
            take(_H_GENDER); take(_H_NUMBER); take(_H_STATE)
        elif vt in ("a", "c", ""):
            pass
        else:
            take(_H_PERSON); take(_H_GENDER); take(_H_NUMBER); take(_H_STATE)
    else:
        raise MorphError(code)
    if rest:
        raise MorphError(code)
    return SEP.join(out)


def expand_oshb(code: str, table: dict | None = None) -> str:
    """`HR/Ncfsa` -> 'Preposition + Noun · Common · Feminine · Singular · Absolute'."""
    if table and code in table:
        return table[code]
    if not code or code[0] not in "HA":
        raise MorphError(code)
    aramaic = code[0] == "A"
    segs = [x for x in code[1:].split("/") if x]
    if not segs:
        raise MorphError(code)
    body = " + ".join(_oshb_segment(sg, aramaic, code) for sg in segs)
    return ("Aramaic: " if aramaic else "") + body
