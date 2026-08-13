#!/usr/bin/env python3
"""Build a canonical ECHO BIBLE SQLite module from an eBible USFX source."""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


BOOKS = [
    ("GEN", "Genèse", 50), ("EXO", "Exode", 40), ("LEV", "Lévitique", 27),
    ("NUM", "Nombres", 36), ("DEU", "Deutéronome", 34), ("JOS", "Josué", 24),
    ("JDG", "Juges", 21), ("RUT", "Ruth", 4), ("1SA", "Premier livre de Samuel", 31),
    ("2SA", "Deuxième livre de Samuel", 24), ("1KI", "Premier livre des Rois", 22),
    ("2KI", "Second livre des Rois", 25), ("1CH", "Premier livre des Chroniques", 29),
    ("2CH", "Second livre des Chroniques", 36), ("EZR", "Esdras", 10),
    ("NEH", "Néhémie", 13), ("EST", "Esther", 10), ("JOB", "Job", 42),
    ("PSA", "Psaumes", 150), ("PRO", "Proverbes", 31), ("ECC", "L'Ecclésiaste", 12),
    ("SNG", "Cantique des Cantiques", 8), ("ISA", "Ésaïe", 66),
    ("JER", "Jérémie", 52), ("LAM", "Lamentations", 5), ("EZK", "Ézékiel", 48),
    ("DAN", "Daniel", 12), ("HOS", "Osée", 14), ("JOL", "Joël", 3),
    ("AMO", "Amos", 9), ("OBA", "Abdias", 1), ("JON", "Jonas", 4),
    ("MIC", "Michée", 7), ("NAM", "Nahum", 3), ("HAB", "Habacuc", 3),
    ("ZEP", "Sophonie", 3), ("HAG", "Aggée", 2), ("ZEC", "Zacharie", 14),
    ("MAL", "Malachie", 4), ("MAT", "Évangile selon Matthieu", 28),
    ("MRK", "Évangile selon Marc", 16), ("LUK", "Évangile selon Luc", 24),
    ("JHN", "Évangile selon Jean", 21), ("ACT", "Actes des Apôtres", 28),
    ("ROM", "Épître de Paul aux Romains", 16),
    ("1CO", "Première épître de Paul aux Corinthiens", 16),
    ("2CO", "Seconde épître de Paul aux Corinthiens", 13),
    ("GAL", "Épître de Paul aux Galates", 6), ("EPH", "Épître de Paul aux Éphésiens", 6),
    ("PHP", "Épître de Paul aux Philippiens", 4), ("COL", "Épître de Paul aux Colossiens", 4),
    ("1TH", "Première épître de Paul aux Thessaloniciens", 5),
    ("2TH", "Second épître de Paul aux Thessaloniciens", 3),
    ("1TI", "Première épître de Paul à Timothée", 6),
    ("2TI", "Second épître de Paul à Timothée", 4), ("TIT", "Épître de Paul à Tite", 3),
    ("PHM", "Épître de Paul à Philémon", 1), ("HEB", "Épître aux Hébreux", 13),
    ("JAS", "Épître de Jacques", 5), ("1PE", "Première épître de Pierre", 5),
    ("2PE", "Seconde épître de Pierre", 3), ("1JN", "Première épître de Jean", 5),
    ("2JN", "Seconde épître de Jean", 1), ("3JN", "Troisième épître de Jean", 1),
    ("JUD", "Épître de Jude", 1), ("REV", "Apocalypse de Jean", 22),
]
BOOK_BY_CODE = {code: (number, name, chapters) for number, (code, name, chapters) in enumerate(BOOKS, 1)}
EXCLUDED = {"f", "fe", "x", "fig", "fm", "fr", "fk", "fq", "fqa", "fl", "fp", "fv", "ft", "fdc", "xo", "xk", "xq", "xt", "xdc"}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--version-id", required=True)
    parser.add_argument("--short-name", required=True)
    parser.add_argument("--full-name", required=True)
    parser.add_argument("--language", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--license", required=True, dest="license_name")
    return parser.parse_args()


def locate_usfx(source: Path) -> tuple[ET.Element, str]:
    if source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source) as archive:
            names = [name for name in archive.namelist() if name.lower().endswith("_usfx.xml")]
            if len(names) != 1:
                raise ValueError(f"Archive USFX ambiguë: {names}")
            with archive.open(names[0]) as stream:
                return ET.parse(stream).getroot(), names[0]
    if source.is_dir():
        files = list(source.glob("*_usfx.xml"))
        if len(files) != 1:
            raise ValueError(f"Dossier USFX ambigu: {files}")
        return ET.parse(files[0]).getroot(), files[0].name
    return ET.parse(source).getroot(), source.name


def clean_text(parts: list[str]) -> str:
    value = "".join(parts).replace("\u00a0", " ").replace("\u202f", " ")
    return unicodedata.normalize("NFC", re.sub(r"\s+", " ", value)).strip()


