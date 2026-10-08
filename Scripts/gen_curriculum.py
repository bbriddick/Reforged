#!/usr/bin/env python3
"""Generate MemoryCurriculum.swift with accurate public-domain KJV text
read from the bundled Reforged/Resources/kjvpce.json. 15 themed units, 150 verses."""
import json, re, sys, os

KJV_PATH = os.path.join(os.path.dirname(__file__), "..", "Reforged", "Resources", "kjvpce.json")
BOOK_ALIASES = {"Psalm": "Psalms"}

# Build a (book, chapter, verse) -> text index once.
_KJV = json.load(open(KJV_PATH))
_INDEX = {}
for _it in _KJV["verses"]:
    _INDEX[(_it["book_name"], _it["chapter"], _it["verse"])] = _it["text"]

def _clean(t):
    # KJV PCE marks translator-supplied words with [brackets]; drop the brackets
    # (keep the words). Psalm superscriptions are wrapped in ‹‹guillemets›› — drop
    # those entirely, they aren't the verse proper. Matches common KJV memory text.
    t = re.sub(r"‹‹.*?››", "", t)
    t = t.replace("[", "").replace("]", "")
    return re.sub(r"\s+", " ", t).strip()

def fetch_kjv(ref):
    m = re.match(r"^(.*?)\s+(\d+):(\d+)(?:-(\d+))?$", ref.strip())
    if not m:
        sys.stderr.write(f"  BAD REF: {ref}\n"); return None
    book, ch, v1, v2 = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
    book = BOOK_ALIASES.get(book, book)
    v2 = int(v2) if v2 else v1
    parts = []
    for v in range(v1, v2 + 1):
        t = _INDEX.get((book, ch, v))
        if t is None:
            sys.stderr.write(f"  MISSING VERSE: {ref} ({book} {ch}:{v})\n"); return None
        parts.append(_clean(t))
    return " ".join(parts)

