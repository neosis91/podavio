import 'dart:math' as math;
import 'dart:typed_data';

import 'skip_segments.dart';

/// Distance de Hamming max entre deux valeurs Chromaprint (sur 32 bits).
const chromaprintMaxHammingBits = 6;

const chromaprintBits = 32;

/// Trous tolérés dans une suite de valeurs qui se correspondent.
const chromaprintMaxGapPoints = 2;

/// Pub, promo ou lecture sponsor assez longue pour Chromaprint.
const adMinDurationMs = 10000;

/// En dessous, Chromaprint ne suffit pas : gabarit log-mel.
const jingleMinDurationMs = 3000;

/// Les jingles d’intro ne sont cherchés que dans cette fenêtre.
/// Le décalage peut être n’importe où dedans (pré-roll dynamique).
const jingleSearchWindowMs = 180000;

/// Un jingle n’est gardé que s’il revient dans au moins autant d’épisodes.
const jingleMinEpisodes = 3;

/// Deux offsets « au même endroit » : précision de frontière mesurée ±1 s.
const stableOffsetSlackMs = 2000;

/// Fin d’épisode : un motif toujours dans cette fenêtre est un outro.
const outroWindowMs = 60000;

/// Auto-comparaison : on ignore les décalages plus courts (le motif
/// collé à lui-même). Au-delà, un refrain reste un candidat non sauté.
const selfMatchMinOffsetMs = 20000;

/// Sous ce ratio de parole (0–1), une répétition vue dans une seule
/// épisode est de la musique : refrain, lit, épisode musical. On la jette.
///
/// Mesuré : lit tonal 0,03, refrain chanté 0,18, parole (seule ou sur un
/// lit) ≥ 0,78. Voir `test/speech_music_test.dart`.
const intraMusicRejectRatio = 0.45;

/// Un refrain périodique n’est gardé que si la parole est aussi nette
/// qu’une lecture (le chant passe dessous).
const intraPeriodicSpeechEscape = 0.75;

/// Écart-type / moyenne des intervalles. En dessous, les reprises sont
/// trop régulières pour une pub insérée au hasard.
const refrainIntervalCvMax = 0.18;

/// Trois occurrences au moins (deux intervalles) pour parler de période.
const refrainMinGaps = 2;

/// Espacement d’un refrain : au-delà de l’auto-comparaison, en deçà
/// d’un couplet très espacé.
const refrainMinIntervalMs = 8000;

const refrainMaxIntervalMs = 180000;

/// Confiance d’un motif retrouvé dans plusieurs épisodes.
const crossEpisodeConfidence = 90;

/// En dessous, l’écran de classement replie le candidat (« afficher plus »).
/// Un motif inter-épisodes reste au-dessus.
const lowConfidenceCutoff = 50;

/// Log-mel : 8 kHz, 40 bandes, hop 10 ms, corrélation après normalisation.
const logMelSampleRate = 8000;

const logMelBandCount = 40;

const logMelHopMs = 10;

/// Seuil de corrélation normalisée. Mesuré : 0,96–0,97 au bon endroit,
/// ≤ 0,50 sur un autre podcast.
const logMelMatchThreshold = 0.85;

/// Même fenêtre que [jingleSearchWindowMs] : on ne balaye pas tout le fichier.
const logMelSearchWindowMs = jingleSearchWindowMs;

/// Jingle de fin de pré-roll, partagé par les podcasts d’un hébergeur.
class NetworkSting {
  const NetworkSting({required this.name, required this.durationMs});

  final String name;
  final int durationMs;
}

/// Acast : ~1,3 s à la fin du bloc de pub inséré, score log-mel 1,00.
const acastNetworkSting = NetworkSting(name: 'Acast', durationMs: 1300);

/// Liste optionnelle. La fin du sting marque la fin du pré-roll.
const knownNetworkStings = <NetworkSting>[acastNetworkSting];

/// Résultat de [classifyRepeatedSegment].
class SegmentClassification {
  const SegmentClassification({
    required this.kind,
    required this.autoSkip,
    this.confidence = crossEpisodeConfidence,
  });

  /// `null` : candidat seulement (parole répétée dans une seule épisode).
  final SkipSegmentKind? kind;

  /// `false` : ne jamais sauter automatiquement.
  final bool autoSkip;

  /// 0–100. Sert à trier l’écran de classement et à replier les doutes.
  /// N’autorise jamais le saut à lui seul.
  final int confidence;
}

/// Avis sur une répétition vue dans une seule épisode.
class IntraEpisodeVerdict {
  const IntraEpisodeVerdict({required this.reject, required this.confidence});

  /// `true` : ne pas enregistrer le passage.
  final bool reject;

  /// 0–100, ignoré quand [reject] est vrai.
  final int confidence;
}

