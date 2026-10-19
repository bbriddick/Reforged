"""Create reforged-study.sqlite from the parsed sources."""
import sqlite3
from pathlib import Path

HERE = Path(__file__).resolve().parent


def create(path: Path) -> sqlite3.Connection:
    if path.exists():
        path.unlink()
    con = sqlite3.connect(path)
    con.executescript("PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF; PRAGMA page_size=4096;")
    con.executescript((HERE / "schema.sql").read_text())
    return con


def finish(con: sqlite3.Connection) -> None:
    con.executescript((HERE / "schema_post.sql").read_text())
    con.commit()
    con.execute("ANALYZE")
    con.commit()
    con.execute("VACUUM")
    con.close()
