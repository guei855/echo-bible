class DictionaryEntry {
  final int id;
  final String headword;
  final String content;
  final String source;
  final String sourceKind;
  final String sourceUrl;
  final String? historyUrl;
  final String? volume;
  final String? pageReference;
  final String quality;

  const DictionaryEntry({
    required this.id,
    required this.headword,
    required this.content,
    required this.source,
    required this.sourceKind,
    required this.sourceUrl,
    required this.quality,
    this.historyUrl,
    this.volume,
    this.pageReference,
  });

  String get title => headword;

  factory DictionaryEntry.fromMap(Map<String, Object?> map) => DictionaryEntry(
        id: map['id'] as int,
        headword: map['headword'] as String,
        content: map['content'] as String,
        source: map['source'] as String,
        sourceKind: map['source_kind'] as String,
        sourceUrl: map['source_url'] as String,
        historyUrl: map['history_url'] as String?,
        volume: map['volume'] as String?,
        pageReference: map['page_reference'] as String?,
        quality: map['quality'] as String,
      );
}
