import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../core/format.dart';
import '../sync/sync_hooks.dart';
import 'app_database.dart';
import 'feed_service.dart';
import 'http_auth.dart';

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadRelocation {
  const DownloadRelocation({required this.moved, required this.failed});

  final int moved;
  final int failed;
}

bool isContentUri(String value) => value.startsWith('content://');

String downloadDirectoryLabel(String location) {
  if (!isContentUri(location)) return location;
  final uri = Uri.parse(location);
  final raw = uri.pathSegments.isEmpty ? location : uri.pathSegments.last;
  final decoded = Uri.decodeComponent(raw);
  final colon = decoded.indexOf(':');
  final relative = colon == -1 ? decoded : decoded.substring(colon + 1);
  if (relative.isEmpty) return 'Stockage du téléphone';
  return relative;
}

bool sameDownloadLocation(String a, String b) {
  if (isContentUri(a) || isContentUri(b)) return a == b;
  return p.normalize(p.absolute(a)) == p.normalize(p.absolute(b));
}

class DownloadService {
  DownloadService(this._database);

  final AppDatabase _database;
  final _clients = <int, http.Client>{};
  final _cancelled = <int>{};
  SafStream? _safStream;
  SafUtil? _safUtil;

  SafStream get _saf => _safStream ??= SafStream();

  SafUtil get _documents => _safUtil ??= SafUtil();

  void cancel(int episodeId) {
    _cancelled.add(episodeId);
    _clients.remove(episodeId)?.close();
  }

