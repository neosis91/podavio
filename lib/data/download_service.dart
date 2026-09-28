import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import 'app_database.dart';
import 'feed_service.dart';

class DownloadService {
  DownloadService(this._database);

  final AppDatabase _database;

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
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(episode.audioUrl));
      request.headers['user-agent'] = podavioUserAgent;
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Téléchargement impossible (${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await _database.setDownloadPath(episode.id, file.path);
    } catch (_) {
      if (sink != null) await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
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
