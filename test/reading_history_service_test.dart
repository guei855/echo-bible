import 'package:echo_bible/core/database/study_schema.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<Database> openHistoryDatabase() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE reading_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        chapter INTEGER,
        verse INTEGER,
        read_at TEXT
      )
    ''');
    await db.execute(
      'CREATE TABLE cross_references(id INTEGER PRIMARY KEY, verse_id INTEGER)',
    );
    await StudySchema.ensure(db);
    return db;
  }

  test('la migration déduplique prudemment les références exactes', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE reading_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        chapter INTEGER,
        verse INTEGER,
        read_at TEXT
      )
    ''');
    await db.execute(
      'CREATE TABLE cross_references(id INTEGER PRIMARY KEY, verse_id INTEGER)',
    );
    await db.insert('reading_history', {
      'book_id': 1,
      'chapter': 1,
      'verse': 1,
      'read_at': '2026-01-01T00:00:00',
    });
    await db.insert('reading_history', {
      'book_id': 1,
      'chapter': 1,
      'verse': 1,
      'read_at': '2026-01-02T00:00:00',
    });
    await db.insert('reading_history', {
      'book_id': 1,
      'chapter': 1,
      'verse': 2,
      'read_at': '2026-01-03T00:00:00',
    });

    await StudySchema.ensure(db);
    final rows = await db.query('reading_history', orderBy: 'id');
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['verse']), [1, 2]);
    expect(rows.every((row) => row['version_id'] == 1), isTrue);
  });

  test('une visite identique remonte en tête sans doublon', () async {
    final db = await openHistoryDatabase();
    addTearDown(db.close);

    await DatabaseService.saveReadingHistoryTo(
      db,
      1,
      1,
      1,
      readAt: DateTime(2026, 1, 1),
    );
    await DatabaseService.saveReadingHistoryTo(
      db,
      40,
      14,
      1,
      readAt: DateTime(2026, 1, 2),
    );
    await DatabaseService.saveReadingHistoryTo(
      db,
      1,
      1,
      1,
      readAt: DateTime(2026, 1, 3),
    );

    final rows = await db.query(
      'reading_history',
      orderBy: 'read_at DESC, id DESC',
    );
    expect(rows, hasLength(2));
    expect(rows.first['book_id'], 1);
    expect(rows.first['read_at'], '2026-01-03T00:00:00.000');
  });

  test('deux versions du même verset restent distinctes', () async {
    final db = await openHistoryDatabase();
    addTearDown(db.close);
    await DatabaseService.saveReadingHistoryTo(db, 1, 1, 1, versionId: 1);
    await DatabaseService.saveReadingHistoryTo(db, 1, 1, 1, versionId: 2);
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reading_history'),
    );
    expect(count, 2);
  });
}
