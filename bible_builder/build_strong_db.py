"""Build the production Strong lexicon from official STEPBible sources."""

import argparse
import hashlib
import html
import os
import re
import shutil
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "bible_builder" / "sources" / "stepbible"
OUTPUT = ROOT / "assets" / "database" / "strong.db"
BACKUP = ROOT / "bible_builder" / "backups" / "strong.db.latest.bak"
SOURCE_URL = "https://github.com/STEPBible/STEPBible-Data"
LICENSE = "CC BY 4.0"

BOOK_IDS = {
    code: index + 1
    for index, code in enumerate(
        (
            "Gen Exo Lev Num Deu Jos Jdg Rut 1Sa 2Sa 1Ki 2Ki 1Ch 2Ch "
            "Ezr Neh Est Job Psa Pro Ecc Sng Isa Jer Lam Ezk Dan Hos Jol "
            "Amo Oba Jon Mic Nam Hab Zep Hag Zec Mal Mat Mrk Luk Jhn Act "
            "Rom 1Co 2Co Gal Eph Php Col 1Th 2Th 1Ti 2Ti Tit Phm Heb Jas "
            "1Pe 2Pe 1Jn 2Jn 3Jn Jud Rev"
        ).split()
    )
}
REFERENCE = re.compile(
    r"^([1-3]?[A-Za-z]+)\.(\d+)\.(\d+)#(\d+)(?:=([^\t]+))?"
)


def plain(value: str) -> str:
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", "", value)
    return html.unescape(value).strip()


def canonical(value: str) -> str:
    match = re.match(r"^([HG])0*(\d+)([A-Za-z]*)", value.strip(), re.I)
    if not match:
        return value.strip().upper()
    return f"{match[1].upper()}{match[2]}{match[3].upper()}"


def first_code(value: str) -> str:
    match = re.search(r"[HG]\d+[A-Za-z]*", value, re.I)
    return canonical(match.group(0)) if match else ""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def source_file(directory: Path, prefix: str) -> Path:
    matches = list(directory.glob(f"{prefix} - *.txt"))
    if len(matches) != 1:
        raise SystemExit(
            f"Expected exactly one official {prefix} file in {directory}, "
            f"found {len(matches)}"
        )
    return matches[0]


def source_files(directory: Path, prefix: str) -> list[Path]:
    matches = sorted(directory.glob(f"{prefix} *.txt"))
    if not matches:
        raise SystemExit(f"No official {prefix} files found in {directory}")
    return matches


def rows(path: Path, testament: str, default_language: str):
    found_header = False
    with path.open(encoding="utf-8-sig") as source:
        for raw in source:
            fields = raw.rstrip("\r\n").split("\t")
            if (
                len(fields) >= 3
                and fields[0] in {"eStrong", "eStrong#"}
                and fields[1:3] == ["dStrong", "uStrong"]
            ):
                found_header = True
                continue
            if not found_header or len(fields) < 8:
                continue
            extended, disambiguated, unified = fields[:3]
            if not re.match(r"^[HG]\d", extended):
                continue
            # eStrong is the backward-compatible public lookup key. Several
            # disambiguated meanings/forms may legitimately share it.
            strong_number = canonical(extended)
            morphology = plain(fields[5]) or None
            language = (
                "Araméen"
                if default_language == "Hébreu"
                and morphology
                and morphology.startswith("A:")
                else default_language
            )
            gloss = plain(fields[6]) or None
            # TBESH explicitly asks projects to obtain Online Bible's
            # permission before using its Meaning column. Keep it out.
            definition_source = (
                plain(fields[7]) or None if default_language == "Grec" else None
            )
            yield (
                strong_number,
                canonical(extended),
                first_code(disambiguated) or None,
                first_code(unified) or None,
                testament,
                language,
                plain(fields[3]),
                plain(fields[4]) or None,
                None,
                morphology,
                gloss,
                gloss,
                definition_source,
                None,
                path.name.split(" - ", 1)[0],
                SOURCE_URL,
                LICENSE,
            )
    if not found_header:
        raise SystemExit(f"No STEPBible data header found in {path}")


def base_strong(value: str) -> str:
    match = re.search(r"([HG])0*(\d+)", value, re.I)
    return f"{match[1].upper()}{int(match[2])}" if match else ""


def original_parts(value: str) -> list[str]:
    return [part.strip(" {}[]()") for part in value.split("/")]


def aligned_part(parts: list[str], index: int, fallback: str) -> str:
    if len(parts) == 1:
        return parts[0]
    return parts[index] if index < len(parts) else fallback


