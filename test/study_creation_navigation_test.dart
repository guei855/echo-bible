import 'dart:async';

import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_studies_screen.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:echo_bible/features/study/widgets/study_creation_sheet.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home, {ThemeMode themeMode = ThemeMode.light}) =>
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB)),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF2563EB),
        ),
        themeMode: themeMode,
        home: home,
      );

  PersonalStudy study({
    required int id,
    required String title,
    StudyDocumentType type = StudyDocumentType.free,
    List<StudyBlock> blocks = const [],
    bool pinned = false,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime(2026, 8, 14, 10);
    return PersonalStudy(
      id: id,
      title: title,
      type: type,
      blocks: blocks,
      isPinned: pinned,
      createdAt: now,
      updatedAt: now,
    );
  }

  StudyBlock verse(String id, String reference) {
    final now = DateTime(2026, 8, 14, 10);
    return StudyBlock(
      id: id,
      type: StudyBlockType.verse,
      position: 0,
      payload: {'reference': reference, 'text': '4 Ainsi parle le Seigneur.'},
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('Mes études crée puis ouvre immédiatement l’éditeur',
      (tester) async {
    final created = study(
      id: 21,
      title: 'Étude de Jean 3',
      type: StudyDocumentType.bibleStudy,
    );
    var focused = false;
    var loads = 0;
    var visibleStudies = <PersonalStudy>[];
    await tester.pumpWidget(app(PersonalStudiesScreen(
      loadStudies: ({String query = ''}) async {
        loads++;
        return visibleStudies;
      },
      launchCreation: (_) async => created,
      editorBuilder: (value, focusOnOpen) {
        focused = focusOnOpen;
        return Builder(
          builder: (editorContext) => Scaffold(
            appBar: AppBar(),
            body: Column(
              children: [
                Text('Éditeur : ${value.title}'),
                FilledButton(
                  onPressed: () {
                    visibleStudies = [
                      value.copyWith(
                        title: 'Étude de Jean 3 actualisée',
                        blocks: [verse('jean-3', 'Jean 3:16')],
                        updatedAt: DateTime(2026, 8, 14, 12),
                      ),
                    ];
                    Navigator.pop(editorContext);
                  },
                  child: const Text('Terminer l’édition'),
                ),
              ],
            ),
          ),
        );
      },
    )));

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-study')));
    await tester.pumpAndSettle();

    expect(find.text('Éditeur : Étude de Jean 3'), findsOneWidget);
    expect(focused, isTrue);
    await tester.tap(find.text('Terminer l’édition'));
    await tester.pumpAndSettle();
    expect(loads, greaterThanOrEqualTo(2));
    expect(find.text('Étude de Jean 3 actualisée'), findsOneWidget);
    expect(find.textContaining('Jean 3:16'), findsOneWidget);
  });

  testWidgets('sélecteur moderne valide type, titre et référence',
      (tester) async {
    final block = verse('jeremie-26-4', 'Jérémie 26:4');
    StudyCreationRequest? request;
    PersonalStudy? result;
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            result = await StudyCreationSheet.show(
              context,
              initialBlock: block,
              primaryReference: 'Jérémie 26:4',
              createStudy: (value) async {
                request = value;
                return study(
                  id: 22,
                  title: value.title,
                  type: value.type,
                  blocks: [block],
                );
              },
            );
          },
          child: const Text('Créer'),
        ),
      ),
    )));

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(find.text('Créer une nouvelle étude'), findsOneWidget);
    expect(
        find.byType(DropdownButtonFormField<StudyDocumentType>), findsNothing);
    expect(find.byKey(const Key('create-study')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-study')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('study-type-bibleStudy')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('new-study-title')));
    await tester.pump();
    expect(find.text('Référence de départ'), findsOneWidget);
    expect(find.text('Jérémie 26:4'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('new-study-title')),
      'Étude de Jérémie 26',
    );
    await tester.ensureVisible(find.byKey(const Key('create-study')));
    await tester.tap(find.byKey(const Key('create-study')));
    await tester.pumpAndSettle();

    expect(result?.title, 'Étude de Jérémie 26');
    expect(request?.type, StudyDocumentType.bibleStudy);
    expect(request?.initialBlock?.id, 'jeremie-26-4');
    expect(request?.primaryReference, 'Jérémie 26:4');
  });

  testWidgets('étude existante reçoit le verset puis ouvre le bon éditeur',
      (tester) async {
    final block = verse('jeremie-reader', 'Jérémie 26:4');
    final destination = study(
      id: 23,
      title: 'Test',
      type: StudyDocumentType.sermon,
    );
    PersonalStudy? saved;
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            final selected = await StudyDestinationSheet.show(
              context,
              block,
              reference: 'Jérémie 26:4',
              loadStudies: () async => [destination],
              saveStudy: (value) async => saved = value,
              loadStudy: (_) async => saved,
            );
            if (context.mounted && selected != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonalStudyEditorScreen(
                    study: selected,
                    openingBlockId: block.id,
                    openingMessage: 'Jérémie 26:4 ajouté.',
                    saveDocument: (_) async {},
                  ),
                ),
              );
            }
          },
          child: const Text('Ajouter'),
        ),
      ),
    )));

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez où intégrer Jérémie 26:4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('study-destination-23')));
    await tester.pumpAndSettle();

    expect(saved?.blocks.single.id, 'jeremie-reader');
    expect(find.byKey(const Key('study-title')), findsOneWidget);
    expect(find.textContaining('Jérémie 26:4'), findsWidgets);
    expect(
      find.byKey(const ValueKey('jeremie-reader')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('nouvelle prédication depuis Bible inclut Jean 3:16',
      (tester) async {
    final block = verse('jean-reader', 'Jean 3:16');
    StudyCreationRequest? request;
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            final selected = await StudyDestinationSheet.show(
              context,
              block,
              reference: 'Jean 3:16',
              loadStudies: () async => const [],
              saveStudy: (_) async {},
              loadStudy: (_) async => null,
              createStudy: (value) async {
                request = value;
                return study(
                  id: 24,
                  title: value.title,
                  type: value.type,
                  blocks: [block],
                );
              },
            );
            if (context.mounted && selected != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: Text('${selected.title}|${selected.content}'),
                  ),
                ),
              );
            }
          },
          child: const Text('Ajouter depuis Bible'),
        ),
      ),
    )));

    await tester.tap(find.text('Ajouter depuis Bible'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-study-destination')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('study-type-sermon')));
    await tester.tap(find.byKey(const Key('study-type-sermon')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('new-study-title')));
    await tester.enterText(
      find.byKey(const Key('new-study-title')),
      'L’amour de Dieu',
    );
    await tester.ensureVisible(find.byKey(const Key('create-study')));
    await tester.tap(find.byKey(const Key('create-study')));
    await tester.pumpAndSettle();

    expect(find.textContaining('L’amour de Dieu|'), findsOneWidget);
    expect(find.textContaining('Jean 3:16'), findsOneWidget);
    expect(request?.type, StudyDocumentType.sermon);
    expect(request?.initialBlock?.id, 'jean-reader');
  });

  testWidgets('recherche, tri épinglé et mode sombre restent lisibles',
      (tester) async {
    final now = DateTime(2026, 8, 14, 10);
    final studies = [
      study(id: 30, title: 'Ancienne', updatedAt: now),
      study(
        id: 31,
        title: 'Message du dimanche',
        type: StudyDocumentType.sermon,
        updatedAt: now.add(const Duration(hours: 1)),
      ),
      study(id: 32, title: 'Épinglée', pinned: true, updatedAt: now),
      for (var index = 0; index < 5; index++)
        study(id: 40 + index, title: 'Étude $index', updatedAt: now),
    ];
    await tester.pumpWidget(app(
      Scaffold(
        body: StudyDestinationSheet(
          block: verse('search-block', 'Jean 3:16'),
          reference: 'Jean 3:16',
          loadStudies: () async => studies,
          saveStudy: (_) async {},
          loadStudy: (_) async => null,
        ),
      ),
      themeMode: ThemeMode.dark,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('study-destination-search')), findsOneWidget);
    final pinnedY =
        tester.getTopLeft(find.byKey(const Key('study-destination-32'))).dy;
    final recentY =
        tester.getTopLeft(find.byKey(const Key('study-destination-31'))).dy;
    expect(pinnedY, lessThan(recentY));

    await tester.enterText(
      find.byKey(const Key('study-destination-search')),
      'Prédication',
    );
    await tester.pump();
    expect(find.text('Message du dimanche'), findsOneWidget);
    expect(find.text('Ancienne'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap ne sauvegarde le passage qu’une fois',
      (tester) async {
    final destination = study(id: 50, title: 'Double tap');
    final completer = Completer<void>();
    var saveCount = 0;
    await tester.pumpWidget(app(Scaffold(
      body: StudyDestinationSheet(
        block: verse('double-tap-block', 'Jean 3:16'),
        reference: 'Jean 3:16',
        loadStudies: () async => [destination],
        saveStudy: (_) {
          saveCount++;
          return completer.future;
        },
        loadStudy: (_) async => destination,
      ),
    )));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('study-destination-50'));
    await tester.tap(card);
    await tester.tap(card, warnIfMissed: false);
    await tester.pump();
    expect(saveCount, 1);
    completer.complete();
    await tester.pumpAndSettle();
    expect(saveCount, 1);
  });

  testWidgets('échec SQLite reste dans la sheet et permet de réessayer',
      (tester) async {
    final destination = study(id: 51, title: 'Erreur insertion');
    var attempts = 0;
    await tester.pumpWidget(app(Scaffold(
      body: StudyDestinationSheet(
        block: verse('failed-block', 'Jean 3:16'),
        reference: 'Jean 3:16',
        loadStudies: () async => [destination],
        saveStudy: (_) async {
          attempts++;
          throw StateError('SQLite indisponible');
        },
        loadStudy: (_) async => null,
      ),
    )));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('study-destination-51'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible d’ajouter ce passage à l’étude.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('study-destination-51')), findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('dix cycles de sheets ne doublent aucune route', (tester) async {
    final block = verse('navigation-block', 'Jean 3:16');
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => StudyDestinationSheet.show(
            context,
            block,
            reference: 'Jean 3:16',
            loadStudies: () async => const [],
            saveStudy: (_) async {},
            loadStudy: (_) async => null,
          ),
          child: const Text('Ouvrir le choix'),
        ),
      ),
    )));

    for (var cycle = 0; cycle < 10; cycle++) {
      await tester.tap(find.text('Ouvrir le choix'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-study-destination')));
      await tester.pumpAndSettle();
      expect(find.text('Créer une nouvelle étude'), findsOneWidget);
      await tester.tapAt(const Offset(8, 80));
      await tester.pumpAndSettle();
      expect(find.text('Ouvrir le choix'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
