# Rapport préalable à l’import — Dictionnaire Vigouroux

Audit arrêté au 13 août 2026. Ce rapport précède obligatoirement toute
construction de `assets/database/dictionary.db`.

## Décision

La situation juridique est exploitable, sous conditions, mais la couverture
technique n’est pas complète. Un premier lot limité aux articles réellement
publiés et relus sur Wikisource est possible sous CC BY-SA 4.0. Il ne devra
jamais être présenté comme l’intégralité des cinq tomes.

Aucun import n’est lancé à cette étape : l’utilisateur doit d’abord accepter
le périmètre incomplet et les obligations CC BY-SA.

## Sources et licences distinctes

| Représentation | Source | Statut vérifié | Conséquence pour ECHO BIBLE |
|---|---|---|---|
| Œuvre historique imprimée | Fulcran Vigouroux, Letouzey et Ané, 1895–1912 | Domaine public | Le texte historique ne doit pas être réécrit ni complété. |
| Fac-similés DjVu | Gallica, fichiers hébergés sur Wikimedia Commons | « Public domain », Public Domain Mark ; auteur mort en 1915 et publication antérieure à 1931 | Redistribution permise ; conserver provenance, notice et sommes de contrôle. |
| Transcription collaborative | Wikisource en français | **CC BY-SA 4.0** | Attribution, lien vers la licence, indication des modifications et partage à l’identique de la matière adaptée. Conserver un lien vers chaque page et son historique. |

Références officielles :

- [ouvrage sur Wikisource](https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible_-_Vigouroux) ;
- [modèle des cinq tomes](https://fr.wikisource.org/wiki/Mod%C3%A8le:Dictionnaire_de_la_Bible_-_Vigouroux) ;
- [règles de droit d’auteur de Wikisource](https://fr.wikisource.org/wiki/Aide:Droit_d%E2%80%99auteur) ;
- [conditions d’utilisation Wikimedia](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use/fr) ;
- pages Commons de chaque tome, enregistrées dans le manifeste source.

## Couverture mesurée

La page officielle annonce **781 articles créés**. C’est le nombre actuellement
disponible sous forme d’articles structurés dans l’espace principal ; il ne
constitue pas le nombre total d’entrées de l’édition imprimée.

| Tome | Plage | Pages du scan | Progression affichée par Wikisource | Reste hors de cette progression |
|---|---|---:|---:|---:|
| I | A–B | 1 054 | 1 043 (98 %) | 11 |
| II | C–F | 1 254 | 805 (64 %) | 449 |
| III | G–K | 987 | 474 (48 %) | 513 |
| IV | L–PA | 1 154 | 324 (28 %) | 830 |
| V | PE–Z | 1 307 | 910 (69 %) | 397 |
| **Total** | A–Z | **5 756** | **3 556 (61,8 %)** | **2 200** |

La page classe aussi globalement l’ouvrage à 25 %, ce qui reflète son état
éditorial général et ne doit pas être confondu avec le ratio de pages affiché
ci-dessus.

### Articles disponibles seulement en scan

Le **nombre exact d’articles seulement présents dans les scans est
indéterminable sans segmenter les 5 756 pages** : les scans n’exposent pas une
liste structurée de toutes les vedettes absentes. Donner `total imprimé - 781`
serait inventer une donnée. La mesure honnête disponible avant OCR est donc
2 200 pages hors de la progression affichée, et non un faux nombre d’articles.

## Qualité de la transcription

- Les articles publiés sont structurés et transclus depuis les pages du
  fac-similé ; ils fournissent titre, auteur éventuel, tome et plages de pages.
- Un contrôle ponctuel d’une page du tome I a trouvé le niveau Wikisource 4
  (validé) et un wikitexte exploitable.
- La page de travail indique que les OCR sont généralement bons, mais signale
  encore des images et planches à extraire ainsi que du grec et de l’hébreu
  manquants.
- Les niveaux de validation ne sont pas homogènes. Chaque article importé
  devra conserver un statut de qualité et sa révision source.
- Le HTML rendu ne doit pas être aplati sans contrôle : tableaux, notes,
  caractères hébreux/grecs, petites capitales et renvois doivent être testés.

Le contrôle API des treize titres de validation donne :

- présents sous le titre exact : `Apôtre`, `Jérusalem` (tome III, pages
  1317–1396) et `Jésus-Christ` ;
- absents sous le titre exact, sans variante pertinente trouvée par recherche
  de préfixe : `Abraham`, `Alliance`, `Baptême`, `David`, `Grâce`, `Jésus`,
  `Moïse`, `Pentecôte`, `Saint-Esprit` et `Temple`.

Une base limitée aux 781 articles actuels échouerait donc six des sept tests
minimaux de validation demandés (`Abraham`, `Alliance`, `David`, `Jésus`,
`Moïse`, `Temple`). Cette preuve technique justifie de ne pas lancer encore
l’intégration applicative.

## Taille

- Fac-similés : **345 225 088 octets**, soit environ **329,2 Mio**.
- Les cinq DjVu sont conservés dans
  `bible_builder/sources/dictionary/vigouroux/` et leurs tailles et SHA-1
  correspondent au manifeste Wikimedia. Aucun fichier partiel ne subsiste.
- `dictionary.db` pour les 781 articles actuels : estimation prudente de
  **25 à 80 Mio** avec contenu UTF-8, métadonnées, alias, références et index
  FTS5. Cette fourchette devra être remplacée par la taille mesurée d’un lot
  pilote ; aucun chiffre plus précis n’est défendable avant extraction.
- Les images et les DjVu ne doivent pas être inclus dans SQLite.

## Méthode d’extraction proposée

1. Énumérer uniquement les 781 pages d’article reliées depuis l’ouvrage ou sa
   catégorie Wikisource ; ignorer les pages non transcrites.
2. Récupérer via l’API MediaWiki le wikitexte/rendu, l’identifiant de révision,
   la date, l’URL canonique et l’URL d’historique.
3. Déduire le tome et les pages à partir des balises de transclusion
   `pages index=...`, sans estimation par position.
4. Convertir le balisage de façon déterministe en texte/HTML local sûr, en
   conservant Unicode, orthographe et structure historique. Aucun contenu IA.
5. Créer des alias seulement depuis les redirections et variantes attestées.
   La normalisation sans accents sert uniquement à la recherche.
6. Extraire les références bibliques avec un parseur français conservateur ;
   stocker séparément les références reconnues et laisser intactes celles qui
   restent ambiguës. Ne jamais copier les versets dans la base dictionnaire.
7. Insérer dans SQLite avec transactions, contraintes, index et FTS5, puis
   vérifier les comptes, les liens de provenance et un échantillon contre les
   fac-similés.
8. Livrer avec l’attribution CC BY-SA 4.0 et une indication claire que la base
   est une sélection incomplète et transformée de Wikisource.

## Conditions avant feu vert

- accepter une première édition incomplète limitée aux articles structurés ;
- accepter que la matière transcrite/adaptée soit distribuée sous CC BY-SA 4.0 ;
- ne pas lancer d’OCR massif pour les 2 200 pages restantes sans un audit
  séparé ;
- réussir un lot pilote incluant accents, hébreu, grec, tableaux et renvois.
