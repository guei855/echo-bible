class BibleVersion {
  final int id;
  final String code;
  final String name;
  final String abbreviation;
  final String language;
  final String? copyright;
  final bool isDefault;

  const BibleVersion({
    required this.id,
    required this.code,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.copyright,
    required this.isDefault,
  });

  factory BibleVersion.fromMap(Map<String, Object?> map) => BibleVersion(
        id: map['id'] as int,
        code: map['code'] as String,
        name: map['name'] as String,
        abbreviation: map['abbreviation'] as String,
        language: map['language'] as String,
        copyright: map['copyright'] as String?,
        isDefault: (map['is_default'] as int) == 1,
      );
}
