import 'dart:math' as math;
import 'dart:typed_data';

import 'envelope.dart';
import 'segment_match.dart';
import 'log_mel.dart';

/// Spectrogrammes chargés ensemble pour la recherche des jingles courts.
/// Au-delà, seuls les épisodes les plus récents sont comparés.
const logMelCompareEpisodeCap = 12;

/// Au-dessus, un son court partagé par plusieurs podcasts devient
/// une virgule de réseau apprise sur l’appareil.
const networkStingLearnThreshold = 0.95;

/// Durées essayées pour un jingle trop court pour Chromaprint.
const shortJingleDurationsMs = <int>[2500, 2000, 1500, 1000];

/// Épisode réduit à son spectrogramme des 180 premières secondes.
class EpisodeMel {
  const EpisodeMel({
    required this.episodeId,
    required this.podcastId,
    required this.clip,
    required this.durationMs,
    this.preRollEndMs,
  });

  final int episodeId;
  final int podcastId;
  final LogMelClip clip;
  final int durationMs;
  final int? preRollEndMs;
}

/// Jingle court retenu, avec son gabarit log-mel.
class ShortJingle {
  const ShortJingle({required this.clip, required this.hits});

  final LogMelClip clip;
  final List<SegmentOccurrence> hits;
}

/// Virgule apprise sur l’appareil, à partir de plusieurs podcasts.
class LearnedSting {
  const LearnedSting({
    required this.clip,
    required this.podcasts,
    required this.episodes,
  });

  final LogMelClip clip;
  final int podcasts;
  final int episodes;
}

