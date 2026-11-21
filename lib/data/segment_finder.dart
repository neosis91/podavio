import 'dart:math' as math;
import 'dart:typed_data';

import 'envelope.dart';
import 'segment_match.dart';
import 'skip_segments.dart';
import 'speech_music.dart';

/// Au-delà, une valeur est trop banale (silence) : on n’en garde qu’un
/// échantillon pour le vote, sinon chaque décalage ramasse des voix.
const _commonValueCap = 48;

/// Décalages suivis au plus pendant un vote. Au-delà, on ne garde que
/// ceux qui ont déjà plusieurs voix : une pub s’accumule, le bruit non.
const _maxVoteKeys = 8192;

/// Voix exactes minimum pour retenir un décalage.
const _minVotes = 4;

/// Décalages vérifiés au plus, les mieux dotés d’abord.
const _maxCandidateDeltas = 64;

/// Un passage connu est retrouvé s’il couvre au moins cette part du gabarit.
const _templateCoverageNumerator = 6;
const _templateCoverageDenominator = 10;

/// Épisode déjà empreinté, prêt à être comparé.
class FingerprintEpisode {
  const FingerprintEpisode({
    required this.episodeId,
    required this.values,
    required this.hopMicros,
    required this.durationMs,
    this.preRollEndMs,
    this.speech,
    this.envelope,
  });

  final int episodeId;
  final List<int> values;
  final int hopMicros;
  final int durationMs;
  final int? preRollEndMs;

  /// Une octet par seconde, 0 musique … 255 parole. `null` : pas encore noté.
  final Uint8List? speech;

  /// Énergie toutes les 20 ms. `null` : épisode empreinté avant le recalage.
  /// L’analyse ne redécode pas seulement pour la remplir.
  final Uint8List? envelope;
}

/// Gabarit déjà en base. Le rapprochement rapide s’en sert avant
/// de chercher des motifs nouveaux.
class KnownTemplate {
  const KnownTemplate({
    required this.id,
    required this.kind,
    required this.fingerprint,
    required this.durationMs,
    required this.confirmed,
    this.confidence,
  });

  final int id;
  final SkipSegmentKind kind;
  final List<int> fingerprint;
  final int durationMs;

  /// Avis agrégé des passages : `false` = ignoré, on le propage.
  final bool? confirmed;

  /// 0–100. `null` : gabarit posé avant le score.
  final int? confidence;
}

