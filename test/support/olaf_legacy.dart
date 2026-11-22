import 'dart:typed_data';

import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/olaf_ads.dart';
import 'package:podavio/data/olaf_sting.dart';
import 'package:podavio/data/segment_match.dart';

/// The Map-based Olaf alignment as it was before the packed index,
/// kept verbatim as the reference for the equivalence tests and the
/// benchmark.

typedef LegacyEdge = ({
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
  int votes,
});

class LegacyTable {
  LegacyTable(this._view, this.count);

  final ByteData _view;
  final int count;

  static LegacyTable parse(Uint8List bytes) =>
      LegacyTable(ByteData.sublistView(bytes, 4), (bytes.length - 4) ~/ 12);

  int hashAt(int index) => _view.getUint64(index * 12, Endian.little);

  int timeAt(int index) => _view.getUint32(index * 12 + 8, Endian.little);
}

/// Index and counts of one haystack, the "cached" variant builds it once.
class LegacyIndex {
  LegacyIndex(this.index, this.counts);

  factory LegacyIndex.of(LegacyTable table) {
    final counts = legacyCounts(table);
    final index = <int, List<int>>{};
    for (var i = 0; i < table.count; i++) {
      final hash = table.hashAt(i);
      if ((counts[hash] ?? 0) > olafAdMaxHashHits) continue;
      (index[hash] ??= <int>[]).add(table.timeAt(i));
    }
    return LegacyIndex(index, counts);
  }

  final Map<int, List<int>> index;
  final Map<int, int> counts;
}

Map<int, int> legacyCounts(LegacyTable table) {
  final counts = <int, int>{};
  for (var i = 0; i < table.count; i++) {
    final hash = table.hashAt(i);
    counts[hash] = (counts[hash] ?? 0) + 1;
  }
  return counts;
}

/// Old `_locate`: rebuilds the haystack index on every call.
OlafAdLocation? legacyLocate(
  LegacyTable needle,
  LegacyTable haystack, {
  required int durationMs,
}) => legacyLocateIn(needle, LegacyIndex.of(haystack), durationMs: durationMs);

OlafAdLocation? legacyLocateIn(
  LegacyTable needle,
  LegacyIndex haystack, {
  required int durationMs,
}) {
  final index = haystack.index;
  final tally = <int, int>{};
  for (var i = 0; i < needle.count; i++) {
    final hits = index[needle.hashAt(i)];
    if (hits == null) continue;
    final relative = needle.timeAt(i);
    for (final time in hits) {
      final bucket = (time - relative) >> 2;
      tally[bucket] = (tally[bucket] ?? 0) + 1;
    }
  }
  if (tally.isEmpty) return null;
  var bestKey = 0;
  var best = 0;
  for (final entry in tally.entries) {
    final key = entry.key;
    if (entry.value < (tally[key - 1] ?? 0)) continue;
    if (entry.value < (tally[key + 1] ?? 0)) continue;
    final merged = entry.value + (tally[key - 1] ?? 0) + (tally[key + 1] ?? 0);
    if (merged > best) {
      best = merged;
      bestKey = key;
    }
  }
  if (best < olafAdMinVotes) return null;
  final length = durationMs > 0
      ? durationMs ~/ olafStepMs
      : olafAdMaxDurationMs ~/ olafStepMs;
  if (length < adMinDurationMs ~/ olafStepMs) return null;
  final capped = length > olafAdMaxDurationMs ~/ olafStepMs
      ? olafAdMaxDurationMs ~/ olafStepMs
      : length;
  final start = bestKey << 2;
  return (startFrame: start, endFrame: start + capped, votes: best);
}

/// Old `_align`: rebuilds both counts and the right index on every pair.
List<LegacyEdge> legacyAlign(LegacyTable left, LegacyTable right) =>
    legacyAlignIn(left, legacyCounts(left), LegacyIndex.of(right));

List<LegacyEdge> legacyAlignIn(
  LegacyTable left,
  Map<int, int> leftCounts,
  LegacyIndex right,
) {
  final index = right.index;
  if (index.isEmpty) return const [];
  final buckets = <int, List<(int, int)>>{};
  for (var i = 0; i < left.count; i++) {
    final hash = left.hashAt(i);
    if ((leftCounts[hash] ?? 0) > olafAdMaxHashHits) continue;
    final hits = index[hash];
    if (hits == null) continue;
    final query = left.timeAt(i);
    for (final ref in hits) {
      final bucket = (query - ref) >> 2;
      (buckets[bucket] ??= <(int, int)>[]).add((ref, query));
    }
  }
  if (buckets.isEmpty) return const [];
  final keys = buckets.keys.toList()..sort();
  final edges = <LegacyEdge>[];
  for (final key in keys) {
    final here = buckets[key]!;
    if (here.length < (buckets[key - 1]?.length ?? 0)) continue;
    if (here.length < (buckets[key + 1]?.length ?? 0)) continue;
    final center = key << 2;
    final votes = <(int, int)>[];
    for (final vote in <(int, int)>[
      ...here,
      ...?buckets[key - 1],
      ...?buckets[key + 1],
    ]) {
      if ((vote.$2 - vote.$1 - center).abs() <= 8) votes.add(vote);
    }
    for (final run in _splitGaps(votes)) {
      final edge = _adEdge(_capRun(run));
      if (edge != null) edges.add(edge);
    }
  }
  return edges;
}

