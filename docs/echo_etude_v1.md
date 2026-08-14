# Echo Étude V1.1

## Architecture

Echo Étude conserve un seul parcours, `PersonalStudiesScreen` vers
`PersonalStudyEditorScreen`, et la base dédiée `echo_studies.db`.

- `study_documents` contient le titre, le type, la référence principale, les
  tags, l’état, le favori et l’épinglage.
- `study_blocks` conserve l’ordre et le `payload_json` des contenus et
  ressources. Les sauvegardes restent transactionnelles.
- L’éditeur enregistre après un debounce de 700 ms et lors du passage de
  l’application en arrière-plan.
- Aucun schéma biblique ou dictionnaire n’est utilisé pour stocker une étude.

## Traitement de texte V1.1

Le moteur est Flutter Quill 11.5.1, distribué sous licence MIT. Le document
riche est stocké dans les blocs texte avec le format versionné
`quill_delta_v1`. Le Delta représente directement le gras, l’italique, le
soulignement, le barré, les tailles, couleurs, surlignages, alignements,
citations, listes, retraits et titres : aucun marqueur de mise en forme n’est
affiché à l’utilisateur.

À l’ouverture, les blocs V1 `text`, `heading` et `quote` sont regroupés en
zones riches. Les anciens marqueurs (`**`, `_`, `<u>`, `~~`, `<mark>` et
`<color>`) sont convertis en attributs Delta. Les ressources spécialisées
(`verse`, `verseRange`, `verseLink`, `strong`, `dictionary`,
`crossReferences`, `comparison`, `divider`, `image`) restent des blocs
structurés intercalés dans la page. Cette migration est additive et ne modifie
ni les identifiants du document ni la structure SQLite.

## Interface

Le texte courant est une page continue sans carte, bordure, poignée ou bouton
de suppression permanent. Une ressource garde une carte visuelle légère ; son
menu de déplacement ou suppression n’apparaît qu’après un appui long. La barre
fixe donne accès aux styles riches, à l’insertion de ressources et à
annuler/rétablir.

## Export

`StudyExportService` définit les formats PDF, DOCX, texte et partage. Le texte
et le partage sont actifs. PDF et DOCX restent volontairement indisponibles
tant qu’un adaptateur de génération conforme n’est pas ajouté : leur future
source sera le Delta riche et les blocs structurés, jamais une simulation ou
un fichier renommé. Le rendu texte actuel extrait uniquement le contenu lisible
et omet les métadonnées techniques du Delta.
