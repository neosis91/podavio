import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import 'playback_handler.dart';
import 'player_controller.dart';

/// Pont Android Auto : browse (Playlist / Non lus / Téléchargements) + contrôles.
class AndroidAutoBridge {
  AndroidAutoBridge(this._ref);

  static const _toDart = MethodChannel('fr.podavio.podavio/android_auto');
  static const _toHost = MethodChannel('fr.podavio.podavio/android_auto_host');

  static const rootId = 'root';
  static const queueId = 'queue';
  static const unreadId = 'unread';
  static const downloadsId = 'downloads';
  static const _episodePrefix = 'episode:';
  static const _browseLimit = 40;

  final Ref _ref;
  var _bound = false;
  ProviderSubscription<PlayerUiState>? _playerSub;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  void bind() {
    if (!_supported || _bound) return;
    _bound = true;
    _toDart.setMethodCallHandler(_onMethodCall);
    _playerSub = _ref.listen<PlayerUiState>(playerProvider, (_, next) {
      unawaited(_pushPlaybackState(next));
    });
    unawaited(_pushPlaybackState(_ref.read(playerProvider)));
  }

  void dispose() {
    if (!_bound) return;
    _bound = false;
    _playerSub?.close();
    _playerSub = null;
    _toDart.setMethodCallHandler(null);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getChildren':
        final parentId = call.arguments as String? ?? rootId;
        return _children(parentId);
      case 'play':
        final state = _ref.read(playerProvider);
        if (state.hasEpisode && !state.playing) {
          await _ref.read(playerProvider.notifier).toggle();
        }
      case 'pause':
        final state = _ref.read(playerProvider);
        if (state.hasEpisode && state.playing) {
          await _ref.read(playerProvider.notifier).toggle();
        }
      case 'skipForward':
        await _ref.read(playerProvider.notifier).skipOutside(
          PlaybackDirection.forward,
        );
      case 'skipBack':
        await _ref.read(playerProvider.notifier).skipOutside(
          PlaybackDirection.backward,
        );
      case 'seek':
        final ms = (call.arguments as num?)?.toInt() ?? 0;
        await _ref.read(playerProvider.notifier).seek(Duration(milliseconds: ms));
      case 'playFromMediaId':
        final mediaId = call.arguments as String? ?? '';
        await _playFromMediaId(mediaId);
      default:
        throw PlatformException(code: 'notImplemented', message: call.method);
    }
    return null;
  }

  Future<List<Map<String, Object?>>> _children(String parentId) async {
    final db = _ref.read(databaseProvider);
    switch (parentId) {
      case rootId:
        return [
          _folder(queueId, 'Playlist', 'Épisodes en file'),
          _folder(unreadId, 'Non lus', 'Boîte de réception'),
          _folder(downloadsId, 'Téléchargements', 'Épisodes hors ligne'),
        ];
      case queueId:
        final items = await db
            .watchEpisodeWindow(queuedOnly: true, limit: _browseLimit)
            .first;
        return [for (final e in items) _episodeItem(e)];
      case unreadId:
        final items = await db
            .watchEpisodeWindow(unreadOnly: true, limit: _browseLimit)
            .first;
        return [for (final e in items) _episodeItem(e)];
      case downloadsId:
        final items = await db
            .watchEpisodeWindow(downloadsOnly: true, limit: _browseLimit)
            .first;
        return [for (final e in items) _episodeItem(e)];
      default:
        return const [];
    }
  }

  Future<void> _playFromMediaId(String mediaId) async {
    if (!mediaId.startsWith(_episodePrefix)) return;
    final id = int.tryParse(mediaId.substring(_episodePrefix.length));
    if (id == null) return;
    final entry = await _ref.read(databaseProvider).getEpisode(id);
    if (entry == null) return;
    await _ref.read(playerProvider.notifier).playEntry(entry);
  }

  Future<void> _pushPlaybackState(PlayerUiState state) async {
    if (!_supported || !_bound) return;
    try {
      await _toHost.invokeMethod<void>('updatePlaybackState', {
        'hasEpisode': state.hasEpisode,
        'playing': state.playing,
        'title': state.title,
        'artist': state.podcastTitle,
        'artworkUri': state.imageUrl,
        'positionMs': state.position.inMilliseconds,
        'durationMs': state.duration.inMilliseconds,
      });
    } on MissingPluginException {
      // Service Auto pas encore attaché.
    } catch (error, stack) {
      debugPrint('Android Auto sync: $error\n$stack');
    }
  }

  Map<String, Object?> _folder(String id, String title, String subtitle) => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'playable': false,
      };

  Map<String, Object?> _episodeItem(EpisodeEntry entry) {
    final artwork = entry.imageUrl() ?? entry.podcast.imageUrl;
    return {
      'id': '$_episodePrefix${entry.episode.id}',
      'title': entry.episode.title,
      'subtitle': entry.podcast.title,
      'playable': true,
      if (artwork != null && artwork.isNotEmpty) 'artworkUri': artwork,
    };
  }
}

final androidAutoBridgeProvider = Provider<AndroidAutoBridge>((ref) {
  final bridge = AndroidAutoBridge(ref);
  bridge.bind();
  ref.onDispose(bridge.dispose);
  return bridge;
});
