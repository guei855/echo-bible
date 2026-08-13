class NaveTopic {
  final int id;
  final String title;
  final String titleEnglish;
  final String? translationStatus;

  const NaveTopic({
    required this.id,
    required this.title,
    required this.titleEnglish,
    this.translationStatus,
  });

  bool get isTranslated => title != titleEnglish;
}

class NaveReference {
  final int subtopicId;
  final String subtopic;
  final String subtopicEnglish;
  final String? translationStatus;
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapter;
  final int verseStart;
  final int? verseEnd;
  const NaveReference(
      {required this.subtopicId,
      required this.subtopic,
      required this.subtopicEnglish,
      this.translationStatus,
      required this.bookId,
      required this.bookName,
      required this.chaptersCount,
      required this.chapter,
      required this.verseStart,
      this.verseEnd});
}
