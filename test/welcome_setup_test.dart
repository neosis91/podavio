import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('restoring a backup has no skip button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: WelcomePage()),
      ),
    );
    await tester.tap(find.text('J’utilise déjà Podavio'));
    await tester.pump();

    expect(find.text('Restaurer la sauvegarde'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
    expect(find.text('Suivant'), findsNothing);
  });

  testWidgets('turning eco mode off restores the previous pure black', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    final settings = container.read(settingsProvider.notifier);

    await settings.setEcoMode(true);
    await settings.setEcoMode(false);
    expect(container.read(settingsProvider).ecoMode, isFalse);
    expect(container.read(settingsProvider).pureBlack, isFalse);

    await settings.setPureBlack(true);
    await settings.setEcoMode(true);
    await settings.setEcoMode(false);
    expect(container.read(settingsProvider).pureBlack, isTrue);
  });

  testWidgets('eco mode already on keeps pure black when no previous value', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ecoMode': true,
      'pureBlack': true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    await container.read(settingsProvider.notifier).setEcoMode(false);
    expect(container.read(settingsProvider).ecoMode, isFalse);
    expect(container.read(settingsProvider).pureBlack, isTrue);
  });
}
