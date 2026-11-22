import 'dart:math' as math;
import 'dart:typed_data';

import 'package:olaf_ffi/olaf_ffi.dart';

import 'ad_context.dart';
import 'envelope.dart';
import 'olaf_index.dart';
import 'olaf_sting.dart';
import 'segment_finder.dart';
import 'segment_match.dart';
import 'skip_segments.dart';

/// Un landmark sur seize. Le blob d’un épisode reste du même ordre que
/// l’empreinte Chromaprint, y compris après les trois premières minutes.
const olafAdKeepModulus = 16;

/// Une pub retenue ne dépasse pas une minute.
const olafAdMaxDurationMs = 60000;

/// Au-delà, la portion ne participe pas à la comparaison : c’est trop long
/// pour une pub, une virgule, un sponsor ou un outro.
const comparisonMaxPortionMs = 120000;

/// En dessous, le pic de l’histogramme est un hasard.
const olafAdMinVotes = 12;

/// Un hash plus fréquent dans un épisode est trop banal pour voter.
const olafAdMaxHashHits = 8;

/// Trou qui sépare deux pubs collées au même décalage.
const olafAdGapMs = 2500;

const _outroBridgeMs = 5000;

const _outroTailSlackMs = 15000;

bool isOlafAdPrint(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x4F &&
      bytes[1] == 0x6C &&
      bytes[2] == 0x61 &&
      bytes[3] == 0x66;
}

/// Magic `Olaf` puis les landmarks (hash uint64, t1 uint32).
Uint8List encodeOlafAdPrints(List<OlafLandmark> prints) {
  final body = encodeOlafPrints(prints);
  final out = Uint8List(4 + body.length);
  out[0] = 0x4F;
  out[1] = 0x6C;
  out[2] = 0x61;
  out[3] = 0x66;
  out.setRange(4, out.length, body);
  return out;
}

/// Dernier landmark, en millisecondes. 0 si le blob n’est pas une empreinte.
int olafAdLastMs(Uint8List bytes) {
  final table = _Table.tryParse(bytes);
  if (table == null || table.count == 0) return 0;
  var maxT = 0;
  for (var i = 0; i < table.count; i++) {
    final time = table.timeAt(i);
    if (time > maxT) maxT = time;
  }
  return maxT * olafStepMs;
}

class OlafAdEpisode {
  const OlafAdEpisode({
    required this.episodeId,
    required this.prints,
    required this.durationMs,
    this.envelope,
    this.preRollEndMs,
    this.speech,
    this.chapters = const [],
  });

  final int episodeId;
  final Uint8List prints;
  final int durationMs;
  final Uint8List? envelope;
  final int? preRollEndMs;
  final Uint8List? speech;
  final List<AdContextChapter> chapters;
}

class OlafAdTemplate {
  const OlafAdTemplate({
    required this.id,
    required this.kind,
    required this.confirmed,
    required this.durationMs,
    required this.prints,
    required this.confidence,
  });

  final int id;
  final SkipSegmentKind kind;
  final bool? confirmed;
  final int durationMs;
  final Uint8List prints;
  final int? confidence;
}