# (id, title, theme, subtitle, icon, accent, [references])
UNITS = [
    ("faith", "Foundations of Faith", "Faith",
     "Where the whole journey begins", "sparkles", "gold", [
        "Hebrews 11:1", "Hebrews 11:6", "Romans 10:17", "2 Corinthians 5:7",
        "Mark 11:24", "Matthew 17:20", "Ephesians 2:8", "James 2:17",
        "Romans 1:17", "Galatians 2:20"]),
    ("salvation", "The Gift of Salvation", "Salvation",
     "Grace, freely given", "heart.fill", "coral", [
        "John 3:16", "Romans 6:23", "Ephesians 2:8-9", "Romans 10:9",
        "Romans 5:8", "Titus 3:5", "Acts 4:12", "John 14:6",
        "2 Corinthians 5:17", "1 Peter 3:18"]),
    ("love", "Love & Compassion", "Love",
     "The greatest of these", "heart.circle.fill", "purple", [
        "1 Corinthians 13:4", "1 Corinthians 13:5", "John 13:34", "1 John 4:19",
        "1 John 4:8", "Romans 8:38-39", "John 15:13", "1 John 4:7",
        "Colossians 3:14", "Mark 12:30"]),
    ("strength", "Strength & Courage", "Strength",
     "He renews the weary", "bolt.fill", "teal", [
        "Philippians 4:13", "Isaiah 40:31", "Joshua 1:9", "2 Timothy 1:7",
        "Ephesians 6:10", "Isaiah 41:10", "Deuteronomy 31:6", "Psalm 18:2",
        "Nehemiah 8:10", "Psalm 27:14"]),
    ("peace", "Peace & Rest", "Peace",
     "Guard your heart and mind", "leaf.fill", "green", [
        "Philippians 4:6", "Philippians 4:7", "John 14:27", "Isaiah 26:3",
        "Matthew 11:28", "Psalm 4:8", "Colossians 3:15", "John 16:33",
        "Romans 5:1", "Psalm 29:11"]),
    ("hope", "Hope & Encouragement", "Hope",
     "A future and a hope", "sunrise.fill", "blue", [
        "Jeremiah 29:11", "Romans 15:13", "Romans 8:28", "Lamentations 3:22-23",
        "Psalm 42:11", "Romans 5:5", "Hebrews 6:19", "Isaiah 40:29",
        "Psalm 30:5", "Romans 12:12"]),
    ("wisdom", "Wisdom & Guidance", "Wisdom",
     "A lamp unto your feet", "lightbulb.fill", "gold", [
        "Proverbs 3:5", "Proverbs 3:6", "James 1:5", "Psalm 119:105",
        "Proverbs 2:6", "Proverbs 9:10", "Colossians 3:16", "Psalm 32:8",
        "Proverbs 16:3", "James 3:17"]),
    ("trust", "Trust & Provision", "Trust",
     "He will supply your needs", "shield.fill", "coral", [
        "Psalm 23:1", "Matthew 6:33", "Psalm 37:5", "Philippians 4:19",
        "Matthew 6:26", "Psalm 55:22", "Nahum 1:7", "Psalm 9:10",
        "Psalm 62:8", "Isaiah 26:4"]),
    ("prayer", "Prayer & Worship", "Prayer",
     "Draw near to God", "hands.sparkles.fill", "purple", [
        "Matthew 6:9", "1 Thessalonians 5:17", "James 5:16", "Matthew 7:7",
        "Psalm 100:4", "John 4:24", "Psalm 95:6", "1 John 5:14",
        "Psalm 145:18", "Ephesians 6:18"]),
    ("grace", "Grace & Forgiveness", "Grace",
     "As far as east from west", "gift.fill", "teal", [
        "Ephesians 1:7", "1 John 1:9", "Colossians 3:13", "Micah 7:18",
        "Psalm 103:12", "2 Corinthians 12:9", "Ephesians 4:32", "Matthew 6:14",
        "Romans 5:20", "Hebrews 4:16"]),
    ("identity", "Identity in Christ", "Identity",
     "A new creation", "person.fill.checkmark", "green", [
        "John 1:12", "Romans 8:1", "1 Peter 2:9", "Ephesians 2:10",
        "2 Corinthians 5:21", "Galatians 3:26", "Colossians 3:3", "1 John 3:1",
        "Romans 8:16", "Ephesians 1:5"]),
    ("fear", "Overcoming Fear & Anxiety", "Fear",
     "Cast your cares on Him", "shield.lefthalf.filled", "blue", [
        "Psalm 34:4", "1 Peter 5:7", "Psalm 56:3", "Isaiah 43:1",
        "Psalm 27:1", "Matthew 6:34", "Psalm 94:19", "Deuteronomy 31:8",
        "Psalm 118:6", "John 14:1"]),
    ("joy", "Joy & Gratitude", "Joy",
     "Give thanks in everything", "sun.max.fill", "gold", [
        "1 Thessalonians 5:18", "Philippians 4:4", "Psalm 118:24", "James 1:2",
        "Psalm 16:11", "Galatians 5:22", "Psalm 100:1-2", "Psalm 28:7",
        "Habakkuk 3:18", "Psalm 126:3"]),
    ("obedience", "Obedience & Discipleship", "Obedience",
     "Follow and abide", "figure.walk", "coral", [
        "John 14:15", "Matthew 28:19", "Luke 9:23", "James 1:22",
        "Matthew 16:24", "John 15:5", "Romans 12:1", "Micah 6:8",
        "1 Samuel 15:22", "Matthew 22:37"]),
    ("eternity", "Eternity & His Return", "Eternity",
     "He is making all things new", "crown.fill", "purple", [
        "John 14:2", "1 Thessalonians 4:16-17", "Revelation 21:4", "John 11:25",
        "2 Corinthians 4:17", "1 Corinthians 15:52", "Philippians 3:20",
        "Titus 2:13", "Revelation 22:12", "1 John 5:13"]),
]

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def main():
    out = []
    total = 0
    missing = []
    for uid, title, theme, subtitle, icon, accent, refs in UNITS:
        verses = []
        for ref in refs:
            txt = fetch_kjv(ref)
            if not txt:
                missing.append(ref)
                txt = ""
            verses.append((ref, txt))
            total += 1
            sys.stderr.write(f"[{total}] {ref} -> {txt[:48]}...\n")
        out.append((uid, title, theme, subtitle, icon, accent, verses))

    lines = []
    lines.append("import Foundation")
    lines.append("")
    lines.append("// MARK: - Memory Journey Curriculum")
    lines.append("//")
    lines.append("// A themed Scripture-memory curriculum that drives the Duolingo-style journey")
    lines.append("// path (see MemoryJourneyView). 15 ordered units, 150 verses. Text is the")
    lines.append("// public-domain King James Version (bundled so nodes work offline); the app")
    lines.append("// stores it as the verse's text when a node is started (KJV is the memory")
    lines.append("// default — see AddVerseSheet). GENERATED by Scripts/gen_curriculum.py —")
    lines.append("// re-run to regenerate; do not hand-edit the verse text.")
    lines.append("")
    lines.append("struct CurriculumVerse: Identifiable, Hashable {")
    lines.append("    let reference: String")
    lines.append("    let text: String   // KJV, public domain")
    lines.append("    var id: String { reference }")
    lines.append("}")
    lines.append("")
    lines.append("struct CurriculumUnit: Identifiable {")
    lines.append("    let id: String")
    lines.append("    let title: String")
    lines.append("    let theme: String        // maps to MemoryVerse.category")
    lines.append("    let subtitle: String")
    lines.append("    let icon: String")
    lines.append("    let accent: PlanAccent")
    lines.append("    let verses: [CurriculumVerse]")
    lines.append("}")
    lines.append("")
    lines.append("enum MemoryCurriculum {")
    lines.append("    static let units: [CurriculumUnit] = [")
    for uid, title, theme, subtitle, icon, accent, verses in out:
        lines.append(f'        CurriculumUnit(id: "{uid}", title: "{esc(title)}", theme: "{esc(theme)}",')
        lines.append(f'            subtitle: "{esc(subtitle)}", icon: "{icon}", accent: .{accent}, verses: [')
        for ref, txt in verses:
            lines.append(f'            CurriculumVerse(reference: "{esc(ref)}", text: "{esc(txt)}"),')
        lines.append("        ]),")
    lines.append("    ]")
    lines.append("")
    lines.append("    /// All curriculum verses in journey order.")
    lines.append("    static var allVerses: [CurriculumVerse] { units.flatMap { $0.verses } }")
    lines.append("")
    lines.append("    /// Bundled KJV text for a reference, if it is part of the curriculum.")
    lines.append("    static func text(for reference: String) -> String? {")
    lines.append("        allVerses.first { $0.reference == reference }?.text")
    lines.append("    }")
    lines.append("")
    lines.append("    /// The unit that contains a given reference.")
    lines.append("    static func unit(for reference: String) -> CurriculumUnit? {")
    lines.append("        units.first { $0.verses.contains { $0.reference == reference } }")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    dest = "/Users/boazbriddick/Documents/Reforged/Reforged/Models/MemoryCurriculum.swift"
    with open(dest, "w") as f:
        f.write("\n".join(lines))
    sys.stderr.write(f"\nWROTE {dest} ({total} verses, {len(missing)} missing)\n")
    if missing:
        sys.stderr.write("MISSING: " + ", ".join(missing) + "\n")

if __name__ == "__main__":
    main()
