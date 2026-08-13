import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/services/strong_database_service.dart';

class StrongRepository {
  const StrongRepository();

  Future<StrongEntry?> findByNumber(String value) async {
    final canonical = _canonical(value.trim());
    if (canonical.isEmpty) return null;
    final db = await StrongDatabaseService.database;
    var rows = await db.rawQuery('''
      SELECT * FROM strong_entries
      WHERE UPPER(strong_number)=?
        OR UPPER(extended_strong_number)=?
        OR UPPER(disambiguated_strong_number)=?
        OR UPPER(unified_strong_number)=?
      ORDER BY CASE
        WHEN UPPER(strong_number)=? THEN 0
        WHEN UPPER(extended_strong_number)=? THEN 1
        WHEN UPPER(disambiguated_strong_number)=? THEN 2
        ELSE 3 END,
        id
      LIMIT 1
    ''', List.filled(7, canonical.toUpperCase()));
    if (rows.isEmpty && _allowsLexicalVariantFallback(canonical)) {
      rows = await db.rawQuery('''
        SELECT * FROM strong_entries
        WHERE UPPER(strong_number) LIKE ?
        ORDER BY LENGTH(strong_number),strong_number
        LIMIT 1
      ''', ['${canonical.toUpperCase()}%']);
    }
    return rows.isEmpty ? null : StrongEntry.fromMap(rows.first);
  }

  Future<List<StrongEntry>> search(String value, {int limit = 200}) async {
    final query = value.trim();
    if (query.isEmpty) return const [];
    final canonical = _canonical(query);
    final db = await StrongDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT * FROM strong_entries
      WHERE UPPER(strong_number) LIKE ? OR LOWER(original_word) LIKE ?
        OR LOWER(transliteration) LIKE ? OR LOWER(gloss) LIKE ?
          OR LOWER(short_definition) LIKE ? OR LOWER(definition_source) LIKE ?
        OR LOWER(definition_fr) LIKE ?
      ORDER BY CASE WHEN UPPER(strong_number) = ? THEN 0 ELSE 1 END,
        strong_number LIMIT ?
    ''', [
      '${canonical.toUpperCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      canonical.toUpperCase(),
      limit
    ]);
    return rows.map(StrongEntry.fromMap).toList();
  }

  Future<int> count() async {
    final db = await StrongDatabaseService.database;
    return (await db.rawQuery('SELECT COUNT(*) total FROM strong_entries'))
        .first['total'] as int;
  }

  Future<List<StrongVerseToken>> forVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    final db = await StrongDatabaseService.database;
    final rows = await db.query(
      'strong_occurrences',
      where: 'book_id=? AND chapter=? AND verse=?',
      whereArgs: [bookId, chapter, verse],
      orderBy: 'token_position,id',
    );
    return rows.map(StrongVerseToken.fromMap).toList();
  }

  Future<List<StrongVerseToken>> occurrences(
    String value, {
    int limit = 200,
  }) async {
    final canonical = _canonical(value.trim());
    if (canonical.isEmpty) return const [];
    final db = await StrongDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT MIN(id) id,strong_number,book_id,chapter,verse,
        MIN(token_original) token_original,MIN(lemma) lemma,
        MIN(morphology) morphology,MIN(token_position) token_position
      FROM strong_occurrences
      WHERE UPPER(strong_number)=?
      GROUP BY strong_number,book_id,chapter,verse
      ORDER BY book_id,chapter,verse
      LIMIT ?
    ''', [canonical.toUpperCase(), limit]);
    return rows.map(StrongVerseToken.fromMap).toList();
  }

  String _canonical(String value) {
    final match =
        RegExp(r'^([HG])0*(\d+)(.*)$', caseSensitive: false).firstMatch(value);
    return match == null
        ? value
        : '${match.group(1)!.toUpperCase()}${match.group(2)}${match.group(3)}';
  }

  bool _allowsLexicalVariantFallback(String value) {
    final match =
        RegExp(r'^[HG](\d+)$', caseSensitive: false).firstMatch(value);
    final number = int.tryParse(match?.group(1) ?? '');
    return number != null && number < 9000;
  }
}
