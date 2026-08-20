import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
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
    int? versionId,
  }) async {
    final sourceOccurrences = await const StrongRepository().occurrences(
      strongCode,
      limit: limit,
      offset: offset,
    );
    if (sourceOccurrences.isEmpty) return const [];
    final selectedVersionId =
        versionId ?? (await BibleVersionRepository.getActiveVersion()).id;
    final ranges = sourceOccurrences.map(
      (occurrence) => (
        occurrence.bookId,
        occurrence.chapter,
        occurrence.verse,
        occurrence.verse,
      ),
    );
    final rows = await BibleVersionRepository.getVersesForRanges(
      versionId: selectedVersionId,
      ranges: ranges,
    );
    final verses = {
      for (final row in rows)
        '${row['book_id']}:${row['chapter_number']}:${row['verse_number']}':
            row,
    };
    if (verses.length < sourceOccurrences.length) {
      final versions = await BibleVersionRepository.getInstalledVersions();
      final fallback = versions.where((item) => item.isDefault).isEmpty
          ? null
          : versions.firstWhere((item) => item.isDefault);
      if (fallback != null && fallback.id != selectedVersionId) {
        final fallbackRows = await BibleVersionRepository.getVersesForRanges(
          versionId: fallback.id,
          ranges: ranges,
        );
        for (final row in fallbackRows) {
          verses.putIfAbsent(
            '${row['book_id']}:${row['chapter_number']}:${row['verse_number']}',
            () => row,
          );
        }
      }
    }
    final books = {
      for (final book in await BibleVersionRepository.getBooks(
        versionId: selectedVersionId,
      ))
        book.id: book,
    };

    return sourceOccurrences
        .map((occurrence) {
          final row = verses[
              '${occurrence.bookId}:${occurrence.chapter}:${occurrence.verse}'];
          if (row == null) return null;
          final book = books[occurrence.bookId];
          return StrongOccurrence(
            bookId: row['book_id'] as int,
            bookName: book?.name ?? 'Livre ${occurrence.bookId}',
            chaptersCount: book?.chaptersCount ?? occurrence.chapter,
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
