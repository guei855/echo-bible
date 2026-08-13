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
    expect(
      Sqflite.firstIntValue(
        await strong.rawQuery('SELECT COUNT(*) FROM french_verse_tokens'),
      ),
      417615,
    );
    expect(
      Sqflite.firstIntValue(
        await strong.rawQuery('SELECT COUNT(*) FROM french_token_strongs'),
      ),
      422771,
    );
    expect(
      await strong.rawQuery('''
        SELECT token.surface,link.strong_number
        FROM french_verse_tokens token
        JOIN french_token_strongs link ON link.token_id=token.id
        WHERE token.book_id=1 AND token.chapter=1 AND token.verse=1
          AND token.normalized_surface='commencement'
      '''),
      [containsPair('strong_number', 'H7225')],
    );
    expect(
      await strong.rawQuery('''
        SELECT token.surface,link.strong_number
        FROM french_verse_tokens token
        JOIN french_token_strongs link ON link.token_id=token.id
        WHERE token.book_id=43 AND token.chapter=1 AND token.verse=1
          AND token.normalized_surface='parole'
      '''),
      isNotEmpty,
    );
    final frenchPlan = await strong.rawQuery('''
      EXPLAIN QUERY PLAN SELECT * FROM french_verse_tokens
      WHERE normalized_surface='dieu'
    ''');
    expect(
      frenchPlan.map((row) => '${row['detail']}').join(' '),
      contains('idx_french_token_surface'),
    );
    final versePlan = await strong.rawQuery('''
      EXPLAIN QUERY PLAN SELECT * FROM french_verse_tokens
      WHERE book_id=43 AND chapter=3 AND verse=16 ORDER BY token_index
    ''');
    expect(
      versePlan.map((row) => '${row['detail']}').join(' '),
      contains('idx_french_token_reference'),
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
    final queryPlan = await cross.rawQuery('''
      EXPLAIN QUERY PLAN
      SELECT * FROM cross_references
      WHERE source_book_id=43 AND source_chapter=3 AND source_verse=16
      ORDER BY score DESC LIMIT 20
    ''');
    expect(
      queryPlan.map((row) => '${row['detail']}').join(' '),
      contains('idx_cross_source'),
    );
    final crossColumns = await cross.rawQuery(
      'PRAGMA table_info(cross_references)',
    );
    expect(
      crossColumns.map((column) => column['name']),
      containsAll([
        'id',
        'source_book_id',
        'source_chapter',
        'source_verse',
        'target_book_id',
        'target_chapter',
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
    expect(
      Sqflite.firstIntValue(await naveFrench.rawQuery(
        "SELECT COUNT(*) FROM nave_translations WHERE entity_type='topic'",
      )),
      54,
    );
    expect(
      Sqflite.firstIntValue(await naveFrench.rawQuery(
        "SELECT COUNT(*) FROM nave_translations WHERE entity_type='section'",
      )),
      1018,
    );
    expect(
      Sqflite.firstIntValue(
        await naveFrench.rawQuery('SELECT COUNT(*) FROM nave_aliases'),
      ),
      29,
    );
    expect(
      await naveFrench.rawQuery('PRAGMA integrity_check'),
      [containsValue('ok')],
    );
    await naveFrench.close();
  });
}
