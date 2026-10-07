import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Avis affiché pendant ou après le téléchargement d’un épisode.
class DownloadNotice {
  const DownloadNotice({
    required this.episodeId,
    required this.title,
    this.podcast,
    this.progress,
  });

  final int episodeId;
  final String title;
  final String? podcast;

  /// `null` : longueur inconnue. Sinon entre 0 et 1.
  final double? progress;
}

/// Notifications système des téléchargements. Les erreurs sont absorbées.
abstract class DownloadNotifications {
  Future<void> showProgress(DownloadNotice notice);

  Future<void> showFinished(DownloadNotice notice);

  Future<void> showFailed(DownloadNotice notice, String message);

  Future<void> dismiss(int episodeId);
}

String downloadProgressBody(DownloadNotice notice) {
  final podcast = _podcastName(notice.podcast);
  final progress = notice.progress;
  if (progress == null) {
    return podcast ?? 'Téléchargement…';
  }
  final percent = (progress.clamp(0, 1) * 100).round();
  if (podcast == null) return '$percent %';
  return '$podcast · $percent %';
}

String downloadFinishedBody(String? podcast) {
  final name = _podcastName(podcast);
  if (name == null) return 'Téléchargé';
  return 'Téléchargé · $name';
}

String downloadErrorText(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  return text;
}

String? _podcastName(String? podcast) {
  final name = podcast?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

class SystemDownloadNotifications implements DownloadNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _tail = Future<void>.value();
  Future<void>? _ready;

  @override
  Future<void> showProgress(DownloadNotice notice) {
    return _run(() async {
      await _ensureReady();
      await _plugin.show(
        id: notice.episodeId,
        title: notice.title,
        body: downloadProgressBody(notice),
        notificationDetails: _progressDetails(notice),
      );
    });
  }

  @override
  Future<void> showFinished(DownloadNotice notice) {
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: notice.episodeId);
      await _plugin.show(
        id: notice.episodeId,
        title: notice.title,
        body: downloadFinishedBody(notice.podcast),
        notificationDetails: _outcomeDetails(
          androidCategory: AndroidNotificationCategory.status,
          linuxCategory: LinuxNotificationCategory.transferComplete,
        ),
      );
    });
  }

  @override
  Future<void> showFailed(DownloadNotice notice, String message) {
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: notice.episodeId);
      await _plugin.show(
        id: notice.episodeId,
        title: notice.title,
        body: message,
        notificationDetails: _outcomeDetails(
          androidCategory: AndroidNotificationCategory.error,
          linuxCategory: LinuxNotificationCategory.transferError,
        ),
      );
    });
  }

  @override
  Future<void> dismiss(int episodeId) {
    return _run(() async {
      await _ensureReady();
      await _plugin.cancel(id: episodeId);
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
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Ouvrir'),
      windows: WindowsInitializationSettings(
        appName: 'Podavio',
        appUserModelId: 'fr.podavio.podavio',
        guid: '8f3c2a91-6d4e-4b7a-9c15-2e6f0a8b4d31',
      ),
    );
    await _plugin.initialize(settings: settings);
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

NotificationDetails _progressDetails(DownloadNotice notice) {
  final progress = notice.progress;
  final percent = progress == null ? 0 : (progress.clamp(0, 1) * 100).round();
  final body = downloadProgressBody(notice);
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
      indeterminate: progress == null,
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
