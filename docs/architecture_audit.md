# Audit d’architecture ECHO BIBLE

## Résultat synthétique

Le projet est déjà organisé principalement par fonctionnalités. La priorité n’est pas de déplacer massivement les fichiers, mais de stabiliser les points d’entrée et d’éliminer les doublons sans appel. `HomeScreen` est **KEEP — PROTECTED** et n’a pas été modifié.

## Données SQLite

| Base / ressource | Rôle observé | Déclarée comme asset | Politique |
|---|---|---:|---|
| `assets/database/bible.db` | Livres, versets, versions et tables utilisateur ajoutées à l’ouverture | oui | Source biblique et utilisateur à préserver ; jamais fusionner avec les bases d’étude |
| `assets/database/strong.db` | Lexique Strong hors ligne | oui | Base d’étude immuable, ouverte en lecture seule |
| `assets/database/cross_references.db` | Liens entre références | oui | Base d’étude immuable, texte cible relu depuis `bible.db` |
| `assets/database/nave.db` | Thèmes et références Nave | oui | Base d’étude immuable, texte cible relu depuis `bible.db` |
| `dictionary.db` | absent | non | À intégrer uniquement avec une ressource redistribuable validée |
| `commentaries.db` | absent | non | À intégrer uniquement avec une ressource redistribuable validée |
| `timeline.db` | absent | non | À définir |
| trois fichiers `*_usfx.xml` | sources de construction biblique | non | Artéfacts du builder, non embarqués dans l’application |

Les bases Strong, références croisées et Nave passent par `BundledDatabase` et des services dédiés. `bible.db` passe par `DatabaseService`/`DatabaseInitializer`. Aucune base n’a été remplacée et aucune table utilisateur n’a été supprimée.

## Repositories, services et modèles

### Repositories canoniques

- Bible : `features/bible/data/repository/bible_repository.dart` avec `BibleLocalDatasource` et `DatabaseHelper`.
- Strong : `StrongRepository` → `StrongDatabaseService` → `strong.db`.
- Références croisées : `CrossReferenceRepository` → `CrossReferenceDatabaseService` → `cross_references.db`, puis lecture des textes dans `bible.db`.
- Nave : `NaveRepository` → `NaveDatabaseService` → `nave.db`, puis lecture des passages dans `bible.db`.

Deux anciennes classes `BibleRepository` supplémentaires ont été identifiées : une copie exacte dans `features/bible/data/bible_repository.dart` et une ancienne API non appelée dans `features/bible/repository/bible_repository.dart`. Elles sont consignées dans le rapport legacy.

### Services conservés

- Communs : `DatabaseService`, `SearchService`, `SettingsService`.
- Bible : `BibleVersionService`, `StrongService` (occurrences/mapping existant), `VerseActionService`.
- Étude : services d’ouverture des trois bases, `VerseStudyService`, `StudyToolsService`, `PersonalStudyService` et l’unique `StudyTabManager`.
- Plans : `ReadingPlanService`, `ReadingReminderService`.

Les services de bases d’étude ont des responsabilités distinctes ; ils ne sont pas des doublons de `DatabaseService`.

### Modèles

Les modèles actifs sont regroupés par fonctionnalité : Bible (`BibleBook`, `BibleVersion`, `Verse`, thèmes de lecture), étude (`StrongEntry`, `CrossReference`, `NaveTopic`, `VerseStudyData`, études et onglets), plans et onboarding. Les anciens modèles/données factices de `features/home` et `features/bible/data/dummy_bible_data.dart` n’ont aucun appel actif ; ils restent documentés pour une suppression ultérieure groupée.

## Widgets

- Widgets actifs du lecteur : sélecteur livre/chapitre, réglages, actions rapides de verset, liaisons du lecteur et fiche d’étude.
- Widgets actifs de l’accueil : `ResumeReadingCard` et `TodayReadingPlanCard`. Ils n’ont pas été modifiés.
- `lib/core/widgets` contient une ancienne bibliothèque UI largement non appelée. La supprimer ou la substituer maintenant changerait potentiellement le rendu ; elle reste legacy.
- Les petits états vides privés se ressemblent, mais leur fusion n’apporte pas assez de valeur pour justifier un changement visuel dans cette phase.

## Doublons classés

| Groupe | Classe | Décision |
|---|---|---|
| A — exact | deux repositories Bible datasource identiques | conserver `data/repository/bible_repository.dart`, supprimer la copie sans appel |
| A — relais exact | `ReaderTabsScreen` | supprimer ; il ne fait que construire `ChapterReaderScreen` |
| B — UI différente | `BibleScreen` / `BooksScreen` | conserver les deux rôles : reprise de lecture et bibliothèque ; un seul lecteur réel |
| B — UI différente | `StudyToolsScreen` / `StudyHubScreen` | conserver les rôles séparés : espace personnel et entrée des ressources d’étude |
| B — fonction voisine | `SearchScreen` / `ConcordanceScreen` | conserver : recherche générale future et recherche Bible/Strong active |
| B — comparaison | `ComparisonPickerScreen` / `ParallelComparisonScreen` | conserver : sélection puis rendu, pas deux moteurs |
| C — ancien écran | `SplashScreen` | legacy sans appel, conservé en attente d’une décision onboarding |
| D — partiel | `StudyResourceScreen` | sous-écran d’indisponibilité, sans données fictives |

## Routes et risques

Le projet ne possède pas de routes nommées mortes : il ne possède pas encore de registre de routes. Centraliser immédiatement toutes les transitions serait un refactoring transversal risqué. La prochaine étape recommandée est d’introduire un registre uniquement lorsqu’une fonctionnalité reçoit un point d’entrée supplémentaire, puis de migrer écran par écran.

Risques encore ouverts :

- `BooksScreen` et `SearchScreen` sont prêts mais sans appel actif ; les relier nécessite une décision sur un contrôle de navigation existant, puisque l’accueil est gelé.
- La barre principale actuelle comporte Accueil/Bible/Outils/Profil et doit rester visuellement inchangée selon la règle de sécurité fournie.
- Dictionnaire, commentaires, chronologie et audio n’ont pas encore de ressources/implémentations réelles.
- Certains anciens fichiers affichent des chaînes manifestement mal encodées dans la console ; une correction globale d’encodage doit être traitée séparément pour éviter de modifier l’accueil protégé.

## Architecture cible progressive

```text
HomeScreen (KEEP — PROTECTED)
└─ MainNavigationScreen (navigation visuelle conservée)
   ├─ BibleScreen → ChapterReaderScreen
   │                 ├─ BookChapterSelectorSheet
   │                 ├─ NoteEditorScreen
   │                 ├─ ParallelComparisonScreen
   │                 └─ VerseStudySheet
   ├─ StudyToolsScreen (espace personnel)
   │  └─ StudyHubScreen (entrée d’étude canonique)
   │     ├─ ConcordanceScreen → StrongWordScreen
   │     ├─ CrossReferencesScreen
   │     ├─ NaveTopicsScreen → NaveTopicDetailScreen
   │     ├─ ComparisonPickerScreen → ParallelComparisonScreen
   │     ├─ PersonalStudiesScreen → PersonalStudyEditorScreen
   │     └─ StudyTabsScreen → StudyTabManager
   └─ SettingsScreen → AboutScreen
```

Cette structure conserve les fonctionnalités en place et la séparation des bases, sans copier une architecture React/Redux et sans créer des écrans vides pour les modules futurs.
