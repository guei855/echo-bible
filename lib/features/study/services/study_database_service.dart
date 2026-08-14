import 'dart:convert';

import 'package:echo_bible/core/database/study_document_schema.dart';
import 'package:echo_bible/core/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class StudyDatabaseService {
  const StudyDatabaseService._();

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databasesPath, 'echo_studies.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => StudyDocumentSchema.ensure(db),
      onOpen: StudyDocumentSchema.ensure,
    );
    _database = database;
    await _importLegacyStudies(database);
    return database;
  }

  static Future<void> _importLegacyStudies(Database target) async {
    final marker = await target.query(
      'study_metadata',
      where: 'key = ?',
      whereArgs: ['legacy_import_v1'],
      limit: 1,
    );
    if (marker.isNotEmpty) return;
    try {
      final source = await DatabaseService.database;
      final tables = await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('personal_studies','study_sections')",
      );
      if (tables.length == 2) {
        final studies = await source.query('personal_studies');
        await target.transaction((transaction) async {
          for (final study in studies) {
            final studyId = study['id'] as int;
            final sections = await source.query(
              'study_sections',
              where: 'study_id = ?',
              whereArgs: [studyId],
              orderBy: 'position, id',
            );
            String? primaryReference;
            for (final section in sections) {
              final value = section['reference'] as String?;
              if (value != null && value.trim().isNotEmpty) {
                primaryReference = value;
                break;
              }
            }
            await transaction.insert('study_documents', {
              'id': studyId,
              'title': study['title'] as String? ?? 'Document sans titre',
              'document_type': 'free',
              'primary_reference': primaryReference,
              'tags_json': '[]',
              'metadata_json': jsonEncode({'importedFrom': 'bible.db'}),
              'status': 'draft',
              'is_favorite': 0,
              'is_pinned': 0,
              'created_at': study['created_at'] as String? ??
                  DateTime.now().toIso8601String(),
              'updated_at': study['updated_at'] as String? ??
                  DateTime.now().toIso8601String(),
            });
            for (var index = 0; index < sections.length; index++) {
              final section = sections[index];
              final reference = section['reference'] as String?;
              final kind = section['kind'] as String? ?? 'text';
              await transaction.insert('study_blocks', {
                'study_id': studyId,
                'block_id': 'legacy-$studyId-${section['id']}',
                'position': index,
                'block_type': kind == 'verse' ? 'verseLink' : kind,
                'payload_json': jsonEncode({
                  'text': section['content'] as String? ?? '',
                  if (reference != null) 'reference': reference,
                }),
                'created_at': study['created_at'] as String? ??
                    DateTime.now().toIso8601String(),
                'updated_at': study['updated_at'] as String? ??
                    DateTime.now().toIso8601String(),
              });
            }
          }
        });
      }
    } on DatabaseException {
      // Une ancienne base absente ou incomplète signifie simplement qu'il
      // n'y a rien à importer. Le document neuf reste utilisable hors ligne.
    } finally {
      await target.insert(
        'study_metadata',
        {'key': 'legacy_import_v1', 'value': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
