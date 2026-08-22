import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/bible/bible_book_display_names.dart';
import 'package:echo_bible/features/study/models/study_tool_item.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:sqflite/sqflite.dart';

class StudyToolsService {
  const StudyToolsService._();

  static Future<StudyToolsSummary> loadSummary() async {
    final db = await DatabaseService.database;
    Future<int> count(String sql) async {
      return Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    }

    final values = await Future.wait<int>([
      count('SELECT COUNT(DISTINCT verse_id) FROM notes'),
      count('SELECT COUNT(DISTINCT verse_id) FROM highlights'),
      count('SELECT COUNT(DISTINCT verse_id) FROM favorites'),
      count('SELECT COUNT(*) FROM tags'),
      count('SELECT COUNT(*) FROM verse_links'),
      PersonalStudyService.countStudies(),
      count('SELECT COUNT(*) FROM reading_history'),
    ]);
    return StudyToolsSummary(
      notes: values[0],
      highlights: values[1],
      bookmarks: values[2],
      tags: values[3],
      links: values[4],
      studies: values[5],
      history: values[6],
    );
  }

  static Future<List<StudyToolItem>> loadItems(StudyToolType type) async {
    final db = await DatabaseService.database;
    final rows = switch (type) {
      StudyToolType.notes => await db.rawQuery('''
          SELECT v.id AS verse_id, v.book_id, b.name AS book_name,
            b.chapters_count, v.chapter_number, v.verse_number, v.text,
            n.title, n.note AS detail, n.updated_at AS item_date
          FROM notes n
          JOIN verses v ON v.id = n.verse_id
          JOIN books b ON b.id = v.book_id
          ORDER BY COALESCE(n.updated_at, n.created_at) DESC, n.id DESC
          LIMIT 200
        '''),
      StudyToolType.highlights => await db.rawQuery('''
          SELECT v.id AS verse_id, v.book_id, b.name AS book_name,
            b.chapters_count, v.chapter_number, v.verse_number, v.text,
            h.color
          FROM highlights h
          JOIN verses v ON v.id = h.verse_id
          JOIN books b ON b.id = v.book_id
          ORDER BY h.id DESC
          LIMIT 200
        '''),
      StudyToolType.bookmarks => await db.rawQuery('''
          SELECT v.id AS verse_id, v.book_id, b.name AS book_name,
            b.chapters_count, v.chapter_number, v.verse_number, v.text,
            f.created_at AS item_date
          FROM favorites f
          JOIN verses v ON v.id = f.verse_id
          JOIN books b ON b.id = v.book_id
          ORDER BY f.created_at DESC, f.id DESC
          LIMIT 200
        '''),
      StudyToolType.history => await db.rawQuery('''
          SELECT v.id AS verse_id, v.book_id, b.name AS book_name,
            b.chapters_count, v.chapter_number, v.verse_number, v.text,
            rh.id AS source_id, rh.read_at AS item_date,
            rh.version_id
          FROM reading_history rh
          JOIN books b ON b.id = rh.book_id
          JOIN verses v ON v.book_id = rh.book_id
            AND v.chapter_number = rh.chapter AND v.verse_number = rh.verse
          ORDER BY rh.read_at DESC, rh.id DESC
          LIMIT 100
        '''),
    };

    return rows
        .map(
          (row) => StudyToolItem(
            sourceId: row['source_id'] as int?,
            verseId: row['verse_id'] as int,
            bookId: row['book_id'] as int,
            bookName: BibleBookDisplayNames.french(
              row['book_id'] as int,
              fallback: row['book_name'] as String?,
            ),
            chaptersCount: row['chapters_count'] as int,
            chapterNumber: row['chapter_number'] as int,
            verseNumber: row['verse_number'] as int,
            verseText: row['text'] as String,
            title: row['title'] as String?,
            detail: row['detail'] as String?,
            color: row['color'] as String?,
            date: row['item_date'] as String?,
            versionId: row['version_id'] as int? ?? 1,
          ),
        )
        .toList();
  }

  static Future<void> deleteHistory(Iterable<int> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return;
    final db = await DatabaseService.database;
    await db.delete(
      'reading_history',
      where: 'id IN (${List.filled(values.length, '?').join(', ')})',
      whereArgs: values,
    );
  }

  static Future<void> clearHistory() async {
    final db = await DatabaseService.database;
    await db.delete('reading_history');
  }

  static Future<void> restoreHistory(Iterable<StudyToolItem> items) async {
    final db = await DatabaseService.database;
    await db.transaction((transaction) async {
      for (final item in items) {
        await transaction.insert('reading_history', {
          if (item.sourceId != null) 'id': item.sourceId,
          'book_id': item.bookId,
          'chapter': item.chapterNumber,
          'verse': item.verseNumber,
          'version_id': item.versionId,
          'read_at': item.date ?? DateTime.now().toIso8601String(),
        });
      }
    });
  }
}
