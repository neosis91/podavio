import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EpisodeListDensity.byId defaults to comfortable', () {
    expect(EpisodeListDensity.byId(null), EpisodeListDensity.comfortable);
    expect(EpisodeListDensity.byId('unknown'), EpisodeListDensity.comfortable);
    expect(EpisodeListDensity.byId('compact'), EpisodeListDensity.compact);
    expect(
      EpisodeListDensity.byId('comfortable'),
      EpisodeListDensity.comfortable,
    );
  });

  testWidgets('Lecture settings persist episode list density', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: PlaybackPage()),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Densité des listes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Densité des listes'), findsOneWidget);
    expect(find.text('Confortable'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaybackPage)),
    );
    expect(
      container.read(settingsProvider).episodeListDensity,
      EpisodeListDensity.comfortable,
    );

    await tester.tap(find.text('Compact'));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).episodeListDensity,
      EpisodeListDensity.compact,
    );
    expect(preferences.getString('episodeListDensity'), 'compact');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });

  testWidgets('saved compact density is restored on load', (tester) async {
    SharedPreferences.setMockInitialValues({
      'episodeListDensity': 'compact',
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: PlaybackPage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaybackPage)),
    );
    expect(
      container.read(settingsProvider).episodeListDensity,
      EpisodeListDensity.compact,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });
}
