# Lexique et Strong : une source de vérité

## Audit

Avant cette connexion, la carte **Lexique** du hub ouvrait l’onglet Strong de
`ConcordanceScreen` et utilisait le nombre d’entrées Nave comme badge. Le futur
global du hub attendait aussi `StrongRepository.count()` sans isoler l’absence
de la ressource : si `strong.db` n’était pas installée, le résumé échouait et le
badge pouvait rester sur « Vérification… ».

## Architecture retenue

`LexiconScreen` est une expérience linguistique dédiée, mais réutilise
directement :

- `StrongRepository` pour les codes, formes originales, translittérations,
  définitions, alignements français, morphologies et occurrences ;
- `StrongDatabaseService` comme unique service d’ouverture SQLite ;
- `ResourceManager` et `OfflineResourceId.strong` pour l’état, le téléchargement
  et la suppression de la ressource ;
- `StrongEntry`, `StrongVerseToken`, `VerseStrongWord` et `StrongWordScreen` pour
  les modèles et la fiche détaillée.

Aucune base `lexique.db` ou `lexicon.db` n’est créée. La seule ressource est
`strong.db`, avec les tables `strong_entries`, `strong_occurrences`,
`morphology_codes`, `french_verse_tokens`, `french_token_strongs`,
`versification_mappings` et `metadata`.

## Comportement

- Installée : la carte affiche « Disponible » et ouvre le Lexique hébreu & grec.
- Absente : la carte affiche « Télécharger » et ouvre le gestionnaire filtré sur
  la seule ressource Strong.
- Les recherches françaises proviennent exclusivement des associations
  `french_verse_tokens` / `french_token_strongs`.
- Les signes massorétiques et les diacritiques grecs sont conservés à
  l’affichage. Une forme hébraïque sans points peut être recherchée sans altérer
  la forme stockée.
- Les occurrences sont chargées par pages de 30 et ouvrent le lecteur au verset
  canonique correspondant.
