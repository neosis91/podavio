import 'dart:math' as math;
import 'dart:typed_data';

import 'chapters_parser.dart';
import 'envelope.dart';
import 'segment_match.dart';
import 'speech_music.dart';

/// En dessous, le contexte ne crée pas de passage tout seul.
///
/// Une correspondance d'empreinte reste. Le seuil ne sert qu'aux
/// propositions, pour ne pas découper la parole ordinaire.
const adContextProposeThreshold = 0.78;

/// Une lecture sponsor peut dépasser la minute que l'empreinte plafonne.
const adContextMaxDurationMs = 120000;

/// Le graphe mn04 n'est pas dans l'application : le test Dart n'a pas
/// d'interpréteur TFLite ni ONNX. La fusion n'en tient compte que si
/// l'appelant passe des mesures et lève [useMn04].
const mn04ContextEnabled = false;

const _silenceRunMs = 200;
const _jumpStartLu = 3.5;
const _jumpFullLu = 5.5;
const _toneMinMs = 12000;
const _toneMaxMs = 18000;
const _toneSpeechMax = 0.30;
const _toneRangeMax = 3.0;
const _toneJumpMax = 4.0;
const _musicUnderLow = 0.45;
const _musicUnderHigh = 0.86;

/// Chapitre déjà connu, borné par le suivant ou par la fin du fichier.
class AdContextChapter {
  const AdContextChapter({
    required this.startMs,
    required this.endMs,
    required this.title,
  });

  final int startMs;
  final int endMs;
  final String title;
}

