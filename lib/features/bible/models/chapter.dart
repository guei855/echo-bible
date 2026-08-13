class Chapter {
  final int bookId;
  final int chapterNumber;

  Chapter({
    required this.bookId,
    required this.chapterNumber,
  });

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      bookId: map['book_id'] as int,
      chapterNumber: map['chapter_number'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'chapter_number': chapterNumber,
    };
  }
}
