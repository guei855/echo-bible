import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/services/nave_database_service.dart';
import 'package:echo_bible/features/study/services/nave_translation_service.dart';

class NaveRepository {
  const NaveRepository();
  String normalize(String value) {
    var result = value.toLowerCase();
    const accents = {
      '\u00e0': 'a',
      '\u00e2': 'a',
      '\u00e4': 'a',
      '\u00e9': 'e',
      '\u00e8': 'e',
      '\u00ea': 'e',
      '\u00eb': 'e',
      '\u00ee': 'i',
      '\u00ef': 'i',
      '\u00f4': 'o',
      '\u00f6': 'o',
      '\u00f9': 'u',
      '\u00fb': 'u',
      '\u00fc': 'u',
      '\u00e7': 'c',
      '\u0153': 'oe',
    };
    accents.forEach(
        (key, replacement) => result = result.replaceAll(key, replacement));
    result = result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    const frenchAliases = {
      'amour': 'love',
      'foi': 'faith',
      'peche': 'sin',
      'priere': 'prayer',
      'salut': 'salvation',
      'saint esprit': 'holy spirit',
      'dieu': 'god',
      'jesus': 'jesus the christ',
      'mariage': 'marriage',
    };
    return frenchAliases[result] ?? result;
  }

  Future<List<NaveTopic>> search(String value, {int limit = 100}) async {
    final query = normalize(value);
    if (query.isEmpty) return const [];
    final db = await NaveDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT id,COALESCE(title_fr,title_en) title
      FROM nave_topics
      WHERE normalized_en LIKE ? OR normalized_fr LIKE ?
      ORDER BY CASE WHEN normalized_fr=? OR normalized_en=? THEN 0 ELSE 1 END,
        COALESCE(title_fr,title_en)
      LIMIT ?
    ''', ['%$query%', '%$query%', query, query, limit]);
    return Future.wait(rows.map((row) async {
      final id = row['id'] as int;
      return NaveTopic(
        id: id,
        title: await NaveTranslationService.translation('topic', id) ??
            row['title'] as String,
      );
    }));
  }

  Future<List<NaveReference>> references(int topicId) async {
    final naveDb = await NaveDatabaseService.database;
    final rows = await naveDb.rawQuery('''SELECT nr.*,
        COALESCE(ns.title_fr,ns.title_en) subtopic
      FROM nave_references nr
      JOIN nave_sections ns ON ns.id=nr.section_id
      WHERE nr.topic_id=? ORDER BY ns.id,nr.id''', [topicId]);
    final bibleDb = await DatabaseService.database;
    final books = {
      for (final row in await bibleDb.query('books')) row['id'] as int: row
    };
    return Future.wait(rows.map((row) async {
      final book = books[row['book_id']]!;
      return NaveReference(
          subtopicId: row['section_id'] as int,
          subtopic: await NaveTranslationService.translation(
                'section',
                row['section_id'] as int,
              ) ??
              row['subtopic'] as String,
          bookId: row['book_id'] as int,
          bookName: book['name'] as String,
          chaptersCount: book['chapters_count'] as int,
          chapter: row['chapter'] as int,
          verseStart: row['verse_start'] as int,
          verseEnd: row['verse_end'] as int?);
    }));
  }

  Future<List<NaveTopic>> forVerse(
    int bookId,
    int chapter,
    int verse, {
    int limit = 100,
  }) async {
    final db = await NaveDatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT nt.id,COALESCE(nt.title_fr,nt.title_en) title
      FROM nave_references nr
      JOIN nave_topics nt ON nt.id=nr.topic_id
      WHERE nr.book_id=? AND nr.chapter=?
        AND ? BETWEEN nr.verse_start AND COALESCE(nr.verse_end,nr.verse_start)
      ORDER BY COALESCE(nt.title_fr,nt.title_en)
      LIMIT ?
    ''', [bookId, chapter, verse, limit]);
    return Future.wait(rows.map((row) async {
      final id = row['id'] as int;
      return NaveTopic(
        id: id,
        title: await NaveTranslationService.translation('topic', id) ??
            row['title'] as String,
      );
    }));
  }

  Future<int> count() async {
    final db = await NaveDatabaseService.database;
    return (await db.rawQuery('SELECT COUNT(*) total FROM nave_topics'))
        .first['total'] as int;
  }
}
