import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache partagé des jaquettes : une URL = un seul téléchargement.
class CoverCache {
  CoverCache._();

  /// Taille max utilisée pour le décodage mémoire des grandes jaquettes.
  static const maxMemPixels = 800;

  static final CacheManager manager = CacheManager(
    Config(
      'podavioCovers',
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 800,
    ),
  );

  static Future<void> prefetch(Iterable<String?> urls) async {
    final seen = <String>{};
    final pending = <Future<void>>[];
    for (final url in urls) {
      final value = url?.trim();
      if (value == null || value.isEmpty || !seen.add(value)) continue;
      pending.add(
        manager.downloadFile(value).then<void>((_) {}).catchError((_) {}),
      );
    }
    if (pending.isEmpty) return;
    await Future.wait(pending);
  }
}
