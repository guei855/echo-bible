"""Build an offline Nave topical index from the public-domain CCEL XML."""

import re
import sqlite3
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "bible_builder/sources/nave/nave.xml"
OUTPUT = ROOT / "assets/database/nave.db"
BOOKS = ['Gen','Exod','Lev','Num','Deut','Josh','Judg','Ruth','1Sam','2Sam',
 '1Kgs','2Kgs','1Chr','2Chr','Ezra','Neh','Esth','Job','Ps','Prov','Eccl',
 'Song','Isa','Jer','Lam','Ezek','Dan','Hos','Joel','Amos','Obad','Jonah',
 'Mic','Nah','Hab','Zeph','Hag','Zech','Mal','Matt','Mark','Luke','John',
 'Acts','Rom','1Cor','2Cor','Gal','Eph','Phil','Col','1Thess','2Thess',
 '1Tim','2Tim','Titus','Phlm','Heb','Jas','1Pet','2Pet','1John','2John',
 '3John','Jude','Rev']
BOOK_IDS = {name: i + 1 for i, name in enumerate(BOOKS)}

# Traductions éditoriales minimales, séparées du texte anglais et explicitement
# marquées « manual ». Elles ne constituent pas une édition française de Nave.
FRENCH_TITLES = {
    'ADAM': 'Adam',
    'FAITH': 'Foi',
    'GOD': 'Dieu',
    'GRACE OF GOD': 'Grâce de Dieu',
    'GRACES': 'Grâces',
    'HOLY SPIRIT': 'Saint-Esprit',
    'JESUS, THE CHRIST': 'Jésus-Christ',
    'LOVE': 'Amour',
    'PRAYER': 'Prière',
    'SALVATION': 'Salut',
    'SIN': 'Péché',
}


def normalize(value: str) -> str:
    value = unicodedata.normalize('NFKD', value).encode('ascii','ignore').decode()
    return re.sub(r'[^a-z0-9]+', ' ', value.lower()).strip()


def label(element) -> str:
    text = ''.join(element.itertext())
    first_ref = next(iter(element.findall('.//scripRef')), None)
    if first_ref is not None:
        ref_text = ''.join(first_ref.itertext())
        pos = text.find(ref_text)
        if pos >= 0:
            text = text[:pos]
    return re.sub(r'^[\s.\-–—]+|\s+$', '', text).strip()


def ref_parts(osis: str):
    value = osis.removeprefix('Bible:')
    start, _, end = value.partition('-')
    bits = start.split('.')
    if len(bits) < 2 or bits[0] not in BOOK_IDS:
        return None
    chapter = int(bits[1]); verse = int(bits[2]) if len(bits) > 2 else 1
    end_verse = None
    if end:
        end_bits = end.split('.')
        if len(end_bits) > 2 and end_bits[0] == bits[0] and int(end_bits[1]) == chapter:
            end_verse = int(end_bits[2])
    return BOOK_IDS[bits[0]], chapter, verse, end_verse


def main() -> None:
    OUTPUT.unlink(missing_ok=True)
    root = ET.parse(SOURCE).getroot()
    db = sqlite3.connect(OUTPUT)
    db.executescript("""
      CREATE TABLE nave_topics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title_en TEXT NOT NULL,
        title_fr TEXT,
        normalized_en TEXT NOT NULL,
        normalized_fr TEXT
      );
      CREATE TABLE nave_sections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL,
        title_en TEXT NOT NULL,
        title_fr TEXT,
        FOREIGN KEY(topic_id) REFERENCES nave_topics(id)
      );
      CREATE TABLE nave_references(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL,
        section_id INTEGER,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse_start INTEGER NOT NULL,
        verse_end INTEGER,
        FOREIGN KEY(topic_id) REFERENCES nave_topics(id),
        FOREIGN KEY(section_id) REFERENCES nave_sections(id)
      );
      CREATE TABLE nave_translations(
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        translation_status TEXT NOT NULL,
        translation_source TEXT NOT NULL,
        PRIMARY KEY(entity_type,entity_id,language)
      );
      CREATE INDEX idx_topics_normalized_en ON nave_topics(normalized_en);
      CREATE INDEX idx_topics_normalized_fr ON nave_topics(normalized_fr);
      CREATE INDEX idx_sections_topic ON nave_sections(topic_id);
      CREATE INDEX idx_nave_refs_topic ON nave_references(topic_id,section_id);
      CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    """)
    refs = skipped = 0
    for glossary in root.iter('glossary'):
      children = list(glossary)
      for index, term in enumerate(children):
        if term.tag != 'term': continue
        title = ''.join(term.itertext()).strip()
        if not title: continue
        title_fr = FRENCH_TITLES.get(title.upper())
        topic_id = db.execute(
            '''INSERT INTO nave_topics(
                 title_en,title_fr,normalized_en,normalized_fr
               ) VALUES(?,?,?,?)''',
            (title, title_fr, normalize(title), normalize(title_fr) if title_fr else None),
        ).lastrowid
        if title_fr:
            db.execute(
                '''INSERT INTO nave_translations(
                     entity_type,entity_id,language,translated_text,
                     translation_status,translation_source
                   ) VALUES(?,?,?,?,?,?)''',
                ('topic', topic_id, 'fr', title_fr, 'manual',
                 'ECHO BIBLE editorial glossary'),
            )
        # ThML places the matching <def> immediately after <term>.
        if index + 1 >= len(children) or children[index + 1].tag != 'def': continue
        for paragraph in children[index + 1].findall('.//p'):
            title_part = label(paragraph) or 'Références générales'
            subtopic_id = db.execute(
                'INSERT INTO nave_sections(topic_id,title_en) VALUES(?,?)',
                (topic_id, title_part),
            ).lastrowid
            for item in paragraph.findall('.//scripRef'):
                parsed = ref_parts(item.get('osisRef',''))
                if parsed is None: skipped += 1; continue
                db.execute('INSERT INTO nave_references(topic_id,section_id,book_id,chapter,verse_start,verse_end) VALUES(?,?,?,?,?,?)',
                           (topic_id, subtopic_id, *parsed)); refs += 1
    db.executemany('INSERT INTO metadata VALUES(?,?)', [
      ('source',"Orville J. Nave, Nave's Topical Bible"),
      ('source_url','https://ccel.org/ccel/n/nave/bible.xml'),
      ('license','Public Domain'),
      ('french_layer','Manual ECHO BIBLE topic glossary; not an official French Nave edition')])
    db.commit(); topics = db.execute('SELECT COUNT(*) FROM nave_topics').fetchone()[0]
    db.close(); print(f'Created {OUTPUT}: {topics} topics, {refs} references, {skipped} skipped.')


if __name__ == '__main__':
    main()
