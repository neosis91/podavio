import 'dart:convert';

/// Fournisseur branché sur la page Synchronisation.
///
/// Pour en ajouter un : une entrée ici, et une branche dans le client HTTP
/// qui parle son protocole.
class SyncProviderOption {
  const SyncProviderOption({
    required this.id,
    required this.titleKey,
    required this.summaryKey,
    required this.browserLogin,
    required this.devices,
  });

  final String id;
  final String titleKey;
  final String summaryKey;
  final bool browserLogin;
  final bool devices;
}

const syncProviderOptions = <SyncProviderOption>[
  SyncProviderOption(
    id: syncProviderGpodder,
    titleKey: 'gPodder',
    summaryKey: 'gpodder.net, or a compatible server you host.',
    browserLogin: false,
    devices: true,
  ),
  SyncProviderOption(
    id: syncProviderNextcloud,
    titleKey: 'gPodder Sync',
    summaryKey: 'Nextcloud with the gPodder Sync app.',
    browserLogin: true,
    devices: false,
  ),
];

const syncProviderGpodder = 'gpodder';
const syncProviderNextcloud = 'nextcloud';

SyncProviderOption? syncProviderById(String? id) {
  for (final option in syncProviderOptions) {
    if (option.id == id) return option;
  }
  return null;
}

/// Adresse saisie par l’utilisateur, avec schéma et dossier éventuel.
class SyncHost {
  const SyncHost({
    required this.scheme,
    required this.host,
    required this.port,
    required this.folder,
  });

  final String scheme;
  final String host;
  final int port;
  final String folder;

  Uri resolve(String path, [Map<String, String>? query]) {
    final prefix = folder.isEmpty ? '' : folder;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: '$prefix$normalized',
      queryParameters: query,
    );
  }

  String get origin {
    final portSuffix =
        (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80)
        ? ''
        : ':$port';
    return '$scheme://$host$portSuffix$folder';
  }
}

/// `gpodder.net`, `https://hôte:port/dossier`.
SyncHost? parseSyncHost(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  var folder = uri.path;
  if (folder.endsWith('/')) folder = folder.substring(0, folder.length - 1);
  if (folder == '/') folder = '';
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  return SyncHost(
    scheme: uri.scheme,
    host: uri.host,
    port: port,
    folder: folder,
  );
}

class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.caption,
    required this.type,
    required this.subscriptions,
  });

  final String id;
  final String caption;
  final String type;
  final int subscriptions;

  static List<SyncDevice> parseList(String body) {
    final json = jsonDecode(body);
    if (json is! List) return const [];
    final devices = <SyncDevice>[];
    for (final item in json) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is! String || id.trim().isEmpty) continue;
      final caption = item['caption'];
      final type = item['type'];
      final count = item['subscriptions'];
      devices.add(
        SyncDevice(
          id: id.trim(),
          caption: caption is String ? caption : id,
          type: type is String ? type : 'other',
          subscriptions: count is num ? count.toInt() : 0,
        ),
      );
    }
    return devices;
  }
}

class SyncSubscriptionChanges {
  const SyncSubscriptionChanges({
    required this.added,
    required this.removed,
    required this.timestamp,
  });

  final List<String> added;
  final List<String> removed;
  final int timestamp;

  static SyncSubscriptionChanges parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map) {
      return const SyncSubscriptionChanges(
        added: [],
        removed: [],
        timestamp: 0,
      );
    }
    return SyncSubscriptionChanges(
      added: _urls(json['add']),
      removed: _urls(json['remove']),
      timestamp: _timestamp(json['timestamp']),
    );
  }
}

class SyncEpisodeAction {
  const SyncEpisodeAction({
    required this.podcast,
    required this.episode,
    required this.action,
    this.guid = '',
    this.timestamp,
    this.position,
    this.started,
    this.total,
    this.device = '',
  });

  final String podcast;
  final String episode;
  final String guid;
  final String action;
  final DateTime? timestamp;
  final int? position;
  final int? started;
  final int? total;
  final String device;

