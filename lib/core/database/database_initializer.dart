import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:echo_bible/core/database/study_schema.dart';

class DatabaseInitializer {
  static Future<void>? _initialization;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'bible.db');

    if (await databaseExists(path)) {
      if (await _containsBibleData(path)) {
        await _installBundledVersionsIfNeeded(path);
        return;
      }
      await deleteDatabase(path);
    }

    await Directory(dirname(path)).create(recursive: true);
    final data = await rootBundle.load('assets/database/core_bible.db');
    await File(path).writeAsBytes(
      data.buffer.asUint8List(),
      flush: true,
    );
  }

  static Future<void> _installBundledVersionsIfNeeded(String path) async {
    Database? database;
    final seedPath = join(dirname(path), 'bible_versions_seed.db');
    try {
      database = await openDatabase(path);
      final versionTable = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bible_versions'",
      );
      var needsVersions = true;
      if (versionTable.isNotEmpty) {
        final versionCount = Sqflite.firstIntValue(
              await database.rawQuery('SELECT COUNT(*) FROM bible_versions'),
            ) ??
            0;
        needsVersions = versionCount < 3;
      }

      await StudySchema.ensure(database);
      final data = await rootBundle.load('assets/database/core_bible.db');
      await File(seedPath).writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
      await database.execute('ATTACH DATABASE ? AS bundled', [seedPath]);
      await database.transaction((transaction) async {
        if (needsVersions) {
          await transaction.execute('''
            INSERT OR REPLACE INTO bible_versions(
              id, code, name, abbreviation, language, copyright, is_default
            )
            SELECT id, code, name, abbreviation, language, copyright, is_default
            FROM bundled.bible_versions
          ''');
          await transaction.execute('''
            INSERT OR REPLACE INTO verse_translations(version_id, verse_id, text)
            SELECT version_id, verse_id, text
            FROM bundled.verse_translations
          ''');
        }
        await transaction.execute('''
          INSERT OR REPLACE INTO strong_dictionary(
            strong, lemma, language, definition, transliteration,
            gloss, morphology, source, source_url, license
          )
          SELECT strong, lemma, language, definition, transliteration,
            gloss, morphology, source, source_url, license
          FROM bundled.strong_dictionary
          WHERE source IN ('TBESH', 'TBESG')
        ''');
      });
      await database.execute('DETACH DATABASE bundled');
    } finally {
      await database?.close();
      final seed = File(seedPath);
      if (await seed.exists()) await seed.delete();
    }
  }

  static Future<bool> _containsBibleData(String path) async {
    Database? database;
    try {
      database = await openDatabase(path, readOnly: true);
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'verses')",
      );
      final names = tables.map((table) => table['name']).toSet();
      return names.contains('books') && names.contains('verses');
    } catch (_) {
      return false;
    } finally {
      await database?.close();
    }
  }
}
