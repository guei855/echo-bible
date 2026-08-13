import 'package:echo_bible/features/search/widgets/highlighted_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hérite une couleur lisible et surligne le terme recherché', (
    tester,
  ) async {
    const inheritedColor = Color(0xFF263238);

    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTextStyle(
          style: TextStyle(color: inheritedColor),
          child: HighlightedText(
            text: "Dieu est amour et l'amour demeure.",
            query: 'amour',
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    final rootSpan = richText.text as TextSpan;
    expect(rootSpan.style?.color, inheritedColor);
    expect(
      rootSpan.children!.whereType<TextSpan>().where(
            (span) => span.text?.toLowerCase() == 'amour',
          ),
      hasLength(2),
    );
  });
}
