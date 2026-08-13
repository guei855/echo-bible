import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('affiche Télécharger pour les trois Bibles publiées',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloadManagerScreen(
          initialCategory: ResourceCategory.bible,
          initialLanguage: ResourceLanguage.fr,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    for (final name in [
      'Bible J.N. Darby',
      'Bible Ostervald',
      'Sainte Bible néo-Crampon Libre',
    ]) {
      if (find.text(name).evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
      }
      final card = find.ancestor(
        of: find.text(name),
        matching: find.byType(Card),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Télécharger')),
        findsOneWidget,
      );
    }
  });
}
