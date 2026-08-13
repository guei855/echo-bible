import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/services/dictionary_database_service.dart';

class DictionaryRepository {
  final DictionaryDatabaseService databaseService;

  const DictionaryRepository({
    this.databaseService = const DictionaryDatabaseService(),
  });

  Future<bool> isAvailable() async {
    final database = await databaseService.open();
    if (database == null) return false;
    try {
      final result = await database.rawQuery('PRAGMA integrity_check');
      return result.isNotEmpty && result.first.values.first == 'ok';
    } catch (_) {
      return false;
    } finally {
      await database.close();
    }
  }

  Future<List<DictionaryEntry>> search(
    String value, {
    int limit = 100,
  }) async {
    final query = normalizeSearchTerm(value);
    if (query.isEmpty) return listAlphabetically(limit: limit);
    final database = await databaseService.open();
    if (database == null) return const [];
    final like = '%${_escapeLike(query)}%';
    final prefix = '${_escapeLike(query)}%';
    final ftsQuery = query
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '"${part.replaceAll('"', '""')}"*')
        .join(' AND ');
    try {
      final rows = await database.rawQuery('''
        SELECT e.*,
          CASE
            WHEN e.normalized_headword = ? THEN 0
            WHEN EXISTS (
              SELECT 1 FROM dictionary_aliases a
              WHERE a.entry_id = e.id AND a.normalized_alias = ?
            ) THEN 1
            WHEN e.normalized_headword LIKE ? ESCAPE '\\' THEN 2
            WHEN e.normalized_headword LIKE ? ESCAPE '\\' THEN 3
            ELSE 4
          END AS search_rank
        FROM dictionary_entries e
        WHERE e.normalized_headword LIKE ? ESCAPE '\\'
          OR EXISTS (
            SELECT 1 FROM dictionary_aliases a
            WHERE a.entry_id = e.id AND a.normalized_alias LIKE ? ESCAPE '\\'
          )
          OR e.id IN (
            SELECT rowid FROM dictionary_fts WHERE dictionary_fts MATCH ?
          )
        ORDER BY search_rank, e.normalized_headword
        LIMIT ?
      ''', [query, query, prefix, like, like, like, ftsQuery, limit]);
      return rows.map(DictionaryEntry.fromMap).toList();
    } finally {
      await database.close();
    }
  }

  Future<List<DictionaryEntry>> listAlphabetically({
    String? letter,
    int limit = 100,
  }) async {
    final database = await databaseService.open();
    if (database == null) return const [];
    try {
      final normalizedLetter = normalizeSearchTerm(letter ?? '');
      final rows = await database.query(
        'dictionary_entries',
        where: normalizedLetter.isEmpty ? null : 'normalized_headword LIKE ?',
        whereArgs: normalizedLetter.isEmpty ? null : ['$normalizedLetter%'],
        orderBy: 'normalized_headword',
        limit: limit,
      );
      return rows.map(DictionaryEntry.fromMap).toList();
    } finally {
      await database.close();
    }
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static String normalizeSearchTerm(String value) {
    var normalized = value.toLowerCase();
    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
    };
    for (final replacement in replacements.entries) {
      normalized = normalized.replaceAll(replacement.key, replacement.value);
    }
    return normalized
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .join(' ');
  }
}
