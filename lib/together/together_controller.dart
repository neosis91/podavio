import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import 'together_discovery.dart';
import 'together_link.dart';
import 'together_protocol.dart';

enum TogetherRole { idle, host, guest }

class TogetherUiState {
  const TogetherUiState({
    this.role = TogetherRole.idle,
    this.code = '',
    this.name = '',
    this.room = '',
    this.people = 0,
    this.peers = const [],
    this.error,
    this.busy = false,
  });

  final TogetherRole role;
  final String code;
  final String name;

  /// Nom choisi par la personne qui a ouvert la salle.
  final String room;

  /// Personnes dans la salle, hôte compris.
  final int people;
  final List<String> peers;
  final String? error;
  final bool busy;

  TogetherUiState copyWith({
    TogetherRole? role,
    String? code,
    String? name,
    String? room,
    int? people,
    List<String>? peers,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return TogetherUiState(
      role: role ?? this.role,
      code: code ?? this.code,
      name: name ?? this.name,
      room: room ?? this.room,
      people: people ?? this.people,
      peers: peers ?? this.peers,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
    );
  }
}

final togetherProvider = NotifierProvider<TogetherController, TogetherUiState>(
  TogetherController.new,
);

class TogetherController extends Notifier<TogetherUiState> {
  TogetherHostLink? _host;
  TogetherGuestLink? _guest;
  StreamSubscription<TogetherIntent>? _intents;
  StreamSubscription<List<String>>? _peers;
  StreamSubscription<TogetherSnapshot>? _states;
  StreamSubscription<TogetherRoomMessage>? _room;
  final _advertiser = TogetherAdvertiser();
  Timer? _pulse;
  TogetherEpisode? _episode;
  int? _episodeId;
  var _seq = 0;
  var _lastRemoteSeq = 0;
  var _applying = false;

  /// Lecture déjà partagée. Un écho local ne doit pas renvoyer l’ordre inverse.
  bool? _sharedPlaying;
  var _leaving = false;
  var _publishTail = Future<void>.value();
  DateTime _seenAt = DateTime.now();
  double? _speedBefore;

  @override
  TogetherUiState build() {
    ref.listen(playerProvider, _onPlayer);
    ref.onDispose(_shutdown);
    final stored = ref
        .read(sharedPreferencesProvider)
        .getString('togetherName');
    return TogetherUiState(name: stored ?? '');
  }

