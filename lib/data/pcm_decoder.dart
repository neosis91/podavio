import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'chromaprint.dart';

/// PCM mono 16 bits little-endian, écrit dans un fichier temporaire.
///
/// L’appelant efface [path] après l’empreinte. Le nom contient
/// `podavio-pcm-` pour ne jamais supprimer le téléchargement d’origine.
class DecodedPcm {
  const DecodedPcm({
    required this.path,
    required this.sampleRate,
    required this.samples,
    required this.durationMs,
  });

  final String path;
  final int sampleRate;
  final int samples;
  final int durationMs;
}

/// Décode un épisode téléchargé, y compris une URI `content:`.
abstract class PcmDecoder {
  const PcmDecoder();

  Future<DecodedPcm?> decode(
    String path, {
    int sampleRate = chromaprintSampleRate,
    Duration? budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  });
}

const _channel = MethodChannel('fr.podavio.podavio/audio_decode');
const _progressEvents = EventChannel(
  'fr.podavio.podavio/audio_decode/progress',
);

void Function(int samples, int expected, int sampleRate)? _decodeProgress;
StreamSubscription<dynamic>? _decodeProgressSub;

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return null;
}

void _listenDecodeProgress() {
  if (!Platform.isAndroid) return;
  _decodeProgressSub ??= _progressEvents.receiveBroadcastStream().listen((
    event,
  ) {
    final notify = _decodeProgress;
    if (notify == null || event is! Map) return;
    final samples = _asInt(event['samples']);
    final rate = _asInt(event['sampleRate']);
    if (samples == null || rate == null || samples <= 0 || rate <= 0) return;
    notify(samples, _asInt(event['expected']) ?? 0, rate);
  }, onError: (_) {});
}

/// Android (MediaCodec), iOS et macOS (AVFoundation). Ailleurs, ffmpeg
/// s’il est installé, sinon un refus journalisé.
class PlatformPcmDecoder extends PcmDecoder {
  const PlatformPcmDecoder();

