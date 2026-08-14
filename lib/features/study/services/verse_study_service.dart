import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';

class VerseStudyService {
  const VerseStudyService._();

  static Future<VerseStudyData> loadVerse(
    int verseId, {
    String? selectedText,
  }) async {
    final db = await DatabaseService.database;
    final verseRows = await db.query(
      'verses',
      columns: ['book_id', 'chapter_number', 'verse_number'],
      where: 'id = ?',
      whereArgs: [verseId],
      limit: 1,
    );
    final strongRepository = const StrongRepository();
    var tokens = const <FrenchStrongToken>[];
    var originalTokens = const <StrongVerseToken>[];
    if (verseRows.isNotEmpty) {
      try {
        final bookId = verseRows.first['book_id'] as int;
        final chapter = verseRows.first['chapter_number'] as int;
        final verse = verseRows.first['verse_number'] as int;
        tokens = await strongRepository.frenchForVerse(
          bookId,
          chapter,
          verse,
          selectedText: selectedText,
        );
        originalTokens = await strongRepository.forVerse(
          bookId,
          chapter,
          verse,
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
    final originalByCode = <String, List<StrongVerseToken>>{};
    for (final original in originalTokens) {
      originalByCode.putIfAbsent(original.strongNumber, () => []).add(original);
    }
    final consumedByCode = <String, int>{};
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final entry = entries[index];
      final candidates = originalByCode[token.strongNumber] ?? const [];
      final consumed = consumedByCode[token.strongNumber] ?? 0;
      final original = candidates.isEmpty
          ? null
          : candidates[consumed.clamp(0, candidates.length - 1)];
      consumedByCode[token.strongNumber] = consumed + 1;
      words.add(
        VerseStrongWord(
          id: token.tokenId,
          order: token.position,
          word: token.displaySurface,
          code: token.strongNumber,
          originalWord: original?.originalToken ?? entry?.originalWord,
          lemma: original?.lemma ?? entry?.originalWord,
          morphology: original?.morphology ?? entry?.morphology,
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
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await DatabaseService.database;
    final sourceOccurrences = await const StrongRepository().occurrences(
      strongCode,
      limit: limit,
      offset: offset,
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
            originalForm: occurrence.originalToken,
            morphology: occurrence.morphology,
            morphologyDescription: occurrence.morphologyDescription,
          );
        })
        .whereType<StrongOccurrence>()
        .toList();
  }
}
