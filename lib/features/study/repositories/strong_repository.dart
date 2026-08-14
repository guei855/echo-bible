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
    final french = _normalizeFrench(query);
    final transliterationPattern = _transliterationPattern(query);
    final db = await StrongDatabaseService.database;
    final digitsOnly = RegExp(r'^0*\d+$').hasMatch(query);
    if (digitsOnly) {
      final number = int.parse(query);
      final rows = await db.rawQuery('''
        SELECT * FROM strong_entries
        WHERE UPPER(strong_number) IN (?,?)
        ORDER BY language,strong_number,id LIMIT ?
      ''', ['H$number', 'G$number', limit]);
      return rows.map(StrongEntry.fromMap).toList();
    }
    final frenchCodes =
        french.isEmpty ? const <Map<String, Object?>>[] : await db.rawQuery('''
            SELECT DISTINCT link.strong_number
            FROM french_verse_tokens token
            JOIN french_token_strongs link ON link.token_id=token.id
            WHERE token.normalized_surface=?
            ORDER BY link.strong_number LIMIT ?
          ''', [french, limit]);
    final frenchEntries = <StrongEntry>[];
    if (frenchCodes.isNotEmpty) {
      final codes = frenchCodes.map((row) => row['strong_number']).toList();
      final placeholders = List.filled(codes.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT * FROM strong_entries
        WHERE strong_number IN ($placeholders)
        ORDER BY strong_number,id LIMIT ?
      ''', [...codes, limit]);
      frenchEntries.addAll(rows.map(StrongEntry.fromMap));
    }
    final hebrewEntries = <StrongEntry>[];
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(query)) {
      final unpointedQuery = _withoutHebrewMarks(query);
      final rows = await db.query(
        'strong_entries',
        where: "UPPER(strong_number) LIKE 'H%'",
        orderBy: 'strong_number,id',
      );
      for (final row in rows) {
        final entry = StrongEntry.fromMap(row);
        if (_withoutHebrewMarks(entry.originalWord).contains(unpointedQuery)) {
          hebrewEntries.add(entry);
          if (hebrewEntries.length == limit) break;
        }
      }
    }
    final greekEntries = <StrongEntry>[];
    if (RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').hasMatch(query)) {
      final normalizedQuery = _withoutGreekMarks(query);
      final rows = await db.query(
        'strong_entries',
        where: "UPPER(strong_number) LIKE 'G%'",
        orderBy: 'strong_number,id',
      );
      for (final row in rows) {
        final entry = StrongEntry.fromMap(row);
        if (_withoutGreekMarks(entry.originalWord).contains(normalizedQuery)) {
          greekEntries.add(entry);
          if (greekEntries.length == limit) break;
        }
      }
    }
    final lexicalRows = await db.rawQuery('''
      SELECT * FROM strong_entries
      WHERE UPPER(strong_number) LIKE ? OR LOWER(original_word) LIKE ?
        OR LOWER(transliteration) LIKE ?
        OR LOWER(transliteration) LIKE ? OR LOWER(gloss) LIKE ?
        OR LOWER(short_definition) LIKE ? OR LOWER(definition_source) LIKE ?
        OR LOWER(definition_fr) LIKE ?
      ORDER BY CASE WHEN UPPER(strong_number)=? THEN 0 ELSE 1 END,
        strong_number,id LIMIT ?
    ''', [
      '${canonical.toUpperCase()}%',
      '%${query.toLowerCase()}%',
      transliterationPattern,
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      '%${query.toLowerCase()}%',
      canonical.toUpperCase(),
      limit
    ]);
    final results = <StrongEntry>[];
    final seen = <int>{};
    for (final entry in [
      ...frenchEntries,
      ...hebrewEntries,
      ...greekEntries,
      ...lexicalRows.map(StrongEntry.fromMap),
    ]) {
      if (seen.add(entry.id)) results.add(entry);
      if (results.length == limit) break;
    }
    return results;
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

  Future<List<FrenchStrongToken>> frenchForVerse(
    int bookId,
    int chapter,
    int verse, {
    String? selectedText,
  }) async {
    final db = await StrongDatabaseService.database;
    final selected = _normalizeFrench(selectedText ?? '');
    final rows = await db.rawQuery('''
      SELECT token.id token_id,token.book_id,token.chapter,token.verse,
        token.token_index,token.surface,token.normalized_surface,
        token.is_translated,token.source_dataset,
        link.strong_number,link.strong_order
      FROM french_verse_tokens token
      JOIN french_token_strongs link ON link.token_id=token.id
      WHERE token.book_id=? AND token.chapter=? AND token.verse=?
        AND (?='' OR token.normalized_surface=?
          OR (token.normalized_surface<>''
            AND instr(?,token.normalized_surface)>0))
      ORDER BY token.token_index,link.strong_order
    ''', [bookId, chapter, verse, selected, selected, selected]);
    return rows.map(FrenchStrongToken.fromMap).toList();
  }

  Future<List<StrongVerseToken>> occurrences(
    String value, {
    int limit = 200,
    int offset = 0,
  }) async {
    final canonical = _canonical(value.trim());
    if (canonical.isEmpty) return const [];
    final db = await StrongDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT MIN(id) id,strong_number,book_id,chapter,verse,
        MIN(token_original) token_original,MIN(lemma) lemma,
        MIN(morphology) morphology,MIN(token_position) token_position,
        MIN((SELECT COALESCE(NULLIF(code.description_fr,''),
          code.description_source)
          FROM morphology_codes code
          WHERE code.code=occurrence.morphology
            OR code.code='G:' || CASE
              WHEN instr(occurrence.morphology,'-')>0
                THEN substr(occurrence.morphology,1,
                  instr(occurrence.morphology,'-')-1)
              ELSE occurrence.morphology END
          ORDER BY CASE WHEN NULLIF(code.description_fr,'') IS NULL
            THEN 1 ELSE 0 END,code.id LIMIT 1)) morphology_description
      FROM strong_occurrences occurrence
      WHERE UPPER(strong_number)=?
      GROUP BY strong_number,book_id,chapter,verse
      ORDER BY book_id,chapter,verse
      LIMIT ? OFFSET ?
    ''', [canonical.toUpperCase(), limit, offset]);
    return rows.map(StrongVerseToken.fromMap).toList();
  }

  Future<String?> morphologyDescription(String value) async {
    final code = value.trim();
    if (code.isEmpty) return null;
    final db = await StrongDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(description_fr,''),description_source)
        description
      FROM morphology_codes
      WHERE UPPER(code)=UPPER(?)
        OR UPPER(code)=UPPER('G:' || CASE WHEN instr(?,'-')>0
          THEN substr(?,1,instr(?,'-')-1) ELSE ? END)
      ORDER BY CASE WHEN UPPER(code)=UPPER(?) THEN 0 ELSE 1 END,
        CASE WHEN NULLIF(description_fr,'') IS NULL THEN 1 ELSE 0 END,id
      LIMIT 1
    ''', [code, code, code, code, code, code]);
    return rows.isEmpty ? null : rows.first['description'] as String?;
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

  String _normalizeFrench(String value) {
    const accented = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyyoea';
    var result = value.toLowerCase();
    for (var index = 0; index < accented.length; index++) {
      result = result.replaceAll(accented[index], plain[index]);
    }
    return result
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _withoutHebrewMarks(String value) =>
      value.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');

  String _transliterationPattern(String value) {
    final lower = value.toLowerCase();
    if (!RegExp(r'^[a-z]+$').hasMatch(lower)) return '%$lower%';
    return '%${lower.replaceAll(RegExp('[aeiouy]'), '_')}%';
  }

  String _withoutGreekMarks(String value) {
    const accented = 'άέήίόύώΆΈΉΊΌΎΏϊΐϋΰάέήίόύώΆΈΉΊΌΎΏ';
    const plain = 'αεηιουωΑΕΗΙΟΥΩιιυυαεηιουωΑΕΗΙΟΥΩ';
    var normalized = value.replaceAll(RegExp(r'[\u0300-\u036F]'), '');
    for (var index = 0; index < accented.length; index++) {
      normalized = normalized.replaceAll(accented[index], plain[index]);
    }
    return normalized;
  }
}
