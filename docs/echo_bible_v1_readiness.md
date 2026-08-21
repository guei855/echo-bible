# Préparation ECHO BIBLE V1

Audit de consolidation réalisé le 21 août 2026 à partir du commit stable
`ba0054b5aa4ade21e2f60270033cf1d1a17bf322`.

## Décision

Le code et les artefacts Android constituent une **candidate V1 techniquement
constructible**. La publication publique reste conditionnée à une recette sur
appareil réel (installation neuve, mise à jour avec données existantes, TTS,
clavier, rotation et mode avion) et à la configuration de la signature de
production dans l'environnement de publication.

Version candidate conservée : `1.0.0+1`. Nom Android vérifié : `ECHO BIBLE`.

## Fonctionnalités terminées et vérifiées automatiquement

- lecteur hors ligne avec LSG, Darby, Ostervald, néo-Crampon et Martin ;
- sélection de versets, notes, favoris, surlignages, soulignages et historique ;
- comparaison d'un passage, dont les plages multi-versets et les cinq versions ;
- Strong, lexique hébreu/grec, morphologie, occurrences et pagination ;
- dictionnaire Vigouroux, recherche normalisée/FTS et gestion de l'absence ;
- références croisées, synchronisation contextuelle et navigation ;
- Nave français V2, recherche par thème et recherche inverse par verset ;
- ECHO Étude : création, ouverture, autosauvegarde, contenu riche, insertion au
  curseur, blocs contextuels et document de plus de 10 000 mots ;
- historique : déduplication, sélection multiple, suppression et compteur ;
- ResourceManager : téléchargement, progression, annulation, checksum,
  corruption SQLite, suppression, réinstallation et fonctionnement local ;
- écrans critiques étroits et sombres couverts par des tests de widgets.

## Consolidation réalisée

- permission `INTERNET` ajoutée au manifeste release ; tous les téléchargements
  publiés utilisent HTTPS et aucun cleartext global n'est autorisé ;
- splash sombre explicite ajouté pour éviter le flash blanc ;
- les réponses obsolètes de la concordance ne peuvent plus remplacer une
  recherche ou un onglet plus récent ;
- la carte « Reprendre la lecture » ignore proprement une base indisponible et
  ne déclenche plus de `setState` après sa destruction ;
- contraste de la recherche corrigé en mode sombre ;
- états utilisateur harmonisés : Installé, Télécharger, Téléchargement…,
  Mettre à jour, Supprimer, Indisponible et Autorisation requise ;
- attribution Vigouroux, Nave français et Bibles téléchargeables actualisée ;
- exécution des tests SQLite rendue déterministe afin d'éviter les transactions
  concurrentes sur le même fichier FFI ;
- compilation Kotlin incrémentale désactivée : les plugins sont dans le cache
  Pub sur `C:` et le projet sur `D:`, combinaison qui corrompait les chemins
  relatifs des caches Kotlin sous Windows.

## Doublons et legacy supprimés

- ancien `BibleRepository` singleton sans appel ;
- quatre versets factices de prototype ;
- ancien initialiseur XML sans appel qui supprimait `bible.db` et ciblait un
  asset qui n'est plus distribué ;
- prototype `ChapterCache` sans appel et non borné.

`HomeScreen` n'a pas été modifié. Aucun écran de commentaires et aucune grande
fonctionnalité n'ont été ajoutés.

## Ressources et taille du paquet

Le `pubspec.yaml` n'embarque que `assets/database/core_bible.db`,
`resources_manifest.json` et `assets/licenses/`. L'inspection ZIP de l'APK
release confirme l'absence de `strong.db`, `cross_references.db`, Nave,
Vigouroux, XML, ZIP, `.part`, sources builder ou archives.

| Artefact | Mesure historique avant | Candidate V1 | Écart |
|---|---:|---:|---:|
| APK debug | 249 603 027 o | 175 999 434 o (167,85 Mio) | -29,5 % |
| APK release universel | 68 195 331 o | 75 998 202 o (72,48 Mio) | +11,4 % |
| APK armeabi-v7a | 24 682 882 o | 27 570 553 o (26,29 Mio) | +11,7 % |
| APK arm64-v8a | 27 208 248 o | 29 653 551 o (28,28 Mio) | +9,0 % |
| APK x86_64 | 28 643 597 o | 31 154 432 o (29,71 Mio) | +8,8 % |
| AAB release | 66 368 267 o | 73 484 558 o (70,08 Mio) | +10,7 % |

