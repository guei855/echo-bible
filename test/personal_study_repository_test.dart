import 'package:echo_bible/core/database/study_document_schema.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:echo_bible/features/study/services/study_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<Database> openStudyDatabase() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await StudyDocumentSchema.ensure(db);
    return db;
  }

  test('crée la base dédiée avec ses tables et index', () async {
    final db = await openStudyDatabase();
    addTearDown(db.close);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']);
    expect(names,
        containsAll(['study_documents', 'study_blocks', 'study_metadata']));
    expect(names, isNot(contains('verses')));
    final documentColumns =
        await db.rawQuery('PRAGMA table_info(study_documents)');
    expect(
        documentColumns.map((column) => column['name']),
        containsAll([
          'document_type',
          'primary_reference',
          'tags_json',
          'metadata_json',
          'status',
          'is_favorite',
          'is_pinned',
        ]));
  });

  test('cycle complet création, autosave logique, reprise et suppression',
      () async {
    final db = await openStudyDatabase();
    addTearDown(db.close);
    final repository =
        PersonalStudyRepository(databaseProvider: () async => db);

    final created = await repository.create(
      title: 'La grâce de Dieu',
      type: StudyDocumentType.sermon,
      useTemplate: true,
    );
    expect(created.type, StudyDocumentType.sermon);
    expect(created.blocks.map((block) => block.plainText),
        contains('INTRODUCTION'));

    final now = DateTime.now();
    final verse = StudyBlock(
      id: 'verse-1',
      type: StudyBlockType.verseRange,
      position: created.blocks.length,
      payload: const {
        'translationId': 1,
        'bookId': 49,
        'bookName': 'Éphésiens',
        'chapter': 2,
        'verseStart': 8,
        'verseEnd': 10,
        'reference': 'Éphésiens 2:8-10',
        'text': '8 Car c’est par la grâce…',
      },
      createdAt: now,
      updatedAt: now,
    );
    final updated = created.copyWith(
      title: 'La grâce',
      primaryReference: 'Éphésiens 2:8-10',
      tags: const ['Grâce', 'Foi'],
      isFavorite: true,
      isPinned: true,
      blocks: [...created.blocks, verse],
    );
    await repository.save(updated);

    final reopened = await repository.load(created.id);
    expect(reopened, isNotNull);
    expect(reopened!.title, 'La grâce');
    expect(reopened.primaryReference, 'Éphésiens 2:8-10');
    expect(reopened.tags, ['Grâce', 'Foi']);
    expect(reopened.isFavorite, isTrue);
    expect(reopened.isPinned, isTrue);
    expect(reopened.blocks.last.type, StudyBlockType.verseRange);
    expect(reopened.blocks.last.payload['translationId'], 1);
    expect(reopened.blocks.last.payload['verseEnd'], 10);

    final results = await repository.loadAll(query: 'Foi');
    expect(results.map((study) => study.id), contains(created.id));
    final duplicate = await repository.duplicate(reopened);
    expect(duplicate.id, isNot(created.id));
    expect(duplicate.title, 'Copie de La grâce');
    expect(
        duplicate.blocks.map((block) => block.id).toSet().intersection(
              reopened.blocks.map((block) => block.id).toSet(),
            ),
        isEmpty);

    await repository.delete(created.id);
    expect(await repository.load(created.id), isNull);
    expect(await repository.load(duplicate.id), isNotNull);
  });

  test('préserve ordre et payload des types de blocs intelligents', () async {
    final db = await openStudyDatabase();
    addTearDown(db.close);
    final repository =
        PersonalStudyRepository(databaseProvider: () async => db);
    final now = DateTime.now();
    final types = StudyBlockType.values;
    final blocks = [
      for (var index = 0; index < types.length; index++)
        StudyBlock(
          id: 'block-$index',
          type: types[index],
          position: index,
          payload: {
            'text': 'contenu $index',
            'nested': {'value': index},
            'items': [index, index + 1],
          },
          createdAt: now,
          updatedAt: now,
        ),
    ];
    final study = await repository.create(
      initialBlocks: blocks,
      primaryReference: 'J\u00e9r\u00e9mie 26:4',
    );
    final reopened = await repository.load(study.id);
    expect(study.id, greaterThan(0));
    expect(reopened!.primaryReference, 'J\u00e9r\u00e9mie 26:4');
    expect(reopened.blocks.map((block) => block.type), types);
    expect(reopened.blocks.map((block) => block.position),
        List.generate(types.length, (index) => index));
    expect(reopened.blocks[5].payload['nested'], {'value': 5});
    expect(reopened.blocks[5].payload['items'], [5, 6]);
  });

  test('export texte omet les métadonnées techniques', () {
    final now = DateTime.now();
    final study = PersonalStudy(
      id: 1,
      title: 'La grâce de Dieu',
      type: StudyDocumentType.sermon,
      primaryReference: 'Éphésiens 2:8-10',
      blocks: [
        StudyBlock(
          id: 'rich',
          type: StudyBlockType.text,
          position: 0,
          payload: const {
            'format': 'quill_delta_v1',
            'delta': [
              {
                'insert': 'La grâce par la foi',
                'attributes': {'bold': true, 'color': '#B91C1C'}
              },
              {'insert': '\n'}
            ],
          },
          createdAt: now,
          updatedAt: now,
        ),
        StudyBlock(
          id: 'verse',
          type: StudyBlockType.verse,
          position: 1,
          payload: const {
            'translationId': 1,
            'reference': 'Jean 3:16 — LSG',
            'text': 'Car Dieu a tant aimé le monde…',
          },
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final text = StudyExportService.renderText(study);
    expect(text, contains('LA GRÂCE DE DIEU'));
    expect(text, contains('Jean 3:16'));
    expect(text, contains('La grâce par la foi'));
    expect(text, isNot(contains('translationId')));
    expect(text, isNot(contains('quill_delta_v1')));
    expect(text, isNot(contains('#B91C1C')));
  });

  test('persiste et rouvre un Delta riche sans perte', () async {
    final db = await openStudyDatabase();
    addTearDown(db.close);
    final repository =
        PersonalStudyRepository(databaseProvider: () async => db);
    final now = DateTime.now();
    const payload = <String, Object?>{
      'format': 'quill_delta_v1',
      'delta': [
        {
          'insert': 'Foi',
          'attributes': {'bold': true, 'background': '#FFF59D'}
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'}
        },
      ],
    };
    final created = await repository.create(initialBlocks: [
      StudyBlock(
        id: 'rich-persisted',
        type: StudyBlockType.text,
        position: 0,
        payload: payload,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final reopened = await repository.load(created.id);
    expect(reopened!.blocks.single.payload, payload);
    expect(reopened.content, 'Foi');
  });
}