/// Motifs répétés par histogramme de décalage Olaf.
///
/// Chaque hash partagé vote pour `tA - tB`. Le pic local est une pub,
/// une intro ou un outro. La plage est coupée à [olafAdMaxDurationMs],
/// puis les bords passent par le même recalage d’enveloppe que
/// l’ancien chemin.
AnalysisPlan planOlafAds({
  required List<OlafAdEpisode> episodes,
  required List<OlafAdTemplate> templates,
  int? focusEpisodeId,
  bool contextLayer = true,
  bool useMn04 = false,
  List<Mn04Cue> mn04 = const [],
}) {
  final usable = <_Episode>[];
  for (final episode in episodes) {
    final table = _Table.tryParse(episode.prints);
    if (table == null || table.count < olafAdMinVotes) continue;
    usable.add(_Episode(episode, table));
  }
  final byId = {for (final episode in usable) episode.id: episode};
  final claimed = <int, List<_Range>>{};
  final known = <int>{};
  final patterns = <PlannedPattern>[];

  for (final template in templates) {
    final needle = _Table.tryParse(template.prints);
    if (needle == null || needle.count < 8) continue;
    final segments = <PlannedSegment>[];
    for (final episode in usable) {
      final located = _locate(
        needle,
        episode.index,
        durationMs: template.durationMs,
      );
      if (located == null) continue;
      segments.add(
        PlannedSegment(
          episodeId: episode.id,
          startMs: located.startFrame * olafStepMs,
          endMs: located.endFrame * olafStepMs,
          kind: template.kind,
          confirmed: template.confirmed,
          matches: 0,
          confidence: template.confidence ?? crossEpisodeConfidence,
        ),
      );
    }
    if (segments.isEmpty) continue;
    final refined = _refinePlanned(segments, byId);
    if (refined.isEmpty) continue;
    for (final segment in refined) {
      known.add(segment.episodeId);
      (claimed[segment.episodeId] ??= []).add(
        _Range(segment.startMs, segment.endMs),
      );
    }
    final matches = refined.map((segment) => segment.episodeId).toSet().length;
    patterns.add(
      PlannedPattern(
        templateId: template.id,
        kind: template.kind,
        confirmed: template.confirmed,
        fingerprint: const [],
        fingerprintBytes: template.prints,
        durationMs: template.durationMs,
        confidence: template.confidence ?? crossEpisodeConfidence,
        segments: [
          for (final segment in refined)
            PlannedSegment(
              episodeId: segment.episodeId,
              startMs: segment.startMs,
              endMs: segment.endMs,
              kind: segment.kind,
              confirmed: segment.confirmed,
              matches: matches,
              confidence: segment.confidence,
            ),
        ],
      ),
    );
  }

  final discover = focusEpisodeId != null && known.contains(focusEpisodeId)
      ? const <_Found>[]
      : _discover(
          usable,
          focusEpisodeId: focusEpisodeId,
          skipEpisodeIds: known,
        );
  for (final found in discover) {
    final fresh = [
      for (final hit in found.hits)
        if (!_claimed(claimed, hit.episodeId, hit.startMs, hit.endMs)) hit,
    ];
    final ids = fresh.map((hit) => hit.episodeId).toSet();
    if (ids.length < 2) continue;
    final decision = classifyRepeatedSegment(fresh);
    final kind = decision.kind ?? SkipSegmentKind.other;
    final confirmed = decision.autoSkip ? null : false;
    final bytes = _templateOf(found, fresh, byId);
    if (bytes.length <= 4) continue;
    final duration = fresh
        .map((hit) => hit.endMs - hit.startMs)
        .reduce(math.max);
    patterns.add(
      PlannedPattern(
        templateId: null,
        kind: kind,
        confirmed: confirmed,
        fingerprint: const [],
        fingerprintBytes: bytes,
        durationMs: duration,
        confidence: decision.confidence,
        segments: [
          for (final hit in fresh)
            PlannedSegment(
              episodeId: hit.episodeId,
              startMs: hit.startMs,
              endMs: hit.endMs,
              kind: kind,
              confirmed: confirmed,
              matches: ids.length,
              confidence: decision.confidence,
            ),
        ],
      ),
    );
  }
  final plan = AnalysisPlan(patterns);
  if (!contextLayer) return plan;
  return _withContext(plan, byId, useMn04: useMn04, mn04: mn04);
}

/// Entrée d’isolate. Le message ne contient que des types transportables.
Map<String, Object?> planOlafAnalysisMessage(Map<String, Object?> message) {
  final episodes = <OlafAdEpisode>[];
  for (final raw in message['episodes']! as List) {
    final row = raw! as List;
    episodes.add(
      OlafAdEpisode(
        episodeId: row[0]! as int,
        durationMs: row[1]! as int,
        preRollEndMs: row[2] as int?,
        prints: _asBytes(row[3]) ?? Uint8List(0),
        envelope: row.length > 4 ? _asBytes(row[4]) : null,
        speech: row.length > 5 ? _asBytes(row[5]) : null,
        chapters: row.length > 6 ? _chaptersOf(row[6]) : const [],
      ),
    );
  }
  final templates = <OlafAdTemplate>[];
  for (final raw in message['templates']! as List) {
    final row = raw! as List;
    templates.add(
      OlafAdTemplate(
        id: row[0]! as int,
        kind: _kindOf(row[1]! as String),
        confirmed: row[2] as bool?,
        durationMs: row[3]! as int,
        prints: _asBytes(row[4]) ?? Uint8List(0),
        confidence: row.length > 5 ? row[5] as int? : null,
      ),
    );
  }
  return _encodePlan(
    planOlafAds(
      episodes: episodes,
      templates: templates,
      focusEpisodeId: message['focus'] as int?,
      contextLayer: message['context'] != false,
      useMn04: message['mn04'] == true,
      mn04: _mn04Of(message['mn04Cues']),
    ),
  );
}

