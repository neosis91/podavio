import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/ad_context.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/speech_music.dart';

/// Mesure unique. AD_CONTEXT_MATRIX=1 la lance ; le test CI sort tout de suite.
void main() {
  test('full synthetic matrix for fingerprint, context and mn04', () async {
    if (Platform.environment['AD_CONTEXT_MATRIX'] != '1') return;
    final root = Directory.systemTemp.createTempSync('podavio-ad-matrix');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final cases = <_Case>[];
    var nextId = 1;
    for (final ms in [15000, 20000, 25000, 30000, 60000]) {
      final seconds = ms ~/ 1000;
      cases.add(await _exact(root, 'exact-$seconds-pcm', ms, nextId));
      nextId += 10;
      cases.add(
        await _exact(root, 'exact-$seconds-mp3', ms, nextId, codec: 'mp3'),
      );
      nextId += 10;
      cases.add(
        await _exact(root, 'exact-$seconds-aac', ms, nextId, codec: 'aac'),
      );
      nextId += 10;
    }
    cases.add(await _speed(root, nextId));
    nextId += 10;
    cases.add(await _hour(root, nextId));
    nextId += 10;
    cases.add(await _read70(root, nextId));
    nextId += 10;
    cases.add(await _backToBack(root, nextId));
    nextId += 10;
    cases.add(await _quiet(root, nextId));
    nextId += 10;
    cases.add(await _single(root, nextId));
    nextId += 10;
    cases.add(await _tone(root, nextId));

    final manifest = [
      for (final item in cases)
        for (final episode in item.episodes)
          {
            'episodeId': episode.id,
            'path': episode.path,
            'sampleRate': chromaprintSampleRate,
          },
    ];
    final manifestFile = File('${root.path}/manifest.json');
    final cuesFile = File('${root.path}/cues.json');
    manifestFile.writeAsStringSync(jsonEncode(manifest));
    final mn = await _mn04(manifestFile, cuesFile);
    final a = _Tally();
    final b = _Tally();
    final c = _Tally();
    var matchA = 0;
    var matchB = 0;
    var matchC = 0;
    var finger = 0;
    var audioMs = 0;
    var peak = 0;
    for (final item in cases) {
      finger += item.analyzeUs;
      audioMs += item.audioMs;
      if (item.peak > peak) peak = item.peak;
      final watchA = Stopwatch()..start();
      final predA = _predict(item, context: false, cues: const []);
      watchA.stop();
      final watchB = Stopwatch()..start();
      final predB = _predict(item, context: true, cues: const []);
      watchB.stop();
      matchA += watchA.elapsedMicroseconds;
      matchB += watchB.elapsedMicroseconds;
      final countA = _score(predA, item.truth);
      final countB = _score(predB, item.truth);
      a.add(countA);
      b.add(countB);
      var statusC = 'non mesuré';
      if (mn.ok) {
        final mine = [
          for (final cue in mn.cues)
            if (item.episodes.any((episode) => episode.id == cue.episodeId))
              cue,
        ];
        final watchC = Stopwatch()..start();
        final predC = _predict(item, context: true, cues: mine, useMn04: true);
        watchC.stop();
        matchC += watchC.elapsedMicroseconds;
        final countC = _score(predC, item.truth);
        c.add(countC);
        statusC = countC.label;
      }
      _say('${item.name} A=${countA.label} B=${countB.label} C=$statusC');
    }
    final hours = audioMs / 3600000;
    _say('CPU ${_cpu()}');
    _say('AUDIO_MS $audioMs HOURS ${hours.toStringAsFixed(3)}');
    _say(_config('A', a, finger + matchA, hours, peak));
    _say(_config('B', b, finger + matchB, hours, peak));
    if (mn.ok) {
      final pythonMb = mn.peakKb <= 0 ? 0 : mn.peakKb / 1024;
      _say(
        '${_config('C', c, finger + matchC + mn.ms * 1000, hours, peak)} '
        'python_peak_mb=${pythonMb.toStringAsFixed(1)} '
        'provider=${mn.provider} mn04_ms=${mn.ms} embedding=${mn.embedding}',
      );
    } else {
      _say('CONFIG C non mesuré (${mn.reason})');
    }
    expect(cases, isNotEmpty);
    expect(audioMs, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 45)));
}