/// Une occurrence d’un motif dans un épisode.
class SegmentOccurrence {
  const SegmentOccurrence({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.episodeDurationMs,
    this.preRollEndMs,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final int episodeDurationMs;

  /// Fin du pré-roll si un sting réseau ou l’écart de durée l’a donnée.
  final int? preRollEndMs;

  int get durationMs => endMs - startMs;
}

/// `true` si deux valeurs Chromaprint se correspondent.
bool chromaprintValuesMatch(int a, int b) {
  return hammingDistance32(a, b) <= chromaprintMaxHammingBits;
}

/// Part minimale de valeurs qui se correspondent dans une suite retenue.
///
/// Le pont de deux trous accepterait sinon un point sur trois. Mesuré :
/// une pub réencodée reste au-dessus, le bruit en dessous.
const chromaprintMinAgreement = 0.55;

final List<int> _popCount8 = List<int>.unmodifiable(
  List<int>.generate(256, (value) {
    var count = 0;
    var bits = value;
    while (bits != 0) {
      count += bits & 1;
      bits >>= 1;
    }
    return count;
  }),
);

int hammingDistance32(int a, int b) {
  final bits = (a ^ b) & 0xFFFFFFFF;
  return _popCount8[bits & 0xFF] +
      _popCount8[(bits >> 8) & 0xFF] +
      _popCount8[(bits >> 16) & 0xFF] +
      _popCount8[(bits >> 24) & 0xFF];
}

/// `true` si la suite a assez de correspondances pour ne pas être du bruit.
bool chromaprintAgreementOk(int matches, int points) {
  if (points <= 0) return false;
  return matches >= points * chromaprintMinAgreement;
}

/// `true` si [next] prolonge la suite qui finit à [previous].
/// Jusqu’à [chromaprintMaxGapPoints] valeurs manquantes sont acceptées.
bool fingerprintOffsetsContinue(int previous, int next) {
  if (next <= previous) return false;
  return next - previous - 1 <= chromaprintMaxGapPoints;
}

bool adDurationQualifies(int durationMs) => durationMs >= adMinDurationMs;

/// Corrélation log-mel suffisante (sons < 3 s, ou frontière à affiner).
bool logMelScoreMatches(double score) => score >= logMelMatchThreshold;

/// Les offsets tiennent dans [slackMs].
bool offsetsAreStable(
  Iterable<int> startMs, {
  int slackMs = stableOffsetSlackMs,
}) {
  final values = startMs.toList();
  if (values.isEmpty) return false;
  var minStart = values.first;
  var maxStart = values.first;
  for (final value in values) {
    if (value < minStart) minStart = value;
    if (value > maxStart) maxStart = value;
  }
  return maxStart - minStart <= slackMs;
}

/// Même offset, ou juste après le pré-roll de l’épisode.
bool comparableJinglePositions(
  List<SegmentOccurrence> hits, {
  int slackMs = stableOffsetSlackMs,
}) {
  if (hits.isEmpty) return false;
  if (offsetsAreStable(hits.map((hit) => hit.startMs), slackMs: slackMs)) {
    return true;
  }
  return hits.every((hit) {
    if (hit.startMs <= slackMs) return true;
    final preRoll = hit.preRollEndMs;
    if (preRoll == null) return false;
    final delta = hit.startMs - preRoll;
    return delta.abs() <= slackMs;
  });
}

/// Jingle court vu dans les 180 premières secondes, assez d’épisodes,
/// positions comparables. En dessous de 3 s, passer par le log-mel.
bool acceptJingleCandidate(List<SegmentOccurrence> hits) {
  if (hits.isEmpty) return false;
  final episodes = <int>{};
  for (final hit in hits) {
    if (hit.startMs > jingleSearchWindowMs) return false;
    if (hit.durationMs < jingleMinDurationMs) return false;
    episodes.add(hit.episodeId);
  }
  if (episodes.length < jingleMinEpisodes) return false;
  return comparableJinglePositions(hits);
}

bool _inOutroWindow(SegmentOccurrence hit) {
  if (hit.episodeDurationMs <= 0) return false;
  final fromEnd = hit.episodeDurationMs - hit.startMs;
  return fromEnd > 0 && fromEnd <= outroWindowMs;
}

bool _inIntroWindow(SegmentOccurrence hit) {
  return hit.startMs >= 0 && hit.startMs <= jingleSearchWindowMs;
}

/// `true` si les départs se répètent à intervalle presque constant.
///
/// Deux occurrences ne suffisent pas : un lit entendu deux fois n’a
/// qu’un intervalle. Trois reprises d’un refrain, si.
bool nearPeriodicRefrain(List<int> startsMs) {
  if (startsMs.length < refrainMinGaps + 1) return false;
  final sorted = [...startsMs]..sort();
  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i] - sorted[i - 1];
    if (gap >= refrainMinIntervalMs) gaps.add(gap);
  }
  if (gaps.length < refrainMinGaps) return false;
  var sum = 0;
  for (final gap in gaps) {
    sum += gap;
  }
  final mean = sum / gaps.length;
  if (mean > refrainMaxIntervalMs) return false;
  var variance = 0.0;
  for (final gap in gaps) {
    final delta = gap - mean;
    variance += delta * delta;
  }
  final cv = math.sqrt(variance / gaps.length) / mean;
  return cv <= refrainIntervalCvMax;
}

