class Verse {
  final int id;
  final int bookId;
  final int chapterNumber;
  final int verseNumber;
  final String text;
  bool isFavorite;
  String? highlightColor;
  String? note;

  Verse({
    required this.id,
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    required this.text,
    this.isFavorite = false,
    this.highlightColor,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_number': chapterNumber,
      'verse_number': verseNumber,
      'text': text,
      'is_favorite': isFavorite ? 1 : 0,
      'highlight_color': highlightColor,
      'note': note,
    };
  }

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] ?? 0,
      bookId: map['book_id'] ?? 0,
      chapterNumber: map['chapter_number'] ?? 0,
      verseNumber: map['verse_number'] ?? 0,
      text: map['text'] ?? '',
      isFavorite: map['is_favorite'] == 1,
      highlightColor: map['highlight_color'],
      note: map['note'],
    );
  }
}
