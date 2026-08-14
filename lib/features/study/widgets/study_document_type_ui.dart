import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:flutter/material.dart';

extension StudyDocumentTypeUi on StudyDocumentType {
  IconData get icon => switch (this) {
        StudyDocumentType.free => Icons.edit_note,
        StudyDocumentType.bibleStudy => Icons.menu_book_outlined,
        StudyDocumentType.sermon => Icons.campaign_outlined,
        StudyDocumentType.meditation => Icons.lightbulb_outline,
      };

  Color accent(ColorScheme colors) => switch (this) {
        StudyDocumentType.free => colors.primary,
        StudyDocumentType.bibleStudy => const Color(0xFF0891B2),
        StudyDocumentType.sermon => const Color(0xFF7C3AED),
        StudyDocumentType.meditation => const Color(0xFFEA580C),
      };

  String get description => switch (this) {
        StudyDocumentType.free =>
          'Écrivez librement vos réflexions, recherches et notes bibliques.',
        StudyDocumentType.bibleStudy =>
          'Structurez observation, interprétation, contexte et application.',
        StudyDocumentType.sermon =>
          'Préparez vos thèmes, points, sous-points, applications et conclusion.',
        StudyDocumentType.meditation =>
          'Développez un verset, une pensée, une application et une prière.',
      };

  String get titleHint => switch (this) {
        StudyDocumentType.free => 'Mes réflexions sur…',
        StudyDocumentType.bibleStudy => 'Étude de Jean 15',
        StudyDocumentType.sermon => 'Message : La grâce de Dieu',
        StudyDocumentType.meditation => 'Méditation sur Psaume 23',
      };

  String contextualTitle(String reference) => switch (this) {
        StudyDocumentType.free => 'Réflexions sur $reference',
        StudyDocumentType.bibleStudy => 'Étude de $reference',
        StudyDocumentType.sermon => 'Message : $reference',
        StudyDocumentType.meditation => 'Méditation sur $reference',
      };
}
