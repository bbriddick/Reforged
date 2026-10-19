CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE books (
  book_id   INTEGER PRIMARY KEY,
  osis      TEXT NOT NULL,
  name      TEXT NOT NULL,
  testament TEXT NOT NULL CHECK (testament IN ('OT','NT')),
  chapters  INTEGER NOT NULL
);

CREATE TABLE kjv_verses (
  verse_id INTEGER PRIMARY KEY,                 -- BBCCCVVV, Philippians 1:1 = 50001001
  book_id  INTEGER NOT NULL REFERENCES books(book_id),
  chapter  INTEGER NOT NULL,
  verse    INTEGER NOT NULL,
  text     TEXT NOT NULL,                       -- plain text, no tags, no Psalm title
  title    TEXT                                 -- Psalm pre-verse title, if any
);

-- One row per (token, Strong's number). Untagged words have strongs = ''. The alignment to the
-- original-language word lives on the same row; `alignments` below is a view over it.
CREATE TABLE kjv_tokens (
  verse_id      INTEGER NOT NULL REFERENCES kjv_verses(verse_id),
  position      INTEGER NOT NULL,               -- 0-based token index (phrase or untagged word)
  strongs       TEXT NOT NULL DEFAULT '',       -- 'G1401'; '' for untagged words
  word          TEXT NOT NULL,                  -- as displayed: 'the servants'; '' for untranslated
  morph         TEXT,                           -- Robinson code, NT only
  word_index    INTEGER NOT NULL,               -- index of first word in kjv_verses.text, -1 for Psalm titles / untranslated
  word_count    INTEGER NOT NULL,
  added         INTEGER NOT NULL DEFAULT 0,     -- 1 = supplied (italic) word
  in_title      INTEGER NOT NULL DEFAULT 0,
  orig_edition  TEXT,                           -- 'TR' | 'WLC'
  orig_position INTEGER,                        -- NULL when match_quality = 'none'
  match_quality TEXT CHECK (match_quality IS NULL OR match_quality IN ('exact','strongs_only','none')),
  PRIMARY KEY (verse_id, position, strongs)
) WITHOUT ROWID;

CREATE VIEW alignments AS
  SELECT verse_id, position AS kjv_position, strongs, orig_edition, orig_position, match_quality
  FROM kjv_tokens WHERE strongs <> '';

CREATE TABLE original_tokens (
  verse_id         INTEGER NOT NULL,            -- KJV verse the word aligns under
  position         INTEGER NOT NULL,            -- 0-based within that verse
  language         TEXT NOT NULL CHECK (language IN ('grc','hbo')),
  edition          TEXT NOT NULL,               -- 'TR' or 'WLC'
  surface          TEXT NOT NULL,               -- Greek unaccented / Hebrew pointed, no cantillation
  surface_accented TEXT,                        -- Greek accented; NULL for Hebrew
  strongs          TEXT NOT NULL,               -- '' when the source gives none
  morph            TEXT,
  alt_strongs      TEXT,                        -- other numbers on the same Hebrew word, space separated
  src_ref          TEXT,                        -- WLC reference, only when its versification differs from the KJV verse
  PRIMARY KEY (verse_id, edition, position)
) WITHOUT ROWID;

CREATE TABLE morph_codes (
  code      TEXT PRIMARY KEY,
  scheme    TEXT NOT NULL,
  expansion TEXT NOT NULL
);

CREATE TABLE strongs_entries (
  strongs    TEXT PRIMARY KEY,
  language   TEXT NOT NULL,                     -- 'grc' | 'hbo' | 'arc'
  lemma      TEXT NOT NULL,
  translit   TEXT,
  pron       TEXT,
  definition TEXT,
  kjv_def    TEXT,
  derivation TEXT,
  occurrences INTEGER NOT NULL DEFAULT 0   -- max(KJV translation total, original-language words)
);

CREATE TABLE lexicon_entries (
  source    TEXT NOT NULL,                      -- 'abbott-smith','bdb','tbesg','tbesh'
  strongs   TEXT,
  lemma     TEXT NOT NULL,
  headword  TEXT,
  body_html TEXT NOT NULL,
  body_text TEXT NOT NULL
);

CREATE TABLE strongs_usage (
  strongs      TEXT NOT NULL,
  english_word TEXT NOT NULL,
  count        INTEGER NOT NULL,
  PRIMARY KEY (strongs, english_word)
) WITHOUT ROWID;

CREATE TABLE strongs_occurrences (
  strongs  TEXT NOT NULL,
  verse_id INTEGER NOT NULL,
  PRIMARY KEY (strongs, verse_id)
) WITHOUT ROWID;
