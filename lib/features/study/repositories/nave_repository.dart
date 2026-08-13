import 'package:echo_bible/core/resources/language_settings_service.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/services/nave_database_service.dart';
import 'package:echo_bible/features/study/services/nave_translation_service.dart';
import 'package:sqflite/sqflite.dart';

class NaveRepository {
  const NaveRepository();

  String normalize(String value) {
    var result = value.toLowerCase();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'í': 'i',
      'ô': 'o',
      'ö': 'o',
      'ó': 'o',
      'œ': 'oe',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'ÿ': 'y',
    };
    accents.forEach(
      (key, replacement) => result = result.replaceAll(key, replacement),
    );
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  Set<String> searchForms(String value) {
    final query = normalize(value);
    if (query.isEmpty) return const {};
    final forms = <String>{query};
    if (query.length > 3 && query.endsWith('s')) {
      forms.add(query.substring(0, query.length - 1));
    }
    if (query.length > 4 && query.endsWith('es')) {
      forms.add(query.substring(0, query.length - 2));
    }
    if (query.length > 4 && query.endsWith('ies')) {
      forms.add('${query.substring(0, query.length - 3)}y');
    }
    return forms;
  }

  Future<List<NaveTopic>> browse({
    int limit = 200,
    AppLanguage? language,
  }) async {
    final selectedLanguage = language ?? await LanguageSettingsService.load();
    final french = selectedLanguage == AppLanguage.fr
        ? await NaveTranslationService.translatedTopics(limit: limit)
        : const <NaveTopicMatch>[];
    return NaveDatabaseService.use((db) async {
      final localizedIds = french.map((item) => item.topicId).toSet();
      final englishRows = await db.query(
        'nave_topics',
        columns: ['id', 'title_en'],
        orderBy: 'normalized_en',
        limit: limit,
      );
      final ids = {
        ...localizedIds,
        ...englishRows.map((row) => row['id'] as int)
      };
      final titles = await _englishTitles(db, ids);
      final topics = <NaveTopic>[
        for (final item in french)
          NaveTopic(
            id: item.topicId,
            title: item.text,
            titleEnglish: titles[item.topicId]!,
            translationStatus: item.status,
          ),
      ];
      for (final row in englishRows) {
        final id = row['id']! as int;
        if (localizedIds.contains(id)) continue;
        final title = row['title_en']! as String;
        topics.add(NaveTopic(id: id, title: title, titleEnglish: title));
        if (topics.length == limit) break;
      }
      return topics;
    });
  }

  Future<List<NaveTopic>> search(
    String value, {
    int limit = 100,
    AppLanguage? language,
  }) async {
    final query = normalize(value);
    if (query.isEmpty) return browse(limit: limit, language: language);
    final selectedLanguage = language ?? await LanguageSettingsService.load();
    final forms = searchForms(value);
    final frenchMatches = selectedLanguage == AppLanguage.fr
        ? await NaveTranslationService.searchTopics(query, forms, limit: limit)
        : const <NaveTopicMatch>[];

    return NaveDatabaseService.use((db) async {
      final frenchIds = frenchMatches.map((match) => match.topicId).toSet();
      final englishRows = await _searchEnglish(db, query, forms, limit);
      final allIds = <int>{
        ...frenchIds,
        ...englishRows.map((row) => row['id']! as int),
      };
      final englishTitles = await _englishTitles(db, allIds);
      final extraFrench = selectedLanguage == AppLanguage.fr
          ? await NaveTranslationService.translations('topic', allIds)
          : const <int, NaveLocalizedText>{};
      final results = <int, NaveTopic>{};

      for (final match in frenchMatches) {
        results[match.topicId] = NaveTopic(
          id: match.topicId,
          title: match.text,
          titleEnglish: englishTitles[match.topicId]!,
          translationStatus: match.status,
        );
      }
      for (final row in englishRows) {
        final id = row['id']! as int;
        if (results.containsKey(id)) continue;
        final english = row['title_en']! as String;
        final translated = extraFrench[id];
        results[id] = NaveTopic(
          id: id,
          title: translated?.text ?? english,
          titleEnglish: english,
          translationStatus: translated?.status,
        );
        if (results.length == limit) break;
      }
      return results.values.toList(growable: false);
    });
  }