class _Episode {
  _Episode(this.source, this.table);

  final OlafAdEpisode source;
  final _Table table;

  /// Built on first use, then shared by every template and every pair.
  late final OlafHashIndex index = OlafHashIndex.build(
    table.count,
    hashAt: table.hashAt,
    timeAt: table.timeAt,
    maxHits: olafAdMaxHashHits,
  );

  int get id => source.episodeId;

  int get durationMs => source.durationMs;

  Uint8List? get envelope => source.envelope;

  int? get preRollEndMs => source.preRollEndMs;

  Uint8List? get speech => source.speech;

  List<AdContextChapter> get chapters => source.chapters;
}

AnalysisPlan _withContext(
  AnalysisPlan plan,
  Map<int, _Episode> byId, {
  required bool useMn04,
  required List<Mn04Cue> mn04,
}) {
  final episodes = {
    for (final episode in byId.values)
      episode.id: AdContextEpisode(
        durationMs: episode.durationMs,
        envelope: episode.envelope,
        speech: episode.speech,
        chapters: episode.chapters,
      ),
  };
  final kept = <PlannedPattern>[];
  final keptHits = <AdContextHit>[];
  for (final pattern in plan.patterns) {
    final fusion = fuseAdContext(
      matches: [
        for (final segment in pattern.segments)
          AdContextHit(
            episodeId: segment.episodeId,
            startMs: segment.startMs,
            endMs: segment.endMs,
          ),
      ],
      episodes: episodes,
      useMn04: useMn04,
      mn04: mn04,
      propose: false,
    );
    if (fusion.matches.isEmpty) continue;
    final ids = fusion.matches.map((hit) => hit.episodeId).toSet();
    if (pattern.templateId == null && ids.length < 2) continue;
    final duration = fusion.matches
        .map((hit) => hit.endMs - hit.startMs)
        .reduce(math.max);
    keptHits.addAll(fusion.matches);
    kept.add(
      PlannedPattern(
        templateId: pattern.templateId,
        kind: pattern.kind,
        confirmed: pattern.confirmed,
        fingerprint: pattern.fingerprint,
        fingerprintBytes: pattern.fingerprintBytes,
        durationMs: duration,
        confidence: pattern.confidence,
        segments: [
          for (final hit in fusion.matches)
            PlannedSegment(
              episodeId: hit.episodeId,
              startMs: hit.startMs,
              endMs: hit.endMs,
              kind: pattern.kind,
              confirmed: pattern.confirmed,
              matches: ids.length,
              confidence: pattern.confidence,
            ),
        ],
      ),
    );
  }
  final extra = fuseAdContext(
    matches: const [],
    episodes: episodes,
    useMn04: useMn04,
    mn04: mn04,
  );
  for (final hit in extra.proposed) {
    if (_contextOverlaps(hit, keptHits)) continue;
    final episode = byId[hit.episodeId];
    if (episode == null) continue;
    final bytes = _slicePrints(episode.table, hit.startMs, hit.endMs);
    if ((bytes.length - 4) ~/ 12 < 8) continue;
    final length = hit.endMs - hit.startMs;
    final kind = length > olafAdMaxDurationMs
        ? SkipSegmentKind.sponsor
        : _inOutro(episode.durationMs, hit.startMs)
        ? SkipSegmentKind.outro
        : SkipSegmentKind.ad;
    final confidence = (hit.score * 70).round().clamp(8, 70);
    keptHits.add(hit);
    kept.add(
      PlannedPattern(
        templateId: null,
        kind: kind,
        confirmed: false,
        fingerprint: const [],
        fingerprintBytes: bytes,
        durationMs: length,
        confidence: confidence,
        segments: [
          PlannedSegment(
            episodeId: hit.episodeId,
            startMs: hit.startMs,
            endMs: hit.endMs,
            kind: kind,
            confirmed: false,
            matches: 1,
            confidence: confidence,
          ),
        ],
      ),
    );
  }
  return AnalysisPlan(kept);
}

