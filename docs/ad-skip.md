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

- Environ 8,08 valeurs de 32 bits par seconde. Le pas réel est
  `1365 / 11025` s, soit 123809 µs (`chromaprintStoredHopMicros`),
  la valeur écrite dans `hop_micros`. `chromaprintHopMicros` (125000)
  reste l’approximation du premier jet.
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

Sur la machine de développement (CPU virtualisé), le portage Dart
produit exactement la même empreinte que `fpcalc` 1.5.1 (algorithme 2).
Huit secondes de PCM prennent environ 6 ms. Un épisode de 30 s, une
fois le PCM en mémoire, prend 30 à 50 ms dans l’isolate, soit de
l’ordre de 4 à 6 s par heure d’audio. L’appariement de deux épisodes
de 30 s prend 1 à 3 ms ; trois empreintes d’environ quatre minutes
restent bien sous la seconde. L’estimation téléphone, 10 à 20 s par
heure, n’a pas été remesurée sur un appareil.

## Décodage

Branché.

- Android : MediaExtractor et MediaCodec, mono 11025 Hz, écrit au fil
  de l’eau. Les URI `content:` passent par le ContentResolver.
- iOS et macOS : AVFoundation, même format.
- Linux et Windows : `ffmpeg` s’il est installé (`-ac 1 -ar 11025`),
  sinon un message dans le journal et pas d’empreinte.

L’empreinte et l’appariement tournent dans un isolate, un épisode à
la fois. Après un téléchargement, au démarrage, et à l’ouverture de
l’écran de classement, les épisodes téléchargés sans empreinte sont
mis en file. Le même écran a le bouton « Analyser les épisodes
téléchargés ». Effacer un téléchargement retire l’empreinte et les
passages `fingerprint`. Un avis déjà posé (`confirmed`) est conservé
si l’analyse retrouve le passage. Un gabarit ignoré (`confirmed`
false) le reste, y compris pour un épisode nouveau.

Le gabarit log-mel (`segment_templates.log_mel`) n’est pas encore
rempli. Les sons de moins de 3 s et le calage au dixième de seconde
attendent cette étape. Les stings réseau (Acast) ne sont pas détectés
dans l’audio : la constante existe, le pré-roll ne vient que de
l’écart entre la durée RSS et la longueur de l’empreinte.

## Chapitres

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

Le gabarit log-mel (sons de moins de 3 s, frontière au dixième) et la
détection des stings de réseau dans l’audio.
