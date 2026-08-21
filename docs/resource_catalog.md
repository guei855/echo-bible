# Catalogue de ressources — audit du 21 août 2026

## Modules prêts à publier

| Ressource | Langue | Source primaire | Licence vérifiée | État |
|---|---|---|---|---|
| Louis Segond 1910 | FR | https://ebible.org/bible/details.php?id=fraLSG | Domaine public | Base installée |
| Bible J.N. Darby | FR | https://ebible.org/bible/details.php?id=frajnd | Domaine public | `fr/bibles/darby.db` |
| Bible Ostervald | FR | https://ebible.org/bible/details.php?id=fra_fob | Domaine public | `fr/bibles/ostervald.db` |
| Néo-Crampon Libre | FR | https://ebible.org/bible/details.php?id=francl | CC BY-SA 4.0 | `fr/bibles/neo_crampon.db` |
| Bible Martin 1744 | FR | https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=FreBDM1744 | Domaine public | `fr/bibles/martin.db` |
| Strong / lexiques / tokens originaux | Commun | https://github.com/STEPBible/STEPBible-Data | CC BY 4.0 pour les jeux utilisés TBESH, TBESG, TAHOT et TAGNT | `common/strong/strong.db` |
| Références croisées | Commun | https://www.openbible.info/labs/cross-references/ | CC BY 4.0 | `common/cross_references/cross_references.db` |
| Nave original | EN | https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave | Domaine public | `en/nave/nave_core.db` |
| Nave — couche française | FR | Traductions Echo Bible reliées aux identifiants du Nave original | CC BY-SA 4.0 | `fr/nave/nave_fr.db` |
| Dictionnaire de Vigouroux | FR | https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible | Œuvre domaine public ; transcription Wikisource CC BY-SA 4.0 | `fr/dictionaries/vigouroux_dictionary.db` |

Les tailles et SHA-256 faisant foi sont dans `resources_manifest.json`.

## Redistribution permise, conversion manquante

| Ressource | Langue | Source primaire | Licence | Décision |
|---|---|---|---|---|
| World English Bible Classic | EN | https://ebible.org/bible/details.php?id=eng-web | Domaine public; nom protégé comme marque | Catalogue, conversion à faire |

## Non redistribué

| Ressource | Motif |
|---|---|
| Parole de Vie | Version moderne de l’Alliance biblique française; autorisation écrite requise pour une copie complète hors ligne. |
| Bible en français courant / NFC | Version moderne de l’Alliance biblique française; autorisation écrite requise. |
| AMP / Bible amplifiée française | Aucun module français libre officiel identifié; les droits numériques complets exigent une licence. |
| Commentaires français | Aucun corpus structuré avec provenance et licence de transcription entièrement validées. |

## Règles d’affichage

- L’interface française privilégie les ressources `fr`, puis `common`, avec
  repli anglais explicite.
- Une sélection française n’est jamais présentée comme alignée mot à mot avec
  un Strong. Les tokens affichés sont ceux du verset original.
- Les sections absentes sont masquées ou remplacées par une seule indication
  de ressource à installer.
- Les textes cibles des références croisées sont lus dans la version biblique
  active.
