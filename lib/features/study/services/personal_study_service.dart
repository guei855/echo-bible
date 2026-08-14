import 'dart:convert';

import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/study_database_service.dart';
import 'package:sqflite/sqflite.dart';

typedef StudyDatabaseProvider = Future<Database> Function();

class PersonalStudyRepository {
  PersonalStudyRepository({StudyDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => StudyDatabaseService.database);

  final StudyDatabaseProvider _databaseProvider;

  Future<List<PersonalStudy>> loadAll({String query = ''}) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'study_documents',
      orderBy: 'is_pinned DESC, updated_at DESC, id DESC',
    );
    final documents = <PersonalStudy>[];
    for (final row in rows) {
      final study = await _fromRow(db, row);
      final needle = query.trim().toLowerCase();
      if (needle.isEmpty ||
          '${study.title} ${study.content} ${study.reference ?? ''} '
                  '${study.tags.join(' ')}'
              .toLowerCase()
              .contains(needle)) {
        documents.add(study);
      }
    }
    return documents;
  }

  Future<PersonalStudy?> load(int id) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'study_documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(db, rows.first);
  }

  Future<PersonalStudy> create({
    String title = 'Document sans titre',
    StudyDocumentType type = StudyDocumentType.free,
    bool useTemplate = false,
    List<StudyBlock>? initialBlocks,
  }) async {
    final db = await _databaseProvider();
    final now = DateTime.now();
    final blocks = initialBlocks ??
        (useTemplate ? StudyTemplates.forType(type, now) : [_emptyText(now)]);
    final id = await db.insert('study_documents', {
      'title': title.trim().isEmpty ? 'Document sans titre' : title.trim(),
      'document_type': type.databaseValue,
      'primary_reference': null,
      'tags_json': '[]',
      'metadata_json': '{}',
      'status': StudyStatus.draft.databaseValue,
      'is_favorite': 0,
      'is_pinned': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    final study = PersonalStudy(
      id: id,
      title: title.trim().isEmpty ? 'Document sans titre' : title.trim(),
      type: type,
      blocks: blocks,
      createdAt: now,
      updatedAt: now,
    );
    await save(study);
    return (await load(id))!;
  }

  Future<void> save(PersonalStudy study) async {
    final db = await _databaseProvider();
    final now = DateTime.now().toIso8601String();
    await db.transaction((transaction) async {
      await transaction.update(
        'study_documents',
        {
          'title': study.title.trim().isEmpty
              ? 'Document sans titre'
              : study.title.trim(),
          'document_type': study.type.databaseValue,
          'primary_reference': study.primaryReference?.trim().isEmpty == true
              ? null
              : study.primaryReference?.trim(),
          'tags_json': jsonEncode(study.tags),
          'metadata_json': jsonEncode(study.metadata),
          'status': study.status.databaseValue,
          'is_favorite': study.isFavorite ? 1 : 0,
          'is_pinned': study.isPinned ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [study.id],
      );
      await transaction.delete(
        'study_blocks',
        where: 'study_id = ?',
        whereArgs: [study.id],
      );
      for (var index = 0; index < study.blocks.length; index++) {
        final block = study.blocks[index];
        await transaction.insert('study_blocks', {
          'study_id': study.id,
          'position': index,
          'block_id': block.id,
          'block_type': block.type.name,
          'payload_json': block.encodePayload(),
          'created_at': block.createdAt.toIso8601String(),
          'updated_at': block.updatedAt.toIso8601String(),
        });
      }
    });
  }

  Future<PersonalStudy> duplicate(PersonalStudy source) async {
    final now = DateTime.now();
    final copy = await create(
      title: 'Copie de ${source.title}',
      type: source.type,
      initialBlocks: [
        for (var index = 0; index < source.blocks.length; index++)
          StudyBlock(
            id: _newBlockId(now, index),
            type: source.blocks[index].type,
            position: index,
            payload: Map<String, Object?>.from(source.blocks[index].payload),
            createdAt: now,
            updatedAt: now,
          ),
      ],
    );
    final complete = copy.copyWith(
      primaryReference: source.primaryReference,
      tags: [...source.tags],
      metadata: Map<String, Object?>.from(source.metadata),
      status: StudyStatus.draft,
    );
    await save(complete);
    return (await load(copy.id))!;
  }

  Future<void> delete(int id) async {
    final db = await _databaseProvider();
    await db.delete('study_documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<PersonalStudy> _fromRow(
    Database db,
    Map<String, Object?> row,
  ) async {
    final id = row['id'] as int;
    final sectionRows = await db.query(
      'study_blocks',
      where: 'study_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC, id ASC',
    );
    final blocks = <StudyBlock>[];
    for (var index = 0; index < sectionRows.length; index++) {
      final section = sectionRows[index];
      final payload = StudyBlock.decodePayload(
        section['payload_json'] as String?,
      );
      final created = _date(section['created_at']) ?? _date(row['created_at']);
      blocks.add(StudyBlock(
        databaseId: section['id'] as int,
        id: section['block_id'] as String? ?? 'legacy-${section['id']}',
        type: StudyBlockType.parse(section['block_type'] as String?),
        position: index,
        payload: payload,
        createdAt: created ?? DateTime.now(),
        updatedAt: _date(section['updated_at']) ?? created ?? DateTime.now(),
      ));
    }
    return PersonalStudy(
      id: id,
      title: row['title'] as String? ?? 'Document sans titre',
      type: StudyDocumentType.parse(row['document_type'] as String?),
      blocks: blocks,
      primaryReference: row['primary_reference'] as String?,
      tags: _stringList(row['tags_json']),
      metadata: _map(row['metadata_json']),
      status: StudyStatus.parse(row['status'] as String?),
      isFavorite: row['is_favorite'] == 1,
      isPinned: row['is_pinned'] == 1,
      createdAt: _date(row['created_at']) ?? DateTime.now(),
      updatedAt: _date(row['updated_at']) ?? DateTime.now(),
    );
  }

  static StudyBlock _emptyText(DateTime now) => StudyBlock(
        id: _newBlockId(now, 0),
        type: StudyBlockType.text,
        position: 0,
        payload: const {
          'text': '',
          'style': {'name': 'normal'}
        },
        createdAt: now,
        updatedAt: now,
      );

  static String _newBlockId(DateTime time, int index) =>
      '${time.microsecondsSinceEpoch}-$index';

  static DateTime? _date(Object? value) =>
      DateTime.tryParse(value as String? ?? '');

  static List<String> _stringList(Object? value) {
    try {
      return (jsonDecode(value as String? ?? '[]') as List)
          .map((item) => item.toString())
          .toList();
    } on Object {
      return const [];
    }
  }

  static Map<String, Object?> _map(Object? value) {
    try {
      return Map<String, Object?>.from(
        jsonDecode(value as String? ?? '{}') as Map,
      );
    } on Object {
      return const {};
    }
  }
}

class StudyTemplates {
  const StudyTemplates._();

  static List<StudyBlock> forType(StudyDocumentType type, DateTime now) {
    final headings = switch (type) {
      StudyDocumentType.sermon => const [
          'THÈME',
          'TEXTE PRINCIPAL',
          'INTRODUCTION',
          'I. PREMIER POINT',
          'A. Sous-point',
          '1. Développement',
          'Références bibliques',
          'Application',
          'II. DEUXIÈME POINT',
          'III. TROISIÈME POINT',
          'CONCLUSION',
          'APPEL / APPLICATION',
        ],
      StudyDocumentType.bibleStudy => const [
          'PASSAGE',
          'CONTEXTE',
          'OBSERVATION',
          'INTERPRÉTATION',
          'MOTS IMPORTANTS',
          'RÉFÉRENCES CROISÉES',
          'VÉRITÉS DOCTRINALES',
          'APPLICATIONS',
          'QUESTIONS',
          'CONCLUSION',
        ],
      StudyDocumentType.meditation => const [
          'THÈME',
          'VERSET',
          'MÉDITATION',
          'VÉRITÉ À RETENIR',
          'APPLICATION',
          'PRIÈRE',
          'CONCLUSION',
        ],
      StudyDocumentType.free => const <String>[],
    };
    if (headings.isEmpty) return [PersonalStudyRepository._emptyText(now)];
    final blocks = <StudyBlock>[];
    for (final heading in headings) {
      blocks.add(StudyBlock(
        id: PersonalStudyRepository._newBlockId(now, blocks.length),
        type: StudyBlockType.heading,
        position: blocks.length,
        payload: {
          'text': heading,
          'level': heading == heading.toUpperCase() ? 1 : 2
        },
        createdAt: now,
        updatedAt: now,
      ));
      blocks.add(StudyBlock(
        id: PersonalStudyRepository._newBlockId(now, blocks.length),
        type: StudyBlockType.text,
        position: blocks.length,
        payload: const {
          'text': '',
          'style': {'name': 'normal'}
        },
        createdAt: now,
        updatedAt: now,
      ));
    }
    return blocks;
  }
}

class PersonalStudyService {
  const PersonalStudyService._();
  static final repository = PersonalStudyRepository();

  static Future<List<PersonalStudy>> loadAll({String query = ''}) =>
      repository.loadAll(query: query);
  static Future<PersonalStudy?> load(int id) => repository.load(id);
  static Future<PersonalStudy> create({
    String title = 'Document sans titre',
    StudyDocumentType type = StudyDocumentType.free,
    bool useTemplate = false,
    List<StudyBlock>? initialBlocks,
  }) =>
      repository.create(
        title: title,
        type: type,
        useTemplate: useTemplate,
        initialBlocks: initialBlocks,
      );
  static Future<void> saveDocument(PersonalStudy study) =>
      repository.save(study);
  static Future<PersonalStudy> duplicate(PersonalStudy study) =>
      repository.duplicate(study);
  static Future<void> delete(int id) => repository.delete(id);
}
