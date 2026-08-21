"""Generate the complete, reviewable French Nave translation worksheet.

No translation API is called. Editorial entries are marked ``manual`` and
every untouched English entity remains ``pending``. The English source text
and stable core identifiers are always retained in the CSV.
"""

import csv
import hashlib
import json
import sqlite3
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE_DATABASE = ROOT / "release_resources/en/nave/nave_core.db"
LEGACY_DATABASE = ROOT / "assets/database/nave.db"
EDITORIAL = ROOT / "bible_builder/translations/nave_fr_editorial.json"
OUTPUT = ROOT / "bible_builder/translations/nave_fr_review.csv"
OUTPUT_DATABASE = ROOT / "release_resources/fr/nave/nave_fr.db"


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    ascii_text = "".join(
        character for character in decomposed if not unicodedata.combining(character)
    )
    return " ".join(
        "".join(character if character.isalnum() else " " for character in ascii_text)
        .split()
    )


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    database_path = CORE_DATABASE if CORE_DATABASE.exists() else LEGACY_DATABASE
    database = sqlite3.connect(database_path)
    database.row_factory = sqlite3.Row
    editorial = json.loads(EDITORIAL.read_text(encoding="utf-8"))
    status = editorial["status"]
    if status not in {"verified", "manual", "machine", "pending"}:
        raise ValueError(f"Unsupported translation status: {status}")

    topic_translations: dict[int, str] = {}
    topic_aliases: dict[int, list[str]] = {}
    for item in editorial["topics"]:
        matches = list(
            database.execute(
                "SELECT id FROM nave_topics WHERE title_en=? ORDER BY id",
                (item["titleEn"],),
            )
        )
        occurrence = item.get("occurrence", 1)
        if len(matches) < occurrence:
            raise ValueError(
                f"Unknown Nave topic: {item['titleEn']} #{occurrence}"
            )
        topic_id = matches[occurrence - 1]["id"]
        topic_translations[topic_id] = item["text"]
        topic_aliases[topic_id] = item.get("aliases", [])

    section_translations: dict[int, str] = {}
    for item in editorial["sections"]:
        matches = list(
            database.execute(
                "SELECT id FROM nave_sections WHERE title_en=? ORDER BY id",
                (item["sourceEn"],),
            )
        )
        if not matches:
            raise ValueError(f"Unknown Nave section: {item['sourceEn']}")
        for match in matches:
            section_translations[match["id"]] = item["text"]

    rows = []
    for entity_type, table, translations in (
        ("topic", "nave_topics", topic_translations),
        ("section", "nave_sections", section_translations),
    ):
        for row in database.execute(f"SELECT id,title_en FROM {table} ORDER BY id"):
            translation = translations.get(row["id"], "")
            rows.append(
                (
                    entity_type,
                    row["id"],
                    row["title_en"],
                    translation,
                    status if translation else "pending",
                    editorial["notes"] if translation else "",
                )
            )

    with OUTPUT.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(
            (
                "entity_type",
                "entity_id",
                "source_en",
                "translation_fr",
                "status",
                "notes",
            )
        )
        writer.writerows(rows)

    OUTPUT_DATABASE.parent.mkdir(parents=True, exist_ok=True)
    temporary = OUTPUT_DATABASE.with_suffix(".db.tmp")
    temporary.unlink(missing_ok=True)
    french = sqlite3.connect(temporary)
    french.executescript(
        """
        CREATE TABLE nave_translations(
          entity_type TEXT NOT NULL, entity_id INTEGER NOT NULL,
          language_code TEXT NOT NULL, translated_text TEXT NOT NULL,
          normalized_text TEXT NOT NULL, status TEXT NOT NULL
            CHECK(status IN ('verified','manual','machine','pending')),
          source TEXT NOT NULL, notes TEXT,
          PRIMARY KEY(entity_type,entity_id,language_code));
        CREATE TABLE nave_aliases(
          id INTEGER PRIMARY KEY AUTOINCREMENT, topic_id INTEGER NOT NULL,
          language_code TEXT NOT NULL, alias_text TEXT NOT NULL,
          normalized_alias TEXT NOT NULL, source TEXT NOT NULL,
          status TEXT NOT NULL
            CHECK(status IN ('verified','manual','machine','pending')),
          UNIQUE(topic_id,language_code,normalized_alias));
        CREATE INDEX idx_nave_translation_search
          ON nave_translations(language_code,entity_type,normalized_text);
        CREATE INDEX idx_nave_alias_search
          ON nave_aliases(language_code,normalized_alias);
        CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        """
    )
    translation_rows = [row for row in rows if row[3]]
    french.executemany(
        """INSERT INTO nave_translations(
          entity_type,entity_id,language_code,translated_text,normalized_text,
          status,source,notes) VALUES(?,?,'fr',?,?,?,?,?)""",
        [
            (
                entity_type,
                entity_id,
                translated_text,
                normalize(translated_text),
                row_status,
                editorial["source"],
                notes,
            )
            for entity_type, entity_id, _, translated_text, row_status, notes
            in translation_rows
        ],
    )
    alias_rows: list[tuple[int, str, str]] = []
    for topic_id, aliases in topic_aliases.items():
        seen: set[str] = set()
        for alias in aliases:
            normalized_alias = normalize(alias)
            if normalized_alias and normalized_alias not in seen:
                seen.add(normalized_alias)
                alias_rows.append((topic_id, alias, normalized_alias))
    french.executemany(
        """INSERT INTO nave_aliases(
          topic_id,language_code,alias_text,normalized_alias,source,status)
          VALUES(?,'fr',?,?,?,'manual')""",
        [
            (topic_id, alias, normalized_alias, editorial["source"])
            for topic_id, alias, normalized_alias in alias_rows
        ],
    )
    metadata = {
        "language": "fr",
        "version": "4",
        "license": "CC BY-SA 4.0",
        "source": editorial["source"],
        "attribution": "Couche française ECHO BIBLE ; source anglaise Orville J. Nave",
        "topic_translations": str(len(topic_translations)),
        "section_translations": str(len(section_translations)),
        "aliases": str(len(alias_rows)),
    }
    french.executemany("INSERT INTO metadata VALUES(?,?)", metadata.items())
    french.commit()
    integrity = french.execute("PRAGMA integrity_check").fetchone()[0]
    french.close()
    if integrity != "ok":
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"nave_fr.db integrity_check={integrity}")
    temporary.replace(OUTPUT_DATABASE)
    database.close()
    translated = sum(1 for row in rows if row[3])
    print(
        f"Created {OUTPUT}: {len(rows)} rows, "
        f"{translated} manual French translations."
    )
    digest = hashlib.sha256(OUTPUT_DATABASE.read_bytes()).hexdigest()
    print(
        f"Created {OUTPUT_DATABASE}: {OUTPUT_DATABASE.stat().st_size} bytes, "
        f"{len(topic_translations)} topics, {len(section_translations)} sections, "
        f"{len(alias_rows)} aliases, SHA-256 {digest}, integrity_check=ok."
    )


if __name__ == "__main__":
    main()
