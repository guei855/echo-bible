import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/services/cross_reference_database_service.dart';

class CrossReferenceRepository {
  static const lsgVersionId = 1;

  const CrossReferenceRepository();

  Future<List<CrossReference>> forVerse(
    int book,
    int chapter,
    int verse, {
    int limit = 20,
    int? versionId,
  }) async {
    final links =
        await CrossReferenceDatabaseService.use((database) => database.query(
              'cross_references',
              where: 'source_book_id=? AND source_chapter=? AND source_verse=?',
              whereArgs: [book, chapter, verse],
              orderBy: 'score DESC,id ASC',
              limit: limit,
            ));
    if (links.isEmpty) return const [];

    final selectedVersionId = versionId ?? await _selectedVersionId();
    final ranges = links.map((link) {
      final start = link['target_verse_start']! as int;
      return (
        link['target_book_id']! as int,
        link['target_chapter']! as int,
        start,
        link['target_verse_end'] as int? ?? start,
      );
    }).toList(growable: false);
    final selectedRows = await BibleVersionRepository.getVersesForRanges(
      versionId: selectedVersionId,
      ranges: ranges,
    );
    final fallbackRows = selectedVersionId == lsgVersionId
        ? selectedRows
        : await BibleVersionRepository.getVersesForRanges(
            versionId: lsgVersionId,
            ranges: ranges,
          );
    final selectedVerses = _verseMap(selectedRows);
    final fallbackVerses = _verseMap(fallbackRows);

    final bibleDb = await DatabaseService.database;
    final bookIds = links
        .map((link) => link['target_book_id']! as int)
        .toSet()
        .toList(growable: false);
    final placeholders = List.filled(bookIds.length, '?').join(',');
    final bookRows = await bibleDb.rawQuery(
      'SELECT id,name,chapters_count FROM books WHERE id IN ($placeholders)',
      bookIds,
    );
    final books = {for (final row in bookRows) row['id']! as int: row};

    final result = <CrossReference>[];
    for (final link in links) {
      final bookId = link['target_book_id']! as int;
      final targetChapter = link['target_chapter']! as int;
      final verseStart = link['target_verse_start']! as int;
      final verseEnd = link['target_verse_end'] as int? ?? verseStart;
      final texts = <String>[];
      var usedFallback = false;
      for (var number = verseStart; number <= verseEnd; number++) {
        final key = '$bookId:$targetChapter:$number';
        final selectedText = selectedVerses[key];
        final fallbackText = fallbackVerses[key];
        if (selectedText != null) {
          texts.add(selectedText);
        } else if (fallbackText != null) {
          texts.add(fallbackText);
          usedFallback = selectedVersionId != lsgVersionId;
        }
      }
      if (texts.isEmpty || books[bookId] == null) continue;
      final bookRow = books[bookId]!;
      result.add(CrossReference(
        bookId: bookId,
        bookName: bookRow['name']! as String,
        chaptersCount: bookRow['chapters_count']! as int,
        chapter: targetChapter,
        verseStart: verseStart,
        verseEnd: verseEnd,
        text: texts.join(' '),
        score: link['score'] as int?,
        sourceDataset: link['source_dataset']! as String,
        requestedVersionId: selectedVersionId,
        usedLsgFallback: usedFallback,
      ));
    }
    return result;
  }

  Future<int> countForVerse(int book, int chapter, int verse) =>
      CrossReferenceDatabaseService.use(
          (database) async => (await database.rawQuery('''
            SELECT COUNT(*) total FROM cross_references
            WHERE source_book_id=? AND source_chapter=? AND source_verse=?
          ''', [book, chapter, verse])).first['total']! as int);

  Future<List<Map<String, Object?>>> findReferencesToVerse(
    int book,
    int chapter,
    int verse, {
    int limit = 20,
  }) =>
      CrossReferenceDatabaseService.use((database) => database.query(
            'cross_references',
            where: '''target_book_id=? AND target_chapter=?
              AND ? BETWEEN target_verse_start AND target_verse_end''',
            whereArgs: [book, chapter, verse],
            orderBy: 'score DESC,id ASC',
            limit: limit,
          ));

  Future<int> count() => CrossReferenceDatabaseService.use((database) async =>
      (await database.rawQuery('SELECT COUNT(*) total FROM cross_references'))
          .first['total']! as int);

  Future<int> _selectedVersionId() async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    if (versions.isEmpty) return lsgVersionId;
    return BibleVersionRepository.getSelectedVersionId(versions);
  }

  Map<String, String> _verseMap(List<Map<String, Object?>> rows) => {
        for (final row in rows)
          '${row['book_id']}:${row['chapter_number']}:${row['verse_number']}':
              row['text']! as String,
      };
}
