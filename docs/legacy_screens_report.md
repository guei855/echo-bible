# Rapport des éléments legacy

Ce rapport précède toute suppression. Une suppression n’est autorisée ici que si le symbole ne possède aucun appel entrant et si son remplacement actif est identifié.

| Fichier | Classe / contenu | Ancien rôle | Nouveau rôle | Statut | Remplacé par | Raison |
|---|---|---|---|---|---|---|
| `lib/features/bible/screens/reader_tabs_screen.dart` | `ReaderTabsScreen` | Relais historique du lecteur multi-onglets | Aucun | DELETE | `ChapterReaderScreen` et `StudyTabsScreen` | Aucun appel ; simple délégation dépréciée |
| `lib/features/bible/data/bible_repository.dart` | `BibleRepository` | Charger les livres | Aucun | DELETE | `lib/features/bible/data/repository/bible_repository.dart` | Copie exacte sans import actif |
| `lib/features/bible/data/bible_local_source.dart` | fichier vide | Ancienne datasource envisagée | Aucun | DELETE | `BibleLocalDatasource` | Fichier vide et sans appel |
| `lib/features/bible/repository/bible_repository.dart` | ancien `BibleRepository` singleton | Versets, surlignages, favoris | Aucun | LEGACY | `DatabaseService`, `VerseActionService`, lecteur actuel | Aucun import actif, mais API différente : conserver jusqu’à une seconde validation |
| `lib/features/splash/splash_screen.dart` | `SplashScreen` | Écran de démarrage | Aucun actuellement | LEGACY | démarrage direct vers `MainNavigationScreen` | Aucun appel entrant ; décision onboarding nécessaire avant suppression |
| `lib/features/bible/data/dummy_bible_data.dart` | données factices | Prototype Bible | Aucun | LEGACY | `bible.db` | Aucun appel, suppression différée avec les autres prototypes |
| `lib/features/bible/repository/chapter_cache.dart` | `ChapterCache` | Prototype de cache | Aucun | LEGACY | chargement actuel du lecteur | Aucun appel, à réévaluer avec la stratégie de performance |
| `lib/features/home/widgets/quick_access_grid.dart` et anciens widgets associés | grille et cartes d’un ancien accueil | Ancienne UI d’accueil | Aucun | LEGACY — PROTECTED SCOPE | `HomeScreen` actuel | Non appelés, mais laissés intacts pour respecter le gel absolu de l’accueil |
| `lib/core/widgets/*` | bibliothèque UI Echo | Design system prototype | Usage très limité ou nul | LEGACY | widgets actifs par feature | Nettoyage différé pour éviter une modification visuelle transversale |

## Suppressions réalisées dans cette phase

- `reader_tabs_screen.dart` : aucune référence entrante, lecteur canonique inchangé.
- `data/bible_repository.dart` : copie stricte du repository conservé.
- `data/bible_local_source.dart` : fichier vide.

## Éléments volontairement non supprimés

Tous les autres candidats restent présents. En particulier, aucun fichier de l’accueil, aucune base SQLite et aucun code de notes, favoris, surlignages, historique ou paramètres n’a été supprimé.
