import 'dart:async';

import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/widgets/verse_study_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _genesis = BibleBook(
  id: 1,
  name: 'Genèse',
  abbreviation: 'Gn',
  testament: 'Ancien Testament',
  chaptersCount: 50,
);

const _versions = [
  BibleVersion(
    id: 1,
    code: 'lsg',
    name: 'Louis Segond 1910',
    abbreviation: 'LSG',
    language: 'fr',
    copyright: 'Domaine public',
    isDefault: true,
  ),
  BibleVersion(
    id: 2,
    code: 'darby',
    name: 'Darby',
    abbreviation: 'DARBY',
    language: 'fr',
    copyright: 'Domaine public',
    isDefault: false,
  ),
  BibleVersion(
    id: 3,
    code: 'ost',
    name: 'Ostervald',
    abbreviation: 'OST',
    language: 'fr',
    copyright: 'Domaine public',
    isDefault: false,
  ),
  BibleVersion(
    id: 4,
    code: 'ncl',
    name: 'Néo-Crampon',
    abbreviation: 'NCL',
    language: 'fr',
    copyright: 'CC BY-SA 4.0',
    isDefault: false,
  ),
];

List<VerseStudyTarget> _targets(int chapter, int start, int end) => [
      for (var verse = start; verse <= end; verse++)
        VerseStudyTarget(
          verseId: chapter * 100 + verse,
          verseNumber: verse,
          verseText: 'Texte Genèse $chapter:$verse',
        ),
    ];

CrossReference _reference(int sourceVerse) => CrossReference(
      bookId: 1,
      bookName: 'Genèse',
      chaptersCount: 50,
      chapter: 1,
      verseStart: sourceVerse,
      verseEnd: sourceVerse,
      text: 'Références chargées pour 8:$sourceVerse',
      sourceDataset: 'test',
      requestedVersionId: 1,
    );

class _EmptyNaveRepository extends NaveRepository {
  const _EmptyNaveRepository();

  @override
  Future<List<NaveTopic>> forVerse(
    int bookId,
    int chapter,
    int verse, {
    int limit = 100,
    AppLanguage? language,
  }) async =>
      const [];
}

Widget _sheet({
  int chapter = 8,
  int initialVerse = 1,
  List<VerseStudyTarget>? verses,
  StudyCrossReferenceLoader? references,
  StudyChapterLoader? chapters,
  String? selectedText,
  NaveRepository naveRepository = const NaveRepository(),
}) =>
    MaterialApp(
      home: Scaffold(
        body: VerseStudySheet(
          book: _genesis,
          chapter: chapter,
          versionId: 1,
          verses: verses ?? _targets(chapter, 1, 4),
          initialVerseNumber: initialVerse,
          selectedText: selectedText,
          loadStudy: (_) async => const VerseStudyData(
            strongWords: [],
            crossReferences: [],
          ),
          loadReferences: references ??
              (book, chapter, verse, version) async => [_reference(verse)],
          loadChapter: chapters,
          comparisonVersionLoader: () async => _versions,
          comparisonChapterLoader: (versionId) async => [
            for (var verse = 1; verse <= 22; verse++)
              {
                'verse_number': verse,
                'text': '${_versions[versionId - 1].abbreviation} 8:$verse',
                'uses_default_text': 0,
              },
          ],
          naveRepository: naveRepository,
        ),
      ),
    );

Future<void> _chooseTool(WidgetTester tester, String name) async {
  final tool = find.byKey(Key('study-tool-$name'));
  await tester.ensureVisible(tool);
  await tester.pump();
  await tester.tap(tool);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('références et comparaison suivent 8:1, 8:2 puis 8:3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(
      _sheet(
        references: (book, chapter, verse, version) async {
          calls.add('$chapter:$verse');
          return [_reference(verse)];
        },
      ),
    );
    await tester.pump();

    await _chooseTool(tester, 'references');
    expect(find.text('Références chargées pour 8:1'), findsOneWidget);
    await tester.tap(find.text('Verset suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Genèse 8:2'), findsOneWidget);
    expect(find.text('Références chargées pour 8:2'), findsOneWidget);
    await tester.tap(find.text('Verset suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Genèse 8:3'), findsOneWidget);
    expect(find.text('Références chargées pour 8:3'), findsOneWidget);
    expect(calls, ['8:1', '8:2', '8:3']);

    await _chooseTool(tester, 'compare');
    for (final version in _versions) {
      expect(
        find.textContaining('${version.abbreviation} 8:3'),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Verset précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Genèse 8:2'), findsOneWidget);
    for (final version in _versions) {
      expect(
        find.textContaining('${version.abbreviation} 8:2'),
        findsOneWidget,
      );
    }

    await _chooseTool(tester, 'references');
    expect(find.text('Références chargées pour 8:2'), findsOneWidget);
  });

  testWidgets('une ancienne réponse de références ne remplace jamais 8:4', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = <int, Completer<List<CrossReference>>>{};
    await tester.pumpWidget(
      _sheet(
        references: (_, __, verse, ___) {
          return (pending[verse] ??= Completer<List<CrossReference>>()).future;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('study-tool-references')));
    await tester.pump();
    for (var verse = 2; verse <= 4; verse++) {
      await tester.tap(find.text('Verset suivant'));
      await tester.pump();
    }
    pending[4]!.complete([_reference(4)]);
    await tester.pump();
    expect(find.text('Références chargées pour 8:4'), findsOneWidget);
    for (final verse in [3, 2, 1]) {
      pending[verse]!.complete([_reference(verse)]);
      await tester.pump();
    }
    expect(find.text('Genèse 8:4'), findsOneWidget);
    expect(find.text('Références chargées pour 8:4'), findsOneWidget);
    expect(find.text('Références chargées pour 8:1'), findsNothing);
  });

  testWidgets('navigation 8:22 vers 9:1 et retour utilise les vrais chapitres',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _sheet(
        initialVerse: 22,
        verses: _targets(8, 22, 22),
        chapters: (_, chapter, __) async =>
            chapter == 9 ? _targets(9, 1, 2) : _targets(8, 1, 22),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Verset suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Genèse 9:1'), findsOneWidget);
    await tester.tap(find.text('Verset précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Genèse 8:22'), findsOneWidget);
  });

  testWidgets('les limites Genèse 1:1 et Apocalypse 22:21 sont désactivées', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sheet(chapter: 1, verses: _targets(1, 1, 1)),
    );
    await tester.pump();
    final previous = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Verset précédent'),
    );
    expect(previous.onPressed, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseStudySheet(
            key: const ValueKey('revelation-boundary'),
            book: BibleBook(
              id: 66,
              name: 'Apocalypse',
              abbreviation: 'Ap',
              testament: 'Nouveau Testament',
              chaptersCount: 22,
            ),
            chapter: 22,
            versionId: 1,
            verses: const [
              VerseStudyTarget(
                verseId: 999,
                verseNumber: 21,
                verseText: 'Amen.',
              ),
            ],
            initialVerseNumber: 21,
            loadStudy: (_) async => const VerseStudyData(
              strongWords: [],
              crossReferences: [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final next = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Verset suivant'),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('une sélection de mot lance une recherche Nave préremplie',
      (tester) async {
    await tester.pumpWidget(
      _sheet(
        selectedText: 'grâce',
        naveRepository: const _EmptyNaveRepository(),
      ),
    );
    await tester.pump();
    await _chooseTool(tester, 'topics');
    final action = find.text('Rechercher « grâce » dans Nave');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'grâce');
  });
}
