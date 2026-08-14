import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/study/screens/study_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('carte Lexique installée affiche Disponible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StudyHubScreen(
        loadStrongState: () async => OfflineResourceState.installed,
      ),
    ));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final badge = tester.widget<Text>(
      find.byKey(const Key('study-Lexique-badge')),
    );
    expect(badge.data, 'Disponible');
  });

  testWidgets('carte Lexique absente affiche Télécharger', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StudyHubScreen(
        loadStrongState: () async => OfflineResourceState.notInstalled,
      ),
    ));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final badge = tester.widget<Text>(
      find.byKey(const Key('study-Lexique-badge')),
    );
    expect(badge.data, 'Télécharger');
  });
}
