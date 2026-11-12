import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:cast/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/app_database.dart';
import '../data/download_controller.dart';
import '../data/download_policy.dart';
import '../data/feed_service.dart';
import '../data/http_auth.dart';
import '../data/online_status.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_hooks.dart';
import '../web_companion/web_remote.dart';
import 'audio_effects.dart';
import 'cast_playback.dart';
import 'cast_session.dart';
import 'playback_handler.dart';
import 'playback_source.dart';
import 'player_sheet_controller.dart';
import 'queue_cursor.dart';
import 'sleep_timer.dart';
import 'stream_cache.dart';
import 'stream_quality.dart';

class PlayerUiState {
  const PlayerUiState({
    this.episodeId,
    this.podcastId,
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
    this.playbackSource = PlaybackSource.queue,
    this.streamQualityLabel,
    this.castDeviceName,
  });

  final int? episodeId;
  final int? podcastId;
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

  /// Liste d’où l’épisode en cours a été lancé.
  final PlaybackSource playbackSource;

  /// « 154 kbps · 48 kHz », ou `null` tant que le flux n’est pas identifié.
  final String? streamQualityLabel;

  /// Nom du récepteur Cast, ou `null` si la lecture est locale.
  final String? castDeviceName;

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
    int? podcastId,
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
    PlaybackSource? playbackSource,
    String? streamQualityLabel,
    bool clearStreamQuality = false,
    String? castDeviceName,
    bool clearCast = false,
  }) {
    return PlayerUiState(
      episodeId: clearEpisode ? null : episodeId ?? this.episodeId,
      podcastId: clearEpisode ? null : podcastId ?? this.podcastId,
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
      playbackSource: playbackSource ?? this.playbackSource,
      streamQualityLabel: clearStreamQuality
          ? null
          : streamQualityLabel ?? this.streamQualityLabel,
      castDeviceName: clearCast ? null : castDeviceName ?? this.castDeviceName,
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
  final source = ref.watch(
    playerProvider.select((state) => state.playbackSource),
  );
  final podcastId = ref.watch(
    playerProvider.select((state) => state.podcastId),
  );
  return QueueCursor().watchHasNext(
    source: source,
    episodeId: episodeId,
    podcastId: podcastId,
    database: ref.watch(databaseProvider),
  );
});

class PlayerNotifier extends Notifier<PlayerUiState> {
  static const _nowPlayingKey = 'nowPlayingEpisodeId';
  static const _carModeKey = 'carMode';

  late AudioPlayer _player;
  late QueueCursor _queue;
  late SleepTimer _sleep;
  int _chapterArm = 0;
  int? _sleepChapterAtMs;
  late CastSession _cast;
  late StreamCache _cache;
  PlayerUiState _ui = const PlayerUiState();
  var _started = false;
  var _disposed = false;
  var _advancing = false;
  var _sessionReady = false;
  var _remote = false;

