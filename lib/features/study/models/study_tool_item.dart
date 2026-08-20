enum StudyToolType { notes, highlights, bookmarks, history }

class StudyToolItem {
  final int? sourceId;
  final int verseId;
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapterNumber;
  final int verseNumber;
  final String verseText;
  final String? title;
  final String? detail;
  final String? color;
  final String? date;
  final int versionId;

  const StudyToolItem({
    this.sourceId,
    required this.verseId,
    required this.bookId,
    required this.bookName,
    required this.chaptersCount,
    required this.chapterNumber,
    required this.verseNumber,
    required this.verseText,
    this.title,
    this.detail,
    this.color,
    this.date,
    this.versionId = 1,
  });
}

class StudyToolsSummary {
  final int notes;
  final int highlights;
  final int bookmarks;
  final int tags;
  final int links;
  final int studies;
  final int history;

  const StudyToolsSummary({
    required this.notes,
    required this.highlights,
    required this.bookmarks,
    required this.tags,
    required this.links,
    required this.studies,
    required this.history,
  });
}
