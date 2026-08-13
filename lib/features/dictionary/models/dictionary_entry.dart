class DictionaryEntry {
  final int id;
  final String title;
  final String content;
  final String source;
  final String? author;
  final String? relatedReferences;

  const DictionaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    this.author,
    this.relatedReferences,
  });

  factory DictionaryEntry.fromMap(Map<String, Object?> map) => DictionaryEntry(
        id: map['id'] as int,
        title: map['title'] as String,
        content: map['content'] as String,
        source: map['source'] as String,
        author: map['author'] as String?,
        relatedReferences: map['related_references'] as String?,
      );
}
