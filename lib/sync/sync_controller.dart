import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/activity_messages.dart';
import '../data/automatic_downloads.dart';
import '../data/download_controller.dart';
import '../data/providers.dart';
import '../data/status_notifications.dart';
import '../settings/settings_controller.dart';
import 'gpodder_client.dart';
import 'sync_hooks.dart';
import 'sync_protocol.dart';

const _providerKey = 'syncProvider';
const _hostKey = 'syncHost';
const _usernameKey = 'syncUsername';
const _passwordKey = 'syncPassword';
const _deviceKey = 'syncDeviceId';
const _deviceCaptionKey = 'syncDeviceCaption';
const _subSinceKey = 'syncSubscriptionSince';
const _episodeSinceKey = 'syncEpisodeSince';
const _attemptKey = 'syncLastAttempt';
const _okKey = 'syncLastOk';
const _errorKey = 'syncLastError';
const _addedKey = 'syncQueueAdded';
const _removedKey = 'syncQueueRemoved';
const _actionsKey = 'syncQueueActions';

class SyncStatus {
  const SyncStatus({
    this.providerId,
    this.host = '',
    this.username = '',
    this.deviceCaption = '',
    this.lastAttempt,
    this.lastOk = false,
    this.error,
    this.busy = false,
  });

  final String? providerId;
  final String host;
  final String username;
  final String deviceCaption;
  final DateTime? lastAttempt;
  final bool lastOk;
  final String? error;
  final bool busy;

  bool get connected => providerId != null && providerId!.isNotEmpty;

  SyncProviderOption? get provider => syncProviderById(providerId);

