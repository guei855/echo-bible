enum TextMarkingType { highlight, underline }

class TextMarking {
  final int? id;
  final int bookId;
  final int chapter;
  final int verseNumber;
  final int versionId;
  final int? startOffset;
  final int? endOffset;
  final String? selectedText;
  final TextMarkingType type;
  final String color;
  final DateTime createdAt;

  const TextMarking({
    this.id,
    required this.bookId,
    required this.chapter,
    required this.verseNumber,
    required this.versionId,
    this.startOffset,
    this.endOffset,
    this.selectedText,
    required this.type,
    required this.color,
    required this.createdAt,
  });

  bool get isWholeVerse => startOffset == null || endOffset == null;

  factory TextMarking.fromMap(Map<String, Object?> map) => TextMarking(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        chapter: map['chapter'] as int,
        verseNumber: map['verse_number'] as int,
        versionId: map['version_id'] as int? ?? 1,
        startOffset: map['start_offset'] as int?,
        endOffset: map['end_offset'] as int?,
        selectedText: map['selected_text'] as String?,
        type: TextMarkingType.values.byName(map['marking_type'] as String),
        color: map['color'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'book_id': bookId,
        'chapter': chapter,
        'verse_number': verseNumber,
        'version_id': versionId,
        'start_offset': startOffset,
        'end_offset': endOffset,
        'selected_text': selectedText,
        'marking_type': type.name,
        'color': color,
        'created_at': createdAt.toIso8601String(),
      };
}
