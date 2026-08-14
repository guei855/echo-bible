import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('autosave débouncé conserve titre et contenu', (tester) async {
    final now = DateTime.now();
    final study = PersonalStudy(
      id: 1,
      title: 'Document sans titre',
      blocks: [
        StudyBlock(
          id: 'text-1',
          type: StudyBlockType.text,
          position: 0,
          payload: const {'text': ''},
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    PersonalStudy? saved;
    var saveCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: PersonalStudyEditorScreen(
        study: study,
        autosaveDelay: const Duration(milliseconds: 100),
        saveDocument: (value) async {
          saveCount++;
          saved = value;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('study-title')), 'Grâce');
    await tester.enterText(
      find.byKey(const Key('study-block-text-1')),
      'Une introduction préservée.',
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(saveCount, 0);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();

    expect(saveCount, 1);
    expect(saved!.title, 'Grâce');
    expect(saved!.blocks.single.payload['text'], 'Une introduction préservée.');
    expect(find.text('Sauvegardé'), findsOneWidget);
  });

  testWidgets(
      'affiche les blocs bibliques, Strong, dictionnaire et comparaison',
      (tester) async {
    final now = DateTime.now();
    StudyBlock block(
            StudyBlockType type, Map<String, Object?> payload, int index) =>
        StudyBlock(
          id: 'block-$index',
          type: type,
          position: index,
          payload: payload,
          createdAt: now,
          updatedAt: now,
        );
    final study = PersonalStudy(
      id: 2,
      title: 'Atelier biblique',
      blocks: [
        block(StudyBlockType.verse,
            const {'reference': 'Jean 3:16', 'text': 'Car Dieu…'}, 0),
        block(
            StudyBlockType.strong,
            const {
              'code': 'G3056',
              'originalWord': 'λόγος',
              'definition': 'Parole'
            },
            1),
        block(StudyBlockType.dictionary,
            const {'title': 'ALLIANCE', 'excerpt': 'Convention…'}, 2),
        block(
            StudyBlockType.crossReferences,
            const {
              'references': ['Romains 5:8', '1 Jean 4:9-10']
            },
            3),
        block(
            StudyBlockType.comparison,
            const {
              'versions': [
                {'label': 'LSG', 'text': 'Car Dieu…'},
                {'label': 'Darby', 'text': 'Car Dieu…'}
              ]
            },
            4),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(MaterialApp(
        home: PersonalStudyEditorScreen(
            study: study, saveDocument: (_) async {})));
    expect(find.text('Jean 3:16\nCar Dieu…'), findsOneWidget);
    expect(find.textContaining('G3056'), findsOneWidget);
    await tester.drag(
        find.byKey(const Key('study-block-list')), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.textContaining('ALLIANCE'), findsOneWidget);
    expect(find.textContaining('Romains 5:8'), findsOneWidget);
    expect(find.textContaining('Darby'), findsOneWidget);
  });
}