void _say(String message) {
  // ignore: avoid_print
  print(message);
}

String _cpu() {
  try {
    for (final line in File('/proc/cpuinfo').readAsLinesSync()) {
      if (line.startsWith('model name')) return line.split(':').last.trim();
    }
  } catch (_) {}
  return 'non mesuré';
}

String _config(String name, _Tally tally, int micros, double hours, int peak) {
  final rate = tally.tp + tally.fn == 0
      ? 'non mesuré'
      : (tally.tp / (tally.tp + tally.fn)).toStringAsFixed(3);
  final boundary = tally.boundN == 0
      ? 'non mesuré'
      : (tally.boundSum / tally.boundN).toStringAsFixed(1);
  final perHour = hours <= 0
      ? 'non mesuré'
      : (micros / 1e6 / hours).toStringAsFixed(2);
  final mb = peak <= 0
      ? 'non mesuré'
      : (peak / (1024 * 1024)).toStringAsFixed(1);
  return 'CONFIG $name tp=${tally.tp} fp=${tally.fp} fn=${tally.fn} '
      'rate=$rate boundary_ms=$boundary s_per_hour=$perHour peak_mb=$mb';
}

class _Tally {
  int tp = 0;
  int fp = 0;
  int fn = 0;
  double boundSum = 0;
  int boundN = 0;

  void add(_Count count) {
    tp += count.tp;
    fp += count.fp;
    fn += count.fn;
    boundSum += count.boundSum;
    boundN += count.boundN;
  }
}

class _Count {
  int tp = 0;
  int fp = 0;
  int fn = 0;
  double boundSum = 0;
  int boundN = 0;

  String get label {
    if (fp > 0) return 'faux-positif';
    if (tp == 0 && fn > 0) return 'manqué';
    if (fn > 0) return 'partiel';
    if (tp > 0) return 'détecté';
    return 'rien';
  }
}

class _Iv {
  const _Iv(this.episodeId, this.startMs, this.endMs);

  final int episodeId;
  final int startMs;
  final int endMs;
}

class _Ep {
  _Ep({
    required this.id,
    required this.path,
    required this.chroma,
    required this.envelope,
    required this.speech,
    required this.durationMs,
    required this.analyzeUs,
    required this.peak,
  });

  final int id;
  final String path;
  final List<int> chroma;
  final Uint8List envelope;
  final Uint8List speech;
  final int durationMs;
  final int analyzeUs;
  final int peak;
}

class _Case {
  _Case(this.name);

  final String name;
  final episodes = <_Ep>[];
  final truth = <_Iv>[];
  var audioMs = 0;
  var analyzeUs = 0;
  var peak = 0;
}

class _Mn {
  _Mn.missing(this.reason)
    : ok = false,
      cues = const [],
      ms = 0,
      peakKb = 0,
      provider = '',
      embedding = 'non mesuré';

  _Mn.ok(this.cues, this.ms, this.peakKb, this.provider, this.embedding)
    : ok = true,
      reason = '';

  final bool ok;
  final String reason;
  final List<Mn04Cue> cues;
  final int ms;
  final int peakKb;
  final String provider;
  final String embedding;
}

List<_Iv> _predict(
  _Case item, {
  required bool context,
  required List<Mn04Cue> cues,
  bool useMn04 = false,
}) {
  final plan = buildAnalysisPlan(
    episodes: [
      for (final episode in item.episodes)
        FingerprintEpisode(
          episodeId: episode.id,
          values: episode.chroma,
          hopMicros: chromaprintStoredHopMicros,
          durationMs: episode.durationMs,
          speech: episode.speech,
          envelope: episode.envelope,
        ),
    ],
    templates: const [],
    contextLayer: context,
    useMn04: useMn04,
    mn04: cues,
  );
  return _merge([
    for (final pattern in plan.patterns)
      for (final segment in pattern.segments)
        _Iv(segment.episodeId, segment.startMs, segment.endMs),
  ]);
}

