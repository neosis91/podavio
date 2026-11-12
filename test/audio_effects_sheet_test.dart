import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/player/audio_effects.dart';
import 'package:podavio/ui/player/audio_effects_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('silence strength falls back to high', () {
    expect(SilenceStrength.byId(null), SilenceStrength.high);
    expect(SilenceStrength.byId('extreme'), SilenceStrength.extreme);
    expect(SilenceStrength.byId('extreme').label, 'Extrême');
  });

  testWidgets('audio effects sheet matches the requested controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showAudioEffectsSheet(context),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Effets audios'), findsOneWidget);
    expect(find.text('Amplification'), findsOneWidget);
    expect(find.text('Stabilisateur de volume'), findsOneWidget);
    expect(find.text('Audio mono'), findsOneWidget);
    expect(find.text('Suppression des silences'), findsOneWidget);
    expect(find.text('Efficacité'), findsNothing);
    expect(find.textContaining('galiseur'), findsNothing);

    final silence = find.ancestor(
      of: find.text('Suppression des silences'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: silence, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Efficacité'), findsOneWidget);
    expect(find.text('Élevée'), findsOneWidget);

    await tester.tap(find.text('Efficacité'));
    await tester.pumpAndSettle();
    expect(find.text('Faible'), findsOneWidget);
    expect(find.text('Moyen'), findsOneWidget);
    expect(find.text('Très élevée'), findsOneWidget);
    expect(find.text('Extrême'), findsWidgets);
  });

  testWidgets('switches keep the app accent above a cover theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final app = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E895D)),
      useMaterial3: true,
    );
    final cover = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE53935),
        brightness: Brightness.dark,
      ).copyWith(surfaceContainerHighest: const Color(0xFFE53935)),
      useMaterial3: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: app,
          home: Theme(
            data: cover,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => showAudioEffectsSheet(context),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(Switch).first))
        .colorScheme;
    expect(scheme.primary, app.colorScheme.primary);
    expect(scheme.surfaceContainerHighest, isNot(const Color(0xFFE53935)));
  });
}
