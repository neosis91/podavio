import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/app_database.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'playback_handler.dart';

class PlayerUiState {
  const PlayerUiState({
    this.episodeId,
    this.title = '',
    this.podcastTitle = '',
    this.imageUrl,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1,
    this.sleepEndsAt,
    this.sleepAtEnd = false,
    this.error,
  });

  final int? episodeId;
  final String title;
  final String podcastTitle;
  final String? imageUrl;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;
  final DateTime? sleepEndsAt;
  final bool sleepAtEnd;
  final String? error;

  bool get hasEpisode => episodeId != null;

  Duration? get sleepRemaining {
    final ends = sleepEndsAt;
    if (ends == null) return null;
    final remaining = ends.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  PlayerUiState copyWith({
    int? episodeId,
    bool clearEpisode = false,
    String? title,
    String? podcastTitle,
    String? imageUrl,
    bool clearImage = false,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    DateTime? sleepEndsAt,
    bool? sleepAtEnd,
    bool clearSleep = false,
    String? error,
    bool clearError = false,
  }) {
    return PlayerUiState(
      episodeId: clearEpisode ? null : episodeId ?? this.episodeId,
      title: title ?? this.title,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      imageUrl: clearImage ? null : imageUrl ?? this.imageUrl,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      sleepEndsAt: clearSleep ? null : sleepEndsAt ?? this.sleepEndsAt,
      sleepAtEnd: sleepAtEnd ?? (clearSleep ? false : this.sleepAtEnd),
      error: clearError ? null : error ?? this.error,
    );
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerUiState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends Notifier<PlayerUiState> {
  late AudioPlayer _player;
  PlayerUiState _ui = const PlayerUiState();
  var _started = false;
  var _disposed = false;
  var _advancing = false;
  var _sessionReady = false;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPositionUi = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _sleepTimer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  PlayerUiState build() {
    if (!_started) {
      _started = true;
      _player = AudioPlayer();
      final settings = ref.read(settingsProvider);
      _ui = PlayerUiState(speed: settings.speed);
      final handler = playbackHandler;
      if (handler != null) {
        handler.skipBack = Duration(seconds: settings.skipBackSeconds);
        handler.skipForward = Duration(seconds: settings.skipForwardSeconds);
        handler.attach(_player);
      }
      _bind();
      ref.onDispose(_dispose);
      ref.listen(settingsProvider, (previous, next) {
        final session = playbackHandler;
        if (session != null) {
          session.skipBack = Duration(seconds: next.skipBackSeconds);
          session.skipForward = Duration(seconds: next.skipForwardSeconds);
        }
        if (next.speed == _ui.speed) return;
        unawaited(_player.setSpeed(next.speed));
        _emit(_ui.copyWith(speed: next.speed));
      });
    }
    return _ui;
  }

  Future<void> playEntry(EpisodeEntry entry) {
    return _play(entry.episode, entry.podcast);
  }

  Future<void> toggle() async {
    if (!_ui.hasEpisode) return;
    if (_player.playing) {
      await _player.pause();
      await persistPosition();
    } else {
      playbackHandler?.activate();
      await _prepareSession();
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    if (!_ui.hasEpisode) return;
    await _player.seek(position);
    _emit(_ui.copyWith(position: position));
    await persistPosition();
  }

  Future<void> skipBy(int seconds) {
    var target = _ui.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (_ui.duration > Duration.zero && target > _ui.duration) {
      target = _ui.duration;
    }
    return seek(target);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _emit(_ui.copyWith(speed: speed));
    await ref.read(settingsProvider.notifier).setSpeed(speed);
  }

  void setSleep(Duration? duration, {bool atEnd = false}) {
    _sleepTimer?.cancel();
    if (duration == null && !atEnd) {
      _emit(_ui.copyWith(clearSleep: true));
      return;
    }
    if (atEnd) {
      _emit(_ui.copyWith(clearSleep: true, sleepAtEnd: true));
      return;
    }
    final ends = DateTime.now().add(duration!);
    _emit(_ui.copyWith(sleepEndsAt: ends, sleepAtEnd: false));
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().isBefore(ends)) {
        _emit(_ui.copyWith(sleepEndsAt: ends));
        return;
      }
      _sleepTimer?.cancel();
      unawaited(_player.pause());
      _emit(_ui.copyWith(clearSleep: true, playing: false));
    });
  }

  Future<void> persistPosition() async {
    final id = _ui.episodeId;
    if (id == null || _disposed) return;
    _lastPersist = DateTime.now();
    await ref
        .read(databaseProvider)
        .setPosition(id, _ui.position.inMilliseconds);
  }

  Future<void> _play(Episode episode, Podcast podcast) async {
    final duration = episode.durationSeconds == null
        ? Duration.zero
        : Duration(seconds: episode.durationSeconds!);
    var start = Duration(milliseconds: episode.positionMs);
    if (duration > Duration.zero &&
        start >= duration - const Duration(seconds: 5)) {
      start = Duration.zero;
    }
    _emit(
      _ui.copyWith(
        episodeId: episode.id,
        title: episode.title,
        podcastTitle: podcast.title,
        imageUrl: episode.imageUrl ?? podcast.imageUrl,
        clearImage: episode.imageUrl == null && podcast.imageUrl == null,
        position: start,
        duration: duration,
        playing: false,
        clearError: true,
      ),
    );
    try {
      playbackHandler?.setEpisode(
        id: '${episode.id}',
        title: episode.title,
        podcast: podcast.title,
        artUri: artworkUri(episode.imageUrl ?? podcast.imageUrl),
        duration: duration > Duration.zero ? duration : null,
      );
      await _prepareSession();
      final uri = _sourceUri(episode);
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          headers: uri.isScheme('file')
              ? null
              : const {'User-Agent': podavioUserAgent},
        ),
      );
      await _player.setSpeed(_ui.speed);
      if (start > Duration.zero) await _player.seek(start);
      await _player.play();
      await ref
          .read(databaseProvider)
          .setPosition(episode.id, start.inMilliseconds);
    } catch (_) {
      _emit(
        _ui.copyWith(playing: false, error: 'Impossible de lire cet épisode.'),
      );
    }
  }

  Uri _sourceUri(Episode episode) {
    final path = episode.downloadPath;
    if (path != null && File(path).existsSync()) return Uri.file(path);
    return Uri.parse(episode.audioUrl);
  }

  Future<void> _prepareSession() async {
    if (_sessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // La session audio n’existe pas sur toutes les plateformes de bureau.
    }
    _sessionReady = true;
  }

  void _bind() {
    _positionSub = _player.positionStream.listen((position) {
      final now = DateTime.now();
      if (now.difference(_lastPositionUi) >=
          const Duration(milliseconds: 250)) {
        _lastPositionUi = now;
        _emit(_ui.copyWith(position: position));
      } else {
        _ui = _ui.copyWith(position: position);
      }
      final id = _ui.episodeId;
      if (id == null) return;
      if (now.difference(_lastPersist) < const Duration(seconds: 5)) return;
      _lastPersist = now;
      unawaited(
        ref.read(databaseProvider).setPosition(id, position.inMilliseconds),
      );
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration == null) return;
      _emit(_ui.copyWith(duration: duration));
    });
    _stateSub = _player.playerStateStream.listen((playerState) {
      _emit(_ui.copyWith(playing: playerState.playing));
      if (playerState.processingState == ProcessingState.completed) {
        unawaited(_onCompleted());
      }
    });
  }

  Future<void> _onCompleted() async {
    if (_advancing || _disposed) return;
    final id = _ui.episodeId;
    if (id == null) return;
    _advancing = true;
    try {
      await ref.read(databaseProvider).setPlayed(id, played: true);
      final sleepAtEnd = _ui.sleepAtEnd;
      _emit(
        _ui.copyWith(
          playing: false,
          position: Duration.zero,
          clearSleep: sleepAtEnd,
        ),
      );
      if (sleepAtEnd) return;
      final next = await ref.read(databaseProvider).nextInQueue();
      if (next == null || _disposed) return;
      await ref.read(databaseProvider).removeFromQueue(next.episode.id);
      await _play(next.episode, next.podcast);
    } finally {
      _advancing = false;
    }
  }

  void _emit(PlayerUiState next) {
    _ui = next;
    if (!_disposed) state = next;
  }

  Future<void> _dispose() async {
    _disposed = true;
    playbackHandler?.detach();
    _sleepTimer?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _stateSub?.cancel();
    await _player.dispose();
  }
}
