import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/models/text_marking.dart';
import 'package:sqflite/sqflite.dart';

class TextMarkingService {
  const TextMarkingService();

  Future<List<TextMarking>> forChapter({
    required int bookId,
    required int chapter,
    required int versionId,
  }) async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'text_markings',
      where: 'book_id = ? AND chapter = ? AND version_id = ?',
      whereArgs: [bookId, chapter, versionId],
      orderBy: 'verse_number, start_offset, id',
    );
    return rows.map(TextMarking.fromMap).toList();
  }

  Future<int> save(TextMarking marking) async {
    final db = await DatabaseService.database;
    return db.insert(
      'text_markings',
      marking.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAll(Iterable<TextMarking> markings) async {
    final db = await DatabaseService.database;
    await db.transaction((transaction) async {
      for (final marking in markings) {
        await transaction.insert(
          'text_markings',
          marking.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> remove({
    required int bookId,
    required int chapter,
    required int versionId,
    required Iterable<int> verses,
    required TextMarkingType type,
  }) async {
    final verseNumbers = verses.toList();
    if (verseNumbers.isEmpty) return;
    final db = await DatabaseService.database;
    await db.delete(
      'text_markings',
      where: 'book_id = ? AND chapter = ? AND version_id = ? '
          'AND marking_type = ? AND verse_number IN '
          '(${List.filled(verseNumbers.length, '?').join(', ')})',
      whereArgs: [bookId, chapter, versionId, type.name, ...verseNumbers],
    );
  }
}
