import 'package:echo_bible/features/study/models/commentary_entry.dart';
import 'package:echo_bible/features/study/services/commentary_database_service.dart';

class CommentaryRepository {
  const CommentaryRepository();

  Future<bool> isAvailable() async =>
      await CommentaryDatabaseService.database != null;

  Future<List<CommentaryEntry>> forVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    final database = await CommentaryDatabaseService.database;
    if (database == null) return const [];
    final rows = await database.rawQuery('''
      SELECT id,author,work_title,source,content,license
      FROM commentaries
      WHERE book_id=? AND chapter=?
        AND ? BETWEEN verse_start AND COALESCE(verse_end, verse_start)
      ORDER BY author,work_title,id
    ''', [bookId, chapter, verse]);
    return rows.map(CommentaryEntry.fromMap).toList();
  }
}
