# Ressources françaises pour ECHO BIBLE

Audit effectué le 13 août 2026. Aucun fichier n’a été téléchargé pendant cet
audit. Les tailles eBible correspondent aux archives USFM officielles; les
tailles CrossWire sont celles publiées par les fiches des modules. « Non
publiée » signifie que la fiche officielle affiche `0.0 b` ou ne fournit pas
de taille exploitable sans téléchargement.

## Lexiques Strong et morphologie

| Ressource | Langue | Source | Licence | Format | Taille | Hors ligne | Utilisable | Attribution | Remarques |
|---|---|---|---|---|---:|---|---|---|---|
| TBESH | Hébreu/araméen, gloss anglais | STEPBible-Data | CC BY 4.0 pour les données STEPBible | TSV → SQLite | 3 288 045 o | Oui | Oui, déjà intégré | STEP Bible | `Meaning` exclu faute d’autorisation Online Bible; `definition_fr` reste NULL |
| TBESG | Grec, définitions anglaises | STEPBible-Data | CC BY 4.0 | TSV → SQLite | 4 736 912 o | Oui | Oui, déjà intégré | STEP Bible | Définition source affichable, jamais présentée comme française |
| FreStrongsHebrew | Français/hébreu | CrossWire; Yvon L’Hermitte, © Yves Petrakian | Copyright; distribution non commerciale permise uniquement en format SWORD | SWORD zLD | Non publiée | Oui | NON en SQLite sans autorisation | Traducteurs, 123-bible, levangile.com, CrossWire | Demander une licence autorisant conversion et redistribution dans l’application |
| FreStrongsGreek | Français/grec | CrossWire; traduction © Yves Petrakian | Copyright; distribution non commerciale permise uniquement en format SWORD | SWORD zLD | Non publiée | Oui | NON en SQLite sans autorisation | Traducteur, 123-bible, levangile.com, CrossWire | Même restriction que le module hébreu |
| FreRobinson | Français/grec | CrossWire; Fraternité de Tibériade | CC BY-SA 4.0 | SWORD zLD | Non publiée | Oui | OUI avec attribution et partage à l’identique | CrossWire + Fraternité de Tibériade | Bon candidat pour expliquer les codes morphologiques grecs en français |
| FreBailly | Français/grec | CrossWire/Chaeréphon | Licence indiquée `null` | SWORD zLD | Non publiée | Oui | NON | — | À éviter tant qu’une licence explicite n’est pas publiée |

Aucun lexique Strong français complet vérifié n’autorise clairement une
conversion vers SQLite. Une éventuelle traduction automatique doit vivre
dans un champ distinct (`machine_translation_fr`) avec moteur, version, date
et libellé visible « traduction automatique non officielle ».

## Bibles françaises

| Version | Abréviation | Source | Licence | Format | Taille | Hors ligne | Utilisable | Attribution/remarques |
|---|---|---|---|---|---:|---|---|---|
| Louis Segond 1910 | LSG1910 / F10 | eBible.org `fraLSG` | Domaine public | USFM ZIP | 3 467 489 o | Oui | OUI immédiatement | Source eBible recommandée; canon complet |
| Ostervald | OST / FOB | eBible.org `fra_fob` | Domaine public | USFM ZIP | 2 993 702 o | Oui | OUI immédiatement | Ne pas confondre avec des révisions modernes protégées |
| Bible J. N. Darby | JND | eBible.org `frajnd`, source BPC | Domaine public selon la fiche | USFM ZIP | 1 640 113 o | Oui | OUI | J. N. Darby, BPC, eBible; versification OT hébraïque à convertir |
| Sainte Bible libre pour le monde | SBL | eBible.org `frasbl` | Domaine public | USFM ZIP | 3 494 455 o | Oui | OUI immédiatement | David Williams, Michael Paul Johnson; traduction encore qualifiée de brouillon |
| Sainte Bible néo-Crampon Libre | NCL | eBible.org `francl` | CC BY-SA 4.0, © 2022 Fraternité de Tibériade | USFM ZIP | 3 727 969 o | Oui | OUI avec attribution | Conserver copyright, source, licence et signaler toute modification |
| Bible David Martin 1744 | MARTIN | CrossWire `FreBDM1744` | Domaine public | SWORD Bible | 1,88 Mio installés | Oui | OUI | Import SWORD reproductible à écrire |
| Bible de Zadoc Kahn | KAHN | CrossWire `FreKhan` | Domaine public | SWORD Bible | 1,37 Mio | Oui | OUI | Ancien Testament juif |
| Septante de Giguet | LXX-G | CrossWire `FreLXXGiguet` | Domaine public | SWORD Bible | 3,24 Mio | Oui | OUI | Septante, pas une Bible protestante standard |
| NT Stapfer 1889 | STAPFER | CrossWire `FreStapfer1889` | Domaine public | SWORD Bible | 717,86 Kio | Oui | OUI | Nouveau Testament seulement |
| Synodale 1921 | SYN1921 | CrossWire `FreSynodale1921` | Domaine public | SWORD Bible | 791,99 Kio | Oui | OUI | NT et Psaumes seulement |
| Bible de Lausanne 1872 | LSN1872 | CrossWire `FreLSN1872` | Permission accordée uniquement à CrossWire | SWORD Biblical Texts | 1,86 Mio | Oui | NON sans autorisation | La distribution numérique ne donne pas de droit à ECHO BIBLE |

