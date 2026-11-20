import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/download_service.dart';
import '../data/playback_file.dart';

/// Ouvre un fichier local, un cache de flux, ou le flux simple.
class StreamCache {
  StreamCache(this._downloads);

  final DownloadService _downloads;
  StreamSubscription<double>? _progress;

  /// Zone où just_audio démarre son proxy local de cache, au premier
  /// flux mis en cache. Le serveur garde cette zone : une coupure
  /// réseau en cours de réponse y arrive au lieu de faire planter l'app.
  Zone? _proxyZone;
  int? _proxyEpisodeId;

  Zone get _zone => _proxyZone ??= createCacheProxyZone(onAbort: _reportAbort);

  /// Un fichier local est réessayé via une copie au nom simple si le décodeur
  /// refuse le chemin d’origine. Jamais de repli réseau.
  Future<void> open(
    AudioPlayer player,
    Uri uri, {
    required Map<String, String>? headers,
    required int? episodeId,
    required bool Function() isUsable,
    required bool Function() isSameEpisode,
  }) async {
    final remote = uri.scheme == 'http' || uri.scheme == 'https';
    if (remote) {
      await _openRemote(
        player,
        uri,
        headers: headers,
        episodeId: episodeId,
        isUsable: isUsable,
        isSameEpisode: isSameEpisode,
      );
      return;
    }
    try {
      await player.setAudioSource(AudioSource.uri(uri, headers: headers));
    } catch (error, stack) {
      final path = uri.scheme == 'file' ? uri.toFilePath() : null;
      if (path == null || isPlaybackCacheFile(path)) {
        debugPrint('Lecture impossible: $error\n$stack');
        rethrow;
      }
      debugPrint('Lecture du fichier, nouvel essai: $error\n$stack');
      final copy = await _downloads.copyLocalFileForPlayback(path);
      if (!isUsable() || copy == null) rethrow;
      await player.setAudioSource(AudioSource.file(copy));
    }
  }

  /// Joue le flux et garde le fichier une fois qu’il est complet.
  /// Un échec du cache revient au streaming simple.
  Future<void> _openRemote(
    AudioPlayer player,
    Uri uri, {
    required Map<String, String>? headers,
    required int? episodeId,
    required bool Function() isUsable,
    required bool Function() isSameEpisode,
  }) async {
    await _progress?.cancel();
    _progress = null;
    if (episodeId == null) {
      await player.setAudioSource(AudioSource.uri(uri, headers: headers));
      return;
    }
    try {
      final file = await _downloads.streamCacheFileFor(
        episodeId,
        uri.toString(),
      );
      if (await file.exists() && await file.length() > 0) {
        await _downloads.rememberStreamCache(episodeId, file.path);
      }
      if (!isSameEpisode()) return;
      // Le cache de flux est encore marqué expérimental par just_audio.
      // ignore: experimental_member_use
      final source = LockCachingAudioSource(
        uri,
        headers: headers,
        cacheFile: file,
      );
      _progress = source.downloadProgressStream.listen((progress) {
        if (progress < 1) return;
        unawaited(_remember(episodeId, file, isSameEpisode));
      });
      _proxyEpisodeId = episodeId;
      await _setSourceInProxyZone(player, source);
    } catch (error, stack) {
      debugPrint('Cache de lecture indisponible: $error\n$stack');
      if (!isUsable()) return;
      await player.setAudioSource(AudioSource.uri(uri, headers: headers));
    }
  }

  /// Le futur de `setAudioSource` naît dans la zone gardée : son résultat
  /// est relayé par un [Completer] de la zone appelante, sinon une erreur
  /// n'atteindrait jamais le `catch` de repli.
  Future<void> _setSourceInProxyZone(AudioPlayer player, AudioSource source) {
    final completer = Completer<void>();
    _zone.run(() {
      player
          .setAudioSource(source)
          .then((_) => completer.complete(), onError: completer.completeError);
    });
    return completer.future;
  }

  void _reportAbort(HttpException error, StackTrace stack) {
    final episodeId = _proxyEpisodeId;
    debugPrint('Flux du cache interrompu: $error');
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'stream_cache',
        level: SentryLevel.warning,
        message: 'Cache proxy response aborted',
        data: {'uri': error.uri?.toString(), 'episodeId': episodeId},
      ),
    );
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.level = SentryLevel.warning;
          scope.setTag('stream_cache.proxy_abort', 'true');
          scope.setContexts('stream_cache', {
            'message': error.message,
            'uri': error.uri?.toString(),
            'episodeId': episodeId,
          });
        },
      ),
    );
  }

  Future<void> _remember(
    int episodeId,
    File file,
    bool Function() isSameEpisode,
  ) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!isSameEpisode()) return;
      if (await file.exists() && await file.length() > 0) {
        await _downloads.rememberStreamCache(episodeId, file.path);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> close() async {
    await _progress?.cancel();
    _progress = null;
  }
}

/// Erreur du proxy local de just_audio (URI `/id/<uuid>`), par exemple une
/// réponse coupée avant son `Content-Length` quand le réseau change.
@visibleForTesting
bool isCacheProxyAbort(Object error) =>
    error is HttpException && (error.uri?.path.startsWith('/id/') ?? false);

/// Zone durable qui capte les coupures du proxy de cache et transmet les
/// autres erreurs à la zone parente, donc au rapport de plantage habituel.
@visibleForTesting
Zone createCacheProxyZone({
  required void Function(HttpException error, StackTrace stack) onAbort,
}) {
  final parent = Zone.current;
  late final Zone zone;
  runZonedGuarded(() => zone = Zone.current, (error, stack) {
    if (error is HttpException && isCacheProxyAbort(error)) {
      onAbort(error, stack);
      return;
    }
    parent.handleUncaughtError(error, stack);
  });
  return zone;
}
