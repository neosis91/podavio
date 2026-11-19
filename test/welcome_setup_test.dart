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

  testWidgets('listening language follows the phone until a choice is saved', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
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
    expect(container.read(settingsProvider).discoverLanguages, ['de']);
    expect(
      container.read(settingsProvider).discoverLanguagesFromSystem,
      isTrue,
    );
    expect(preferences.getStringList('discoverLanguages'), isNull);

    tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
    await tester.pump();
    expect(container.read(settingsProvider).discoverLanguages, ['fr']);
    expect(preferences.getStringList('discoverLanguages'), isNull);

    await container
        .read(settingsProvider.notifier)
        .setDiscoverAllLanguages(true);
    await container
        .read(settingsProvider.notifier)
        .setDiscoverAllLanguages(false);
    expect(container.read(settingsProvider).discoverLanguages, ['fr']);
    expect(
      container.read(settingsProvider).discoverLanguagesFromSystem,
      isFalse,
    );
  });

  testWidgets('a saved listening language stays in place', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({
      'discoverLanguages': ['*'],
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: WelcomePage()),
      ),
    );
    await tester.pump();

    expect(preferences.getStringList('discoverLanguages'), ['*']);
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
