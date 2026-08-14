import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: home,
      );

  testWidgets('autosave débouncé conserve titre et Delta riche',
      (tester) async {
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
    QuillController? richController;
    var saveCount = 0;
    await tester.pumpWidget(app(PersonalStudyEditorScreen(
      study: study,
      autosaveDelay: const Duration(milliseconds: 100),
      onActiveController: (value) => richController = value,
      saveDocument: (value) async {
        saveCount++;
        saved = value;
      },
    )));

    await tester.enterText(find.byKey(const Key('study-title')), 'Grâce');
    richController!.replaceText(
      0,
      0,
      'Une introduction préservée.',
      const TextSelection.collapsed(offset: 28),
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(saveCount, 0);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();

    expect(saveCount, 1);
    expect(saved!.title, 'Grâce');
    expect(saved!.blocks.single.payload['format'], 'quill_delta_v1');
    expect(saved!.blocks.single.plainText, 'Une introduction préservée.');
    expect(find.text('Sauvegardé'), findsOneWidget);
  });

  testWidgets('le gras est WYSIWYG et aucun marqueur ne devient visible',
      (tester) async {
    final now = DateTime.now();
    QuillController? controller;
    final study = PersonalStudy(
      id: 2,
      title: 'Atelier biblique',
      blocks: [
        StudyBlock(
          id: 'rich-1',
          type: StudyBlockType.text,
          position: 0,
          payload: const {
            'format': 'quill_delta_v1',
            'delta': [
              {'insert': 'Grâce et foi\n'},
            ],
          },
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(app(PersonalStudyEditorScreen(
      study: study,
      onActiveController: (value) => controller = value,
      saveDocument: (_) async {},
    )));

    controller!.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.tap(find.byKey(const Key('rich-bold')));
    await tester.pump();

    final delta = controller!.document.toDelta().toJson();
    expect(delta.first['insert'], 'Grâce');
    expect((delta.first['attributes'] as Map)['bold'], isTrue);
    expect(controller!.document.toPlainText(), isNot(contains('**')));
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('les ressources sont des cartes sans poignée permanente',
      (tester) async {
    final now = DateTime.now();
    final study = PersonalStudy(
      id: 3,
      title: 'Ressources',
      blocks: [
        StudyBlock(
          id: 'verse',
          type: StudyBlockType.verse,
          position: 0,
          payload: const {'reference': 'Jean 3:16', 'text': 'Car Dieu…'},
          createdAt: now,
          updatedAt: now,
        ),
        StudyBlock(
          id: 'strong',
          type: StudyBlockType.strong,
          position: 1,
          payload: const {
            'code': 'G3056',
            'originalWord': 'λόγος',
            'definition': 'Parole',
          },
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(app(PersonalStudyEditorScreen(
      study: study,
      saveDocument: (_) async {},
    )));

    expect(find.text('Jean 3:16\nCar Dieu…'), findsOneWidget);
    expect(find.textContaining('G3056'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Ouvrir'), findsNothing);
    await tester.longPress(find.text('Verset'));
    await tester.pump();
    expect(find.text('Ouvrir'), findsOneWidget);
  });
}