  Future<List<NaveReference>> references(
    int topicId, {
    AppLanguage? language,
  }) async {
    final selectedLanguage = language ?? await LanguageSettingsService.load();
    final rows = await NaveDatabaseService.use((db) => db.rawQuery('''
      SELECT nr.*,ns.title_en subtopic_en
      FROM nave_references nr
      JOIN nave_sections ns ON ns.id=nr.section_id
      WHERE nr.topic_id=? ORDER BY ns.id,nr.id
    ''', [topicId]));
    final translations = selectedLanguage == AppLanguage.fr
        ? await NaveTranslationService.translations(
            'section',
            rows.map((row) => row['section_id']! as int),
          )
        : const <int, NaveLocalizedText>{};
    final bibleDb = await DatabaseService.database;
    final books = {
      for (final row in await bibleDb.query('books')) row['id'] as int: row,
    };
    return rows.map((row) {
      final sectionId = row['section_id']! as int;
      final english = row['subtopic_en']! as String;
      final translated = translations[sectionId];
      final book = books[row['book_id']]!;
      return NaveReference(
        subtopicId: sectionId,
        subtopic: translated?.text ?? english,
        subtopicEnglish: english,
        translationStatus: translated?.status,
        bookId: row['book_id']! as int,
        bookName: book['name']! as String,
        chaptersCount: book['chapters_count']! as int,
        chapter: row['chapter']! as int,
        verseStart: row['verse_start']! as int,
        verseEnd: row['verse_end'] as int?,
      );
    }).toList(growable: false);
  }

  Future<List<NaveTopic>> forVerse(
    int bookId,
    int chapter,
    int verse, {
    int limit = 100,
    AppLanguage? language,
  }) async {
    final selectedLanguage = language ?? await LanguageSettingsService.load();
    final rows = await NaveDatabaseService.use((db) => db.rawQuery('''
      SELECT DISTINCT nt.id,nt.title_en
      FROM nave_references nr
      JOIN nave_topics nt ON nt.id=nr.topic_id
      WHERE nr.book_id=? AND nr.chapter=?
        AND ? BETWEEN nr.verse_start AND COALESCE(nr.verse_end,nr.verse_start)
      ORDER BY nt.normalized_en
      LIMIT ?
    ''', [bookId, chapter, verse, limit]));
    final translations = selectedLanguage == AppLanguage.fr
        ? await NaveTranslationService.translations(
            'topic',
            rows.map((row) => row['id']! as int),
          )
        : const <int, NaveLocalizedText>{};
    return rows.map((row) {
      final id = row['id']! as int;
      final english = row['title_en']! as String;
      final translated = translations[id];
      return NaveTopic(
        id: id,
        title: translated?.text ?? english,
        titleEnglish: english,
        translationStatus: translated?.status,
      );
    }).toList(growable: false);
  }

  Future<int> count() => NaveDatabaseService.use((db) async =>
      (await db.rawQuery('SELECT COUNT(*) total FROM nave_topics'))
          .first['total']! as int);

  Future<List<Map<String, Object?>>> _searchEnglish(
    Database db,
    String query,
    Set<String> exactForms,
    int limit,
  ) {
    final placeholders = List.filled(exactForms.length, '?').join(',');
    return db.rawQuery('''
      SELECT id,title_en,
        CASE WHEN normalized_en IN ($placeholders) THEN 4 ELSE 5 END rank
      FROM nave_topics
      WHERE normalized_en IN ($placeholders) OR normalized_en LIKE ?
      ORDER BY rank,normalized_en,id
      LIMIT ?
    ''', [
      ...exactForms,
      ...exactForms,
      '%$query%',
      limit,
    ]);
  }

  Future<Map<int, String>> _englishTitles(
    Database db,
    Iterable<int> topicIds,
  ) async {
    final ids = topicIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id,title_en FROM nave_topics WHERE id IN ($placeholders)',
      ids,
    );
    return {
      for (final row in rows) row['id']! as int: row['title_en']! as String,
    };
  }
}