  /// True une fois que l’utilisateur a vraiment lancé la lecture cette session.
  var _hasPlayedInSession = false;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPositionUi = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _skipIntro = Duration.zero;
  Duration _skipOutro = Duration.zero;
  int? _outroSkippedEpisodeId;
  AndroidLoudnessEnhancer? _loudness;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  PlayerUiState build() {
    if (!_started) {
      _started = true;
      _player = _openPlayer();
      final settings = ref.read(settingsProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      final carMode = prefs.getBool(_carModeKey) ?? false;
      _ui = PlayerUiState(
        speed: settings.speed,
        volume: settings.volume,
        carMode: carMode,
      );
      unawaited(_player.setVolume(settings.volume));
      unawaited(_applyAudioEffects(ref.read(audioEffectsProvider)));
      ref.listen(audioEffectsProvider, (previous, next) {
        unawaited(_applyAudioEffects(next));
      });
      _queue = QueueCursor();
      _sleep = SleepTimer();
      _cast = CastSession();
      _cache = StreamCache(ref.read(downloadServiceProvider));
      final handler = playbackHandler;
      if (handler != null) {
        handler.skipBack = Duration(seconds: settings.skipBackSeconds);
        handler.skipForward = Duration(seconds: settings.skipForwardSeconds);
        handler.onDirectionalSkip = skipOutside;
        handler.attach(_player);
      }
      _bind();
      ref.onDispose(_dispose);
      ref.listen(settingsProvider, (previous, next) {
        final session = playbackHandler;
        if (session != null) {
          session.skipBack = Duration(seconds: next.skipBackSeconds);
          session.skipForward = Duration(seconds: next.skipForwardSeconds);
          session.onDirectionalSkip = skipOutside;
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

  /// Le navigateur associé joue le son. Le téléphone n’est plus que l’écran.
  void setWebRemote(bool active) {
    if (_disposed || _remote == active) return;
    _remote = active;
    WebRemoteHooks.active = active;
    if (!active) {
      _emit(_ui.copyWith(playing: false));
      return;
    }
    if (!_ui.hasEpisode) return;
    if (_player.playing) unawaited(_player.pause());
    WebRemoteHooks.command({
      'type': 'command',
      'action': 'prepare',
      'episodeId': _ui.episodeId,
      'positionMs': _ui.position.inMilliseconds,
    });
    ref.read(playerSheetProvider.notifier).expand();
  }

  /// Affiche l’épisode lu par le navigateur et ouvre le grand lecteur.
  Future<void> showWebPlayback({
    required int episodeId,
    required Duration position,
    bool? playing,
    Duration? duration,
  }) async {
    if (_disposed || !ref.mounted) return;
    final wasRemote = _remote;
    _remote = true;
    WebRemoteHooks.active = true;
    if (_player.playing) unawaited(_player.pause());
    final changed = _ui.episodeId != episodeId;
    if (changed) {
      final entry = await ref.read(databaseProvider).getEpisode(episodeId);
      if (_disposed || !ref.mounted || entry == null || !_remote) return;
      final settings = ref.read(settingsProvider);
      final cover = EpisodeEntry(
        episode: entry.episode,
        podcast: entry.podcast,
      );
      final seconds = entry.episode.durationSeconds;
      _emit(
        _ui.copyWith(
          episodeId: entry.episode.id,
          podcastId: entry.podcast.id,
          title: entry.episode.title,
          podcastTitle: entry.podcast.title,
          imageUrl: cover.imageUrl(
            preferPodcastCover: settings.preferPodcastCover,
          ),
          imagePath: cover.imagePath(
            preferPodcastCover: settings.preferPodcastCover,
          ),
          updateImage: true,
          position: position,
          duration:
              duration ??
              (seconds == null ? Duration.zero : Duration(seconds: seconds)),
          playing: playing ?? false,
          clearError: true,
        ),
      );
    } else {
      _emit(
        _ui.copyWith(position: position, playing: playing, duration: duration),
      );
    }
    if (!wasRemote || changed) {
      ref.read(playerSheetProvider.notifier).expand();
    }
  }

  /// Change la liste suivie par suivant et précédent, sans relancer l’épisode.
  void setPlaybackSource(PlaybackSource source) {
    if (_disposed || _ui.playbackSource == source) return;
    _emit(_ui.copyWith(playbackSource: source));
  }

  Future<void> playEntry(
    EpisodeEntry entry, {
    PlaybackSource? source,
    bool autoplay = true,
  }) async {
    if (_remote) {
      final positionMs = entry.episode.positionMs;
      WebRemoteHooks.command({
        'type': 'command',
        'action': autoplay ? 'play' : 'prepare',
        'episodeId': entry.episode.id,
        'positionMs': positionMs,
      });
      await showWebPlayback(
        episodeId: entry.episode.id,
        position: Duration(milliseconds: positionMs),
        playing: autoplay,
        duration: entry.episode.durationSeconds == null
            ? null
            : Duration(seconds: entry.episode.durationSeconds!),
      );
      return;
    }
    if (source != null) _emit(_ui.copyWith(playbackSource: source));
    return _play(entry.episode, entry.podcast, autoplay: autoplay);
  }

  /// La playlist n’est plus remplie par la lecture. Le lecteur conserve l’appel
  /// au défilement, sans rien ajouter.
  Future<void> extendQueue() async {}

  /// Voir [extendQueue]. Renvoie toujours 0.
  Future<int> prependQueue() async => 0;

  /// Lance l’épisode, ou bascule lecture / pause s’il est déjà chargé.
  ///
  /// Suivant et précédent parcourent la liste d’où la lecture a été lancée.
  /// La playlist ne change que si l’épisode y est ajouté. Un second appui
  /// sur l’épisode en cours met seulement en pause.
  Future<void> playOrPauseEntry(
    EpisodeEntry entry, {
    PlaybackSource? source,
  }) async {
    if (_ui.episodeId == entry.episode.id) {
      await toggle();
      return;
    }
    await playEntry(entry, source: source);
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
    if (_remote) {
      if (!_ui.hasEpisode) return;
      _emit(_ui.copyWith(playing: !_ui.playing));
      WebRemoteHooks.command({'type': 'command', 'action': 'toggle'});
      return;
    }
    if (!_ui.hasEpisode) return;
    if (_cast.active) {
      if (_ui.playing) {
        _cast.pause();
      } else {
        _cast.play();
      }
      return;
    }
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

  /// Lecture ou pause, sans inverser l’état s’il est déjà le bon.
  Future<void> setPlaying(bool playing) async {
    if (!_ui.hasEpisode) return;
    if (_cast.active) {
      if (playing) {
        _cast.play();
      } else {
        _cast.pause();
      }
      return;
    }
    if (_player.playing == playing) return;
    await toggle();
  }

  Future<void> seek(Duration position) async {
    if (_remote) {
      if (!_ui.hasEpisode) return;
      _emit(_ui.copyWith(position: position));
      WebRemoteHooks.command({
        'type': 'command',
        'action': 'seek',
        'positionMs': position.inMilliseconds,
      });
      return;
    }
    if (!_ui.hasEpisode) return;
    if (_cast.active) {
      _cast.seek(position);
      _emit(_ui.copyWith(position: position));
      await persistPosition();
      return;
    }
    await _player.seek(position);
    _emit(_ui.copyWith(position: position));
    await persistPosition();
  }

  /// Notification, casque et Android Auto : saut ou épisode selon le réglage.
  Future<void> skipOutside(PlaybackDirection direction) async {
    if (_disposed || !_ui.hasEpisode) return;
    final settings = ref.read(settingsProvider);
    switch (settings.outsideApp) {
      case OutsideAppControl.skip:
        final seconds = direction == PlaybackDirection.forward
            ? settings.skipForwardSeconds
            : -settings.skipBackSeconds;
        await skipBy(seconds);
      case OutsideAppControl.episode:
        if (direction == PlaybackDirection.forward) {
          await playNextInQueue();
        } else {
          await playPreviousInQueue();
        }
    }
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
    _sleep.close();
    try {
      await _player.stop();
    } catch (error, stack) {
      debugPrint('Arrêt lecteur: $error\n$stack');
    }
    if (_disposed || !ref.mounted) return;
    final settings = ref.read(settingsProvider);
    _hasPlayedInSession = false;
    _emit(PlayerUiState(speed: settings.speed, volume: settings.volume));
    if (ref.mounted) {
      ref.read(playerSheetProvider.notifier).collapse();
    }
  }

  Future<EpisodeEntry?> _relativeEntry(int delta) {
    return _queue.relative(
      delta: delta,
      source: _ui.playbackSource,
      episodeId: _ui.episodeId,
      database: ref.read(databaseProvider),
      isDisposed: () => _disposed,
    );
  }

  /// Épisode précédent dans la liste en cours, sinon dans le podcast.
  /// Sans précédent, reprend l’épisode courant depuis le début.
  Future<void> playPreviousInQueue() async {
    final step = await _queue.previous(
      remote: _remote,
      advancing: _advancing,
      hasEpisode: _ui.hasEpisode,
      position: _ui.position,
      source: _ui.playbackSource,
      episodeId: _ui.episodeId,
      database: ref.read(databaseProvider),
      isDisposed: () => _disposed,
      isMounted: () => ref.mounted,
    );
    await _applyQueueStep(step);
  }

  /// Passe à l’épisode suivant dans la playlist.
  Future<void> playNextInQueue() async {
    final step = await _queue.next(
      remote: _remote,
      advancing: _advancing,
      source: _ui.playbackSource,
      episodeId: _ui.episodeId,
      database: ref.read(databaseProvider),
      isDisposed: () => _disposed,
    );
    // La file reste dans l’ordre affiché. `_play` sync la position précédente.
    await _applyQueueStep(step);
  }

  Future<void> _applyQueueStep(QueueStep step) async {
    switch (step.kind) {
      case QueueStepKind.none:
        return;
      case QueueStepKind.seekStart:
        await seek(Duration.zero);
      case QueueStepKind.remote:
        WebRemoteHooks.command({
          'type': 'command',
          'action': step.remoteAction,
        });
      case QueueStepKind.play:
        final entry = step.entry!;
        _advancing = true;
        try {
          await _play(entry.episode, entry.podcast);
        } finally {
          _advancing = false;
        }
    }
  }

  /// Vitesse pour la session en cours, sans l’enregistrer sur le podcast.
  Future<void> setSessionSpeed(double speed) async {
    final value = _normalizeSpeed(speed);
    await _player.setSpeed(value);
    _emit(_ui.copyWith(speed: value));
  }

  Future<void> setSpeed(double speed) async {
    final value = _normalizeSpeed(speed);
    await _player.setSpeed(value);
    _emit(_ui.copyWith(speed: value));
    final episodeId = _ui.episodeId;
    if (episodeId == null || !ref.mounted) return;
    final entry = await ref.read(databaseProvider).getEpisode(episodeId);
    if (entry == null || !ref.mounted) return;
    await ref
        .read(databaseProvider)
        .setPodcastPlaybackSpeed(entry.podcast.id, value);
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
    await ref
        .read(databaseProvider)
        .setPodcastPlaybackSpeed(entry.podcast.id, null);
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

  void setSleep(
    Duration? duration, {
    bool atEnd = false,
    bool atChapter = false,
  }) {
    final arm = ++_chapterArm;
    _sleepChapterAtMs = null;
    if (atChapter) unawaited(_loadChapterStop(arm));
    _sleep.arm(
      duration: duration,
      atEnd: duration == null && atEnd,
      onCleared: () => _emit(_ui.copyWith(clearSleep: true)),
      onUntilEnd: () => _emit(_ui.copyWith(clearSleep: true, sleepAtEnd: true)),
      onArmed: (ends) =>
          _emit(_ui.copyWith(sleepEndsAt: ends, sleepAtEnd: atEnd)),
      onTick: (ends) => _emit(_ui.copyWith(sleepEndsAt: ends)),
      onElapsed: _pauseForSleep,
    );
  }

  /// Prochaine frontière de chapitre après la position actuelle.
  Future<void> _loadChapterStop(int arm) async {
    final id = _ui.episodeId;
    if (id == null || !ref.mounted) return;
    final chapters = await ref.read(databaseProvider).watchChapters(id).first;
    if (arm != _chapterArm || _disposed) return;
    final position = _ui.position.inMilliseconds;
    for (final chapter in chapters) {
      if (chapter.startMs > position + 1000) {
        _sleepChapterAtMs = chapter.startMs;
        return;
      }
    }
  }

  void _maybeSleepAtChapter(Duration position) {
    final boundary = _sleepChapterAtMs;
    if (boundary == null || !_ui.playing) return;
    if (position.inMilliseconds + 400 < boundary) return;
    _sleepChapterAtMs = null;
    unawaited(_pauseForSleep());
  }

  Future<void> _pauseForSleep() async {
    _sleepChapterAtMs = null;
    _chapterArm++;
    _sleep.close();
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
    await ref
        .read(databaseProvider)
        .upsertPlaybackPosition(id, _ui.position.inMilliseconds);
  }

  /// Sync métier vers `episodes` (tuiles « en cours », lectures récentes, lastPlayedAt).
  Future<void> syncPositionToEpisode({bool? touchLastPlayed}) async {
    final id = _ui.episodeId;
    if (id == null || _disposed || !ref.mounted) return;
    await ref
        .read(databaseProvider)
        .setPosition(
          id,
          _ui.position.inMilliseconds,
          touchLastPlayed: touchLastPlayed ?? _hasPlayedInSession,
        );
    final entry = await ref.read(databaseProvider).getEpisode(id);
    if (entry == null || _disposed || !ref.mounted) return;
    final total = entry.episode.durationSeconds ?? _ui.duration.inSeconds;
    SyncHooks.reportEpisode(
      SyncEpisodeReport(
        episodeId: id,
        feedUrl: entry.podcast.feedUrl,
        audioUrl: entry.episode.audioUrl,
        guid: entry.episode.guid,
        action: 'play',
        positionSeconds: _ui.position.inSeconds,
        startedSeconds: 0,
        totalSeconds: total < 0 ? 0 : total,
      ),
    );
  }

  Future<void> _refreshCoverArt(bool preferPodcastCover) async {
    final id = _ui.episodeId;
    if (id == null || _disposed || !ref.mounted) return;
    final entry = await ref.read(databaseProvider).getEpisode(id);
    if (entry == null || _disposed || !ref.mounted) return;
    final remote = entry.imageUrl(preferPodcastCover: preferPodcastCover);
    final local = entry.imagePath(preferPodcastCover: preferPodcastCover);
    _emit(_ui.copyWith(imageUrl: remote, imagePath: local, updateImage: true));
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
        podcastId: podcast.id,
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
        clearStreamQuality: true,
      ),
    );
    final storedDownload = episode.downloadPath?.trim();
    final downloaded = storedDownload != null && storedDownload.isNotEmpty;
    // Un fichier téléchargé se lit toujours en local. Le Wi-Fi, les données
    // mobiles et l’absence d’internet ne s’appliquent qu’au flux distant.
    final Uri sourceUri;
    if (downloaded) {
      final path = await ref
          .read(downloadServiceProvider)
          .readablePlaybackPath(storedDownload);
      if (!ref.mounted || _disposed) return;
      if (path == null || path.isEmpty) {
        _emit(
          _ui.copyWith(playing: false, error: 'Impossible de lire ce fichier.'),
        );
        return;
      }
      sourceUri = Uri.file(path);
    } else {
      sourceUri = Uri.parse(episode.audioUrl);
      if (_isRemote(sourceUri) && !settings.allowMobileStreaming) {
        final onMobile = await ref.read(mobileDataProbeProvider)();
        if (!ref.mounted || _disposed) return;
        if (onMobile) {
          _emit(
            _ui.copyWith(
              playing: false,
              error: 'Le streaming est limité au Wi-Fi.',
            ),
          );
          return;
        }
      }
    }
    unawaited(
      _publishStreamQuality(
        episodeId: episode.id,
        uri: sourceUri,
        headers: sourceUri.scheme == 'http' || sourceUri.scheme == 'https'
            ? podcastRequestHeaders(
                userAgent: podavioUserAgent,
                username: podcast.authUsername,
                password: podcast.authPassword,
              )
            : null,
        duration: duration,
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
      await _cache.open(
        _player,
        sourceUri,
        headers: downloaded
            ? null
            : podcastRequestHeaders(
                userAgent: podavioUserAgent,
                username: podcast.authUsername,
                password: podcast.authPassword,
              ),
        episodeId: episode.id,
        isUsable: () => ref.mounted && !_disposed,
        isSameEpisode: () =>
            ref.mounted && !_disposed && _ui.episodeId == episode.id,
      );
      await _player.setSpeed(_ui.speed);
      await _player.setVolume(_ui.volume);
      if (start > Duration.zero) await _player.seek(start);
      if (!ref.mounted || _disposed) return;
      if (_cast.active) {
        await _player.pause();
        final error = await _cast.load(
          episode: episode,
          podcast: podcast,
          position: start,
          preferPodcastCover: preferPodcastCover,
        );
        if (error != null && !_disposed) {
          _emit(_ui.copyWith(error: error, playing: false));
        }
      } else if (autoplay) {
        await _player.play();
      }
    } catch (error, stack) {
      debugPrint('Lecture impossible: $error\n$stack');
      _emit(
        _ui.copyWith(
          playing: false,
          error: downloaded
              ? 'Impossible de lire ce fichier.'
              : 'Impossible de lire cet épisode.',
        ),
      );
    }
  }

  /// Envoie l’épisode sur [device] et met le lecteur local en pause.
  /// Renvoie un message si le flux ne peut pas être casté.
  Future<String?> castTo(CastDevice device) async {
    if (!_ui.hasEpisode) return 'Aucune lecture en cours';
    final entry = await ref.read(databaseProvider).getEpisode(_ui.episodeId!);
    if (!ref.mounted || _disposed || entry == null) return null;
    final url = entry.episode.audioUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'Cet épisode n’a pas d’adresse que le Cast peut lire';
    }
    final opened = await _cast.connect(
      device,
      isGone: () => _disposed || !ref.mounted,
      onUpdate: _onCastUpdate,
    );
    if (opened.aborted) return null;
    if (!opened.connected) return opened.message;
    await _player.pause();
    _emit(_ui.copyWith(castDeviceName: device.name, playing: true));
    final error = await _cast.load(
      episode: entry.episode,
      podcast: entry.podcast,
      position: _ui.position,
      preferPodcastCover: ref.read(settingsProvider).preferPodcastCover,
    );
    if (error != null) {
      await playHere();
      return error;
    }
    return null;
  }

  /// Revient sur l’appareil, à la position du Cast.
  Future<void> playHere() async {
    if (!_cast.active) return;
    final position = _ui.position;
    final wasPlaying = _ui.playing;
    await _cast.release();
    if (_disposed || !ref.mounted) return;
    _emit(_ui.copyWith(clearCast: true, playing: false, position: position));
    await _player.seek(position);
    if (wasPlaying && !_disposed) {
      await _player.play();
    }
  }

  void _onCastUpdate(CastPlaybackUpdate update) {
    if (_disposed || !_cast.active || !ref.mounted) return;
    if (update.completed) {
      unawaited(_onCompleted());
      return;
    }
    _emit(_ui.copyWith(position: update.position, playing: update.playing));
    final id = _ui.episodeId;
    if (id == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPersist) < const Duration(seconds: 5)) return;
    _lastPersist = now;
    unawaited(
      ref
          .read(databaseProvider)
          .upsertPlaybackPosition(id, update.position.inMilliseconds),
    );
  }

  Future<void> _publishStreamQuality({
    required int episodeId,
    required Uri uri,
    required Map<String, String>? headers,
    required Duration duration,
  }) async {
    try {
      final label = await loadStreamQualityLabel(
        uri: uri,
        headers: headers,
        duration: duration > Duration.zero ? duration : null,
      );
      if (_disposed || !ref.mounted || _ui.episodeId != episodeId) return;
      if (label == null || label == _ui.streamQualityLabel) return;
      _emit(_ui.copyWith(streamQualityLabel: label));
    } catch (_) {
      // Le flux reste lisible sans la ligne de qualité.
    }
  }

  bool _isRemote(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  static double _normalizeSpeed(double speed) {
    final stepped = (speed * 100).round() / 100;
    return stepped.clamp(0.4, 7.0);
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

  static const _amplifyGain = 8.0;

  AudioPlayer _openPlayer() {
    if (kIsWeb || !Platform.isAndroid) return AudioPlayer();
    final effects = ref.read(audioEffectsProvider);
    final loudness = AndroidLoudnessEnhancer();
    _loudness = loudness;
    loudness.setTargetGain(effects.amplify ? _amplifyGain : 0);
    loudness.setEnabled(effects.amplify);
    return AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [loudness]),
    );
  }

  Future<void> _applyAudioEffects(AudioEffects effects) async {
    // just_audio expose la coupure des silences et le renforcement Android.
    // Le stabilisateur et le mono restent mémorisés : le moteur n’a pas
    // de compresseur ni de mixage mono.
    try {
      await _player.setSkipSilenceEnabled(effects.skipSilence);
    } catch (_) {
      // La coupure des silences n’existe pas sur toutes les plateformes.
    }
    final loudness = _loudness;
    if (loudness == null) return;
    try {
      await loudness.setTargetGain(effects.amplify ? _amplifyGain : 0);
      await loudness.setEnabled(effects.amplify);
    } catch (_) {}
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
      if (_cast.active || _remote) return;
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
      _maybeSleepAtChapter(position);
      if (now.difference(_lastPersist) < const Duration(seconds: 5)) return;
      _lastPersist = now;
      unawaited(
        ref
            .read(databaseProvider)
            .upsertPlaybackPosition(id, position.inMilliseconds),
      );
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration == null || _remote) return;
      _emit(_ui.copyWith(duration: duration));
      _maybeSkipOutro(_ui.position);
    });
    _stateSub = _player.playerStateStream.listen((playerState) {
      if (_cast.active || _remote) return;
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
      // Avant le marquage : un filtre « non lus » ou « en cours » retire
      // l’épisode de la liste dès qu’il est terminé. C’est le premier
      // « À suivre » du grand lecteur. La file n’est pas modifiée.
      final following = await _relativeEntry(1);
      // Sync finale puis marquage terminé (position épisode → 0).
      await syncPositionToEpisode();
      await db.setPlayed(id, played: true);
      // Garder l’épisode en « en cours » pour le mini-player au prochain lancement.
      await _rememberNowPlaying(id);
      final sleepAtEnd = _ui.sleepAtEnd;
      if (sleepAtEnd) {
        _sleepChapterAtMs = null;
        _chapterArm++;
        _sleep.close();
      }
      _emit(
        _ui.copyWith(
          playing: false,
          position: Duration.zero,
          clearSleep: sleepAtEnd,
        ),
      );
      var movedOn = false;
      if (!sleepAtEnd && !_disposed && following != null) {
        await _play(following.episode, following.podcast);
        movedOn = _ui.episodeId != id;
      }
      // Ici seulement : marquer lu à la main ne passe pas par cette méthode.
      await _deleteDownloadAfterPlayback(id, releasePlayer: !movedOn);
    } finally {
      _advancing = false;
    }
  }

  /// Efface le fichier de l’épisode terminé si le réglage est actif.
  /// Un favori est conservé. [releasePlayer] : on reste sur cet épisode,
  /// donc le lecteur doit lâcher le fichier avant de l’effacer.
  Future<void> _deleteDownloadAfterPlayback(
    int episodeId, {
    required bool releasePlayer,
  }) async {
    if (_disposed || !ref.mounted) return;
    final entry = await ref.read(databaseProvider).getEpisode(episodeId);
    if (entry == null || _disposed || !ref.mounted) return;
    final episode = entry.episode;
    if (!shouldDeleteAfterPlayback(
      enabled: ref.read(settingsProvider).deleteAfterPlayback,
      favorite: episode.favorite,
      downloadPath: episode.downloadPath,
    )) {
      return;
    }
    if (releasePlayer && _ui.episodeId == episodeId) {
      await _loadRemoteSource(episode, entry.podcast);
    }
    if (_disposed || !ref.mounted) return;
    try {
      await ref.read(downloadProgressProvider.notifier).deleteDownload(episode);
    } catch (error, stack) {
      debugPrint('Suppression après lecture: $error\n$stack');
    }
  }

  /// Pointe le lecteur local vers le flux, pour lâcher le fichier
  /// et permettre de relancer l’épisode une fois le fichier effacé.
  Future<void> _loadRemoteSource(Episode episode, Podcast podcast) async {
    final url = episode.audioUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    if (_disposed || !ref.mounted || _ui.episodeId != episode.id) return;
    try {
      if (_player.playing) await _player.pause();
    } catch (error, stack) {
      debugPrint('Pause avant suppression: $error\n$stack');
    }
    if (_disposed || !ref.mounted || _ui.episodeId != episode.id) return;
    try {
      await _cache.open(
        _player,
        uri,
        headers: podcastRequestHeaders(
          userAgent: podavioUserAgent,
          username: podcast.authUsername,
          password: podcast.authPassword,
        ),
        episodeId: episode.id,
        isUsable: () => ref.mounted && !_disposed,
        isSameEpisode: () =>
            ref.mounted && !_disposed && _ui.episodeId == episode.id,
      );
    } catch (error, stack) {
      debugPrint('Flux après suppression: $error\n$stack');
    }
  }

  void _emit(PlayerUiState next) {
    _ui = next;
    if (_disposed || !ref.mounted) return;
    state = next;
  }

  Future<void> _dispose() async {
    _disposed = true;
    final handler = playbackHandler;
    if (handler != null) {
      handler.onDirectionalSkip = null;
      handler.detach();
    }
    _sleep.close();
    await _cast.release();
    await _cache.close();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _stateSub?.cancel();
    await _player.dispose();
  }
}
