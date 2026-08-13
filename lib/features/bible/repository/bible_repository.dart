import 'package:sqflite/sqflite.dart';
import 'package:echo_bible/features/bible/data/database/database_helper.dart';

class BibleRepository {
  static final BibleRepository instance = BibleRepository._internal();
  BibleRepository._internal();

  Future<List<Map<String, dynamic>>> getVerses(int bookId, int chapter) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'verses',
      where: 'book_id = ? AND chapter_number = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'verse_number ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getHighlights(
      int bookId, int chapter) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'highlights',
      where: 'book_id = ? AND chapter_number = ?',
      whereArgs: [bookId, chapter],
    );
  }

  Future<void> saveHighlight(
      int bookId, int chapter, int verse, String color) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'highlights',
      {
        'book_id': bookId,
        'chapter_number': chapter,
        'verse_number': verse,
        'color': color
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isFavorite(int bookId, int chapter, int verse) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'favorites',
      where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
      whereArgs: [bookId, chapter, verse],
    );
    return result.isNotEmpty;
  }

  Future<void> toggleFavorite(
      int bookId, int chapter, int verse, String text) async {
    final db = await DatabaseHelper.instance.database;
    if (await isFavorite(bookId, chapter, verse)) {
      await db.delete('favorites',
          where: 'book_id = ? AND chapter_number = ? AND verse_number = ?',
          whereArgs: [bookId, chapter, verse]);
    } else {
      await db.insert('favorites', {
        'book_id': bookId,
        'chapter_number': chapter,
        'verse_number': verse,
        'text': text
      });
    }
  }
}
