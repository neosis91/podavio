import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/settings_controller.dart';
import 'status_notifications.dart';

const _channel = MethodChannel('fr.podavio.podavio/analysis_keepalive');

/// Maintient le processus Android pendant l’analyse, avec une notification.
/// Sans ça, quitter l’app tue le décodage en cours.
Future<void> syncAnalysisKeepAlive({
  AppSettings? settings,
  required int count,
}) async {
  if (!Platform.isAndroid) return;
  try {
    if (count <= 0 || settings == null) {
      await _channel.invokeMethod<void>('stop');
      return;
    }
    await _channel.invokeMethod<void>('start', {
      'title': notificationText(settings, 'Analyzing episodes ({count} left)', {
        'count': '$count',
      }),
      'channel': notificationText(settings, 'Analysis management'),
    });
  } catch (error, stack) {
    debugPrint('Maintien de l’analyse : $error\n$stack');
  }
}
