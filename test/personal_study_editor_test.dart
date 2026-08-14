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

  test('inset toolbar nul clavier fermÃ© et dynamique clavier ouvert', () {
    expect(studyToolbarBottomInset(const MediaQueryData()), 0);
    expect(
      studyToolbarBottomInset(
        const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
      ),
      300,
    );
  });

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

  testWidgets('formatage conserve focus et selection de Jesus-Christ',
      (tester) async {
    final now = DateTime.now();
    QuillController? controller;
    FocusNode? focusNode;
    final study = PersonalStudy(
      id: 5,
      title: 'Focus',
      blocks: [
        StudyBlock(
          id: 'rich-focus',
          type: StudyBlockType.text,
          position: 0,
          payload: const {
            'format': 'quill_delta_v1',
            'delta': [
              {'insert': 'J\u00e9sus-Christ nous sauve.\n'},
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
      onActiveFocusNode: (value) => focusNode = value,
      saveDocument: (_) async {},
    )));

    focusNode!.requestFocus();
    controller!.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 12),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('rich-bold')));
    await tester.pump();

    expect(focusNode!.hasFocus, isTrue);
    expect(
      controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 12),
    );
    final delta = controller!.document.toDelta().toJson();
    expect(delta.first['insert'], 'J\u00e9sus-Christ');
    expect((delta.first['attributes'] as Map)['bold'], isTrue);

    await tester.tap(find.byKey(const Key('rich-style')));
    await tester.pumpAndSettle();
    expect(focusNode!.hasFocus, isTrue);
    await tester.tap(find.text('Parole forte'));
    await tester.pumpAndSettle();
    expect(focusNode!.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('rich-more')));
    await tester.pumpAndSettle();
    expect(focusNode!.hasFocus, isTrue);
    await tester.tap(find.text('Barr\u00e9'));
    await tester.pumpAndSettle();
    expect(focusNode!.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('insert-study-block')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tapAt(const Offset(8, 100));
    await tester.pumpAndSettle();
    expect(focusNode!.hasFocus, isTrue);
    expect(
      controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 12),
    );
  });

  testWidgets('snackbar temporaire et annulation de suppression',
      (tester) async {
    final now = DateTime.now();
    final study = PersonalStudy(
      id: 6,
      title: 'Suppression',
      blocks: [
        StudyBlock(
          id: 'verse-delete',
          type: StudyBlockType.verse,
          position: 0,
          payload: const {'reference': 'Jean 3:16', 'text': 'Car Dieu...'},
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

    Future<void> deleteVerse() async {
      await tester.longPress(find.text('Verset'));
      await tester.pump();
      await tester.tap(find.byTooltip('Actions du bloc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await deleteVerse();
    expect(find.text('Bloc supprim\u00e9.'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Verset'), findsOneWidget);
    expect(find.text('Bloc supprim\u00e9.'), findsNothing);

    await deleteVerse();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Bloc supprim\u00e9.'), findsNothing);
  });

  testWidgets('suppression puis sortie repetee ne declenche pas de crash',
      (tester) async {
    final now = DateTime.now();
    final study = PersonalStudy(
      id: 7,
      title: 'Navigation',
      blocks: [
        StudyBlock(
          id: 'verse-navigation',
          type: StudyBlockType.verse,
          position: 0,
          payload: const {'reference': 'Jean 3:16', 'text': 'Car Dieu...'},
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalStudyEditorScreen(
                study: study,
                saveDocument: (_) async {},
              ),
            ),
          ),
          child: const Text('Ouvrir editeur'),
        ),
      ),
    )));

    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.tap(find.text('Ouvrir editeur'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Verset'));
      await tester.pump();
      await tester.tap(find.byTooltip('Actions du bloc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pump();
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ouvrir editeur'), findsOneWidget);
      expect(find.text('Bloc supprim\u00e9.'), findsNothing);
    }
  });
}
