import 'package:echo_bible/features/bible/models/text_marking.dart';
import 'package:echo_bible/features/bible/widgets/annotated_selectable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combine un surlignage et un soulignage qui se chevauchent', () {
    final widget = AnnotatedSelectableText(
      text: 'Au commencement',
      style: const TextStyle(),
      markings: [
        TextMarking(
          bookId: 1,
          chapter: 1,
          verseNumber: 1,
          versionId: 1,
          startOffset: 3,
          endOffset: 15,
          selectedText: 'commencement',
          type: TextMarkingType.highlight,
          color: 'yellow',
          createdAt: DateTime(2026),
        ),
        TextMarking(
          bookId: 1,
          chapter: 1,
          verseNumber: 1,
          versionId: 1,
          startOffset: 6,
          endOffset: 15,
          selectedText: 'mencement',
          type: TextMarkingType.underline,
          color: 'blue',
          createdAt: DateTime(2026, 1, 2),
        ),
      ],
      resolveColor: (key, {required background}) =>
          background ? Colors.yellow : Colors.blue,
    );

    final spans = widget.buildMarkedSpans().cast<TextSpan>();
    expect(spans.map((span) => span.text).join(), 'Au commencement');
    final overlap = spans.firstWhere((span) => span.text == 'mencement');
    expect(overlap.style?.backgroundColor, Colors.yellow);
    expect(overlap.style?.decoration, TextDecoration.underline);
    expect(overlap.style?.decorationColor, Colors.blue);
  });

  test('conserve le texte exact et les offsets dans la persistance', () {
    final marking = TextMarking(
      bookId: 1,
      chapter: 1,
      verseNumber: 1,
      versionId: 3,
      startOffset: 3,
      endOffset: 15,
      selectedText: 'commencement',
      type: TextMarkingType.highlight,
      color: 'orange',
      createdAt: DateTime.utc(2026),
    );
    final restored = TextMarking.fromMap({'id': 4, ...marking.toMap()});
    expect(restored.startOffset, 3);
    expect(restored.endOffset, 15);
    expect(restored.selectedText, 'commencement');
    expect(restored.versionId, 3);
  });
}
