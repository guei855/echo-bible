import 'package:echo_bible/features/study/models/study_tool_item.dart';
import 'package:echo_bible/features/study/screens/study_tool_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StudyToolItem item(int id) => StudyToolItem(
        sourceId: id,
        verseId: id,
        bookId: id == 3 ? 24 : 1,
        bookName: id == 3 ? 'Jérémie' : 'Genèse',
        chaptersCount: id == 3 ? 52 : 50,
        chapterNumber: id,
        verseNumber: 1,
        verseText: 'Texte du passage $id.',
        versionId: id == 3 ? 2 : 1,
      );

  late List<StudyToolItem> items;
  late List<int> deleted;
  late List<StudyToolItem> restored;
  late bool cleared;

  setUp(() {
    items = [item(1), item(2), item(3)];
    deleted = [];
    restored = [];
    cleared = false;
  });

  Widget app({ValueChanged<StudyToolItem>? onOpenItem}) => MaterialApp(
        home: StudyToolListScreen(
          type: StudyToolType.history,
          title: 'Historique',
          itemLoader: (_) async => items,
          deleteHistory: (ids) async {
            deleted.addAll(ids);
            items.removeWhere((entry) => ids.contains(entry.sourceId));
          },
          restoreHistory: (entries) async {
            restored.addAll(entries);
            items.insertAll(0, entries);
          },
          clearHistory: () async {
            cleared = true;
            items.clear();
          },
          onOpenItem: onOpenItem,
        ),
      );

  testWidgets('appui long sélectionne puis suppression simple avec Undo',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('history-item-1')));
    await tester.pump();
    expect(find.text('1 sélectionné'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-delete-selected')));
    await tester.pumpAndSettle();

    expect(deleted, [1]);
    expect(find.byKey(const Key('history-item-1')), findsNothing);
    await tester.tap(find.text('ANNULER'));
    await tester.pumpAndSettle();
    expect(restored.single.sourceId, 1);
    expect(find.byKey(const Key('history-item-1')), findsOneWidget);
  });

  testWidgets('sélection multiple et Tout sélectionner suppriment en groupe',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('history-item-1')));
    await tester.tap(find.byKey(const Key('history-item-2')));
    await tester.pump();
    expect(find.text('2 sélectionnés'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-select-all')));
    await tester.pump();
    expect(find.text('3 sélectionnés'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-delete-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(deleted.toSet(), {1, 2, 3});
    expect(find.text('Aucun passage récent pour le moment.'), findsOneWidget);
  });

  testWidgets('Tout effacer demande confirmation et vide immédiatement',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer tout l’historique ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
    expect(find.text('Aucun passage récent pour le moment.'), findsOneWidget);
  });

  testWidgets('un passage conserve version, livre, chapitre et verset',
      (tester) async {
    StudyToolItem? opened;
    await tester.pumpWidget(app(onOpenItem: (item) => opened = item));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-item-3')));
    await tester.pump();

    expect(opened?.bookId, 24);
    expect(opened?.chapterNumber, 3);
    expect(opened?.verseNumber, 1);
    expect(opened?.versionId, 2);
  });
}