bool _contextOverlaps(AdContextHit hit, List<AdContextHit> others) {
  final length = hit.endMs - hit.startMs;
  for (final other in others) {
    if (other.episodeId != hit.episodeId) continue;
    final start = math.max(hit.startMs, other.startMs);
    final end = math.min(hit.endMs, other.endMs);
    if (end <= start) continue;
    final shorter = math.min(length, other.endMs - other.startMs);
    if (shorter > 0 && (end - start) * 2 >= shorter) return true;
  }
  return false;
}

Uint8List _slicePrints(_Table table, int startMs, int endMs) {
  final origin = startMs ~/ olafStepMs;
  final end = endMs ~/ olafStepMs;
  final marks = <OlafLandmark>[];
  for (var i = 0; i < table.count; i++) {
    final time = table.timeAt(i);
    if (time < origin || time > end) continue;
    marks.add(OlafLandmark(hash: table.hashAt(i), t1: time - origin));
  }
  return encodeOlafAdPrints(marks);
}

List<AdContextChapter> _chaptersOf(Object? raw) {
  if (raw is! List) return const [];
  final chapters = <AdContextChapter>[];
  for (final item in raw) {
    if (item is! List || item.length < 3) continue;
    final start = item[0];
    final end = item[1];
    final title = item[2];
    if (start is! int || end is! int || title is! String) continue;
    if (end <= start) continue;
    chapters.add(AdContextChapter(startMs: start, endMs: end, title: title));
  }
  return chapters;
}

List<Mn04Cue> _mn04Of(Object? raw) {
  if (raw is! List) return const [];
  final cues = <Mn04Cue>[];
  for (final item in raw) {
    if (item is! List || item.length < 8) continue;
    final episodeId = item[0];
    final start = item[1];
    final end = item[2];
    if (episodeId is! int || start is! int || end is! int) continue;
    cues.add(
      Mn04Cue(
        episodeId: episodeId,
        startMs: start,
        endMs: end,
        speech: _asDouble(item[3]),
        music: _asDouble(item[4]),
        jingle: _asDouble(item[5]),
        backgroundMusic: _asDouble(item[6]),
        scoreJump: _asDouble(item[7]),
      ),
    );
  }
  return cues;
}

double _asDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  return 0;
}

class _Table {
  _Table(this._view, this.count);

  final ByteData _view;
  final int count;

  static _Table? tryParse(Uint8List bytes) {
    if (!isOlafAdPrint(bytes)) return null;
    final body = bytes.length - 4;
    if (body < 12 || body % 12 != 0) return null;
    return _Table(ByteData.sublistView(bytes, 4), body ~/ 12);
  }

  int hashAt(int index) => _view.getUint64(index * 12, Endian.little);

  int timeAt(int index) => _view.getUint32(index * 12 + 8, Endian.little);
}

class _Range {
  const _Range(this.start, this.end);

  final int start;
  final int end;
}

class _Located {
  const _Located(this.startFrame, this.endFrame, this.votes);

  final int startFrame;
  final int endFrame;
  final int votes;
}

class _Draft {
  _Draft({
    required this.episodeId,
    required this.rawStart,
    required this.rawEnd,
    required this.votes,
    required this.hit,
  });

  final int episodeId;
  final int rawStart;
  final int rawEnd;
  final int votes;
  final SegmentOccurrence hit;
}

class _Found {
  _Found(this.drafts);

  final List<_Draft> drafts;