  @override
  Future<DecodedPcm?> decode(
    String path, {
    int sampleRate = chromaprintSampleRate,
    Duration? budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  }) async {
    final stored = path.trim();
    if (stored.isEmpty) return null;
    if (stored.startsWith('content:') && !Platform.isAndroid) {
      debugPrint('Décodage audio: URI content non prise en charge ici.');
      return null;
    }
    final limit = budget ?? const Duration(minutes: 6);
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return _invoke(stored, sampleRate, limit, onProgress);
    }
    if (Platform.isLinux || Platform.isWindows) {
      return _ffmpeg(stored, sampleRate, limit, onProgress);
    }
    debugPrint('Décodage audio non pris en charge sur cette plateforme.');
    return null;
  }

  Future<DecodedPcm?> _invoke(
    String path,
    int sampleRate,
    Duration budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  ) async {
    _listenDecodeProgress();
    _decodeProgress = onProgress;
    try {
      final raw = await _channel
          .invokeMethod<Object?>('decodeToPcm', {
            'path': path,
            'sampleRate': sampleRate,
            'deadlineMs': budget.inMilliseconds,
          })
          .timeout(budget + const Duration(seconds: 5));
      return _fromMap(raw);
    } on MissingPluginException {
      debugPrint('Décodage audio: canal natif absent.');
    } on PlatformException catch (error) {
      debugPrint('Décodage audio: ${error.message}');
    } on TimeoutException {
      debugPrint('Décodage audio: délai dépassé.');
    } finally {
      if (_decodeProgress == onProgress) _decodeProgress = null;
    }
    return null;
  }

  Future<DecodedPcm?> _ffmpeg(
    String path,
    int sampleRate,
    Duration budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  ) async {
    if (path.startsWith('content:')) return null;
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('Décodage audio: fichier introuvable.');
      return null;
    }
    final binary = await _executable(Platform.isWindows ? 'where' : 'which', [
      'ffmpeg',
    ]);
    if (binary == null) {
      debugPrint(
        'Décodage audio: ffmpeg est absent, empreinte ignorée sur cette plateforme.',
      );
      return null;
    }
    final out = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}podavio-pcm-${DateTime.now().microsecondsSinceEpoch}.pcm',
    );
    // Le PCM va dans le fichier. La progression passe par la sortie
    // standard (`-progress pipe:1`), l’en-tête (durée) par l’erreur
    // standard. Rien de tout ça ne passe dans le flux PCM.
    final process = await Process.start(binary, [
      '-y',
      '-nostdin',
      '-hide_banner',
      '-nostats',
      '-v',
      'info',
      '-progress',
      'pipe:1',
      '-i',
      path,
      '-ac',
      '1',
      '-ar',
      '$sampleRate',
      '-f',
      's16le',
      '-acodec',
      'pcm_s16le',
      out.path,
    ]);
    final reader = FfmpegProgressReader();
    final stderrText = StringBuffer();
    int? durationUs;
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
    final malformed = const Utf8Decoder(allowMalformed: true);

    void report(int outTimeUs) {
      if (onProgress == null || outTimeUs <= 0) return;
      final samples = outTimeUs * sampleRate ~/ 1000000;
      if (samples <= 0) return;
      final now = DateTime.now();
      if (now.difference(lastReport) < ffmpegProgressGap) return;
      lastReport = now;
      final known = durationUs;
      final expected = known == null || known <= 0
          ? 0
          : known * sampleRate ~/ 1000000;
      try {
        onProgress(samples, expected, sampleRate);
      } catch (error, stack) {
        debugPrint('Décodage audio: $error\n$stack');
      }
    }

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    void finish(Completer<void> done) {
      if (!done.isCompleted) done.complete();
    }

    final stdoutRaw = process.stdout
        .transform(malformed)
        .listen(
          (chunk) {
            for (final us in reader.add(chunk)) {
              report(us);
            }
          },
          onError: (Object error) {
            debugPrint('Décodage audio: $error');
            finish(stdoutDone);
          },
          onDone: () {
            for (final us in reader.flush()) {
              report(us);
            }
            finish(stdoutDone);
          },
          cancelOnError: false,
        );
    final stderrRaw = process.stderr
        .transform(malformed)
        .listen(
          (chunk) {
            stderrText.write(chunk);
            durationUs ??= ffmpegHeaderDurationUs(stderrText.toString());
          },
          onError: (Object error) {
            debugPrint('Décodage audio: $error');
            finish(stderrDone);
          },
          onDone: () => finish(stderrDone),
          cancelOnError: false,
        );
    final timer = Timer(budget, () => process.kill(ProcessSignal.sigkill));
    late final int exitCode;
    try {
      exitCode = await process.exitCode;
      timer.cancel();
      await stdoutDone.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      await stderrDone.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      timer.cancel();
      await stdoutRaw.cancel();
      await stderrRaw.cancel();
    }
    for (final us in reader.flush()) {
      report(us);
    }
    final message = stderrText.toString().trim();
    if (exitCode != 0 || !await out.exists()) {
      if (await out.exists()) await out.delete();
      final shown = message.length > 500
          ? message.substring(message.length - 500)
          : message;
      debugPrint(
        'Décodage audio: ffmpeg a échoué${shown.isEmpty ? '' : ' ($shown)'}.',
      );
      return null;
    }
    final bytes = await out.length();
    final samples = bytes ~/ 2;
    if (samples <= 0) {
      await out.delete();
      return null;
    }
    return DecodedPcm(
      path: out.path,
      sampleRate: sampleRate,
      samples: samples,
      durationMs: samples * 1000 ~/ sampleRate,
    );
  }
}

DecodedPcm? _fromMap(Object? raw) {
  if (raw is! Map) return null;
  final path = raw['path'];
  final rate = raw['sampleRate'];
  final samples = raw['samples'];
  final duration = raw['durationMs'];
  if (path is! String || path.isEmpty) return null;
  if (rate is! num || samples is! num || duration is! num) return null;
  if (samples <= 0) return null;
  return DecodedPcm(
    path: path,
    sampleRate: rate.toInt(),
    samples: samples.toInt(),
    durationMs: duration.toInt(),
  );
}

/// Même écart que le décodage Android, pour ne pas réveiller l’interface
/// à chaque ligne de ffmpeg.
const ffmpegProgressGap = Duration(milliseconds: 400);

