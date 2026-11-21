import 'segment_match.dart';
import 'log_mel.dart';

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
