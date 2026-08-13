class NaveTopic {
  final int id;
  final String title;
  const NaveTopic({required this.id, required this.title});
}

class NaveReference {
  final int subtopicId;
  final String subtopic;
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapter;
  final int verseStart;
  final int? verseEnd;
  const NaveReference(
      {required this.subtopicId,
      required this.subtopic,
      required this.bookId,
      required this.bookName,
      required this.chaptersCount,
      required this.chapter,
      required this.verseStart,
      this.verseEnd});
}
