import 'dart:convert';

import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/study/models/study_tab.dart';

class StudyTabManager {
  const StudyTabManager();

  static const _defaults = [
    StudyTab(
        id: 'bible-john-3',
        type: 'bible',
        title: 'Jean 3',
        state: {'book': 43, 'chapter': 3}),
    StudyTab(
        id: 'strong-g26',
        type: 'strong',
        title: 'Strong G26',
        state: {'query': 'G26'}),
    StudyTab(
        id: 'concordance-amour',
        type: 'concordance',
        title: 'amour',
        state: {'query': 'amour'}),
    StudyTab(
        id: 'nave-faith',
        type: 'nave',
        title: 'Nave : Foi',
        state: {'query': 'Foi'}),
    StudyTab(
        id: 'comparison-john-3-16',
        type: 'comparison',
        title: 'Jean 3:16',
        state: {'book': 43, 'chapter': 3, 'verse': 16}),
  ];

  Future<List<StudyTab>> load() async {
    final db = await DatabaseService.database;
    var rows = await db.query('study_tabs', orderBy: 'sort_order');
    if (rows.isEmpty) {
      for (var index = 0; index < _defaults.length; index++) {
        final tab = _defaults[index];
        await db.insert('study_tabs', {
          'id': tab.id,
          'type': tab.type,
          'title': tab.title,
          'state_json': jsonEncode(tab.state),
          'sort_order': index,
          'updated_at': DateTime.now().toIso8601String()
        });
      }
      rows = await db.query('study_tabs', orderBy: 'sort_order');
    }
    return rows
        .map((row) => StudyTab(
            id: row['id'] as String,
            type: row['type'] as String,
            title: row['title'] as String,
            state: jsonDecode(row['state_json'] as String)
                as Map<String, dynamic>))
        .toList();
  }

  Future<void> close(String id) async {
    final db = await DatabaseService.database;
    await db.delete('study_tabs', where: 'id=?', whereArgs: [id]);
  }
}
