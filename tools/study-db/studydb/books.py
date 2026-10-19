"""Book table and per-source name maps.

book_id is the standard 1..66 Protestant order, which matches the numbering already used by
the app's bundled kjvpce/trparsed/wlc JSON (Philippians = 50). Verse IDs are BBCCCVVV.
"""

# (book_id, osis, name, testament, kjv_imp_name, tr_file, tagnt_code)
_ROWS = [
    (1, "Gen", "Genesis", "OT", "Genesis", None, None),
    (2, "Exod", "Exodus", "OT", "Exodus", None, None),
    (3, "Lev", "Leviticus", "OT", "Leviticus", None, None),
    (4, "Num", "Numbers", "OT", "Numbers", None, None),
    (5, "Deut", "Deuteronomy", "OT", "Deuteronomy", None, None),
    (6, "Josh", "Joshua", "OT", "Joshua", None, None),
    (7, "Judg", "Judges", "OT", "Judges", None, None),
    (8, "Ruth", "Ruth", "OT", "Ruth", None, None),
    (9, "1Sam", "1 Samuel", "OT", "I Samuel", None, None),
    (10, "2Sam", "2 Samuel", "OT", "II Samuel", None, None),
    (11, "1Kgs", "1 Kings", "OT", "I Kings", None, None),
    (12, "2Kgs", "2 Kings", "OT", "II Kings", None, None),
    (13, "1Chr", "1 Chronicles", "OT", "I Chronicles", None, None),
    (14, "2Chr", "2 Chronicles", "OT", "II Chronicles", None, None),
    (15, "Ezra", "Ezra", "OT", "Ezra", None, None),
    (16, "Neh", "Nehemiah", "OT", "Nehemiah", None, None),
    (17, "Esth", "Esther", "OT", "Esther", None, None),
    (18, "Job", "Job", "OT", "Job", None, None),
    (19, "Ps", "Psalms", "OT", "Psalms", None, None),
    (20, "Prov", "Proverbs", "OT", "Proverbs", None, None),
    (21, "Eccl", "Ecclesiastes", "OT", "Ecclesiastes", None, None),
    (22, "Song", "Song of Solomon", "OT", "Song of Solomon", None, None),
    (23, "Isa", "Isaiah", "OT", "Isaiah", None, None),
    (24, "Jer", "Jeremiah", "OT", "Jeremiah", None, None),
    (25, "Lam", "Lamentations", "OT", "Lamentations", None, None),
    (26, "Ezek", "Ezekiel", "OT", "Ezekiel", None, None),
    (27, "Dan", "Daniel", "OT", "Daniel", None, None),
    (28, "Hos", "Hosea", "OT", "Hosea", None, None),
    (29, "Joel", "Joel", "OT", "Joel", None, None),
    (30, "Amos", "Amos", "OT", "Amos", None, None),
    (31, "Obad", "Obadiah", "OT", "Obadiah", None, None),
    (32, "Jonah", "Jonah", "OT", "Jonah", None, None),
    (33, "Mic", "Micah", "OT", "Micah", None, None),
    (34, "Nah", "Nahum", "OT", "Nahum", None, None),
    (35, "Hab", "Habakkuk", "OT", "Habakkuk", None, None),
    (36, "Zeph", "Zephaniah", "OT", "Zephaniah", None, None),
    (37, "Hag", "Haggai", "OT", "Haggai", None, None),
    (38, "Zech", "Zechariah", "OT", "Zechariah", None, None),
    (39, "Mal", "Malachi", "OT", "Malachi", None, None),
    (40, "Matt", "Matthew", "NT", "Matthew", "MT", "Mat"),
    (41, "Mark", "Mark", "NT", "Mark", "MR", "Mrk"),
    (42, "Luke", "Luke", "NT", "Luke", "LU", "Luk"),
    (43, "John", "John", "NT", "John", "JOH", "Jhn"),
    (44, "Acts", "Acts", "NT", "Acts", "AC", "Act"),
    (45, "Rom", "Romans", "NT", "Romans", "RO", "Rom"),
    (46, "1Cor", "1 Corinthians", "NT", "I Corinthians", "1CO", "1Co"),
    (47, "2Cor", "2 Corinthians", "NT", "II Corinthians", "2CO", "2Co"),
    (48, "Gal", "Galatians", "NT", "Galatians", "GA", "Gal"),
    (49, "Eph", "Ephesians", "NT", "Ephesians", "EPH", "Eph"),
    (50, "Phil", "Philippians", "NT", "Philippians", "PHP", "Php"),
    (51, "Col", "Colossians", "NT", "Colossians", "COL", "Col"),
    (52, "1Thess", "1 Thessalonians", "NT", "I Thessalonians", "1TH", "1Th"),
    (53, "2Thess", "2 Thessalonians", "NT", "II Thessalonians", "2TH", "2Th"),
    (54, "1Tim", "1 Timothy", "NT", "I Timothy", "1TI", "1Ti"),
    (55, "2Tim", "2 Timothy", "NT", "II Timothy", "2TI", "2Ti"),
    (56, "Titus", "Titus", "NT", "Titus", "TIT", "Tit"),
    (57, "Phlm", "Philemon", "NT", "Philemon", "PHM", "Phm"),
    (58, "Heb", "Hebrews", "NT", "Hebrews", "HEB", "Heb"),
    (59, "Jas", "James", "NT", "James", "JAS", "Jas"),
    (60, "1Pet", "1 Peter", "NT", "I Peter", "1PE", "1Pe"),
    (61, "2Pet", "2 Peter", "NT", "II Peter", "2PE", "2Pe"),
    (62, "1John", "1 John", "NT", "I John", "1JO", "1Jn"),
    (63, "2John", "2 John", "NT", "II John", "2JO", "2Jn"),
    (64, "3John", "3 John", "NT", "III John", "3JO", "3Jn"),
    (65, "Jude", "Jude", "NT", "Jude", "JUDE", "Jud"),
    (66, "Rev", "Revelation", "NT", "Revelation of John", "RE", "Rev"),
]

BOOKS = [dict(book_id=r[0], osis=r[1], name=r[2], testament=r[3], kjv=r[4], tr=r[5], tagnt=r[6]) for r in _ROWS]
BY_ID = {b["book_id"]: b for b in BOOKS}
BY_OSIS = {b["osis"]: b for b in BOOKS}
BY_KJV_NAME = {b["kjv"]: b for b in BOOKS}
BY_TAGNT = {b["tagnt"]: b for b in BOOKS if b["tagnt"]}
BY_TR = {b["tr"]: b for b in BOOKS if b["tr"]}

# OSIS book ids as written in morphhb VerseMap/XML and KJV module, which sometimes differ in case
# or spelling from the names above. Only the ones that differ are listed.
OSIS_ALIASES = {"Phlm": "Phlm", "Philem": "Phlm", "Jas": "Jas", "Jam": "Jas"}


def verse_id(book_id: int, chapter: int, verse: int) -> int:
    return book_id * 1_000_000 + chapter * 1_000 + verse