  Future<String> resolveDownloadDirectory(String? configured) async {
    if (configured != null && configured.isNotEmpty) return configured;
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'downloads'));
    await folder.create(recursive: true);
    return folder.path;
  }

  Future<void> download(
    Episode episode, {
    String? directory,
    void Function(double progress)? onProgress,
  }) async {
    final location = await resolveDownloadDirectory(directory);
    final podcast = await _database.getPodcast(episode.podcastId);
    final name = downloadFileName(
      podcastTitle: podcast?.title ?? '',
      episodeTitle: episode.title,
      extension: audioExtension(episode.mimeType, episode.audioUrl),
    );
    final client = http.Client();
    _clients[episode.id] = client;
    File? file;
    String? contentUri;
    String? session;
    try {
      final headers = podcastRequestHeaders(
        userAgent: podavioUserAgent,
        username: podcast?.authUsername,
        password: podcast?.authPassword,
      );
      final request = http.Request('GET', Uri.parse(episode.audioUrl));
      request.headers.addAll(headers);
      final response = headers.containsKey('Authorization')
          ? await sendKeepingAuthorization(
              client,
              request..followRedirects = false,
            )
          : await client.send(request);
      if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
      if (response.statusCode == 401) {
        throw Exception(
          'Téléchargement refusé. Vérifiez l’identifiant dans les paramètres du podcast.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Téléchargement impossible (${response.statusCode}).');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      if (isContentUri(location)) {
        final info = await _saf.startWriteStream(
          location,
          name,
          _mime(episode),
          overwrite: true,
        );
        session = info.session;
        contentUri = info.fileResult.uri.toString();
        await for (final chunk in response.stream) {
          if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
          final bytes = Uint8List.fromList(chunk);
          await _saf.writeChunk(session, bytes);
          received += bytes.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await _saf.endWriteStream(session);
        session = null;
      } else {
        final folder = Directory(location);
        await folder.create(recursive: true);
        file = File(p.join(folder.path, name));
        final sink = file.openWrite();
        try {
          await for (final chunk in response.stream) {
            if (_cancelled.contains(episode.id)) {
              throw const DownloadCancelled();
            }
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) onProgress?.call(received / total);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      }
      if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
      await _database.setDownloadPath(episode.id, contentUri ?? file!.path);
      if (podcast != null) {
        SyncHooks.reportEpisode(
          SyncEpisodeReport(
            episodeId: episode.id,
            feedUrl: podcast.feedUrl,
            audioUrl: episode.audioUrl,
            guid: episode.guid,
            action: 'download',
          ),
        );
      }
      file = null;
      contentUri = null;
    } catch (error) {
      if (session != null) {
        try {
          await _saf.endWriteStream(session);
        } catch (_) {}
        session = null;
      }
      await _discardPartial(file);
      if (contentUri != null) await _deleteContent(contentUri);
      if (_cancelled.contains(episode.id) || error is DownloadCancelled) {
        throw const DownloadCancelled();
      }
      rethrow;
    } finally {
      if (session != null) {
        try {
          await _saf.endWriteStream(session);
        } catch (_) {}
      }
      _clients.remove(episode.id);
      _cancelled.remove(episode.id);
      client.close();
    }
  }

  Future<DownloadRelocation> relocateDownloads({
    required String? from,
    required String? to,
  }) async {
    final sourceRoot = await resolveDownloadDirectory(from);
    final targetRoot = await resolveDownloadDirectory(to);
    if (sameDownloadLocation(sourceRoot, targetRoot)) {
      return const DownloadRelocation(moved: 0, failed: 0);
    }
    await _ensureWritable(targetRoot);
    final episodes = await _database.downloadedEpisodes();
    var moved = 0;
    var failed = 0;
    for (final episode in episodes) {
      final path = episode.downloadPath;
      if (path == null) continue;
      try {
        final next = await _moveStoredFile(episode, path, targetRoot);
        if (next == null) continue;
        if (next != path) await _database.updateDownloadPath(episode.id, next);
        moved++;
      } catch (_) {
        failed++;
      }
    }
    return DownloadRelocation(moved: moved, failed: failed);
  }

  Future<void> deleteDownload(Episode episode) async {
    final path = episode.downloadPath;
    if (path != null) await deleteStored(path);
    await _database.setDownloadPath(episode.id, null);
    final podcast = await _database.getPodcast(episode.podcastId);
    if (podcast != null) {
      SyncHooks.reportEpisode(
        SyncEpisodeReport(
          episodeId: episode.id,
          feedUrl: podcast.feedUrl,
          audioUrl: episode.audioUrl,
          guid: episode.guid,
          action: 'delete',
        ),
      );
    }
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      await deleteStored(path);
    }
  }

  Future<void> deleteStored(String path) async {
    if (isContentUri(path)) {
      await _deleteContent(path);
      return;
    }
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<String?> _moveStoredFile(
    Episode episode,
    String source,
    String targetRoot,
  ) async {
    if (isContentUri(source) && isContentUri(targetRoot)) {
      final document = await _documents.documentFileFromUri(source, false);
      if (document == null) return null;
      final existing = await _documents.child(targetRoot, [document.name]);
      if (existing != null && existing.uri == source) return source;
      if (existing != null) await _documents.delete(existing.uri, false);
      final copied = await _documents.copyTo(source, false, targetRoot);
      if (copied.uri == source) return source;
      await _deleteContent(source);
      return copied.uri;
    }
    if (isContentUri(source)) {
      final document = await _documents.documentFileFromUri(source, false);
      if (document == null) return null;
      final dest = File(p.join(targetRoot, document.name));
      if (await dest.exists()) await dest.delete();
      await _saf.copyToLocalFile(source, dest.path);
      await _deleteContent(source);
      return dest.path;
    }
    final file = File(source);
    if (!await file.exists()) return null;
    if (isContentUri(targetRoot)) {
      final created = await _saf.pasteLocalFile(
        file.path,
        targetRoot,
        p.basename(file.path),
        _mime(episode),
        overwrite: true,
      );
      await file.delete();
      return created.uri.toString();
    }
    final dest = File(p.join(targetRoot, p.basename(file.path)));
    if (sameDownloadLocation(file.path, dest.path)) return dest.path;
    await _moveLocalFile(file, dest);
    return dest.path;
  }

  Future<void> _moveLocalFile(File source, File dest) async {
    if (await dest.exists()) await dest.delete();
    try {
      await source.rename(dest.path);
    } on FileSystemException {
      await source.copy(dest.path);
      await source.delete();
    }
  }

  Future<void> _ensureWritable(String location) async {
    if (isContentUri(location)) {
      final probe = await _saf.writeFileBytes(
        location,
        '.podavio-write-test',
        'text/plain',
        Uint8List.fromList('ok'.codeUnits),
        overwrite: true,
      );
      await _deleteContent(probe.uri.toString());
      return;
    }
    final directory = Directory(location);
    try {
      await directory.create(recursive: true);
      final probe = File(p.join(directory.path, '.podavio-write-test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (_) {
      throw Exception('Impossible d’écrire dans ce dossier.');
    }
  }

  Future<void> _deleteContent(String uri) async {
    try {
      await _documents.delete(uri, false);
    } catch (_) {}
  }

  Future<void> _discardPartial(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  String _mime(Episode episode) {
    final mime = episode.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    return 'audio/mpeg';
  }

  Future<int> downloadBytesForPodcast(int podcastId) async {
    final items = await _database.episodesForPodcast(podcastId);
    var total = 0;
    for (final episode in items) {
      final path = episode.downloadPath;
      if (path == null) continue;
      total += await _storedLength(path);
    }
    return total;
  }

  Future<Map<int, int>> downloadBytesByPodcast() async {
    final items = await _database.downloadedEpisodes();
    final totals = <int, int>{};
    for (final episode in items) {
      final path = episode.downloadPath;
      if (path == null) continue;
      final length = await _storedLength(path);
      totals[episode.podcastId] = (totals[episode.podcastId] ?? 0) + length;
    }
    return totals;
  }

  Future<int> _storedLength(String path) async {
    try {
      if (isContentUri(path)) {
        final document = await _documents.documentFileFromUri(path, false);
        final length = document?.length ?? -1;
        return length > 0 ? length : 0;
      }
      final file = File(path);
      if (await file.exists()) return await file.length();
    } catch (_) {}
    return 0;
  }
}
