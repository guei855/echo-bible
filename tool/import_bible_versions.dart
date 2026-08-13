import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final databaseFile = File('assets/database/bible.db');
  if (!databaseFile.existsSync()) {
    stderr.writeln('Base introuvable : ${databaseFile.absolute.path}');
    exitCode = 1;
    return;
  }

  final db = await databaseFactory.openDatabase(databaseFile.absolute.path);
  try {
    await _ensureSchema(db);
    final verseRows = await db.rawQuery('''
      SELECT v.id, b.abbreviation, v.chapter_number, v.verse_number
      FROM verses v
      JOIN books b ON b.id = v.book_id
    ''');
    final verseIds = <String, int>{
      for (final row in verseRows)
        '${row['abbreviation']}.${row['chapter_number']}.${row['verse_number']}':
            row['id'] as int,
    };

    await db.transaction((transaction) async {
      await transaction.insert(
        'bible_versions',
        {
          'id': 1,
          'code': 'fra_lsg',
          'name': 'Louis Segond 1910',
          'abbreviation': 'LSG',
          'language': 'fra',
          'copyright': 'Domaine public',
          'is_default': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.rawInsert('''
        INSERT OR IGNORE INTO verse_translations(version_id, verse_id, text)
        SELECT 1, id, text FROM verses
      ''');
    });

    await _importVersion(
      db: db,
      verseIds: verseIds,
      versionId: 2,
      code: 'fra_fob',
      name: 'Bible Ostervald',
      abbreviation: 'FOB',
      source: File('assets/database/fra_fob_usfx.xml'),
    );
    await _importVersion(
      db: db,
      verseIds: verseIds,
      versionId: 3,
      code: 'fra_jnd',
      name: 'Bible J.N. Darby',
      abbreviation: 'JND',
      source: File('assets/database/frajnd_usfx.xml'),
    );

    final counts = await db.rawQuery('''
      SELECT bv.abbreviation, COUNT(vt.verse_id) AS verse_count
      FROM bible_versions bv
      LEFT JOIN verse_translations vt ON vt.version_id = bv.id
      GROUP BY bv.id
      ORDER BY bv.id
    ''');
    for (final count in counts) {
      stdout
          .writeln('${count['abbreviation']}: ${count['verse_count']} versets');
    }
  } finally {
    await db.close();
  }
}

Future<void> _ensureSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS bible_versions(
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      abbreviation TEXT NOT NULL,
      language TEXT NOT NULL,
      copyright TEXT,
      is_default INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS verse_translations(
      version_id INTEGER NOT NULL,
      verse_id INTEGER NOT NULL,
      text TEXT NOT NULL,
      PRIMARY KEY(version_id, verse_id),
      FOREIGN KEY(version_id) REFERENCES bible_versions(id) ON DELETE CASCADE,
      FOREIGN KEY(verse_id) REFERENCES verses(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_verse_translations_verse
    ON verse_translations(verse_id, version_id)
  ''');
}

Future<void> _importVersion({
  required Database db,
  required Map<String, int> verseIds,
  required int versionId,
  required String code,
  required String name,
  required String abbreviation,
  required File source,
}) async {
  stdout.writeln('Lecture de ${source.path}…');
  final document = XmlDocument.parse(await source.readAsString());
  final translations = <int, String>{};
  var parsed = 0;
  var unmatched = 0;

  for (final verse in document.findAllElements('v')) {
    final bcv = verse.getAttribute('bcv');
    if (bcv == null) continue;
    final match = RegExp(r'^([^.]+)\.(\d+)\.(\d+)').firstMatch(bcv);
    if (match == null) continue;
    parsed++;
    final key = '${match.group(1)}.${match.group(2)}.${match.group(3)}';
    final verseId = verseIds[key];
    if (verseId == null) {
      unmatched++;
      continue;
    }
    final text = _extractVerseText(verse);
    if (text.isNotEmpty) translations[verseId] = text;
  }

  await db.transaction((transaction) async {
    await transaction.insert(
      'bible_versions',
      {
        'id': versionId,
        'code': code,
        'name': name,
        'abbreviation': abbreviation,
        'language': 'fra',
        'copyright': 'Domaine public',
        'is_default': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await transaction.delete(
      'verse_translations',
      where: 'version_id = ?',
      whereArgs: [versionId],
    );
    final batch = transaction.batch();
    for (final translation in translations.entries) {
      batch.insert('verse_translations', {
        'version_id': versionId,
        'verse_id': translation.key,
        'text': translation.value,
      });
    }
    await batch.commit(noResult: true);
  });

  stdout.writeln(
    '$abbreviation : $parsed marqueurs, ${translations.length} textes importés, '
    '$unmatched références non alignées.',
  );
}

String _extractVerseText(XmlElement verse) {
  final buffer = StringBuffer();
  XmlNode? sibling = verse.nextSibling;
  while (sibling != null) {
    if (sibling is XmlElement &&
        const {'v', 've', 'c'}.contains(sibling.name.local)) {
      break;
    }
    buffer.write(_extractVisibleText(sibling));
    sibling = sibling.nextSibling;
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _extractVisibleText(XmlNode node) {
  if (node is XmlText) return node.value;
  if (node is! XmlElement) return '';
  if (const {'f', 'x', 'ref', 'note', 'milestone'}.contains(node.name.local)) {
    return '';
  }
  return node.children.map(_extractVisibleText).join();
}
