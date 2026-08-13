"""Build the production Strong lexicon from official STEPBible sources."""

import argparse
import csv
import datetime as dt
import difflib
import hashlib
import html
import io
import os
import re
import shutil
import sqlite3
import unicodedata
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "bible_builder" / "sources" / "stepbible"
FRENCH_SOURCE_DIR = ROOT / "bible_builder" / "sources" / "concordance_bible"
OUTPUT = ROOT / "assets" / "database" / "strong.db"
BACKUP = ROOT / "bible_builder" / "backups" / "strong.db.latest.bak"
SOURCE_URL = "https://github.com/STEPBible/STEPBible-Data"
LICENSE = "CC BY 4.0"
FRENCH_SOURCE_URL = "https://concordance.bible/Sg1910/download/"
FRENCH_ATTRIBUTION = (
    'Numéros Strong affectés en 2026 par “Concordances et Traductions '
    'de la Bible” (concordance.bible).'
)

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
FRENCH_BOOK_IDS = {
    code: index + 1
    for index, code in enumerate(
        (
            "Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs "
            "1Chr 2Chr Ezra Neh Esth Job Ps Prov Eccl Song Isa Jer Lam "
            "Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech "
            "Mal Matt Mark Luke John Acts Rom 1Cor 2Cor Gal Eph Phil Col "
            "1Thess 2Thess 1Tim 2Tim Titus Phlm Heb Jas 1Pet 2Pet 1John "
            "2John 3John Jude Rev"
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


def normalized_french(value: str) -> str:
    """Accent-insensitive key used for French lookup, never for display."""
    decomposed = unicodedata.normalize("NFKD", html.unescape(value).casefold())
    without_marks = "".join(
        character
        for character in decomposed
        if unicodedata.category(character) != "Mn"
    )
    return " ".join(re.findall(r"[a-z0-9]+", without_marks))


def french_csv_rows(archive: Path, member: str) -> list[dict[str, str]]:
    if not archive.exists():
        raise SystemExit(
            f"Missing {archive}. Download it from {FRENCH_SOURCE_URL}"
        )
    with zipfile.ZipFile(archive) as bundle, bundle.open(member) as raw:
        reader = csv.DictReader(
            io.TextIOWrapper(raw, encoding="utf-8-sig"), delimiter="\t"
        )
        return list(reader)


def french_tokens(markup: str):
    pattern = re.compile(
        r'<w\s+[^>]*strong="([^"]+)"[^>]*>(.*?)</w>', re.I | re.S
    )
    for position, match in enumerate(pattern.finditer(markup), start=1):
        strongs = tuple(
            dict.fromkeys(
                canonical(code)
                for code in re.findall(r"[HG]0*\d+[A-Za-z]*", match.group(1), re.I)
            )
        )
        surface = plain(match.group(2))
        if strongs:
            yield position, surface, normalized_french(surface), strongs


def build_versification_pairs(
    source_rows: list[dict[str, str]], canonical_rows: list[dict[str, str]]
):
    """Align official WLC/NA references with historical Segond references.

    Exact verse text is authoritative. Small changed/split blocks are paired
    locally by their ordered Strong sequences, and retain an explicit method
    and confidence instead of silently rewriting Bible databases.
    """
    for book in FRENCH_BOOK_IDS:
        source = [row for row in source_rows if row["book_id"] == book]
        target = [row for row in canonical_rows if row["book_id"] == book]
        matcher = difflib.SequenceMatcher(
            None,
            [row["text"] for row in source],
            [row["text"] for row in target],
            autojunk=False,
        )
        for tag, source_start, source_end, target_start, target_end in matcher.get_opcodes():
            if tag == "equal":
                for offset in range(target_end - target_start):
                    yield source[source_start + offset], target[target_start + offset], "exact_text", 1.0
                continue
            candidates = source[max(0, source_start - 1) : min(len(source), source_end + 1)]
            for target_row in target[target_start:target_end]:
                target_codes = [code for _, _, _, codes in french_tokens(target_row["text"]) for code in codes]
                best_row = None
                best_score = -1.0
                for source_row in candidates:
                    source_codes = [code for _, _, _, codes in french_tokens(source_row["text"]) for code in codes]
                    score = difflib.SequenceMatcher(None, source_codes, target_codes, autojunk=False).ratio()
                    if score > best_score:
                        best_row, best_score = source_row, score
                if best_row is None:
                    best_row = target_row
                    best_score = 0.0
                yield best_row, target_row, "strong_sequence", best_score


def import_french_alignment(database: sqlite3.Connection, source_dir: Path):
    canonical_archive = source_dir / "Sg1910-csv_v11n.zip"
    editorial_archive = source_dir / "Sg1910-csv.zip"
    canonical_rows = french_csv_rows(canonical_archive, "Sg1910_v11n.csv")
    editorial_rows = french_csv_rows(editorial_archive, "Sg1910.csv")
    mappings = list(build_versification_pairs(editorial_rows, canonical_rows))
    mapping_by_canonical = {
        (target["book_id"], int(target["num_chapter"]), int(target["num_verse"])):
        (source, method, confidence)
        for source, target, method, confidence in mappings
    }
    token_count = 0
    association_count = 0
    empty_count = 0
    for row in canonical_rows:
        book_code = row["book_id"]
        chapter = int(row["num_chapter"])
        verse = int(row["num_verse"])
        source, method, confidence = mapping_by_canonical[(book_code, chapter, verse)]
        database.execute(
            """INSERT INTO versification_mappings(
              source_dataset,source_book_code,source_chapter,source_verse,
              book_id,chapter,verse,method,confidence
            ) VALUES(?,?,?,?,?,?,?,?,?)""",
            (
                "Sg1910-WLC-NA",
                source["book_id"],
                int(source["num_chapter"]),
                int(source["num_verse"]),
                FRENCH_BOOK_IDS[book_code],
                chapter,
                verse,
                method,
                confidence,
            ),
        )
        for position, surface, normalized, strongs in french_tokens(row["text"]):
            cursor = database.execute(
                """INSERT INTO french_verse_tokens(
                  book_id,chapter,verse,token_index,surface,normalized_surface,
                  is_translated,source_dataset
                ) VALUES(?,?,?,?,?,?,?,?)""",
                (
                    FRENCH_BOOK_IDS[book_code],
                    chapter,
                    verse,
                    position,
                    surface,
                    normalized,
                    int(bool(surface.strip())),
                    "Sg1910-v11n",
                ),
            )
            token_id = cursor.lastrowid
            database.executemany(
                """INSERT INTO french_token_strongs(
                  token_id,strong_number,strong_order
                ) VALUES(?,?,?)""",
                ((token_id, code, order) for order, code in enumerate(strongs, start=1)),
            )
            token_count += 1
            association_count += len(strongs)
            empty_count += int(not surface.strip())
    return {
        "french_tokens": token_count,
        "french_associations": association_count,
        "french_untranslated_tokens": empty_count,
        "versification_mappings": len(mappings),
        "french_editorial_archive": editorial_archive.name,
        "french_editorial_sha256": sha256(editorial_archive),
        "french_historical_archive": canonical_archive.name,
        "french_historical_sha256": sha256(canonical_archive),
    }


def build(
    source_dir: Path,
    french_source_dir: Path,
    output: Path,
    backup: Path | None,
) -> None:
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
          CREATE TABLE french_verse_tokens(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            token_index INTEGER NOT NULL,
            surface TEXT NOT NULL,
            normalized_surface TEXT NOT NULL,
            is_translated INTEGER NOT NULL CHECK(is_translated IN (0,1)),
            source_dataset TEXT NOT NULL
          );
          CREATE UNIQUE INDEX idx_french_token_reference
            ON french_verse_tokens(book_id,chapter,verse,token_index);
          CREATE INDEX idx_french_token_surface
            ON french_verse_tokens(normalized_surface,book_id,chapter,verse);
          CREATE TABLE french_token_strongs(
            token_id INTEGER NOT NULL,
            strong_number TEXT NOT NULL,
            strong_order INTEGER NOT NULL,
            PRIMARY KEY(token_id,strong_number),
            FOREIGN KEY(token_id) REFERENCES french_verse_tokens(id)
          );
          CREATE INDEX idx_french_association_strong
            ON french_token_strongs(strong_number,token_id);
          CREATE TABLE versification_mappings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_dataset TEXT NOT NULL,
            source_book_code TEXT NOT NULL,
            source_chapter INTEGER NOT NULL,
            source_verse INTEGER NOT NULL,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            method TEXT NOT NULL,
            confidence REAL NOT NULL
          );
          CREATE INDEX idx_versification_source
            ON versification_mappings(
              source_dataset,source_book_code,source_chapter,source_verse
            );
          CREATE INDEX idx_versification_canonical
            ON versification_mappings(book_id,chapter,verse);
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
        french_metadata = import_french_alignment(database, french_source_dir)
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
            "french_source": "Segond 1910 avec numéros Strong",
            "french_source_url": FRENCH_SOURCE_URL,
            "french_text_license": "Domaine public",
            "french_strong_license": "Utilisation libre avec attribution",
            "french_attribution": FRENCH_ATTRIBUTION,
            "french_retrieved_at": dt.date.today().isoformat(),
            "french_alignment_policy": (
                "Real source mapping only; no automatic translation"
            ),
            **{key: str(value) for key, value in french_metadata.items()},
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
        for book_id, chapter, verse, surface, code in (
            (1, 1, 1, "commencement", "H7225"),
            (43, 1, 1, "parole", "G3056"),
        ):
            found = database.execute(
                """SELECT 1 FROM french_verse_tokens token
                   JOIN french_token_strongs link ON link.token_id=token.id
                   WHERE token.book_id=? AND token.chapter=? AND token.verse=?
                     AND token.normalized_surface=? AND link.strong_number=?""",
                (book_id, chapter, verse, surface, code),
            ).fetchone()
            if not found:
                raise SystemExit(
                    f"Required French Strong alignment missing: {surface} -> {code}"
                )
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
    parser.add_argument(
        "--french-source-dir", type=Path, default=FRENCH_SOURCE_DIR
    )
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--backup", type=Path, default=BACKUP)
    parser.add_argument("--no-backup", action="store_true")
    arguments = parser.parse_args()
    build(
        arguments.source_dir,
        arguments.french_source_dir,
        arguments.output,
        None if arguments.no_backup else arguments.backup,
    )


if __name__ == "__main__":
    main()