def extract_verses(root: ET.Element) -> list[tuple[int, int, int, str]]:
    verses: list[tuple[int, int, int, str]] = []
    current: list[object] | None = None
    catholic_versification = any(
        verse.attrib.get("bcv", "").startswith("JOL.4.") for verse in root.iter("v")
    )

    def flush() -> None:
        nonlocal current
        if current is not None:
            book_id, chapter, verse, parts = current
            text = clean_text(parts)  # type: ignore[arg-type]
            # Some eBible editions retain an intentionally omitted verse marker
            # (usually a textual-criticism note) without main Bible text.
            if text:
                verses.append((book_id, chapter, verse, text))  # type: ignore[arg-type]
            current = None

    def walk(element: ET.Element, excluded: bool = False) -> None:
        nonlocal current
        tag = element.tag.rsplit("}", 1)[-1]
        now_excluded = excluded or tag in EXCLUDED
        if tag == "v":
            flush()
            bcv = element.attrib.get("bcv", "")
            match = re.fullmatch(r"([1-3A-Z]+)\.(\d+)\.(\d+)", bcv)
            if not match:
                raise ValueError(f"Référence USFX invalide: {bcv}")
            code, chapter, verse = match.groups()
            chapter_number, verse_number = int(chapter), int(verse)
            if catholic_versification and code == "JOL":
                if chapter_number == 3:
                    chapter_number, verse_number = 2, verse_number + 27
                elif chapter_number == 4:
                    chapter_number = 3
            if (catholic_versification and code == "MAL" and
                    chapter_number == 3 and verse_number >= 19):
                chapter_number, verse_number = 4, verse_number - 18
            if code in BOOK_BY_CODE and chapter_number <= BOOK_BY_CODE[code][2]:
                current = [BOOK_BY_CODE[code][0], chapter_number, verse_number, []]
        elif tag == "ve":
            flush()
        elif current is not None and not now_excluded and element.text:
            current[3].append(element.text)  # type: ignore[union-attr]
        for child in element:
            walk(child, now_excluded)
            if current is not None and not now_excluded and child.tail:
                current[3].append(child.tail)  # type: ignore[union-attr]

    for book in root.findall("book"):
        if book.attrib.get("id") in BOOK_BY_CODE:
            walk(book)
            flush()
    return verses


def build_database(options: argparse.Namespace) -> None:
    root, source_file = locate_usfx(options.input)
    verses = extract_verses(root)
    chapters = {(book, chapter) for book, chapter, _, _ in verses}
    if len(chapters) != 1189:
        raise ValueError(f"Canon incomplet: {len(chapters)} chapitres au lieu de 1189")
    present_books = {book for book, _, _, _ in verses}
    if present_books != set(range(1, 67)):
        raise ValueError(f"Canon incomplet: {len(present_books)} livres au lieu de 66")

    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.unlink(missing_ok=True)
    connection = sqlite3.connect(options.output)
    try:
        connection.executescript("""
            PRAGMA journal_mode=OFF;
            PRAGMA synchronous=OFF;
            CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE books(id INTEGER PRIMARY KEY, canonical_number INTEGER NOT NULL UNIQUE,
              name TEXT NOT NULL, abbreviation TEXT NOT NULL, testament TEXT NOT NULL,
              chapters_count INTEGER NOT NULL);
            CREATE TABLE chapters(id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL,
              chapter_number INTEGER NOT NULL, verses_count INTEGER NOT NULL,
              UNIQUE(book_id, chapter_number));
            CREATE TABLE verses(id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL,
              chapter_number INTEGER NOT NULL, verse_number INTEGER NOT NULL, text TEXT NOT NULL);
            CREATE UNIQUE INDEX idx_verses_reference
              ON verses(book_id, chapter_number, verse_number);
        """)
        metadata = {
            "id": options.version_id, "code": options.version_id,
            "shortName": options.short_name, "name": options.full_name,
            "language": options.language, "source": options.source,
            "sourceFile": source_file, "license": options.license_name, "version": "1.0.0",
        }
        connection.executemany("INSERT INTO metadata VALUES (?, ?)", metadata.items())
        connection.executemany(
            "INSERT INTO books VALUES (?, ?, ?, ?, ?, ?)",
            [(number, number, name, code, "Ancien" if number <= 39 else "Nouveau", count)
             for number, (code, name, count) in enumerate(BOOKS, 1)],
        )
        verse_counts: dict[tuple[int, int], int] = {}
        for book, chapter, _, _ in verses:
            verse_counts[(book, chapter)] = verse_counts.get((book, chapter), 0) + 1
        connection.executemany(
            "INSERT INTO chapters(id, book_id, chapter_number, verses_count) VALUES (?, ?, ?, ?)",
            [(book * 1000 + chapter, book, chapter, count)
             for (book, chapter), count in sorted(verse_counts.items())],
        )
        connection.executemany(
            "INSERT INTO verses(book_id, chapter_number, verse_number, text) VALUES (?, ?, ?, ?)", verses)
        connection.commit()
        result = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise ValueError(f"integrity_check: {result}")
    except Exception:
        connection.close()
        options.output.unlink(missing_ok=True)
        raise
    finally:
        try:
            connection.close()
        except sqlite3.ProgrammingError:
            pass
    print(f"{options.output}: 66 livres, 1189 chapitres, {len(verses)} versets, integrity_check=ok")


if __name__ == "__main__":
    try:
        build_database(arguments())
    except Exception as error:
        print(f"Erreur: {error}", file=sys.stderr)
        raise SystemExit(1)