/// Répétition interne à une épisode.
///
/// Musique (ratio de parole bas) ou refrain quasi périodique : on rejette.
/// Parole insérée sans période : candidat, jamais sauté, confiance selon
/// le ratio. Sans chronologie de parole, seule la période décide : le
/// comportement précédent (candidat) reste pour les empreintes anciennes.
IntraEpisodeVerdict judgeIntraEpisodeRepeat({
  required List<int> startsMs,
  required double? speechRatio,
}) {
  final periodic = nearPeriodicRefrain(startsMs);
  final musical = speechRatio != null && speechRatio < intraMusicRejectRatio;
  final periodicMusic =
      periodic &&
      (speechRatio == null || speechRatio < intraPeriodicSpeechEscape);
  if (musical || periodicMusic) {
    return const IntraEpisodeVerdict(reject: true, confidence: 0);
  }
  return IntraEpisodeVerdict(
    reject: false,
    confidence: intraEpisodeConfidence(speechRatio, periodic: periodic),
  );
}

/// Confiance d’un candidat intra-épisode. Toujours sous
/// [crossEpisodeConfidence], pour que le tri place les pubs devant.
int intraEpisodeConfidence(double? speechRatio, {required bool periodic}) {
  if (speechRatio == null) return periodic ? 15 : 42;
  var score = ((speechRatio - 0.25) * 110).round();
  if (periodic) score -= 12;
  return score.clamp(8, 80);
}

/// Classe un motif déjà repéré entre épisodes.
///
/// - Toujours en début, offset stable ou juste après le pré-roll : intro.
/// - Toujours dans la dernière minute : outro.
/// - L’offset change d’un épisode à l’autre : pub / promo insérée.
/// - Offset stable ailleurs : lecture sponsor fixe.
/// - Une seule épisode : candidat sans saut. Le finder applique
///   [judgeIntraEpisodeRepeat] avant, et peut ne rien garder.
SegmentClassification classifyRepeatedSegment(List<SegmentOccurrence> hits) {
  final episodes = hits.map((hit) => hit.episodeId).toSet();
  if (episodes.length < 2) {
    return const SegmentClassification(kind: null, autoSkip: false);
  }
  if (hits.every(_inOutroWindow)) {
    return const SegmentClassification(
      kind: SkipSegmentKind.outro,
      autoSkip: true,
    );
  }
  if (hits.every(_inIntroWindow) && comparableJinglePositions(hits)) {
    return const SegmentClassification(
      kind: SkipSegmentKind.intro,
      autoSkip: true,
    );
  }
  if (!offsetsAreStable(hits.map((hit) => hit.startMs))) {
    return const SegmentClassification(
      kind: SkipSegmentKind.ad,
      autoSkip: true,
    );
  }
  return const SegmentClassification(
    kind: SkipSegmentKind.sponsor,
    autoSkip: true,
  );
}

/// Fin du pré-roll : le sting réseau est joué à la fin du bloc inséré.
int preRollEndFromSting(int stingStartMs, NetworkSting sting) {
  return stingStartMs + sting.durationMs;
}

/// `itunes:duration` contre la durée réelle du fichier téléchargé.
///
/// L’écart positif approche le temps de pub insérée. L’insertion dépend
/// du User-Agent : utiliser le fichier qu’on a vraiment, pas un autre fetch.
int? approximateInsertedAdMs({
  required int? rssDurationMs,
  required int fileDurationMs,
}) {
  if (rssDurationMs == null) return null;
  final delta = fileDurationMs - rssDurationMs;
  if (delta <= 0) return null;
  return delta;
}

/// Float32 little-endian, trame par trame, [logMelBandCount] bandes.
Uint8List encodeLogMel(List<List<double>> frames) {
  final bytes = Uint8List(frames.length * logMelBandCount * 4);
  final view = ByteData.sublistView(bytes);
  var offset = 0;
  for (final frame in frames) {
    if (frame.length != logMelBandCount) {
      throw ArgumentError(
        'Une trame log-mel a ${frame.length} bandes, pas $logMelBandCount.',
      );
    }
    for (final band in frame) {
      view.setFloat32(offset, band, Endian.little);
      offset += 4;
    }
  }
  return bytes;
}

List<List<double>> decodeLogMel(Uint8List bytes) {
  final width = logMelBandCount * 4;
  if (bytes.lengthInBytes % width != 0) {
    throw ArgumentError('Gabarit log-mel tronqué.');
  }
  final view = ByteData.sublistView(bytes);
  final frames = <List<double>>[];
  for (var offset = 0; offset < bytes.lengthInBytes; offset += width) {
    frames.add([
      for (var band = 0; band < logMelBandCount; band++)
        view.getFloat32(offset + band * 4, Endian.little),
    ]);
  }
  return frames;
}
