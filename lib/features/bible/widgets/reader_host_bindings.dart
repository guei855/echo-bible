import 'package:echo_bible/features/bible/widgets/book_chapter_selector_sheet.dart';
import 'package:flutter/widgets.dart';

class ReaderHostBindings extends InheritedWidget {
  final int? initialVersionId;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onVersionChanged;
  final ValueChanged<BookChapterSelection> onPassageChanged;

  const ReaderHostBindings({
    super.key,
    required this.initialVersionId,
    required this.onChapterChanged,
    required this.onVersionChanged,
    required this.onPassageChanged,
    required super.child,
  });

  static ReaderHostBindings? maybeRead(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<ReaderHostBindings>();
    return element?.widget as ReaderHostBindings?;
  }

  @override
  bool updateShouldNotify(ReaderHostBindings oldWidget) =>
      initialVersionId != oldWidget.initialVersionId;
}