  List<SegmentOccurrence> get hits => [for (final draft in drafts) draft.hit];
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

List<_Found> _discover(
  List<_Episode> episodes, {
  int? focusEpisodeId,
  Set<int> skipEpisodeIds = const {},
}) {
  final edges = <_Edge>[];
  for (var i = 0; i < episodes.length; i++) {
    final left = episodes[i];
    if (skipEpisodeIds.contains(left.id)) continue;
    if (focusEpisodeId != null && left.id != focusEpisodeId) continue;
    for (var j = 0; j < episodes.length; j++) {
      if (j == i) continue;
      if (focusEpisodeId == null && j <= i) continue;
      final right = episodes[j];
      final aligned = _align(left, right);
      if (aligned.isEmpty) continue;
      edges.addAll(aligned);
      break;
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
    (groups[find(i)] ??= []).add(edges[i]);
  }
  final byId = {for (final episode in episodes) episode.id: episode};
  final found = <_Found>[];
  for (final group in groups.values) {
    final drafts = _drafts(group, byId);
    if (drafts.length < 2) continue;
    final refined = _refineDrafts(drafts, byId);
    final hits = [
      for (final draft in refined)
        if (draft.hit.endMs - draft.hit.startMs >= adMinDurationMs) draft,
    ];
    if (hits.map((draft) => draft.episodeId).toSet().length < 2) continue;
    found.add(_Found(hits));
  }
  return found;
}

List<_Edge> _align(_Episode left, _Episode right) {
  final index = right.index;
  if (index.isEmpty) return const [];
  final own = left.index;
  final times = index.times;
  final buckets = <int, List<(int, int)>>{};
  for (var i = 0; i < left.table.count; i++) {
    if (own.countOf(own.idOfLandmark(i)) > olafAdMaxHashHits) continue;
    final id = index.find(left.table.hashAt(i));
    if (id < 0) continue;
    final end = index.end(id);
    final query = left.table.timeAt(i);
    for (var k = index.start(id); k < end; k++) {
      final ref = times[k];
      final bucket = (query - ref) >> 2;
      (buckets[bucket] ??= <(int, int)>[]).add((ref, query));
    }
  }
  if (buckets.isEmpty) return const [];
  final keys = buckets.keys.toList()..sort();
  final edges = <_Edge>[];
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
      final capped = _capRun(run);
      final edge = _edge(left, right, capped);
      if (edge != null) edges.add(edge);
    }
  }
  return edges;
}

