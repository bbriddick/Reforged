CREATE INDEX idx_lex_strongs ON lexicon_entries(strongs, source);
CREATE INDEX idx_lex_lemma   ON lexicon_entries(lemma, source);
CREATE VIRTUAL TABLE kjv_fts USING fts5(text, content='kjv_verses', content_rowid='verse_id');
INSERT INTO kjv_fts(kjv_fts) VALUES('rebuild');
