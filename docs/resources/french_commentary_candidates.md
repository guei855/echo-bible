# Audit des commentaires bibliques français

Audit effectué le 13 août 2026. Aucun fichier n'a été téléchargé ni ajouté à
l'application. Une œuvre ancienne dans le domaine public n'est pas pour autant
une base structurée : l'alignement livre/chapitre/verset doit être contrôlé avant
toute publication dans ECHO BIBLE.

| Classe | Ressource | Auteur, date, langue | Source officielle | Licence et réutilisation | Format, taille, couverture | Décision |
| --- | --- | --- | --- | --- | --- | --- |
| A | *Commentaire littéral sur tous les livres de l'Ancien et du Nouveau Testament* — fac-similé de la Genèse | Augustin Calmet, 1707, français | Wikimedia Commons/Wikisource | Œuvre et fichier signalés domaine public ; redistribution et adaptation permises avec conservation des mentions de provenance | PDF, 991 pages pour la Genèse, couverture du corpus disponible à vérifier volume par volume | Réutilisable juridiquement, mais pas intégrable immédiatement comme données par verset : OCR et contrôle éditorial requis |
| B | Transcription Wikisource du *Commentaire littéral* | Augustin Calmet ; contributeurs Wikisource, français | Wikisource | CC BY-SA (attribution et partage dans les mêmes conditions) ; adaptation permise sous la même licence | HTML, EPUB, MOBI et PDF ; taille variable ; transcription actuellement incomplète/hétérogène | Candidat prioritaire après inventaire de couverture, export, attribution et validation humaine |
| C | Reproductions Gallica de commentaires français du domaine public | Auteurs divers | BnF/Gallica | Réutilisation non commerciale libre avec mention de source ; licence/autorisation payante requise pour un usage commercial des reproductions | PDF/OCR, tailles et couvertures variables | Ne pas embarquer tant que le modèle de diffusion d'ECHO BIBLE et l'autorisation nécessaire ne sont pas clarifiés |
| C | *Bible annotée de Neuchâtel* | Collectif, fin du XIXe siècle, français | Aucune édition numérique complète avec licence explicite et données par verset n'a été validée lors de cet audit | Œuvre ancienne, mais droits de la numérisation/transcription non établis | Sources web ou scans dispersés ; couverture/tailles non vérifiées | Permission ou source ouverte explicite requise |
| D | Traductions françaises de Matthew Henry trouvées sur des sites bibliques | Matthew Henry, traduction française | Sources tierces diverses | Licence de la traduction française non démontrée | HTML/base propriétaire selon le site | À éviter ; ne pas copier, notamment depuis BibleStrong |

## Décision d'intégration

Il n'existe pas encore, parmi les sources validées, de corpus français à la
fois complet, proprement structuré par verset, téléchargeable et redistribuable
sans ambiguïté. `commentaries.db` n'est donc pas créé. Le gestionnaire de
ressources reste sans URL de téléchargement et l'interface annonce honnêtement :
« Les commentaires bibliques français ne sont pas encore installés. »

Le schéma attendu par le repository pour une future base validée est :

```sql
CREATE TABLE commentaries (
  id INTEGER PRIMARY KEY,
  author TEXT NOT NULL,
  work_title TEXT NOT NULL,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse_start INTEGER NOT NULL,
  verse_end INTEGER,
  content TEXT NOT NULL,
  language TEXT NOT NULL,
  source TEXT NOT NULL,
  license TEXT
);
CREATE INDEX idx_commentaries_book_chapter_verse
  ON commentaries(book_id, chapter, verse_start);
```

Sources consultées :

- https://fr.wikisource.org/wiki/Commentaire_litteral_sur_tous_les_livres_de_l%27Ancien_et_du_Nouveau_Testament
- https://fr.wikisource.org/wiki/Fichier:Commentaire_litteral_sur_tous_les_livres_de_l%27Ancien_et_du_Nouveau_Testament_-_La_Gen%C3%A8se.pdf
- https://gallica.bnf.fr/accueil/fr/html/conditions-dutilisation-de-gallica
- https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=JFB (anglais uniquement, donc non retenu)
