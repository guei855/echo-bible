import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lsg = BibleVersion(
  id: 1,
  code: 'lsg1910',
  name: 'Louis Segond 1910',
  abbreviation: 'LSG',
  language: 'fr',
  copyright: 'Domaine public',
  isDefault: true,
);
const _darby = BibleVersion(
  id: 2,
  code: 'darby',
  name: 'Darby',
  abbreviation: 'DARBY',
  language: 'fr',
  copyright: 'Domaine public',
  isDefault: false,
);

List<Map<String, Object?>> _chapter(int versionId) => [
      for (var verse = 1; verse <= 18; verse++)
        {
          'verse_number': verse,
          'text': 'Texte $versionId du verset $verse',
          'uses_default_text': 0,
        },
    ];

Widget _host({
  required List<BibleVersion> versions,
  int start = 16,
  int end = 16,
  ThemeMode themeMode = ThemeMode.light,
}) =>
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: PassageComparisonView(
          bookId: 43,
          chapter: 3,
          verseStart: start,
          verseEnd: end,
          versionLoader: () async => versions,
          chapterLoader: (id) async => _chapter(id),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('compare Jean 3:16 avec plusieurs versions sur petit écran',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(versions: const [_lsg, _darby]));
    await tester.pumpAndSettle();

    expect(find.text('LSG — Louis Segond 1910'), findsOneWidget);
    expect(find.text('DARBY — Darby'), findsOneWidget);
    expect(find.textContaining('Texte 1 du verset 16'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserve toute la plage Jean 3:16-18', (tester) async {
    await tester.pumpWidget(
      _host(versions: const [_lsg, _darby], start: 16, end: 18),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Texte 1 du verset 16'), findsOneWidget);
    expect(find.textContaining('Texte 1 du verset 18'), findsOneWidget);
    expect(find.textContaining('Texte 1 du verset 15'), findsNothing);
  });

  testWidgets('gère une seule version installée en mode sombre',
      (tester) async {
    await tester.pumpWidget(
      _host(versions: const [_lsg], themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 version(s) comparée(s)'), findsOneWidget);
    expect(find.text('LSG — Louis Segond 1910'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une version absente ne provoque pas de crash', (tester) async {
    SharedPreferences.setMockInitialValues({
      'comparison_preferred_version_ids': ['999'],
    });
    await tester.pumpWidget(_host(versions: const [_lsg]));
    await tester.pumpAndSettle();

    expect(find.text('LSG — Louis Segond 1910'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('affiche les cartes côte à côte sur grand écran', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(versions: const [_lsg, _darby]));
    await tester.pumpAndSettle();

    final lsg = tester.getTopLeft(find.text('LSG — Louis Segond 1910'));
    final darby = tester.getTopLeft(find.text('DARBY — Darby'));
    expect((lsg.dy - darby.dy).abs(), lessThan(4));
  });
}