List<_Iv> _merge(List<_Iv> hits) {
  final left = [...hits];
  final merged = <_Iv>[];
  while (left.isNotEmpty) {
    var current = left.removeAt(0);
    var grew = true;
    while (grew) {
      grew = false;
      for (var i = 0; i < left.length; i++) {
        final other = left[i];
        if (other.episodeId != current.episodeId) continue;
        final overlap = _overlap(
          current.startMs,
          current.endMs,
          other.startMs,
          other.endMs,
        );
        final shorter = math.min(
          current.endMs - current.startMs,
          other.endMs - other.startMs,
        );
        if (shorter <= 0 || overlap * 2 < shorter) continue;
        current = _Iv(
          current.episodeId,
          math.min(current.startMs, other.startMs),
          math.max(current.endMs, other.endMs),
        );
        left.removeAt(i);
        grew = true;
        break;
      }
    }
    merged.add(current);
  }
  return merged;
}

_Count _score(List<_Iv> predictions, List<_Iv> truth) {
  final count = _Count();
  final used = <int>{};
  for (final prediction in predictions) {
    var best = -1;
    var bestOverlap = 0;
    for (var i = 0; i < truth.length; i++) {
      if (used.contains(i) || truth[i].episodeId != prediction.episodeId) {
        continue;
      }
      final overlap = _overlap(
        prediction.startMs,
        prediction.endMs,
        truth[i].startMs,
        truth[i].endMs,
      );
      final shorter = math.min(
        prediction.endMs - prediction.startMs,
        truth[i].endMs - truth[i].startMs,
      );
      if (shorter <= 0 || overlap < shorter / 2 || overlap <= bestOverlap) {
        continue;
      }
      best = i;
      bestOverlap = overlap;
    }
    if (best < 0) {
      count.fp++;
      continue;
    }
    used.add(best);
    count.tp++;
    count.boundSum += (prediction.startMs - truth[best].startMs).abs();
    count.boundSum += (prediction.endMs - truth[best].endMs).abs();
    count.boundN += 2;
  }
  count.fn += truth.length - used.length;
  return count;
}

int _overlap(int a0, int a1, int b0, int b1) {
  final start = math.max(a0, b0);
  final end = math.min(a1, b1);
  return end > start ? end - start : 0;
}

Future<_Case> _exact(
  Directory root,
  String name,
  int adMs,
  int id, {
  String? codec,
}) async {
  final item = _Case(name);
  await _storePair(item, root, id, _bed(adMs, seed: 11), codec: codec);
  return item;
}

Future<_Case> _speed(Directory root, int id) async {
  final ad = _bed(20000, seed: 12);
  final fast = _faster(ad, 1.02);
  final item = _Case('speed-1.02');
  await _store(item, root, id, _mix(ad, leadMs: 6000), ad, 6350);
  await _store(item, root, id + 1, _mix(fast, leadMs: 14000), fast, 14350);
  return item;
}

Future<_Case> _read70(Directory root, int id) async {
  final item = _Case('read-70s');
  await _storePair(
    item,
    root,
    id,
    _bed(70000, seed: 13),
    leadA: 6000,
    leadB: 16000,
  );
  return item;
}

