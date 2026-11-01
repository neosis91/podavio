import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/download_controller.dart';
import '../data/download_service.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../sync/sync_hooks.dart';
import 'web_companion_crypto.dart';
import 'web_companion_keepalive.dart';
import 'web_companion_library.dart';
import 'web_companion_snapshot.dart';
import 'web_companion_link.dart';
import 'web_companion_store.dart';
import 'web_remote.dart';

class WebCompanionState {
  const WebCompanionState({
    this.linked = false,
    this.socketOpen = false,
    this.browserOnline = false,
    this.fingerprint,
    this.browser,
    this.os,
    this.error,
  });

  final bool linked;
  final bool socketOpen;
  final bool browserOnline;
  final String? fingerprint;
  final String? browser;
  final String? os;
  final String? error;

  WebCompanionState copyWith({
    bool? linked,
    bool? socketOpen,
    bool? browserOnline,
    String? fingerprint,
    String? browser,
    String? os,
    String? error,
    bool clearError = false,
  }) {
    return WebCompanionState(
      linked: linked ?? this.linked,
      socketOpen: socketOpen ?? this.socketOpen,
      browserOnline: browserOnline ?? this.browserOnline,
      fingerprint: fingerprint ?? this.fingerprint,
      browser: browser ?? this.browser,
      os: os ?? this.os,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final webCompanionProvider =
    NotifierProvider<WebCompanionController, WebCompanionState>(
      WebCompanionController.new,
    );

class WebCompanionController extends Notifier<WebCompanionState> {
  final _store = WebCompanionStore();
  WebCompanionLink? _link;
  WebCompanionSession? _session;
  Timer? _pushTimer;
  var _pushing = false;
  var _pushAgain = false;
  DateTime _progressSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  var _generation = 0;

  @override
  WebCompanionState build() {
    ref.onDispose(() {
      _generation++;
      _pushTimer?.cancel();
      WebRemoteHooks.send = null;
      WebRemoteHooks.active = false;
      unawaited(_link?.close());
    });
    ref.listen(preferredPodcastsProvider, (_, _) => _schedulePush());
    ref.listen(unreadCountsByPodcastProvider, (_, _) => _schedulePush());
    ref.listen(
      playerProvider.select((player) => player.position),
      (_, _) => _schedulePush(),
    );
    unawaited(_restore());
    return const WebCompanionState();
  }

  Future<void> pair(String raw) async {
    final qr = WebCompanionQr.parse(raw);
    if (qr == null) {
      state = state.copyWith(error: 'invalid');
      return;
    }
    final generation = ++_generation;
    await _link?.close();
    WebCompanionHandshake handshake;
    try {
      handshake = await webCompanionHandshake(
        pwaPub: qr.pwaPub,
        conn: 'pair',
        random: Random.secure(),
      );
    } catch (_) {
      state = state.copyWith(error: 'invalid');
      return;
    }
    if (generation != _generation) return;
    final session = WebCompanionSession(
      relay: qr.relay,
      session: qr.session,
      pwaPub: qr.pwaPub,
      phonePub: handshake.phonePub,
      key: handshake.key,
      fingerprint: handshake.fingerprint,
    );
    await _store.write(session);
    if (generation != _generation) return;
    state = WebCompanionState(linked: true, fingerprint: session.fingerprint);
    await _open(session, generation);
  }

  Future<void> disconnect({bool notifyPeer = true}) async {
    _generation++;
    _pushTimer?.cancel();
    WebRemoteHooks.send = null;
    WebRemoteHooks.active = false;
    ref.read(playerProvider.notifier).setWebRemote(false);
    final link = _link;
    _link = null;
    _session = null;
    if (notifyPeer) {
      await link?.unlink();
    } else {
      await link?.close();
    }
    await _store.clear();
    await stopWebCompanionKeepAlive();
    state = const WebCompanionState();
  }

  Future<void> _restore() async {
    final generation = _generation;
    final session = await _store.read();
    if (generation != _generation || session == null) return;
    state = state.copyWith(
      linked: true,
      fingerprint: session.fingerprint,
      browser: session.browser,
      os: session.os,
      clearError: true,
    );
    await _open(session, generation);
  }

  Future<void> _open(WebCompanionSession session, int generation) async {
    _session = session;
    await startWebCompanionKeepAlive(_keepAliveTitle());
    final link = WebCompanionLink(
      session: session,
      onClient: (client) {
        if (generation != _generation) return;
        final current = _session;
        if (current == null) return;
        final next = current.copyWith(browser: client.browser, os: client.os);
        _session = next;
        unawaited(_store.write(next));
        state = state.copyWith(browser: next.browser, os: next.os);
      },
      onBrowser: (online) {
        if (generation != _generation) return;
        state = state.copyWith(browserOnline: online, socketOpen: true);
        ref.read(playerProvider.notifier).setWebRemote(online);
        if (online) _schedulePush();
      },
      onUnlink: () {
        if (generation != _generation) return;
        unawaited(disconnect(notifyPeer: false));
      },
      onLibrary: (action) {
        if (generation != _generation) return;
        unawaited(_applyLibrary(action));
      },
      onProgress: (progress) {
        unawaited(_saveProgress(progress));
        if (generation != _generation) return;
        unawaited(
          ref
              .read(playerProvider.notifier)
              .showWebPlayback(
                episodeId: progress.episodeId,
                position: Duration(milliseconds: progress.positionMs),
                playing: progress.ended ? false : progress.playing,
                duration: progress.durationMs == null
                    ? null
                    : Duration(milliseconds: progress.durationMs!),
              ),
        );
      },
    );
    _link = link;
    WebRemoteHooks.send = (command) {
      unawaited(link.sendCommand(command));
    };
    unawaited(link.start());
    if (generation == _generation) {
      state = state.copyWith(socketOpen: true, clearError: true);
    }
  }

  void _schedulePush() {
    if (_link?.browserOnline != true) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_push());
    });
  }

