import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'app_database.dart';
import 'download_service.dart';
import 'providers.dart';

const automaticDatabaseBackupKey = 'automaticDatabaseBackup';
const automaticDatabaseBackupFolderKey = 'automaticDatabaseBackupFolder';
const lastAutomaticDatabaseBackupAtKey = 'lastAutomaticDatabaseBackupAt';

/// Intervalle AntennaPod : une sauvegarde tous les 3 jours.
const automaticBackupInterval = Duration(days: 3);

/// Rétention AntennaPod : 5 fichiers.
const automaticBackupKeepCount = 5;

const _backupPrefix = 'PodavioBackup-';
const _automaticBackupPrefix = 'PodavioAuto-';
const _backupSuffix = '.sqlite';

/// Incrémenté quand une sauvegarde automatique échoue hors de l’écran
/// qui l’a demandée. Le shell affiche alors un message.
final automaticBackupFailureProvider =
    NotifierProvider<AutomaticBackupFailureNotifier, int>(
      AutomaticBackupFailureNotifier.new,
    );

class AutomaticBackupFailureNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notifyFailure() => state = state + 1;
}

Future<File> podavioDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'podavio.sqlite'));
}

String databaseBackupFileName([DateTime? when]) {
  return '$_backupPrefix${_backupStamp(when ?? DateTime.now())}$_backupSuffix';
}

String automaticDatabaseBackupFileName([DateTime? when]) {
  return '$_automaticBackupPrefix${_backupStamp(when ?? DateTime.now())}$_backupSuffix';
}

String _backupStamp(DateTime stamp) {
  String two(int value) => value.toString().padLeft(2, '0');
  final year = stamp.year.toString().padLeft(4, '0');
  return '$year-${two(stamp.month)}-${two(stamp.day)}-'
      '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}';
}

const _databaseExportChannel = MethodChannel(
  'fr.podavio.podavio/database_export',
);

/// Taille d’un morceau envoyé au stockage Android. Reste très en dessous
/// de la limite du tas Java, contrairement au fichier entier.
const _backupChunkBytes = 256 * 1024;