/// Passage délimité par une virgule de réseau.
class StingSpan {
  const StingSpan({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.label,
    required this.score,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final String label;
  final double score;
}

/// Gabarit nommé (fichier livré avec l’application, ou appris).
class NamedLogMel {
  const NamedLogMel({required this.name, required this.clip});

  final String name;
  final LogMelClip clip;
}

/// Jingles de moins de 3 s, pris au début ou juste après le pré-roll.
List<ShortJingle> discoverShortJingles(List<EpisodeMel> episodes) {
  final found = <ShortJingle>[];
  final covered = <int>{};
  for (final duration in shortJingleDurationsMs) {
    for (final episode in episodes) {
      if (covered.contains(episode.episodeId)) continue;
      final start = _candidateStart(episode);
      final clip = sliceLogMel(episode.clip, start, start + duration);
      if (!_audible(clip)) continue;
      final hits = <SegmentOccurrence>[
        SegmentOccurrence(
          episodeId: episode.episodeId,
          startMs: start,
          endMs: start + clip.durationMs,
          episodeDurationMs: episode.durationMs,
          preRollEndMs: episode.preRollEndMs,
        ),
      ];
      for (final other in episodes) {
        if (other.episodeId == episode.episodeId) continue;
        final matches = searchLogMel(clip, other.clip);
        if (matches.isEmpty) continue;
        final best = matches.reduce(
          (left, right) => left.score >= right.score ? left : right,
        );
        hits.add(
          SegmentOccurrence(
            episodeId: other.episodeId,
            startMs: best.startMs,
            endMs: best.endMs,
            episodeDurationMs: other.durationMs,
            preRollEndMs: other.preRollEndMs,
          ),
        );
      }
      if (!_acceptShort(hits)) continue;
      for (final hit in hits) {
        covered.add(hit.episodeId);
      }
      found.add(ShortJingle(clip: clip, hits: hits));
    }
  }
  return found;
}

/// Recale le début d’un passage Chromaprint sur le log-mel.
///
/// [roughStartMs] peut être à ±1 s. Le cœur du passage sert de gabarit,
/// cherché dans une fenêtre de 1,5 s. Sous le seuil, on garde l’estimation.
LogMelMatch? refineLogMelBoundary({
  required LogMelClip episode,
  required int roughStartMs,
  required int roughEndMs,
}) {
  if (roughEndMs - roughStartMs < jingleMinDurationMs) return null;
  final rough = sliceLogMel(episode, roughStartMs, roughEndMs);
  final audible = _trimSilence(rough);
  if (audible.frames.length < 8) return null;
  final origin = roughStartMs - 1500 < 0 ? 0 : roughStartMs - 1500;
  final window = sliceLogMel(episode, origin, roughEndMs + 1500);
  final matches = searchLogMel(
    audible,
    window,
    minSeparationMs: audible.durationMs,
  );
  if (matches.isEmpty) return null;
  final best = matches.reduce(
    (left, right) => left.score >= right.score ? left : right,
  );
  final start = origin + best.startMs;
  return LogMelMatch(
    startMs: start,
    endMs: start + audible.durationMs,
    score: best.score,
  );
}

/// Recale début et fin en comparant deux épisodes, au pas de 10 ms.
///
/// Le cœur du passage sert de référence. On avance ou on recule tant que
/// les trames alignées se correspondent, dans ±[boundaryRefineSlackMs].
/// `null` si les deux sons ne se distinguent pas de ce qui les entoure.
LogMelMatch? refinePairedLogMelEdges({
  required LogMelClip left,
  required int leftStartMs,
  required int leftEndMs,
  required LogMelClip right,
  required int rightStartMs,
  required int rightEndMs,
  int slackMs = boundaryRefineSlackMs,
}) {
  final span = leftEndMs - leftStartMs;
  if (span < jingleMinDurationMs || left.frames.length < 8) return null;
  final delta = leftStartMs - rightStartMs;

  double cosAt(int leftMs) {
    final frameL = leftMs ~/ logMelHopMs;
    final frameR = (leftMs - delta) ~/ logMelHopMs;
    if (frameL < 0 ||
        frameR < 0 ||
        frameL >= left.frames.length ||
        frameR >= right.frames.length) {
      return 0;
    }
    return _frameCos(left.frames[frameL], right.frames[frameR]);
  }

  final inner = <double>[];
  final innerFrom = leftStartMs + span ~/ 5;
  final innerTo = leftEndMs - span ~/ 5;
  for (var t = innerFrom; t < innerTo; t += logMelHopMs) {
    inner.add(cosAt(t));
  }
  final outer = <double>[];
  for (var t = leftStartMs - slackMs; t < leftStartMs - 200; t += logMelHopMs) {
    outer.add(cosAt(t));
  }
  if (inner.length < 4 || outer.length < 4) return null;
  inner.sort();
  outer.sort();
  final innerMed = inner[inner.length ~/ 2];
  final outerMed = outer[outer.length ~/ 2];
  if (innerMed - outerMed < 0.12) return null;
  final gate = (innerMed + outerMed) / 2;
  const holdNeed = 150 ~/ logMelHopMs;

  int? rising;
  var hold = 0;
  final riseStop = leftStartMs + slackMs < leftEndMs
      ? leftStartMs + slackMs
      : leftEndMs;
  for (var t = leftStartMs - slackMs; t < riseStop; t += logMelHopMs) {
    if (cosAt(t) >= gate) {
      hold++;
      if (hold >= holdNeed) {
        rising = t - (holdNeed - 1) * logMelHopMs;
        break;
      }
    } else {
      hold = 0;
    }
  }
  int? falling;
  hold = 0;
  final fallStop = leftEndMs - slackMs > leftStartMs
      ? leftEndMs - slackMs
      : leftStartMs;
  for (var t = leftEndMs + slackMs; t > fallStop; t -= logMelHopMs) {
    if (cosAt(t) >= gate) {
      hold++;
      if (hold >= holdNeed) {
        falling = t + holdNeed * logMelHopMs;
        break;
      }
    } else {
      hold = 0;
    }
  }
  if (rising == null || falling == null || falling - rising < span ~/ 2) {
    return null;
  }
  if ((rising - leftStartMs).abs() > slackMs) return null;
  if ((falling - leftEndMs).abs() > slackMs) return null;
  final score = innerMed.clamp(0.0, 1.0);
  if (score < logMelMatchThreshold) return null;
  return LogMelMatch(startMs: rising, endMs: falling, score: score);
}

double _frameCos(List<double> left, List<double> right) {
  var dot = 0.0;
  final n = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < n; i++) {
    dot += left[i] * right[i];
  }
  if (dot > 1) return 1;
  if (dot < -1) return -1;
  return dot;
}

LogMelClip _trimSilence(LogMelClip clip) {
  var first = clip.frames.length;
  var last = -1;
  for (var i = 0; i < clip.frames.length; i++) {
    if (!_frameLoud(clip.frames[i])) continue;
    if (i < first) first = i;
    last = i;
  }
  if (last < first) return const LogMelClip([]);
  return LogMelClip(clip.frames.sublist(first, last + 1));
}

bool _frameLoud(List<double> frame) {
  for (final value in frame) {
    if (value.abs() > 1e-6) return true;
  }
  return false;
}

/// La virgule marque la fin du bloc inséré.
///
/// Dans les 180 premières secondes, le pré-roll est `[0, fin]`.
/// Dans la dernière minute, le post-roll va de la virgule à la fin.
List<StingSpan> stingDelimitedSpans({
  required EpisodeMel episode,
  required List<NamedLogMel> stings,
}) {
  final spans = <StingSpan>[];
  for (final sting in stings) {
    if (sting.clip.frames.length < 8) continue;
    final matches = searchLogMel(sting.clip, episode.clip);
    if (matches.isEmpty) continue;
    final best = matches.reduce(
      (left, right) => left.score >= right.score ? left : right,
    );
    if (best.startMs <= jingleSearchWindowMs) {
      spans.add(
        StingSpan(
          episodeId: episode.episodeId,
          startMs: 0,
          endMs: best.endMs,
          label: sting.name,
          score: best.score,
        ),
      );
      continue;
    }
    final fromEnd = episode.durationMs - best.startMs;
    if (fromEnd > 0 && fromEnd <= outroWindowMs) {
      spans.add(
        StingSpan(
          episodeId: episode.episodeId,
          startMs: best.startMs,
          endMs: episode.durationMs,
          label: sting.name,
          score: best.score,
        ),
      );
    }
  }
  return spans;
}

/// Un son court identique, collé à la fin d’un bloc dynamique,
/// dans au moins deux podcasts.
List<LearnedSting> learnNetworkStings(List<EpisodeMelBoundary> slices) {
  final parent = <int, int>{for (var i = 0; i < slices.length; i++) i: i};
  int find(int id) {
    var root = id;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    return root;
  }

  for (var i = 0; i < slices.length; i++) {
    for (var j = i + 1; j < slices.length; j++) {
      if (slices[i].podcastId == slices[j].podcastId) continue;
      final score = _bestScore(slices[i].clip, slices[j].clip);
      if (score < networkStingLearnThreshold) continue;
      parent[find(j)] = find(i);
    }
  }
  final groups = <int, List<EpisodeMelBoundary>>{};
  for (var i = 0; i < slices.length; i++) {
    (groups[find(i)] ??= []).add(slices[i]);
  }
  final learned = <LearnedSting>[];
  for (final group in groups.values) {
    final podcasts = group.map((slice) => slice.podcastId).toSet();
    if (podcasts.length < 2) continue;
    learned.add(
      LearnedSting(
        clip: group.first.clip,
        podcasts: podcasts.length,
        episodes: group.map((slice) => slice.episodeId).toSet().length,
      ),
    );
  }
  return learned;
}

/// Tranche collée à la fin d’un bloc de pub dynamique.
class EpisodeMelBoundary {
  const EpisodeMelBoundary({
    required this.podcastId,
    required this.episodeId,
    required this.clip,
  });