Future<_Case> _backToBack(Directory root, int id) async {
  final first = _bed(18000, seed: 21);
  final second = _bed(18000, seed: 22);
  final gap = _samples(250);
  final joined = Int16List(first.length + gap + second.length);
  joined.setRange(0, first.length, first);
  joined.setRange(first.length + gap, joined.length, second);
  final item = _Case('back-to-back');
  await _store(
    item,
    root,
    id,
    _mix(joined, leadMs: 6000),
    null,
    0,
    truth: false,
  );
  await _store(
    item,
    root,
    id + 1,
    _mix(joined, leadMs: 15000),
    null,
    0,
    truth: false,
  );
  final firstMs = first.length * 1000 ~/ chromaprintSampleRate;
  final secondMs = second.length * 1000 ~/ chromaprintSampleRate;
  for (final start in [6350, 15350]) {
    final episode = start == 6350 ? id : id + 1;
    item.truth.add(_Iv(episode, start, start + firstMs));
    final next = start + firstMs + 250;
    item.truth.add(_Iv(episode, next, next + secondMs));
  }
  return item;
}

Future<_Case> _quiet(Directory root, int id) async {
  final item = _Case('minus-6db');
  await _storePair(item, root, id, _gain(_bed(20000, seed: 14), 0.501));
  return item;
}

Future<_Case> _single(Directory root, int id) async {
  final item = _Case('single-episode');
  final ad = _bed(20000, seed: 15);
  await _store(item, root, id, _mix(ad, leadMs: 8000), ad, 8350);
  await _store(
    item,
    root,
    id + 1,
    _programme(20000, seed: 4),
    null,
    0,
    truth: false,
  );
  return item;
}

Future<_Case> _tone(Directory root, int id) async {
  final item = _Case('tone-15s');
  final tone = _sine(_samples(15000), 440, 7000);
  await _store(
    item,
    root,
    id,
    _splice(tone, leadMs: 8000),
    null,
    0,
    truth: false,
  );
  await _store(
    item,
    root,
    id + 1,
    _splice(tone, leadMs: 18000),
    null,
    0,
    truth: false,
  );
  return item;
}

Future<_Case> _hour(Directory root, int id) async {
  final item = _Case('hour-noise');
  final ad = _bed(20000, seed: 16);
  await _storeHour(item, root, id, ad, adAtMs: 10 * 60 * 1000, seed: 101);
  await _storeHour(item, root, id + 1, ad, adAtMs: 25 * 60 * 1000, seed: 202);
  return item;
}

Future<void> _storePair(
  _Case item,
  Directory root,
  int id,
  Int16List ad, {
  String? codec,
  int leadA = 6000,
  int leadB = 14000,
}) async {
  await _store(
    item,
    root,
    id,
    _mix(ad, leadMs: leadA),
    ad,
    leadA + 350,
    codec: codec,
  );
  await _store(
    item,
    root,
    id + 1,
    _mix(ad, leadMs: leadB),
    ad,
    leadB + 350,
    codec: codec,
  );
}

Future<void> _store(
  _Case item,
  Directory root,
  int id,
  Int16List samples,
  Int16List? ad,
  int truthStart, {
  String? codec,
  bool truth = true,
}) async {
  final raw = File('${root.path}/$id.pcm');
  _writeSamples(raw, samples);
  var path = raw.path;
  var start = truthStart;
  if (codec != null) {
    path = await _transcode(root, raw, codec);
    final built = _analyze(path, id);
    if (ad != null) {
      final located = _locate(built.envelope, _envelopeOf(ad));
      if (located >= 0 && (located - truthStart).abs() < 5000) start = located;
    }
    _keep(item, built);
  } else {
    _keep(item, _analyze(path, id));
  }
  if (truth && ad != null) {
    final length = ad.length * 1000 ~/ chromaprintSampleRate;
    item.truth.add(_Iv(id, start, start + length));
  }
}

void _keep(_Case item, _Ep episode) {
  item.episodes.add(episode);
  item.analyzeUs += episode.analyzeUs;
  item.audioMs += episode.durationMs;
  if (episode.peak > item.peak) item.peak = episode.peak;
}

