import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:just_audio/just_audio.dart';

/// Session système (notification média, écran de verrouillage, centre de contrôle).
PlaybackHandler? playbackHandler;

class PlaybackHandler {
  PlaybackHandler(this._session);

  final FlutterMediaSession _session;
  AudioPlayer? _player;
  var _skipBack = const Duration(seconds: 10);
  var _skipForward = const Duration(seconds: 30);
  var _active = false;
  var _unsupported = false;
  MediaMetadata? _metadata;
  Future<void>? _starting;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Duration get skipBack => _skipBack;

  set skipBack(Duration value) {
    _skipBack = value;
    unawaited(_publishIntervals());
  }

  Duration get skipForward => _skipForward;

  set skipForward(Duration value) {
    _skipForward = value;
    unawaited(_publishIntervals());
  }

  Future<void> prepare() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        await _session.setWindowsAppUserModelId(
          'fr.podavio.podavio',
          displayName: 'Podavio',
        );
      } catch (error, stack) {
        debugPrint('Identifiant Windows indisponible: $error\n$stack');
      }
    }
    await _publishIntervals();
  }

  void attach(AudioPlayer player) {
    if (identical(_player, player)) return;
    detach();
    _player = player;
    _subscriptions.addAll([
      player.playerStateStream.listen((_) => _push(force: true)),
      player.positionStream.listen((_) => _push()),
      player.speedStream.listen((_) => _push(force: true)),
      player.durationStream.listen(_rememberDuration),
    ]);
  }

  void detach() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _player = null;
  }

  void activate() {
    _active = true;
    unawaited(_ensureStarted().then((_) => _push(force: true)));
  }

  void setEpisode({
    required String title,
    required String podcast,
    Uri? artUri,
    Duration? duration,
  }) {
    _active = true;
    _metadata = MediaMetadata(
      title: title,
      artist: podcast,
      album: podcast,
      artworkUri: artUri?.toString(),
      duration: duration != null && duration > Duration.zero ? duration : null,
    );
    unawaited(
      _ensureStarted().then((_) async {
        await _pushMetadata();
        _push(force: true);
      }),
    );
  }

  Future<void> _ensureStarted() {
    if (_unsupported) return Future<void>.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      await _session.activate();
      _session.setActionHandler(
        onPlay: () => unawaited(_player?.play()),
        onPause: () => unawaited(_player?.pause()),
        onStop: () => unawaited(_stop()),
        onSeekTo: (position) => unawaited(_player?.seek(position)),
        onSkipToNext: () => unawaited(_skip(_skipForward)),
        onSkipToPrevious: () => unawaited(_skip(-_skipBack)),
        onFastForward: () => unawaited(_skip(_skipForward)),
        onRewind: () => unawaited(_skip(-_skipBack)),
      );
      await FlutterMediaSessionPlatform.instance.updateAvailableActions(
        _actions,
      );
      await _publishIntervals();
      await _pushMetadata();
    } catch (error, stack) {
      if (error is MissingPluginException) _unsupported = true;
      _starting = null;
      debugPrint('Contrôles média indisponibles: $error\n$stack');
    }
  }

  Future<void> _stop() async {
    _active = false;
    _starting = null;
    await _player?.pause();
    try {
      await _session.deactivate();
    } catch (error, stack) {
      debugPrint('Arrêt des contrôles média impossible: $error\n$stack');
    }
  }

  Future<void> _skip(Duration offset) async {
    final player = _player;
    if (player == null) return;
    var target = player.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    final duration = player.duration;
    if (duration != null && duration > Duration.zero && target > duration) {
      target = duration;
    }
    await player.seek(target);
  }

  void _rememberDuration(Duration? duration) {
    final current = _metadata;
    if (current == null || duration == null || duration <= Duration.zero) {
      return;
    }
    if (current.duration == duration) return;
    _metadata = MediaMetadata(
      title: current.title,
      artist: current.artist,
      album: current.album,
      artworkUri: current.artworkUri,
      duration: duration,
    );
    unawaited(_pushMetadata());
  }

  Future<void> _publishIntervals() async {
    try {
      await _session.setSkipIntervals(
        backwardSeconds: _skipBack.inSeconds,
        forwardSeconds: _skipForward.inSeconds,
      );
    } catch (error, stack) {
      debugPrint('Intervalles de saut indisponibles: $error\n$stack');
    }
  }

  Future<void> _pushMetadata() async {
    final metadata = _metadata;
    if (metadata == null || _unsupported || _starting == null) return;
    try {
      await FlutterMediaSessionPlatform.instance.updateMetadata(metadata);
    } catch (error, stack) {
      debugPrint('Métadonnées média indisponibles: $error\n$stack');
    }
  }

  void _push({bool force = false}) {
    final player = _player;
    if (!_active || player == null || _unsupported || _starting == null) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastPush) < const Duration(seconds: 1)) {
      return;
    }
    _lastPush = now;
    final state = PlaybackState(
      status: _status(player),
      position: player.position,
      speed: player.speed,
      bufferedPosition: player.bufferedPosition,
    );
    unawaited(
      FlutterMediaSessionPlatform.instance
          .updatePlaybackState(state)
          .catchError((Object error, StackTrace stack) {
            debugPrint('État de lecture indisponible: $error\n$stack');
          }),
    );
  }

  Set<MediaAction> get _actions {
    final apple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    return {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.seekTo,
      MediaAction.stop,
      if (apple) ...[MediaAction.rewind, MediaAction.fastForward],
      if (!apple) ...[MediaAction.skipToPrevious, MediaAction.skipToNext],
    };
  }
}

PlaybackStatus _status(AudioPlayer player) {
  return switch (player.processingState) {
    ProcessingState.idle ||
    ProcessingState.loading ||
    ProcessingState.buffering => PlaybackStatus.buffering,
    ProcessingState.ready =>
      player.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
    ProcessingState.completed => PlaybackStatus.ended,
  };
}

Uri? artworkUri(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.isScheme('http') || uri.isScheme('https') || uri.isScheme('file')) {
    return uri;
  }
  return null;
}