  SyncStatus copyWith({
    String? providerId,
    String? host,
    String? username,
    String? deviceCaption,
    DateTime? lastAttempt,
    bool? lastOk,
    String? error,
    bool clearError = false,
    bool? busy,
    bool clearProvider = false,
  }) {
    return SyncStatus(
      providerId: clearProvider ? null : (providerId ?? this.providerId),
      host: host ?? this.host,
      username: username ?? this.username,
      deviceCaption: deviceCaption ?? this.deviceCaption,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastOk: lastOk ?? this.lastOk,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class GpodderDraft {
  const GpodderDraft({
    required this.host,
    required this.username,
    required this.password,
    required this.devices,
  });

  final SyncHost host;
  final String username;
  final String password;
  final List<SyncDevice> devices;
}

final syncStatusProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  var _running = false;
  var _again = false;
  var _forceAgain = false;

  @override
  SyncStatus build() {
    SyncHooks.subscribed = _enqueueAdd;
    SyncHooks.unsubscribed = _enqueueRemove;
    SyncHooks.episode = _enqueueEpisode;
    ref.onDispose(() {
      if (SyncHooks.subscribed == _enqueueAdd) SyncHooks.subscribed = null;
      if (SyncHooks.unsubscribed == _enqueueRemove) {
        SyncHooks.unsubscribed = null;
      }
      if (SyncHooks.episode == _enqueueEpisode) SyncHooks.episode = null;
      _debounce?.cancel();
    });
    final status = _read();
    if (status.connected) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!ref.mounted) return;
        unawaited(sync());
      });
    }
    return status;
  }

  Future<GpodderDraft> authenticateGpodder({
    required String host,
    required String username,
    required String password,
  }) async {
    final parsed = parseSyncHost(host);
    if (parsed == null) throw const SyncRequestException('host');
    final client = GpodderClient(
      host: parsed,
      username: username.trim(),
      password: password,
      providerId: syncProviderGpodder,
    );
    try {
      await client.login();
      final devices = await client.devices();
      return GpodderDraft(
        host: parsed,
        username: username.trim(),
        password: password,
        devices: devices,
      );
    } finally {
      client.close();
    }
  }

  Future<void> finishGpodder({
    required GpodderDraft draft,
    SyncDevice? device,
    String? newCaption,
    required String deviceType,
  }) async {
    final caption = (newCaption ?? device?.caption ?? 'Podavio').trim();
    final id = device?.id ?? newSyncDeviceId();
    final client = GpodderClient(
      host: draft.host,
      username: draft.username,
      password: draft.password,
      providerId: syncProviderGpodder,
      deviceId: id,
    );
    try {
      await client.login();
      if (device == null) {
        await client.registerDevice(
          id: id,
          caption: caption.isEmpty ? 'Podavio' : caption,
          type: deviceType,
        );
      }
    } finally {
      client.close();
    }
    await _store(
      providerId: syncProviderGpodder,
      host: draft.host.origin,
      username: draft.username,
      password: draft.password,
      deviceId: id,
      deviceCaption: caption.isEmpty ? 'Podavio' : caption,
    );
    state = _read();
    await sync();
  }

  Future<NextcloudLoginStart> beginNextcloud(String host) async {
    final parsed = parseSyncHost(host);
    if (parsed == null) throw const SyncRequestException('host');
    return startNextcloudLogin(parsed);
  }

  /// Vrai quand le navigateur a autorisé Podavio.
  Future<bool> finishNextcloudPoll({
    required NextcloudLoginStart start,
    required String host,
  }) async {
    final result = await pollNextcloudLogin(start);
    if (result == null) return false;
    final parsed = parseSyncHost(
      result.server.isNotEmpty ? result.server : host,
    );
    if (parsed == null) throw const SyncRequestException('host');
    await _store(
      providerId: syncProviderNextcloud,
      host: parsed.origin,
      username: result.username,
      password: result.appPassword,
      deviceId: '',
      deviceCaption: '',
    );
    state = _read();
    unawaited(sync());
    return true;
  }

  Future<void> logout() async {
    _debounce?.cancel();
    final preferences = _preferences;
    await preferences.remove(_providerKey);
    await preferences.remove(_hostKey);
    await preferences.remove(_usernameKey);
    await preferences.remove(_passwordKey);
    await preferences.remove(_deviceKey);
    await preferences.remove(_deviceCaptionKey);
    await preferences.remove(_subSinceKey);
    await preferences.remove(_episodeSinceKey);
    await preferences.remove(_attemptKey);
    await preferences.remove(_okKey);
    await preferences.remove(_errorKey);
    await preferences.remove(_addedKey);
    await preferences.remove(_removedKey);
    await preferences.remove(_actionsKey);
    state = const SyncStatus();
  }

  Future<void> sync({bool force = false}) async {
    if (!state.connected) return;
    if (_running) {
      _again = true;
      _forceAgain = _forceAgain || force;
      return;
    }
    _running = true;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _syncOnce(force: force);
      state = _read().copyWith(busy: false);
    } finally {
      _running = false;
      if (_again) {
        final againForce = _forceAgain;
        _again = false;
        _forceAgain = false;
        await sync(force: againForce);
      }
    }
  }

  Future<void> _syncOnce({required bool force}) async {
    final preferences = _preferences;
    final client = _openClient();
    if (client == null) return;
    try {
      await client.login();
      await _syncSubscriptions(client, preferences, force: force);
      await _syncEpisodes(client, preferences, force: force);
      await preferences.setInt(
        _attemptKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await preferences.setBool(_okKey, true);
      await preferences.remove(_errorKey);
    } on SyncRequestException catch (error) {
      await preferences.setInt(
        _attemptKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await preferences.setBool(_okKey, false);
      await preferences.setString(_errorKey, _errorCode(error));
      if (ref.mounted && ref.read(settingsProvider).notifySyncErrors) {
        final message = notificationText(
          ref.read(settingsProvider),
          'Synchronization failed.',
        );
        await ref.read(statusNotificationsProvider).showSyncError(message);
        if (ref.mounted) {
          ref.read(activityMessagesProvider.notifier).add(message);
        }
      }
    } finally {
      client.close();
    }
  }

  Future<void> _syncSubscriptions(
    GpodderClient client,
    SharedPreferences preferences, {
    required bool force,
  }) async {
    final since = preferences.getInt(_subSinceKey) ?? 0;
    final remote = await client.subscriptionChanges(since);
    final removedQueue = preferences.getStringList(_removedKey) ?? [];
    final addedQueue = preferences.getStringList(_addedKey) ?? [];
    final database = ref.read(databaseProvider);
    SyncHooks.applying = true;
    try {
      for (final url in remote.added) {
        if (removedQueue.contains(url)) continue;
        final existing = await database.findByFeedUrl(url);
        if (existing?.subscribed == true) continue;
        try {
          await ref
              .read(feedServiceProvider)
              .subscribe(
                url,
                notifyNewEpisodes: ref.read(settingsProvider).notifyNewEpisodes,
              );
        } catch (_) {}
      }
      if (ref.mounted) unawaited(runAutomaticDownloads(ref));
      for (final url in remote.removed) {
        if (addedQueue.contains(url)) continue;
        final existing = await database.findByFeedUrl(url);
        if (existing == null || !existing.subscribed) continue;
        final paths = await database.deletePodcast(existing.id);
        await ref.read(downloadServiceProvider).deleteFiles(paths);
      }
    } finally {
      SyncHooks.applying = false;
    }

    var uploadAdd = List<String>.from(addedQueue);
    var uploadRemove = List<String>.from(removedQueue);
    if (since == 0 || force) {
      uploadAdd = await _subscribedUrls();
    }
    uploadAdd.removeWhere(remote.added.contains);
    uploadRemove.removeWhere(remote.removed.contains);
    var timestamp = remote.timestamp;
    if (uploadAdd.isNotEmpty || uploadRemove.isNotEmpty) {
      timestamp = await client.uploadSubscriptions(
        add: uploadAdd,
        remove: uploadRemove,
      );
    }
    await preferences.setStringList(_addedKey, const []);
    await preferences.setStringList(_removedKey, const []);
    if (timestamp > 0) await preferences.setInt(_subSinceKey, timestamp);
  }

  Future<void> _syncEpisodes(
    GpodderClient client,
    SharedPreferences preferences, {
    required bool force,
  }) async {
    final since = preferences.getInt(_episodeSinceKey) ?? 0;
    final remote = await client.episodeActions(since);
    final queued = _readActions(preferences);
    final applicable = remoteActionsToApply(remote.actions, queued);
    SyncHooks.applying = true;
    try {
      for (final action in applicable) {
        await _applyEpisode(action);
      }
    } finally {
      SyncHooks.applying = false;
    }

    final upload = List<SyncEpisodeAction>.from(queued);
    if (since == 0 || force) {
      final played = await ref
          .read(databaseProvider)
          .subscribedPlayedEpisodes();
      for (final entry in played) {
        final total = entry.episode.durationSeconds ?? 0;
        final seconds = total > 0 ? total : 1;
        upload.add(
          SyncEpisodeAction(
            podcast: entry.podcast.feedUrl,
            episode: entry.episode.audioUrl,
            guid: entry.episode.guid,
            action: 'play',
            position: seconds,
            started: seconds,
            total: seconds,
          ),
        );
      }
    }
    var timestamp = remote.timestamp;
    if (upload.isNotEmpty) {
      final next = await client.uploadEpisodeActions(upload);
      if (next > 0) timestamp = next;
      await preferences.remove(_actionsKey);
    }
    if (timestamp > 0) await preferences.setInt(_episodeSinceKey, timestamp);
  }

  Future<void> _applyEpisode(SyncEpisodeAction action) async {
    final database = ref.read(databaseProvider);
    final episode = await database.episodeForSync(
      feedUrl: action.podcast,
      audioUrl: action.episode,
      guid: action.guid,
    );
    if (episode == null) return;
    switch (action.action) {
      case 'new':
        await database.setPlayed(episode.id, played: false);
      case 'delete':
        if (episode.downloadPath != null) {
          SyncHooks.silentEpisodes.add(episode.id);
          try {
            await ref
                .read(downloadProgressProvider.notifier)
                .deleteDownload(episode);
          } finally {
            SyncHooks.silentEpisodes.remove(episode.id);
          }
        }
      case 'download':
        if (episode.downloadPath == null) {
          final episodeId = episode.id;
          SyncHooks.silentEpisodes.add(episodeId);
          unawaited(() async {
            try {
              await ref
                  .read(downloadProgressProvider.notifier)
                  .download(episode);
            } catch (_) {
            } finally {
              SyncHooks.silentEpisodes.remove(episodeId);
            }
          }());
        }
      case 'play':
        final total = action.total ?? episode.durationSeconds ?? 0;
        final position = action.position ?? 0;
        final almostDone = total > 0 && position >= total - 10;
        if (almostDone) {
          await database.setPlayed(episode.id, played: true);
        } else {
          await database.setPosition(episode.id, position * 1000);
          if (episode.played) {
            await database.setPlayed(episode.id, played: false);
          }
        }
      default:
        break;
    }
  }

  void _enqueueAdd(String url) {
    final preferences = _preferences;
    final removed = preferences.getStringList(_removedKey) ?? [];
    removed.remove(url);
    final added = preferences.getStringList(_addedKey) ?? [];
    if (!added.contains(url)) added.add(url);
    unawaited(preferences.setStringList(_removedKey, removed));
    unawaited(preferences.setStringList(_addedKey, added));
    _schedule();
  }

  void _enqueueRemove(String url) {
    final preferences = _preferences;
    final added = preferences.getStringList(_addedKey) ?? [];
    added.remove(url);
    final removed = preferences.getStringList(_removedKey) ?? [];
    if (!removed.contains(url)) removed.add(url);
    unawaited(preferences.setStringList(_addedKey, added));
    unawaited(preferences.setStringList(_removedKey, removed));
    _schedule();
  }

  void _enqueueEpisode(SyncEpisodeReport report) {
    final preferences = _preferences;
    final actions = _readActions(preferences);
    final next = SyncEpisodeAction(
      podcast: report.feedUrl,
      episode: report.audioUrl,
      guid: report.guid,
      action: report.action,
      position: report.positionSeconds,
      started: report.startedSeconds,
      total: report.totalSeconds,
    );
    actions.removeWhere((action) => action.queueKey == next.queueKey);
    actions.add(next);
    unawaited(
      preferences.setString(
        _actionsKey,
        jsonEncode([for (final action in actions) action.toJson()]),
      ),
    );
    _schedule();
  }

  void _schedule() {
    if (!state.connected) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () {
      unawaited(sync());
    });
  }

  GpodderClient? _openClient() {
    final preferences = _preferences;
    final providerId = preferences.getString(_providerKey);
    final host = parseSyncHost(preferences.getString(_hostKey) ?? '');
    final username = preferences.getString(_usernameKey) ?? '';
    final password = preferences.getString(_passwordKey) ?? '';
    if (providerId == null || host == null || username.isEmpty) return null;
    return GpodderClient(
      host: host,
      username: username,
      password: password,
      providerId: providerId,
      deviceId: preferences.getString(_deviceKey) ?? '',
    );
  }

  Future<void> _store({
    required String providerId,
    required String host,
    required String username,
    required String password,
    required String deviceId,
    required String deviceCaption,
  }) async {
    final preferences = _preferences;
    await preferences.setString(_providerKey, providerId);
    await preferences.setString(_hostKey, host);
    await preferences.setString(_usernameKey, username);
    await preferences.setString(_passwordKey, password);
    await preferences.setString(_deviceKey, deviceId);
    await preferences.setString(_deviceCaptionKey, deviceCaption);
    await preferences.remove(_subSinceKey);
    await preferences.remove(_episodeSinceKey);
    await preferences.remove(_errorKey);
  }

  SyncStatus _read() {
    final preferences = _preferences;
    final attempt = preferences.getInt(_attemptKey);
    return SyncStatus(
      providerId: preferences.getString(_providerKey),
      host: preferences.getString(_hostKey) ?? '',
      username: preferences.getString(_usernameKey) ?? '',
      deviceCaption: preferences.getString(_deviceCaptionKey) ?? '',
      lastAttempt: attempt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(attempt),
      lastOk: preferences.getBool(_okKey) ?? false,
      error: preferences.getString(_errorKey),
    );
  }

  List<SyncEpisodeAction> _readActions(SharedPreferences preferences) {
    final raw = preferences.getString(_actionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return [];
      return [for (final item in json) ?_actionFromQueue(item)];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _subscribedUrls() async {
    final podcasts = await ref.read(databaseProvider).listSubscribed();
    return [
      for (final podcast in podcasts)
        if (podcast.feedUrl.startsWith('http')) podcast.feedUrl,
    ];
  }

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);
}

String newSyncDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(4, (_) => random.nextInt(256));
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'podavio-$hex';
}

String _errorCode(SyncRequestException error) {
  if (error.unauthorized) return 'credentials';
  if (error.message.startsWith('HTTP')) return 'failed';
  return 'unreachable';
}

SyncEpisodeAction? _actionFromQueue(Object? raw) {
  if (raw is! Map) return null;
  final podcast = raw['podcast'];
  final episode = raw['episode'];
  final action = raw['action'];
  if (podcast is! String || episode is! String || action is! String) {
    return null;
  }
  final guid = raw['guid'];
  return SyncEpisodeAction(
    podcast: podcast,
    episode: episode,
    guid: guid is String ? guid : '',
    action: action,
    position: raw['position'] is num ? (raw['position'] as num).toInt() : null,
    started: raw['started'] is num ? (raw['started'] as num).toInt() : null,
    total: raw['total'] is num ? (raw['total'] as num).toInt() : null,
  );
}
