import 'dart:math' as math;

import 'segment_match.dart';

/// Valeurs Chromaprint qui se suivent au minimum pour une virgule.
///
/// Une valeur résume environ 2 s de son (largeur des classifieurs) : une
/// virgule de 3 s entourée d’autre chose n’en donne que quelques-unes.
const chromaprintStingMinPoints = 4;

/// Plus long, le passage partagé est une pub ou une intro.
const chromaprintStingMaxMs = 6500;

/// Une copie dont le départ bouge d’au moins autant n’est pas un carton fixe.
const chromaprintStingSpreadMs = 2000;

/// Deux épisodes seuls demandent une suite plus longue.
const chromaprintStingStrongPoints = 8;

/// Une valeur plus fréquente dans un épisode (silence, ton) ne vote pas.
const _maxHits = 12;

class ChromaprintStingEpisode {
  const ChromaprintStingEpisode({
    required this.episodeId,
    required this.values,
    required this.hopMicros,
  });

  final int episodeId;

  /// Empreinte des premières minutes seulement.
  final List<int> values;
  final int hopMicros;
}

typedef StingSpan = ({int episodeId, int startMs, int endMs});

class _Edge {
  const _Edge(this.left, this.right, this.points);

  final StingSpan left;
  final StingSpan right;
  final int points;
}

/// Désigne les épisodes et l’heure approximative d’un même son court,
/// à une heure qui change d’un épisode à l’autre.
///
/// Chaque valeur identique vote pour un décalage. Le décalage est vérifié
/// par la distance de Hamming, valeur par valeur. Une suite trop longue
/// est une pub ou le carton d’ouverture et sort. Le log-mel pose ensuite
/// les bornes : ce n’est qu’un indice.
List<StingSpan> findChromaprintStingHint(
  List<ChromaprintStingEpisode> episodes, {
  List<StingSpan> covered = const [],
}) {
  final usable = [
    for (final episode in episodes)
      if (episode.values.length >= 16 && episode.hopMicros > 0) episode,
  ];
  if (usable.length < 2) return const [];
  final indexes = [for (final episode in usable) _index(episode.values)];
  final edges = <_Edge>[];
  for (var i = 0; i < usable.length; i++) {
    for (var j = i + 1; j < usable.length; j++) {
      edges.addAll(_align(usable[i], usable[j], indexes[j]));
    }
  }
  if (edges.isEmpty) return const [];

  final parent = List<int>.generate(edges.length, (index) => index);
  int find(int index) {
    var cursor = index;
    while (parent[cursor] != cursor) {
      parent[cursor] = parent[parent[cursor]];
      cursor = parent[cursor];
    }
    return cursor;
  }

  for (var i = 0; i < edges.length; i++) {
    for (var j = i + 1; j < edges.length; j++) {
      if (_sameSound(edges[i], edges[j])) {
        final a = find(i);
        final b = find(j);
        if (a != b) parent[b] = a;
      }
    }
  }
  final groups = <int, List<_Edge>>{};
  for (var i = 0; i < edges.length; i++) {
    (groups[find(i)] ??= []).add(edges[i]);
  }

  Map<int, (StingSpan, int)>? best;
  var bestRank = -1;
  for (final group in groups.values) {
    final spans = <int, (StingSpan, int)>{};
    void keep(StingSpan span, int points) {
      if (_mostlyCovered(covered, span)) return;
      final current = spans[span.episodeId];
      if (current == null || points > current.$2) {
        spans[span.episodeId] = (span, points);
      }
    }

    for (final edge in group) {
      keep(edge.left, edge.points);
      keep(edge.right, edge.points);
    }
    if (spans.length < 2) continue;
    final starts = [for (final entry in spans.values) entry.$1.startMs];
    final spread = starts.reduce(math.max) - starts.reduce(math.min);
    if (spread < chromaprintStingSpreadMs) continue;
    final points = spans.values.map((entry) => entry.$2).reduce(math.max);
    if (spans.length == 2 && points < chromaprintStingStrongPoints) continue;
    final rank = spans.length * 1000 + points.clamp(0, 999);
    if (rank > bestRank) {
      bestRank = rank;
      best = spans;
    }
  }
  if (best == null) return const [];
  return [for (final entry in best.values) entry.$1];
}

