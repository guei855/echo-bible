#!/usr/bin/env python3
"""Build the offline Vigouroux dictionary from Wikisource and verified DjVu scans."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import html
from html.parser import HTMLParser
import json
import re
import sqlite3
import subprocess
import threading
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://fr.wikisource.org/w/api.php"
CATEGORY = "Catégorie:Articles du Dictionnaire de la Bible"
SOURCE_ROOT = Path("bible_builder/sources/dictionary/vigouroux")
USER_AGENT = "ECHO-BIBLE/1.0 (offline Vigouroux builder; github.com/guei855/echo-bible)"
VOLUMES = {
    "I": "Dictionnaire_de_la_Bible_-_F._Vigouroux_-_Tome_I.djvu",
    "II": "Dictionnaire_de_la_Bible_-_F._Vigouroux_-_Tome_II.djvu",
    "III": "Dictionnaire_de_la_Bible_-_F._Vigouroux_-_Tome_III.djvu",
    "IV": "Dictionnaire_de_la_Bible_-_F._Vigouroux_-_Tome_IV.djvu",
    "V": "Dictionnaire_de_la_Bible_-_F._Vigouroux_-_Tome_V.djvu",
}
_REQUEST_LOCK = threading.Lock()
_LAST_REQUEST_AT = 0.0


def normalized(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).casefold()
    value = "".join(char for char in value if not unicodedata.combining(char))
    return " ".join(re.sub(r"[^a-z0-9œæ]+", " ", value).split())


def request_json(params: dict[str, str], retries: int = 12) -> dict:
    global _LAST_REQUEST_AT
    url = API + "?" + urllib.parse.urlencode(params)
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            # Wikimedia asks automated clients to serialize requests. Keeping a
            # small global interval also makes interrupted builds resumable
            # without immediately hitting HTTP 429 again.
            with _REQUEST_LOCK:
                delay = 1.5 - (time.monotonic() - _LAST_REQUEST_AT)
                if delay > 0:
                    time.sleep(delay)
                _LAST_REQUEST_AT = time.monotonic()
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.load(response)
        except Exception as error:  # Network retries are intentionally broad.
            last_error = error
            retry_after = getattr(error, "headers", {}).get("Retry-After") if getattr(error, "headers", None) else None
            time.sleep(max(float(retry_after or 0), min(5 * 2**attempt, 120)))
    raise RuntimeError(f"Wikisource unavailable after {retries} attempts: {url}") from last_error


class ArticleTextParser(HTMLParser):
    block_tags = {"p", "h1", "h2", "h3", "h4", "h5", "li", "br", "tr"}
    void_tags = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.skip_depth = 0
        self.started = False
        self.output_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        classes = set((attributes.get("class") or "").split())
        if "prp-pages-output" in classes:
            self.started = True
            self.output_depth = 1
            return
        if not self.started:
            return
        if tag not in self.void_tags:
            self.output_depth += 1
        if self.skip_depth:
            if tag not in self.void_tags:
                self.skip_depth += 1
            return
        if classes.intersection({"ws-noexport", "mw-editsection", "thumb", "gallery"}) or tag in {"style", "script", "form"}:
            if tag not in self.void_tags:
                self.skip_depth = 1
            return
        if self.started and tag in self.block_tags:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if not self.started:
            return
        if self.skip_depth:
            self.skip_depth -= 1
        elif tag in self.block_tags:
            self.parts.append("\n")
        if tag not in self.void_tags:
            self.output_depth -= 1
            if self.output_depth == 0:
                self.started = False

    def handle_data(self, data: str) -> None:
        if self.started and not self.skip_depth:
            self.parts.append(data)

    def text(self) -> str:
        value = html.unescape("".join(self.parts))
        value = unicodedata.normalize("NFC", value).replace("\xa0", " ")
        lines = [" ".join(line.split()) for line in value.splitlines()]
        return "\n\n".join(line for line in lines if line)


def category_members(cache: Path, refresh: bool) -> list[dict]:
    path = cache / "category.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text(encoding="utf-8"))
    members: list[dict] = []
    continuation: str | None = None
    while True:
        params = {
            "action": "query", "format": "json", "formatversion": "2",
            "list": "categorymembers", "cmtitle": CATEGORY, "cmnamespace": "0",
            "cmlimit": "500", "cmprop": "ids|title|timestamp",
        }
        if continuation:
            params["cmcontinue"] = continuation
        data = request_json(params)
        members.extend(data["query"]["categorymembers"])
        continuation = data.get("continue", {}).get("cmcontinue")
        if not continuation:
            break
    members = [item for item in members if item["title"].startswith("Dictionnaire de la Bible/") and "/Évangiles (Concorde des)/" not in item["title"]]
    path.write_text(json.dumps(members, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return members


def fetch_article(member: dict, cache: Path, refresh: bool) -> dict:
    path = cache / "articles" / f"{member['pageid']}.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text(encoding="utf-8"))
    data = request_json({
        "action": "parse", "format": "json", "formatversion": "2",
        "pageid": str(member["pageid"]), "prop": "text|wikitext|revid",
    })["parse"]
    parser = ArticleTextParser()
    parser.feed(data["text"])
    wikitext = data.get("wikitext", "")
    volume_match = re.search(r"Tome ([IV]+)\.djvu", wikitext)
    page_match = re.search(r'from="?([^" ]+)"?\s+to="?([^" ]+)', wikitext)
    rendered = html.unescape(data["text"])
    printed_start = re.search(r'itemprop="pageStart"[^>]*>([^<]+)', rendered)
    printed_end = re.search(r'itemprop="pageEnd"[^>]*>([^<]+)', rendered)
    if printed_start:
        page_reference = printed_start.group(1).strip()
        if printed_end and printed_end.group(1).strip() != page_reference:
            page_reference += f"–{printed_end.group(1).strip()}"
    else:
        page_reference = f"DjVu {page_match.group(1)}–{page_match.group(2)}" if page_match else None
    article = {
        "headword": member["title"].split("/", 1)[1],
        "content": parser.text(),
        "sourceKind": "wikisource_transcription",
        "sourceUrl": "https://fr.wikisource.org/wiki/" + urllib.parse.quote(member["title"].replace(" ", "_"), safe="/_"),
        "historyUrl": "https://fr.wikisource.org/w/index.php?title=" + urllib.parse.quote(member["title"].replace(" ", "_"), safe="_") + "&action=history",
        "pageId": member["pageid"], "revisionId": data["revid"],
        "revisionTimestamp": member.get("timestamp"),
        "volume": volume_match.group(1) if volume_match else None,
        "pageReference": page_reference,
        "quality": "Wikisource transcription",
    }
    if len(article["content"]) < 20:
        raise ValueError(f"Empty rendered article: {member['title']}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(article, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return article


def djvutxt_path(explicit: str | None) -> Path:
    candidates = [explicit, r"C:\Program Files (x86)\DjVuLibre\djvutxt.exe", "djvutxt"]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate)
        if path.exists() or candidate == "djvutxt":
            return path
    raise FileNotFoundError("djvutxt not found; install DjVuLibre or pass --djvutxt")


def clean_djvu_text(value: str) -> str:
    value = unicodedata.normalize("NFC", value)
    lines = []
    for raw in value.splitlines():
        line = re.sub(r"[\x00-\x1f]", "", raw).strip()
        if not line or re.fullmatch(r"[-.•* ]?\d+[»'.-]?", line):
            continue
        lines.append(line)
    text = "\n".join(lines)
    text = re.sub(r"(?<=\w)-\n(?=[a-zà-ÿ])", "", text)
    text = re.sub(r"(?<![.!?;:»])\n(?=[a-zà-ÿ])", " ", text)
    text = re.sub(r"[ \t]+", " ", text)
    return "\n\n".join(line.strip() for line in text.splitlines() if line.strip())


def extract_complements(config: dict, tool: Path) -> list[dict]:
    entries = []
    for item in config["entries"]:
        source_file = SOURCE_ROOT / VOLUMES[item["volume"]]
        pages = ",".join(str(page) for page in item["djvuPages"])
        page_texts = []
        for page in item["djvuPages"]:
            result = subprocess.run(
                [str(tool), f"-page={page}", str(source_file)],
                check=True,
                capture_output=True,
            )
            page_texts.append(result.stdout.decode("utf-8"))
        text = "\n".join(page_texts)
        start = text.find(item["start"])
        if start < 0:
            raise ValueError(f"Start marker missing for {item['headword']}: {item['start']}")
        end = text.find(item["end"], start + len(item["start"]))
        if end < 0:
            raise ValueError(f"End marker missing for {item['headword']}: {item['end']}")
        content = clean_djvu_text(text[start:end])
        entries.append({
            "headword": item["headword"], "content": content,
            "sourceKind": "djvu_embedded_text_layer", "sourceUrl": json.loads((SOURCE_ROOT / "SOURCE_MANIFEST.json").read_text(encoding="utf-8"))["volumes"][list(VOLUMES).index(item["volume"])]["description_url"],
            "historyUrl": None, "pageId": None, "revisionId": None,
            "revisionTimestamp": None, "volume": item["volume"],
            "pageReference": item["printedPages"], "quality": "Uncorrected embedded text layer; no new OCR",
            "aliases": item.get("aliases", []), "sourceFile": source_file.name,
            "djvuPages": pages,
        })
    return entries


def build_database(entries: list[dict], output: Path) -> dict:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    database = sqlite3.connect(output)
    fts5 = False
    try:
        database.executescript("""
          PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL;
          CREATE TABLE dictionary_entries(
            id INTEGER PRIMARY KEY, headword TEXT NOT NULL, normalized_headword TEXT NOT NULL,
            content TEXT NOT NULL, source TEXT NOT NULL, source_kind TEXT NOT NULL,
            source_url TEXT NOT NULL, history_url TEXT, volume TEXT, page_reference TEXT,
            page_id INTEGER, revision_id INTEGER, revision_timestamp TEXT, quality TEXT NOT NULL,
            source_file TEXT, djvu_pages TEXT
          );
          CREATE TABLE dictionary_aliases(
            id INTEGER PRIMARY KEY, entry_id INTEGER NOT NULL REFERENCES dictionary_entries(id) ON DELETE CASCADE,
            alias TEXT NOT NULL, normalized_alias TEXT NOT NULL, UNIQUE(entry_id, normalized_alias)
          );
          CREATE TABLE dictionary_metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
          CREATE INDEX idx_dictionary_headword ON dictionary_entries(normalized_headword);
          CREATE INDEX idx_dictionary_alias ON dictionary_aliases(normalized_alias);
        """)
        try:
            database.execute("CREATE VIRTUAL TABLE dictionary_fts USING fts5(headword, normalized_headword, content, content='dictionary_entries', content_rowid='id', tokenize='unicode61 remove_diacritics 2')")
            fts5 = True
        except sqlite3.OperationalError:
            database.execute("CREATE INDEX idx_dictionary_content ON dictionary_entries(content)")
        for entry in sorted(entries, key=lambda value: normalized(value["headword"])):
            cursor = database.execute("""INSERT INTO dictionary_entries(
              headword,normalized_headword,content,source,source_kind,source_url,history_url,volume,page_reference,
              page_id,revision_id,revision_timestamp,quality,source_file,djvu_pages
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", (
                entry["headword"], normalized(entry["headword"]), entry["content"],
                "Dictionnaire de la Bible — F. Vigouroux", entry["sourceKind"], entry["sourceUrl"], entry.get("historyUrl"),
                entry.get("volume"), entry.get("pageReference"), entry.get("pageId"), entry.get("revisionId"),
                entry.get("revisionTimestamp"), entry["quality"], entry.get("sourceFile"), entry.get("djvuPages"),
            ))
            for alias in entry.get("aliases", []):
                database.execute("INSERT OR IGNORE INTO dictionary_aliases(entry_id,alias,normalized_alias) VALUES(?,?,?)", (cursor.lastrowid, alias, normalized(alias)))
        metadata = {
            "title": "Dictionnaire de la Bible", "director": "Fulcran Vigouroux",
            "publisher": "Letouzey et Ané", "historical_publication": "1895-1912",
            "source_credit": "Gallica / Wikimedia Commons / Wikisource",
            "historical_work_status": "Public domain", "transcription_license": "CC BY-SA 4.0",
            "transformations": "Unicode NFC; whitespace normalization; removal of Wikisource navigation/UI; conservative line dehyphenation for DjVu complements",
            "entry_count": str(len(entries)), "wikisource_entry_count": str(sum(e["sourceKind"] == "wikisource_transcription" for e in entries)),
            "djvu_complement_count": str(sum(e["sourceKind"] == "djvu_embedded_text_layer" for e in entries)),
            "fts5": str(fts5).lower(),
        }
        database.executemany("INSERT INTO dictionary_metadata(key,value) VALUES(?,?)", metadata.items())
        if fts5:
            database.execute("INSERT INTO dictionary_fts(dictionary_fts) VALUES('rebuild')")
        database.commit()
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        aliases = database.execute("SELECT COUNT(*) FROM dictionary_aliases").fetchone()[0]
    finally:
        database.close()
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return {"entries": len(entries), "aliases": aliases, "fts5": fts5, "bytes": output.stat().st_size, "sha256": digest, "integrity_check": integrity}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("release_resources/fr/dictionaries/vigouroux_dictionary.db"))
    parser.add_argument("--cache", type=Path, default=SOURCE_ROOT / "cache")
    parser.add_argument("--report", type=Path, default=Path("bible_builder/VIGOUROUX_BUILD_REPORT.json"))
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--cache-only", action="store_true")
    parser.add_argument("--djvutxt")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    members = category_members(args.cache, args.refresh)
    if args.cache_only:
        articles = []
        missing = []
        for member in members:
            path = args.cache / "articles" / f"{member['pageid']}.json"
            if path.exists():
                articles.append(json.loads(path.read_text(encoding="utf-8")))
            else:
                missing.append(member["title"])
        if missing:
            raise RuntimeError(
                f"Cache incomplete: {len(missing)} article(s) missing; "
                "run again without --cache-only"
            )
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            articles = list(pool.map(lambda item: fetch_article(item, args.cache, args.refresh), members))
    config = json.loads((SOURCE_ROOT / "DJVU_COMPLEMENTS.json").read_text(encoding="utf-8"))
    complements = extract_complements(config, djvutxt_path(args.djvutxt))
    by_headword = {normalized(entry["headword"]): entry for entry in articles}
    for entry in complements:
        by_headword.setdefault(normalized(entry["headword"]), entry)
    report = build_database(list(by_headword.values()), args.output)
    report.update({
        "category_members": len(members),
        "wikisource_articles_fetched": len(articles),
        "wikisource_entries_retained": sum(
            entry["sourceKind"] == "wikisource_transcription"
            for entry in by_headword.values()
        ),
        "djvu_complements_defined": len(complements),
        "djvu_complements_retained": sum(
            entry["sourceKind"] == "djvu_embedded_text_layer"
            for entry in by_headword.values()
        ),
        "output": str(args.output),
    })
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
