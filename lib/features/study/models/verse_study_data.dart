import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';

class VerseStudyData {
  final List<VerseStrongWord> strongWords;
  final List<CrossReference> crossReferences;

  const VerseStudyData({
    required this.strongWords,
    required this.crossReferences,
  });
}

class VerseStrongWord {
  final int id;
  final int order;
  final String word;
  final String code;
  final String? originalWord;
  final String? lemma;
  final String? morphology;
  final String? language;
  final String? definition;
  final String? transliteration;
  final String? pronunciation;
  final String? gloss;
  final String? shortDefinition;
  final String? frenchDefinition;
  final String? source;
  final String? license;
  final StrongNumberKind numberKind;

  const VerseStrongWord({
    required this.id,
    required this.order,
    required this.word,
    required this.code,
    this.originalWord,
    this.lemma,
    this.morphology,
    this.language,
    this.definition,
    this.transliteration,
    this.pronunciation,
    this.gloss,
    this.shortDefinition,
    this.frenchDefinition,
    this.source,
    this.license,
    this.numberKind = StrongNumberKind.classic,
  });

  String get inferredLanguage {
    if (language?.trim().isNotEmpty ?? false) return language!;
    if (code.toUpperCase().startsWith('H')) return 'Hébreu';
    if (code.toUpperCase().startsWith('G')) return 'Grec';
    return 'Langue non renseignée';
  }

  String? get morphologyInFrench {
    final raw = morphology?.trim();
    if (raw == null || raw.isEmpty) return null;
    final code = raw.contains(',') ? raw.split(',').last : raw;
    final greek = RegExp(r'^([A-Z]+)-([A-Z])([A-Z])([A-Z])$').firstMatch(code);
    if (greek != null) {
      const types = {
        'N': 'Nom',
        'A': 'Adjectif',
        'V': 'Verbe',
        'P': 'Pronom',
        'R': 'Préposition',
      };
      const cases = {
        'N': 'Nominatif',
        'G': 'Génitif',
        'D': 'Datif',
        'A': 'Accusatif',
        'V': 'Vocatif',
      };
      const numbers = {'S': 'Singulier', 'P': 'Pluriel'};
      const genders = {'M': 'Masculin', 'F': 'Féminin', 'N': 'Neutre'};
      return [
        types[greek.group(1)] ?? greek.group(1),
        cases[greek.group(2)] ?? greek.group(2),
        numbers[greek.group(3)] ?? greek.group(3),
        genders[greek.group(4)] ?? greek.group(4),
      ].whereType<String>().join(' · ');
    }
    final hebrew = RegExp(r'^[HA]:?([A-Za-z]+)$').firstMatch(raw);
    if (hebrew != null) {
      final value = hebrew.group(1)!;
      final labels = <String>[];
      if (value.startsWith('N')) labels.add('Nom');
      if (value.contains('m')) labels.add('Masculin');
      if (value.contains('f')) labels.add('Féminin');
      if (value.contains('s')) labels.add('Singulier');
      if (value.contains('p')) labels.add('Pluriel');
      if (value.contains('a')) labels.add('État absolu');
      if (value.contains('c')) labels.add('État construit');
      if (labels.isNotEmpty) return labels.join(' · ');
    }
    return raw;
  }
}

class StrongOccurrence {
  final int bookId;
  final String bookName;
  final int chaptersCount;
  final int chapterNumber;
  final int verseNumber;
  final String verseText;

  const StrongOccurrence({
    required this.bookId,
    required this.bookName,
    required this.chaptersCount,
    required this.chapterNumber,
    required this.verseNumber,
    required this.verseText,
  });
}
