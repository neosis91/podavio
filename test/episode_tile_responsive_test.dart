import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_controller.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/player/player_controller.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/widgets/brand.dart';
import 'package:podavio/ui/widgets/episode_tile.dart';
import 'package:podavio/ui/widgets/list_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  final cases = <({String name, double width, ListWidthTier tier})>[
    (name: 'narrow <360', width: 320, tier: ListWidthTier.narrow),
    (name: 'phone', width: 400, tier: ListWidthTier.phone),
    (name: 'tablet', width: 700, tier: ListWidthTier.tablet),
    // Contenu utile après rail (~200) sur desktop 1280.
    (name: 'desktop+rail', width: 1080, tier: ListWidthTier.large),
  ];

  for (final density in EpisodeListDensity.values) {
    for (final textScale in [1.0, 1.3]) {
      for (final c in cases) {
        testWidgets('tile ${c.name} ${density.id} textScale=$textScale '
            'lays out without overflow', (tester) async {
          final harness = await _pumpTile(
            tester,
            width: c.width,
            density: density,
            textScale: textScale,
            entry: _entry(
              title:
                  'Un titre assez long pour forcer deux lignes '
                  'sur les largeurs étroites et moyennes',
              positionMs: 90 * 1000,
              durationSeconds: 30 * 60,
              favorite: true,
              queueIndex: 1,
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.textContaining('Un titre assez long'), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.byIcon(Icons.favorite), findsOneWidget);

          final metrics = EpisodeTileMetrics.resolve(
            width: c.width,
            textTheme: Typography.material2021().black,
            textScaler: TextScaler.linear(textScale),
            density: density,
            played: false,
            onSurface: const Color(0xFF000000),
            muted: const Color(0xFF666666),
          );
          expect(metrics.tier, c.tier);
          expect(
            metrics.coverSize,
            inInclusiveRange(
              _coverMin(c.tier, density),
              _coverMax(c.tier, density),
            ),
          );

          await harness.close(tester);
        });
      }
    }
  }

  testWidgets('download percent is hidden on narrow, shown on phone+', (
    tester,
  ) async {
    final narrow = await _pumpTile(
      tester,
      width: 320,
      entry: _entry(),
      downloadProgress: {1: 0.42},
    );
    expect(tester.takeException(), isNull);
    expect(find.text('42 %'), findsNothing);
    expect(find.byType(DownloadProgressRing), findsOneWidget);
    await narrow.close(tester);

    final phone = await _pumpTile(
      tester,
      width: 400,
      entry: _entry(),
      downloadProgress: {1: 0.42},
    );
    expect(tester.takeException(), isNull);
    expect(find.text('42 %'), findsOneWidget);
    expect(find.byType(DownloadProgressRing), findsOneWidget);
    await phone.close(tester);
  });

  testWidgets('playing row uses a highlight background', (tester) async {
    final harness = await _pumpTile(
      tester,
      width: 400,
      entry: _entry(id: 7),
      playingEpisodeId: 7,
    );
    expect(tester.takeException(), isNull);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(EpisodeTile),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, isNot(Colors.transparent));
    expect(material.color!.a, greaterThan(0));

    await harness.close(tester);
  });

  testWidgets('search highlight matches title and podcast', (tester) async {
    final harness = await _pumpTile(
      tester,
      width: 400,
      entry: _entry(title: 'Café du matin', podcastTitle: 'Radio Café'),
      highlightQuery: 'cafe',
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Café du matin'), findsOneWidget);
    expect(find.text('Radio Café'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);

    await harness.close(tester);
  });

  testWidgets('playlist drag handle stays tappable on all widths', (
    tester,
  ) async {
    for (final width in [320.0, 400.0, 700.0, 1080.0]) {
      final harness = await _pumpTile(
        tester,
        width: width,
        entry: _entry(queueIndex: 0),
        reorderIndex: 0,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DragIndicatorIcon), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsOneWidget);
      await harness.close(tester);
    }
  });

  testWidgets('podcast page hides podcast name and reste when progressing', (
    tester,
  ) async {
    final harness = await _pumpTile(
      tester,
      width: 400,
      showPodcast: false,
      entry: _entry(
        podcastTitle: 'Ne doit pas apparaître',
        positionMs: 60 * 1000,
        durationSeconds: 10 * 60,
      ),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Ne doit pas apparaître'), findsNothing);
    expect(find.textContaining('reste'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await harness.close(tester);
  });

  testWidgets('horizontal padding follows width tiers', (tester) async {
    expect(listHorizontalPadding(320), 12);
    expect(listHorizontalPadding(400), 16);
    expect(listHorizontalPadding(700), 20);
    expect(listHorizontalPadding(1000), 24);
  });
}

double _coverMin(ListWidthTier tier, EpisodeListDensity density) {
  final compact = density == EpisodeListDensity.compact;
  return switch (tier) {
    ListWidthTier.narrow => compact ? 48.0 : 52.0,
    ListWidthTier.phone => compact ? 52.0 : 56.0,
    ListWidthTier.tablet => compact ? 56.0 : 60.0,
    ListWidthTier.large => compact ? 60.0 : 64.0,
  };
}

double _coverMax(ListWidthTier tier, EpisodeListDensity density) {
  final compact = density == EpisodeListDensity.compact;
  return switch (tier) {
    ListWidthTier.narrow => compact ? 68.0 : 72.0,
    ListWidthTier.phone => compact ? 80.0 : 88.0,
    ListWidthTier.tablet => compact ? 88.0 : 92.0,
    ListWidthTier.large => compact ? 92.0 : 96.0,
  };
}

EpisodeEntry _entry({
  int id = 1,
  String title = 'Épisode test',
  String podcastTitle = 'Podcast test',
  int positionMs = 0,
  int? durationSeconds = 1800,
  bool favorite = false,
  int? queueIndex,
  String? downloadPath,
}) {
  return EpisodeEntry(
    episode: Episode(
      id: id,
      podcastId: 1,
      guid: 'guid-$id',
      title: title,
      description: '',
      audioUrl: 'https://example.com/a.mp3',
      durationSeconds: durationSeconds,
      publishedAt: DateTime(2026, 1, 15),
      positionMs: positionMs,
      played: false,
      favorite: favorite,
      downloadPath: downloadPath,
      queueIndex: queueIndex,
      chaptersFetched: false,
    ),
    podcast: Podcast(
      id: 1,
      feedUrl: 'https://example.com/feed.xml',
      title: podcastTitle,
      author: 'Auteur',
      description: '',
      subscribedAt: DateTime(2025, 1, 1),
      preferred: false,
      autoDownload: false,
      keepUpdated: true,
      episodeNotification: false,
      subscribed: true,
      skipIntroSeconds: 0,
      skipOutroSeconds: 0,
      personsJson: '[]',
      fundingJson: '[]',
    ),
  );
}

class _Harness {
  _Harness(this.database);

  final AppDatabase database;

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  }
}

class _StubPlayer extends PlayerNotifier {
  _StubPlayer(this._state);

  final PlayerUiState _state;

  @override
  PlayerUiState build() => _state;
}

class _StubDownloads extends DownloadProgressNotifier {
  _StubDownloads(this._progress);

  final Map<int, double> _progress;

  @override
  Map<int, double> build() => _progress;
}

Future<_Harness> _pumpTile(
  WidgetTester tester, {
  required double width,
  required EpisodeEntry entry,
  EpisodeListDensity density = EpisodeListDensity.comfortable,
  double textScale = 1,
  bool showPodcast = true,
  int? reorderIndex,
  String highlightQuery = '',
  int? playingEpisodeId,
  Map<int, double> downloadProgress = const {},
}) async {
  SharedPreferences.setMockInitialValues({'episodeListDensity': density.id});
  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase(NativeDatabase.memory());

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: reorderIndex == null
                    ? EpisodeTile(
                        entry: entry,
                        showPodcast: showPodcast,
                        highlightQuery: highlightQuery,
                      )
                    : ReorderableListView(
                        onReorderItem: (_, _) {},
                        buildDefaultDragHandles: false,
                        children: [
                          EpisodeTile(
                            key: ValueKey(entry.episode.id),
                            entry: entry,
                            showPodcast: showPodcast,
                            reorderIndex: reorderIndex,
                            highlightQuery: highlightQuery,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(database),
        playerProvider.overrideWith(
          () => _StubPlayer(PlayerUiState(episodeId: playingEpisodeId)),
        ),
        downloadProgressProvider.overrideWith(
          () => _StubDownloads(downloadProgress),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return _Harness(database);
}
