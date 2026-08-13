# Candidats au dictionnaire biblique français

Décision du 13 août 2026, prise avant toute intégration de contenu.

| Titre | Auteur | Date | Source officielle | Licence constatée | Format / taille | Domaine public | Redistribution dans l’application | Attribution | Qualité | Décision |
|---|---|---:|---|---|---|---|---|---|---|---|
| Dictionnaire de la Bible | Fulcran Vigouroux et contributeurs | 1895–1912 | [Wikisource](https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible_-_Vigouroux) | Œuvre et scans dans le domaine public ; transcription Wikisource sous CC BY-SA 4.0 | 5 DjVu, 345 225 088 octets, 5 756 pages ; 781 articles structurés annoncés | OUI pour l’œuvre et les scans | OUI pour un lot incomplet, sous CC BY-SA 4.0 et avec historique d’attribution | Vigouroux, Letouzey et Ané, Gallica, Wikisource et contributeurs | Couverture affichée : T1 98 %, T2 64 %, T3 48 %, T4 28 %, T5 69 % ; images, grec et hébreu encore manquants | **Audit terminé, import en attente d’accord** : rapport préalable disponible |
| Glossaire de la Bible David Martin 1744 | Auteur numérique non indiqué | module 2010 | [CrossWire FreGBM](https://crosswire.org/sword/modules/ModInfo.jsp?modName=FreGBM) | « Copyrighted; Freely distributable » | Module SWORD, 127,13 Kio, environ 970 définitions | INCERTAIN pour la transcription | NON démontré pour conversion, adaptation et redistribution SQLite | CrossWire, biblemartin.com et auteur à identifier | Petit glossaire, pas un dictionnaire général complet | **Refusé** sans permission explicite de conversion/reformatage |
| Dictionnaire Westphal et éditions modernes | auteurs/éditeurs divers | variable | aucune source ouverte officielle validée | protégée ou non documentée | variable | NON/INCERTAIN | NON | variable | parfois élevée | **Refusé** sans licence explicite |

## Conclusion

Vigouroux est juridiquement réutilisable, mais seulement comme corpus incomplet
et attribué sous CC BY-SA 4.0 lorsque la transcription Wikisource est utilisée.
Le rapport préalable chiffre la couverture et propose un import déterministe.
ECHO BIBLE n’embarque encore aucun extrait et ne présente pas cette édition
comme complète.

Le module Flutter recherche à l’avenir une base installée séparément au schéma suivant :

```sql
CREATE TABLE dictionary_entries(
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  normalized_title TEXT NOT NULL,
  content TEXT NOT NULL,
  source TEXT NOT NULL,
  author TEXT,
  related_references TEXT
);
```

La page affiche clairement l’absence de ressource validée. Dès qu’une source complète et compatible sera approuvée, le repository pourra l’ouvrir en lecture seule sans modifier `bible.db`.
