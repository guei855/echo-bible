# Audit ciblé — versions bibliques françaises

## KEEP

- `HomeScreen`, sans modification.
- LSG embarquée et schéma utilisateur existant.
- `ChapterReaderScreen` et `ParallelComparisonScreen` comme interfaces de base.
- Notes, favoris, surlignages, soulignages, historique et paramètres.
- `assets/database/bible.db`, conservé strictement à l’identique.

## REUSE

- `ResourceManager` pour le téléchargement temporaire, SHA-256, contrôle SQLite,
  remplacement atomique, version installée, annulation et suppression.
- `DownloadManagerScreen` pour le catalogue et la progression.
- Le sélecteur du lecteur et le sélecteur à cases de la comparaison.

## EXTEND

- Catalogue avec Darby, Ostervald et Néo-Crampon prêts à héberger.
- Stockage `ApplicationSupportDirectory/echo_bible/resources/bibles/fr/`.
- Préservation approximative du défilement au changement de version.
- Comparaison dynamique des seules versions installées, préférences comprises.

## FIX

- Remplacement de l’état générique « En préparation » par « Prêt à héberger »
  pour les trois bases construites sans URL publique.
- Retour automatique à LSG lorsque le module actif disparaît.
- Schéma des modules avec `canonical_number` et `book_id` communs 1–66.

## CREATE

- Source officielle, licence et provenance pour chaque édition.
- Générateur unique `bible_builder/build_bible_version.py`.
- `BibleVersionRepository`, unique couche d’accès aux versions.
- Module SQLite Néo-Crampon et tests d’installation/intégrité/repli.

Aucun second gestionnaire de téléchargements ou repository par version n’a été créé.
