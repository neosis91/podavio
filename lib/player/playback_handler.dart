import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Session média partagée avec la notification, l’écran de verrouillage et MPRIS.
PlaybackHandler? playbackHandler;

class PlaybackHandler extends BaseAudioHandler {
  AudioPlayer? _player;
  var skipBack = const Duration(seconds: 10);
  var skipForward = const Duration(seconds: 30);
  var _active = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  void attach(AudioPlayer player) {
    if (identical(_player, player)) return;
    detach();
    _player = player;
    _subscriptions.addAll([
      player.playbackEventStream.listen((_) => _broadcast()),
      player.playingStream.listen((_) => _broadcast()),
      player.speedStream.listen((_) => _broadcast()),
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
    _broadcast();
  }

  void setEpisode({
    required String id,
    required String title,
    required String podcast,
    Uri? artUri,
    Duration? duration,
  }) {
    _active = true;
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        album: podcast,
        artist: podcast,
        artUri: artUri,
        duration: duration != null && duration > Duration.zero
            ? duration
            : null,
      ),
    );
    _broadcast();
  }

  @override
  Future<void> play() async {
    _active = true;
    await _player?.play();
  }

  @override
  Future<void> pause() => _player?.pause() ?? Future<void>.value();

  @override
  Future<void> seek(Duration position) =>
      _player?.seek(position) ?? Future<void>.value();

  @override
  Future<void> stop() async {
    _active = false;
    await _player?.pause();
    await super.stop();
  }

  @override
  Future<void> rewind() => _skip(-skipBack);

  @override
  Future<void> fastForward() => _skip(skipForward);

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) await rewind();
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (begin) await fastForward();
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
    final current = mediaItem.value;
    if (current == null || duration == null || duration <= Duration.zero) {
      return;
    }
    if (current.duration == duration) return;
    mediaItem.add(current.copyWith(duration: duration));
  }

  void _broadcast() {
    final player = _player;
    if (!_active || player == null) return;
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [_rewind, if (playing) _pause else _play, _fastForward],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }
}

const _play = MediaControl(
  androidIcon: 'drawable/audio_service_play_arrow',
  label: 'Lecture',
  action: MediaAction.play,
);

const _pause = MediaControl(
  androidIcon: 'drawable/audio_service_pause',
  label: 'Pause',
  action: MediaAction.pause,
);

const _rewind = MediaControl(
  androidIcon: 'drawable/audio_service_fast_rewind',
  label: 'Reculer',
  action: MediaAction.rewind,
);

const _fastForward = MediaControl(
  androidIcon: 'drawable/audio_service_fast_forward',
  label: 'Avancer',
  action: MediaAction.fastForward,
);

Uri? artworkUri(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.isScheme('http') || uri.isScheme('https') || uri.isScheme('file')) {
    return uri;
  }
  return null;
}
