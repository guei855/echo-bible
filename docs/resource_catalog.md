# Catalogue de ressources — audit du 13 août 2026

## Modules prêts à publier

| Ressource | Langue | Source primaire | Licence vérifiée | État |
|---|---|---|---|---|
| Louis Segond 1910 | FR | https://ebible.org/bible/details.php?id=fraLSG | Domaine public | Base installée |
| Bible J.N. Darby | FR | https://ebible.org/bible/details.php?id=frajnd | Domaine public | `fr/bibles/darby.db` |
| Bible Ostervald | FR | https://ebible.org/bible/details.php?id=fra_fob | Domaine public | `fr/bibles/ostervald.db` |
| Strong / lexiques / tokens originaux | Commun | https://github.com/STEPBible/STEPBible-Data | CC BY 4.0 pour les jeux utilisés TBESH, TBESG, TAHOT et TAGNT | `common/strong/strong.db` |
| Références croisées | Commun | https://www.openbible.info/labs/cross-references/ | CC BY 4.0 | `common/cross_references/cross_references.db` |
| Nave original | EN | https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave | Domaine public | `en/nave/nave_core.db` |
| Nave — couche française | FR | Traductions Echo Bible reliées aux identifiants du Nave original | CC BY-SA 4.0 | `fr/nave/nave_fr.db` |

Les tailles et SHA-256 faisant foi sont dans `resources_manifest.json`.

## Redistribution permise, conversion manquante

| Ressource | Langue | Source primaire | Licence | Décision |
|---|---|---|---|---|
| Néo-Crampon Libre | FR | https://ebible.org/bible/details.php?id=francl | CC BY-SA 4.0, attribution et partage à l’identique | Catalogue, conversion à faire |
| World English Bible Classic | EN | https://ebible.org/bible/details.php?id=eng-web | Domaine public; nom protégé comme marque | Catalogue, conversion à faire |
| Dictionnaire de Vigouroux | FR | https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible_-_Vigouroux | Œuvre/scans domaine public; transcription Wikisource sous CC BY-SA selon les pages | Import structuré et attribution à finaliser |

## Non redistribué

| Ressource | Motif |
|---|---|
| Parole de Vie | Version moderne de l’Alliance biblique française; autorisation écrite requise pour une copie complète hors ligne. |
| Bible en français courant / NFC | Version moderne de l’Alliance biblique française; autorisation écrite requise. |
| AMP / Bible amplifiée française | Aucun module français libre officiel identifié; les droits numériques complets exigent une licence. |
| Bible Martin | L’œuvre historique est du domaine public, mais aucune source numérique complète, primaire, structurée et accompagnée d’une fiche de redistribution suffisamment claire n’a encore été validée. L’OCR/PDF n’est pas importé. |
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