List<List<(int, int)>> _splitGaps(List<(int, int)> votes) {
  if (votes.isEmpty) return const [];
  votes.sort((a, b) => a.$2.compareTo(b.$2));
  const gap = olafAdGapMs ~/ olafStepMs;
  final runs = <List<(int, int)>>[];
  var current = <(int, int)>[votes.first];
  for (var i = 1; i < votes.length; i++) {
    if (votes[i].$2 - current.last.$2 > gap) {
      runs.add(current);
      current = <(int, int)>[];
    }
    current.add(votes[i]);
  }
  runs.add(current);
  return runs;
}

List<(int, int)> _capRun(List<(int, int)> run) {
  if (run.length < 2) return run;
  if ((run.last.$2 - run.first.$2) * olafStepMs > comparisonMaxPortionMs) {
    return const [];
  }
  const maxFrames = olafAdMaxDurationMs ~/ olafStepMs;
  if (run.last.$2 - run.first.$2 <= maxFrames) return run;
  var bestL = 0;
  var bestR = 1;
  var bestN = 0;
  var right = 0;
  for (var left = 0; left < run.length; left++) {
    while (right < run.length && run[right].$2 - run[left].$2 <= maxFrames) {
      right++;
    }
    final count = right - left;
    if (count > bestN) {
      bestN = count;
      bestL = left;
      bestR = right;
    }
  }
  return run.sublist(bestL, bestR);
}

LegacyEdge? _adEdge(List<(int, int)> votes) {
  if (votes.length < olafAdMinVotes) return null;
  var refMin = votes.first.$1;
  var refMax = votes.first.$1;
  var queryMin = votes.first.$2;
  var queryMax = votes.first.$2;
  for (final vote in votes) {
    if (vote.$1 < refMin) refMin = vote.$1;
    if (vote.$1 > refMax) refMax = vote.$1;
    if (vote.$2 < queryMin) queryMin = vote.$2;
    if (vote.$2 > queryMax) queryMax = vote.$2;
  }
  const minFrames = adMinDurationMs ~/ olafStepMs;
  const maxFrames = olafAdMaxDurationMs ~/ olafStepMs;
  if (queryMax - queryMin < minFrames || refMax - refMin < minFrames) {
    return null;
  }
  if (queryMax - queryMin > maxFrames || refMax - refMin > maxFrames) {
    return null;
  }
  return (
    leftStart: queryMin,
    leftEnd: queryMax,
    rightStart: refMin,
    rightEnd: refMax,
    votes: votes.length,
  );
}

/// Old sting `_align`, index rebuilt for every pair.
List<LegacyEdge> legacyStingAlign(
  OlafEpisodePrints left,
  OlafEpisodePrints right,
) {
  final reference = _stingIndex(right.prints);
  if (reference.isEmpty) return const [];
  final buckets = <int, List<(int, int)>>{};
  for (final mark in left.prints) {
    final hits = reference[mark.hash];
    if (hits == null) continue;
    for (final time in hits) {
      final bucket = (mark.t1 - time) >> 2;
      (buckets[bucket] ??= <(int, int)>[]).add((time, mark.t1));
    }
  }
  if (buckets.isEmpty) return const [];
  final keys = buckets.keys.toList()..sort();
  final edges = <LegacyEdge>[];
  for (final key in keys) {
    final here = buckets[key]!;
    if (here.length < (buckets[key - 1]?.length ?? 0)) continue;
    if (here.length < (buckets[key + 1]?.length ?? 0)) continue;
    if (here.length < olafStingMinVotes) continue;
    final votes = [...here];
    for (final extra in <(int, int)>[
      ...?buckets[key - 1],
      ...?buckets[key + 1],
    ]) {
      if (_fits(votes, extra)) votes.add(extra);
    }
    final edge = _stingEdge(votes);
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

Map<int, List<int>> _stingIndex(List<OlafLandmark> prints) {
  final counts = <int, int>{};
  for (final mark in prints) {
    counts[mark.hash] = (counts[mark.hash] ?? 0) + 1;
  }
  final index = <int, List<int>>{};
  for (final mark in prints) {
    if ((counts[mark.hash] ?? 0) > 12) continue;
    index.putIfAbsent(mark.hash, () => <int>[]).add(mark.t1);
  }
  return index;
}

LegacyEdge? _stingEdge(List<(int, int)> votes) {
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
  return (
    leftStart: queryStart,
    leftEnd: queryEnd,
    rightStart: refStart,
    rightEnd: refEnd,
    votes: votes.length,
  );
}

bool _short(int startMs, int endMs) {
  final length = endMs - startMs;
  return length >= olafStingMinMs && length <= olafStingMaxMs;
}
