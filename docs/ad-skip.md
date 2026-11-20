# Saut automatique des pubs, sponsors et jingles

Le saut ne concerne que les épisodes **déjà téléchargés**. Un flux streamé,
et le Cast (qui lit l’URL distante, pas le fichier local), ne sont ni
analysés ni sautés par ce mécanisme.

Les seuils ci-dessous viennent de mesures sur de vrais épisodes :
*Entrez dans l'Histoire*, *Petit Poisson Deviendra Podcast*,
*La Réu d'Écran Large*, *TFTC - Le Podcast*, *Petit Vulgaire*.
Les constantes vivent dans `lib/data/segment_match.dart`.

## Empreinte

Chromaprint, licence MIT ou LGPL. Ne pas prendre de bibliothèque AGPL
(Olaf, par exemple).

- Environ 8 valeurs de 32 bits par seconde. `hopMicros` vaut alors 125000
  (`chromaprintHopMicros`).
- Le blob `episode_fingerprints.data` est la suite de ces `uint32` en
  little-endian (`encodeFingerprint` / `decodeFingerprint`).

## Repérer un passage répété

Pour les épisodes téléchargés d’un même podcast :

1. Index inversé : chaque valeur d’empreinte pointe vers les
   `(episodeId, offset)` où elle apparaît.
2. Vote par décalage. Deux épisodes qui partagent une séquence ont un
   écart d’offsets constant. On compte, pour chaque paire d’épisodes, les
   deltas `offsetA - offsetB` qui s’alignent.
3. Deux valeurs se correspondent si leur distance de Hamming est ≤ 6 bits
   sur 32 (`chromaprintValuesMatch`). Ça absorbe le bruit d’un réencodage.
4. Une suite peut sauter jusqu’à 2 valeurs (`chromaprintMaxGapPoints`)
   sans être coupée en deux.
5. Une plage retenue comme pub, promo ou lecture sponsor dure au moins
   10 secondes (`adMinDurationMs`). Mesuré : Squarespace 29 s à 8 positions
   différentes, lectures sponsor ~70 s, outros de 15 à 47 s, cross-promos.
6. Le motif devient un `SegmentTemplate` (tranche d’empreinte, durée, type
   classé une fois) et un `SkipSegment` par épisode
   (`source = fingerprint`, `matches` = nombre d’épisodes).

## Jingles d’intro courts

Chromaprint ne cherche un jingle que dans les **180 premières secondes**
(`jingleSearchWindowMs`), à n’importe quel offset : un pré-roll dynamique
le décale. Exemple mesuré, jingle RTL à 0:00 ou à 27,7 s.

- Longueur minimale 3 s (`jingleMinDurationMs`).
- On ne garde le candidat que s’il revient dans au moins 3 épisodes
  (`jingleMinEpisodes`), à une position comparable : même offset, ou juste
  après le pré-roll (`acceptJingleCandidate`).
- Résultat mesuré : jingle RTL retrouvé sur 15/15 paires. À 3 s, aucun
  faux positif d’un podcast à l’autre. À 2 s, un seul : le sting Acast,
  commun au réseau. Précision des frontières : ±0,5 à 1 s
  (`stableOffsetSlackMs` = 2 s).

Une fois le jingle trouvé, on le stocke comme gabarit **du podcast** :
tranche Chromaprint (`segment_templates.fingerprint`) et gabarit log-mel
(`segment_templates.log_mel`). Les épisodes suivants ne cherchent que ce
gabarit, pas tout l’index.

## Log-mel

Pour les sons de moins de 3 s, et pour caler la frontière au dixième :

- 8 kHz, 40 bandes mel, hop 10 ms ;
- normalisation par trame, puis corrélation croisée normalisée glissante
  sur les 180 premières secondes ;
- seuil 0,85 (`logMelMatchThreshold`).

Mesuré sur un gabarit RTL de 2 s : 0,96–0,97 au bon endroit, ≤ 0,50 sur
les autres podcasts.

## Stings de réseau

Acast joue un sting d’environ 1,3 s à la fin de son bloc de pub inséré
(score log-mel 1,00 d’un podcast Acast à l’autre). `knownNetworkStings`
liste ces signatures. La fin du sting (`preRollEndFromSting`) marque la
fin du pré-roll, ce qui rend comparables des jingles décalés.

## Classement

`classifyRepeatedSegment` :

- toujours au début, offset stable ou collé au pré-roll → intro ;
- toujours dans la dernière minute → outro ;
- l’offset change d’un épisode à l’autre → pub / promo (insertion
  dynamique) ;
- offset stable au milieu → lecture sponsor fixe ;
- répétition vue dans une seule épisode (refrain, musique de fond :
  3 faux positifs mesurés) → candidat seulement, `autoSkip` faux. On
  l’enregistre avec `confirmed = false` pour que le lecteur ne le saute
  pas.

## Durée RSS et fichier

`itunes:duration` comparée à la durée réelle du fichier
(`approximateInsertedAdMs`) approche le temps de pub insérée. Observé :
de +30 s à +4 min 15. L’insertion dépend du User-Agent : l’écart se
calcule sur le fichier téléchargé, pas sur un autre téléchargement.

## Débit mesuré

Sur un cœur de Xeon virtualisé : `fpcalc` 2 à 3,5 s par heure d’audio,
appariement 2 à 97 ms par podcast. Estimation téléphone, non mesurée :
10 à 20 s par heure.

## Décodage

Sur Android, le PCM viendra de MediaExtractor et MediaCodec, puis
Chromaprint. Ce n’est pas branché : `PlaceholderEpisodeAudioAnalyzer` ne
calcule rien. `DownloadProgressNotifier._run` appelle quand même
l’analyseur après un téléchargement réussi, pour que le moteur réel se
branche sans changer le flux de téléchargement.

Les URI `content:` ne sont pas ouvertes comme un fichier. Le décodage
natif devra les prendre en charge.

## En attendant l’analyseur

Quand les chapitres d’un épisode sont enregistrés, un titre qui ressemble
à une pub ou un sponsor (`pub`, `publicité`, `sponsorisé`, et l’équivalent
dans d’autres langues) crée un `SkipSegment` avec `source = chapter`.
La fin du passage est le chapitre suivant, ou la durée de l’épisode.

## Lecture

`_maybeSkipSegment` (à côté de `_maybeSkipOutro`) avance à la fin du
passage si :

- la lecture vient d’un fichier téléchargé ;
- `autoSkipAds` est actif sur le podcast ;
- le type est dans `autoSkipKinds` ;
- `confirmed` n’est pas `false` (`null` = pas encore revu, on saute quand
  même ; `false` = ignoré, y compris un refrain d’une seule épisode).

Un retour manuel dans le passage (seek arrière, y compris depuis la
notification via `PlaybackHandler.onUserSeek`) le marque comme tenu : on
ne le ressaute pas. Un bandeau « Passage ignoré » propose d’annuler.

## Reste à faire

L’implémentation réelle de `EpisodeAudioAnalyzer` : décodage PCM,
Chromaprint, index inversé, vote avec les seuils ci-dessus, gabarit
log-mel, écriture des modèles et des passages.
