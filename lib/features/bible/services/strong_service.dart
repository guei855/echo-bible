import 'package:echo_bible/features/study/repositories/strong_repository.dart';

class StrongResultItem {
  final String code;
  final String lemma;
  final String? testament;
  final String? definition;
  final String? frenchDefinition;
  final String? shortDefinition;
  final String? transliteration;
  final String? pronunciation;
  final String? morphology;
  final String? language;
  final String? gloss;
  final String? source;
  final String? license;

  const StrongResultItem({
    required this.code,
    required this.lemma,
    required this.testament,
    required this.definition,
    required this.frenchDefinition,
    required this.shortDefinition,
    required this.transliteration,
    required this.pronunciation,
    required this.morphology,
    required this.language,
    required this.gloss,
    required this.source,
    required this.license,
  });
}

class StrongService {
  const StrongService._();

  static Future<List<StrongResultItem>> search(String query) async {
    final normalizedQuery = _canonicalQuery(query);
    if (normalizedQuery.isEmpty) return [];

    final results = await const StrongRepository().search(normalizedQuery);
    return results
        .map(
          (entry) => StrongResultItem(
            code: entry.strongNumber,
            lemma: entry.originalWord,
            testament: entry.testament,
            definition: entry.definition,
            frenchDefinition: entry.frenchDefinition,
            shortDefinition: entry.shortDefinition,
            transliteration: entry.transliteration,
            pronunciation: entry.pronunciation,
            morphology: entry.morphology,
            language: entry.language,
            gloss: entry.gloss,
            source: entry.source,
            license: entry.license,
          ),
        )
        .toList();
  }

  static String _canonicalQuery(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^([HG])0*(\d+)(.*)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return trimmed;
    return '${match.group(1)!.toUpperCase()}${match.group(2)}${match.group(3)!}';
  }
}