  Future<void> _push() async {
    final link = _link;
    if (link == null || !link.browserOnline || _pushing) return;
    _pushing = true;
    try {
      final snapshot = await buildWebCompanionSnapshot(
        ref.read(databaseProvider),
      );
      await link.sendSnapshot(snapshot);
    } catch (_) {
      // La session peut se fermer pendant l’envoi.
    } finally {
      _pushing = false;
      if (_pushAgain) {
        _pushAgain = false;
        unawaited(_push());
      }
    }
  }

  /// Envoi immédiat : une action de bibliothèque ne doit pas attendre la
  /// prochaine progression de lecture.
  void _pushLibrary() {
    if (_link?.browserOnline != true) return;
    _pushTimer?.cancel();
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    unawaited(_push());
  }

  Future<void> _applyLibrary(WebLibraryAction action) async {
    final database = ref.read(databaseProvider);
    try {
      switch (action.kind) {
        case WebLibraryKind.favorite:
          final favorite = action.favorite;
          if (favorite == null) return;
          if (await database.getEpisode(action.episodeId) == null) return;
          await database.setFavorite(action.episodeId, favorite: favorite);
        case WebLibraryKind.download:
          await _downloadFromBrowser(database, action.episodeId);
        case WebLibraryKind.removeDownload:
          final entry = await database.getEpisode(action.episodeId);
          final path = entry?.episode.downloadPath;
          if (entry != null && path != null && path.isNotEmpty) {
            await ref
                .read(downloadProgressProvider.notifier)
                .deleteDownload(entry.episode);
          }
        case WebLibraryKind.playlist:
          final playlistId = action.playlistId;
          final member = action.member;
          if (playlistId == null || member == null) return;
          if (await database.getEpisode(action.episodeId) == null) return;
          if (member) {
            await database.addToPlaylist(playlistId, action.episodeId);
          } else {
            await database.removeFromPlaylist(playlistId, action.episodeId);
          }
        case WebLibraryKind.createPlaylist:
          final name = action.name;
          if (name == null) return;
          if (await database.getEpisode(action.episodeId) == null) return;
          final id = await database.createPlaylist(name);
          await database.addToPlaylist(id, action.episodeId);
      }
    } catch (_) {
      // L’épisode ou la playlist a pu disparaître entre-temps.
    }
    _pushLibrary();
  }

  Future<void> _downloadFromBrowser(AppDatabase database, int episodeId) async {
    final entry = await database.getEpisode(episodeId);
    if (entry == null) {
      await _downloadResult(episodeId, false);
      return;
    }
    final path = entry.episode.downloadPath;
    if (path != null && path.isNotEmpty) {
      await _downloadResult(episodeId, true);
      return;
    }
    var ok = false;
    try {
      await ref.read(downloadProgressProvider.notifier).download(entry.episode);
      ok = true;
    } on DownloadCancelled {
      ok = false;
    } catch (_) {
      ok = false;
    }
    await _downloadResult(episodeId, ok);
  }

  Future<void> _downloadResult(int episodeId, bool ok) async {
    await _link?.sendCommand({
      'type': 'library-result',
      'action': 'download',
      'episodeId': episodeId,
      'ok': ok,
    });
  }

  Future<void> _saveProgress(WebProgress progress) async {
    final settled = progress.ended || progress.playing == false;
    final now = DateTime.now();
    if (!settled &&
        now.difference(_progressSavedAt) < const Duration(seconds: 5)) {
      return;
    }
    _progressSavedAt = now;
    final player = ref.read(playerProvider);
    final sameEpisode = player.episodeId == progress.episodeId;
    if (sameEpisode && player.playing && !WebRemoteHooks.active) return;
    final database = ref.read(databaseProvider);
    final entry = await database.getEpisode(progress.episodeId);
    if (entry == null) return;
    if (progress.ended) {
      await database.setPlayed(progress.episodeId, played: true);
    } else {
      await database.setPosition(progress.episodeId, progress.positionMs);
      await database.upsertPlaybackPosition(
        progress.episodeId,
        progress.positionMs,
      );
      final total = entry.episode.durationSeconds ?? 0;
      SyncHooks.reportEpisode(
        SyncEpisodeReport(
          episodeId: progress.episodeId,
          feedUrl: entry.podcast.feedUrl,
          audioUrl: entry.episode.audioUrl,
          guid: entry.episode.guid,
          action: 'play',
          positionSeconds: progress.positionMs ~/ 1000,
          startedSeconds: 0,
          totalSeconds: total < 0 ? 0 : total,
        ),
      );
    }
    if (sameEpisode && !player.playing && !WebRemoteHooks.active) {
      await ref
          .read(playerProvider.notifier)
          .seek(
            Duration(milliseconds: progress.ended ? 0 : progress.positionMs),
          );
    }
  }

  String _keepAliveTitle() {
    final language = Platform.localeName.toLowerCase();
    if (language.startsWith('fr')) return 'Podavio Web est connecté';
    return 'Podavio Web is connected';
  }
}
