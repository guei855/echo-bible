class NaveTopic {
  final int id;
  final String title;
  final String titleEnglish;
  final String? translationStatus;
  final int sectionCount;
  final int referenceCount;

  const NaveTopic({
    required this.id,
    required this.title,
    required this.titleEnglish,
    this.translationStatus,
    this.sectionCount = 0,
    this.referenceCount = 0,
  });

  bool get isTranslated => title != titleEnglish;
}

class NaveReference {
  final int id;
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
  final String? verseText;
  final int? versionId;
  final String? versionAbbreviation;
  final bool usesDefaultText;
  const NaveReference(
      {this.id = 0,
      required this.subtopicId,
      required this.subtopic,
      required this.subtopicEnglish,
      this.translationStatus,
      required this.bookId,
      required this.bookName,
      required this.chaptersCount,
      required this.chapter,
      required this.verseStart,
      this.verseEnd,
      this.verseText,
      this.versionId,
      this.versionAbbreviation,
      this.usesDefaultText = false});

  String get referenceLabel =>
      '$bookName $chapter:$verseStart${verseEnd == null ? '' : '-$verseEnd'}';
}
