import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/library_hub_page.dart';
import 'package:podavio/ui/library_pages.dart';
import 'package:podavio/ui/router.dart';
import 'package:podavio/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('downloads back returns to the library', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    final podcastId = await database
        .into(database.podcasts)
        .insert(
          PodcastsCompanion.insert(
            feedUrl: 'https://example.com/feed.xml',
            title: 'Une émission',
            subscribedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await database
        .into(database.episodes)
        .insert(
          EpisodesCompanion.insert(
            podcastId: podcastId,
            guid: 'episode-1',
            title: 'Un épisode téléchargé',
            audioUrl: 'https://example.com/episode.mp3',
            downloadPath: const Value('/tmp/episode.mp3'),
          ),
        );
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.library,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: AppRoutes.library,
              builder: (context, state) => const LibraryPage(),
            ),
            GoRoute(
              path: AppRoutes.downloads,
              builder: (context, state) => const DownloadsPage(),
            ),
            GoRoute(
              path: AppRoutes.podcasts,
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: AppRoutes.discover,
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Téléchargements'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, AppRoutes.downloads);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, AppRoutes.library);
    expect(find.text('Lectures récentes'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });
}
