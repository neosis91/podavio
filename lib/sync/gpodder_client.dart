import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_protocol.dart';

class SyncRequestException implements Exception {
  const SyncRequestException(this.message, {this.unauthorized = false});

  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

/// Client gpodder.net, ou gPodder Sync (Nextcloud) : mêmes données, autres chemins.
class GpodderClient {
  GpodderClient({
    required this.host,
    required this.username,
    required this.password,
    required this.providerId,
    this.deviceId = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final SyncHost host;
  final String username;
  final String password;
  final String providerId;
  final String deviceId;
  final http.Client _http;

  bool get _nextcloud => providerId == syncProviderNextcloud;

  void close() => _http.close();

  Future<void> login() async {
    if (_nextcloud) return;
    await _send(
      'POST',
      host.resolve('/api/2/auth/${_enc(username)}/login.json'),
      body: '',
      contentType: 'text/plain',
    );
  }

  Future<List<SyncDevice>> devices() async {
    final body = await _send(
      'GET',
      host.resolve('/api/2/devices/${_enc(username)}.json'),
    );
    return SyncDevice.parseList(body);
  }

  Future<void> registerDevice({
    required String id,
    required String caption,
    required String type,
  }) async {
    await _send(
      'POST',
      host.resolve('/api/2/devices/${_enc(username)}/${_enc(id)}.json'),
      jsonBody: {'caption': caption, 'type': type},
    );
  }

  Future<SyncSubscriptionChanges> subscriptionChanges(int since) async {
    final body = await _send('GET', _subscriptionsUri(since));
    return SyncSubscriptionChanges.parse(body);
  }

  Future<int> uploadSubscriptions({
    required List<String> add,
    required List<String> remove,
  }) async {
    final body = await _send(
      'POST',
      _subscriptionsPostUri(),
      jsonBody: {'add': add, 'remove': remove},
    );
    return parseUploadTimestamp(body);
  }

  Future<SyncEpisodeChanges> episodeActions(int since) async {
    final body = await _send('GET', _episodesUri(since));
    return SyncEpisodeChanges.parse(body);
  }

  Future<int> uploadEpisodeActions(List<SyncEpisodeAction> actions) async {
    var timestamp = 0;
    const bulk = 30;
    for (var i = 0; i < actions.length; i += bulk) {
      final end = i + bulk < actions.length ? i + bulk : actions.length;
      final slice = actions.sublist(i, end);
      final body = await _send(
        'POST',
        _episodesPostUri(),
        jsonBody: [
          for (final action in slice) action.toJson(deviceId: deviceId),
        ],
      );
      final next = parseUploadTimestamp(body);
      if (next > 0) timestamp = next;
    }
    return timestamp;
  }

  Uri _subscriptionsUri(int since) {
    if (_nextcloud) {
      return _app('subscriptions', {'since': '$since'});
    }
    return host.resolve(
      '/api/2/subscriptions/${_enc(username)}/${_enc(deviceId)}.json',
      {'since': '$since'},
    );
  }

  Uri _subscriptionsPostUri() {
    if (_nextcloud) return _app('subscription_change/create');
    return host.resolve(
      '/api/2/subscriptions/${_enc(username)}/${_enc(deviceId)}.json',
    );
  }

  Uri _episodesUri(int since) {
    if (_nextcloud) return _app('episode_action', {'since': '$since'});
    return host.resolve('/api/2/episodes/${_enc(username)}.json', {
      'since': '$since',
      'aggregated': 'true',
    });
  }

  Uri _episodesPostUri() {
    if (_nextcloud) return _app('episode_action/create');
    return host.resolve('/api/2/episodes/${_enc(username)}.json');
  }

  Uri _app(String path, [Map<String, String>? query]) {
    return host.resolve('/index.php/apps/gpoddersync/$path', query);
  }

  Future<String> _send(
    String method,
    Uri uri, {
    Object? jsonBody,
    String? body,
    String contentType = 'application/json',
  }) async {
    final request = http.Request(method, uri);
    request.headers['Authorization'] = _basic(username, password);
    request.headers['User-Agent'] = 'Podavio';
    request.headers['Accept'] = 'application/json';
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(jsonBody);
    } else if (body != null) {
      request.headers['Content-Type'] = contentType;
      request.body = body;
    }
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(const Duration(seconds: 30));
    } catch (error) {
      throw SyncRequestException('$error');
    }
    final text = await response.stream.bytesToString();
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw const SyncRequestException('unauthorized', unauthorized: true);
    }
    if (code < 200 || code >= 300) {
      throw SyncRequestException('HTTP $code');
    }
    return text;
  }
}

String _basic(String username, String password) {
  final token = base64Encode(utf8.encode('$username:$password'));
  return 'Basic $token';
}

String _enc(String value) => Uri.encodeComponent(value);

/// Démarre le flux navigateur de Nextcloud (login v2).
Future<NextcloudLoginStart> startNextcloudLogin(
  SyncHost host, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  try {
    final uri = host.resolve('/index.php/login/v2');
    final response = await client
        .post(uri, headers: const {'User-Agent': 'Podavio'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncRequestException('HTTP ${response.statusCode}');
    }
    final start = NextcloudLoginStart.parse(response.body);
    if (start == null) {
      throw const SyncRequestException('login');
    }
    return start;
  } catch (error) {
    if (error is SyncRequestException) rethrow;
    throw SyncRequestException('$error');
  } finally {
    if (ownsClient) client.close();
  }
}

/// `null` tant que la personne n’a pas autorisé l’application.
Future<NextcloudLoginResult?> pollNextcloudLogin(
  NextcloudLoginStart start, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  try {
    final response = await client
        .post(
          start.endpoint,
          headers: const {'User-Agent': 'Podavio'},
          body: {'token': start.token},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncRequestException('HTTP ${response.statusCode}');
    }
    final result = NextcloudLoginResult.parse(response.body);
    if (result == null) {
      throw const SyncRequestException('login');
    }
    return result;
  } catch (error) {
    if (error is SyncRequestException) rethrow;
    throw SyncRequestException('$error');
  } finally {
    if (ownsClient) client.close();
  }
}
