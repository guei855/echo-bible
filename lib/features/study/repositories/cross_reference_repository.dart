import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/services/cross_reference_database_service.dart';

class CrossReferenceRepository {
  const CrossReferenceRepository();

  Future<List<CrossReference>> forVerse(
    int book,
    int chapter,
    int verse, {
    int limit = 100,
    int? versionId,
  }) async {
    final crossDb = await CrossReferenceDatabaseService.database;
    final links = await crossDb.query('cross_references',
        where: 'source_book_id=? AND source_chapter=? AND source_verse=?',
        whereArgs: [book, chapter, verse],
        orderBy: 'score DESC',
        limit: limit);
    if (links.isEmpty) return const [];
    final bibleDb = await DatabaseService.database;
    final selectedVersionId = versionId ?? await _selectedVersionId();
    final result = <CrossReference>[];
    for (final link in links) {
      final rows = await bibleDb.rawQuery('''
        SELECT v.book_id,b.name book_name,b.chapters_count,v.chapter_number,
          v.verse_number,COALESCE(vt.text,v.text) AS text
        FROM verses v
        JOIN books b ON b.id=v.book_id
        LEFT JOIN verse_translations vt
          ON vt.verse_id=v.id AND vt.version_id=?
        WHERE v.book_id=? AND v.chapter_number=?
          AND v.verse_number BETWEEN ? AND ?
        ORDER BY v.verse_number
      ''', [
        selectedVersionId,
        link['target_book_id'],
        link['target_chapter'],
        link['target_verse_start'],
        link['target_verse_end'],
      ]);
      if (rows.isEmpty) continue;
      final row = rows.first;
      result.add(CrossReference(
          bookId: row['book_id'] as int,
          bookName: row['book_name'] as String,
          chaptersCount: row['chapters_count'] as int,
          chapter: row['chapter_number'] as int,
          verseStart: link['target_verse_start'] as int,
          verseEnd: link['target_verse_end'] as int,
          text: rows.map((verse) => verse['text'] as String).join(' '),
          score: link['score'] as int?));
    }
    return result;
  }

  Future<int?> _selectedVersionId() async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    if (versions.isEmpty) return null;
    return BibleVersionRepository.getSelectedVersionId(versions);
  }

  Future<int> count() async {
    final db = await CrossReferenceDatabaseService.database;
    return (await db.rawQuery('SELECT COUNT(*) total FROM cross_references'))
        .first['total'] as int;
  }
}
