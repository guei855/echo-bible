# Ressources bibliques hors ligne

État vérifié le 13 août 2026. Aucune donnée de BibleStrong n’a été utilisée.

## STEPBible — Strong et morphologie

- **Source officielle :** [STEPBible Data](https://github.com/STEPBible/STEPBible-Data)
- **Version/date :** branche `master`, téléchargée le 13 août 2026.
- **Licence vérifiée :** CC BY 4.0 dans l’en-tête individuel de chacun des fichiers.
- **Attribution :** STEPBible.org, Tyndale House Cambridge et contributeurs ; lien vers le dépôt.
- **SQLite généré :** `assets/database/strong.db`, 71 217 152 octets.
- **Script :** `bible_builder/build_strong_db.py` (`tool/create_strong_db.py` est le relais compatible).
- **Transformation :** TSV vers tables indexées ; ponctuation originale séparée conservée hors du token lexical ; aucune association aux mots français.
- **Résolution des identifiants :** les numéros classiques et Extended Strong
  restent distincts ; voir
  [strong_number_resolution.md](resources/strong_number_resolution.md).
- **Politique française :** `definition_fr` reste NULL faute de source française complète et compatible. Les définitions TBESG restent signalées comme texte source. La colonne TBESH « Meaning » n’est pas importée à cause de l’autorisation supplémentaire demandée en amont.

| Fichier | Taille | SHA-256 |
|---|---:|---|
| TBESH | 3 288 045 | `464DCCADD95FD8620DD05FA0D7A4CABA58EC3C4D5DB3EBF38E43D046CA25B591` |
| TBESG | 4 736 912 | `312F723D7B8EF263BBDFB0451C9B8057125804DFFF390B6F8544CFF2A84B57F4` |
| TAHOT Gen–Deu | 18 190 455 | `E9B8546EE48FE0BFC57C3B70F5F40E98D96580E803526D19026224E31753368B` |
| TAHOT Jos–Est | 24 500 317 | `195FEE1DC3653BAB33701F170734EB894ED647C10CD08CC61749375FE8B73775` |
| TAHOT Job–Sng | 9 540 133 | `84E118A97E5725E3847CDFDD593873513021C790C63CC91A0D41FCA2B5DB2ED5` |
| TAHOT Isa–Mal | 17 977 518 | `F3DED203D2A74D6368932C97AE550D1D0754B271AF491DC0DEDF36FE3BA0BCC5` |
| TAGNT Mat–Jhn | 14 189 032 | `AB8EAAEB68E17A1DCFA34E1E9350358F22F03BC2A97244D848750AD81044BC8E` |
| TAGNT Act–Rev | 15 939 932 | `524E32375361E6D3FA2F7EF00B87605FDC4317A762F395651A05FDC31AD031B7` |
| TEHMC | 394 580 | `78779BEA824B31D4467DEC0161D547481C86F266BC39DEF12CD11DC7DCBE6DA7` |
| TEGMC | 467 056 | `5F0416F7617019A6082285214903BDE569A980D5FD3B88B8D7020D944E94DE82` |

Comptes SQLite : 22 717 entrées lexicales, 501 392 occurrences TAHOT, 141 720 occurrences TAGNT et 98 définitions de codes morphologiques. Les sources sont conservées dans `bible_builder/sources/stepbible/`.

## OpenBible.info Cross References

- **Source officielle :** [OpenBible.info Labs](https://www.openbible.info/labs/cross-references/)
- **Fichier :** `cross-references.zip` (1 982 196 octets), TSV extrait (8 301 974 octets).
- **Licence vérifiée :** CC BY 4.0, lien présent sur la page officielle et indication dans l’en-tête du TSV.
- **Attribution :** OpenBible.info avec lien vers la source.
- **SQLite généré :** `assets/database/cross_references.db`, 25 624 576 octets, 344 144 liens dont 87 495 plages.
- **Script :** `tool/create_cross_references_db.py`.
- **Transformation :** références OSIS et votes vers identifiants des 66 livres. Aucun texte biblique n’est dupliqué ; la version française sélectionnée est lue dans `bible.db`.
- **Sources conservées :** `bible_builder/sources/cross_references/`.

## Nave's Topical Bible

- **Auteur :** Orville J. Nave.
- **Sources officielles :** [CCEL](https://ccel.org/ccel/n/nave/bible.html) et [module CrossWire](https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave).
- **Version CrossWire :** 3.0, 29 novembre 2008.
- **Licence vérifiée :** domaine public selon la fiche officielle CrossWire.
- **Fichiers :** XML CCEL, 11 374 641 octets ; archive SWORD conservée, 1 300 879 octets.
- **SQLite généré :** `assets/database/nave.db`, 4 583 424 octets.
- **Script :** `tool/create_nave_db.py`.
- **Comptes :** 5 322 thèmes, 29 379 sections, 77 921 références, 12 lignes françaises portant 11 libellés distincts.
- **Couche française :** titres éditoriaux séparés, statut `manual`, jamais présentés comme traduction officielle complète. Les sections restent en anglais tant qu’elles ne sont pas validées.
- **Sources conservées :** `bible_builder/sources/nave/`.

## Dictionnaire biblique français

L’audit préalable demandé pour Vigouroux est documenté dans
[vigouroux_pre_import_report.md](resources/vigouroux_pre_import_report.md).
Les cinq fac-similés ont été téléchargés depuis Wikimedia Commons et leurs
tailles et SHA-1 ont été vérifiés. Aucune base n’a été créée.
Le détail des autres candidats et des refus est dans
[dictionary_candidates.md](resources/dictionary_candidates.md).

- Vigouroux/Wikisource : 781 articles structurés annoncés ; fac-similés du
  domaine public, transcription CC BY-SA 4.0, couverture inégale et incomplète.
- FreGBM/CrossWire : « Copyrighted; Freely distributable », sans droit explicite de conversion/adaptation SQLite.
- Westphal et éditions modernes : aucune licence de redistribution validée.

Le module Flutter et le schéma cible sont prêts, mais l’écran indique honnêtement que la ressource française n’est pas installée.

## Bases non modifiées

`bible.db` reste la source des textes français et des données utilisateur. Les notes, favoris, surlignages, historiques et paramètres n’ont pas été supprimés. Les fichiers XML bibliques existants n’ont pas été intégrés aux nouvelles bases d’étude.
