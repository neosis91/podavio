import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import 'app_database.dart';
import 'feed_service.dart';

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadService {
  DownloadService(this._database);

  final AppDatabase _database;
  final _clients = <int, http.Client>{};
  final _cancelled = <int>{};

  void cancel(int episodeId) {
    _cancelled.add(episodeId);
    _clients.remove(episodeId)?.close();
  }

  Future<void> download(
    Episode episode, {
    void Function(double progress)? onProgress,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'downloads'));
    await folder.create(recursive: true);
    final file = File(
      p.join(
        folder.path,
        '${episode.id}${audioExtension(episode.mimeType, episode.audioUrl)}',
      ),
    );
    final client = http.Client();
    _clients[episode.id] = client;
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(episode.audioUrl));
      request.headers['user-agent'] = podavioUserAgent;
      final response = await client.send(request);
      if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Téléchargement impossible (${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
      await _database.setDownloadPath(episode.id, file.path);
    } catch (error) {
      await _discardPartial(sink, file);
      if (_cancelled.contains(episode.id) || error is DownloadCancelled) {
        throw const DownloadCancelled();
      }
      rethrow;
    } finally {
      _clients.remove(episode.id);
      _cancelled.remove(episode.id);
      client.close();
    }
  }

  Future<void> _discardPartial(IOSink? sink, File file) async {
    try {
      await sink?.close();
    } catch (_) {}
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteDownload(Episode episode) async {
    final path = episode.downloadPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _database.setDownloadPath(episode.id, null);
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