/// Passage à écrire pour un épisode.
class PlannedSegment {
  const PlannedSegment({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.kind,
    required this.confirmed,
    required this.matches,
    required this.confidence,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final SkipSegmentKind kind;
  final bool? confirmed;
  final int matches;

  /// 0–100. Le saut n’en dépend pas.
  final int confidence;
}

/// Motif, nouveau ou déjà rattaché à un gabarit.
class PlannedPattern {
  const PlannedPattern({
    required this.templateId,
    required this.kind,
    required this.confirmed,
    required this.fingerprint,
    required this.durationMs,
    required this.segments,
    required this.confidence,
  });

  /// `null` : gabarit à créer.
  final int? templateId;
  final SkipSegmentKind kind;
  final bool? confirmed;
  final List<int> fingerprint;
  final int durationMs;
  final List<PlannedSegment> segments;

  /// 0–100, recopié sur le gabarit.
  final int confidence;

  int get occurrences =>
      segments.map((segment) => segment.episodeId).toSet().length;
}

/// Résultat pur, sans base. L’écriture est idempotente à part.
class AnalysisPlan {
  const AnalysisPlan(this.patterns);

  final List<PlannedPattern> patterns;
}

/// D’abord les gabarits connus, puis les motifs nouveaux.
AnalysisPlan buildAnalysisPlan({
  required List<FingerprintEpisode> episodes,
  required List<KnownTemplate> templates,
  int? focusEpisodeId,
}) {
  final usable = [
    for (final episode in episodes)
      if (episode.values.length >= 8 && episode.hopMicros > 0) episode,
  ];
  final hop = usable.isEmpty ? 0 : usable.first.hopMicros;
  final byId = {for (final episode in usable) episode.episodeId: episode};
  final indexes = {
    for (final episode in usable) episode.episodeId: _Index(episode.values),
  };
  final patterns = <PlannedPattern>[];
  final claimed = <int, List<_Range>>{};

  for (final template in templates) {
    if (template.fingerprint.length < 8) continue;
    final segments = <PlannedSegment>[];
    for (final episode in usable) {
      if (episode.hopMicros != hop && hop != 0) continue;
      final ranges = _matchNeedle(
        template.fingerprint,
        episode.values,
        requireTemplateShape: true,
        index: indexes[episode.episodeId],
      );
      for (final range in ranges) {
        final startMs = _indexMs(range.start, episode.hopMicros);
        final endMs = _indexMs(range.end, episode.hopMicros);
        if (endMs <= startMs) continue;
        segments.add(
          PlannedSegment(
            episodeId: episode.episodeId,
            startMs: startMs,
            endMs: endMs,
            kind: template.kind,
            confirmed: template.confirmed,
            matches: 0,
            confidence: _templateConfidence(template),
          ),
        );
      }
    }
    if (segments.isEmpty) continue;
    final refinedSegments = _refinePlanned(segments, byId);
    for (final segment in refinedSegments) {
      (claimed[segment.episodeId] ??= []).add(
        _Range(segment.startMs, segment.endMs),
      );
    }
    patterns.add(
      _withMatches(
        PlannedPattern(
          templateId: template.id,
          kind: template.kind,
          confirmed: template.confirmed,
          fingerprint: template.fingerprint,
          durationMs: template.durationMs,
          segments: refinedSegments,
          confidence: _templateConfidence(template),
        ),
      ),
    );
  }

  for (final found in _discoverPatterns(
    usable,
    focusEpisodeId: focusEpisodeId,
    indexes: indexes,
  )) {
    final similar = _similarTemplate(found, templates);
    if (similar != null) {
      final extras = [
        for (final hit in found.occurrences)
          if (!_claimed(claimed, hit.episodeId, hit.startMs, hit.endMs)) hit,
      ];
      if (extras.isEmpty) continue;
      final host = patterns.indexWhere(
        (pattern) => pattern.templateId == similar.id,
      );
      final extraSegments = [
        for (final hit in extras)
          PlannedSegment(
            episodeId: hit.episodeId,
            startMs: hit.startMs,
            endMs: hit.endMs,
            kind: similar.kind,
            confirmed: similar.confirmed,
            matches: 0,
            confidence: _templateConfidence(similar),
          ),
      ];
      if (host >= 0) {
        patterns[host] = _withMatches(
          PlannedPattern(
            templateId: similar.id,
            kind: similar.kind,
            confirmed: similar.confirmed,
            fingerprint: patterns[host].fingerprint,
            durationMs: patterns[host].durationMs,
            segments: [...patterns[host].segments, ...extraSegments],
            confidence: patterns[host].confidence,
          ),
        );
      } else {
        patterns.add(
          _withMatches(
            PlannedPattern(
              templateId: similar.id,
              kind: similar.kind,
              confirmed: similar.confirmed,
              fingerprint: found.fingerprint,
              durationMs: found.durationMs,
              segments: extraSegments,
              confidence: _templateConfidence(similar),
            ),
          ),
        );
      }
      for (final hit in extras) {
        (claimed[hit.episodeId] ??= []).add(_Range(hit.startMs, hit.endMs));
      }
      continue;
    }

    final fresh = [
      for (final hit in found.occurrences)
        if (!_claimed(claimed, hit.episodeId, hit.startMs, hit.endMs)) hit,
    ];
    if (fresh.isEmpty) continue;
    final decision = fresh.length == found.occurrences.length
        ? found.classification
        : _keep(fresh, byId);
    if (decision == null) continue;
    final kind = decision.kind ?? SkipSegmentKind.other;
    final confirmed = decision.autoSkip ? null : false;
    patterns.add(
      _withMatches(
        PlannedPattern(
          templateId: null,
          kind: kind,
          confirmed: confirmed,
          fingerprint: found.fingerprint,
          durationMs: found.durationMs,
          confidence: decision.confidence,
          segments: [
            for (final hit in fresh)
              PlannedSegment(
                episodeId: hit.episodeId,
                startMs: hit.startMs,
                endMs: hit.endMs,
                kind: kind,
                confirmed: confirmed,
                matches: 0,
                confidence: decision.confidence,
              ),
          ],
        ),
      ),
    );
  }
  return AnalysisPlan(patterns);
}

/// Motif repéré entre épisodes, avant l’écriture.
class DiscoveredPattern {
  const DiscoveredPattern({
    required this.fingerprint,
    required this.durationMs,
    required this.occurrences,
    required this.classification,
  });

  final List<int> fingerprint;
  final int durationMs;
  final List<SegmentOccurrence> occurrences;
  final SegmentClassification classification;
}

/// Index inversé et vote par décalage, sur les empreintes données.
///
/// [focusEpisodeId] ne compare que les paires qui contiennent cet
/// épisode. Les motifs déjà posés en gabarit sont réappliqués à part.
/// L’index de chaque épisode n’est construit qu’une fois.
List<DiscoveredPattern> discoverPatterns(
  List<FingerprintEpisode> episodes, {
  int? focusEpisodeId,
}) {
  return _discoverPatterns(episodes, focusEpisodeId: focusEpisodeId);
}

List<DiscoveredPattern> _discoverPatterns(
  List<FingerprintEpisode> episodes, {
  int? focusEpisodeId,
  Map<int, _Index>? indexes,
}) {
  if (episodes.isEmpty) return const [];
  final byId = {for (final episode in episodes) episode.episodeId: episode};
  final built =
      indexes ??
      {
        for (final episode in episodes)
          episode.episodeId: _Index(episode.values),
      };
  final clusters = _Clusters();
  for (var i = 0; i < episodes.length; i++) {
    for (var j = i; j < episodes.length; j++) {
      final left = episodes[i].episodeId;
      final right = episodes[j].episodeId;
      if (focusEpisodeId != null &&
          left != focusEpisodeId &&
          right != focusEpisodeId) {
        continue;
      }
      final index = built[right];
      if (index == null) continue;
      _compare(episodes[i], episodes[j], clusters, self: i == j, index: index);
    }
  }
  return _materialize(clusters, byId);
}

Map<String, Object?> encodeAnalysisInput({
  required List<FingerprintEpisode> episodes,
  required List<KnownTemplate> templates,
}) {
  return {
    'episodes': [
      for (final episode in episodes)
        <Object?>[
          episode.episodeId,
          episode.hopMicros,
          episode.durationMs,
          episode.preRollEndMs,
          episode.values,
          episode.speech,
          episode.envelope,
        ],
    ],
    'templates': [
      for (final template in templates)
        <Object?>[
          template.id,
          template.kind.name,
          template.confirmed,
          template.durationMs,
          template.fingerprint,
          template.confidence,
        ],
    ],
  };
}

/// Entrée d’isolate : le message ne contient que des types transportables.
Map<String, Object?> planAnalysisMessage(Map<String, Object?> message) {
  final episodes = <FingerprintEpisode>[];
  for (final raw in message['episodes']! as List) {
    final row = raw! as List;
    final blob = _bytes(row[4]) ?? Uint8List(0);
    episodes.add(
      FingerprintEpisode(
        episodeId: row[0]! as int,
        hopMicros: row[1]! as int,
        durationMs: row[2]! as int,
        preRollEndMs: row[3] as int?,
        values: decodeFingerprint(blob),
        speech: row.length > 5 ? _bytes(row[5]) : null,
        envelope: row.length > 6 ? _bytes(row[6]) : null,
      ),
    );
  }
  final templates = <KnownTemplate>[];
  for (final raw in message['templates']! as List) {
    final row = raw! as List;
    templates.add(
      KnownTemplate(
        id: row[0]! as int,
        kind: _kindOf(row[1]! as String),
        confirmed: row[2] as bool?,
        durationMs: row[3]! as int,
        fingerprint: decodeFingerprint(_bytes(row[4]) ?? Uint8List(0)),
        confidence: row.length > 5 ? row[5] as int? : null,
      ),
    );
  }
  return _encodePlan(
    buildAnalysisPlan(
      episodes: episodes,
      templates: templates,
      focusEpisodeId: message['focus'] as int?,
    ),
  );
}

AnalysisPlan decodeAnalysisPlan(Map<Object?, Object?> message) {
  final patterns = <PlannedPattern>[];
  for (final raw in message['patterns']! as List) {
    final row = _map(raw);
    final segments = <PlannedSegment>[];
    for (final item in row['segments']! as List) {
      final segment = _map(item);
      segments.add(
        PlannedSegment(
          episodeId: segment['episodeId']! as int,
          startMs: segment['startMs']! as int,
          endMs: segment['endMs']! as int,
          kind: _kindOf(segment['kind']! as String),
          confirmed: segment['confirmed'] as bool?,
          matches: segment['matches']! as int,
          confidence: segment['confidence'] as int? ?? crossEpisodeConfidence,
        ),
      );
    }
    patterns.add(
      PlannedPattern(
        templateId: row['templateId'] as int?,
        kind: _kindOf(row['kind']! as String),
        confirmed: row['confirmed'] as bool?,
        fingerprint: (row['fingerprint']! as List).cast<int>(),
        durationMs: row['durationMs']! as int,
        segments: segments,
        confidence: row['confidence'] as int? ?? crossEpisodeConfidence,
      ),
    );
  }
  return AnalysisPlan(patterns);
}

Map<Object?, Object?> _map(Object? raw) {
  return Map<Object?, Object?>.from(raw! as Map);
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

void _compare(
  FingerprintEpisode a,
  FingerprintEpisode b,
  _Clusters clusters, {
  required bool self,
  required _Index index,
}) {
  if (a.hopMicros != b.hopMicros || a.values.isEmpty || b.values.isEmpty) {
    return;
  }
  final hop = a.hopMicros;
  final minDelta = self ? _pointsForMs(selfMatchMinOffsetMs, hop) : null;
  final votes = <int, _Tally>{};
  for (var i = 0; i < a.values.length; i++) {
    final hits = index.offsets[a.values[i]];
    if (hits == null) continue;
    for (final j in hits) {
      final delta = i - j;
      if (minDelta != null && delta < minDelta) continue;
      _vote(votes, delta, i);
    }
  }
  final candidates = [
    for (final entry in votes.entries)
      if (entry.value.count >= _minVotes) entry,
  ]..sort((left, right) => right.value.count.compareTo(left.value.count));
  final limited = candidates.length > _maxCandidateDeltas
      ? candidates.sublist(0, _maxCandidateDeltas)
      : candidates;
  for (final candidate in limited) {
    final tally = candidate.value;
    final span = tally.max - tally.min + 1;
    // Des ancres trop espacées ne font pas une pub : on évite de
    // reparcourir tout l’épisode pour un décalage de silence.
    if (span > tally.count * 80 + 128) continue;
    final window = _tightSpan(
      a.values,
      b.values,
      candidate.key,
      tally.min,
      tally.max,
    );
    for (final run in _runs(
      a.values,
      b.values,
      candidate.key,
      from: window.$1,
      to: window.$2,
    )) {
      final points = run.end - run.start;
      final durationMs = _spanMs(points, hop);
      final startA = _indexMs(run.start, hop);
      final startB = _indexMs(run.start - candidate.key, hop);
      final long = durationMs >= adMinDurationMs;
      final jingle =
          durationMs >= jingleMinDurationMs &&
          startA <= jingleSearchWindowMs &&
          startB >= 0 &&
          startB <= jingleSearchWindowMs;
      if (!long && !jingle) continue;
      if (!chromaprintAgreementOk(run.matches, points)) continue;
      final pieces = _splitWeak(a.values, b.values, candidate.key, run);
      for (final piece in pieces) {
        _keepRun(a, b, candidate.key, piece, hop, clusters);
      }
    }
  }
}

void _keepRun(
  FingerprintEpisode a,
  FingerprintEpisode b,
  int delta,
  _Range run,
  int hop,
  _Clusters clusters,
) {
  final points = run.end - run.start;
  final durationMs = _spanMs(points, hop);
  final startA = _indexMs(run.start, hop);
  final startB = _indexMs(run.start - delta, hop);
  final long = durationMs >= adMinDurationMs;
  final jingle =
      durationMs >= jingleMinDurationMs &&
      startA <= jingleSearchWindowMs &&
      startB >= 0 &&
      startB <= jingleSearchWindowMs;
  if (!long && !jingle) return;
  if (!chromaprintAgreementOk(run.matches, points)) return;
  if (!_distinctive(a.values, run.start, run.end)) return;
  clusters.add(
    a.episodeId,
    run.start,
    run.end,
    b.episodeId,
    run.start - delta,
    run.end - delta,
    hop,
  );
}

class _Index {
  _Index(List<int> values) {
    final buckets = <int, List<int>>{};
    for (var i = 0; i < values.length; i++) {
      (buckets[values[i]] ??= []).add(i);
    }
    for (final entry in buckets.entries) {
      final offsets = entry.value;
      if (offsets.length <= _commonValueCap) {
        this.offsets[entry.key] = offsets;
        continue;
      }
      final kept = <int>[];
      final step = offsets.length / _commonValueCap;
      for (var i = 0; i < _commonValueCap; i++) {
        kept.add(offsets[(i * step).floor()]);
      }
      this.offsets[entry.key] = kept;
    }
  }

  final offsets = <int, List<int>>{};
}

class _Range {
  const _Range(this.start, this.end, [this.matches = 0]);

  final int start;
  final int end;
  final int matches;
}

List<_Range> _runs(List<int> a, List<int> b, int delta, {int? from, int? to}) {
  var startI = math.max(0, delta);
  var endI = math.min(a.length, b.length + delta);
  if (from != null && from > startI) startI = from;
  if (to != null && to < endI) endI = to;
  final found = <_Range>[];
  var runStart = -1;
  var last = -1;
  var gap = 0;
  var matches = 0;
  void close() {
    if (runStart >= 0 && last >= runStart) {
      found.add(_Range(runStart, last + 1, matches));
    }
    runStart = -1;
    last = -1;
    gap = 0;
    matches = 0;
  }

  for (var i = startI; i < endI; i++) {
    if (chromaprintValuesMatch(a[i], b[i - delta])) {
      if (runStart < 0) runStart = i;
      last = i;
      gap = 0;
      matches++;
    } else if (runStart >= 0) {
      gap++;
      if (gap > chromaprintMaxGapPoints) close();
    }
  }
  close();
  return found;
}

/// Coupe un passage dont une fenêtre d’environ une seconde ne correspond
/// presque plus. Les deux morceaux sont revus ensuite pour la durée.
List<_Range> _splitWeak(List<int> a, List<int> b, int delta, _Range run) {
  const window = 8;
  const minHits = 3;
  final length = run.end - run.start;
  if (length <= window) return [run];
  final cuts = <int>[];
  var weak = -1;
  for (var i = run.start; i + window <= run.end; i++) {
    var hits = 0;
    for (var j = i; j < i + window; j++) {
      if (chromaprintValuesMatch(a[j], b[j - delta])) hits++;
    }
    if (hits < minHits) {
      if (weak < 0) weak = i;
    } else if (weak >= 0) {
      cuts.add(weak + window ~/ 2);
      weak = -1;
    }
  }
  if (weak >= 0) cuts.add(weak + window ~/ 2);
  if (cuts.isEmpty) return [run];
  final pieces = <_Range>[];
  var cursor = run.start;
  for (final cut in cuts) {
    if (cut - cursor >= 8) {
      pieces.add(_Range(cursor, cut, _countMatches(a, b, delta, cursor, cut)));
    }
    cursor = cut;
  }
  if (run.end - cursor >= 8) {
    pieces.add(
      _Range(cursor, run.end, _countMatches(a, b, delta, cursor, run.end)),
    );
  }
  return pieces.isEmpty ? [run] : pieces;
}

int _countMatches(List<int> a, List<int> b, int delta, int start, int end) {
  var matches = 0;
  for (var i = start; i < end; i++) {
    if (chromaprintValuesMatch(a[i], b[i - delta])) matches++;
  }
  return matches;
}

class _Tally {
  _Tally(int index) : count = 1, min = index, max = index;

  int count;
  int min;
  int max;
}

void _vote(Map<int, _Tally> votes, int delta, int index) {
  final current = votes[delta];
  if (current != null) {
    current.count++;
    if (index < current.min) current.min = index;
    if (index > current.max) current.max = index;
    return;
  }
  if (votes.length < _maxVoteKeys) {
    votes[delta] = _Tally(index);
    return;
  }
  votes.removeWhere((_, tally) => tally.count < 2);
  if (votes.length >= _maxVoteKeys) return;
  votes[delta] = _Tally(index);
}

/// Étend [min] et [max] tant que la distance de Hamming suit, puis
/// s’arrête au premier trou trop long. Le parcours ne couvre que le passage.
(int, int) _tightSpan(
  List<int> a,
  List<int> b,
  int delta,
  int minIndex,
  int maxIndex,
) {
  final startLimit = math.max(0, delta);
  final endLimit = math.min(a.length, b.length + delta);
  if (endLimit <= startLimit) return (startLimit, startLimit);
  var lo = minIndex.clamp(startLimit, endLimit - 1);
  var hi = maxIndex.clamp(lo, endLimit - 1);
  var gap = 0;
  for (var i = lo - 1; i >= startLimit; i--) {
    if (chromaprintValuesMatch(a[i], b[i - delta])) {
      lo = i;
      gap = 0;
    } else if (++gap > chromaprintMaxGapPoints) {
      break;
    }
  }
  gap = 0;
  for (var i = hi + 1; i < endLimit; i++) {
    if (chromaprintValuesMatch(a[i], b[i - delta])) {
      hi = i;
      gap = 0;
    } else if (++gap > chromaprintMaxGapPoints) {
      break;
    }
  }
  return (lo, hi + 1);
}

List<_Range> _matchNeedle(
  List<int> needle,
  List<int> haystack, {
  required bool requireTemplateShape,
  _Index? index,
}) {
  if (needle.length < 8 || haystack.isEmpty) return const [];
  final built = index ?? _Index(haystack);
  final votes = <int, _Tally>{};
  for (var j = 0; j < needle.length; j++) {
    final hits = built.offsets[needle[j]];
    if (hits == null) continue;
    for (final i in hits) {
      final delta = i - j;
      _vote(votes, delta, i);
    }
  }
  final candidates = [
    for (final entry in votes.entries)
      if (entry.value.count >= _minVotes) entry,
  ]..sort((left, right) => right.value.count.compareTo(left.value.count));
  final limited = candidates.length > _maxCandidateDeltas
      ? candidates.sublist(0, _maxCandidateDeltas)
      : candidates;
  final found = <_Range>[];
  for (final candidate in limited) {
    final tally = candidate.value;
    final span = tally.max - tally.min + 1;
    if (span > tally.count * 80 + 128) continue;
    final window = _tightSpan(
      haystack,
      needle,
      candidate.key,
      tally.min,
      tally.max,
    );
    for (final run in _runs(
      haystack,
      needle,
      candidate.key,
      from: window.$1,
      to: window.$2,
    )) {
      final span = run.end - run.start;
      final covered =
          span * _templateCoverageDenominator >=
          needle.length * _templateCoverageNumerator;
      final shaped = !requireTemplateShape || span <= needle.length + 8;
      if (covered &&
          shaped &&
          chromaprintAgreementOk(run.matches, run.end - run.start) &&
          _distinctive(haystack, run.start, run.end)) {
        found.add(run);
      }
    }
  }
  return _mergeRanges(found);
}

bool _distinctive(List<int> values, int start, int end) {
  final seen = <int>{};
  for (var i = start; i < end && i < values.length; i++) {
    if (i < 0) continue;
    seen.add(values[i]);
    if (seen.length >= 3) return true;
  }
  return false;
}

List<_Range> _mergeRanges(List<_Range> ranges) {
  if (ranges.length < 2) return ranges;
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Range>[sorted.first];
  for (final range in sorted.skip(1)) {
    final last = merged.last;
    if (_overlapFraction(last.start, last.end, range.start, range.end) >= 0.5) {
      merged[merged.length - 1] = _Range(
        math.min(last.start, range.start),
        math.max(last.end, range.end),
      );
    } else {
      merged.add(range);
    }
  }
  return merged;
}

class _Span {
  _Span(this.episodeId, this.start, this.end, this.cluster, this.hopMicros);

  final int episodeId;
  int start;
  int end;
  int cluster;
  final int hopMicros;
}

class _Clusters {
  final _parent = <int, int>{};
  final spans = <_Span>[];

  int _make() {
    final id = _parent.length;
    _parent[id] = id;
    return id;
  }

  int find(int id) {
    var root = id;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    var node = id;
    while (_parent[node] != root) {
      final next = _parent[node]!;
      _parent[node] = root;
      node = next;
    }
    return root;
  }

  void _union(int a, int b) {
    final left = find(a);
    final right = find(b);
    if (left != right) _parent[right] = left;
  }

  void add(
    int episodeA,
    int startA,
    int endA,
    int episodeB,
    int startB,
    int endB,
    int hopMicros,
  ) {
    if (startA < 0 || startB < 0 || endA <= startA || endB <= startB) return;
    final touching = <_Span>[];
    for (final span in spans) {
      span.cluster = find(span.cluster);
      final hitA =
          span.episodeId == episodeA &&
          _indexOverlap(span.start, span.end, startA, endA);
      final hitB =
          span.episodeId == episodeB &&
          _indexOverlap(span.start, span.end, startB, endB);
      if (hitA || hitB) touching.add(span);
    }
    var cluster = touching.isEmpty ? _make() : find(touching.first.cluster);
    for (final span in touching) {
      _union(cluster, span.cluster);
    }
    cluster = find(cluster);
    for (final span in touching) {
      span.cluster = find(span.cluster);
    }
    _absorb(episodeA, startA, endA, cluster, hopMicros);
    _absorb(episodeB, startB, endB, cluster, hopMicros);
  }

  void _absorb(int episodeId, int start, int end, int cluster, int hopMicros) {
    for (final span in spans) {
      if (span.episodeId != episodeId || find(span.cluster) != cluster) {
        continue;
      }
      if (!_indexOverlap(span.start, span.end, start, end)) continue;
      if (start < span.start) span.start = start;
      if (end > span.end) span.end = end;
      return;
    }
    spans.add(_Span(episodeId, start, end, cluster, hopMicros));
  }
}

bool _indexOverlap(int a0, int a1, int b0, int b1) {
  return _overlapFraction(a0, a1, b0, b1) >= 0.5;
}

double _overlapFraction(int a0, int a1, int b0, int b1) {
  final start = math.max(a0, b0);
  final end = math.min(a1, b1);
  if (end <= start) return 0;
  final shorter = math.min(a1 - a0, b1 - b0);
  if (shorter <= 0) return 0;
  return (end - start) / shorter;
}

List<DiscoveredPattern> _materialize(
  _Clusters clusters,
  Map<int, FingerprintEpisode> byId,
) {
  final groups = <int, List<_Span>>{};
  for (final span in clusters.spans) {
    (groups[clusters.find(span.cluster)] ??= []).add(span);
  }
  final found = <DiscoveredPattern>[];
  for (final group in groups.values) {
    final occurrences = <SegmentOccurrence>[];
    _Span? longest;
    for (final span in group) {
      final episode = byId[span.episodeId];
      if (episode == null) continue;
      final startMs = _indexMs(span.start, span.hopMicros);
      final endMs = _indexMs(span.end, span.hopMicros);
      if (endMs <= startMs) continue;
      occurrences.add(
        SegmentOccurrence(
          episodeId: span.episodeId,
          startMs: startMs,
          endMs: endMs,
          episodeDurationMs: episode.durationMs,
          preRollEndMs: episode.preRollEndMs,
        ),
      );
      if (longest == null ||
          span.end - span.start > longest.end - longest.start) {
        longest = span;
      }
    }
    if (occurrences.isEmpty || longest == null) continue;
    final aligned = _refineOccurrences(occurrences, byId);
    final decision = _keep(aligned, byId);
    if (decision == null) continue;
    final episode = byId[longest.episodeId]!;
    final slice = episode.values.sublist(
      longest.start.clamp(0, episode.values.length),
      longest.end.clamp(0, episode.values.length),
    );
    if (slice.length < 8) continue;
    found.add(
      DiscoveredPattern(
        fingerprint: slice,
        durationMs: _spanMs(slice.length, longest.hopMicros),
        occurrences: aligned,
        classification: decision,
      ),
    );
  }
  return found;
}

SegmentClassification? _keep(
  List<SegmentOccurrence> hits,
  Map<int, FingerprintEpisode> byId,
) {
  if (hits.isEmpty) return null;
  final episodes = hits.map((hit) => hit.episodeId).toSet();
  final long = hits.every((hit) => adDurationQualifies(hit.durationMs));
  if (episodes.length >= 2 && long) return classifyRepeatedSegment(hits);
  if (acceptJingleCandidate(hits)) return classifyRepeatedSegment(hits);
  if (episodes.length < 2 && long) {
    final verdict = judgeIntraEpisodeRepeat(
      startsMs: [for (final hit in hits) hit.startMs],
      speechRatio: _speechOf(hits, byId),
    );
    if (verdict.reject) return null;
    return SegmentClassification(
      kind: null,
      autoSkip: false,
      confidence: verdict.confidence,
    );
  }
  return null;
}

List<PlannedSegment> _refinePlanned(
  List<PlannedSegment> segments,
  Map<int, FingerprintEpisode> byId,
) {
  final hits = [
    for (final segment in segments)
      SegmentOccurrence(
        episodeId: segment.episodeId,
        startMs: segment.startMs,
        endMs: segment.endMs,
        episodeDurationMs: byId[segment.episodeId]?.durationMs ?? 0,
      ),
  ];
  final refined = _refineOccurrences(hits, byId);
  return [
    for (var i = 0; i < segments.length; i++)
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

List<SegmentOccurrence> _refineOccurrences(
  List<SegmentOccurrence> hits,
  Map<int, FingerprintEpisode> byId,
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
  final startShift = _medianShift([for (final shift in shifts) shift.startMs]);
  final endShift = _medianShift([for (final shift in shifts) shift.endMs]);
  return [for (final hit in hits) _shiftOccurrence(hit, startShift, endShift)];
}

int _medianShift(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
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

double? _speechOf(
  List<SegmentOccurrence> hits,
  Map<int, FingerprintEpisode> byId,
) {
  var sum = 0.0;
  var count = 0;
  for (final hit in hits) {
    final ratio = speechRatioIn(
      byId[hit.episodeId]?.speech,
      hit.startMs,
      hit.endMs,
    );
    if (ratio == null) continue;
    sum += ratio;
    count++;
  }
  if (count == 0) return null;
  return sum / count;
}

int _templateConfidence(KnownTemplate template) {
  return template.confidence ?? crossEpisodeConfidence;
}

Uint8List? _bytes(Object? raw) {
  if (raw == null) return null;
  if (raw is Uint8List) return raw;
  if (raw is List) return Uint8List.fromList(raw.cast<int>());
  return null;
}

KnownTemplate? _similarTemplate(
  DiscoveredPattern found,
  List<KnownTemplate> templates,
) {
  for (final template in templates) {
    if (template.fingerprint.length < 8 || found.fingerprint.length < 8) {
      continue;
    }
    final needle = template.fingerprint.length <= found.fingerprint.length
        ? template.fingerprint
        : found.fingerprint;
    final haystack = identical(needle, template.fingerprint)
        ? found.fingerprint
        : template.fingerprint;
    if (_matchNeedle(needle, haystack, requireTemplateShape: true).isNotEmpty) {
      return template;
    }
  }
  return null;
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
    if (_overlapFraction(range.start, range.end, start, end) >= 0.5) {
      return true;
    }
  }
  return false;
}

PlannedPattern _withMatches(PlannedPattern pattern) {
  final matches = pattern.occurrences;
  return PlannedPattern(
    templateId: pattern.templateId,
    kind: pattern.kind,
    confirmed: pattern.confirmed,
    fingerprint: pattern.fingerprint,
    durationMs: pattern.durationMs,
    confidence: pattern.confidence,
    segments: [
      for (final segment in pattern.segments)
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
  );
}

int _indexMs(int index, int hopMicros) {
  if (index <= 0 || hopMicros <= 0) return 0;
  return index * hopMicros ~/ 1000;
}

int _spanMs(int points, int hopMicros) => _indexMs(points, hopMicros);

int _pointsForMs(int ms, int hopMicros) {
  if (hopMicros <= 0) return 0;
  return (ms * 1000 + hopMicros - 1) ~/ hopMicros;
}

SkipSegmentKind _kindOf(String name) {
  for (final kind in SkipSegmentKind.values) {
    if (kind.name == name) return kind;
  }
  return SkipSegmentKind.other;
}
