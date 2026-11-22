import 'dart:typed_data';

import 'package:olaf_ffi/olaf_ffi.dart';

import 'envelope.dart';
import 'olaf_index.dart';

/// A sting shorter than this is a fragment, not the network motif.
const olafStingMinMs = 1000;

/// Longer than this, the shared sound is an ad or an intro, not a sting.
const olafStingMaxMs = 6500;

/// Votes under this are chance collisions.
const olafStingMinVotes = 8;

/// A hash more frequent than this in one episode does not vote.
const olafStingMaxHashHits = 12;

/// Two episodes alone need a tighter vote, the same idea as a strong score.
const olafStingStrongVotes = 24;

/// A copy whose start moves by at least this much is not a fixed card.
const olafStingSpreadMs = 2000;

/// Landmarks of one episode, plus the silence envelope used to place edges.
class OlafEpisodePrints {
  const OlafEpisodePrints({
    required this.episodeId,
    required this.prints,
    this.envelope,
    this.durationMs = 0,
  });

  final int episodeId;
  final List<OlafLandmark> prints;
  final Uint8List? envelope;
  final int durationMs;
}

/// The sting itself, already snapped to held silence when an envelope exists.
class OlafContentSting {
  const OlafContentSting({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.votes,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final int votes;
}

class _Edge {
  _Edge({
    required this.leftId,
    required this.leftStart,
    required this.leftEnd,
    required this.rightId,
    required this.rightStart,
    required this.rightEnd,
    required this.votes,
  });

  final int leftId;
  final int leftStart;
  final int leftEnd;
  final int rightId;
  final int rightStart;
  final int rightEnd;
  final int votes;
}

class _Span {
  _Span(this.startMs, this.endMs, this.votes);

  int startMs;
  int endMs;
  int votes;
}

/// Finds one short sound that repeats in the first minutes, at a time
/// that can change from episode to episode.
///
/// The vote is Olaf's: landmarks that share a hash and the same time
/// offset (quantized by four frames) support one alignment. A long
/// alignment is an ad or the opening card and is dropped. When a fixed
/// card and a moving sting both match, the moving one wins.
List<OlafContentSting> findOlafContentSting(
  List<OlafEpisodePrints> episodes, {
  List<({int episodeId, int startMs, int endMs})> covered = const [],
}) {
  final usable = [
    for (final episode in episodes)
      if (episode.prints.length >= olafStingMinVotes) episode,
  ];
  if (usable.length < 2) return const [];
  final indexes = [for (final episode in usable) _index(episode.prints)];
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

  void unite(int a, int b) {
    final left = find(a);
    final right = find(b);
    if (left != right) parent[right] = left;
  }

  for (var i = 0; i < edges.length; i++) {
    for (var j = i + 1; j < edges.length; j++) {
      if (_sameSound(edges[i], edges[j])) unite(i, j);
    }
  }

  final groups = <int, List<_Edge>>{};
  for (var i = 0; i < edges.length; i++) {
    groups.putIfAbsent(find(i), () => <_Edge>[]).add(edges[i]);
  }

  _Pattern? best;
  for (final group in groups.values) {
    final pattern = _uncovered(_pattern(group), covered);
    if (pattern == null) continue;
    if (best == null || pattern.rank > best.rank) best = pattern;
  }
  if (best == null || best.spread < olafStingSpreadMs) return const [];
  if (best.episodes.length == 2 && best.votes < olafStingStrongVotes) {
    return const [];
  }

  final byId = {for (final episode in usable) episode.episodeId: episode};
  return [
    for (final entry in best.episodes.entries)
      _snap(byId[entry.key]!, entry.value),
  ];
}

_Pattern? _uncovered(
  _Pattern? pattern,
  List<({int episodeId, int startMs, int endMs})> covered,
) {
  if (pattern == null || covered.isEmpty) return pattern;
  final kept = <int, _Span>{};
  for (final entry in pattern.episodes.entries) {
    if (!_mostlyCovered(covered, entry.key, entry.value)) {
      kept[entry.key] = entry.value;
    }
  }
  if (kept.length < 2) return null;
  var earliest = 1 << 30;
  var latest = 0;
  for (final span in kept.values) {
    if (span.startMs < earliest) earliest = span.startMs;
    if (span.startMs > latest) latest = span.startMs;
  }
  return _Pattern(
    episodes: kept,
    votes: pattern.votes,
    spread: latest - earliest,
  );
}

/// A longer passage already found (an ad, an intro) is not reused.
bool _mostlyCovered(
  List<({int episodeId, int startMs, int endMs})> covered,
  int episodeId,
  _Span span,
) {
  final length = span.endMs - span.startMs;
  if (length <= 0) return false;
  for (final item in covered) {
    if (item.episodeId != episodeId) continue;
    if (item.endMs - item.startMs < length + 1000) continue;
    final overlap =
        (span.endMs < item.endMs ? span.endMs : item.endMs) -
        (span.startMs > item.startMs ? span.startMs : item.startMs);
    if (overlap >= length / 2) return true;
  }
  return false;
}

class _Pattern {
  _Pattern({required this.episodes, required this.votes, required this.spread});

  final Map<int, _Span> episodes;
  final int votes;
  final int spread;

  int get rank => episodes.length * 1000 + spread ~/ 1000 + votes.clamp(0, 999);
}

_Pattern? _pattern(List<_Edge> edges) {
  final spans = <int, _Span>{};
  var votes = 0;
  for (final edge in edges) {
    votes += edge.votes;
    _keep(spans, edge.leftId, _Span(edge.leftStart, edge.leftEnd, edge.votes));
    _keep(
      spans,
      edge.rightId,
      _Span(edge.rightStart, edge.rightEnd, edge.votes),
    );
  }
  if (spans.length < 2) return null;
  var earliest = 1 << 30;
  var latest = 0;
  for (final span in spans.values) {
    if (span.startMs < earliest) earliest = span.startMs;
    if (span.startMs > latest) latest = span.startMs;
  }
  return _Pattern(episodes: spans, votes: votes, spread: latest - earliest);
}

void _keep(Map<int, _Span> spans, int episodeId, _Span incoming) {
  final current = spans[episodeId];
  if (current == null || incoming.votes > current.votes) {
    spans[episodeId] = incoming;
  }
}

bool _sameSound(_Edge left, _Edge right) {
  return _overlap(
        left.leftId,
        left.leftStart,
        left.leftEnd,
        right.leftId,
        right.leftStart,
        right.leftEnd,
      ) ||
      _overlap(
        left.leftId,
        left.leftStart,
        left.leftEnd,
        right.rightId,
        right.rightStart,
        right.rightEnd,
      ) ||
      _overlap(
        left.rightId,
        left.rightStart,
        left.rightEnd,
        right.leftId,
        right.leftStart,
        right.leftEnd,
      ) ||
      _overlap(
        left.rightId,
        left.rightStart,
        left.rightEnd,
        right.rightId,
        right.rightStart,
        right.rightEnd,
      );
}

bool _overlap(
  int leftId,
  int leftStart,
  int leftEnd,
  int rightId,
  int rightStart,
  int rightEnd,
) {
  if (leftId != rightId) return false;
  final start = leftStart > rightStart ? leftStart : rightStart;
  final end = leftEnd < rightEnd ? leftEnd : rightEnd;
  if (end <= start) return false;
  final left = leftEnd - leftStart;
  final right = rightEnd - rightStart;
  final shorter = left < right ? left : right;
  return (end - start) * 2 >= shorter;
}

List<_Edge> _align(
  OlafEpisodePrints left,
  OlafEpisodePrints right,
  OlafHashIndex reference,
) {
  if (reference.isEmpty) return const [];
  final times = reference.times;
  final buckets = <int, List<(int, int)>>{};
  for (final mark in left.prints) {
    final id = reference.find(mark.hash);
    if (id < 0) continue;
    final end = reference.end(id);
    for (var k = reference.start(id); k < end; k++) {
      final time = times[k];
      final bucket = (mark.t1 - time) >> 2;
      (buckets[bucket] ??= <(int, int)>[]).add((time, mark.t1));
    }
  }
  if (buckets.isEmpty) return const [];
  final keys = buckets.keys.toList()..sort();
  final edges = <_Edge>[];
  for (final key in keys) {
    final here = buckets[key]!;
    if (here.length < (buckets[key - 1]?.length ?? 0)) continue;
    if (here.length < (buckets[key + 1]?.length ?? 0)) continue;
    if (here.length < olafStingMinVotes) continue;
    // A neighbour one frame away is the same alignment. A collision in
    // that neighbour must not stretch the sting into an ad, so it is
    // kept only while both spans stay inside the sting length.
    final votes = [...here];
    for (final extra in <(int, int)>[
      ...?buckets[key - 1],
      ...?buckets[key + 1],
    ]) {
      if (_fits(votes, extra)) votes.add(extra);
    }
    final edge = _edge(left, right, votes);
    if (edge != null) edges.add(edge);
  }
  return edges;
}

bool _fits(List<(int, int)> votes, (int, int) extra) {
  var refMin = extra.$1;
  var refMax = extra.$1;
  var queryMin = extra.$2;
  var queryMax = extra.$2;
  for (final vote in votes) {
    if (vote.$1 < refMin) refMin = vote.$1;
    if (vote.$1 > refMax) refMax = vote.$1;
    if (vote.$2 < queryMin) queryMin = vote.$2;
    if (vote.$2 > queryMax) queryMax = vote.$2;
  }
  final ref = (refMax - refMin) * olafStepMs;
  final query = (queryMax - queryMin) * olafStepMs;
  return ref <= olafStingMaxMs && query <= olafStingMaxMs;
}

OlafHashIndex _index(List<OlafLandmark> prints) => OlafHashIndex.build(
  prints.length,
  hashAt: (index) => prints[index].hash,
  timeAt: (index) => prints[index].t1,
  maxHits: olafStingMaxHashHits,
);

/// Edges of one pair, through the same index as [findOlafContentSting].
/// Exposed for the equivalence tests.
List<({int leftStart, int leftEnd, int rightStart, int rightEnd, int votes})>
olafStingEdges(OlafEpisodePrints left, OlafEpisodePrints right) => [
  for (final edge in _align(left, right, _index(right.prints)))
    (
      leftStart: edge.leftStart,
      leftEnd: edge.leftEnd,
      rightStart: edge.rightStart,
      rightEnd: edge.rightEnd,
      votes: edge.votes,
    ),
];

_Edge? _edge(
  OlafEpisodePrints left,
  OlafEpisodePrints right,
  List<(int, int)> votes,
) {
  if (votes.length < olafStingMinVotes) return null;
  var refMin = 1 << 30;
  var refMax = 0;
  var queryMin = 1 << 30;
  var queryMax = 0;
  for (final vote in votes) {
    if (vote.$1 < refMin) refMin = vote.$1;
    if (vote.$1 > refMax) refMax = vote.$1;
    if (vote.$2 < queryMin) queryMin = vote.$2;
    if (vote.$2 > queryMax) queryMax = vote.$2;
  }
  final refStart = refMin * olafStepMs;
  final refEnd = refMax * olafStepMs;
  final queryStart = queryMin * olafStepMs;
  final queryEnd = queryMax * olafStepMs;
  if (!_short(refStart, refEnd) || !_short(queryStart, queryEnd)) return null;
  return _Edge(
    leftId: left.episodeId,
    leftStart: queryStart,
    leftEnd: queryEnd,
    rightId: right.episodeId,
    rightStart: refStart,
    rightEnd: refEnd,
    votes: votes.length,
  );
}

bool _short(int startMs, int endMs) {
  final length = endMs - startMs;
  return length >= olafStingMinMs && length <= olafStingMaxMs;
}

/// 12 little-endian bytes per landmark: hash, then t1.
Uint8List encodeOlafPrints(List<OlafLandmark> prints) {
  final bytes = Uint8List(prints.length * 12);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < prints.length; i++) {
    data.setUint64(i * 12, prints[i].hash, Endian.little);
    data.setUint32(i * 12 + 8, prints[i].t1, Endian.little);
  }
  return bytes;
}

List<OlafLandmark> decodeOlafPrints(Uint8List bytes) {
  final count = bytes.length ~/ 12;
  if (count == 0) return const [];
  final data = ByteData.sublistView(bytes);
  return [
    for (var i = 0; i < count; i++)
      OlafLandmark(
        hash: data.getUint64(i * 12, Endian.little),
        t1: data.getUint32(i * 12 + 8, Endian.little),
      ),
  ];
}

OlafContentSting _snap(OlafEpisodePrints episode, _Span span) {
  final envelope = episode.envelope;
  final placed = envelope == null
      ? (startMs: span.startMs, endMs: span.endMs)
      : snapPortionToSilence(
          envelope,
          span.startMs,
          span.endMs,
          durationMs: episode.durationMs,
        );
  return OlafContentSting(
    episodeId: episode.episodeId,
    startMs: placed.startMs,
    endMs: placed.endMs,
    votes: span.votes,
  );
}
