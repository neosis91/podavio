import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Réglages de plateforme communs aux avis de téléchargement et de statut.
/// Les canaux et les demandes de permission restent dans chaque notificateur.
const podavioNotificationSettings = InitializationSettings(
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

Future<void> initializePodavioNotifications(
  FlutterLocalNotificationsPlugin plugin,
) {
  return plugin.initialize(settings: podavioNotificationSettings);
}
