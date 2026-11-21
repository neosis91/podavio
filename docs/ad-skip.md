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
   Le popcount se fait par octets.
4. Une suite peut sauter jusqu’à 2 valeurs (`chromaprintMaxGapPoints`)
   sans être coupée en deux. Trois valeurs manquantes la coupent.
5. La suite doit encore compter au moins 55 % de valeurs qui collent
   (`chromaprintMinAgreement`). Un pont d’une valeur sur trois, assez
   long pour passer les 10 s, est rejeté. Une fenêtre d’environ 1 s
   (8 points) avec moins de 3 correspondances coupe la suite
   (`_splitWeak`).
6. Le vote retient le premier et le dernier offset de chaque décalage.
   Si ces ancres sont trop espacées pour le nombre de votes
   (`écart > votes × 80 + 128`), le décalage est un hasard : on ne
   parcourt pas le fichier. Sinon la distance de Hamming ne s’étend
   qu’autour de cette plage.
7. Une plage retenue comme pub, promo ou lecture sponsor dure au moins
   10 secondes (`adMinDurationMs`). Mesuré : Squarespace 29 s à 8 positions
   différentes, lectures sponsor ~70 s, outros de 15 à 47 s, cross-promos.
8. Le motif devient un `SegmentTemplate` (tranche d’empreinte, durée, type)
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
  commun au réseau. L’offset « stable » tolère 2 s
  (`stableOffsetSlackMs`). La frontière, elle, est resserrée ensuite
  (voir plus bas) : le pas Chromaprint reste ~124 ms, le recalage vise
  le pas de 20 ms.

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

C’est branché. Le PCM 11 025 Hz est rééchantillonné à 8 kHz pendant
la lecture du fichier, dans l’isolate d’empreinte : on ne décode pas
le fichier une seconde fois, et on ne garde que les 180 premières
secondes (`episode_log_mels`).

La recherche (jingles courts, recalage, virgules) ne tourne pas sur
l’isolate d’interface, qui est le thread principal Android. Elle part
dans un isolate annulable. Le spectre est une FFT réelle (les échantillons
sont réels). La recherche glisse d’abord de 4 trames (40 ms), puis
recale à ±40 ms au pas de 10 ms. Un score déjà trop bas pour le seuil
demandé est abandonné avant la fin de l’aiguille. On ne compare
que les 12 épisodes les plus récents (`logMelCompareEpisodeCap`) et au
plus 24 frontières de bloc. Les écritures tiennent dans une
transaction, pour ne pas reconstruire l’écran de classement à chaque
ligne. Un jingle déjà enregistré sur un épisode plus ancien n’est pas
effacé : il n’est simplement plus repris dans cette fenêtre.

- Un passage Chromaprint d’au moins 3 s, dans cette fenêtre, est recalé
  sur le log-mel (début et fin au pas de 10 ms). Si un autre épisode
  porte le même gabarit, les deux spectres se recoupent
  (`refinePairedLogMelEdges`) et la frontière se pose sur la transition
  de similarité, pas seulement sur le silence.
- L’empreinte est accompagnée d’une enveloppe d’énergie sur tout
  l’épisode : un octet d’RMS toutes les 20 ms
  (`episode_fingerprints.envelope`, schéma 24, colonne SQL hors Drift).
  Autour du match grossier (±1,5 s), on cherche où les enveloppes
  commencent et cessent de se correspondre. Le même décalage, médiane
  des paires, est appliqué à toutes les occurrences. Sans contraste
  (écart de médiane < 0,12), on garde la frontière Chromaprint.
  Une enveloppe absente ne relance pas le décodage : les épisodes déjà
  analysés restent en cache. Le bouton d’analyse, ou un épisode nouveau,
  remplit la colonne.
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
jusqu’à la prochaine analyse. Une chronologie absente (`speech` NULL)
ne relance plus le décodage toute seule : c’est ce qui rejouait
l’analyse à chaque ouverture, y compris après un force-stop. Le bouton
« Analyser les épisodes téléchargés » recalcule encore une chronologie
manquante. Un blob de longueur nulle (fichier trop court pour une
seconde) compte comme déjà calculé.

La note est faite seconde par seconde (`SpeechTimelineBuilder`) : une
seconde de PCM à la fois, pas une seconde copie de l’épisode. Le
fichier PCM est effacé à la fin de l’analyse, donc la chronologie est
gardée en base. La recalculer seulement sur les plages candidates
demanderait un second décodage.