Future<void> _storeHour(
  _Case item,
  Directory root,
  int id,
  Int16List ad, {
  required int adAtMs,
  required int seed,
}) async {
  final path = '${root.path}/$id.pcm';
  final watch = Stopwatch();
  var peak = ProcessInfo.currentRss;
  void note() {
    final rss = ProcessInfo.currentRss;
    if (rss > peak) peak = rss;
  }

  final file = File(path).openSync(mode: FileMode.write);
  final chroma = ChromaprintHasher();
  final speech = SpeechTimelineBuilder();
  final envelope = EnergyEnvelopeBuilder();
  final rate = chromaprintSampleRate;
  final total = rate * 3600;
  final adAt = adAtMs * rate ~/ 1000;
  final gap = _samples(300);
  var state = seed;
  var written = 0;
  final chunk = Int16List(rate);
  try {
    while (written < total) {
      final count = math.min(rate, total - written);
      for (var i = 0; i < count; i++) {
        final at = written + i;
        if (at >= adAt && at < adAt + ad.length) {
          chunk[i] = ad[at - adAt];
        } else if (at >= adAt - gap && at < adAt) {
          chunk[i] = 0;
        } else if (at >= adAt + ad.length && at < adAt + ad.length + gap) {
          chunk[i] = 0;
        } else {
          state = (1664525 * state + 1013904223) & 0x7fffffff;
          chunk[i] = ((state / 0x3fffffff - 1) * 2500).round();
        }
      }
      final slice = count == chunk.length
          ? chunk
          : Int16List.sublistView(chunk, 0, count);
      _writeRaw(file, slice);
      watch.start();
      chroma.add(slice);
      speech.add(slice);
      envelope.add(slice);
      note();
      watch.stop();
      written += count;
    }
  } finally {
    file.closeSync();
  }
  _keep(
    item,
    _Ep(
      id: id,
      path: path,
      chroma: chroma.finish(),
      envelope: envelope.finish(),
      speech: speech.finish(),
      durationMs: total * 1000 ~/ rate,
      analyzeUs: watch.elapsedMicroseconds,
      peak: peak,
    ),
  );
  item.truth.add(_Iv(id, adAtMs, adAtMs + ad.length * 1000 ~/ rate));
}

_Ep _analyze(String path, int id) {
  final watch = Stopwatch()..start();
  var peak = ProcessInfo.currentRss;
  void note() {
    final rss = ProcessInfo.currentRss;
    if (rss > peak) peak = rss;
  }

  final chroma = ChromaprintHasher();
  final speech = SpeechTimelineBuilder();
  final envelope = EnergyEnvelopeBuilder();
  final file = File(path).openSync();
  final raw = Uint8List(8192 * 2);
  final piece = Int16List(8192);
  var samples = 0;
  try {
    while (true) {
      final read = file.readIntoSync(raw);
      if (read < 2) break;
      final count = read ~/ 2;
      final view = ByteData.sublistView(raw, 0, count * 2);
      for (var i = 0; i < count; i++) {
        piece[i] = view.getInt16(i * 2, Endian.little);
      }
      final slice = count == piece.length
          ? piece
          : Int16List.sublistView(piece, 0, count);
      chroma.add(slice);
      speech.add(slice);
      envelope.add(slice);
      samples += count;
      note();
    }
  } finally {
    file.closeSync();
  }
  note();
  watch.stop();
  return _Ep(
    id: id,
    path: path,
    chroma: chroma.finish(),
    envelope: envelope.finish(),
    speech: speech.finish(),
    durationMs: samples * 1000 ~/ chromaprintSampleRate,
    analyzeUs: watch.elapsedMicroseconds,
    peak: peak,
  );
}

