import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

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
const _backupSuffix = '.sqlite';

Future<File> podavioDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'podavio.sqlite'));
}

String databaseBackupFileName([DateTime? when]) {
  final stamp = when ?? DateTime.now();
  final y = stamp.year.toString().padLeft(4, '0');
  final m = stamp.month.toString().padLeft(2, '0');
  final d = stamp.day.toString().padLeft(2, '0');
  return '$_backupPrefix$y-$m-$d$_backupSuffix';
}

/// Copie cohérente de la base (VACUUM INTO), sans fermer Drift.
Future<Uint8List> exportDatabaseBytes(AppDatabase database) async {
  final tempDir = await getTemporaryDirectory();
  final temp = File(
    p.join(tempDir.path, 'podavio-export-${DateTime.now().microsecondsSinceEpoch}.sqlite'),
  );
  if (await temp.exists()) await temp.delete();
  final escaped = temp.path.replaceAll("'", "''");
  try {
    await database.customStatement('VACUUM INTO \'$escaped\'');
    return await temp.readAsBytes();
  } finally {
    if (await temp.exists()) {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }
}

/// Remplace la base ouverte par [bytes], puis invalide les providers Drift.
Future<void> importDatabaseBytes(
  ProviderContainer container,
  Uint8List bytes,
) async {
  if (bytes.length < 16) {
    throw StateError('File is too small to be a SQLite database.');
  }
  final header = String.fromCharCodes(bytes.take(15));
  if (!header.startsWith('SQLite format')) {
    throw StateError('Not a SQLite database.');
  }

  await container.read(playerProvider.notifier).dismiss();

  final live = await podavioDatabaseFile();
  final database = container.read(databaseProvider);
  // Pas de wal_checkpoint ici : le parcours d’accueil garde un watch ouvert,
  // et TRUNCATE attendrait ce lecteur sans jamais finir.
  await closeAppDatabase(database);

  await live.writeAsBytes(bytes, flush: true);
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final side = File('${live.path}$suffix');
    if (await side.exists()) await side.delete();
  }

  container.invalidate(databaseProvider);
  // Recreate immediately so dependents reopen a live connection.
  container.read(databaseProvider);
}

Future<void> writeBackupBytes(String folder, Uint8List bytes, String name) async {
  if (isContentUri(folder)) {
    await SafStream().writeFileBytes(
      folder,
      name,
      'application/x-sqlite3',
      bytes,
      overwrite: true,
    );
    return;
  }
  final directory = Directory(folder);
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(bytes, flush: true);
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
        if (!child.isDir &&
            child.name.startsWith(_backupPrefix) &&
            child.name.endsWith(_backupSuffix))
          child.name,
    ];
  }
  final directory = Directory(folder);
  if (!await directory.exists()) return const [];
  final names = <String>[];
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name.startsWith(_backupPrefix) && name.endsWith(_backupSuffix)) {
      names.add(name);
    }
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
    final bytes = await exportDatabaseBytes(ref.read(databaseProvider));
    final name = databaseBackupFileName();
    await writeBackupBytes(folder, bytes, name);
    await pruneAutomaticBackups(folder);
    await prefs.setInt(
      lastAutomaticDatabaseBackupAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (error, stack) {
    debugPrint('Automatic database backup failed: $error\n$stack');
  }
}

/// Déclenché une fois au démarrage (via le shell).
final automaticDatabaseBackupProvider = Provider<void>((ref) {
  unawaited(maybeRunAutomaticDatabaseBackup(ref));
});
