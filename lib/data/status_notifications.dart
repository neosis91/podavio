import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/interface_locale.dart';
import '../l10n/messages.dart';
import '../settings/settings_controller.dart';
import 'activity_messages.dart';
import 'local_notifications.dart';
import 'models.dart';

/// Annonces hors du téléchargement : nouveaux épisodes, échec de synchro.
abstract class StatusNotifications {
  Future<void> showNewEpisodes({required String body, required String title});

  Future<void> showSyncError(String message);
}

class SystemStatusNotifications implements StatusNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  @override
  Future<void> showNewEpisodes({required String body, required String title}) {
    return _show(
      id: 1500000000,
      title: title,
      body: body,
      channelId: 'podavio_new_episodes',
      channelName: 'Nouveaux épisodes',
      channelDescription: 'Un abonnement vient de publier',
    );
  }

  @override
  Future<void> showSyncError(String message) {
    return _show(
      id: 1900000001,
      title: 'Synchronisation',
      body: message,
      channelId: 'podavio_sync_errors',
      channelName: 'Erreurs de synchronisation',
      channelDescription: 'La synchronisation n’a pas abouti',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      await (_ready ??= _prepare());
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_notification',
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(threadIdentifier: channelId),
          macOS: DarwinNotificationDetails(threadIdentifier: channelId),
          linux: LinuxNotificationDetails(
            category: LinuxNotificationCategory.imReceived,
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('Notification ignorée: $error\n$stack');
    }
  }

  Future<void> _prepare() {
    return initializePodavioNotifications(_plugin);
  }
}

/// Une seule annonce pour toute une actualisation, reprise dans la page.
Future<void> announceNewEpisodes(
  StatusNotifications notifications,
  AppSettings settings,
  List<NewEpisodeArrival> arrivals,
  ActivityMessagesNotifier messages,
) async {
  if (arrivals.isEmpty) return;
  final body = newEpisodesNotificationBody(settings, arrivals);
  messages.add(body);
  await notifications.showNewEpisodes(
    title: notificationText(settings, 'New episodes'),
    body: body,
  );
}

/// Au plus douze podcasts : au-delà, la notification resterait un pavé.
String newEpisodesNotificationBody(
  AppSettings settings,
  List<NewEpisodeArrival> arrivals,
) {
  final shown = arrivals.take(12);
  return [for (final arrival in shown) _oneArrival(settings, arrival)]
      .join('\n');
}

String _oneArrival(AppSettings settings, NewEpisodeArrival arrival) {
  final key = arrival.count == 1
      ? '1 new episode from {podcast}'
      : '{count} new episodes from {podcast}';
  return notificationText(settings, key, {
    'podcast': arrival.title,
    'count': '${arrival.count}',
  });
}

/// Texte d’une notification, dans la langue de l’interface.
String notificationText(
  AppSettings settings,
  String key, [
  Map<String, String>? params,
]) {
  final code = resolveInterfaceLocale(
    stored: settings.interfaceLanguage,
    system: WidgetsBinding.instance.platformDispatcher.locale,
  ).languageCode;
  var text = code == 'en' ? key : (interfaceMessages[code]?[key] ?? key);
  if (params != null) {
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
  }
  return text;
}
