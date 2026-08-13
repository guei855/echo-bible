# Inventaire des écrans ECHO BIBLE

Audit réalisé le 13 août 2026. L’application n’utilise actuellement aucune route nommée : toutes les transitions sont des `MaterialPageRoute` locales. La « route » indiquée ci-dessous décrit donc le point d’entrée effectif, pas un nom déclaré dans `MaterialApp`.

## Écrans et décisions

| Écran | Fichier | Classe | Module | Route / accès actuel | Appelé depuis | Fonction | Statut | Doublon de | Action recommandée |
|---|---|---|---|---|---|---|---|---|---|
| Accueil | `lib/features/home/screens/home_screen.dart` | `HomeScreen` | Home | index 0 de la navigation principale | `MainNavigationScreen` | Accueil validé | **KEEP — PROTECTED** | — | Ne modifier ni l’UI ni la disposition ; seules ses destinations pourraient être corrigées si elles existaient |
| Navigation principale | `lib/features/home/screens/main_navigation_screen.dart` | `MainNavigationScreen` | Home/navigation | `MaterialApp.home` | `main.dart`, onboarding | Conteneur des 4 onglets existants | KEEP — PROTECTED | — | Conserver l’apparence et les quatre destinations actuelles tant qu’une migration produit n’est pas validée |
| Bible | `lib/features/bible/screens/bible_screen.dart` | `BibleScreen` | Bible | index 1 | `MainNavigationScreen` | Rouvre la dernière lecture et héberge le lecteur | KEEP | — | Point d’entrée Bible actuel ; conserver la reprise de lecture |
| Livres | `lib/features/bible/screens/books_screen.dart` | `BooksScreen` | Bible | aucune transition active | aucune | Liste AT/NT puis lecteur | KEEP | sélecteur livre/chapitre (fonction proche) | Conserver comme écran canonique de bibliothèque ; raccorder uniquement lorsqu’un bouton existant doit ouvrir la liste |
| Lecteur | `lib/features/bible/screens/chapter_reader_screen.dart` | `ChapterReaderScreen` | Bible | route locale paramétrée | Bible, accueil, recherche, étude, plans | Lecteur unique, versions, sélection, actions de versets | KEEP | — | Lecteur canonique unique |
| Relais lecteur | `lib/features/bible/screens/reader_tabs_screen.dart` | `ReaderTabsScreen` | Bible | aucune | aucune | Simple relais déprécié vers le lecteur | DELETE | `ChapterReaderScreen` | Supprimé après vérification des références |
| Note de verset | `lib/features/bible/screens/note_editor_screen.dart` | `NoteEditorScreen` | Bible/notes | route locale paramétrée | `ChapterReaderScreen` | Créer/modifier/supprimer une note | KEEP | — | Sous-écran canonique d’édition |
| Comparaison parallèle | `lib/features/bible/screens/parallel_comparison_screen.dart` | `ParallelComparisonScreen` | Bible/comparaison | route locale paramétrée | lecteur, sélecteur, onglets d’étude | Comparer 2 ou 3 versions | KEEP | — | Écran canonique d’affichage comparé |
| Recherche générale | `lib/features/search/screens/search_screen.dart` | `SearchScreen` | Recherche | aucune transition active | aucune | Recherche du texte biblique | KEEP | Concordance (fonction voisine, pas identique) | Conserver ; futur point d’entrée de recherche globale, sans ajouter de section à l’accueil |
| Concordance | `lib/features/search/screens/concordance_screen.dart` | `ConcordanceScreen` | Recherche/étude | route locale | `StudyHubScreen`, onglets d’étude | Recherche Bible et Strong par onglets | KEEP | — | Recherche canonique Bible/Strong actuelle |
| Plans | `lib/features/plans/screens/reading_plans_screen.dart` | `ReadingPlansScreen` | Plans | route locale | carte du jour, outils | Plans intégrés et personnels | KEEP | — | Écran canonique actuel |
| Création de plan | `lib/features/plans/screens/create_plan_screen.dart` | `CreatePlanScreen` | Plans | route locale | `ReadingPlansScreen` | Création d’un plan personnel | KEEP | — | Sous-écran canonique |
| Outils personnels | `lib/features/study/screens/study_tools_screen.dart` | `StudyToolsScreen` | Étude/espace personnel | index 2 | `MainNavigationScreen` | Notes, signets, surlignages, historique, plans et accès à l’étude | KEEP | `StudyHubScreen` (chevauchement partiel) | Conserver comme espace de travail ; ne pas le traiter comme un second moteur d’étude |
| Étude biblique | `lib/features/study/screens/study_hub_screen.dart` | `StudyHubScreen` | Étude | route locale | `StudyToolsScreen` | Point d’entrée des ressources d’étude | KEEP | — | Écran canonique d’étude ; renommage éventuel en `StudyScreen` dans une migration séparée |
| Liste d’éléments personnels | `lib/features/study/screens/study_tool_list_screen.dart` | `StudyToolListScreen` | Étude/espace personnel | route locale paramétrée | `StudyToolsScreen` | Notes, signets, surlignages, historique | KEEP | — | Sous-écran mutualisé |
| Strong détail | `lib/features/study/screens/strong_word_screen.dart` | `StrongWordScreen` | Strong | route locale paramétrée | concordance, fiche de verset | Détail lexical et occurrences | KEEP | — | Détail Strong canonique ; recherche assurée par l’onglet Strong de la concordance |
| Références croisées | `lib/features/study/screens/cross_references_screen.dart` | `CrossReferencesScreen` | Références croisées | route locale paramétrée ou autonome | lecteur, étude | Recherche et navigation vers les cibles | KEEP | — | Écran canonique ; repository unique |
| Nave | `lib/features/study/screens/nave_topics_screen.dart` | `NaveTopicsScreen` | Nave | route locale | étude, onglets | Recherche de thèmes | KEEP | — | Liste canonique |
| Fiche Nave | `lib/features/study/screens/nave_topics_screen.dart` | `NaveTopicDetailScreen` | Nave | route locale paramétrée | `NaveTopicsScreen` | Références d’un thème | KEEP | — | Sous-écran canonique |
| Choix comparaison | `lib/features/study/screens/comparison_picker_screen.dart` | `ComparisonPickerScreen` | Comparaison | route locale | étude | Choix référence et versions | KEEP | — | Entrée canonique vers `ParallelComparisonScreen` |
| Études personnelles | `lib/features/study/screens/personal_studies_screen.dart` | `PersonalStudiesScreen` | Études | route locale | outils, étude | Liste/recherche/suppression | KEEP | — | Liste canonique actuelle |
| Éditeur d’étude | `lib/features/study/screens/personal_study_editor_screen.dart` | `PersonalStudyEditorScreen` | Études | route locale paramétrée | études personnelles | Création/modification | KEEP | — | Éditeur canonique actuel |
| Onglets d’étude | `lib/features/study/screens/study_tabs_screen.dart` | `StudyTabsScreen` | Étude | route locale | étude | Contextes persistants | KEEP | — | Conserver avec l’unique `StudyTabManager` |
| Sources | `lib/features/study/screens/study_sources_screen.dart` | `StudySourcesScreen` | Étude/licences | route locale | étude | Sources et licences de données | KEEP | section À propos (complémentaire) | Conserver comme vue spécialisée |
| Ressource indisponible | `lib/features/study/screens/study_resource_screen.dart` | `StudyResourceScreen` | Étude | route locale paramétrée | étude | État d’attente dictionnaire/chronologie/IA | KEEP (PARTIAL) | — | Garder comme sous-écran générique, sans le présenter comme donnée disponible |
| Paramètres / profil actuel | `lib/features/settings/screens/settings_screen.dart` | `SettingsScreen` | Paramètres | index 3 | `MainNavigationScreen` | Paramètres et accès À propos | KEEP | futur profil (absent) | Écran canonique actuel |
| À propos | `lib/features/settings/screens/about_screen.dart` | `AboutScreen` | Paramètres/licences | route locale | paramètres | Version, sources, licences | KEEP | sources d’étude (complémentaire) | Conserver |
| Onboarding | `lib/features/onboarding/screens/onboarding_screen.dart` | `OnboardingScreen` | Onboarding | route de remplacement | splash ou interne | Présentation initiale | KEEP | — | Conserver |
| Splash | `lib/features/splash/splash_screen.dart` | `SplashScreen` | Démarrage | aucune transition entrante | aucune | Temporisation puis onboarding | LEGACY | démarrage direct actuel | Ne pas supprimer avant décision produit sur l’onboarding |

