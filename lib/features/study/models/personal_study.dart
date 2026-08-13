class PersonalStudy {
  final int id;
  final String title;
  final String content;
  final String? reference;
  final DateTime updatedAt;

  const PersonalStudy({
    required this.id,
    required this.title,
    required this.content,
    required this.reference,
    required this.updatedAt,
  });
}
