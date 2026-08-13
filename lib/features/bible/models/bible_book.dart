class BibleBook {
  final int id;
  final String name;
  final String abbreviation;
  final String testament;
  final int chaptersCount;

  BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.chaptersCount,
  });

  factory BibleBook.fromMap(Map<String, dynamic> map) {
    return BibleBook(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      abbreviation: map['abbreviation'] ?? '',
      testament: map['testament'] ?? '',
      chaptersCount: map['chapters_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'testament': testament,
      'chapters_count': chaptersCount,
    };
  }
}
