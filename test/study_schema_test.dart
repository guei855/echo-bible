import 'package:echo_bible/core/database/study_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('crée le socle d’étude sans dupliquer les versets', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
      'CREATE TABLE cross_references(id INTEGER PRIMARY KEY, verse_id INTEGER)',
    );
    await db.execute('''
      CREATE TABLE strong_words(
        id INTEGER PRIMARY KEY,
        verse_id INTEGER,
        word_order INTEGER,
        strong TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY,
        verse_id INTEGER,
        note TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE strong_dictionary(
        strong TEXT PRIMARY KEY,
        lemma TEXT,
        language TEXT,
        definition TEXT,
        transliteration TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE reading_plans(
        id INTEGER PRIMARY KEY,
        title TEXT,
        duration INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE reading_plan_items(
        id INTEGER PRIMARY KEY,
        plan_id INTEGER,
        day INTEGER,
        book_id INTEGER,
        chapter INTEGER
      )
    ''');

    await StudySchema.ensure(db);

    final markingColumns =
        await db.rawQuery('PRAGMA table_info(text_markings)');
    expect(
      markingColumns.map((column) => column['name']),
      containsAll([
        'book_id',
        'chapter',
        'verse_number',
        'version_id',
        'start_offset',
        'end_offset',
        'selected_text',
        'marking_type',
        'color',
        'created_at',
      ]),
    );
    await StudySchema.ensure(db);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll([
        'study_tabs',
        'personal_studies',
        'study_sections',
        'tags',
        'verse_tags',
        'verse_links',
      ]),
    );
    expect(names, isNot(contains('study_verses')));

    final noteColumns = await db.rawQuery('PRAGMA table_info(notes)');
    final noteColumnNames = noteColumns.map((column) => column['name']).toSet();
    expect(noteColumnNames, containsAll(['title', 'updated_at']));

    expect(names, isNot(contains('strong_words')));
    expect(names, isNot(contains('strong_dictionary')));

    final planColumns = await db.rawQuery('PRAGMA table_info(reading_plans)');
    final planColumnNames = planColumns.map((column) => column['name']).toSet();
    expect(
      planColumnNames,
      containsAll([
        'description',
        'start_date',
        'is_personal',
        'is_active',
        'created_at',
      ]),
    );
  });
}
