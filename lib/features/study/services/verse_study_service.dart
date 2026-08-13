import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';

class VerseStudyService {
  const VerseStudyService._();

  static Future<VerseStudyData> loadVerse(int verseId) async {
    final db = await DatabaseService.database;
    final verseRows = await db.query(
      'verses',
      columns: ['book_id', 'chapter_number', 'verse_number'],
      where: 'id = ?',
      whereArgs: [verseId],
      limit: 1,
    );
    final strongRepository = const StrongRepository();
    var tokens = const <StrongVerseToken>[];
    if (verseRows.isNotEmpty) {
      try {
        tokens = await strongRepository.forVerse(
          verseRows.first['book_id'] as int,
          verseRows.first['chapter_number'] as int,
          verseRows.first['verse_number'] as int,
        );
      } catch (_) {
        // Optional module not installed: the other study tools remain usable.
      }
    }
    final entries = await Future.wait(
      tokens.map(
        (token) => strongRepository.findByNumber(token.strongNumber),
      ),
    );
    final words = <VerseStrongWord>[];
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final entry = entries[index];
      words.add(
        VerseStrongWord(
          id: token.id,
          order: token.position,
          word: token.originalToken,
          code: token.strongNumber,
          lemma: token.lemma ?? entry?.originalWord,
          morphology: token.morphology ?? entry?.morphology,
          language: entry?.language,
          definition: entry?.definition,
          frenchDefinition: entry?.frenchDefinition,
          shortDefinition: entry?.shortDefinition,
          transliteration: entry?.transliteration,
          pronunciation: entry?.pronunciation,
          gloss: entry?.gloss,
          source: entry?.source,
          license: entry?.license,
          numberKind: entry?.numberKind ?? StrongNumberKind.classic,
        ),
      );
    }

    return VerseStudyData(
      strongWords: words,
      // Cross references are loaded only when their study tab is selected.
      crossReferences: const [],
    );
  }

  static Future<List<StrongOccurrence>> loadOccurrences(
    String strongCode, {
    int limit = 200,
  }) async {
    final db = await DatabaseService.database;
    final sourceOccurrences = await const StrongRepository().occurrences(
      strongCode,
      limit: limit,
    );
    if (sourceOccurrences.isEmpty) return const [];
    final clauses = List.filled(
      sourceOccurrences.length,
      '(v.book_id=? AND v.chapter_number=? AND v.verse_number=?)',
    ).join(' OR ');
    final arguments = <Object?>[
      for (final occurrence in sourceOccurrences) ...[
        occurrence.bookId,
        occurrence.chapter,
        occurrence.verse,
      ],
    ];
    final rows = await db.rawQuery('''
      SELECT v.book_id,b.name AS book_name,b.chapters_count,
        v.chapter_number,v.verse_number,v.text
      FROM verses v JOIN books b ON b.id=v.book_id
      WHERE $clauses
    ''', arguments);
    final verses = {
      for (final row in rows)
        '${row['book_id']}:${row['chapter_number']}:${row['verse_number']}':
            row,
    };

    return sourceOccurrences
        .map((occurrence) {
          final row = verses[
              '${occurrence.bookId}:${occurrence.chapter}:${occurrence.verse}'];
          if (row == null) return null;
          return StrongOccurrence(
            bookId: row['book_id'] as int,
            bookName: row['book_name'] as String,
            chaptersCount: row['chapters_count'] as int,
            chapterNumber: row['chapter_number'] as int,
            verseNumber: row['verse_number'] as int,
            verseText: row['text'] as String,
          );
        })
        .whereType<StrongOccurrence>()
        .toList();
  }
}