Future<String> _transcode(Directory root, File pcm, String codec) async {
  final encoded = File(
    '${root.path}/${pcm.uri.pathSegments.last}.${codec == 'mp3' ? 'mp3' : 'm4a'}',
  );
  final decoded = File('${encoded.path}.pcm');
  final encode = await Process.run('ffmpeg', [
    '-y',
    '-f',
    's16le',
    '-ar',
    '$chromaprintSampleRate',
    '-ac',
    '1',
    '-i',
    pcm.path,
    '-c:a',
    codec == 'mp3' ? 'libmp3lame' : 'aac',
    '-b:a',
    '64k',
    encoded.path,
  ]);
  if (encode.exitCode != 0) {
    throw Exception('ffmpeg $codec: ${encode.stderr}');
  }
  final decode = await Process.run('ffmpeg', [
    '-y',
    '-i',
    encoded.path,
    '-f',
    's16le',
    '-ar',
    '$chromaprintSampleRate',
    '-ac',
    '1',
    decoded.path,
  ]);
  if (decode.exitCode != 0) {
    throw Exception('ffmpeg decode: ${decode.stderr}');
  }
  return decoded.path;
}

Future<_Mn> _mn04(File manifest, File cues) async {
  final script = File('tool/efficientat_mn04.py');
  if (!script.existsSync()) return _Mn.missing('script absent');
  final result = await Process.run('python3', [
    script.path,
    manifest.path,
    cues.path,
  ]);
  if (result.exitCode != 0) {
    final text = '${result.stderr}'.trim();
    return _Mn.missing(text.isEmpty ? 'code ${result.exitCode}' : text);
  }
  final parsed = jsonDecode(cues.readAsStringSync());
  if (parsed is! List) return _Mn.missing('json illisible');
  final list = <Mn04Cue>[];
  for (final item in parsed) {
    if (item is! Map) continue;
    list.add(
      Mn04Cue(
        episodeId: item['episodeId'] as int,
        startMs: item['startMs'] as int,
        endMs: item['endMs'] as int,
        speech: (item['speech'] as num).toDouble(),
        music: (item['music'] as num).toDouble(),
        jingle: (item['jingle'] as num).toDouble(),
        backgroundMusic: (item['backgroundMusic'] as num).toDouble(),
        scoreJump: (item['scoreJump'] as num).toDouble(),
      ),
    );
  }
  final err = '${result.stderr}';
  final provider = _field(err, 'provider');
  final ms = int.tryParse(_field(err, 'ms')) ?? 0;
  final peak = int.tryParse(_field(err, 'peak_kb')) ?? 0;
  final embedding = _field(err, 'embedding');
  return _Mn.ok(
    list,
    ms,
    peak,
    provider.isEmpty ? 'non mesuré' : provider,
    embedding.isEmpty ? 'non mesuré' : embedding,
  );
}

String _field(String text, String key) {
  final match = RegExp('$key=(\\S+)').firstMatch(text);
  return match == null ? '' : match.group(1)!;
}

int _samples(int ms) => ms * chromaprintSampleRate ~/ 1000;

Int16List _mix(Int16List ad, {required int leadMs}) {
  final lead = _programme(leadMs, seed: leadMs);
  final tail = _programme(6000, seed: leadMs + 9);
  final gap = _samples(350);
  final out = Int16List(lead.length + gap + ad.length + gap + tail.length);
  var at = 0;
  out.setRange(at, at + lead.length, lead);
  at += lead.length + gap;
  out.setRange(at, at + ad.length, ad);
  at += ad.length + gap;
  out.setRange(at, at + tail.length, tail);
  return out;
}

Int16List _splice(Int16List insert, {required int leadMs}) {
  final lead = _programme(leadMs, seed: 30 + leadMs);
  final tail = _programme(6000, seed: 40 + leadMs);
  final out = Int16List(lead.length + insert.length + tail.length);
  out.setRange(0, lead.length, lead);
  out.setRange(lead.length, lead.length + insert.length, insert);
  out.setRange(lead.length + insert.length, out.length, tail);
  return out;
}