Map<int, List<int>> _index(List<int> values) {
  final buckets = <int, List<int>>{};
  for (var i = 0; i < values.length; i++) {
    (buckets[values[i]] ??= []).add(i);
  }
  buckets.removeWhere((_, hits) => hits.length > _maxHits);
  return buckets;
}

List<_Edge> _align(
  ChromaprintStingEpisode left,
  ChromaprintStingEpisode right,
  Map<int, List<int>> index,
) {
  if (left.hopMicros != right.hopMicros) return const [];
  final votes = <int, (int, int, int)>{};
  final a = left.values;
  final b = right.values;
  for (var i = 0; i < a.length; i++) {
    final hits = index[a[i]];
    if (hits == null) continue;
    for (final j in hits) {
      final current = votes[i - j];
      votes[i - j] = current == null
          ? (1, i, i)
          : (current.$1 + 1, current.$2, i);
    }
  }
  final hop = left.hopMicros;
  final edges = <_Edge>[];
  for (final entry in votes.entries) {
    if (entry.value.$1 < 2) continue;
    final delta = entry.key;
    final from = math.max(math.max(0, delta), entry.value.$2 - 16);
    final to = math.min(
      math.min(a.length, b.length + delta),
      entry.value.$3 + 17,
    );
    var start = -1;
    var last = -1;
    var gap = 0;
    var matches = 0;
    void close() {
      if (start >= 0) {
        final points = last - start + 1;
        final ms = points * hop ~/ 1000;
        if (points >= chromaprintStingMinPoints &&
            ms <= chromaprintStingMaxMs &&
            chromaprintAgreementOk(matches, points) &&
            _distinctive(a, start, last + 1)) {
          edges.add(
            _Edge(
              (
                episodeId: left.episodeId,
                startMs: start * hop ~/ 1000,
                endMs: (last + 1) * hop ~/ 1000,
              ),
              (
                episodeId: right.episodeId,
                startMs: (start - delta) * hop ~/ 1000,
                endMs: (last + 1 - delta) * hop ~/ 1000,
              ),
              points,
            ),
          );
        }
      }
      start = -1;
      gap = 0;
      matches = 0;
    }

    for (var i = from; i < to; i++) {
      if (chromaprintValuesMatch(a[i], b[i - delta])) {
        if (start < 0) start = i;
        last = i;
        gap = 0;
        matches++;
      } else if (start >= 0 && ++gap > chromaprintMaxGapPoints) {
        close();
      }
    }
    close();
  }
  return edges;
}

bool _distinctive(List<int> values, int start, int end) {
  final seen = <int>{};
  for (var i = start; i < end; i++) {
    seen.add(values[i]);
    if (seen.length >= 3) return true;
  }
  return false;
}

bool _overlaps(StingSpan a, StingSpan b) {
  if (a.episodeId != b.episodeId) return false;
  final start = math.max(a.startMs, b.startMs);
  final end = math.min(a.endMs, b.endMs);
  if (end <= start) return false;
  final shorter = math.min(a.endMs - a.startMs, b.endMs - b.startMs);
  return shorter > 0 && (end - start) * 2 >= shorter;
}

bool _sameSound(_Edge x, _Edge y) {
  return _overlaps(x.left, y.left) ||
      _overlaps(x.left, y.right) ||
      _overlaps(x.right, y.left) ||
      _overlaps(x.right, y.right);
}

/// Un passage plus long déjà repéré (pub, intro) n’est pas repris.
bool _mostlyCovered(List<StingSpan> covered, StingSpan span) {
  final length = span.endMs - span.startMs;
  if (length <= 0) return false;
  for (final item in covered) {
    if (item.episodeId != span.episodeId) continue;
    if (item.endMs - item.startMs < length + 1000) continue;
    final overlap =
        math.min(span.endMs, item.endMs) - math.max(span.startMs, item.startMs);
    if (overlap >= length / 2) return true;
  }
  return false;
}
