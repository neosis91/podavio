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

LogMelMatch? _bestCenteredMatch(LogMelClip needle, LogMelClip haystack) {
  final width = needle.frames.length;
  if (width < 8 || haystack.frames.length < width) return null;
  final limit = haystack.frames.length - width;
  var best = 0.0;
  var bestStart = -1;
  for (var start = 0; start <= limit; start += 2) {
    final score = _centeredCosine(needle, haystack, start);
    if (score <= best) continue;
    best = score;
    bestStart = start;
  }
  if (bestStart < 0 || best < logMelMatchThreshold) return null;
  final startMs = bestStart * logMelHopMs;
  return LogMelMatch(
    startMs: startMs,
    endMs: startMs + width * logMelHopMs,
    score: best,
  );
}

double _centeredCosine(LogMelClip needle, LogMelClip haystack, int start) {
  var dot = 0.0;
  var leftEnergy = 0.0;
  var rightEnergy = 0.0;
  for (var frame = 0; frame < needle.frames.length; frame++) {
    final left = needle.frames[frame];
    final right = haystack.frames[start + frame];
    final bands = left.length < right.length ? left.length : right.length;
    var meanLeft = 0.0;
    var meanRight = 0.0;
    for (var band = 0; band < bands; band++) {
      meanLeft += left[band];
      meanRight += right[band];
    }
    meanLeft /= bands;
    meanRight /= bands;
    for (var band = 0; band < bands; band++) {
      final a = left[band] - meanLeft;
      final b = right[band] - meanRight;
      dot += a * b;
      leftEnergy += a * a;
      rightEnergy += b * b;
    }
  }
  final denom = math.sqrt(leftEnergy) * math.sqrt(rightEnergy);
  if (denom <= 1e-8) return 0;
  final score = dot / denom;
  if (score > 1) return 1;
  if (score < -1) return -1;
  return score;
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

/// Durée cherchée juste après une pub : la virgule du réseau, ~3 s.
const postAdStingMs = 2800;

/// La virgule doit coller à la fin de la pub, à ce trou près.
const postAdStingGapMs = 800;

/// Même plancher que les jingles : deux épisodes seulement feraient
/// d’une pub coupée trop tôt une fausse virgule.
const postAdStingMinEpisodes = 3;

/// Virgule répétée dans les secondes qui suivent une pub.
class PostAdSting {
  const PostAdSting({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
}

/// Cherche le même court extrait juste après la fin de pub de plusieurs
/// épisodes. Le log-mel ne couvre que les 180 premières secondes.
List<PostAdSting> findPostAdStings({
  required List<EpisodeMel> episodes,
  required List<({int episodeId, int endMs})> adEnds,
}) {
  final byEpisode = <int, EpisodeMel>{
    for (final episode in episodes) episode.episodeId: episode,
  };
  final anchors = <({int episodeId, int endMs, LogMelClip clip})>[];
  for (final ad in adEnds) {
    if (ad.endMs <= 0 || ad.endMs > logMelSearchWindowMs) continue;
    final episode = byEpisode[ad.episodeId];
    if (episode == null) continue;
    final clip = sliceLogMel(episode.clip, ad.endMs, ad.endMs + postAdStingMs);
    if (!_audible(clip)) continue;
    anchors.add((episodeId: ad.episodeId, endMs: ad.endMs, clip: clip));
  }
  if (anchors.length < postAdStingMinEpisodes) return const [];

  final hits = <int, PostAdSting>{};
  for (final anchor in anchors) {
    final matched = <PostAdSting>[
      PostAdSting(
        episodeId: anchor.episodeId,
        startMs: anchor.endMs,
        endMs: anchor.endMs + anchor.clip.durationMs,
      ),
    ];
    for (final other in anchors) {
      if (other.episodeId == anchor.episodeId) continue;
      final episode = byEpisode[other.episodeId];
      if (episode == null) continue;
      final windowStart = other.endMs - 400 < 0 ? 0 : other.endMs - 400;
      final window = sliceLogMel(
        episode.clip,
        windowStart,
        other.endMs + postAdStingMs + postAdStingGapMs,
      );
      // La cosinus brute du log-mel vaut ~1 sur la parole réelle : chaque
      // trame est presque plate. On retire la moyenne de la trame, sinon
      // toute fin de pub serait une virgule.
      final found = _bestCenteredMatch(anchor.clip, window);
      if (found == null) continue;
      var start = windowStart + found.startMs;
      final end = windowStart + found.endMs;
      if (start < other.endMs - 400 || start > other.endMs + postAdStingGapMs) {
        continue;
      }
      if (start < other.endMs) start = other.endMs;
      if (start - other.endMs <= postAdStingGapMs) start = other.endMs;
      if (end <= start) continue;
      matched.add(
        PostAdSting(episodeId: other.episodeId, startMs: start, endMs: end),
      );
    }
    if (matched.length < postAdStingMinEpisodes) continue;
    for (final hit in matched) {
      final prior = hits[hit.episodeId];
      if (prior == null ||
          hit.endMs - hit.startMs > prior.endMs - prior.startMs) {
        hits[hit.episodeId] = hit;
      }
    }
  }
  if (hits.length < postAdStingMinEpisodes) return const [];
  return hits.values.toList();
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

  final adEnds = <({int episodeId, int endMs})>[];
  for (final segment in segments) {
    final id = segment[0]! as int;
    final startMs = segment[2]! as int;
    final endMs = refinedEnds[id] ?? segment[3]! as int;
    if (endMs - startMs < adMinDurationMs) continue;
    adEnds.add((episodeId: segment[1]! as int, endMs: endMs));
  }
  final postAd = findPostAdStings(episodes: episodes, adEnds: adEnds);

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
