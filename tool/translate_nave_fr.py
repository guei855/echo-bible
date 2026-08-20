"""Generate the complete, reviewable French Nave translation worksheet.

No translation API is called. Editorial entries are marked ``manual`` and
every untouched English entity remains ``pending``. The English source text
and stable core identifiers are always retained in the CSV.
"""

import csv
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE_DATABASE = ROOT / "release_resources/en/nave/nave_core.db"
LEGACY_DATABASE = ROOT / "assets/database/nave.db"
EDITORIAL = ROOT / "bible_builder/translations/nave_fr_editorial.json"
OUTPUT = ROOT / "bible_builder/translations/nave_fr_review.csv"


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
        topic_translations[matches[occurrence - 1]["id"]] = item["text"]

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
                )
            )
    database.close()

    with OUTPUT.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(
            ("entity_type", "entity_id", "source_en", "translation_fr", "status")
        )
        writer.writerows(rows)
    translated = sum(1 for row in rows if row[3])
    print(
        f"Created {OUTPUT}: {len(rows)} rows, "
        f"{translated} manual French translations."
    )


if __name__ == "__main__":
    main()