La confiance (0–100) est stockée sur `skip_segments.confidence` et
`segment_templates.confidence` (schéma 22). Un motif inter-épisodes
vaut 90. Un candidat intra-épisode vaut
`(ratio − 0,25) × 110`, moins 12 s’il est périodique, borné à 8–80.
Sous 50 (`lowConfidenceCutoff`), l’écran de classement le replie
derrière « Afficher les passages incertains ». Le tri dans chaque type
est la confiance décroissante. La confiance ne déclenche pas de saut.

Coût mesuré sur la machine de développement (CPU virtualisé), 120 s de
PCM tonal : **34 puis 35 ms** de note, soit environ 1,0 s par heure.
Avant la FFT réelle, le même banc donnait 43 à 54 ms. Le test refuse
au-delà de 8 s/h. L’estimation téléphone n’a pas été remesurée.

## Durée RSS et fichier

`itunes:duration` comparée à la durée réelle du fichier
(`approximateInsertedAdMs`) approche le temps de pub insérée. Observé :
de +30 s à +4 min 15. L’insertion dépend du User-Agent : l’écart se
calcule sur le fichier téléchargé, pas sur un autre téléchargement.

## Débit mesuré

Sur la machine de développement (CPU virtualisé), le portage Dart
produit exactement la même empreinte que `fpcalc` 1.5.1 (algorithme 2),
y compris après le passage à la FFT réelle.

Banc `test/analysis_speed_test.dart`, même machine, PCM tonal synthétique
déjà en fichier (pas de décodage natif). Moyenne de deux passages avant
ces changements, puis après (le cas dense n’a été mesuré qu’une fois
avant, à 563 ms) :

| Étape | Avant | Après |
| --- | --- | --- |
| 120 s, total Dart | 421 ms | 163 ms |
| dont empreinte | 143 ms | 50 ms |
| dont parole/musique | 49 ms | 35 ms |
| dont spectre log-mel (fenêtre 180 s) | 166 ms | 41 ms |
| lecture, rééchantillonnage, enveloppe (reste) | ~63 ms | ~38 ms |
| 6 épisodes × 20 min, hashes distincts | 56 ms | 34 ms |
| 4 épisodes × 30 min, hashes répétés | 563 ms | 207 ms |
| 8 recherches log-mel dans 20 s | 228 ms | 92 ms |

L’empreinte d’une heure tombe d’environ 4,3 s à 1,5 s sur cette machine.
Le spectre log-mel ne couvre que 180 s, donc il ne grandit plus avec
l’épisode. Les écritures en base restent un blob par épisode : elles
ne sont pas le coût. Le décodage natif (MediaCodec, AVFoundation,
ffmpeg) n’est pas dans ce banc ; il était déjà hors de l’isolate
d’interface.

Mémoire, même banc de 120 s : tampons retenus 7,73 Mo contre 7,73 Mo
avant (l’enveloppe de 120 s ajoute 6 ko). Delta RSS environ 17 Mo,
comme avant, pic ~158 Mo contre ~156 Mo. Le test du fichier silencieux
de 20 min exige encore que les tampons retenus restent sous la moitié
du fichier. Le plafond visé reste celui du chemin par blocs : pas une
seconde copie de l’épisode, et pas un second isolate de décodage.

Fichier silencieux de 2 h (158,8 Mo, 11 025 Hz, mono, 16 bits), mesure
d’avant cette accélération, même machine. L’ancien chemin gardait le
fichier et une copie `Int16` : 318 Mo de RSS. Le chemin par blocs
finissait en 5,7 s, avec 12 Mo retenus et +36 Mo de RSS. Ce plafond
n’est pas relevé.

## Décodage

Branché.

- Android : MediaExtractor et MediaCodec, sur un thread de fond (pas
  le thread principal), mono 11025 Hz, écrit au fil de l’eau. Les URI
  `content:` passent par le ContentResolver. La boucle s’arrête si la
  fin de flux n’arrive pas : 8 lectures vides comptent comme une fin,
  200 attentes après la fin d’entrée, 500 si l’entrée ne se termine
  pas, et un délai de 6 minutes (`deadlineMs`). Un dépassement efface
  le fichier partiel et renvoie un échec, pour ne pas enregistrer une
  empreinte tronquée.
- iOS et macOS : AVFoundation, même format, hors du thread principal,
  avec le même délai. Un appel `copyNextSampleBuffer` qui ne revient
  pas peut dépasser ce délai ; le délai Dart, lui, libère la file.
- Linux et Windows : `ffmpeg` s’il est installé (`-ac 1 -ar 11025`),
  lancé avec `Process.start` et tué au bout de 6 minutes. Sinon un
  message dans le journal et pas d’empreinte.

