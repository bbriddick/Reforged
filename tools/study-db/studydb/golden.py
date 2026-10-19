"""Golden cases (spec 10.1). Each is checked through studydb.query against the built database."""
from . import query as Q

NT = lambda book, c, v: Q.verse_id(book, c, v)


import unicodedata

_n = lambda x: unicodedata.normalize("NFC", x)


def _starts(s):
    return lambda v: isinstance(v, str) and _n(v).startswith(_n(s))


def _has(s):
    return lambda v: isinstance(v, str) and _n(s) in _n(v)


CASES = [
    dict(name="Phil 1:1 servants (spec golden)", verse=NT(50, 1, 1), word="servants", expect={
        "strongs": "G1401", "language": "Greek", "match_quality": "exact",
        "original.surface": "δουλοι", "original.accented": "δοῦλοι", "original.morph": "N-NPM",
        "original.morph_expansion": "Noun · Nominative · Plural · Masculine",
        "entry.lemma": "δοῦλος", "entry.translit": "doûlos", "entry.pron": "doo'-los",
        "entry.definition": _starts("a slave (literal or figurative, involuntary or voluntary"),
        "entry.kjv_def": "bond(-man), servant", "entry.derivation": _has("δέω"),
        "usage": [("servant", 120), ("bond", 6), ("bondman", 1)], "occurrences": 127,
        "long_entries.0.source": "abbott-smith"}),
    dict(name="Gen 1:1 God (Hebrew)", verse=NT(1, 1, 1), word="God", expect={
        "strongs": "H430", "language": "Hebrew", "original.surface": "אֱלֹהִים", "original.morph": "HNcmpa",
        "entry.lemma": "אֱלֹהִים", "match_quality": "exact", "long_entries.0.source": "bdb"}),
    dict(name="Gen 1:1 created (two Strong's, object marker skipped)", verse=NT(1, 1, 1), word="created", expect={
        "strongs": "H1254", "original.surface": "בָּרָא"}),
    dict(name="Dan 2:4 O king (Aramaic)", verse=NT(27, 2, 4), word="king", occurrence=1, expect={
        "language": "Aramaic", "strongs": "H4430", "original.surface": "מַלְכָּא"}),
    dict(name="Mal 4:1 (KJV 4 = Hebrew Mal 3:19)", verse=NT(39, 4, 1), word="day", expect={
        "strongs": "H3117", "original.surface": "הַיּוֹם"}),
    dict(name="John 3:16 loved (Greek verb)", verse=NT(43, 3, 16), word="loved", expect={
        "strongs": "G25", "original.accented": "ἠγάπησεν", "original.morph": "V-AAI-3S",
        "original.morph_expansion": "Verb · Aorist · Active · Indicative · 3rd Person · Singular",
        "entry.lemma": "ἀγαπάω"}),
    dict(name="John 1:1 Word", verse=NT(43, 1, 1), word="Word", expect={
        "strongs": "G3056", "original.accented": "λόγος", "original.morph": "N-NSM", "entry.lemma": "λόγος"}),
    dict(name="Rom 3:23 sinned (second aorist)", verse=NT(45, 3, 23), word="sinned", expect={
        "strongs": "G264", "original.morph": "V-2AAI-3P", "entry.lemma": "ἁμαρτάνω"}),
    dict(name="1 Cor 13:4 charity", verse=NT(46, 13, 4), word="charity", expect={
        "strongs": "G26", "original.accented": "ἀγάπη", "entry.lemma": "ἀγάπη"}),
    dict(name="Ps 23:1 shepherd", verse=NT(19, 23, 1), word="shepherd", expect={
        "strongs": "H7462", "language": "Hebrew"}),
    dict(name="Ps 3:1 title folded into verse 1 (Lord)", verse=NT(19, 3, 1), word="Lord", expect={
        "strongs": "H3068", "language": "Hebrew"}),
    dict(name="Matt 1:1 genealogy name", verse=NT(40, 1, 1), word="Abraham", expect={
        "strongs": "G11", "original.accented": "Ἀβραάμ"}),
]
