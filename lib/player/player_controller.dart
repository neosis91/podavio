import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/app_database.dart';
import '../data/feed_service.dart';
import '../data/http_auth.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'playback_handler.dart';
import 'player_sheet_controller.dart';

class PlayerUiState {
  const PlayerUiState({
    this.episodeId,
    this.title = '',
    this.podcastTitle = '',
    this.imageUrl,
    this.imagePath,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1,
    this.volume = 1,
    this.carMode = false,
    this.sleepEndsAt,
    this.sleepAtEnd = false,
    this.error,
  });

  final int? episodeId;
  final String title;
  final String podcastTitle;
  final String? imageUrl;
  final String? imagePath;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  /// Persisté via SharedPreferences (`carMode`).
  final bool carMode;
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
    String? imagePath,
    /// Remplace [imageUrl] / [imagePath] même si la nouvelle valeur est `null`.
    bool updateImage = false,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
    bool? carMode,
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
      imageUrl: updateImage ? imageUrl : imageUrl ?? this.imageUrl,
      imagePath: updateImage ? imagePath : imagePath ?? this.imagePath,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      carMode: carMode ?? this.carMode,
      sleepEndsAt: clearSleep ? null : sleepEndsAt ?? this.sleepEndsAt,
      sleepAtEnd: sleepAtEnd ?? (clearSleep ? false : this.sleepAtEnd),
      error: clearError ? null : error ?? this.error,
    );
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerUiState>(
  PlayerNotifier.new,
);

/// True s’il existe un épisode suivant dans la file après l’épisode en cours.
final hasNextInQueueProvider = StreamProvider<bool>((ref) {
  final episodeId = ref.watch(
    playerProvider.select((state) => state.episodeId),
  );
  return ref.watch(databaseProvider).watchHasNextInQueue(
    afterEpisodeId: episodeId,
  );
});

class PlayerNotifier extends Notifier<PlayerUiState> {
  static const _nowPlayingKey = 'nowPlayingEpisodeId';
  static const _carModeKey = 'carMode';

