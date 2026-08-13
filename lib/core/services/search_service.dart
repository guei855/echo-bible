import 'package:echo_bible/core/services/database_service.dart';

class SearchResultItem {
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapterNumber;
  final int verseNumber;
  final String text;

  SearchResultItem({
    required this.bookId,
    required this.bookName,
    required this.chaptersCount,
    required this.chapterNumber,
    required this.verseNumber,
    required this.text,
  });
}

class SearchService {
  static const _wordCharacters = 'A-Za-zÀ-ÖØ-öø-ÿŒœÆæ0-9';

  /// Recherche une occurrence exacte (mot ou expression), sans confondre par
  /// exemple « amour » et « amours ».
  static Future<List<SearchResultItem>> searchExactVerses(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final db = await DatabaseService.database;
    final escapedQuery = normalizedQuery
        .toLowerCase()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final candidates = await db.rawQuery('''
      SELECT
        v.book_id,
        b.name AS book_name,
        b.chapters_count,
        v.chapter_number,
        v.verse_number,
        v.text
      FROM verses v
      JOIN books b ON v.book_id = b.id
      WHERE LOWER(v.text) LIKE ? ESCAPE '\\'
      ORDER BY v.book_id ASC, v.chapter_number ASC, v.verse_number ASC
    ''', ['%$escapedQuery%']);

    return candidates
        .where(
          (row) => containsExactExpression(
            row['text'] as String,
            normalizedQuery,
          ),
        )
        .take(200)
        .map(_fromRow)
        .toList();
  }

  static bool containsExactExpression(String text, String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return false;

    final expression = RegExp(
      '(^|[^$_wordCharacters])${RegExp.escape(normalizedQuery)}(?=\$|[^$_wordCharacters])',
      caseSensitive: false,
    );
    return expression.hasMatch(text);
  }

  static Future<List<SearchResultItem>> searchVerses(String query) async {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return [];

    final db = await DatabaseService.database;
    final conditions =
        List.filled(terms.length, 'LOWER(v.text) LIKE ?').join(' AND ');
    final arguments = terms.map((term) => '%${term.toLowerCase()}%').toList();

    final results = await db.rawQuery('''
      SELECT
        v.book_id,
        b.name AS book_name,
        b.chapters_count,
        v.chapter_number,
        v.verse_number,
        v.text
      FROM verses v
      JOIN books b ON v.book_id = b.id
      WHERE $conditions
      ORDER BY v.book_id ASC, v.chapter_number ASC, v.verse_number ASC
      LIMIT 200
    ''', arguments);

    return results.map(_fromRow).toList();
  }

  static SearchResultItem _fromRow(Map<String, Object?> row) =>
      SearchResultItem(
        bookId: row['book_id'] as int,
        bookName: row['book_name'] as String,
        chaptersCount: row['chapters_count'] as int,
        chapterNumber: row['chapter_number'] as int,
        verseNumber: row['verse_number'] as int,
        text: row['text'] as String,
      );
}
