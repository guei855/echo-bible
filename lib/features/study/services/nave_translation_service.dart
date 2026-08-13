import 'dart:io';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class NaveLocalizedText {
  final String text;
  final String status;

  const NaveLocalizedText({required this.text, required this.status});
}

class NaveTopicMatch extends NaveLocalizedText {
  final int topicId;
  final int rank;

  const NaveTopicMatch({
    required this.topicId,
    required super.text,
    required super.status,
    required this.rank,
  });
}

/// Reads the optional, lightweight French layer without attaching or copying
/// the original Nave database. Connections are intentionally short-lived so a
/// resource can safely be removed and reinstalled while the application runs.
class NaveTranslationService {
  const NaveTranslationService._();

  static Future<List<NaveTopicMatch>> searchTopics(
    String normalizedQuery,
    Iterable<String> exactCandidates, {
    int limit = 100,
  }) async {
    final candidates = exactCandidates.toSet().toList(growable: false);
    if (normalizedQuery.isEmpty || candidates.isEmpty) return const [];
    return await _withDatabase<List<NaveTopicMatch>>((db) async {
          final placeholders = List.filled(candidates.length, '?').join(',');
          final rows = await db.rawQuery('''
            SELECT entity_id,translated_text,status,MIN(rank) rank
            FROM (
              SELECT entity_id,translated_text,status,0 rank
              FROM nave_translations
              WHERE language_code='fr' AND entity_type='topic'
                AND normalized_text IN ($placeholders)
              UNION ALL
              SELECT a.topic_id,t.translated_text,t.status,1 rank
              FROM nave_aliases a
              JOIN nave_translations t
                ON t.entity_type='topic' AND t.entity_id=a.topic_id
                  AND t.language_code=a.language_code
              WHERE a.language_code='fr'
                AND a.normalized_alias IN ($placeholders)
              UNION ALL
              SELECT entity_id,translated_text,status,2 rank
              FROM nave_translations
              WHERE language_code='fr' AND entity_type='topic'
                AND normalized_text LIKE ?
              UNION ALL
              SELECT entity_id,translated_text,status,3 rank
              FROM nave_translations
              WHERE language_code='fr' AND entity_type='topic'
                AND normalized_text LIKE ?
            )
            GROUP BY entity_id,translated_text,status
            ORDER BY rank,translated_text
            LIMIT ?
          ''', [
            ...candidates,
            ...candidates,
            '$normalizedQuery%',
            '%$normalizedQuery%',
            limit,
          ]);
          return rows
              .map((row) => NaveTopicMatch(
                    topicId: row['entity_id']! as int,
                    text: row['translated_text']! as String,
                    status: row['status']! as String,
                    rank: row['rank']! as int,
                  ))
              .toList(growable: false);
        }) ??
        const [];
  }

  static Future<Map<int, NaveLocalizedText>> translations(
    String entityType,
    Iterable<int> entityIds,
  ) async {
    final ids = entityIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    return await _withDatabase<Map<int, NaveLocalizedText>>((db) async {
          final placeholders = List.filled(ids.length, '?').join(',');
          final rows = await db.rawQuery('''
            SELECT entity_id,translated_text,status
            FROM nave_translations
            WHERE language_code='fr' AND entity_type=?
              AND entity_id IN ($placeholders)
          ''', [entityType, ...ids]);
          return {
            for (final row in rows)
              row['entity_id']! as int: NaveLocalizedText(
                text: row['translated_text']! as String,
                status: row['status']! as String,
              ),
          };
        }) ??
        const {};
  }

  static Future<List<NaveTopicMatch>> translatedTopics({
    int limit = 200,
  }) async =>
      await _withDatabase((db) async {
        final rows = await db.rawQuery('''
          SELECT entity_id,translated_text,status,0 rank
          FROM nave_translations
          WHERE language_code='fr' AND entity_type='topic'
          ORDER BY normalized_text
          LIMIT ?
        ''', [limit]);
        return rows
            .map((row) => NaveTopicMatch(
                  topicId: row['entity_id']! as int,
                  text: row['translated_text']! as String,
                  status: row['status']! as String,
                  rank: 0,
                ))
            .toList(growable: false);
      }) ??
      const [];

  static Future<T?> _withDatabase<T>(
    Future<T> Function(Database database) action,
  ) async {
    final file = await _databaseFile();
    if (file == null) return null;
    final database = await openDatabase(file.path, readOnly: true);
    try {
      return await action(database);
    } finally {
      await database.close();
    }
  }

  static Future<File?> _databaseFile() async {
    const manager = ResourceManager();
    final descriptor = manager.descriptor(OfflineResourceId.naveFrench);
    final installed = await manager.installedFile(descriptor);
    if (await installed.exists()) return installed;
    const compileTimeFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
    final isFlutterTest = compileTimeFlutterTest ||
        Platform.environment['FLUTTER_TEST']?.toLowerCase() == 'true';
    if (!isFlutterTest) return null;
    final development = File(path.join(
      Directory.current.path,
      'release_resources',
      'fr',
      'nave',
      descriptor.localFileName,
    ));
    return await development.exists() ? development : null;
  }
}