def tahot_occurrences(path: Path, lemmas: dict[str, str]):
    with path.open(encoding="utf-8-sig") as source:
        for raw in source:
            fields = raw.rstrip("\r\n").split("\t")
            if len(fields) < 6:
                continue
            reference = REFERENCE.match(fields[0])
            if reference is None or reference.group(1) not in BOOK_IDS:
                continue
            book, chapter, verse, position, variant = reference.groups()
            tokens = original_parts(fields[1])
            strong_parts = fields[4].split("/")
            morphology_parts = fields[5].split("/")
            for part_index, strong_part in enumerate(strong_parts):
                codes = re.findall(r"H0*\d+[A-Za-z]*", strong_part)
                for source_code in codes:
                    code = base_strong(source_code)
                    if not code:
                        continue
                    token = aligned_part(tokens, part_index, fields[1])
                    token = token.split("\\", 1)[0].strip()
                    morphology = aligned_part(
                        morphology_parts, part_index, fields[5]
                    )
                    yield (
                        code,
                        BOOK_IDS[book],
                        int(chapter),
                        int(verse),
                        token or fields[1],
                        lemmas.get(code),
                        morphology or None,
                        int(position),
                        variant,
                        "TAHOT",
                    )


def tagnt_occurrences(path: Path, lemmas: dict[str, str]):
    with path.open(encoding="utf-8-sig") as source:
        for raw in source:
            fields = raw.rstrip("\r\n").split("\t")
            if len(fields) < 5:
                continue
            reference = REFERENCE.match(fields[0])
            if reference is None or reference.group(1) not in BOOK_IDS:
                continue
            book, chapter, verse, position, variant = reference.groups()
            tagged = fields[3].split("=", 1)
            code = base_strong(tagged[0])
            if not code:
                continue
            morphology = tagged[1].strip() if len(tagged) > 1 else None
            token = re.sub(r"\s+\([^()]*(?:\([^()]*\)[^()]*)*\)\s*$", "", fields[1])
            lemma = fields[4].split("=", 1)[0].strip() or lemmas.get(code)
            yield (
                code,
                BOOK_IDS[book],
                int(chapter),
                int(verse),
                token or fields[1],
                lemma,
                morphology,
                int(position),
                variant,
                "TAGNT",
            )


def morphology_rows(path: Path, language: str):
    with path.open(encoding="utf-8-sig") as source:
        for raw in source:
            fields = raw.rstrip("\r\n").split("\t")
            if len(fields) < 3 or not re.match(r"^[HG]:", fields[0]):
                continue
            code, example, description = (field.strip() for field in fields[:3])
            if code and description:
                yield code, language, example or None, description, path.name[:5]


