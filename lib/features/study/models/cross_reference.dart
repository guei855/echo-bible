class CrossReference {
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String text;
  final int? score;
  final String sourceDataset;
  final int requestedVersionId;
  final bool usedLsgFallback;

  const CrossReference({
    required this.bookId,
    required this.bookName,
    required this.chaptersCount,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.text,
    required this.sourceDataset,
    required this.requestedVersionId,
    this.usedLsgFallback = false,
    this.score,
  });

  String get verseLabel =>
      verseEnd == verseStart ? '$verseStart' : '$verseStart-$verseEnd';
}
