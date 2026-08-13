# Ancien emplacement Strong

Les sources officielles sont désormais conservées dans
`bible_builder/sources/stepbible/` et la construction reproductible se lance
avec :

```powershell
python bible_builder/build_strong_db.py
```

Ce dossier est gardé uniquement pour ne pas casser d’anciens chemins locaux.
Le générateur ne se rabat plus sur `bible.db` et ne modifie jamais cette base.
