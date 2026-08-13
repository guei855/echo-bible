import 'package:echo_bible/features/study/screens/cross_references_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('affiche le contexte, les textes français et la pagination',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CrossReferencesScreen(
          sourceBook: 43,
          sourceBookName: 'Jean',
          sourceChapter: 3,
          sourceVerse: 16,
          sourceVersionId: 1,
        ),
      ),
    );
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.text('Jean 3:16').evaluate().isNotEmpty) break;
    }

    expect(find.text('Références croisées'), findsOneWidget);
    expect(find.text('Jean 3:16'), findsOneWidget);
    expect(find.text('23 passages liés'), findsOneWidget);
    expect(find.textContaining('OpenBible.info'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Afficher plus'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Afficher plus'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    expect(find.byType(Chip), findsNothing);
  });
}