Ordre conseillé pour une première extension : LSG1910, Ostervald, SBL, puis
Darby après mise au point de la table de versification.

## Dictionnaires bibliques français

| Titre | Auteur/éditeur | Source | Licence | Format | Taille | Hors ligne | Utilisable | Attribution/remarques |
|---|---|---|---|---|---:|---|---|---|
| Glossaire de la Bible David Martin 1744 | Auteur numérique non indiqué | CrossWire `FreGBM` | Copyright; « freely distributable » | SWORD Dictionary | 127,13 Kio | Oui | Autorisation conseillée avant conversion | Environ 970 définitions; licence vague sur adaptation/reformatage |
| Dictionnaire de la Bible | F. Vigouroux et contributeurs | Wikisource | Œuvre ancienne du domaine public; contributions Wikisource CC BY-SA 4.0 | DjVu + OCR/wikitexte | Non empaquetée, multi-tomes | Oui après construction | OUI après audit tome par tome | Attribuer auteurs, édition, Wikisource, contributeurs et CC BY-SA |
| Bailly abrégé grec-français | A. Bailly; transcription Chaeréphon | CrossWire `FreBailly` | Aucune licence publiée (`null`) | SWORD zLD | Non publiée | Oui | NON | Pas un dictionnaire biblique général; redistribution juridiquement incertaine |

## Nave en français

Le catalogue officiel CrossWire contient Nave en anglais, domaine public,
mais aucune traduction française avec licence libre explicite n’a été
trouvée. La base anglaise existante peut fournir la structure et les
références, pas un contenu français présenté comme définitif.

Une couche séparée devrait utiliser : `topic_id, locale, translated_title,
translated_body, status, translator, reviewer, source, license`. Seules les
traductions `validated` devraient être définitives; une traduction automatique
resterait un brouillon clairement marqué.

## Références croisées

OpenBible.info publie ses références sous CC BY. Le dataset est indépendant
de la langue. ECHO BIBLE résout désormais chaque cible dans
`verse_translations` avec la version française sélectionnée, puis retombe sur
`verses.text` si elle manque. Les plages assemblent tous les versets de
`target_verse_start` à `target_verse_end`.

## Commentaires français

| Titre | Auteur/traducteurs | Source | Licence | Format | Taille | Hors ligne | Utilisable | Attribution/remarques |
|---|---|---|---|---|---:|---|---|---|
| Commentaires de la Bible par saint Augustin | Augustin; Poujoulat/Raulx, 1864–1872 | CrossWire `FreAug` | Domaine public | SWORD Commentary | 7,97 Mio | Oui | OUI | Attribuer auteur, traducteurs, édition et CrossWire; couverture non continue |
| Bible Annotée | Louis Bonnet et Félix Bovet | CrossWire `FreBA` | Domaine public | SWORD Bible avec notes | 2,15 Mio | Oui | OUI après vérification | Séparer texte et notes dans SQLite; attribuer auteurs, Théotex et CrossWire |
| Chaque jour les Écritures | Bibles et Publications Chrétiennes | CrossWire `FreCJE` | Protégé; permission accordée à CrossWire | SWORD Commentary | 1,48 Mio | Oui | NON sans autorisation | Ne pas importer le module dans ECHO BIBLE |
| Matthew Henry en français | Traducteur/édition variables | Aucune édition libre officielle vérifiée | Généralement protégée ou licence absente | Variable | Variable | Potentiellement | NON | Ne jamais reprendre une traduction Web sans licence explicite |

## Classement final

### A — intégrables immédiatement

- LSG1910, Ostervald, SBL et Darby (avec conversion de versification).
- Martin 1744, Zadoc Kahn, LXX Giguet, Stapfer et Synodale 1921.
- Commentaires de saint Augustin et Bible Annotée.
- Structure Nave anglaise du domaine public, sans fausse traduction.

### B — intégrables avec attribution

- TBESH/TBESG CC BY 4.0 selon les exclusions déjà appliquées.
- Néo-Crampon Libre et FreRobinson sous CC BY-SA 4.0.
- OpenBible Cross References sous CC BY.
- Vigouroux depuis Wikisource après audit tome par tome et attribution CC BY-SA.

### C — nécessitent une autorisation

- FreStrongsHebrew et FreStrongsGreek pour conversion SQLite ou usage hors du
  cadre non commercial en format SWORD.
- Glossaire David Martin `FreGBM`, Bible de Lausanne numérique et `FreCJE`.
- Toute traduction française définitive de Nave non produite sous licence
  compatible.

### D — à éviter

- FreBailly tant que sa licence officielle reste absente.
- Traductions françaises de Matthew Henry sans licence explicite.
- Données de BibleStrong ou d’une autre application tierce.
- Traductions automatiques présentées comme définitions officielles.
- Révisions modernes portant un nom ancien sans licence vérifiée.
