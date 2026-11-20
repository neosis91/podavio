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
import 'download_resume.dart';
import 'feed_service.dart';
import 'http_auth.dart';
import 'playback_file.dart';

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
  DownloadService(this._database, {this.partials});

  final AppDatabase _database;
  final Directory? partials;
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
    if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
    final location = await resolveDownloadDirectory(directory);
    final podcast = await _database.getPodcast(episode.podcastId);
    final stored = await _database.episodeById(episode.id) ?? episode;
    final cache = await _readyCacheFile(stored);
    if (cache != null) {
      await _promoteCache(
        episode: stored,
        podcast: podcast,
        cache: cache,
        location: location,
        onProgress: onProgress,
      );
      await forgetPartials([stored.id]);
      return;
    }
    final name = downloadFileName(
      podcastTitle: podcast?.title ?? '',
      episodeTitle: episode.title,
      extension: audioExtension(episode.mimeType, episode.audioUrl),
    );
    final client = http.Client();
    _clients[episode.id] = client;
    final partial = await _partialFile(episode.id);
    String? published;
    try {
      final headers = podcastRequestHeaders(
        userAgent: podavioUserAgent,
        username: podcast?.authUsername,
        password: podcast?.authPassword,
      );
      await _downloadToPartial(
        client: client,
        episode: episode,
        headers: headers,
        partial: partial,
        onProgress: onProgress,
      );
      if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
      published = await _publishPartial(
        partial: partial,
        location: location,
        name: name,
        episode: episode,
      );
      await _commitDownload(
        episode: episode,
        podcast: podcast,
        path: published,
      );
      published = null;
      await _forgetPartial(partial);
    } catch (error) {
      if (published != null) await _deletePublished(published);
      if (_cancelled.contains(episode.id) || error is DownloadCancelled) {
        await _forgetPartial(partial);
        throw const DownloadCancelled();
      }
      if (await _partialLength(partial) == 0) await _forgetPartial(partial);
      rethrow;
    } finally {
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
    await _forgetPartial(await _partialFile(episode.id));
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
    } else {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _deletePlaybackCache(path);
  }

  /// Fichier que le lecteur peut ouvrir sans réseau ni Wi-Fi.
  ///
  /// Un chemin disque est renvoyé tel quel, même si un contrôle d’existence
  /// échouerait. Un `content://` est copié dans le cache de l’application :
  /// le lecteur ne sait pas relire ces URI de façon fiable, et les réécrire
  /// en `Uri` peut les casser.
  Future<String?> readablePlaybackPath(String downloadPath) async {
    final direct = filesystemPlaybackPath(downloadPath);
    if (direct != null) return direct;
    final uri = downloadPath.trim();
    if (!isContentUri(uri)) return null;
    try {
      final cache = await _playbackCacheDirectory();
      return await cachedPlaybackFile(
        source: uri,
        cacheDirectory: cache,
        copy: (source, dest) => _saf.copyToLocalFile(source, dest),
        sourceLength: _contentLength,
      );
    } catch (_) {
      return null;
    }
  }

  /// Deuxième essai : copie vers un nom simple quand le chemin d’origine
  /// est refusé par le décodeur (espaces, crochets, accents).
  Future<String?> copyLocalFileForPlayback(String sourcePath) async {
    if (isPlaybackCacheFile(sourcePath)) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    try {
      final cache = await _playbackCacheDirectory();
      return await cachedPlaybackFile(
        source: sourcePath,
        cacheDirectory: cache,
        copy: (from, dest) async {
          await File(from).copy(dest);
        },
        sourceLength: (from) => File(from).length(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fichier de cache complet, s’il existe. Un `.part` ne compte pas.
  Future<File?> _readyCacheFile(Episode episode) async {
    final recorded = episode.cachePath?.trim() ?? '';
    if (recorded.isNotEmpty && !recorded.endsWith('.part')) {
      final file = File(recorded);
      if (await file.exists() && await file.length() > 0) return file;
    }
    try {
      final expected = await streamCacheFileFor(episode.id, episode.audioUrl);
      if (await expected.exists() && await expected.length() > 0) {
        return expected;
      }
    } catch (_) {}
    return null;
  }

  /// Copie le cache vers le dossier des téléchargements, sous le nom habituel,
  /// puis l’oublie comme cache. Aucune requête vers l’épisode.
  Future<void> _promoteCache({
    required Episode episode,
    required Podcast? podcast,
    required File cache,
    required String location,
    void Function(double progress)? onProgress,
  }) async {
    if (_cancelled.contains(episode.id)) throw const DownloadCancelled();
    final name = downloadFileName(
      podcastTitle: podcast?.title ?? '',
      episodeTitle: episode.title,
      extension: audioExtension(episode.mimeType, episode.audioUrl),
    );
    final String storedPath;
    if (isContentUri(location)) {
      final created = await _saf.pasteLocalFile(
        cache.path,
        location,
        name,
        _mime(episode),
        overwrite: true,
      );
      storedPath = created.uri.toString();
    } else {
      final folder = Directory(location);
      await folder.create(recursive: true);
      final dest = File(p.join(folder.path, name));
      if (!sameDownloadLocation(cache.path, dest.path)) {
        await _moveLocalFile(cache, dest);
      }
      storedPath = dest.path;
    }
    await _commitDownload(episode: episode, podcast: podcast, path: storedPath);
    onProgress?.call(1);
  }

  Future<void> _commitDownload({
    required Episode episode,
    required Podcast? podcast,
    required String path,
  }) async {
    await _database.setDownloadPath(episode.id, path);
    final current = await _database.episodeById(episode.id);
    final cachePath = current?.cachePath?.trim() ?? '';
    if (cachePath.isNotEmpty && sameDownloadLocation(cachePath, path)) {
      await _database.setCachePath(episode.id, null);
    } else if (cachePath.isNotEmpty) {
      await forgetStreamCache(episode.id);
    }
    if (podcast == null) return;
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

  /// Emplacement du fichier gardé pendant le streaming de [episodeId].
  Future<File> streamCacheFileFor(int episodeId, String audioUrl) async {
    final support = await getApplicationSupportDirectory();
    final file = streamCacheFile(support, episodeId, audioUrl);
    await file.parent.create(recursive: true);
    return file;
  }

  /// Retient le fichier s’il est complet et que l’épisode n’est pas téléchargé.
  Future<void> rememberStreamCache(int episodeId, String path) async {
    final episode = await _database.episodeById(episodeId);
    if (episode == null) return;
    final download = episode.downloadPath?.trim() ?? '';
    if (download.isNotEmpty) return;
    if (episode.cachePath == path) return;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return;
    await _database.setCachePath(episodeId, path);
  }

  /// Efface le fichier de streaming et l’oublie. Un téléchargement n’est pas touché.
  Future<void> forgetStreamCache(int episodeId) async {
    final episode = await _database.episodeById(episodeId);
    final path = episode?.cachePath?.trim() ?? '';
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final mime = File('$path.mime');
      if (await mime.exists()) {
        try {
          await mime.delete();
        } catch (_) {}
      }
    }
    if (episode != null) await _database.setCachePath(episodeId, null);
  }

  Future<Directory> _playbackCacheDirectory() async {
    final root = await getTemporaryDirectory();
    return Directory(p.join(root.path, playbackCacheFolder));
  }

  Future<void> _deletePlaybackCache(String source) async {
    try {
      final cache = await _playbackCacheDirectory();
      final file = File(p.join(cache.path, playbackCacheName(source)));
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<int?> _contentLength(String uri) async {
    final document = await _documents.documentFileFromUri(uri, false);
    final length = document?.length ?? -1;
    if (length <= 0) return null;
    return length;
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

  /// Efface les morceaux de ces épisodes. Rien n’est fait s’ils n’existent pas.
  Future<void> forgetPartials(Iterable<int> episodeIds) async {
    try {
      for (final id in episodeIds) {
        await _forgetPartial(await _partialFile(id));
      }
    } catch (_) {}
  }

  Future<Directory> _partialDirectory() async {
    final root = partials ?? await getApplicationSupportDirectory();
    final folder = Directory(p.join(root.path, 'download-partials'));
    await folder.create(recursive: true);
    return folder;
  }

  Future<File> _partialFile(int episodeId) async {
    final folder = await _partialDirectory();
    return File(p.join(folder.path, '$episodeId.part'));
  }

  Future<int> _partialLength(File partial) async {
    if (!await partial.exists()) return 0;
    return partial.length();
  }

  /// Garde l’adresse et l’identité du fichier. Une autre adresse repart de zéro.
  Future<({int length, String? validator})> _openPartial(
    File partial,
    String audioUrl,
  ) async {
    final marker = File('${partial.path}.url');
    final previous = await _readPartialMark(marker);
    if (previous.url.isNotEmpty &&
        previous.url != audioUrl &&
        await partial.exists()) {
      await partial.delete();
      if (await marker.exists()) await marker.delete();
    }
    if (previous.url != audioUrl) {
      await _writePartialMark(partial, audioUrl, null);
      return (length: await _partialLength(partial), validator: null);
    }
    return (
      length: await _partialLength(partial),
      validator: previous.validator,
    );
  }

  Future<({String url, String? validator})> _readPartialMark(
    File marker,
  ) async {
    if (!await marker.exists()) return (url: '', validator: null);
    final lines = (await marker.readAsString()).split('\n');
    final url = lines.isEmpty ? '' : lines.first;
    final validator = lines.length > 1 && lines[1].isNotEmpty ? lines[1] : null;
    return (url: url, validator: validator);
  }

  Future<void> _writePartialMark(
    File partial,
    String audioUrl,
    String? validator,
  ) async {
    final marker = File('${partial.path}.url');
    await marker.parent.create(recursive: true);
    await marker.writeAsString('$audioUrl\n${validator ?? ''}\n');
  }

  Future<void> _forgetPartial(File partial) async {
    if (await partial.exists()) {
      try {
        await partial.delete();
      } catch (_) {}
    }
    final marker = File('${partial.path}.url');
    if (await marker.exists()) {
      try {
        await marker.delete();
      } catch (_) {}
    }
  }

  Future<http.StreamedResponse> _sendAudio(
    http.Client client,
    Episode episode,
    Map<String, String> headers,
    int offset,
    String? validator,
  ) {
    final request = http.Request('GET', Uri.parse(episode.audioUrl));
    request.headers.addAll(headers);
    if (offset > 0) {
      request.headers['Range'] = 'bytes=$offset-';
      if (validator != null && validator.isNotEmpty) {
        request.headers['If-Range'] = validator;
      }
    }
    if (headers.containsKey('Authorization')) {
      request.followRedirects = false;
      return sendKeepingAuthorization(client, request);
    }
    return client.send(request);
  }

  Future<void> _downloadToPartial({
    required http.Client client,
    required Episode episode,
    required Map<String, String> headers,
    required File partial,
    required void Function(double progress)? onProgress,
  }) async {
    final opened = await _openPartial(partial, episode.audioUrl);
    var offset = opened.length;
    var validator = opened.validator;
    final resumedFrom = offset;
    var response = await _sendAudio(
      client,
      episode,
      headers,
      offset,
      validator,
    );
    var plan = planDownloadBody(
      statusCode: response.statusCode,
      partialBytes: offset,
      contentLength: response.contentLength,
      contentRange: response.headers['content-range'],
    );
    if (plan.mode == DownloadBodyMode.restart) {
      await response.stream.drain<void>();
      response = await _sendAudio(client, episode, headers, 0, null);
      plan = planDownloadBody(
        statusCode: response.statusCode,
        partialBytes: 0,
        contentLength: response.contentLength,
        contentRange: response.headers['content-range'],
      );
      offset = 0;
      validator = null;
    }
    if (plan.mode == DownloadBodyMode.complete) {
      await response.stream.drain<void>();
      if (plan.total > 0) onProgress?.call(1);
      return;
    }
    if (plan.mode == DownloadBodyMode.restart) {
      await response.stream.drain<void>();
      throw Exception('Téléchargement impossible (${response.statusCode}).');
    }
    final nextValidator = downloadValidator(response.headers);
    final changed =
        resumedFrom > 0 &&
        validator != null &&
        nextValidator != null &&
        validator != nextValidator;
    if (changed && plan.mode == DownloadBodyMode.append) {
      await response.stream.drain<void>();
      response = await _sendAudio(client, episode, headers, 0, null);
      plan = planDownloadBody(
        statusCode: response.statusCode,
        partialBytes: 0,
        contentLength: response.contentLength,
        contentRange: response.headers['content-range'],
      );
      offset = 0;
    }
    await _rejectFailed(response);
    await _writePartial(
      episodeId: episode.id,
      partial: partial,
      audioUrl: episode.audioUrl,
      validator: downloadValidator(response.headers) ?? validator,
      preferIncoming: changed,
      response: response,
      plan: plan,
      onProgress: onProgress,
    );
  }

  Future<void> _rejectFailed(http.StreamedResponse response) async {
    final status = response.statusCode;
    if (status == 401) {
      await response.stream.drain<void>();
      throw Exception(
        'Téléchargement refusé. Vérifiez l’identifiant dans les paramètres du podcast.',
      );
    }
    if (status >= 200 && status < 300) return;
    await response.stream.drain<void>();
    throw Exception('Téléchargement impossible ($status).');
  }

  Future<void> _writePartial({
    required int episodeId,
    required File partial,
    required String audioUrl,
    required String? validator,
    required bool preferIncoming,
    required http.StreamedResponse response,
    required DownloadBodyPlan plan,
    required void Function(double progress)? onProgress,
  }) async {
    final replacing = plan.mode == DownloadBodyMode.replace;
    final target = replacing ? File('${partial.path}.incoming') : partial;
    if (replacing && await target.exists()) await target.delete();
    final sink = target.openWrite(
      mode: replacing ? FileMode.write : FileMode.append,
    );
    var received = plan.already;
    var sinceFlush = 0;
    var closed = false;
    try {
      if (plan.total > 0 && received > 0) {
        onProgress?.call(received / plan.total);
      }
      await for (final chunk in response.stream) {
        if (_cancelled.contains(episodeId)) throw const DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        sinceFlush += chunk.length;
        if (plan.total > 0) {
          final fraction = received / plan.total;
          onProgress?.call(fraction > 1 ? 1 : fraction);
        }
        if (sinceFlush >= 256 * 1024) {
          await sink.flush();
          sinceFlush = 0;
        }
      }
      await sink.flush();
      await sink.close();
      closed = true;
      final length = await _partialLength(target);
      if (plan.total > 0 && length != plan.total) {
        throw Exception('Téléchargement interrompu.');
      }
      if (replacing) await _moveLocalFile(target, partial);
      await _writePartialMark(partial, audioUrl, validator);
    } catch (_) {
      if (!closed) {
        try {
          await sink.close();
        } catch (_) {}
        closed = true;
      }
      if (replacing) {
        final length = await _partialLength(target);
        if (plan.total > 0 && length > plan.total) {
          if (await target.exists()) await target.delete();
        } else if (preferIncoming) {
          await _preferIncoming(target, partial);
          if (await partial.exists()) {
            await _writePartialMark(partial, audioUrl, validator);
          }
        } else {
          await _keepLongerPartial(target, partial);
        }
      } else if (plan.total > 0 && await _partialLength(partial) > plan.total) {
        await _forgetPartial(partial);
      }
      rethrow;
    } finally {
      if (!closed) await sink.close();
    }
  }

  /// Le nouveau fichier remplace l’ancien, même s’il est encore plus court.
  Future<void> _preferIncoming(File incoming, File partial) async {
    final incomingLength = await _partialLength(incoming);
    try {
      if (incomingLength > 0) {
        await _moveLocalFile(incoming, partial);
      } else {
        if (await incoming.exists()) await incoming.delete();
        await _forgetPartial(partial);
      }
    } catch (_) {}
  }

  /// Garde le préfixe le plus long quand une réponse complète s’interrompt.
  Future<void> _keepLongerPartial(File incoming, File partial) async {
    final incomingLength = await _partialLength(incoming);
    final kept = await _partialLength(partial);
    try {
      if (incomingLength > kept) {
        await _moveLocalFile(incoming, partial);
      } else if (await incoming.exists()) {
        await incoming.delete();
      }
    } catch (_) {}
  }

  Future<String> _publishPartial({
    required File partial,
    required String location,
    required String name,
    required Episode episode,
  }) async {
    if (isContentUri(location)) {
      final created = await _saf.pasteLocalFile(
        partial.path,
        location,
        name,
        _mime(episode),
        overwrite: true,
      );
      return created.uri.toString();
    }
    final folder = Directory(location);
    await folder.create(recursive: true);
    final dest = File(p.join(folder.path, name));
    if (await dest.exists()) await dest.delete();
    await partial.copy(dest.path);
    return dest.path;
  }

  Future<void> _deletePublished(String path) async {
    if (isContentUri(path)) {
      await _deleteContent(path);
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
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
