# Echo Étude V1

## Architecture

Echo Étude réutilise `PersonalStudiesScreen` et `PersonalStudyEditorScreen`.
Il n'existe pas de second écran ou dépôt concurrent.

- `personal_studies` contient les métadonnées du document : type, référence
  principale, tags, état, favori et épinglage.
- `study_sections` est la table persistante des `StudyBlock`. Le champ
  `payload_json` conserve les données propres à chaque bloc et `block_id`
  fournit une identité stable pour l'édition et le réordonnancement.
- Les anciennes sections sont migrées de manière additive à l'ouverture de la
  base. Les tables bibliques et les bases de ressources ne sont pas utilisées
  pour stocker les études.
- L'éditeur sauvegarde un instantané transactionnel après un debounce de
  700 ms et lors du passage de l'application en arrière-plan.

## Blocs V1

`text`, `heading`, `verse`, `verseRange`, `verseLink`, `strong`, `dictionary`,
`crossReferences`, `comparison`, `quote`, `divider` et `image`.

Les blocs bibliques conservent l'identité canonique du passage en plus du texte
figé. Les blocs sont ouvrables dans le lecteur, Strong ou Vigouroux et leur ordre
est persistant.

## Export

La couche `StudyExportService` définit les formats PDF, DOCX, texte et partage.
L'export texte et le partage Android/WhatsApp sont actifs en V1. Le projet ne
contient actuellement aucune bibliothèque de génération PDF ou DOCX; ces deux
adaptateurs restent donc volontairement désactivés dans l'interface au lieu de
produire des fichiers invalides. Le rendu texte commun est indépendant de
l'interface et servira de source aux futurs adaptateurs PDF/DOCX.

L'insertion d'image V1 conserve une légende ou un chemin local dans un bloc
structuré. La copie gérée du fichier dans le stockage de l'application sera à
ajouter avec le futur sélecteur de médias.
