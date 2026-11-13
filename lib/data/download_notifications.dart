import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_notifications.dart';

/// Un lot de téléchargements, affiché comme une seule notification.
class DownloadBatch {
  const DownloadBatch({
    required this.remaining,
    required this.progress,
    this.title,
    this.podcast,
    this.succeeded = 0,
    this.failed = 0,
    this.failureMessage,
  });

  /// Fichiers encore en cours ou en attente.
  final int remaining;

  /// Part déjà écrite du lot, entre 0 et 1.
  final double progress;

  /// Titre d’un épisode, quand le lot n’en contient qu’un.
  final String? title;
  final String? podcast;
  final int succeeded;
  final int failed;
  final String? failureMessage;
}

/// Notifications système des téléchargements. Les erreurs sont absorbées.
abstract class DownloadNotifications {
  Future<void> showProgress(DownloadBatch batch);

  Future<void> showFinished(DownloadBatch batch);

  Future<void> dismiss();
}

String downloadBatchProgressTitle(DownloadBatch batch) {
  if (batch.remaining == 1) {
    final title = _name(batch.title);
    if (title != null) return title;
  }
  return 'Téléchargements';
}

String downloadBatchProgressBody(DownloadBatch batch) {
  final percent = (batch.progress.clamp(0, 1) * 100).round();
  final podcast = _name(batch.podcast);
  final head = batch.remaining == 1 && podcast != null
      ? '$podcast · $percent %'
      : batch.remaining == 1
      ? '$percent %'
      : '${batch.remaining} épisodes · $percent %';
  if (batch.failed <= 0) return head;
  final failures = batch.failed == 1 ? '1 échec' : '${batch.failed} échecs';
  return '$head · $failures';
}

String downloadBatchOutcomeTitle(DownloadBatch batch) {
  if (batch.succeeded + batch.failed == 1) {
    final title = _name(batch.title);
    if (title != null) return title;
  }
  return 'Téléchargements';
}

String downloadBatchOutcomeBody(DownloadBatch batch) {
  final succeeded = batch.succeeded;
  final failed = batch.failed;
  if (failed <= 0) {
    if (succeeded == 1) {
      final title = _name(batch.title);
      final done = downloadFinishedBody(batch.podcast);
      if (title == null) return done;
      return '$title · $done';
    }
    return '$succeeded épisodes téléchargés';
  }
  if (succeeded <= 0) {
    if (failed != 1) return '$failed échecs';
    final message = _name(batch.failureMessage) ?? '1 échec';
    final title = _name(batch.title);
    if (title == null) return message;
    return '$title · $message';
  }
  final ok = succeeded == 1 ? '1 téléchargé' : '$succeeded téléchargés';
  final ko = failed == 1 ? '1 échec' : '$failed échecs';
  return '$ok, $ko';
}

String downloadFinishedBody(String? podcast) {
  final name = _name(podcast);
  if (name == null) return 'Téléchargé';
  return 'Téléchargé · $name';
}

String downloadErrorText(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  return text;
}

String? _name(String? value) {
  final name = value?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

class SystemDownloadNotifications implements DownloadNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _tail = Future<void>.value();
  Future<void>? _ready;

  @override
  Future<void> showProgress(DownloadBatch batch) {
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: _outcomeId);
      await _plugin.show(
        id: _progressId,
        title: downloadBatchProgressTitle(batch),
        body: downloadBatchProgressBody(batch),
        notificationDetails: _progressDetails(batch),
      );
    });
  }

  @override
  Future<void> showFinished(DownloadBatch batch) {
    final failedOnly = batch.succeeded <= 0 && batch.failed > 0;
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: _progressId);
      await _plugin.show(
        id: _outcomeId,
        title: downloadBatchOutcomeTitle(batch),
        body: downloadBatchOutcomeBody(batch),
        notificationDetails: _outcomeDetails(
          androidCategory: failedOnly
              ? AndroidNotificationCategory.error
              : AndroidNotificationCategory.status,
          linuxCategory: failedOnly
              ? LinuxNotificationCategory.transferError
              : LinuxNotificationCategory.transferComplete,
        ),
      );
    });
  }

  @override
  Future<void> dismiss() {
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: _progressId);
      await _plugin.cancel(id: _outcomeId);
    });
  }

  Future<void> _run(Future<void> Function() action) {
    final next = _tail.then((_) async {
      try {
        await action();
      } catch (error, stack) {
        debugPrint('Notification de téléchargement ignorée: $error\n$stack');
      }
    });
    _tail = next;
    return next;
  }

  Future<void> _ensureReady() {
    return _ready ??= _prepare();
  }

  Future<void> _prepare() async {
    await initializePodavioNotifications(_plugin);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }
}

const _progressChannel = 'podavio_downloads';
const _doneChannel = 'podavio_downloads_done';
const _progressId = 1400000100;
const _outcomeId = 1400000101;

NotificationDetails _progressDetails(DownloadBatch batch) {
  final progress = batch.progress.clamp(0, 1).toDouble();
  final percent = (progress * 100).round();
  final body = downloadBatchProgressBody(batch);
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _progressChannel,
      'Téléchargements',
      channelDescription: 'Progression des téléchargements d’épisodes',
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.progress,
      icon: 'ic_notification',
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      indeterminate: false,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      silent: true,
      channelShowBadge: false,
    ),
    iOS: const DarwinNotificationDetails(
      presentBanner: false,
      presentList: true,
      presentSound: false,
      presentBadge: false,
      threadIdentifier: _progressChannel,
    ),
    macOS: const DarwinNotificationDetails(
      presentBanner: false,
      presentList: true,
      presentSound: false,
      presentBadge: false,
      threadIdentifier: _progressChannel,
    ),
    linux: LinuxNotificationDetails(
      category: LinuxNotificationCategory.transfer,
      urgency: LinuxNotificationUrgency.low,
      suppressSound: true,
      resident: true,
      timeout: const LinuxNotificationTimeout.expiresNever(),
    ),
    windows: WindowsNotificationDetails(
      audio: WindowsNotificationAudio.silent(),
      subtitle: body,
      progressBars: [
        WindowsProgressBar(id: 'download', status: body, value: progress),
      ],
    ),
  );
}

NotificationDetails _outcomeDetails({
  required AndroidNotificationCategory androidCategory,
  required LinuxNotificationCategory linuxCategory,
}) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _doneChannel,
      'Téléchargements terminés',
      channelDescription: 'Fin ou échec d’un téléchargement d’épisode',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: androidCategory,
      icon: 'ic_notification',
      autoCancel: true,
    ),
    iOS: const DarwinNotificationDetails(
      presentBanner: true,
      presentList: true,
      presentSound: true,
      presentBadge: false,
      threadIdentifier: _doneChannel,
    ),
    macOS: const DarwinNotificationDetails(
      presentBanner: true,
      presentList: true,
      presentSound: true,
      presentBadge: false,
      threadIdentifier: _doneChannel,
    ),
    linux: LinuxNotificationDetails(
      category: linuxCategory,
      urgency: LinuxNotificationUrgency.normal,
    ),
  );
}
