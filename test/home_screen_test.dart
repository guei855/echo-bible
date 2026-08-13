import 'package:echo_bible/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('l’accueil ne contient plus la grille Accès rapide', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('Accès rapide'), findsNothing);
    expect(find.text('Audio Bible'), findsNothing);
    expect(find.text('IA Assistant'), findsNothing);
    expect(find.text('Application 100% gratuite'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