List<List<(int, int)>> _splitGaps(List<(int, int)> votes) {
  if (votes.isEmpty) return const [];
  votes.sort((a, b) => a.$2.compareTo(b.$2));
  final gap = olafAdGapMs ~/ olafStepMs;
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
  final maxFrames = olafAdMaxDurationMs ~/ olafStepMs;
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

_Edge? _edge(_Episode left, _Episode right, List<(int, int)> votes) {
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
  final minFrames = adMinDurationMs ~/ olafStepMs;
  final maxFrames = olafAdMaxDurationMs ~/ olafStepMs;
  if (queryMax - queryMin < minFrames || refMax - refMin < minFrames) {
    return null;
  }
  if (queryMax - queryMin > maxFrames || refMax - refMin > maxFrames) {
    return null;
  }
  return _Edge(
    leftId: left.id,
    leftStart: queryMin,
    leftEnd: queryMax,
    rightId: right.id,
    rightStart: refMin,
    rightEnd: refMax,
    votes: votes.length,
  );
}

bool _sameSound(_Edge left, _Edge right) {
  return _overlapEdge(
        left.leftId,
        left.leftStart,
        left.leftEnd,
        right.leftId,
        right.leftStart,
        right.leftEnd,
      ) ||
      _overlapEdge(
        left.leftId,
        left.leftStart,
        left.leftEnd,
        right.rightId,
        right.rightStart,
        right.rightEnd,
      ) ||
      _overlapEdge(
        left.rightId,
        left.rightStart,
        left.rightEnd,
        right.leftId,
        right.leftStart,
        right.leftEnd,
      ) ||
      _overlapEdge(
        left.rightId,
        left.rightStart,
        left.rightEnd,
        right.rightId,
        right.rightStart,
        right.rightEnd,
      );
}

bool _overlapEdge(
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
  if (shorter <= 0) return false;
  return (end - start) * 2 >= shorter;
}

class _FrameSpan {
  _FrameSpan(this.start, this.end, this.votes);

  int start;
  int end;
  int votes;
}

List<_Draft> _drafts(List<_Edge> edges, Map<int, _Episode> byId) {
  final spans = <int, List<_FrameSpan>>{};
  for (final edge in edges) {
    _keepSpan(spans, edge.leftId, edge.leftStart, edge.leftEnd, edge.votes);
    _keepSpan(spans, edge.rightId, edge.rightStart, edge.rightEnd, edge.votes);
  }
  final outro = spans.entries.every((entry) {
    final episode = byId[entry.key];
    if (episode == null) return false;
    return entry.value.every(
      (span) => _inOutro(episode.durationMs, span.start * olafStepMs),
    );
  });
  final drafts = <_Draft>[];
  for (final entry in spans.entries) {
    final episode = byId[entry.key];
    if (episode == null) continue;
    final merged = _mergeSpans(entry.value, outro: outro);
    for (final span in merged) {
      var endMs = span.end * olafStepMs;
      if (outro &&
          episode.durationMs > 0 &&
          episode.durationMs - endMs <= _outroTailSlackMs &&
          episode.durationMs > endMs) {
        endMs = episode.durationMs;
      }
      drafts.add(
        _Draft(
          episodeId: episode.id,
          rawStart: span.start,
          rawEnd: span.end,
          votes: span.votes,
          hit: SegmentOccurrence(
            episodeId: episode.id,
            startMs: span.start * olafStepMs,
            endMs: endMs,
            episodeDurationMs: episode.durationMs,
            preRollEndMs: episode.preRollEndMs,
          ),
        ),
      );
    }
  }
  return drafts;
}

void _keepSpan(
  Map<int, List<_FrameSpan>> spans,
  int episodeId,
  int start,
  int end,
  int votes,
) {
  final list = spans.putIfAbsent(episodeId, () => <_FrameSpan>[]);
  for (final span in list) {
    if (!_overlapEdge(episodeId, span.start, span.end, episodeId, start, end)) {
      continue;
    }
    if (start < span.start) span.start = start;
    if (end > span.end) span.end = end;
    if (votes > span.votes) span.votes = votes;
    return;
  }
  list.add(_FrameSpan(start, end, votes));
}

List<_FrameSpan> _mergeSpans(List<_FrameSpan> spans, {required bool outro}) {
  if (spans.length < 2) return spans;
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_FrameSpan>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final previous = merged.last;
    final gapMs = (sorted[i].start - previous.end) * olafStepMs;
    final close = _overlapEdge(
      0,
      previous.start,
      previous.end,
      0,
      sorted[i].start,
      sorted[i].end,
    );
    if (close || (outro && gapMs >= 0 && gapMs <= _outroBridgeMs)) {
      if (sorted[i].end > previous.end) previous.end = sorted[i].end;
      if (sorted[i].votes > previous.votes) previous.votes = sorted[i].votes;
      continue;
    }
    merged.add(sorted[i]);
  }
  return merged;
}

bool _inOutro(int durationMs, int startMs) {
  if (durationMs <= 0) return false;
  final fromEnd = durationMs - startMs;
  return fromEnd > 0 && fromEnd <= outroWindowMs;
}

List<_Draft> _refineDrafts(List<_Draft> drafts, Map<int, _Episode> byId) {
  final refined = _refineHits([for (final draft in drafts) draft.hit], byId);
  return [
    for (var i = 0; i < drafts.length; i++)
      _Draft(
        episodeId: drafts[i].episodeId,
        rawStart: drafts[i].rawStart,
        rawEnd: drafts[i].rawEnd,
        votes: drafts[i].votes,
        hit: refined[i],
      ),
  ];
}

List<PlannedSegment> _refinePlanned(
  List<PlannedSegment> segments,
  Map<int, _Episode> byId,
) {
  final hits = [
    for (final segment in segments)
      SegmentOccurrence(
        episodeId: segment.episodeId,
        startMs: segment.startMs,
        endMs: segment.endMs,
        episodeDurationMs: byId[segment.episodeId]?.durationMs ?? 0,
        preRollEndMs: byId[segment.episodeId]?.preRollEndMs,
      ),
  ];
  final refined = _refineHits(hits, byId);
  return [
    for (var i = 0; i < segments.length; i++)
      if (refined[i].endMs - refined[i].startMs >= adMinDurationMs)
        PlannedSegment(
          episodeId: segments[i].episodeId,
          startMs: refined[i].startMs,
          endMs: refined[i].endMs,
          kind: segments[i].kind,
          confirmed: segments[i].confirmed,
          matches: segments[i].matches,
          confidence: segments[i].confidence,
        ),
  ];
}