  late AudioPlayer _player;
  PlayerUiState _ui = const PlayerUiState();
  var _started = false;
  var _disposed = false;
  var _advancing = false;
  var _sessionReady = false;
  /// True une fois que l’utilisateur a vraiment lancé la lecture cette session.
  var _hasPlayedInSession = false;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPositionUi = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _skipIntro = Duration.zero;
  Duration _skipOutro = Duration.zero;
  int? _outroSkippedEpisodeId;
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
      final prefs = ref.read(sharedPreferencesProvider);
      final carMode = prefs.getBool(_carModeKey) ?? false;
      _ui = PlayerUiState(
        speed: settings.speed,
        volume: settings.volume,
        carMode: carMode,
      );
      unawaited(_player.setVolume(settings.volume));
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
        if (previous != null && previous.speed != next.speed) {
          unawaited(_applyDefaultSpeedIfNoPodcastOverride(next.speed));
        }
        if (next.volume != _ui.volume) {
          unawaited(_player.setVolume(next.volume));
          _emit(_ui.copyWith(volume: next.volume));
        }
        if (previous?.preferPodcastCover != next.preferPodcastCover) {
          unawaited(_refreshCoverArt(next.preferPodcastCover));
        }
      });
    }
    return _ui;
  }

  Future<void> playEntry(EpisodeEntry entry) {
    return _play(entry.episode, entry.podcast);
  }

  /// Recharge le dernier épisode en cours sans démarrer la lecture.
  Future<void> restoreLastEpisode() async {
    if (_disposed || !ref.mounted || _ui.hasEpisode) return;
    try {
      final entry = await _resolveRestoreEntry();
      if (_disposed || !ref.mounted || _ui.hasEpisode || entry == null) return;
      await _play(entry.episode, entry.podcast, autoplay: false);
    } catch (error, stack) {
      debugPrint('Reprise lecture impossible: $error\n$stack');
    }
  }

  Future<EpisodeEntry?> _resolveRestoreEntry() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final db = ref.read(databaseProvider);

    // 1) Pref écrite lors d’une vraie lecture (y compris épisode terminé).
    final savedId = prefs.getInt(_nowPlayingKey);
    if (savedId != null) {
      final saved = await db.getEpisode(savedId);
      if (!ref.mounted) return null;
      if (saved != null) return saved;
      await prefs.remove(_nowPlayingKey);
    }

    // 2) Repli : dernier lastPlayedAt, terminé ou non.
    if (!ref.mounted) return null;
    final latest = await db.lastPlayedEpisode();
    if (!ref.mounted || latest == null) return latest;
    await prefs.setInt(_nowPlayingKey, latest.episode.id);
    return latest;
  }

  Future<void> _rememberNowPlaying(int episodeId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_nowPlayingKey, episodeId);
  }

  Future<void> toggle() async {
    if (!_ui.hasEpisode) return;
    if (_player.playing) {
      await _player.pause();
      await persistPosition();
      await syncPositionToEpisode();
    } else {
      playbackHandler?.activate();
      await _prepareSession();
      await _markPlayedInSession();
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

  /// Chapitre précédent (`delta < 0`) ou suivant (`delta > 0`).
  /// Si on est à plus de 3 s dans le chapitre courant, « précédent » le reprend.
  Future<void> skipChapter(
    List<EpisodeChapter> chapters, {
    required int delta,
  }) async {
    if (!_ui.hasEpisode || chapters.isEmpty) return;
    final pos = _ui.position.inMilliseconds;
    var index = -1;
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].startMs <= pos) {
        index = i;
      } else {
        break;
      }
    }
    if (delta < 0) {
      if (index < 0) {
        await seek(Duration.zero);
        return;
      }
      final intoChapter = pos - chapters[index].startMs;
      if (intoChapter > 3000) {
        await seek(Duration(milliseconds: chapters[index].startMs));
        return;
      }
      final prev = index > 0 ? index - 1 : 0;
      await seek(Duration(milliseconds: chapters[prev].startMs));
      return;
    }
    final next = index + 1;
    if (next >= chapters.length) {
      if (_ui.duration > Duration.zero) await seek(_ui.duration);
      return;
    }
    await seek(Duration(milliseconds: chapters[next].startMs));
  }

  /// Ferme le lecteur (mini compris) en gardant la position.
  Future<void> dismiss() async {
    if (!_ui.hasEpisode || _disposed) return;
    await persistPosition();
    await syncPositionToEpisode();
    if (_disposed || !ref.mounted) return;
    _sleepTimer?.cancel();
    try {
      await _player.stop();
    } catch (error, stack) {
      debugPrint('Arrêt lecteur: $error\n$stack');
    }
    if (_disposed || !ref.mounted) return;
    final settings = ref.read(settingsProvider);
    _hasPlayedInSession = false;
    _emit(
      PlayerUiState(speed: settings.speed, volume: settings.volume),
    );
    if (ref.mounted) {
      ref.read(playerSheetProvider.notifier).collapse();
    }
  }

  /// Passe à l’épisode suivant dans la playlist.
  Future<void> playNextInQueue() async {
    if (_advancing || _disposed) return;
    final currentId = _ui.episodeId;
    final next = await ref.read(databaseProvider).nextInQueue(
      afterEpisodeId: currentId,
    );
    if (next == null || _disposed) return;
    _advancing = true;
    try {
      // Ne pas retirer de la file : seulement à la fin complète de l’épisode.
      // `_play` sync la position de l’épisode précédent.
      await _play(next.episode, next.podcast);
    } finally {
      _advancing = false;
    }
  }

  Future<void> setSpeed(double speed) async {
    final value = _normalizeSpeed(speed);
    await _player.setSpeed(value);
    _emit(_ui.copyWith(speed: value));
    final episodeId = _ui.episodeId;
    if (episodeId == null || !ref.mounted) return;
    final entry = await ref.read(databaseProvider).getEpisode(episodeId);
    if (entry == null || !ref.mounted) return;
    await ref.read(databaseProvider).setPodcastPlaybackSpeed(
      entry.podcast.id,
      value,
    );
  }

  /// Vitesse des épisodes de ce podcast. `null` reprend le réglage général.
  Future<void> setPodcastSpeed(int podcastId, double? speed) async {
    await ref.read(databaseProvider).setPodcastPlaybackSpeed(podcastId, speed);
    if (!ref.mounted || _disposed) return;
    final episodeId = _ui.episodeId;
    if (episodeId == null) return;
    final entry = await ref.read(databaseProvider).getEpisode(episodeId);
    if (entry?.podcast.id != podcastId || !ref.mounted || _disposed) return;
    final applied = _normalizeSpeed(speed ?? ref.read(settingsProvider).speed);
    await _player.setSpeed(applied);
    if (!ref.mounted || _disposed) return;
    _emit(_ui.copyWith(speed: applied));
  }

  /// Remet la vitesse du podcast courant au défaut global.
  Future<void> resetPodcastSpeed() async {
    final episodeId = _ui.episodeId;
    if (episodeId == null) return;
    final entry = await ref.read(databaseProvider).getEpisode(episodeId);
    if (entry == null || !ref.mounted) return;
    await ref.read(databaseProvider).setPodcastPlaybackSpeed(
      entry.podcast.id,
      null,
    );
    if (!ref.mounted || _disposed) return;
    final speed = ref.read(settingsProvider).speed;
    await _player.setSpeed(speed);
    _emit(_ui.copyWith(speed: speed));
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
    _emit(_ui.copyWith(volume: clamped));
    await ref.read(settingsProvider.notifier).setVolume(clamped);
  }

  Future<void> nudgeVolume(double delta) {
    return setVolume(_ui.volume + delta);
  }

  Future<void> setCarMode(bool enabled) async {
    _emit(_ui.copyWith(carMode: enabled));
    await ref.read(sharedPreferencesProvider).setBool(_carModeKey, enabled);
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
      unawaited(_pauseForSleep());
    });
  }

  Future<void> _pauseForSleep() async {
    await _player.pause();
    await persistPosition();
    await syncPositionToEpisode();
    _emit(_ui.copyWith(clearSleep: true, playing: false));
  }

  Future<void> _markPlayedInSession() async {
    _hasPlayedInSession = true;
    final id = _ui.episodeId;
    if (id == null || !ref.mounted) return;
    await _rememberNowPlaying(id);
    await persistPosition();
    await syncPositionToEpisode(touchLastPlayed: true);
  }

  /// Persist légère : table `playback_positions` seule (pas de pulse listes).
  Future<void> persistPosition() async {
    final id = _ui.episodeId;
    if (id == null || _disposed || !ref.mounted) return;
    _lastPersist = DateTime.now();
    await ref.read(databaseProvider).upsertPlaybackPosition(
      id,
      _ui.position.inMilliseconds,
    );
  }

  /// Sync métier vers `episodes` (tuiles « en cours », historique, lastPlayedAt).
  Future<void> syncPositionToEpisode({bool? touchLastPlayed}) async {
    final id = _ui.episodeId;
    if (id == null || _disposed || !ref.mounted) return;
    await ref.read(databaseProvider).setPosition(
      id,
      _ui.position.inMilliseconds,
      touchLastPlayed: touchLastPlayed ?? _hasPlayedInSession,
    );
  }

  Future<void> _refreshCoverArt(bool preferPodcastCover) async {
    final id = _ui.episodeId;
    if (id == null || _disposed || !ref.mounted) return;
    final entry = await ref.read(databaseProvider).getEpisode(id);
    if (entry == null || _disposed || !ref.mounted) return;
    final remote = entry.imageUrl(preferPodcastCover: preferPodcastCover);
    final local = entry.imagePath(preferPodcastCover: preferPodcastCover);
    _emit(
      _ui.copyWith(
        imageUrl: remote,
        imagePath: local,
        updateImage: true,
      ),
    );
    playbackHandler?.setEpisode(
      title: entry.episode.title,
      podcast: entry.podcast.title,
      artUri: artworkUri(local ?? remote),
      duration: _ui.duration > Duration.zero ? _ui.duration : null,
    );
  }

  Future<void> _play(
    Episode episode,
    Podcast podcast, {
    bool autoplay = true,
  }) async {
    final previousId = _ui.episodeId;
    if (previousId != null && previousId != episode.id) {
      await persistPosition();
      await syncPositionToEpisode();
    }
    if (!ref.mounted || _disposed) return;

    final db = ref.read(databaseProvider);
    final savedMs = await db.playbackPositionMs(episode.id);
    if (!ref.mounted || _disposed) return;

    final duration = episode.durationSeconds == null
        ? Duration.zero
        : Duration(seconds: episode.durationSeconds!);
    var start = Duration(milliseconds: savedMs ?? episode.positionMs);
    if (duration > Duration.zero &&
        start >= duration - const Duration(seconds: 5)) {
      start = Duration.zero;
    }
    _skipIntro = Duration(seconds: podcast.skipIntroSeconds);
    _skipOutro = Duration(seconds: podcast.skipOutroSeconds);
    _outroSkippedEpisodeId = null;
    start = _applyIntroSkip(start, duration);
    final settings = ref.read(settingsProvider);
    final speed = podcast.playbackSpeed ?? settings.speed;
    final preferPodcastCover = settings.preferPodcastCover;
    final cover = EpisodeEntry(episode: episode, podcast: podcast);
    final remoteImage = cover.imageUrl(preferPodcastCover: preferPodcastCover);
    final localImage = cover.imagePath(preferPodcastCover: preferPodcastCover);
    if (autoplay) {
      _hasPlayedInSession = true;
    }
    _emit(
      _ui.copyWith(
        episodeId: episode.id,
        title: episode.title,
        podcastTitle: podcast.title,
        imageUrl: remoteImage,
        imagePath: localImage,
        updateImage: true,
        position: start,
        duration: duration,
        speed: speed,
        playing: false,
        clearError: true,
      ),
    );
    if (!ref.mounted) return;
    if (autoplay) {
      // Mémoriser seulement lors d’une vraie lecture (pas d’une reprise).
      await _rememberNowPlaying(episode.id);
      await db.upsertPlaybackPosition(episode.id, start.inMilliseconds);
      await db.setPosition(
        episode.id,
        start.inMilliseconds,
        touchLastPlayed: true,
      );
    }
    if (!ref.mounted || _disposed) return;
    try {
      playbackHandler?.setEpisode(
        title: episode.title,
        podcast: podcast.title,
        artUri: artworkUri(localImage ?? remoteImage),
        duration: duration > Duration.zero ? duration : null,
      );
      if (ref.mounted) {
        unawaited(ref.read(feedServiceProvider).ensureChapters(episode.id));
      }
      await _prepareSession();
      if (!ref.mounted || _disposed) return;
      final uri = _sourceUri(episode);
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          headers: uri.scheme == 'http' || uri.scheme == 'https'
              ? podcastRequestHeaders(
                  userAgent: podavioUserAgent,
                  username: podcast.authUsername,
                  password: podcast.authPassword,
                )
              : null,
        ),
      );
      await _player.setSpeed(_ui.speed);
      await _player.setVolume(_ui.volume);
      if (start > Duration.zero) await _player.seek(start);
      if (!ref.mounted || _disposed) return;
      if (autoplay) {
        await _player.play();
      }
    } catch (_) {
      _emit(
        _ui.copyWith(playing: false, error: 'Impossible de lire cet épisode.'),
      );
    }
  }

  Uri _sourceUri(Episode episode) {
    final path = episode.downloadPath;
    if (path == null) return Uri.parse(episode.audioUrl);
    if (path.startsWith('content://')) return Uri.parse(path);
    if (File(path).existsSync()) return Uri.file(path);
    return Uri.parse(episode.audioUrl);
  }

  static double _normalizeSpeed(double speed) {
    final stepped = (speed * 10).round() / 10;
    return stepped.clamp(0.5, 3.0);
  }

  Future<void> _applyDefaultSpeedIfNoPodcastOverride(double speed) async {
    final episodeId = _ui.episodeId;
    if (episodeId != null) {
      final entry = await ref.read(databaseProvider).getEpisode(episodeId);
      if (!ref.mounted || _disposed) return;
      if (entry?.podcast.playbackSpeed != null) return;
    }
    await _player.setSpeed(speed);
    _emit(_ui.copyWith(speed: speed));
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
      _maybeSkipOutro(position);
      if (now.difference(_lastPersist) < const Duration(seconds: 5)) return;
      _lastPersist = now;
      unawaited(
        ref.read(databaseProvider).upsertPlaybackPosition(
          id,
          position.inMilliseconds,
        ),
      );
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration == null) return;
      _emit(_ui.copyWith(duration: duration));
      _maybeSkipOutro(_ui.position);
    });
    _stateSub = _player.playerStateStream.listen((playerState) {
      _emit(_ui.copyWith(playing: playerState.playing));
      if (playerState.processingState == ProcessingState.completed) {
        unawaited(_onCompleted());
      }
    });
  }

  /// Saute le générique de début seulement si la reprise est encore dedans.
  Duration _applyIntroSkip(Duration start, Duration duration) {
    if (_skipIntro <= Duration.zero || start >= _skipIntro) return start;
    if (duration > Duration.zero) {
      final earliestEnd = duration - _skipOutro - const Duration(seconds: 1);
      if (_skipIntro >= earliestEnd) return start;
    }
    return _skipIntro;
  }

  void _maybeSkipOutro(Duration position) {
    if (_advancing || !_ui.playing) return;
    final id = _ui.episodeId;
    if (id == null || _outroSkippedEpisodeId == id) return;
    if (_skipOutro <= Duration.zero) return;
    final duration = _ui.duration;
    if (duration <= Duration.zero) return;
    final limit = duration - _skipOutro;
    if (limit <= _skipIntro + const Duration(seconds: 1)) return;
    if (position < limit) return;
    _outroSkippedEpisodeId = id;
    unawaited(_onCompleted());
  }

  Future<void> _onCompleted() async {
    if (_advancing || _disposed) return;
    final id = _ui.episodeId;
    if (id == null) return;
    _advancing = true;
    try {
      final db = ref.read(databaseProvider);
      // Sync finale puis marquage terminé (position épisode → 0).
      await syncPositionToEpisode();
      await db.setPlayed(id, played: true);
      // Retrait auto de la file uniquement quand l’épisode est terminé.
      await db.removeFromQueue(id);
      // Garder l’épisode en « en cours » pour le mini-player au prochain lancement.
      await _rememberNowPlaying(id);
      final sleepAtEnd = _ui.sleepAtEnd;
      _emit(
        _ui.copyWith(
          playing: false,
          position: Duration.zero,
          clearSleep: sleepAtEnd,
        ),
      );
      if (sleepAtEnd) return;
      final next = await db.nextInQueue(afterEpisodeId: id);
      if (next == null || _disposed) return;
      await _play(next.episode, next.podcast);
    } finally {
      _advancing = false;
    }
  }

  void _emit(PlayerUiState next) {
    _ui = next;
    if (_disposed || !ref.mounted) return;
    state = next;
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
