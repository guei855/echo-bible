# Sources STEPBible

Source officielle : <https://github.com/STEPBible/STEPBible-Data>

Les lexiques, textes originaux tagués et tables morphologiques de ce dossier
proviennent de la branche `master` officielle. Leurs en-têtes et attributions
doivent être conservés. Ils reconstruisent `assets/database/strong.db` avec :

```powershell
python bible_builder/build_strong_db.py
```

Le générateur exclut volontairement la colonne `Meaning` de TBESH, dont
l’en-tête demande une autorisation Online Bible supplémentaire. `definition_fr`
reste NULL en l’absence de source française compatible et vérifiée.

TAHOT et TAGNT alimentent `strong_occurrences` avec les tokens hébreux et
grecs, leurs références, positions, lemmes et morphologies. TEHMC et TEGMC
alimentent `morphology_codes`. Ces données ne sont jamais alignées
artificiellement avec les mots de la traduction française.