/// Copie cohérente de la base (VACUUM INTO), sans fermer Drift.
///
/// Le fichier temporaire reste en place : l’appelant le supprime après
/// la copie. Il n’est pas lu en entier en mémoire.
Future<File> exportDatabaseFile(
  AppDatabase database, {
  Directory? directory,
}) async {
  final dir = directory ?? await getTemporaryDirectory();
  final temp = File(
    p.join(
      dir.path,
      'podavio-export-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ),
  );
  if (await temp.exists()) await temp.delete();
  final escaped = temp.path.replaceAll("'", "''");
  await database.customStatement('VACUUM INTO \'$escaped\'');
  return temp;
}

Future<void> deleteExportFile(File file) async {
  if (!await file.exists()) return;
  try {
    await file.delete();
  } catch (_) {}
}

/// Ouvre le dialogue « Enregistrer sous » et renvoie l’URI du document,
/// sans envoyer le contenu. Null si l’utilisateur annule.
Future<String?> pickDatabaseExportUri(String fileName) {
  return _databaseExportChannel.invokeMethod<String>('createDocument', {
    'fileName': fileName,
  });
}

/// Copie [bytes] vers un fichier temporaire, par morceaux.
Future<File> stageDatabaseStream(Stream<List<int>> bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(
      dir.path,
      'podavio-import-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ),
  );
  final sink = file.openWrite();
  try {
    await sink.addStream(bytes);
  } catch (error) {
    await sink.close();
    await deleteExportFile(file);
    rethrow;
  }
  await sink.close();
  return file;
}

/// Vérifie l’en-tête SQLite, puis remplace [destination] par une copie de [source].
Future<void> replaceDatabaseFile(File destination, File source) async {
  await _assertSqliteFile(source);
  final incoming = File('${destination.path}.incoming');
  if (await incoming.exists()) await incoming.delete();
  try {
    await source.copy(incoming.path);
    if (await destination.exists()) await destination.delete();
    await incoming.rename(destination.path);
  } catch (error) {
    await deleteExportFile(incoming);
    rethrow;
  }
}

Future<void> _assertSqliteFile(File source) async {
  final length = await source.length();
  if (length < 16) {
    throw StateError('File is too small to be a SQLite database.');
  }
  final input = await source.open();
  try {
    final bytes = await input.read(15);
    final header = String.fromCharCodes(bytes);
    if (!header.startsWith('SQLite format')) {
      throw StateError('Not a SQLite database.');
    }
  } finally {
    await input.close();
  }
}

/// Remplace la base ouverte par [source], puis rouvre les providers Drift.
///
/// [source] est copié sur le disque. Il n’est pas lu en entier en mémoire.
Future<void> importDatabaseFile(
  ProviderContainer container,
  File source,
) async {
  await _assertSqliteFile(source);
  await container.read(playerProvider.notifier).dismiss();

  final live = await podavioDatabaseFile();
  final database = container.read(databaseProvider);
  // Le routeur et le compagnon web gardent des watch ouverts. `close()`
  // attend ces lectures, comme `wal_checkpoint(TRUNCATE)`. On les coupe
  // avant de fermer, puis seulement on remplace le fichier.
  container.read(databasePhaseProvider.notifier).beginReplacement();
  try {
    try {
      container.read(databaseProvider);
      throw StateError('Database stayed open during replacement.');
    } on ProviderException catch (error) {
      // Les watch se désabonnent dans cette lecture.
      final cause = error.exception;
      if (cause is! StateError ||
          cause.message != 'Database is being replaced.') {
        rethrow;
      }
    }
    await closeAppDatabase(database);
    await replaceDatabaseFile(live, source);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final side = File('${live.path}$suffix');
      if (await side.exists()) await side.delete();
    }

    final fresh = AppDatabase.defaults();
    try {
      await forgetMissingLocalFiles(fresh);
    } finally {
      await closeAppDatabase(fresh);
    }
  } finally {
    container.read(databasePhaseProvider.notifier).finishReplacement();
    container.read(databaseProvider);
  }
}

/// Oublie les fichiers locaux absents. Un chemin encore présent est conservé.
/// Un `content://` qu’on ne peut pas vérifier est conservé.
Future<void> forgetMissingLocalFiles(AppDatabase database) async {
  final missingDownloads = <int>[];
  for (final file in await database.episodeDownloadFiles()) {
    if (!await storedFileExists(file.path)) missingDownloads.add(file.id);
  }
  await database.clearEpisodeDownloads(missingDownloads);

  final missingEpisodeImages = <int>[];
  for (final file in await database.episodeImageFiles()) {
    if (!await storedFileExists(file.path)) {
      missingEpisodeImages.add(file.id);
    }
  }
  await database.clearEpisodeImagePaths(missingEpisodeImages);

  final missingCovers = <int>[];
  for (final file in await database.podcastImageFiles()) {
    if (!await storedFileExists(file.path)) missingCovers.add(file.id);
  }
  await database.clearPodcastImagePaths(missingCovers);
}

Future<bool> storedFileExists(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  if (isContentUri(trimmed)) {
    if (!Platform.isAndroid) return true;
    try {
      return await SafUtil().exists(trimmed, false);
    } catch (_) {
      return true;
    }
  }
  return File(trimmed).exists();
}

Future<void> writeBackupFile(String folder, File source, String name) async {
  if (isContentUri(folder)) {
    final saf = SafStream();
    final info = await saf.startWriteStream(
      folder,
      name,
      'application/x-sqlite3',
      overwrite: true,
    );
    try {
      await _writeFileChunks(saf, info.session, source);
    } finally {
      await saf.endWriteStream(info.session);
    }
    return;
  }
  final directory = Directory(folder);
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, name));
  if (await file.exists()) await file.delete();
  await source.copy(file.path);
}

