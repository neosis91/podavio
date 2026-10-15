import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/interface_language_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('marks the device language on its code and follows the system', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.platformDispatcher.localeTestValue = const Locale('fr');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: InterfaceLanguagePage()),
      ),
    );
    await tester.pump();

    final frenchTile = find.ancestor(
      of: find.text('Français'),
      matching: find.byType(RadioListTile<String>),
    );
    expect(
      find.descendant(of: frenchTile, matching: find.text('fr - Système')),
      findsOneWidget,
    );
    expect(find.text('Système'), findsNothing);

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(preferences.getString('interfaceLanguage'), 'de');

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(preferences.containsKey('interfaceLanguage'), isFalse);
  });

  testWidgets('hides System when the device language is not offered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.platformDispatcher.localeTestValue = const Locale('sv');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: InterfaceLanguagePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Système'), findsNothing);
    expect(find.text('en'), findsOneWidget);
    expect(find.text('fr'), findsOneWidget);
  });
}
