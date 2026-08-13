import 'package:flutter/material.dart';
import '../models/onboarding_page.dart';

class OnboardingData {
  static const List<OnboardingPageModel> pages = [
    // Page 1 : L'icône de livre que tu voulais sur "Faites de la Bible..."
    OnboardingPageModel(
      icon: Icons.menu_book_rounded,
      title: "Faites de la Bible votre compagnon quotidien",
      description:
          "Plans de lecture, méditations, favoris et bien plus encore pour nourrir votre foi chaque jour.",
    ),
    // Page 2 : L'icône de recherche/étude
    OnboardingPageModel(
      icon: Icons.search_rounded,
      title: "Étudiez la Parole en profondeur",
      description:
          "Retrouvez rapidement un verset, comparez plusieurs versions, prenez des notes et explorez les richesses des Écritures.",
    ),
    // Page 3 : L'icône de bienvenue / livre ouvert
    OnboardingPageModel(
      icon: Icons.auto_stories_rounded,
      title: "Bienvenue dans ECHO BIBLE",
      description:
          "Découvrez une nouvelle manière de lire, méditer et laisser Dieu vous parler à travers Sa Parole.",
    ),
  ];
}