/// Écrit [source] dans le document déjà créé par le dialogue d’export.
Future<void> writeBackupToDocument(String uri, File source) async {
  final saf = SafStream();
  final info = await saf.startWriteFileUriStream(uri);
  try {
    await _writeFileChunks(saf, info.session, source);
  } finally {
    await saf.endWriteStream(info.session);
  }
}

Future<void> _writeFileChunks(
  SafStream saf,
  String session,
  File source,
) async {
  final input = await source.open();
  try {
    final buffer = Uint8List(_backupChunkBytes);
    while (true) {
      final read = await input.readInto(buffer);
      if (read <= 0) break;
      final chunk = Uint8List.fromList(buffer.sublist(0, read));
      await saf.writeChunk(session, chunk);
    }
  } finally {
    await input.close();
  }
}

Future<void> pruneAutomaticBackups(String folder) async {
  final names = await _listBackupNames(folder);
  if (names.length <= automaticBackupKeepCount) return;
  final sorted = [...names]..sort();
  final toDelete = sorted.take(names.length - automaticBackupKeepCount);
  for (final name in toDelete) {
    await _deleteBackup(folder, name);
  }
}

Future<List<String>> _listBackupNames(String folder) async {
  if (isContentUri(folder)) {
    final children = await SafUtil().list(folder);
    return [
      for (final child in children)
        if (!child.isDir && _isAutomaticBackupName(child.name)) child.name,
    ];
  }
  final directory = Directory(folder);
  if (!await directory.exists()) return const [];
  final names = <String>[];
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (_isAutomaticBackupName(name)) names.add(name);
  }
  return names;
}

Future<void> _deleteBackup(String folder, String name) async {
  if (isContentUri(folder)) {
    final children = await SafUtil().list(folder);
    for (final child in children) {
      if (!child.isDir && child.name == name) {
        await SafUtil().delete(child.uri, false);
        return;
      }
    }
    return;
  }
  final file = File(p.join(folder, name));
  if (await file.exists()) await file.delete();
}

bool _isAutomaticBackupName(String name) {
  return name.startsWith(_automaticBackupPrefix) &&
      name.endsWith(_backupSuffix);
}

/// Écrit une sauvegarde tout de suite et mémorise l’heure.
Future<void> performAutomaticDatabaseBackup({
  required AppDatabase database,
  required SharedPreferences preferences,
  required String folder,
}) async {
  final file = await exportDatabaseFile(database);
  try {
    await writeBackupFile(folder, file, automaticDatabaseBackupFileName());
  } finally {
    await deleteExportFile(file);
  }
  await pruneAutomaticBackups(folder);
  await preferences.setInt(
    lastAutomaticDatabaseBackupAtKey,
    DateTime.now().millisecondsSinceEpoch,
  );
}

/// Lance une sauvegarde auto si l’option est active et que l’intervalle est passé.
Future<void> maybeRunAutomaticDatabaseBackup(Ref ref) async {
  if (kIsWeb) return;
  final settings = ref.read(settingsProvider);
  if (!settings.automaticDatabaseBackup) return;
  final folder = settings.automaticDatabaseBackupFolder;
  if (folder == null || folder.isEmpty) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final lastMs = prefs.getInt(lastAutomaticDatabaseBackupAtKey);
  if (lastMs != null) {
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (DateTime.now().difference(last) < automaticBackupInterval) return;
  }

  try {
    await performAutomaticDatabaseBackup(
      database: ref.read(databaseProvider),
      preferences: prefs,
      folder: folder,
    );
  } catch (error, stack) {
    debugPrint('Automatic database backup failed: $error\n$stack');
    ref.read(automaticBackupFailureProvider.notifier).notifyFailure();
  }
}

/// Déclenché une fois au démarrage (via le shell).
final automaticDatabaseBackupProvider = Provider<void>((ref) {
  unawaited(maybeRunAutomaticDatabaseBackup(ref));
});
