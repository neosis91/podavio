import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'download_controller.dart';
import 'download_policy.dart';
import 'online_status.dart';
import 'providers.dart';

var _running = false;
var _again = false;

final automaticDownloadRunProvider =
    NotifierProvider<AutomaticDownloadRun, void>(AutomaticDownloadRun.new);

/// Point d’entrée depuis un widget. Le [Ref] du provider lance le passage.
class AutomaticDownloadRun extends Notifier<void> {
  @override
  void build() {}

  Future<void> run() => runAutomaticDownloads(ref);
}

/// Applique [decideAutomaticDownloads] et enfile les fichiers.
///
/// Un appel pendant un passage est rejoué une fois à la fin. Sur les données
/// mobiles refusées, rien n’est effacé ni téléchargé.
Future<void> runAutomaticDownloads(Ref ref) async {
  if (_running) {
    _again = true;
    return;
  }
  _running = true;
  try {
    do {
      _again = false;
      await _runOnce(ref);
    } while (_again && ref.mounted);
  } finally {
    _running = false;
  }
}

Future<void> _runOnce(Ref ref) async {
  if (!ref.mounted) return;
  final settings = ref.read(settingsProvider);
  final onMobile = await ref.read(mobileDataProbeProvider)();
  if (!ref.mounted) return;
  if (mobileDataBlocksDownload(
    allowMobileData: settings.allowMobileData,
    mobileDataActive: onMobile,
  )) {
    return;
  }

  final database = ref.read(databaseProvider);
  final incoming = await database.automaticDownloadCandidates();
  final cached = await database.cachedLocalDownloads();
  if (!ref.mounted) return;
  final fresh = ref.read(settingsProvider);
  final decision = decideAutomaticDownloads(
    enabled: true,
    cacheSize: fresh.episodeCacheSize,
    cleanup: fresh.episodeCacheCleanup,
    incoming: incoming,
    cached: cached,
    now: DateTime.now(),
  );
  final downloads = ref.read(downloadProgressProvider.notifier);
  for (final id in decision.deleteIds) {
    if (!ref.mounted) return;
    final episode = await database.episodeById(id);
    if (episode == null) continue;
    await downloads.deleteDownload(episode);
  }
  for (final id in decision.downloadIds) {
    if (!ref.mounted) return;
    final episode = await database.episodeById(id);
    if (episode == null) continue;
    unawaited(
      downloads
          .download(episode, automatic: true)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
}
