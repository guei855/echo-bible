class Verse {
  final int number;
  final String text;
  bool isBookmarked;
  bool isHighlighted;

  Verse({
    required this.number,
    required this.text,
    this.isBookmarked = false,
    this.isHighlighted = false,
  });
}