/// Mesures mn04 sur une fenêtre. Les scores sont des sigmoïdes AudioSet.
///
/// [scoreJump] vaut `1 − cosinus` entre les vecteurs de classes de deux
/// fenêtres voisines. L'export utilisé n'expose pas l'embedding interne.
class Mn04Cue {
  const Mn04Cue({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    required this.speech,
    required this.music,
    required this.jingle,
    required this.backgroundMusic,
    required this.scoreJump,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final double speech;
  final double music;
  final double jingle;
  final double backgroundMusic;
  final double scoreJump;
}

/// Enveloppe, parole et chapitres déjà calculés. Pas un second décodage.
class AdContextEpisode {
  const AdContextEpisode({
    required this.durationMs,
    this.envelope,
    this.speech,
    this.chapters = const [],
  });

  final int durationMs;
  final Uint8List? envelope;
  final Uint8List? speech;
  final List<AdContextChapter> chapters;
}

/// Passage, d'empreinte ou proposé par le contexte.
class AdContextHit {
  const AdContextHit({
    required this.episodeId,
    required this.startMs,
    required this.endMs,
    this.score = 0,
  });

  final int episodeId;
  final int startMs;
  final int endMs;
  final double score;
}

/// Correspondances revues, puis propositions qui ne les recouvrent pas.
class AdContextFusion {
  const AdContextFusion({required this.matches, required this.proposed});

  final List<AdContextHit> matches;
  final List<AdContextHit> proposed;
}

/// Confirme, rejette ou allonge les correspondances, puis propose.
///
/// [enabled] faux rend les correspondances telles quelles. Les mesures
/// mn04 ne comptent que si [useMn04] ou [mn04ContextEnabled] est vrai.
AdContextFusion fuseAdContext({
  required List<AdContextHit> matches,
  required Map<int, AdContextEpisode> episodes,
  bool enabled = true,
  bool useMn04 = false,
  List<Mn04Cue> mn04 = const [],
  bool propose = true,
}) {
  if (!enabled) {
    return AdContextFusion(matches: matches, proposed: const []);
  }
  final allowMn04 = (useMn04 || mn04ContextEnabled) && mn04.isNotEmpty;
  final cache = <int, List<_Window>>{};
  List<_Window> windowsOf(int id) {
    return cache.putIfAbsent(id, () {
      final episode = episodes[id];
      if (episode == null) return const [];
      return _windows(
        episode,
        episodeId: id,
        mn04: allowMn04 ? mn04 : const [],
      );
    });
  }

  final kept = <AdContextHit>[];
  for (final hit in matches) {
    final episode = episodes[hit.episodeId];
    final envelope = episode?.envelope;
    if (episode == null || envelope == null || envelope.isEmpty) {
      kept.add(hit);
      continue;
    }
    if (_rejectsTone(episode, hit, mn04: allowMn04 ? mn04 : const [])) {
      continue;
    }
    final strong = [
      for (final window in windowsOf(hit.episodeId))
        if (window.score >= adContextProposeThreshold &&
            !window.tone &&
            _overlapShare(hit, window) >= 0.5)
          window,
    ];
    final inner = [
      for (final window in strong)
        if (window.startMs >= hit.startMs - 400 &&
            window.endMs <= hit.endMs + 400)
          window,
    ];
    if (inner.length >= 2) {
      for (final window in inner) {
        kept.add(window.hit(hit.episodeId));
      }
      continue;
    }
    _Window? longer;
    final hitLen = hit.endMs - hit.startMs;
    for (final window in strong) {
      final length = window.endMs - window.startMs;
      if (length <= hitLen || length > adContextMaxDurationMs) continue;
      final overlap = _overlapMs(
        hit.startMs,
        hit.endMs,
        window.startMs,
        window.endMs,
      );
      if (hitLen <= 0 || overlap * 2 < hitLen) continue;
      if (longer == null || length > longer.endMs - longer.startMs) {
        longer = window;
      }
    }
    if (longer != null) {
      kept.add(longer.hit(hit.episodeId));
    } else {
      kept.add(hit);
    }
  }
  if (!propose) {
    return AdContextFusion(matches: kept, proposed: const []);
  }
  final proposed = <AdContextHit>[];
  for (final id in episodes.keys) {
    for (final window in windowsOf(id)) {
      if (window.score < adContextProposeThreshold || window.tone) continue;
      final hit = window.hit(id);
      if (_hitsOverlap(hit, kept) || _hitsOverlap(hit, proposed)) continue;
      proposed.add(hit);
    }
  }
  return AdContextFusion(matches: kept, proposed: proposed);
}

class _Window {
  const _Window({
    required this.startMs,
    required this.endMs,
    required this.score,
    required this.tone,
  });

  final int startMs;
  final int endMs;
  final double score;
  final bool tone;

  AdContextHit hit(int episodeId) {
    return AdContextHit(
      episodeId: episodeId,
      startMs: startMs,
      endMs: endMs,
      score: score,
    );
  }
}

class _View {
  const _View({
    required this.silenceEdges,
    required this.jumpLu,
    required this.interiorLu,
    required this.compressLu,
    required this.speech,
    required this.labeled,
    required this.mnSpeech,
    required this.mnBackground,
    required this.mnJump,
  });

  final int silenceEdges;
  final double jumpLu;
  final double interiorLu;
  final double compressLu;
  final double? speech;
  final bool labeled;
  final double mnSpeech;
  final double mnBackground;
  final double mnJump;
}

List<_Window> _windows(
  AdContextEpisode episode, {
  required int episodeId,
  required List<Mn04Cue> mn04,
}) {
  final envelope = episode.envelope;
  if (envelope == null || envelope.isEmpty) return const [];
  final spans = _soundSpans(envelope);
  for (final chapter in episode.chapters) {
    if (skipKindForChapterTitle(chapter.title) == null) continue;
    final length = chapter.endMs - chapter.startMs;
    if (length < adMinDurationMs || length > adContextMaxDurationMs) continue;
    spans.add((chapter.startMs, chapter.endMs));
  }
  final scored = <_Window>[];
  for (final span in spans) {
    final length = span.$2 - span.$1;
    if (length < adMinDurationMs || length > adContextMaxDurationMs) continue;
    final view = _view(
      episode,
      span.$1,
      span.$2,
      episodeId: episodeId,
      mn04: mn04,
    );
    final tone = _tone(view, length);
    final score = _score(
      view,
      span.$1,
      episode.durationMs,
      allowMn04: mn04.isNotEmpty,
    );
    _keepBest(
      scored,
      _Window(startMs: span.$1, endMs: span.$2, score: score, tone: tone),
    );
  }
  return scored;
}

void _keepBest(List<_Window> scored, _Window window) {
  for (var i = 0; i < scored.length; i++) {
    final other = scored[i];
    final overlap = _overlapMs(
      other.startMs,
      other.endMs,
      window.startMs,
      window.endMs,
    );
    final shorter = math.min(
      other.endMs - other.startMs,
      window.endMs - window.startMs,
    );
    if (shorter <= 0 || overlap * 2 < shorter) continue;
    if (window.score > other.score) scored[i] = window;
    return;
  }
  scored.add(window);
}

_View _view(
  AdContextEpisode episode,
  int startMs,
  int endMs, {
  required int episodeId,
  required List<Mn04Cue> mn04,
}) {
  final envelope = episode.envelope!;
  final startQuiet = _quietBefore(envelope, startMs);
  final endQuiet = _quietAfter(envelope, endMs);
  final jump = _edgeJump(envelope, startMs, endMs);
  final interior = _rangeLu(envelope, startMs, endMs);
  final neighbour = _neighbourRange(envelope, startMs, endMs);
  var mnSpeech = 0.0;
  var mnBackground = 0.0;
  var mnJump = 0.0;
  for (final cue in mn04) {
    if (cue.episodeId != episodeId) continue;
    final overlap = _overlapMs(startMs, endMs, cue.startMs, cue.endMs);
    if (overlap <= 0) continue;
    if (cue.speech > mnSpeech) mnSpeech = cue.speech;
    if (cue.backgroundMusic > mnBackground) mnBackground = cue.backgroundMusic;
    if (cue.scoreJump > mnJump) mnJump = cue.scoreJump;
  }
  return _View(
    silenceEdges: (startQuiet ? 1 : 0) + (endQuiet ? 1 : 0),
    jumpLu: jump,
    interiorLu: interior,
    compressLu: neighbour - interior,
    speech: speechRatioIn(episode.speech, startMs, endMs),
    labeled: _labeled(episode.chapters, startMs, endMs),
    mnSpeech: mnSpeech,
    mnBackground: mnBackground,
    mnJump: mnJump,
  );
}

double _score(
  _View view,
  int startMs,
  int durationMs, {
  required bool allowMn04,
}) {
  final silence = view.silenceEdges >= 2
      ? 0.30
      : view.silenceEdges == 1
      ? 0.08
      : 0.0;
  final jump = _ramp(view.jumpLu, _jumpStartLu, _jumpFullLu) * 0.28;
  final compress = _ramp(view.compressLu, 2, 4) * 0.22;
  final speech = view.speech;
  final musicUnder =
      speech != null && speech >= _musicUnderLow && speech < _musicUnderHigh
      ? 0.12
      : 0.0;
  final atStart = startMs <= jingleSearchWindowMs;
  final atEnd =
      durationMs > 0 &&
      durationMs - startMs <= outroWindowMs &&
      durationMs - startMs > 0;
  final position = atStart || atEnd ? 0.04 : 0.0;
  final chapter = view.labeled ? 0.24 : 0.0;
  final acoustic = silence + jump + compress + musicUnder + position + chapter;
  if (!allowMn04 || acoustic < 0.55) return acoustic.clamp(0.0, 1.0);
  var extra = 0.0;
  if (view.mnSpeech >= 0.35 && view.mnBackground >= 0.25) extra += 0.08;
  if (view.mnJump >= 0.15) extra += 0.06;
  return (acoustic + extra).clamp(0.0, 1.0);
}

/// Ton répété : 12 à 18 s, presque pas de parole, niveau plat, sans saut.
bool _tone(_View view, int durationMs) {
  if (durationMs < _toneMinMs || durationMs > _toneMaxMs) return false;
  final speech = view.speech;
  if (speech == null || speech >= _toneSpeechMax) return false;
  if (view.interiorLu > _toneRangeMax) return false;
  if (view.jumpLu >= _toneJumpMax) return false;
  if (view.labeled) return false;
  if (view.mnSpeech >= 0.50) return false;
  return true;
}

bool _rejectsTone(
  AdContextEpisode episode,
  AdContextHit hit, {
  required List<Mn04Cue> mn04,
}) {
  final envelope = episode.envelope;
  if (envelope == null || envelope.isEmpty) return false;
  final view = _view(
    episode,
    hit.startMs,
    hit.endMs,
    episodeId: hit.episodeId,
    mn04: mn04,
  );
  return _tone(view, hit.endMs - hit.startMs);
}

List<(int, int)> _soundSpans(Uint8List envelope) {
  final need = math.max(1, _silenceRunMs ~/ envelopeHopMs);
  final spans = <(int, int)>[];
  var soundStart = -1;
  var quiet = 0;
  if (envelope.isNotEmpty && envelope[0] > envelopeSilenceLevel) {
    soundStart = 0;
  }
  for (var i = 0; i < envelope.length; i++) {
    if (envelope[i] <= envelopeSilenceLevel) {
      quiet++;
      if (quiet == need && soundStart >= 0) {
        _emitSpan(
          spans,
          envelope,
          soundStart * envelopeHopMs,
          (i - need + 1) * envelopeHopMs,
        );
        soundStart = -1;
      }
      continue;
    }
    if (soundStart < 0) soundStart = i;
    quiet = 0;
  }
  if (soundStart >= 0) {
    final tail = quiet >= need ? quiet : 0;
    final end = envelope.length - tail;
    if (end > soundStart) {
      _emitSpan(
        spans,
        envelope,
        soundStart * envelopeHopMs,
        end * envelopeHopMs,
      );
    }
  }
  return spans;
}

void _emitSpan(List<(int, int)> spans, Uint8List envelope, int start, int end) {
  final length = end - start;
  if (length >= adMinDurationMs && length <= adContextMaxDurationMs) {
    spans.add((start, end));
    return;
  }
  if (length <= adContextMaxDurationMs) return;
  var from = start;
  var lastCut = start;
  for (var t = start + adMinDurationMs; t <= end - adMinDurationMs; t += 500) {
    final before = _lufs(_meanPower(envelope, t - 1000, t));
    final after = _lufs(_meanPower(envelope, t, t + 1000));
    if ((after - before).abs() < _jumpFullLu) continue;
    if (t - lastCut < adMinDurationMs) continue;
    final piece = t - from;
    if (piece >= adMinDurationMs && piece <= adContextMaxDurationMs) {
      spans.add((from, t));
    }
    from = t;
    lastCut = t;
  }
  final tail = end - from;
  if (tail >= adMinDurationMs && tail <= adContextMaxDurationMs) {
    spans.add((from, end));
  }
}

bool _quietBefore(Uint8List envelope, int ms) {
  final end = ms ~/ envelopeHopMs;
  final start = end - (_silenceRunMs ~/ envelopeHopMs);
  if (start < 0 || end > envelope.length) return false;
  for (var i = start; i < end; i++) {
    if (envelope[i] > envelopeSilenceLevel) return false;
  }
  return end > start;
}

bool _quietAfter(Uint8List envelope, int ms) {
  final start = ms ~/ envelopeHopMs;
  final end = start + (_silenceRunMs ~/ envelopeHopMs);
  if (start < 0 || end > envelope.length) return false;
  for (var i = start; i < end; i++) {
    if (envelope[i] > envelopeSilenceLevel) return false;
  }
  return end > start;
}

double _edgeJump(Uint8List envelope, int startMs, int endMs) {
  var best = 0.0;
  final before = _outsideLufs(envelope, startMs, -1);
  if (before != null) {
    final inside = _lufs(_meanPower(envelope, startMs, startMs + 400));
    best = math.max(best, (inside - before).abs());
  }
  final after = _outsideLufs(envelope, endMs, 1);
  if (after != null) {
    final inside = _lufs(_meanPower(envelope, endMs - 400, endMs));
    best = math.max(best, (inside - after).abs());
  }
  return best;
}

double? _outsideLufs(Uint8List envelope, int boundaryMs, int direction) {
  var index = boundaryMs ~/ envelopeHopMs;
  if (direction < 0) index -= 1;
  final maxSkip = 600 ~/ envelopeHopMs;
  var skipped = 0;
  while (skipped < maxSkip) {
    if (index < 0 || index >= envelope.length) return null;
    if (envelope[index] > envelopeSilenceLevel) break;
    index += direction;
    skipped++;
  }
  final need = 400 ~/ envelopeHopMs;
  var sum = 0.0;
  var count = 0;
  var guard = 0;
  while (count < need && guard < need + maxSkip) {
    if (index < 0 || index >= envelope.length) break;
    if (envelope[index] > envelopeSilenceLevel) {
      final ratio = envelope[index] / 255.0;
      sum += ratio * ratio;
      count++;
    }
    index += direction;
    guard++;
  }
  if (count < need ~/ 2) return null;
  return _lufs(sum / count);
}

double _neighbourRange(Uint8List envelope, int startMs, int endMs) {
  final before = _sideRange(envelope, startMs, -1);
  final after = _sideRange(envelope, endMs, 1);
  return math.max(before, after);
}

double _sideRange(Uint8List envelope, int boundaryMs, int direction) {
  var index = boundaryMs ~/ envelopeHopMs;
  if (direction < 0) index -= 1;
  final maxSkip = 600 ~/ envelopeHopMs;
  var skipped = 0;
  while (skipped < maxSkip) {
    if (index < 0 || index >= envelope.length) return 0;
    if (envelope[index] > envelopeSilenceLevel) break;
    index += direction;
    skipped++;
  }
  final values = <double>[];
  var guard = 0;
  final hop = 400 ~/ envelopeHopMs;
  while (values.length < 5 && guard < 8) {
    var sum = 0.0;
    var count = 0;
    for (var k = 0; k < hop; k++) {
      if (index < 0 || index >= envelope.length) break;
      if (envelope[index] > envelopeSilenceLevel) {
        final ratio = envelope[index] / 255.0;
        sum += ratio * ratio;
        count++;
      }
      index += direction;
    }
    if (count == 0) break;
    values.add(_lufs(sum / count));
    guard++;
  }
  if (values.length < 3) return 0;
  values.sort();
  return values.last - values.first;
}

double _rangeLu(Uint8List envelope, int startMs, int endMs) {
  final values = <double>[];
  for (var t = startMs; t + 400 <= endMs; t += 400) {
    values.add(_lufs(_meanPower(envelope, t, t + 400)));
  }
  if (values.length < 3) return 0;
  values.sort();
  final low = values[(values.length * 0.1).floor()];
  final high =
      values[(values.length * 0.9).floor().clamp(0, values.length - 1)];
  return high - low;
}

double _meanPower(Uint8List envelope, int startMs, int endMs) {
  if (envelope.isEmpty || endMs <= startMs) return 0;
  final start = (startMs ~/ envelopeHopMs).clamp(0, envelope.length - 1);
  var end = (endMs ~/ envelopeHopMs).clamp(0, envelope.length);
  if (end <= start) end = math.min(envelope.length, start + 1);
  var sum = 0.0;
  for (var i = start; i < end; i++) {
    final ratio = envelope[i] / 255.0;
    sum += ratio * ratio;
  }
  return sum / (end - start);
}

double _lufs(double meanPower) {
  if (meanPower <= 1e-12) return -70;
  return -0.691 + 10 * math.log(meanPower) / math.ln10;
}

double _ramp(double value, double low, double high) {
  if (value <= low) return 0;
  if (value >= high) return 1;
  return (value - low) / (high - low);
}

bool _labeled(List<AdContextChapter> chapters, int startMs, int endMs) {
  final length = endMs - startMs;
  if (length <= 0) return false;
  for (final chapter in chapters) {
    if (skipKindForChapterTitle(chapter.title) == null) continue;
    final overlap = _overlapMs(startMs, endMs, chapter.startMs, chapter.endMs);
    if (overlap * 2 >= length) return true;
  }
  return false;
}

double _overlapShare(AdContextHit hit, _Window window) {
  final length = math.min(
    hit.endMs - hit.startMs,
    window.endMs - window.startMs,
  );
  if (length <= 0) return 0;
  return _overlapMs(hit.startMs, hit.endMs, window.startMs, window.endMs) /
      length;
}

bool _hitsOverlap(AdContextHit hit, List<AdContextHit> others) {
  final length = hit.endMs - hit.startMs;
  for (final other in others) {
    if (other.episodeId != hit.episodeId) continue;
    final overlap = _overlapMs(
      hit.startMs,
      hit.endMs,
      other.startMs,
      other.endMs,
    );
    final shorter = math.min(length, other.endMs - other.startMs);
    if (shorter > 0 && overlap * 2 >= shorter) return true;
  }
  return false;
}

int _overlapMs(int a0, int a1, int b0, int b1) {
  final start = math.max(a0, b0);
  final end = math.min(a1, b1);
  return end > start ? end - start : 0;
}
