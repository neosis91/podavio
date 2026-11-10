import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'build_info.dart';

/// Transactions d'ouverture, les seules remontées en release.
/// SimpMusic ne trace que `app.open` ; le SDK Flutter nomme ce démarrage
/// `app.start` ou `ui.load`.
const _startupTransactions = {'app.start', 'ui.load'};

/// Démarre Sentry avant le reste de l'application.
///
/// Un DSN vide, le cas d'un `flutter run` sans `--dart-define`, désactive
/// l'envoi. La release publique reçoit `SENTRY_DSN` depuis le secret CI.
Future<void> startCrashReporting(Future<void> Function() appRunner) {
  return SentryFlutter.init((options) {
    options.dsn = const String.fromEnvironment('SENTRY_DSN');
    options.sendDefaultPii = true;
    options.environment = kReleaseMode
        ? 'production'
        : (kProfileMode ? 'profile' : 'debug');
    if (BuildInfo.version.isNotEmpty) {
      options.release = BuildInfo.version;
    }
    if (BuildInfo.commit.isNotEmpty) {
      options.dist = BuildInfo.commit;
    }
    options.tracesSampler = (samplingContext) {
      final name = samplingContext.transactionContext.name;
      if (_startupTransactions.contains(name)) return 1.0;
      return 0.0;
    };
  }, appRunner: appRunner);
}