  Future<void> startHost(String name) async {
    if (state.role != TogetherRole.idle || state.busy) return;
    if (ref.read(playerProvider).episodeId == null) return;
    final displayName = await _rememberName(name);
    state = state.copyWith(busy: true, clearError: true, name: displayName);
    TogetherHostLink? link;
    try {
      link = await TogetherHostLink.open();
      link.roomName = displayName;
      final code = newTogetherCode(Random());
      await _advertiser.start(port: link.port, code: code);
      _host = link;
      _speedBefore = ref.read(playerProvider).speed;
      _intents = link.intents.listen(_onIntent);
      _peers = link.peers.listen((peers) {
        if (ref.mounted) state = state.copyWith(peers: peers);
      });
      _pulse = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_publish());
      });
      state = TogetherUiState(
        role: TogetherRole.host,
        code: code,
        name: displayName,
      );
      await _publish();
    } catch (error, stack) {
      await link?.close();
      await _advertiser.stop();
      _host = null;
      state = TogetherUiState(
        name: displayName,
        error: 'Could not start the session.',
      );
      debugPrint('Écoutons ensemble: $error\n$stack');
    }
  }

  Future<void> join(String rawCode, String name) async {
    if (state.role != TogetherRole.idle || state.busy) return;
    final code = normalizeTogetherCode(rawCode);
    final displayName = await _rememberName(name);
    if (code.length != 4) {
      state = state.copyWith(
        name: displayName,
        error: 'Enter the 4-character code.',
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true, name: displayName);
    try {
      final endpoint = await findTogetherSession(code);
      if (!ref.mounted) return;
      if (endpoint == null) {
        state = TogetherUiState(
          name: displayName,
          error: 'Could not find this session.',
        );
        return;
      }
      final guest = await TogetherGuestLink.connect(
        host: endpoint.host,
        port: endpoint.port,
        name: displayName,
      );
      if (!ref.mounted) {
        await guest.close();
        return;
      }
      _guest = guest;
      _speedBefore = ref.read(playerProvider).speed;
      _lastRemoteSeq = 0;
      _states = guest.states.listen(_onRemote, onDone: _onGuestEnded);
      _room = guest.room.listen(_onRoom);
      final room = guest.latestRoom;
      state = TogetherUiState(
        role: TogetherRole.guest,
        code: code,
        name: displayName,
        room: room?.name ?? '',
        people: room?.people ?? 0,
      );
    } catch (_) {
      await _guest?.close();
      _guest = null;
      if (!ref.mounted) return;
      state = TogetherUiState(
        name: displayName,
        error: 'Could not find this session.',
      );
    }
  }

  Future<void> leave() async {
    _leaving = true;
    final speed = _speedBefore;
    await _shutdown();
    _leaving = false;
    if (!ref.mounted) return;
    state = TogetherUiState(name: state.name);
    if (speed == null || !ref.mounted) return;
    await ref.read(playerProvider.notifier).setSpeed(speed);
  }

  Future<String> _rememberName(String name) async {
    final trimmed = name.trim();
    final preferences = ref.read(sharedPreferencesProvider);
    if (trimmed.isEmpty) {
      await preferences.remove('togetherName');
    } else {
      await preferences.setString('togetherName', trimmed);
    }
    return trimmed.isEmpty ? 'Guest' : trimmed;
  }

  void _onPlayer(PlayerUiState? previous, PlayerUiState next) {
    if (_applying || state.role == TogetherRole.idle) {
      _seenAt = DateTime.now();
      return;
    }
    final elapsed = DateTime.now().difference(_seenAt);
    _seenAt = DateTime.now();
    final previousMs =
        previous?.position.inMilliseconds ?? next.position.inMilliseconds;
    final seek =
        previous != null &&
        isTogetherSeek(
          previousMs: previousMs,
          nextMs: next.position.inMilliseconds,
          elapsed: elapsed,
        );
    final playingChanged = previous != null && previous.playing != next.playing;
    final episodeChanged = previous?.episodeId != next.episodeId;
    final speedChanged =
        previous != null && (previous.speed - next.speed).abs() > 0.05;

    if (state.role == TogetherRole.guest) {
      final guest = _guest;
      if (guest == null) return;
      final positionMs = next.position.inMilliseconds;
      if (playingChanged && next.playing != _sharedPlaying) {
        _sharedPlaying = next.playing;
        guest.sendIntent(
          TogetherIntent(
            kind: next.playing
                ? TogetherIntentKind.play
                : TogetherIntentKind.pause,
            positionMs: positionMs,
          ),
        );
      } else if (seek) {
        guest.sendIntent(
          TogetherIntent(kind: TogetherIntentKind.seek, positionMs: positionMs),
        );
      }
      return;
    }

    if (episodeChanged || playingChanged || seek || speedChanged) {
      unawaited(_publish());
    }
  }

  Future<void> _onIntent(TogetherIntent intent) async {
    if (_host == null) return;
    _applying = true;
    try {
      final player = ref.read(playerProvider.notifier);
      final ui = ref.read(playerProvider);
      if ((ui.position.inMilliseconds - intent.positionMs).abs() > 400) {
        await player.seek(Duration(milliseconds: intent.positionMs));
      }
      if (!ref.mounted) return;
      if (intent.kind == TogetherIntentKind.play) {
        _sharedPlaying = true;
        await player.setPlaying(true);
      } else if (intent.kind == TogetherIntentKind.pause) {
        _sharedPlaying = false;
        await player.setPlaying(false);
      }
    } finally {
      _applying = false;
    }
    await _publish();
  }

  Future<void> _onRemote(TogetherSnapshot remote) async {
    if (remote.seq <= _lastRemoteSeq || _applying) return;
    _lastRemoteSeq = remote.seq;
    _sharedPlaying = remote.playing;
    final local = await _localSnapshot();
    if (!ref.mounted || _guest == null) return;
    final plan = planTogetherAdjustment(local: local, remote: remote);
    if (plan.isEmpty) return;
    _applying = true;
    try {
      final player = ref.read(playerProvider.notifier);
      if (plan.load) {
        final entry = await _entryFor(remote.episode);
        if (!ref.mounted || _guest == null) return;
        if (entry == null) {
          state = state.copyWith(error: 'This episode is not in your library.');
          return;
        }
        await player.playEntry(entry, autoplay: false);
      }
      if (!ref.mounted || _guest == null) return;
      if (plan.speed) await player.setSessionSpeed(remote.speed);
      if (plan.seek) {
        await player.seek(Duration(milliseconds: remote.positionMs));
      }
      if (!ref.mounted) return;
      if (plan.playing != null) await player.setPlaying(plan.playing!);
      if (ref.mounted) state = state.copyWith(clearError: true);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(error: 'This episode is not in your library.');
      }
    } finally {
      _applying = false;
    }
  }

  void _onRoom(TogetherRoomMessage message) {
    if (!ref.mounted || state.role != TogetherRole.guest) return;
    state = state.copyWith(room: message.name, people: message.people);
  }

  void _onGuestEnded() {
    if (_leaving || state.role != TogetherRole.guest) return;
    final name = state.name;
    unawaited(() async {
      await _shutdown();
      if (!ref.mounted) return;
      state = TogetherUiState(name: name, error: 'The session ended.');
    }());
  }

  Future<void> _publish() {
    final next = _publishTail.then((_) => _publishNow());
    _publishTail = next.catchError((_) {});
    return next;
  }

  Future<void> _publishNow() async {
    final link = _host;
    if (link == null || _applying || !ref.mounted) return;
    final ui = ref.read(playerProvider);
    final episode = await _episodeFor(ui.episodeId);
    if (episode == null || _host == null) return;
    _seq += 1;
    link.publish(
      TogetherSnapshot(
        seq: _seq,
        playing: ui.playing,
        positionMs: ui.position.inMilliseconds,
        speed: ui.speed,
        episode: episode,
      ),
    );
  }

  Future<TogetherSnapshot?> _localSnapshot() async {
    final ui = ref.read(playerProvider);
    final episode = await _episodeFor(ui.episodeId);
    if (episode == null) return null;
    return TogetherSnapshot(
      seq: 0,
      playing: ui.playing,
      positionMs: ui.position.inMilliseconds,
      speed: ui.speed,
      episode: episode,
    );
  }

  Future<TogetherEpisode?> _episodeFor(int? id) async {
    if (id == null) {
      _episode = null;
      _episodeId = null;
      return null;
    }
    if (_episodeId == id && _episode != null) return _episode;
    final entry = await ref.read(databaseProvider).getEpisode(id);
    if (entry == null) return null;
    _episodeId = id;
    _episode = TogetherEpisode(
      feedUrl: entry.podcast.feedUrl,
      guid: entry.episode.guid,
      title: entry.episode.title,
      podcastTitle: entry.podcast.title,
      audioUrl: entry.episode.audioUrl,
    );
    return _episode;
  }

  Future<EpisodeEntry?> _entryFor(TogetherEpisode episode) async {
    final database = ref.read(databaseProvider);
    var stored = await database.episodeForSync(
      feedUrl: episode.feedUrl,
      audioUrl: episode.audioUrl,
      guid: episode.guid,
    );
    if (stored == null) {
      try {
        await ref.read(feedServiceProvider).preview(episode.feedUrl);
      } catch (_) {
        return null;
      }
      if (!ref.mounted) return null;
      stored = await database.episodeForSync(
        feedUrl: episode.feedUrl,
        audioUrl: episode.audioUrl,
        guid: episode.guid,
      );
    }
    if (stored == null) return null;
    return database.getEpisode(stored.id);
  }

  Future<void> _shutdown() async {
    _pulse?.cancel();
    _pulse = null;
    await _intents?.cancel();
    await _peers?.cancel();
    await _states?.cancel();
    await _room?.cancel();
    _intents = null;
    _peers = null;
    _states = null;
    _room = null;
    _sharedPlaying = null;
    final host = _host;
    final guest = _guest;
    _host = null;
    _guest = null;
    _episode = null;
    _episodeId = null;
    await host?.close();
    await guest?.close();
    await _advertiser.stop();
  }
}
