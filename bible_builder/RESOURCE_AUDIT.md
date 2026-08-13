# Audit des ressources d’étude hors ligne

Audit du 12 août 2026. Les tailles STEPBible correspondent aux blobs de la
branche `master` du dépôt officiel. Aucune ressource de BibStrong n’a été
consultée ou copiée.

| Ressource | Source | Licence | Format | Taille constatée/publiée | Utilisable dans ECHO BIBLE | Attribution requise | Utilité |
|---|---|---|---|---:|---|---|---|
| Strong hébreu (TBESH) | STEPBible-Data, `Lexicons/TBESH…txt` | CC BY 4.0 pour les données STEPBible; colonne `Meaning` exclue car l’en-tête demande l’autorisation d’Online Bible | TSV UTF-8 | 3 288 045 o | OUI, formes/translittérations/morphologie/glosses; NON pour `Meaning` sans permission | STEP Bible + lien | Lexique hébreu/araméen hors ligne |
| Strong grec (TBESG) | STEPBible-Data, `Lexicons/TBESG…txt` | CC BY 4.0 | TSV UTF-8 | 4 736 912 o | OUI | STEP Bible + lien | Lexique grec et définitions sources |
| Texte hébreu tagué (TAHOT) | STEPBible-Data, `Translators Amalgamated OT+NT/TAHOT…` | CC BY 4.0 annoncé dans le dépôt et les noms de fichiers | TSV UTF-8, 4 parties | 70 208 423 o | OUI, après conception de l’import et validation de la versification | STEP Bible + lien | Référence → token hébreu → Strong désambiguïsé → morphologie |
| Texte grec tagué (TAGNT) | STEPBible-Data, `Translators Amalgamated OT+NT/TAGNT…` | CC BY 4.0 annoncé dans le dépôt et les noms de fichiers | TSV UTF-8, 2 parties | 30 128 964 o | OUI, après conception de l’import et gestion des variantes textuelles | STEP Bible + lien | Référence → token grec/lemme → Strong → morphologie/variantes |
| Morphologie hébraïque (TEHMC) | STEPBible-Data, `Morphology codes/TEHMC…txt` | CC BY 4.0 | Texte tabulé | 394 580 o | OUI, utile avec TAHOT; non nécessaire au lexique seul | STEP Bible + lien | Expansion lisible des codes morphologiques hébreux |
| Morphologie grecque (TEGMC) | STEPBible-Data, `Morphology codes/TEGMC…txt` | CC BY 4.0 | Texte tabulé | 467 056 o | OUI, utile avec TAGNT; non nécessaire au lexique seul | STEP Bible + lien | Expansion lisible des codes morphologiques grecs |
| Références croisées | OpenBible.info Cross References | CC BY (page officielle) | TSV dans ZIP | ZIP existant : 1 982 196 o; TSV : 8 301 974 o | OUI; déjà présent avant cet audit, aucun nouveau téléchargement | OpenBible.info + lien | Liens entre passages avec votes |
| Nave | CrossWire, module `Nave` | Domaine public | Module SWORD zLD; XML de construction existant | ZIP existant : 1 300 879 o; XML : 11 374 641 o | OUI; déjà présent avant cet audit, aucun nouveau téléchargement | Attribution recommandée à Orville J. Nave et CrossWire | Index thématique et références |
| Dictionnaire biblique | CrossWire `Easton` ou `Smith` | Domaine public | Module SWORD dictionnaire/zLD | Smith : 3,33 Mio installé; Easton : taille non publiée par la page | OUI, après import reproductible et contrôle de l’édition | Auteur, édition et CrossWire | Articles historiques; contenu anglais et ancien |
| Commentaires bibliques | CrossWire `MHCC` ou `JFB` | Domaine public | Modules SWORD Commentary | MHCC : 2,03 Mio; JFB : 5,74 Mio installés | OUI, après import reproductible; à signaler comme commentaire historique | Auteurs, édition et CrossWire | Commentaire hors ligne en anglais |

## Ressources déconseillées

- TTESV : licence CC BY-NC dans le nom du fichier, texte ESV soumis à des
  conditions propres, et aucun alignement fiable avec la LSG française.
- Les colonnes `Meaning` de TBESH : ne pas intégrer sans permission écrite
  d’Online Bible, même si le reste du jeu STEPBible est annoncé CC BY 4.0.
- Les lexiques modernes propriétaires (HALOT, BDAG, DCH, etc.) : aucune
  redistribution hors ligne sans licence commerciale explicite.
- Les copies de modules ou bases provenant de BibStrong ou d’autres
  applications : provenance et droits non vérifiables.
- Les éditions numériques anonymes d’ouvrages du domaine public : le texte
  original peut être libre tandis que la transcription ou l’édition dérivée
  ne l’est pas nécessairement.

## Décision sur le vrai mapping Strong

TAHOT et TAGNT sont les jeux appropriés. Ils doivent alimenter une nouvelle
table d’occurrences originales distincte du texte français, avec au minimum
la référence, la position du token, la forme originale, le lemme/Strong, la
morphologie et les informations de variante. Ils ne doivent jamais être
répartis automatiquement sur les mots de la LSG.
