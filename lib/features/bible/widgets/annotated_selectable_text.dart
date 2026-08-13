import 'package:echo_bible/features/bible/models/text_marking.dart';
import 'package:flutter/material.dart';

class AnnotatedSelectableText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<TextMarking> markings;
  final Color Function(String colorKey, {required bool background})
      resolveColor;
  final ValueChanged<TextSelection>? onSelectionChanged;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  const AnnotatedSelectableText({
    super.key,
    required this.text,
    required this.style,
    required this.markings,
    required this.resolveColor,
    this.onSelectionChanged,
    this.contextMenuBuilder,
  });

  @override
  Widget build(BuildContext context) => SelectableText.rich(
        TextSpan(children: buildMarkedSpans()),
        style: style,
        onSelectionChanged: (selection, _) =>
            onSelectionChanged?.call(selection),
        contextMenuBuilder: contextMenuBuilder,
      );

  @visibleForTesting
  List<InlineSpan> buildMarkedSpans() {
    if (text.isEmpty || markings.isEmpty) return [TextSpan(text: text)];
    final boundaries = <int>{0, text.length};
    for (final marking in markings) {
      boundaries
        ..add((marking.startOffset ?? 0).clamp(0, text.length))
        ..add((marking.endOffset ?? text.length).clamp(0, text.length));
    }
    final offsets = boundaries.toList()..sort();
    final spans = <InlineSpan>[];
    for (var index = 0; index < offsets.length - 1; index++) {
      final start = offsets[index];
      final end = offsets[index + 1];
      if (start == end) continue;
      final active = markings.where((marking) {
        final markingStart = marking.startOffset ?? 0;
        final markingEnd = marking.endOffset ?? text.length;
        return markingStart < end && markingEnd > start;
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final highlights = active
          .where((marking) => marking.type == TextMarkingType.highlight)
          .toList();
      final underlines = active
          .where((marking) => marking.type == TextMarkingType.underline)
          .toList();
      final highlight = highlights.isEmpty ? null : highlights.last;
      final underline = underlines.isEmpty ? null : underlines.last;
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: TextStyle(
          backgroundColor: highlight == null
              ? null
              : resolveColor(highlight.color, background: true),
          decoration: underline == null ? null : TextDecoration.underline,
          decorationColor: underline == null
              ? null
              : resolveColor(underline.color, background: false),
          decorationThickness: underline == null ? null : 2,
        ),
      ));
    }
    return spans;
  }
}
