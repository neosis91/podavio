import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/theme.dart';
import 'package:podavio/data/online_status.dart';
import 'package:podavio/ui/widgets/offline_banner.dart';

void main() {
  testWidgets('shows a banner when internet is unreachable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onlineStatusProvider.overrideWith(OfflineStatus.new)],
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );

    expect(find.text('Pas de connexion internet'), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('offline-banner'))).color,
      podavioRed,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
  });

  testWidgets('hides the banner when internet is reachable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onlineStatusProvider.overrideWith(OnlineStatus.new)],
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );

    expect(find.text('Pas de connexion internet'), findsNothing);
  });
}

class OfflineStatus extends OnlineStatusNotifier {
  @override
  bool? build() => false;
}

class OnlineStatus extends OnlineStatusNotifier {
  @override
  bool? build() => true;
}
