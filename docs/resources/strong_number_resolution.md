# Résolution des numéros Strong et Extended Strong

ECHO BIBLE conserve les identifiants fournis par STEPBible sans les convertir en
un autre numéro lexical.

## Recherche exacte

`StrongRepository.findByNumber` normalise seulement la casse et les zéros de
présentation (`h0430` → `H430`). Il recherche ensuite une égalité exacte dans :

1. `strong_number` ;
2. `extended_strong_number` ;
3. `disambiguated_strong_number` ;
4. `unified_strong_number`.

Si un numéro classique inférieur à 9000 n’a aucune entrée exacte, le repository
peut choisir sa première variante lexicale attestée (`H3588` → `H3588A`). Ce
repli est interdit pour les séries grammaticales 9000+, afin que `H9003` ne
puisse jamais être remplacé par un numéro ressemblant.

## Classification d’affichage

- Numéro ordinaire inférieur à 9000 : **Strong classique**.
- Numéro avec extension lexicale attestée (suffixe ou identifiant Extended
  différent) : **Extended Strong lexical**.
- Série STEPBible `H9000+` : **Extended Strong grammatical**. Ces entrées
  représentent notamment des préfixes, prépositions et éléments grammaticaux.

Exemple : `H9003` est conservé comme entrée autonome pour `/ב`, translittéré
`b`, morphologie `Prefix`, sens source `in/on/with`. Il n’est pas ramené vers
un Strong hébreu classique.

Les occurrences utilisent une égalité exacte sur `strong_number`. La recherche
générale peut proposer plusieurs résultats préfixés, mais le choix d’un résultat
ouvre toujours son identifiant exact.
