# Page de paramètres globale du saut des pubs — cahier des charges

## But
Une page dans les paramètres de l'application qui regroupe l'analyse (pubs, virgules, sponsors, outros) de tous les podcasts, en plus de la gestion existante podcast par podcast, qui reste en place.

## Podcasts affichés
- La page affiche les analyses de tous les podcasts qui ont déjà au moins un épisode téléchargé.
- Un podcast sans aucun téléchargement n'apparaît pas sur la page, même s'il est suivi.
- Si un podcast perd tous ses téléchargements, il disparaît de la liste ; ses séquences enregistrées ne sont pas effacées.
- Un seul épisode téléchargé suffit pour qu'un podcast apparaisse (pas deux).
- Avec un seul téléchargement, la page montre les séquences déjà connues qui s'appliquent ; la comparaison épisode contre épisode commence dès qu'un deuxième épisode est téléchargé.

## Autres points déjà décidés
- Regrouper les empreintes par source d'hébergement (par exemple audiomeans).
- Exclure de la comparaison les portions de plus de 2 minutes.
- Les types de passages à sauter et l'interrupteur de saut automatique deviennent des réglages globaux.
- Tout reste local sur l'appareil, sans requête réseau.
