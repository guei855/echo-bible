import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';

class PersonalStudyService {
  const PersonalStudyService._();

  static Future<List<PersonalStudy>> loadAll() async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery('''
      SELECT ps.id, ps.title, ps.updated_at,
        COALESCE((SELECT content FROM study_sections
          WHERE study_id = ps.id AND kind = 'text'
          ORDER BY position LIMIT 1), '') AS content,
        (SELECT reference FROM study_sections
          WHERE study_id = ps.id AND reference IS NOT NULL
          ORDER BY position LIMIT 1) AS reference
      FROM personal_studies ps
      ORDER BY ps.updated_at DESC, ps.id DESC
    ''');
    return rows.map(_fromRow).toList();
  }

  static Future<int> save({
    int? id,
    required String title,
    required String content,
    String? reference,
  }) async {
    final db = await DatabaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((transaction) async {
      final studyId = id ??
          await transaction.insert('personal_studies', {
            'title': title.trim(),
            'created_at': now,
            'updated_at': now,
          });
      if (id != null) {
        await transaction.update(
          'personal_studies',
          {'title': title.trim(), 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
        await transaction.delete(
          'study_sections',
          where: 'study_id = ?',
          whereArgs: [id],
        );
      }
      await transaction.insert('study_sections', {
        'study_id': studyId,
        'position': 0,
        'kind': 'text',
        'content': content.trim(),
        'style_json': '{}',
      });
      final cleanReference = reference?.trim();
      if (cleanReference != null && cleanReference.isNotEmpty) {
        await transaction.insert('study_sections', {
          'study_id': studyId,
          'position': 1,
          'kind': 'verse',
          'content': cleanReference,
          'reference': cleanReference,
          'style_json': '{}',
        });
      }
      return studyId;
    });
  }

  static Future<void> delete(int id) async {
    final db = await DatabaseService.database;
    await db.delete('personal_studies', where: 'id = ?', whereArgs: [id]);
  }

  static PersonalStudy _fromRow(Map<String, Object?> row) => PersonalStudy(
        id: row['id'] as int,
        title: row['title'] as String,
        content: row['content'] as String? ?? '',
        reference: row['reference'] as String?,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