List<SegmentOccurrence> _refineHits(
  List<SegmentOccurrence> hits,
  Map<int, _Episode> byId,
) {
  final shifted = _shiftHits(hits, byId);
  return [for (final hit in shifted) _snapHit(hit, byId[hit.episodeId])];
}

List<SegmentOccurrence> _shiftHits(
  List<SegmentOccurrence> hits,
  Map<int, _Episode> byId,
) {
  if (hits.length < 2) return hits;
  final anchor = hits.firstWhere(
    (hit) => byId[hit.episodeId]?.envelope?.isNotEmpty == true,
    orElse: () => hits.first,
  );
  final anchorBytes = byId[anchor.episodeId]?.envelope;
  if (anchorBytes == null || anchorBytes.isEmpty) return hits;
  final shifts = <EnvelopeShift>[];
  for (final hit in hits) {
    if (identical(hit, anchor)) continue;
    final other = byId[hit.episodeId]?.envelope;
    if (other == null || other.isEmpty) continue;
    final shift = envelopeEdgeShift(
      anchor: anchorBytes,
      other: other,
      anchorStartMs: anchor.startMs,
      anchorEndMs: anchor.endMs,
      otherStartMs: hit.startMs,
      otherEndMs: hit.endMs,
    );
    if (shift != null) shifts.add(shift);
  }
  if (shifts.isEmpty) return hits;
  final startShift = _median([for (final shift in shifts) shift.startMs]);
  final endShift = _median([for (final shift in shifts) shift.endMs]);
  return [for (final hit in hits) _shiftOccurrence(hit, startShift, endShift)];
}

SegmentOccurrence _snapHit(SegmentOccurrence hit, _Episode? episode) {
  final envelope = episode?.envelope;
  var start = hit.startMs;
  var end = hit.endMs;
  if (envelope != null && envelope.isNotEmpty) {
    final snapped = snapPortionToSilence(
      envelope,
      start,
      end,
      durationMs: hit.episodeDurationMs,
    );
    start = snapped.startMs;
    end = snapped.endMs;
  }
  final reachesEnd =
      hit.episodeDurationMs > 0 && hit.episodeDurationMs - end <= 500;
  if (!reachesEnd && end - start > olafAdMaxDurationMs) {
    end = start + olafAdMaxDurationMs;
  }
  if (end <= start) return hit;
  return SegmentOccurrence(
    episodeId: hit.episodeId,
    startMs: start,
    endMs: end,
    episodeDurationMs: hit.episodeDurationMs,
    preRollEndMs: hit.preRollEndMs,
  );
}