## Fonctions demandées mais sans écran actif

Les dossiers `audio`, `dictionary`, `commentaries`, `timeline`, `profile`, `notes`, `bookmarks` et `compare` sont absents ou vides. Il ne faut pas créer de faux écrans ni de fausses données uniquement pour remplir l’arborescence. Les fonctions déjà disponibles restent portées par le lecteur, `StudyToolListScreen`, `ComparisonPickerScreen` et `SettingsScreen`.

## Navigation actuelle

- Entrée : `main.dart` → `MainNavigationScreen`.
- Barre principale inchangée : Accueil → `HomeScreen`, Bible → `BibleScreen`, Outils → `StudyToolsScreen`, Profil → `SettingsScreen`.
- Étude : `StudyToolsScreen` → `StudyHubScreen` → concordance/Strong, références, Nave, comparaison, études, sources et onglets.
- Bible : `BibleScreen` → `ChapterReaderScreen`; la sélection livre/chapitre est assurée dans le lecteur par `BookChapterSelectorSheet`.
- Aucun `routes`, `onGenerateRoute`, `Navigator.pushNamed` ou `go_router` n’est présent.

## Décision sur l’accueil

`HomeScreen` est explicitement exclu de toute fusion, remplacement ou suppression. Les widgets historiques d’accueil non appelés sont inventoriés comme legacy, mais restent intacts pendant cette phase afin de respecter le gel visuel.