Int16List _programme(int ms, {required int seed}) {
  final raw = _voiced(ms, seed: seed);
  final out = Int16List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    final wobble =
        0.45 + 0.55 * math.sin(2 * math.pi * i / (chromaprintSampleRate * 1.7));
    out[i] = (raw[i] * wobble).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _bed(int ms, {required int seed}) {
  final voice = _voiced(ms, seed: seed);
  final bed = _chord(ms);
  final out = Int16List(voice.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = (voice[i] * 0.85 + bed[i] * 0.18).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _gain(Int16List input, double gain) {
  final out = Int16List(input.length);
  for (var i = 0; i < input.length; i++) {
    out[i] = (input[i] * gain).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _faster(Int16List input, double speed) {
  final count = (input.length / speed).floor();
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final position = i * speed;
    final index = position.floor();
    final frac = position - index;
    final left = input[index];
    final right = index + 1 < input.length ? input[index + 1] : left;
    out[i] = (left + (right - left) * frac).round();
  }
  return out;
}

Int16List _sine(int count, double hz, double amplitude) {
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final t = i / chromaprintSampleRate;
    out[i] = (amplitude * math.sin(2 * math.pi * hz * t)).round();
  }
  return out;
}

Int16List _voiced(int ms, {required int seed}) {
  final rate = chromaprintSampleRate;
  final count = _samples(ms);
  final out = Int16List(count);
  var state = seed;
  double next() {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state / 0x3fffffff - 1;
  }

  final period = rate ~/ 4;
  final vowel = (rate * 0.09).round();
  final consonant = (rate * 0.035).round();
  final pitches = <double>[];
  for (var i = 0; i < count ~/ period + 1; i++) {
    pitches.add(100 + (next() + 1) * 40);
  }
  for (var i = 0; i < count; i++) {
    final phase = i % period;
    if (phase >= vowel + consonant) {
      out[i] = (next() * 250).round();
      continue;
    }
    final t = i / rate;
    if (phase < consonant) {
      out[i] = (next() * 11000).round();
      continue;
    }
    final pitch = pitches[i ~/ period];
    final sample =
        0.62 * math.sin(2 * math.pi * pitch * t) +
        0.22 * math.sin(2 * math.pi * pitch * 2 * t) +
        0.08 * next();
    out[i] = (sample * 12000).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _chord(int ms) {
  final count = _samples(ms);
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final t = i / chromaprintSampleRate;
    final sample =
        0.42 * math.sin(2 * math.pi * 220 * t) +
        0.26 * math.sin(2 * math.pi * 277.18 * t) +
        0.18 * math.sin(2 * math.pi * 329.63 * t);
    out[i] = (sample * 16000).round();
  }
  return out;
}

Uint8List _envelopeOf(Int16List samples) {
  final builder = EnergyEnvelopeBuilder();
  const step = 4096;
  var offset = 0;
  while (offset < samples.length) {
    final end = math.min(samples.length, offset + step);
    builder.add(Int16List.sublistView(samples, offset, end));
    offset = end;
  }
  return builder.finish();
}

int _locate(Uint8List haystack, Uint8List needle) {
  if (needle.length < 8 || haystack.length < needle.length) return -1;
  var bestAt = 0;
  var best = 1 << 62;
  for (var i = 0; i + needle.length <= haystack.length; i += 2) {
    var sad = 0;
    for (var j = 0; j < needle.length; j += 2) {
      sad += (haystack[i + j] - needle[j]).abs();
    }
    if (sad < best) {
      best = sad;
      bestAt = i;
    }
  }
  return bestAt * envelopeHopMs;
}

void _writeSamples(File file, Int16List samples) {
  final out = file.openSync(mode: FileMode.write);
  try {
    const step = 8192;
    var offset = 0;
    while (offset < samples.length) {
      final end = math.min(samples.length, offset + step);
      _writeRaw(out, Int16List.sublistView(samples, offset, end));
      offset = end;
    }
  } finally {
    out.closeSync();
  }
}

void _writeRaw(RandomAccessFile file, Int16List samples) {
  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  file.writeFromSync(bytes);
}
