"""Produce the reviewable French translation layer for Nave.

The script never calls a translation API. Existing manual/verified translations
are preserved, explicitly reviewed seeds are marked ``manual``, and every other
row remains ``pending`` with an empty French value.
"""

import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "assets/database/nave.db"
OUTPUT = ROOT / "bible_builder/translations/nave_fr_review.csv"

MANUAL_SECTIONS = {
    "To Adam": "À Adam",
    "To Abraham": "À Abraham",
    "To Jacob, at Beth-el": "À Jacob, à Béthel",
    "To Moses, in the flaming bush": "À Moïse, dans le buisson ardent",
    "To Moses, at Sinai": "À Moïse, au Sinaï",
    "To Moses and Joshua": "À Moïse et Josué",
    "To Israel": "À Israël",
    "To Gideon": "À Gédéon",
    "To Solomon": "À Salomon",
    "To Isaiah": "À Ésaïe",
    "To Ezekiel": "À Ézéchiel",
    "Proclaimed": "Proclamé",
}


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    database = sqlite3.connect(DATABASE)
    database.row_factory = sqlite3.Row
    existing = {
        (row["entity_type"], row["entity_id"]): (
            row["translated_text"],
            row["translation_status"],
        )
        for row in database.execute(
            """SELECT entity_type,entity_id,translated_text,translation_status
               FROM nave_translations WHERE language='fr'"""
        )
    }
    rows = []
    for entity_type, table in (("topic", "nave_topics"), ("section", "nave_sections")):
        for row in database.execute(f"SELECT id,title_en,title_fr FROM {table} ORDER BY id"):
            translation, status = existing.get(
                (entity_type, row["id"]),
                (row["title_fr"] or "", "manual" if row["title_fr"] else "pending"),
            )
            if entity_type == "section" and row["title_en"] in MANUAL_SECTIONS:
                translation = MANUAL_SECTIONS[row["title_en"]]
                status = "manual"
            rows.append(
                (entity_type, row["id"], row["title_en"], translation, status)
            )
    database.close()

    with OUTPUT.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(
            ("entity_type", "entity_id", "source_en", "translation_fr", "status")
        )
        writer.writerows(rows)
    translated = sum(1 for row in rows if row[3])
    print(f"Created {OUTPUT}: {len(rows)} rows, {translated} French translations.")


if __name__ == "__main__":
    main()

