# Virgules de réseau

Une virgule est un son court, commun à plusieurs podcasts d’un même
hébergeur, collé à la fin d’un bloc de pub inséré. Podavio la cherche
dans les 180 premières secondes. Sa fin marque la fin du pré-roll.

Le fichier `manifest.json` liste les gabarits livrés avec l’application.
Il est vide : l’enregistrement Acast (environ 1,3 s, score log-mel 1,00
d’un podcast Acast à l’autre) n’est pas inclus. On ne fabrique pas ce
son. L’application peut l’apprendre toute seule quand le même extrait
revient à la fin d’un bloc dynamique dans au moins deux podcasts
téléchargés. Cette mémoire reste sur l’appareil.

## Ajouter un gabarit

1. Isoler le son (WAV mono). Deux secondes suffisent.
2. Produire le log-mel déjà utilisé par l’application : 8 kHz, 40 bandes,
   hop 10 ms, normalisation par trame, float32 little-endian. Le codage
   est celui de `encodeLogMel` (`lib/data/segment_match.dart`).
3. Déposer le fichier à côté de ce texte, par exemple `acast.f32`.
4. Ajouter une entrée dans `manifest.json` :

```json
{
  "stings": [
    {"name": "Acast", "durationMs": 1300, "file": "acast.f32"}
  ]
}
```

Le même schéma vaut pour une variante Acast, Ausha ou Audiomeans.
Un fichier absent est ignoré : l’application démarre quand même.