/// Temps de sortie, en microsecondes, lu dans un bloc `-progress`.
///
/// `out_time_us` est en microsecondes. `out_time_ms` l’est aussi :
/// le nom est trompeur, y compris quand `out_time_us` est présent.
/// On préfère `out_time_us`, puis l’horloge `out_time`, puis `out_time_ms`.
class FfmpegProgressReader {
  String _rest = '';
  int? _us;
  int? _ms;
  int? _clock;

  /// Consomme [chunk], éventuellement coupé au milieu d’une ligne,
  /// avec des fins `\n` ou `\r\n`. Un temps par bloc `progress=`.
  List<int> add(String chunk) {
    if (chunk.isEmpty) return const [];
    final text = _rest + chunk;
    final lines = text.split('\n');
    _rest = lines.removeLast();
    return _times(lines);
  }

  /// Traite la dernière ligne si ffmpeg l’a écrite sans saut de ligne.
  List<int> flush() {
    if (_rest.isEmpty) return const [];
    final pending = _rest;
    _rest = '';
    return _times([pending]);
  }

  List<int> _times(List<String> lines) {
    final times = <int>[];
    for (final raw in lines) {
      final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      final time = _take(line);
      if (time != null) times.add(time);
    }
    return times;
  }

  int? _take(String line) {
    if (line.isEmpty) return null;
    final split = line.indexOf('=');
    if (split <= 0) return null;
    final key = line.substring(0, split);
    final value = line.substring(split + 1).trim();
    switch (key) {
      case 'out_time_us':
        _us = int.tryParse(value);
      case 'out_time_ms':
        _ms = int.tryParse(value);
      case 'out_time':
        _clock = ffmpegClockUs(value);
      case 'progress':
        final time = _resolved();
        _us = null;
        _ms = null;
        _clock = null;
        return time;
    }
    return null;
  }

  int? _resolved() {
    final us = _us;
    if (us != null && us >= 0) return us;
    final clock = _clock;
    if (clock != null && clock >= 0) return clock;
    final ms = _ms;
    if (ms == null || ms < 0) return null;
    return ms;
  }
}

/// `HH:MM:SS` ou `HH:MM:SS.fraction`, en microsecondes. `N/A` donne null.
int? ffmpegClockUs(String value) {
  final match = RegExp(r'^(\d+):(\d+):(\d+)(?:\.(\d+))?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  final seconds = int.parse(match.group(3)!);
  var micros = ((hours * 60 + minutes) * 60 + seconds) * 1000000;
  final fraction = match.group(4);
  if (fraction != null && fraction.isNotEmpty) {
    final digits = fraction.length >= 6
        ? fraction.substring(0, 6)
        : fraction.padRight(6, '0');
    micros += int.parse(digits);
  }
  return micros;
}

final _headerDuration = RegExp(
  r'Duration:\s*(?:N/A|(\d+):(\d+):(\d+(?:\.\d+)?))',
);

/// Durée de l’en-tête ffmpeg, en microsecondes. `Duration: N/A` ou
/// un texte sans durée donne null.
int? ffmpegHeaderDurationUs(String text) {
  final match = _headerDuration.firstMatch(text);
  if (match == null || match.group(1) == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  final seconds = match.group(3)!;
  final dot = seconds.indexOf('.');
  final whole = int.parse(dot < 0 ? seconds : seconds.substring(0, dot));
  var micros = ((hours * 60 + minutes) * 60 + whole) * 1000000;
  if (dot >= 0) {
    final fraction = seconds.substring(dot + 1);
    if (fraction.isNotEmpty) {
      final digits = fraction.length >= 6
          ? fraction.substring(0, 6)
          : fraction.padRight(6, '0');
      micros += int.parse(digits);
    }
  }
  return micros;
}

Future<String?> _executable(String command, List<String> args) async {
  try {
    final result = await Process.run(command, args);
    if (result.exitCode != 0) return null;
    final path = '${result.stdout}'.trim().split(RegExp(r'\r?\n')).first.trim();
    if (path.isEmpty) return null;
    return path;
  } catch (error) {
    debugPrint('Décodage audio: $error');
    return null;
  }
}
