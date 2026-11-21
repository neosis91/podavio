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
(`segment_templates.log_mel`). Les épisodes suivants cherchent ce gabarit
avant de reparcourir tout l’index.

## Log-mel

Pour les sons de moins de 3 s, et pour caler la frontière au dixième :

- 8 kHz, 40 bandes mel, hop 10 ms ;
- normalisation par trame, puis corrélation croisée normalisée glissante
  sur les 180 premières secondes ;
- seuil 0,85 (`logMelMatchThreshold`).

Mesuré sur un gabarit RTL de 2 s : 0,96–0,97 au bon endroit, ≤ 0,50 sur
les autres podcasts.

C’est branché. Le PCM 11 025 Hz déjà décodé pour Chromaprint est
rééchantillonné à 8 kHz dans le même isolate : on ne décode pas le
fichier une seconde fois. On ne garde que les 180 premières secondes
(`episode_log_mels`).

- Un passage Chromaprint d’au moins 3 s, dans cette fenêtre, est recalé
  sur le log-mel (début et fin au pas de 10 ms).
- En dessous de 3 s, le candidat est le premier son de l’épisode, ou le
  son juste après le pré-roll. On le garde s’il revient dans au moins
  3 épisodes à une position comparable. Le gabarit est de type `jingle`.
- L’épisode suivant est d’abord comparé aux gabarits log-mel déjà connus.

## Stings de réseau

Acast joue un sting d’environ 1,3 s à la fin de son bloc de pub inséré
(score log-mel 1,00 d’un podcast Acast à l’autre, ≤ 0,65 ailleurs).
`knownNetworkStings` en décrit la durée. Le son lui-même n’est pas dans
le dépôt : on ne le fabrique pas. `assets/stings/README.md` explique
comment ajouter un gabarit (Acast, une variante, Ausha, Audiomeans).

Quand une virgule connue est trouvée dans les 180 premières secondes,
le pré-roll `[0, fin de la virgule]` devient un `SkipSegment`
(`kind = ad`, `source = network`). Dans la dernière minute, le passage
va de la virgule à la fin de l’épisode. L’écran de classement l’affiche
avec le libellé « Virgule réseau ». L’avis reste ouvert, sauf si les
pubs du podcast sont déjà toutes confirmées ou toutes ignorées.

Un son court identique, collé à la fin d’un bloc dynamique, et retrouvé
dans au moins deux podcasts (score ≥ 0,95), est appris sur l’appareil
(`learned_network_stings`). Il n’est pas un gabarit du podcast.

## Classement

`classifyRepeatedSegment` :

- toujours au début, offset stable ou collé au pré-roll → intro ;
- toujours dans la dernière minute → outro ;
- l’offset change d’un épisode à l’autre → pub / promo (insertion
  dynamique) ;
- offset stable au milieu → lecture sponsor fixe ;
- répétition vue dans une seule épisode → voir ci-dessous. Jamais
  sautée : `autoSkip` faux, `confirmed = false`.

## Musique dans une seule épisode

Trois faux positifs mesurés venaient d’une répétition **interne** à
l’épisode : refrain de *BADABOUM* (14 s et 18 s, Petit Vulgaire), lit
musical (18 s à 0:10 et 2:49, Petit Poisson Deviendra Podcast), épisode
musical *En boucle* (18 s, TFTC). Une pub, une promo ou un jingle
d’intro reviennent **d’un épisode à l’autre**. On ne touche pas à ce
cas, même quand le son est musical : un jingle d’intro l’est souvent.

Le PCM 11 025 Hz déjà décodé pour Chromaprint est noté dans le même
isolate, une valeur par seconde (`speech_music.dart`). Pas de modèle.
Pour chaque seconde :

- variance du taux de passages par zéro, trames de 20 ms (consonnes
  contre voyelle ou note tenue) ;
- part de trames sous la moitié de l’énergie moyenne (pauses) ;
- part de l’enveloppe à 4 Hz (débit syllabique), Goertzel ;
- flux spectral entre quatre FFT de 512 points ;
- harmonicité : pic d’autocorrélation entre 80 et 500 Hz ;
- stabilité du chroma sur ces quatre spectres.

