import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openModule(String relativePath) async {
    final file = File('release_resources/$relativePath');
    expect(file.existsSync(), isTrue, reason: file.path);
    return databaseFactoryFfi.openDatabase(file.absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
  }

  test('prépare les ressources d’étude hors du bundle initial', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('assets/database/strong.db')));
    expect(pubspec, isNot(contains('assets/database/cross_references.db')));
    expect(pubspec, isNot(contains('assets/database/nave.db')));

    final strong = await openModule('common/strong/strong.db');
    expect(
        Sqflite.firstIntValue(
            await strong.rawQuery('SELECT COUNT(*) FROM strong_entries')),
        greaterThan(20000));
    expect(
        await strong.query('strong_entries',
            where: 'strong_number=?', whereArgs: ['G26']),
        isNotEmpty);
    expect(
        await strong.query('strong_entries',
            where: 'strong_number=?', whereArgs: ['H430']),
        isNotEmpty);
    final strongColumns = await strong.rawQuery(
      'PRAGMA table_info(strong_entries)',
    );
    expect(
      strongColumns.map((column) => column['name']),
      containsAll([
        'testament',
        'extended_strong_number',
        'disambiguated_strong_number',
        'unified_strong_number',
        'language',
        'original_word',
        'transliteration',
        'pronunciation',
        'morphology',
        'short_definition',
        'definition_source',
        'definition_fr',
      ]),
    );
    expect(
      Sqflite.firstIntValue(
        await strong.rawQuery('SELECT COUNT(*) FROM strong_occurrences'),
      ),
      greaterThan(600000),
    );
    expect(
      await strong.query(
        'strong_occurrences',
        where: 'strong_number=? AND book_id=1 AND chapter=1 AND verse=1',
        whereArgs: ['H7225'],
      ),
      isNotEmpty,
    );
    expect(
      Sqflite.firstIntValue(
        await strong.rawQuery('SELECT COUNT(*) FROM morphology_codes'),
      ),
      greaterThan(90),
    );
    await strong.close();

    final cross =
        await openModule('common/cross_references/cross_references.db');
    expect(
        Sqflite.firstIntValue(
            await cross.rawQuery('SELECT COUNT(*) FROM cross_references')),
        greaterThan(300000));
    expect(
        await cross.query('cross_references',
            where:
                'source_book_id=43 AND source_chapter=3 AND source_verse=16'),
        isNotEmpty);
    final crossColumns = await cross.rawQuery(
      'PRAGMA table_info(cross_references)',
    );
    expect(
      crossColumns.map((column) => column['name']),
      containsAll([
        'source_book_id',
        'target_book_id',
        'target_verse_start',
        'target_verse_end',
        'score',
        'source_dataset',
      ]),
    );
    await cross.close();

    final nave = await openModule('en/nave/nave_core.db');
    expect(
        Sqflite.firstIntValue(
            await nave.rawQuery('SELECT COUNT(*) FROM nave_topics')),
        greaterThan(5000));
    expect(
        await nave.query('nave_topics',
            where: 'normalized_en=?', whereArgs: ['faith']),
        isNotEmpty);
    expect(await nave.query('nave_translations'), isEmpty);
    await nave.close();

    final naveFrench = await openModule('fr/nave/nave_fr.db');
    expect(await naveFrench.query('nave_translations'), isNotEmpty);
    await naveFrench.close();
  });
}
