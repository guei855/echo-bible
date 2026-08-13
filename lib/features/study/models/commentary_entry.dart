class CommentaryEntry {
  final int id;
  final String author;
  final String workTitle;
  final String source;
  final String content;
  final String? license;

  const CommentaryEntry({
    required this.id,
    required this.author,
    required this.workTitle,
    required this.source,
    required this.content,
    this.license,
  });

  factory CommentaryEntry.fromMap(Map<String, Object?> map) => CommentaryEntry(
        id: map['id'] as int,
        author: map['author'] as String,
        workTitle: map['work_title'] as String,
        source: map['source'] as String,
        content: map['content'] as String,
        license: map['license'] as String?,
      );
}