Le score de parole mélange ces rampes. Un son continu, au taux de
passages par zéro stable, est rabattu : le changement de note d’un
refrain fait monter le flux, mais ce n’est pas de la parole. Le chroma
seul ne sépare pas une voyelle tenue d’un accord ; il ne pèse que peu.

Mesuré sur signaux synthétiques, même machine que le débit plus bas :

| Signal | Score |
| --- | --- |
| Lit tonal (accord continu) | 0,03 |
| Refrain chanté, notes enchaînées sans silence | 0,18 |
| Bruit modulé à 4 Hz, bouffées et pauses | 0,83 |
| Parole voisée (voyelle, consonne, silence) | 0,89 |
| La même parole sur le lit tonal | 0,79 |

Seuil de rejet : **0,45** (`intraMusicRejectRatio`). L’écart entre le
chant (0,18) et la parole sur lit (0,79) laisse de la marge.

Règle, seulement si le motif ne sort pas de l’épisode :

1. Score sous 0,45 → on ne l’enregistre pas.
2. Trois départs ou plus, intervalles de 8 s à 3 min, écart-type /
   moyenne ≤ 0,18 (`refrainIntervalCvMax`) → refrain. On le jette,
   sauf si le score de parole est ≥ 0,75
   (`intraPeriodicSpeechEscape`) : une lecture répétée à intervalle
   régulier reste un candidat.
3. Sinon candidat, `confirmed = false`, jamais sauté automatiquement.
   Deux occurrences sans période (la pub entendue deux fois dans le
   seul épisode déjà téléchargé) restent un candidat.

Sans chronologie (empreinte calculée avant cette note), seule la
période décide. Le candidat ancien, non périodique, reste en base
jusqu’à la prochaine analyse. Au démarrage et via le bouton de
l’écran, un épisode dont `episode_fingerprints.speech` est NULL est
repassé. Un blob de longueur nulle (fichier trop court pour une
seconde) compte comme déjà calculé.

La confiance (0–100) est stockée sur `skip_segments.confidence` et
`segment_templates.confidence` (schéma 22). Un motif inter-épisodes
vaut 90. Un candidat intra-épisode vaut
`(ratio − 0,25) × 110`, moins 12 s’il est périodique, borné à 8–80.
Sous 50 (`lowConfidenceCutoff`), l’écran de classement le replie
derrière « Afficher les passages incertains ». Le tri dans chaque type
est la confiance décroissante. La confiance ne déclenche pas de saut.

Coût mesuré sur la machine de développement (CPU virtualisé), 20 s de
PCM tonal extrapolés : **environ 0,7 s par heure** d’audio. Le test
refuse au-delà de 8 s/h. Ajouté aux 4 à 6 s de Chromaprint, l’heure
reste du même ordre. L’estimation téléphone, 10 à 20 s, n’a pas été
remesurée.

## Durée RSS et fichier

`itunes:duration` comparée à la durée réelle du fichier
(`approximateInsertedAdMs`) approche le temps de pub insérée. Observé :
de +30 s à +4 min 15. L’insertion dépend du User-Agent : l’écart se
calcule sur le fichier téléchargé, pas sur un autre téléchargement.

## Débit mesuré

Sur la machine de développement (CPU virtualisé), le portage Dart
produit exactement la même empreinte que `fpcalc` 1.5.1 (algorithme 2).
Huit secondes de PCM prennent environ 6 ms. Un épisode de 30 s, PCM
déjà en mémoire, empreinte et log-mel compris, prend 70 à 85 ms dans
l’isolate. L’appariement Chromaprint de deux épisodes de 30 s reste
de l’ordre de quelques millisecondes ; y ajouter la recherche log-mel
porte le total vers 0,2 s. Le log-mel ne couvre que 180 s, donc une
heure d’audio reste dominée par Chromaprint, environ 4 à 6 s sur cette
machine, plus environ 0,7 s pour la note parole/musique (voir plus
haut). L’estimation téléphone, 10 à 20 s par heure, n’a pas été
remesurée sur un appareil.

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

Déposer le vrai gabarit Acast (ou Ausha, Audiomeans) dans
`assets/stings/`, comme décrit dans `assets/stings/README.md`.
Sans ce fichier, seules les virgules apprises sur l’appareil sont
cherchées.