Les mesures « avant » sont des artefacts historiques du dépôt (13 et 21 août)
et ne correspondent pas tous au même périmètre fonctionnel. L'augmentation des
releases reflète notamment les modules ajoutés depuis cette date ; la réduction
debug et l'inspection du paquet démontrent en revanche le retrait effectif des
grosses ressources optionnelles. Le premier poste applicatif est
`core_bible.db` (13 205 504 o bruts, 4 728 614 o compressés).

## Qualité, sécurité et performance

- `flutter analyze` : **No issues found** ;
- suite complète : **144 tests actifs réussis**, deux tests réseau réels
  optionnels ignorés lorsqu'ils ne sont pas explicitement activés ;
- tests couverts : loaders success/empty/error, réponses async obsolètes,
  navigation contextuelle, bases absentes/corrompues, SQLite fermé,
  suppressions répétées, responsive 320 px et palettes sombres ;
- manifeste de ressources : 9/9 entrées complètes, SHA-256 valides, tailles,
  versions, langues, catégories, licences, sources et URL HTTPS ;
- scan Git : aucun token, clé privée, mot de passe, `.env`, keystore, APK, AAB
  ou `.part` suivi ;
- permissions release : INTERNET, notifications, redémarrage et vibration,
  toutes justifiées par les téléchargements et rappels locaux ;
- `EXPLAIN QUERY PLAN` utilise les index attendus pour Strong, Vigouroux,
  références croisées et Nave ; ECHO Étude possède
  `idx_study_documents_sort` et `idx_study_blocks_order` ;
- les repositories Strong, Vigouroux, références et Nave limitent/paginent les
  requêtes ; aucune ressource complète n'est chargée en mémoire ;
- les bases optionnelles sont ouvertes à la demande et leurs handles sont
  fermés ou invalidés lors de leur suppression.

## Builds validés

- `flutter build apk --debug` : réussi ;
- `flutter build apk --release` : réussi ;
- `flutter build apk --release --split-per-abi` : réussi pour armeabi-v7a,
  arm64-v8a et x86_64 ;
- `flutter build appbundle --release` : réussi.

Les artefacts sont sous `build/app/outputs/` et restent ignorés par Git.

## Fonctionnalités partielles ou reportées

- commentaires bibliques : **reportés**, aucune ressource intégrée ;
- export PDF/DOCX avancé : **reporté V1.1** ;
- IA : **reportée** ;
- audio en ligne : **reporté** ; le TTS local existant doit encore être recetté
  sur les moteurs Android ciblés ;
- paysage et très grands facteurs de texte : support sans crash visé, finition
  visuelle non garantie sur chaque écran ;
- World English Bible et autres versions modernes : non distribuées en V1.

## Recette manuelle obligatoire avant publication

Ces contrôles ne peuvent pas être certifiés par les tests hôte sans appareil ou
émulateur Android préparé :

1. installation neuve et premier lancement ;
2. mise à jour depuis l'APK stable avec notes, favoris, marquages, études,
   historique et réglages existants ;
3. mode avion après installation de chaque ressource ;
4. suppression d'une ressource pendant que l'application reste ouverte ;
5. interruption/reprise réseau réelle et autorisation de notifications ;
6. TTS lors d'un changement de version et en quittant le lecteur ;
7. Gboard, texte agrandi, portrait/paysage et largeurs 320 à 480 px ;
8. vérification de la signature, de l'icône adaptative et de la fiche Play.

## Risques restants

- la release locale est une validation de compilation ; la clé de signature de
  production n'est volontairement pas stockée dans Git ;
- le build release propre est lent sous Windows car l'incrémental Kotlin est
  désactivé pour assurer sa fiabilité entre les lecteurs `C:` et `D:` ;
- les tests réseau réels sont optionnels afin que la suite standard reste
  déterministe et hors ligne ;
- les prototypes d'accueil non appelés sont conservés pour respecter le gel de
  `HomeScreen` et pourront être retirés dans une passe dédiée.