Le fichier PCM n’est pas renvoyé dans le canal de plateforme : seul le
chemin, le taux, le nombre d’échantillons et la durée traversent. Le
fichier est ensuite lu par blocs de 8192 échantillons. Chromaprint, la
note parole et le rééchantillonnage 8 kHz avancent ensemble. Le log-mel
ne conserve que les 180 premières secondes.

L’empreinte et l’appariement tournent dans un isolate, un épisode à
la fois. On ne lance pas un second décodage en parallèle : ça
doublerait le pic de RAM. L’isolate est tué si l’épisode dépasse
8 minutes (`audioAnalysisBudget`), ou si l’analyse automatique est
coupée. Une fin en retard ne réécrit pas une ligne déjà marquée en
échec.

Pendant une lecture, l’isolate d’empreinte marque une pause de 12 ms
après chaque bloc de 8192 échantillons (`AnalysisPace`, mode `play`),
pour ne pas garder un cœur pendant que l’audio joue. Au premier plan
sans lecture, il cède seulement l’ordonnancement (`front`). En
arrière-plan, sans lecture, il va au plus vite. L’isolate d’interface
ne calcule pas.

La file dédoublonne : le même épisode demandé deux fois (démarrage,
écran, fin de téléchargement) n’est décodé qu’une fois. Un second
`force` pendant l’analyse en cours est rejoué une fois à la suite.

Après un téléchargement, au démarrage, et à l’ouverture de l’écran de
classement, les épisodes téléchargés **sans ligne**
`episode_fingerprints` sont mis en file, si le réglage « Analyser
automatiquement les téléchargements » est allumé (activé par défaut,
écran de classement et réglages de lecture). Le même écran a le bouton
« Analyser les épisodes téléchargés », qui reste disponible quand le
réglage est coupé.

Une analyse qui n’a pas fini (`running` au redémarrage, délai dépassé,
décodage nul) est marquée `failed` dans `episode_fingerprints.status`
(colonne SQL hors schéma Drift, défaut `done`). Le démarrage ne la
reprend pas. Le bouton, lui, la reprend. Effacer un téléchargement
retire la ligne, donc un nouveau téléchargement peut être analysé.

Un avis déjà posé (`confirmed`) est conservé si l’analyse retrouve le
passage. Un gabarit ignoré (`confirmed` false) le reste, y compris
pour un épisode nouveau. L’index inversé d’un épisode n’est construit
qu’une fois, les votes de décalage sont bornés (8192 clés), et un
épisode nouveau n’est comparé qu’aux autres : les paires déjà connues
restent couvertes par les gabarits.

## Chapitres

Quand les chapitres d’un épisode sont enregistrés, un titre qui ressemble
à une pub ou un sponsor (`pub`, `publicité`, `sponsorisé`, et l’équivalent
dans d’autres langues) crée un `SkipSegment` avec `source = chapter`.
La fin du passage est le chapitre suivant, ou la durée de l’épisode.

L’écran des chapitres couvre tout l’épisode, du début à la fin. Chaque
passage détecté est un chapitre (Publicité, Virgule réseau, Intro, Outro,
et les autres libellés). Deux pubs qui se suivent restent deux chapitres.
Entre ces passages, le titre vient du podcast s’il en a donné un pour cet
intervalle. Sinon le chapitre s’appelle « Épisode ». La pub et la virgule
collée juste après sont deux chapitres, mais un seul saut à la lecture.

## Frontières

La fin d’une pub peut s’arrêter sur un creux alors que le son continue.
Si l’enveloppe retrouve du niveau puis un silence tenu dans les 4 secondes,
la fin avance jusqu’à ce silence. Une virgule d’environ 3 secondes répétée
juste après cette fin, dans au moins trois épisodes, devient un passage
`jingle` de source `network`. La comparaison retire la moyenne de chaque
trame : sur la parole, la cosinus brute du log-mel vaut presque 1 partout. Un outro découpé en plusieurs bouts dans la
dernière minute est recollé (trou d’au plus 5 secondes) et, s’il s’arrête
à moins de 15 secondes de la fin du fichier, va jusqu’au bout.

## Lecture

`_maybeSkipSegment` (à côté de `_maybeSkipOutro`) avance à la fin du
passage, ou à la fin de la virgule collée juste après une pub. La liste des passages est lue une fois au démarrage de la
lecture d’un fichier téléchargé (`listSkipSegments` vers `_skipWindows`)
et le test de position ne refait pas de requête. Le saut a lieu si :

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
