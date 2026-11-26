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
      return _ffmpeg(stored, sampleRate, limit);
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
    final process = await Process.start(binary, [
      '-y',
      '-v',
      'error',
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
    unawaited(process.stdout.drain());
    final stderr = process.stderr.transform(utf8.decoder).join();
    final timer = Timer(budget, () => process.kill(ProcessSignal.sigkill));
    final exitCode = await process.exitCode;
    timer.cancel();
    final message = (await stderr).trim();
    if (exitCode != 0 || !await out.exists()) {
      if (await out.exists()) await out.delete();
      debugPrint(
        'Décodage audio: ffmpeg a échoué${message.isEmpty ? '' : ' ($message)'}.',
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
