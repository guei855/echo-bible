import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:echo_bible/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Construit l'application et déclenche une première image.
    await tester.pumpWidget(const EchoBibleApp());

    // Vérifie que l'application démarre bien
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
