import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/episodes_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('EpisodeFilters', () {
    test('null ids default to unread inbox', () {
      expect(EpisodeFilters.fromIds(null), EpisodeFilters.inboxDefault);
      expect(EpisodeFilters.fromIds(null).unreadOnly, isTrue);
      expect(EpisodeFilters.fromIds(null).isEmpty, isFalse);
    });

    test('empty ids mean no filters (show all)', () {
      expect(EpisodeFilters.fromIds(const []), EpisodeFilters.empty);
      expect(EpisodeFilters.fromIds(const []).isEmpty, isTrue);
    });

    test('toIds / fromIds round-trip', () {
      const filters = EpisodeFilters(
        unreadOnly: true,
        downloadsOnly: true,
        inProgressOnly: true,
      );
      expect(EpisodeFilters.fromIds(filters.toIds()).unreadOnly, isTrue);
      expect(EpisodeFilters.fromIds(filters.toIds()).downloadsOnly, isTrue);
      expect(EpisodeFilters.fromIds(filters.toIds()).inProgressOnly, isTrue);
    });
  });

  testWidgets('Episodes page uses filter dialog instead of segmented button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: EpisodesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('Non lus'), findsOneWidget); // chip barre (défaut)

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Filtrer'), findsOneWidget);

    await tester.tap(find.text('Filtrer'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrer'), findsWidgets);
    expect(find.text('Téléchargés'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);

    await tester.tap(find.text('Téléchargés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(find.text('Téléchargés'), findsOneWidget);
    expect(
      preferences.getStringList('episodeFilters'),
      containsAll(['unreadOnly', 'downloadsOnly']),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EpisodesPage)),
    );
    expect(container.read(settingsProvider).episodeFilters.downloadsOnly, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });

  testWidgets('clearing filters persists empty list (show all)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: EpisodesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();

    expect(find.text('Non lus'), findsNothing);
    expect(preferences.getStringList('episodeFilters'), isEmpty);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EpisodesPage)),
    );
    expect(container.read(settingsProvider).episodeFilters.isEmpty, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });
}
