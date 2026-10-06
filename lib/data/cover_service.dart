import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'feed_service.dart';
import 'http_auth.dart';

/// Télécharge automatiquement les jaquettes de podcasts en local.
///
/// Les jaquettes d’épisode spécifiques (rares) ne sont pas synchronisées
/// en masse : on réutilise en priorité la couverture du podcast.
class CoverService {
  CoverService(this._database);

  final AppDatabase _database;
  final _inflight = <String, Future<String?>>{};
  Directory? _coversDir;
  var _syncRunning = false;
  Timer? _debounce;

  Future<Directory> _coversDirectory() async {
    final cached = _coversDir;
    if (cached != null) return cached;
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'covers'));
    await folder.create(recursive: true);
    _coversDir = folder;
    return folder;
  }

  Future<File> _fileForUrl(String url) async {
    final folder = await _coversDirectory();
    final digest = url.codeUnits.fold<int>(
      0,
      (hash, unit) => (hash * 31 + unit) & 0x7fffffff,
    );
    return File(
      p.join(folder.path, '${digest.toRadixString(16)}${_extension(url)}'),
    );
  }

  String _extension(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    for (final extension in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      if (path.endsWith(extension)) {
        return extension == '.jpeg' ? '.jpg' : extension;
      }
    }
    return '.jpg';
  }

  /// Planifie une sync (évite les rafales quand la liste des podcasts change).
  void schedulePodcastSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(syncMissingPodcastCovers());
    });
  }

  Future<String?> ensureLocalFile(
    String? url, {
    String? username,
    String? password,
  }) async {
    final remote = url?.trim();
    if (remote == null || remote.isEmpty) return null;
    final authorization = basicAuthorization(username, password);
    final key = authorization == null ? remote : '$remote\n$authorization';
    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = _download(remote, username: username, password: password);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<String?> _download(
    String url, {
    String? username,
    String? password,
  }) async {
    final file = await _fileForUrl(url);
    if (await file.exists() && await file.length() > 0) return file.path;

    final client = http.Client();
    try {
      final headers = podcastRequestHeaders(
        userAgent: podavioUserAgent,
        username: username,
        password: password,
      );
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final sent = headers.containsKey('Authorization')
          ? sendKeepingAuthorization(client, request..followRedirects = false)
          : client.send(request);
      final response = await sent.timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = await response.stream.toBytes().timeout(
        const Duration(seconds: 30),
      );
      if (bytes.isEmpty) return null;
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> syncMissingPodcastCovers() async {
    if (_syncRunning) return;
    _syncRunning = true;
    try {
      final items = await _database.podcastsMissingCovers();
      if (items.isEmpty) return;

      // Parallelisme limité pour ne pas saturer le réseau / le disque.
      const concurrency = 3;
      final updates = <({int id, String path})>[];
      for (var i = 0; i < items.length; i += concurrency) {
        final chunk = items.skip(i).take(concurrency).toList();
        final paths = await Future.wait([
          for (final podcast in chunk)
            ensureLocalFile(
              podcast.imageUrl,
              username: podcast.authUsername,
              password: podcast.authPassword,
            ),
        ]);
        for (var j = 0; j < chunk.length; j++) {
          final path = paths[j];
          if (path == null) continue;
          updates.add((id: chunk[j].id, path: path));
        }
      }

      // Une seule transaction → un seul refresh des streams Drift.
      if (updates.isNotEmpty) {
        await _database.setPodcastImagePaths(updates);
      }
    } finally {
      _syncRunning = false;
    }
  }
}
