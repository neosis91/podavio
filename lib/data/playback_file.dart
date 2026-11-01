import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/format.dart';

/// Dossier de cache pour les fichiers que le lecteur ne peut pas ouvrir
/// directement (URI `content://`, ou chemin refusé par le décodeur).
const playbackCacheFolder = 'podavio-playback';

/// Chemin disque d’un téléchargement, ou `null` pour un URI `content://`
/// ou une valeur vide. Ne teste pas l’existence du fichier : un contrôle
/// qui échoue ne doit pas renvoyer la lecture vers internet.
String? filesystemPlaybackPath(String? downloadPath) {
  final path = downloadPath?.trim();
  if (path == null || path.isEmpty || path.startsWith('content://')) {
    return null;
  }
  if (path.startsWith('file://')) return Uri.parse(path).toFilePath();
  return path;
}

bool isPlaybackCacheFile(String path) {
  return p.split(path).contains(playbackCacheFolder);
}

/// Nom stable, sans caractères spéciaux, pour une copie lisible hors ligne.
String playbackCacheName(String source) {
  final extension = audioExtension(null, source);
  return '${_fnv1a32(source).toRadixString(16)}$extension';
}

/// Copie [source] dans [cacheDirectory] si besoin, puis renvoie ce fichier.
///
/// Une copie déjà présente et de la même taille est réutilisée. [sourceLength]
/// à `null` ou `<= 0` signifie « taille inconnue » : la copie existante reste.
Future<String> cachedPlaybackFile({
  required String source,
  required Directory cacheDirectory,
  required Future<void> Function(String source, String destPath) copy,
  Future<int?> Function(String source)? sourceLength,
}) async {
  await cacheDirectory.create(recursive: true);
  final dest = File(p.join(cacheDirectory.path, playbackCacheName(source)));
  final expected = sourceLength == null ? null : await sourceLength(source);
  if (await dest.exists()) {
    final size = await dest.length();
    if (size > 0 && (expected == null || expected <= 0 || size == expected)) {
      return dest.path;
    }
    await dest.delete();
  }
  await copy(source, dest.path);
  if (!await dest.exists() || await dest.length() == 0) {
    throw StateError('Fichier de lecture vide');
  }
  return dest.path;
}

int _fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
