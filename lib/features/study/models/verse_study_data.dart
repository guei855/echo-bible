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