SegmentOccurrence _shiftOccurrence(
  SegmentOccurrence hit,
  int startShift,
  int endShift,
) {
  var start = hit.startMs + startShift;
  var end = hit.endMs + endShift;
  if (start < 0) start = 0;
  if (hit.episodeDurationMs > 0 && end > hit.episodeDurationMs) {
    end = hit.episodeDurationMs;
  }
  if (end <= start) return hit;
  return SegmentOccurrence(
    episodeId: hit.episodeId,
    startMs: start,
    endMs: end,
    episodeDurationMs: hit.episodeDurationMs,
    preRollEndMs: hit.preRollEndMs,
  );
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

Uint8List _templateOf(
  _Found found,
  List<SegmentOccurrence> fresh,
  Map<int, _Episode> byId,
) {
  _Draft? best;
  for (final draft in found.drafts) {
    if (!fresh.any((hit) => hit.episodeId == draft.episodeId)) continue;
    if (best == null ||
        draft.rawEnd - draft.rawStart > best.rawEnd - best.rawStart) {
      best = draft;
    }
  }
  final anchor = best;
  final episode = anchor == null ? null : byId[anchor.episodeId];
  if (anchor == null || episode == null) return encodeOlafAdPrints(const []);
  final hit = fresh.firstWhere((item) => item.episodeId == anchor.episodeId);
  final origin = hit.startMs ~/ olafStepMs;
  final marks = <OlafLandmark>[];
  for (var i = 0; i < episode.table.count; i++) {
    final time = episode.table.timeAt(i);
    if (time < anchor.rawStart || time > anchor.rawEnd) continue;
    final relative = time - origin;
    if (relative < 0) continue;
    marks.add(OlafLandmark(hash: episode.table.hashAt(i), t1: relative));
  }
  return encodeOlafAdPrints(marks);
}

_Located? _locate(
  _Table needle,
  OlafHashIndex index, {
  required int durationMs,
}) {
  final times = index.times;
  final tally = <int, int>{};
  for (var i = 0; i < needle.count; i++) {
    final id = index.find(needle.hashAt(i));
    if (id < 0) continue;
    final end = index.end(id);
    final relative = needle.timeAt(i);
    for (var k = index.start(id); k < end; k++) {
      final time = times[k];
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
  return _Located(start, start + capped, best);
}

bool _claimed(
  Map<int, List<_Range>> claimed,
  int episodeId,
  int start,
  int end,
) {
  final ranges = claimed[episodeId];
  if (ranges == null) return false;
  for (final range in ranges) {
    final overlapStart = start > range.start ? start : range.start;
    final overlapEnd = end < range.end ? end : range.end;
    if (overlapEnd <= overlapStart) continue;
    final shorter = (end - start) < (range.end - range.start)
        ? (end - start)
        : (range.end - range.start);
    if (shorter > 0 && (overlapEnd - overlapStart) * 2 >= shorter) return true;
  }
  return false;
}

Uint8List? _asBytes(Object? raw) {
  if (raw == null) return null;
  if (raw is Uint8List) return raw;
  if (raw is List) return Uint8List.fromList(raw.cast<int>());
  return null;
}

SkipSegmentKind _kindOf(String name) {
  for (final kind in SkipSegmentKind.values) {
    if (kind.name == name) return kind;
  }
  return SkipSegmentKind.other;
}

Map<String, Object?> _encodePlan(AnalysisPlan plan) {
  return {
    'patterns': [
      for (final pattern in plan.patterns)
        <String, Object?>{
          'templateId': pattern.templateId,
          'kind': pattern.kind.name,
          'confirmed': pattern.confirmed,
          'durationMs': pattern.durationMs,
          'fingerprint': pattern.fingerprint,
          'fingerprintBytes': pattern.fingerprintBytes,
          'confidence': pattern.confidence,
          'segments': [
            for (final segment in pattern.segments)
              <String, Object?>{
                'episodeId': segment.episodeId,
                'startMs': segment.startMs,
                'endMs': segment.endMs,
                'kind': segment.kind.name,
                'confirmed': segment.confirmed,
                'matches': segment.matches,
                'confidence': segment.confidence,
              },
          ],
        },
    ],
  };
}

typedef OlafAdEdgeVotes = ({
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
  int votes,
});

typedef OlafAdLocation = ({int startFrame, int endFrame, int votes});

/// One parsed Olaf ad print with its cached index. Exposed for the
/// equivalence tests and the benchmark; [planOlafAds] uses the same code.
final class OlafAdIndexed {
  OlafAdIndexed._(this._episode);

  static OlafAdIndexed? parse(Uint8List bytes, {int episodeId = 0}) {
    final table = _Table.tryParse(bytes);
    if (table == null) return null;
    final source = OlafAdEpisode(
      episodeId: episodeId,
      prints: bytes,
      durationMs: 0,
    );
    return OlafAdIndexed._(_Episode(source, table));
  }

  final _Episode _episode;

  OlafHashIndex get index => _episode.index;

  List<OlafAdEdgeVotes> alignWith(OlafAdIndexed right) => [
    for (final edge in _align(_episode, right._episode))
      (
        leftStart: edge.leftStart,
        leftEnd: edge.leftEnd,
        rightStart: edge.rightStart,
        rightEnd: edge.rightEnd,
        votes: edge.votes,
      ),
  ];

  OlafAdLocation? locate(Uint8List needle, {required int durationMs}) {
    final table = _Table.tryParse(needle);
    if (table == null) return null;
    final located = _locate(table, index, durationMs: durationMs);
    if (located == null) return null;
    return (
      startFrame: located.startFrame,
      endFrame: located.endFrame,
      votes: located.votes,
    );
  }
}
