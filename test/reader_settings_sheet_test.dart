import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/widgets/reader_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ne déborde pas sur un écran de téléphone étroit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSettingsSheet(
            initialFontSize: 16,
            initialFontFamily: 'Roboto',
            initialDarkMode: false,
            onSettingsChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coucher de soleil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applique une palette lisible à tous les réglages en mode sombre',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSettingsSheet(
            initialFontSize: 18,
            initialFontFamily: 'Roboto',
            initialDarkMode: true,
            onSettingsChanged: () {},
          ),
        ),
      ),
    );

    for (final label in [
      'Paramètres de lecture',
      'Taille du texte',
      '18',
      'Police',
      'Interligne',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, AppColors.textPrimaryDark);
    }

    for (final theme in [
      'Clair',
      'Sépia',
      'Nature',
      'Coucher de soleil',
      'Sombre',
      'Noir',
      'Mauve',
      'Nuit',
    ]) {
      expect(find.text(theme), findsOneWidget);
    }

    final sheetContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = sheetContainer.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF1B1D21));

    await tester.ensureVisible(find.text('Roboto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roboto'));
    await tester.pumpAndSettle();
    final lora = tester.widgetList<Text>(find.text('Lora')).last;
    expect(lora.style?.color, AppColors.textPrimaryDark);
  });
}