  final int podcastId;
  final int episodeId;
  final LogMelClip clip;
}

int _candidateStart(EpisodeMel episode) {
  final preRoll = episode.preRollEndMs ?? 0;
  final sound = _firstSoundMs(episode.clip);
  return preRoll > sound ? preRoll : sound;
}

int _firstSoundMs(LogMelClip clip) {
  for (var i = 0; i < clip.frames.length; i++) {
    for (final value in clip.frames[i]) {
      if (value.abs() > 1e-6) return i * logMelHopMs;
    }
  }
  return 0;
}

bool _audible(LogMelClip clip) {
  if (clip.frames.length < 8) return false;
  var loud = 0;
  for (final frame in clip.frames) {
    for (final value in frame) {
      if (value.abs() > 1e-6) {
        loud++;
        break;
      }
    }
  }
  return loud * 2 >= clip.frames.length;
}

bool _acceptShort(List<SegmentOccurrence> hits) {
  if (hits.isEmpty) return false;
  final episodes = <int>{};
  for (final hit in hits) {
    if (hit.startMs > jingleSearchWindowMs) return false;
    if (hit.durationMs >= jingleMinDurationMs) return false;
    if (hit.durationMs < shortJingleDurationsMs.last) return false;
    episodes.add(hit.episodeId);
  }
  if (episodes.length < jingleMinEpisodes) return false;
  return comparableJinglePositions(hits);
}

/// Durée de la virgule cherchée avant le contenu, dans les 2 à 4 s.
const contentStingMs = 3000;

/// Pas des fenêtres essayées dans les trois premières minutes.
const contentStingStepMs = 2000;

/// Score d’une copie nette. En dessous, ce n’est pas la même virgule.
const contentStingScore = 0.85;

/// Deux épisodes suffisent seulement si la copie est franche.
const contentStingStrongScore = 0.90;

/// Le pic doit dépasser le niveau de fond, sinon tout se ressemble.
const contentStingMargin = 0.35;

const contentStingMinEpisodes = 2;

/// Virgule répétée avant le contenu, à un instant qui peut changer.
class ContentSting {
  const ContentSting({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
}

/// Cherche le même extrait de ~3 s n’importe où dans les 180 premières
/// secondes. L’heure n’a pas à coïncider, et aucune pub n’est exigée à côté.
///
/// La cosinus brute du log-mel vaut ~1 sur la parole : chaque trame est
/// presque plate. On compare des trames centrées. Un passage déjà couvert
/// par un motif plus long (la pub, l’intro) n’est pas repris comme virgule.
List<ContentSting> findContentStings({
  required List<EpisodeMel> episodes,
  List<({int episodeId, int startMs, int endMs})> covered = const [],
}) {
  final usable = [
    for (final episode in episodes.take(logMelCompareEpisodeCap))
      if (episode.clip.frames.length >= contentStingMs ~/ logMelHopMs) episode,
  ];
  if (usable.length < contentStingMinEpisodes) return const [];
  final units = <int, _UnitFrames>{
    for (final episode in usable) episode.episodeId: _UnitFrames(episode.clip),
  };
  final width = contentStingMs ~/ logMelHopMs;
  final step = contentStingStepMs ~/ logMelHopMs;
  _StingPattern? best;
  for (final anchor in usable) {
    final needle = units[anchor.episodeId]!;
    final last = needle.frames - width;
    for (var origin = 0; origin <= last; origin += step) {
      final startMs = origin * logMelHopMs;
      if (startMs > logMelSearchWindowMs) break;
      if (!_voiced(needle, origin, width)) continue;
      if (_mostlyCovered(
        covered,
        anchor.episodeId,
        startMs,
        startMs + contentStingMs,
      )) {
        continue;
      }
      final hits = <ContentSting>[
        ContentSting(
          episodeId: anchor.episodeId,
          startMs: startMs,
          endMs: startMs + contentStingMs,
        ),
      ];
      var weakest = 1.0;
      for (final other in usable) {
        if (other.episodeId == anchor.episodeId) continue;
        final hay = units[other.episodeId]!;
        final found = _bestStingAlign(needle, origin, hay, width);
        if (found == null) continue;
        if (found.score < contentStingScore ||
            found.margin < contentStingMargin) {
          continue;
        }
        final hitStart = found.frame * logMelHopMs;
        final hitEnd = hitStart + contentStingMs;
        if (_mostlyCovered(covered, other.episodeId, hitStart, hitEnd)) {
          continue;
        }
        hits.add(
          ContentSting(
            episodeId: other.episodeId,
            startMs: hitStart,
            endMs: hitEnd,
          ),
        );
        if (found.score < weakest) weakest = found.score;
      }
      if (hits.length < contentStingMinEpisodes) continue;
      if (hits.length < 3 && weakest < contentStingStrongScore) continue;
      final pattern = _StingPattern(hits);
      if (best == null || pattern.rank > best.rank) best = pattern;
    }
  }
  return best?.hits ?? const [];
}

bool _mostlyCovered(
  List<({int episodeId, int startMs, int endMs})> covered,
  int episodeId,
  int startMs,
  int endMs,
) {
  final length = endMs - startMs;
  if (length <= 0) return false;
  for (final span in covered) {
    if (span.episodeId != episodeId) continue;
    if (span.endMs - span.startMs < length + 1000) continue;
    final overlap =
        math.min(endMs, span.endMs) - math.max(startMs, span.startMs);
    if (overlap >= length / 2) return true;
  }
  return false;
}

class _StingPattern {
  _StingPattern(this.hits);

  final List<ContentSting> hits;

  int get spread {
    var low = hits.first.startMs;
    var high = low;
    for (final hit in hits) {
      if (hit.startMs < low) low = hit.startMs;
      if (hit.startMs > high) high = hit.startMs;
    }
    return high - low;
  }

  /// Une virgule dont l’heure change bat une intro toujours au même instant.
  int get rank {
    final variable = spread >= 2000 ? 1 : 0;
    return variable * 100000 + hits.length * 1000 + spread ~/ 1000;
  }
}

class _UnitFrames {
  _UnitFrames(LogMelClip clip)
    : frames = clip.frames.length,
      data = Float32List(clip.frames.length * logMelBandCount),
      coarse = Float32List(clip.frames.length * _coarseBands) {
    for (var frame = 0; frame < frames; frame++) {
      final row = clip.frames[frame];
      final n = row.length < logMelBandCount ? row.length : logMelBandCount;
      var mean = 0.0;
      for (var band = 0; band < n; band++) {
        mean += row[band];
      }
      mean /= logMelBandCount;
      var energy = 0.0;
      final base = frame * logMelBandCount;
      for (var band = 0; band < logMelBandCount; band++) {
        final value = (band < n ? row[band] : 0.0) - mean;
        data[base + band] = value;
        energy += value * value;
      }
      final norm = math.sqrt(energy);
      if (norm > 1e-8) {
        for (var band = 0; band < logMelBandCount; band++) {
          data[base + band] /= norm;
        }
      } else {
        for (var band = 0; band < logMelBandCount; band++) {
          data[base + band] = 0;
        }
      }
      final coarseBase = frame * _coarseBands;
      var coarseMean = 0.0;
      for (var band = 0; band < _coarseBands; band++) {
        var sum = 0.0;
        final from = band * (logMelBandCount ~/ _coarseBands);
        final to = from + logMelBandCount ~/ _coarseBands;
        for (var i = from; i < to; i++) {
          sum += data[base + i];
        }
        coarse[coarseBase + band] = sum;
        coarseMean += sum;
      }
      coarseMean /= _coarseBands;
      var coarseEnergy = 0.0;
      for (var band = 0; band < _coarseBands; band++) {
        final value = coarse[coarseBase + band] - coarseMean;
        coarse[coarseBase + band] = value;
        coarseEnergy += value * value;
      }
      final coarseNorm = math.sqrt(coarseEnergy);
      if (coarseNorm > 1e-8) {
        for (var band = 0; band < _coarseBands; band++) {
          coarse[coarseBase + band] /= coarseNorm;
        }
      }
    }
  }

  static const _coarseBands = 8;

  final int frames;
  final Float32List data;
  final Float32List coarse;

  int get bands => logMelBandCount;
}

bool _voiced(_UnitFrames frames, int start, int width) {
  var voiced = 0;
  var seen = 0;
  for (var frame = 0; frame < width; frame += 4) {
    final base = (start + frame) * frames.bands;
    var energy = 0.0;
    for (var band = 0; band < frames.bands; band += 4) {
      final value = frames.data[base + band];
      energy += value * value;
    }
    seen++;
    if (energy > 1e-6) voiced++;
  }
  return seen > 0 && voiced * 2 >= seen;
}

({int frame, double score, double margin})? _bestStingAlign(
  _UnitFrames needle,
  int origin,
  _UnitFrames hay,
  int width,
) {
  if (hay.frames < width) return null;
  final limit = hay.frames - width;
  const stride = 10;
  final peaks = <({int frame, double score})>[];
  for (var start = 0; start <= limit; start += stride) {
    final coarse = _coarseScore(needle, origin, hay, start, width);
    if (coarse < 0.55) continue;
    var replaced = false;
    for (var i = 0; i < peaks.length; i++) {
      final delta = peaks[i].frame - start;
      if (delta >= width || delta <= -width) continue;
      replaced = true;
      if (coarse > peaks[i].score) {
        peaks[i] = (frame: start, score: coarse);
      }
      break;
    }
    if (replaced) continue;
    peaks.add((frame: start, score: coarse));
    if (peaks.length > 3) {
      peaks.sort((a, b) => b.score.compareTo(a.score));
      peaks.removeLast();
    }
  }
  if (peaks.isEmpty) return null;
  var bestFrame = -1;
  var best = 0.0;
  for (final peak in peaks) {
    final from = peak.frame - stride < 0 ? 0 : peak.frame - stride;
    final to = peak.frame + stride > limit ? limit : peak.frame + stride;
    for (var frame = from; frame <= to; frame++) {
      final score = _frameScore(needle, origin, hay, frame, width);
      if (score <= best) continue;
      best = score;
      bestFrame = frame;
    }
  }
  if (bestFrame < 0 || best < contentStingScore) return null;
  final samples = <double>[];
  final probe = limit <= 0 ? 1 : limit ~/ 8;
  for (var i = 0; i < 8; i++) {
    final at = i * probe;
    if (at > limit) break;
    samples.add(_frameScore(needle, origin, hay, at, width, background: true));
  }
  samples.add(best);
  samples.sort();
  final margin = best - samples[samples.length ~/ 2];
  return (frame: bestFrame, score: best, margin: margin);
}

double _coarseScore(
  _UnitFrames needle,
  int origin,
  _UnitFrames hay,
  int start,
  int width,
) {
  const bands = _UnitFrames._coarseBands;
  var dot = 0.0;
  var used = 0;
  for (var frame = 0; frame < width; frame += 2) {
    final left = (origin + frame) * bands;
    final right = (start + frame) * bands;
    var local = 0.0;
    for (var band = 0; band < bands; band++) {
      local += needle.coarse[left + band] * hay.coarse[right + band];
    }
    dot += local;
    used++;
    if ((used & 7) == 0) {
      final remaining = (width - frame) ~/ 2;
      if ((dot + remaining) / (used + remaining) < 0.55) return 0;
    }
  }
  if (used == 0) return 0;
  return dot / used;
}

double _frameScore(
  _UnitFrames needle,
  int origin,
  _UnitFrames hay,
  int start,
  int width, {
  bool background = false,
}) {
  final bands = needle.bands;
  final stride = background ? 4 : 1;
  var dot = 0.0;
  var used = 0;
  for (var frame = 0; frame < width; frame += stride) {
    final left = (origin + frame) * bands;
    final right = (start + frame) * bands;
    var local = 0.0;
    for (var band = 0; band < bands; band++) {
      local += needle.data[left + band] * hay.data[right + band];
    }
    dot += local;
    used++;
    if (!background && (used & 15) == 0) {
      final remaining = (width - frame - 1) ~/ stride;
      if ((dot + remaining) / (used + remaining) < contentStingScore) {
        return 0;
      }
    }
  }
  if (used == 0) return 0;
  return dot / used;
}

/// Recherche log-mel hors de l’isolate d’interface.
///
/// Le message ne contient que des octets. Le décodage en trames se fait ici.
Map<String, Object?> planLogMelMessage(Map<String, Object?> message) {
  final episodes = <EpisodeMel>[];
  for (final raw in message['episodes']! as List) {
    final row = (raw as List).cast<Object?>();
    episodes.add(
      EpisodeMel(
        episodeId: row[0]! as int,
        podcastId: row[1]! as int,
        clip: _clipAll(row[2]! as Uint8List),
        durationMs: row[3]! as int,
        preRollEndMs: row[4] as int?,
      ),
    );
  }
  final templates = <({int id, LogMelClip? clip})>[];
  for (final raw in message['templates']! as List) {
    final row = (raw as List).cast<Object?>();
    final bytes = row[1] as Uint8List?;
    templates.add((
      id: row[0]! as int,
      clip: bytes == null || bytes.isEmpty ? null : _clipAll(bytes),
    ));
  }
  final stings = <NamedLogMel>[];
  for (final raw in message['stings']! as List) {
    final row = (raw as List).cast<Object?>();
    stings.add(
      NamedLogMel(
        name: row[0]! as String,
        clip: _clipAll(row[1]! as Uint8List),
      ),
    );
  }
  final segments = <List<Object?>>[];
  for (final raw in message['segments']! as List) {
    segments.add((raw as List).cast<Object?>());
  }

  final jingles = <Map<String, Object?>>[];
  for (final jingle in discoverShortJingles(episodes)) {
    final bytes = encodeLogMel(jingle.clip.frames.cast<List<double>>());
    final known = _knownTemplate(jingle.clip, templates);
    jingles.add({
      'bytes': bytes,
      'durationMs': jingle.clip.durationMs,
      'templateId': known?.id,
      'fillLogMel': known != null && known.clip == null,
      'hits': [
        for (final hit in jingle.hits)
          <String, Object?>{
            'episodeId': hit.episodeId,
            'startMs': hit.startMs,
            'endMs': hit.endMs,
          },
      ],
    });
  }

  final refinedEnds = <int, int>{};
  final refinements = <Map<String, Object?>>[];
  for (final segment in segments) {
    final startMs = segment[2]! as int;
    final endMs = segment[3]! as int;
    if (endMs - startMs < jingleMinDurationMs) continue;
    if (startMs > logMelSearchWindowMs) continue;
    final episodeId = segment[1]! as int;
    final episode = episodes
        .where((item) => item.episodeId == episodeId)
        .firstOrNull;
    if (episode == null) continue;
    final self = refineLogMelBoundary(
      episode: episode.clip,
      roughStartMs: startMs,
      roughEndMs: endMs,
    );
    final templateIdEarly = segment[5] as int?;
    LogMelMatch? paired;
    if (templateIdEarly != null) {
      for (final other in segments) {
        if (identical(other, segment) || other[5] != templateIdEarly) continue;
        final otherId = other[1]! as int;
        final partner = episodes
            .where((item) => item.episodeId == otherId)
            .firstOrNull;
        if (partner == null) continue;
        paired = refinePairedLogMelEdges(
          left: episode.clip,
          leftStartMs: self?.startMs ?? startMs,
          leftEndMs: self?.endMs ?? endMs,
          right: partner.clip,
          rightStartMs: other[2]! as int,
          rightEndMs: other[3]! as int,
        );
        if (paired != null) break;
      }
    }
    final refined = paired ?? self;
    if (refined == null) continue;
    // La fin déjà poussée jusqu’au silence ne doit pas être raccourcie
    // par un recalage qui s’arrête au dernier hash partagé.
    final templateId = segment[5] as int?;
    Uint8List? templateBytes;
    if (templateId != null) {
      final template = templates
          .where((item) => item.id == templateId)
          .firstOrNull;
      if (template != null && template.clip == null) {
        final slice = sliceLogMel(episode.clip, refined.startMs, refined.endMs);
        if (slice.frames.length >= 8) {
          templateBytes = encodeLogMel(slice.frames.cast<List<double>>());
        }
      }
    }
    final keptEnd = refined.endMs > endMs ? refined.endMs : endMs;
    refinedEnds[segment[0]! as int] = keptEnd;
    refinements.add({
      'segmentId': segment[0],
      'episodeId': segment[1],
      'startMs': refined.startMs,
      'endMs': keptEnd,
      'matches': segment[4],
      'templateId': templateId,
      'templateBytes': templateBytes,
    });
  }

  final spans = <Map<String, Object?>>[];
  for (final episode in episodes) {
    for (final span in stingDelimitedSpans(episode: episode, stings: stings)) {
      spans.add({
        'episodeId': span.episodeId,
        'startMs': span.startMs,
        'endMs': span.endMs,
      });
    }
  }

  final slices = <EpisodeMelBoundary>[];
  for (final raw in message['boundaries']! as List) {
    final row = (raw as List).cast<Object?>();
    final id = row[0]! as int;
    final endMs = refinedEnds[id] ?? row[4]! as int;
    final clip = _clipRange(row[3]! as Uint8List, endMs - 1300, endMs);
    if (clip.frames.length < 8) continue;
    slices.add(
      EpisodeMelBoundary(
        podcastId: row[1]! as int,
        episodeId: row[2]! as int,
        clip: clip,
      ),
    );
  }
  final existing = <({int id, LogMelClip clip})>[];
  for (final raw in message['learned']! as List) {
    final row = (raw as List).cast<Object?>();
    existing.add((id: row[0]! as int, clip: _clipAll(row[1]! as Uint8List)));
  }
  final learned = <Map<String, Object?>>[];
  for (final sting in learnNetworkStings(slices)) {
    int? prior;
    for (final row in existing) {
      final score = searchLogMel(
        sting.clip,
        row.clip,
        threshold: networkStingLearnThreshold,
      );
      if (score.isNotEmpty) {
        prior = row.id;
        break;
      }
    }
    learned.add({
      'priorId': prior,
      'bytes': prior == null
          ? encodeLogMel(sting.clip.frames.cast<List<double>>())
          : null,
      'durationMs': sting.clip.durationMs,
      'episodes': sting.episodes,
      'podcasts': sting.podcasts,
    });
  }

  final covered = <({int episodeId, int startMs, int endMs})>[];
  for (final segment in segments) {
    final id = segment[0]! as int;
    final startMs = segment[2]! as int;
    final endMs = refinedEnds[id] ?? segment[3]! as int;
    if (endMs <= startMs) continue;
    covered.add((
      episodeId: segment[1]! as int,
      startMs: startMs,
      endMs: endMs,
    ));
  }
  final postAd = findContentStings(episodes: episodes, covered: covered);

  return {
    'jingles': jingles,
    'refinements': refinements,
    'spans': spans,
    'learned': learned,
    'postAd': [
      for (final hit in postAd)
        <String, Object?>{
          'episodeId': hit.episodeId,
          'startMs': hit.startMs,
          'endMs': hit.endMs,
        },
    ],
  };
}

({int id, LogMelClip? clip})? _knownTemplate(
  LogMelClip clip,
  List<({int id, LogMelClip? clip})> templates,
) {
  for (final template in templates) {
    final known = template.clip;
    if (known == null || known.frames.length < 8) continue;
    if (searchLogMel(clip, known, threshold: 0.95).isNotEmpty ||
        searchLogMel(known, clip, threshold: 0.95).isNotEmpty) {
      return template;
    }
  }
  return null;
}

LogMelClip _clipAll(Uint8List bytes) {
  return _clipRange(bytes, 0, 1 << 30);
}

LogMelClip _clipRange(Uint8List bytes, int startMs, int endMs) {
  final width = logMelBandCount * 4;
  if (bytes.lengthInBytes < width) return const LogMelClip([]);
  final frameCount = bytes.lengthInBytes ~/ width;
  var start = (startMs / logMelHopMs).floor();
  var end = (endMs / logMelHopMs).ceil();
  if (start < 0) start = 0;
  if (end > frameCount) end = frameCount;
  if (end <= start) return const LogMelClip([]);
  final view = ByteData.sublistView(bytes);
  final frames = <Float64List>[];
  for (var frame = start; frame < end; frame++) {
    final row = Float64List(logMelBandCount);
    final offset = frame * width;
    for (var band = 0; band < logMelBandCount; band++) {
      row[band] = view.getFloat32(offset + band * 4, Endian.little);
    }
    frames.add(row);
  }
  return LogMelClip(frames);
}

double _bestScore(LogMelClip left, LogMelClip right) {
  final matches = searchLogMel(
    left,
    right,
    threshold: networkStingLearnThreshold,
    minSeparationMs: left.durationMs,
  );
  if (matches.isEmpty) return 0;
  return matches.first.score;
}