  Map<String, Object?> toJson({String? deviceId}) {
    return {
      'podcast': podcast,
      'episode': episode,
      if (guid.isNotEmpty) 'guid': guid,
      'action': action,
      'timestamp': syncActionTimestamp(timestamp ?? DateTime.now()),
      if (deviceId != null && deviceId.isNotEmpty) 'device': deviceId,
      if (action == 'play') ...{
        'position': position ?? 0,
        'started': started ?? 0,
        'total': total ?? 0,
      },
    };
  }

  String get queueKey => '$podcast\n$episode\n$guid';
}

class SyncEpisodeChanges {
  const SyncEpisodeChanges({required this.actions, required this.timestamp});

  final List<SyncEpisodeAction> actions;
  final int timestamp;

  static SyncEpisodeChanges parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map) {
      return const SyncEpisodeChanges(actions: [], timestamp: 0);
    }
    final raw = json['actions'];
    final actions = <SyncEpisodeAction>[];
    if (raw is List) {
      for (final item in raw) {
        final action = _action(item);
        if (action != null) actions.add(action);
      }
    }
    return SyncEpisodeChanges(
      actions: actions,
      timestamp: _timestamp(json['timestamp']),
    );
  }
}

class NextcloudLoginStart {
  const NextcloudLoginStart({
    required this.token,
    required this.endpoint,
    required this.login,
  });

  final String token;
  final Uri endpoint;
  final Uri login;

  static NextcloudLoginStart? parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final poll = json['poll'];
    final login = json['login'];
    if (poll is! Map || login is! String) return null;
    final token = poll['token'];
    final endpoint = poll['endpoint'];
    if (token is! String || endpoint is! String) return null;
    final endpointUri = Uri.tryParse(endpoint);
    final loginUri = Uri.tryParse(login);
    if (endpointUri == null || loginUri == null) return null;
    return NextcloudLoginStart(
      token: token,
      endpoint: endpointUri,
      login: loginUri,
    );
  }
}

class NextcloudLoginResult {
  const NextcloudLoginResult({
    required this.server,
    required this.username,
    required this.appPassword,
  });

  final String server;
  final String username;
  final String appPassword;

  static NextcloudLoginResult? parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final server = json['server'];
    final username = json['loginName'];
    final password = json['appPassword'];
    if (server is! String || username is! String || password is! String) {
      return null;
    }
    if (username.isEmpty || password.isEmpty) return null;
    return NextcloudLoginResult(
      server: server,
      username: username,
      appPassword: password,
    );
  }
}

int parseUploadTimestamp(String body) {
  final json = jsonDecode(body);
  if (json is! Map) return 0;
  return _timestamp(json['timestamp']);
}

String syncActionTimestamp(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}

/// Dernière action distante par épisode. Une action locale en attente gagne.
List<SyncEpisodeAction> remoteActionsToApply(
  List<SyncEpisodeAction> remote,
  List<SyncEpisodeAction> queued,
) {
  final blocked = {for (final action in queued) action.queueKey};
  final latest = <String, SyncEpisodeAction>{};
  for (final action in remote) {
    if (blocked.contains(action.queueKey)) continue;
    if (action.action == 'flattr') continue;
    latest[action.queueKey] = action;
  }
  return latest.values.toList();
}

List<String> _urls(Object? raw) {
  if (raw is! List) return const [];
  final urls = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    final url = item.trim();
    if (url.startsWith('http') && !urls.contains(url)) urls.add(url);
  }
  return urls;
}

int _timestamp(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return 0;
}

SyncEpisodeAction? _action(Object? raw) {
  if (raw is! Map) return null;
  final podcast = raw['podcast'];
  final episode = raw['episode'];
  final action = raw['action'];
  if (podcast is! String || episode is! String || action is! String) {
    return null;
  }
  if (podcast.isEmpty || episode.isEmpty) return null;
  final guid = raw['guid'];
  final stamp = raw['timestamp'];
  return SyncEpisodeAction(
    podcast: podcast.trim(),
    episode: episode.trim(),
    guid: guid is String ? guid.trim() : '',
    action: action.trim(),
    timestamp: stamp is String ? DateTime.tryParse(stamp) : null,
    position: _seconds(raw['position']),
    started: _seconds(raw['started']),
    total: _seconds(raw['total']),
    device: raw['device'] is String ? raw['device'] as String : '',
  );
}

int? _seconds(Object? raw) {
  if (raw is! num) return null;
  final value = raw.toInt();
  if (value < 0) return null;
  return value;
}
