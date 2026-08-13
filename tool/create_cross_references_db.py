"""Build the offline cross-reference database from OpenBible.info data."""

import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "bible_builder/sources/cross_references/source/cross_references.txt"
OUTPUT = ROOT / "assets/database/cross_references.db"

BOOKS = ['Gen','Exod','Lev','Num','Deut','Josh','Judg','Ruth','1Sam','2Sam',
 '1Kgs','2Kgs','1Chr','2Chr','Ezra','Neh','Esth','Job','Ps','Prov','Eccl',
 'Song','Isa','Jer','Lam','Ezek','Dan','Hos','Joel','Amos','Obad','Jonah',
 'Mic','Nah','Hab','Zeph','Hag','Zech','Mal','Matt','Mark','Luke','John',
 'Acts','Rom','1Cor','2Cor','Gal','Eph','Phil','Col','1Thess','2Thess',
 '1Tim','2Tim','Titus','Phlm','Heb','Jas','1Pet','2Pet','1John','2John',
 '3John','Jude','Rev']
ALIASES = {'Ex':'Exod','Deut':'Deut','Judg':'Judg','Ruth':'Ruth','Ps':'Ps',
           'Song':'Song','Phil':'Phil','Philem':'Phlm','Rev':'Rev'}
BOOK_IDS = {name: index + 1 for index, name in enumerate(BOOKS)}


def parse_source(value: str):
    start, separator, end = value.partition('-')
    book, chapter, verse = start.split('.')[:3]
    book = ALIASES.get(book, book)
    first = (BOOK_IDS[book], int(chapter), int(verse))
    if not separator:
        return [first]
    end_book, end_chapter, end_verse = end.split('.')[:3]
    end_book = ALIASES.get(end_book, end_book)
    if end_book == book and int(end_chapter) == first[1]:
        return [(first[0], first[1], number)
                for number in range(first[2], int(end_verse) + 1)]
    # Cross-chapter ranges are represented by their explicit endpoints; the
    # source does not provide the intervening chapter versification here.
    return [first, (BOOK_IDS[end_book], int(end_chapter), int(end_verse))]


def parse_target(value: str):
    start, separator, end = value.partition('-')
    book, chapter, verse = start.split('.')[:3]
    book = ALIASES.get(book, book)
    if not separator:
        return BOOK_IDS[book], int(chapter), int(verse), int(verse)
    end_book, end_chapter, end_verse = end.split('.')[:3]
    end_book = ALIASES.get(end_book, end_book)
    if end_book != book or end_chapter != chapter:
        raise ValueError('Cross-chapter target range')
    return BOOK_IDS[book], int(chapter), int(verse), int(end_verse)


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source: {SOURCE}")
    OUTPUT.unlink(missing_ok=True)
    db = sqlite3.connect(OUTPUT)
    db.executescript("""
      CREATE TABLE cross_references(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_book_id INTEGER NOT NULL, source_chapter INTEGER NOT NULL,
        source_verse INTEGER NOT NULL, target_book_id INTEGER NOT NULL,
        target_chapter INTEGER NOT NULL,
        target_verse_start INTEGER NOT NULL,
        target_verse_end INTEGER,
        score INTEGER,
        source_dataset TEXT NOT NULL
      );
      CREATE INDEX idx_cross_source ON cross_references(source_book_id,source_chapter,source_verse,score DESC);
      CREATE INDEX idx_cross_target ON cross_references(
        target_book_id,target_chapter,target_verse_start,target_verse_end
      );
      CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    """)
    batch = []
    skipped = 0
    with SOURCE.open(encoding="utf-8-sig", newline="") as source:
        for row in csv.DictReader(source, delimiter="\t"):
            try:
                score = int(row['Votes']) if row['Votes'] else None
                target = parse_target(row['To Verse'])
                for source_ref in parse_source(row['From Verse']):
                    batch.append((*source_ref, *target, score, 'OpenBible.info'))
            except (KeyError, ValueError):
                skipped += 1
    db.executemany("""INSERT INTO cross_references(source_book_id,source_chapter,
      source_verse,target_book_id,target_chapter,target_verse_start,
      target_verse_end,score,source_dataset)
      VALUES(?,?,?,?,?,?,?,?,?)""", batch)
    db.executemany("INSERT INTO metadata VALUES(?,?)", [
      ('source','OpenBible.info Cross References'),
      ('source_url','https://www.openbible.info/labs/cross-references/'),
      ('license','CC BY 4.0')])
    db.commit()
    db.close()
    print(f"Created {OUTPUT} with {len(batch)} links; skipped {skipped}.")


if __name__ == '__main__':
    main()