def build(source_dir: Path, output: Path, backup: Path | None) -> None:
    hebrew = source_file(source_dir, "TBESH")
    greek = source_file(source_dir, "TBESG")
    tahot = source_files(source_dir, "TAHOT")
    tagnt = source_files(source_dir, "TAGNT")
    tehmc = source_file(source_dir, "TEHMC")
    tegmc = source_file(source_dir, "TEGMC")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".db.tmp")
    temporary.unlink(missing_ok=True)
    database = sqlite3.connect(temporary)
    try:
        database.executescript("""
          CREATE TABLE strong_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            strong_number TEXT NOT NULL,
            extended_strong_number TEXT NOT NULL,
            disambiguated_strong_number TEXT,
            unified_strong_number TEXT,
            testament TEXT NOT NULL,
            language TEXT NOT NULL,
            original_word TEXT NOT NULL,
            transliteration TEXT,
            pronunciation TEXT,
            morphology TEXT,
            gloss TEXT,
            short_definition TEXT,
            definition_source TEXT,
            definition_fr TEXT,
            source TEXT NOT NULL,
            source_url TEXT NOT NULL,
            license TEXT NOT NULL
          );
          CREATE INDEX idx_strong_number
            ON strong_entries(strong_number);
          CREATE INDEX idx_strong_extended
            ON strong_entries(extended_strong_number);
          CREATE INDEX idx_strong_language
            ON strong_entries(language);
          CREATE INDEX idx_strong_transliteration
            ON strong_entries(transliteration COLLATE NOCASE);
          CREATE INDEX idx_strong_gloss
            ON strong_entries(gloss COLLATE NOCASE);
          CREATE TABLE strong_occurrences(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            strong_number TEXT NOT NULL,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            token_original TEXT NOT NULL,
            lemma TEXT,
            morphology TEXT,
            token_position INTEGER NOT NULL,
            textual_variant TEXT,
            source_dataset TEXT NOT NULL
          );
          CREATE INDEX idx_occurrence_strong
            ON strong_occurrences(strong_number,book_id,chapter,verse);
          CREATE INDEX idx_occurrence_reference
            ON strong_occurrences(book_id,chapter,verse,token_position);
          CREATE TABLE morphology_codes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            language TEXT NOT NULL,
            example TEXT,
            description_source TEXT NOT NULL,
            description_fr TEXT,
            source TEXT NOT NULL
          );
          CREATE INDEX idx_morphology_code ON morphology_codes(code);
          CREATE TABLE metadata(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        """)
        sql = """INSERT INTO strong_entries(
          strong_number,extended_strong_number,disambiguated_strong_number,
          unified_strong_number,testament,language,original_word,
          transliteration,pronunciation,morphology,gloss,short_definition,
          definition_source,definition_fr,source,source_url,license
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"""
        database.executemany(
            sql, rows(hebrew, "Ancien Testament", "Hébreu")
        )
        database.executemany(
            sql, rows(greek, "Nouveau Testament / Septante", "Grec")
        )
        counts = dict(
            database.execute(
                "SELECT source, COUNT(*) FROM strong_entries GROUP BY source"
            )
        )
        lemmas = {
            row[0]: row[1]
            for row in database.execute(
                """SELECT strong_number, MIN(original_word)
                   FROM strong_entries GROUP BY strong_number"""
            )
        }
        occurrence_sql = """INSERT INTO strong_occurrences(
          strong_number,book_id,chapter,verse,token_original,lemma,morphology,
          token_position,textual_variant,source_dataset
        ) VALUES(?,?,?,?,?,?,?,?,?,?)"""
        for path in tahot:
            database.executemany(occurrence_sql, tahot_occurrences(path, lemmas))
        for path in tagnt:
            database.executemany(occurrence_sql, tagnt_occurrences(path, lemmas))
        database.executemany(
            """INSERT INTO morphology_codes(
              code,language,example,description_source,source
            ) VALUES(?,?,?,?,?)""",
            morphology_rows(tehmc, "Hébreu"),
        )
        database.executemany(
            """INSERT INTO morphology_codes(
              code,language,example,description_source,source
            ) VALUES(?,?,?,?,?)""",
            morphology_rows(tegmc, "Grec"),
        )
        occurrence_counts = dict(
            database.execute(
                """SELECT source_dataset, COUNT(*) FROM strong_occurrences
                   GROUP BY source_dataset"""
            )
        )
        metadata = {
            "source": "STEPBible Tyndale Brief lexicons TBESH / TBESG",
            "source_url": SOURCE_URL,
            "license": LICENSE,
            "tbesh_file": hebrew.name,
            "tbesh_sha256": sha256(hebrew),
            "tbesh_entries": str(counts.get("TBESH", 0)),
            "tbesg_file": greek.name,
            "tbesg_sha256": sha256(greek),
            "tbesg_entries": str(counts.get("TBESG", 0)),
            "hebrew_meaning_policy": (
                "Excluded: upstream requests Online Bible permission"
            ),
            "definition_fr_policy": "NULL: no verified French source",
            "tahot_files": " | ".join(path.name for path in tahot),
            "tahot_occurrences": str(occurrence_counts.get("TAHOT", 0)),
            "tagnt_files": " | ".join(path.name for path in tagnt),
            "tagnt_occurrences": str(occurrence_counts.get("TAGNT", 0)),
            "tehmc_file": tehmc.name,
            "tegmc_file": tegmc.name,
            "occurrence_policy": (
                "Original-language tokens only; never aligned to French words"
            ),
        }
        for path in [*tahot, *tagnt, tehmc, tegmc]:
            metadata[f"sha256_{path.name[:5].lower()}_{sha256(path)[:8]}"] = sha256(path)
        database.executemany(
            "INSERT INTO metadata(key,value) VALUES(?,?)", metadata.items()
        )
        database.commit()
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise SystemExit(f"SQLite integrity check failed: {integrity}")
        for code in ("H3588", "H430", "H7225", "G26", "G3056"):
            found = database.execute(
                """SELECT 1 FROM strong_entries
                   WHERE strong_number = ? OR strong_number LIKE ? LIMIT 1""",
                (code, f"{code}%"),
            ).fetchone()
            if not found:
                raise SystemExit(f"Required Strong entry missing: {code}")
            occurrence = database.execute(
                "SELECT 1 FROM strong_occurrences WHERE strong_number=? LIMIT 1",
                (code,),
            ).fetchone()
            if not occurrence:
                raise SystemExit(f"Required Strong occurrence missing: {code}")
    finally:
        database.close()

    if output.exists() and backup is not None:
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output, backup)
    os.replace(temporary, output)
    print(
        f"Created {output} with {counts.get('TBESH', 0)} Hebrew/Aramaic "
        f"and {counts.get('TBESG', 0)} Greek entries."
        f" Imported {occurrence_counts.get('TAHOT', 0)} TAHOT and "
        f"{occurrence_counts.get('TAGNT', 0)} TAGNT occurrences."
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, default=SOURCE_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--backup", type=Path, default=BACKUP)
    parser.add_argument("--no-backup", action="store_true")
    arguments = parser.parse_args()
    build(
        arguments.source_dir,
        arguments.output,
        None if arguments.no_backup else arguments.backup,
    )


if __name__ == "__main__":
    main()
