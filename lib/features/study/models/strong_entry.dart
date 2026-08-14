enum StrongNumberKind { classic, extendedLexical, extendedGrammar }

class StrongEntry {
  final int id;
  final String strongNumber;
  final String extendedStrongNumber;
  final String? disambiguatedStrongNumber;
  final String? unifiedStrongNumber;
  final String? testament;
  final String language;
  final String originalWord;
  final String? transliteration;
  final String? pronunciation;
  final String? morphology;
  final String? gloss;
  final String? shortDefinition;
  final String? definition;
  final String? frenchDefinition;
  final String source;
  final String license;

  const StrongEntry(
      {required this.id,
      required this.strongNumber,
      required this.extendedStrongNumber,
      this.disambiguatedStrongNumber,
      this.unifiedStrongNumber,
      this.testament,
      required this.language,
      required this.originalWord,
      this.transliteration,
      this.pronunciation,
      this.morphology,
      this.gloss,
      this.shortDefinition,
      this.definition,
      this.frenchDefinition,
      required this.source,
      required this.license});

  factory StrongEntry.fromMap(Map<String, Object?> map) => StrongEntry(
      id: map['id'] as int,
      strongNumber: map['strong_number'] as String,
      extendedStrongNumber: map['extended_strong_number'] as String? ??
          map['strong_number'] as String,
      disambiguatedStrongNumber: map['disambiguated_strong_number'] as String?,
      unifiedStrongNumber: map['unified_strong_number'] as String?,
      testament: map['testament'] as String?,
      language: map['language'] as String,
      originalWord: map['original_word'] as String,
      transliteration: map['transliteration'] as String?,
      pronunciation: map['pronunciation'] as String?,
      morphology: map['morphology'] as String?,
      gloss: map['gloss'] as String?,
      shortDefinition: map['short_definition'] as String?,
      definition: map['definition_source'] as String?,
      frenchDefinition: map['definition_fr'] as String?,
      source: map['source'] as String,
      license: map['license'] as String);

  StrongNumberKind get numberKind {
    final match =
        RegExp(r'^[HG](\d+)', caseSensitive: false).firstMatch(strongNumber);
    final number = int.tryParse(match?.group(1) ?? '');
    if (number != null && number >= 9000) {
      return StrongNumberKind.extendedGrammar;
    }
    if (extendedStrongNumber.toUpperCase() != strongNumber.toUpperCase() ||
        RegExp(r'[A-Z]$', caseSensitive: false).hasMatch(strongNumber)) {
      return StrongNumberKind.extendedLexical;
    }
    return StrongNumberKind.classic;
  }

  String get numberKindLabel => switch (numberKind) {
        StrongNumberKind.classic => 'Strong classique',
        StrongNumberKind.extendedLexical => 'Extended Strong lexical',
        StrongNumberKind.extendedGrammar =>
          'Extended Strong — préfixe grammatical',
      };
}

class StrongVerseToken {
  final int id;
  final String strongNumber;
  final int bookId;
  final int chapter;
  final int verse;
  final String originalToken;
  final String? lemma;
  final String? morphology;
  final String? morphologyDescription;
  final int position;

  const StrongVerseToken({
    required this.id,
    required this.strongNumber,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.originalToken,
    required this.lemma,
    required this.morphology,
    this.morphologyDescription,
    required this.position,
  });

  factory StrongVerseToken.fromMap(Map<String, Object?> map) =>
      StrongVerseToken(
        id: map['id'] as int,
        strongNumber: map['strong_number'] as String,
        bookId: map['book_id'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        originalToken: map['token_original'] as String,
        lemma: map['lemma'] as String?,
        morphology: map['morphology'] as String?,
        morphologyDescription: map['morphology_description'] as String?,
        position: map['token_position'] as int,
      );
}

class FrenchStrongToken {
  final int tokenId;
  final int bookId;
  final int chapter;
  final int verse;
  final int position;
  final String surface;
  final String normalizedSurface;
  final bool isTranslated;
  final String strongNumber;
  final int strongOrder;
  final String sourceDataset;

  const FrenchStrongToken({
    required this.tokenId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.position,
    required this.surface,
    required this.normalizedSurface,
    required this.isTranslated,
    required this.strongNumber,
    required this.strongOrder,
    required this.sourceDataset,
  });

  factory FrenchStrongToken.fromMap(Map<String, Object?> map) =>
      FrenchStrongToken(
        tokenId: map['token_id'] as int,
        bookId: map['book_id'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        position: map['token_index'] as int,
        surface: map['surface'] as String,
        normalizedSurface: map['normalized_surface'] as String,
        isTranslated: map['is_translated'] == 1,
        strongNumber: map['strong_number'] as String,
        strongOrder: map['strong_order'] as int,
        sourceDataset: map['source_dataset'] as String,
      );

  String get displaySurface =>
      isTranslated ? surface : '[terme original non traduit]';
}
