import 'dart:convert';

enum StudyDocumentType {
  free('free', 'Étude libre'),
  bibleStudy('bible_study', 'Étude biblique'),
  sermon('sermon', 'Prédication'),
  meditation('meditation', 'Méditation');

  const StudyDocumentType(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static StudyDocumentType parse(String? value) => values.firstWhere(
        (item) => item.databaseValue == value,
        orElse: () => StudyDocumentType.free,
      );
}

enum StudyStatus {
  draft('draft', 'Brouillon'),
  completed('completed', 'Finalisé');

  const StudyStatus(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static StudyStatus parse(String? value) => values.firstWhere(
        (item) => item.databaseValue == value,
        orElse: () => StudyStatus.draft,
      );
}

enum StudyBlockType {
  text,
  heading,
  verse,
  verseRange,
  verseLink,
  strong,
  dictionary,
  crossReferences,
  comparison,
  nave,
  quote,
  divider,
  image;

  static StudyBlockType parse(String? value) => values.firstWhere(
        (item) => item.name == value,
        orElse: () => StudyBlockType.text,
      );
}

class StudyBlock {
  final int? databaseId;
  final String id;
  final StudyBlockType type;
  final int position;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyBlock({
    this.databaseId,
    required this.id,
    required this.type,
    required this.position,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  String get plainText => switch (type) {
        StudyBlockType.text => _plainTextPayload(payload),
        StudyBlockType.heading ||
        StudyBlockType.quote =>
          payload['text'] as String? ?? '',
        StudyBlockType.divider => '────────',
        StudyBlockType.verse ||
        StudyBlockType.verseRange =>
          '${payload['reference'] ?? ''}\n'
              '${payload['text'] ?? ''}',
        StudyBlockType.verseLink => payload['reference'] as String? ?? '',
        StudyBlockType.strong => payload['displayMode'] == 'link'
            ? payload['code'] as String? ?? ''
            : '${payload['code'] ?? ''} '
                '${payload['originalWord'] ?? ''}\n${payload['definition'] ?? ''}',
        StudyBlockType.dictionary => payload['displayMode'] == 'reference'
            ? payload['title'] as String? ?? ''
            : '${payload['title'] ?? ''}\n${payload['excerpt'] ?? ''}',
        StudyBlockType.crossReferences =>
          (payload['references'] as List<Object?>? ?? const []).join('\n'),
        StudyBlockType.comparison =>
          (payload['versions'] as List<Object?>? ?? const []).map((item) {
            final value = item as Map<String, Object?>;
            return '${value['label']}: ${value['text']}';
          }).join('\n'),
        StudyBlockType.nave => '${payload['title'] ?? ''}\n'
            "Bible thématique Nave${(payload['references'] as List<Object?>? ?? const []).isEmpty ? '' : '\n${(payload['references'] as List<Object?>).join('\n')}'}",
        StudyBlockType.image => payload['caption'] as String? ?? 'Image',
      };

  StudyBlock copyWith({
    StudyBlockType? type,
    int? position,
    Map<String, Object?>? payload,
    DateTime? updatedAt,
  }) =>
      StudyBlock(
        databaseId: databaseId,
        id: id,
        type: type ?? this.type,
        position: position ?? this.position,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String encodePayload() => jsonEncode(payload);

  static String _plainTextPayload(Map<String, Object?> payload) {
    final delta = payload['delta'];
    if (delta is! List) return payload['text'] as String? ?? '';
    final buffer = StringBuffer();
    for (final operation in delta) {
      if (operation is Map && operation['insert'] is String) {
        buffer.write(operation['insert']);
      }
    }
    return buffer.toString().replaceFirst(RegExp(r'\n$'), '').trimRight();
  }

  static Map<String, Object?> decodePayload(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    try {
      return Map<String, Object?>.from(jsonDecode(value) as Map);
    } on FormatException {
      return {'text': value};
    }
  }
}

class PersonalStudy {
  final int id;
  final String title;
  final StudyDocumentType type;
  final List<StudyBlock> blocks;
  final String? primaryReference;
  final List<String> tags;
  final Map<String, Object?> metadata;
  final StudyStatus status;
  final bool isFavorite;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalStudy({
    required this.id,
    required this.title,
    this.type = StudyDocumentType.free,
    this.blocks = const [],
    this.primaryReference,
    this.tags = const [],
    this.metadata = const {},
    this.status = StudyStatus.draft,
    this.isFavorite = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get content => blocks.map((block) => block.plainText).join('\n\n');
  String? get reference {
    if (primaryReference != null && primaryReference!.trim().isNotEmpty) {
      return primaryReference;
    }
    for (final block in blocks) {
      final value = block.payload['reference'] as String?;
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  PersonalStudy copyWith({
    String? title,
    StudyDocumentType? type,
    List<StudyBlock>? blocks,
    String? primaryReference,
    List<String>? tags,
    Map<String, Object?>? metadata,
    StudyStatus? status,
    bool? isFavorite,
    bool? isPinned,
    DateTime? updatedAt,
  }) =>
      PersonalStudy(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        blocks: blocks ?? this.blocks,
        primaryReference: primaryReference ?? this.primaryReference,
        tags: tags ?? this.tags,
        metadata: metadata ?? this.metadata,
        status: status ?? this.status,
        isFavorite: isFavorite ?? this.isFavorite,
        isPinned: isPinned ?? this.isPinned,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
