import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/l10n/messages.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache size and cleanup ignore unknown stored values', () {
    expect(episodeCacheSizeFromStored(null), isNull);
    expect(episodeCacheSizeFromStored(0), isNull);
    expect(episodeCacheSizeFromStored(7), isNull);
    expect(episodeCacheSizeFromStored(20), 20);
    expect(episodeCacheSizeLabel(null), 'Unlimited');
    expect(episodeCacheSizeLabel(20), '20 episodes');

    expect(EpisodeCacheCleanup.byId(null), EpisodeCacheCleanup.never);
    expect(EpisodeCacheCleanup.byId('nope'), EpisodeCacheCleanup.never);
    expect(
      EpisodeCacheCleanup.byId('notInPlaylist'),
      EpisodeCacheCleanup.notInPlaylist,
    );
    expect(EpisodeCacheCleanup.afterListening.daysAfterListening, 0);
    expect(EpisodeCacheCleanup.after1Day.daysAfterListening, 1);
    expect(EpisodeCacheCleanup.after30Days.daysAfterListening, 30);
    expect(EpisodeCacheCleanup.never.daysAfterListening, isNull);
    expect(EpisodeCacheCleanup.notInPlaylist.daysAfterListening, isNull);
  });

  test('download setting strings exist in every language', () {
    const keys = [
      'Automatic download',
      'Includes every subscription. Each podcast can be excluded from its menu. Turning this off keeps those choices.',
      'Episode cache',
      'Unlimited',
      'Download limit',
      'Maximum number of episodes to download per podcast during an automatic download.',
      '1 episode',
      '2 episodes',
      '3 episodes',
      '4 episodes',
      '5 episodes',
      '10 episodes',
      '20 episodes',
      '50 episodes',
      '100 episodes',
      '200 episodes',
      '500 episodes',
      '1000 episodes',
      'Automatic deletion',
      'Delete after playback',
      'Deletes the file when playback finishes. Favorites are kept.',
      'Free up space',
      'Only when the cache is full, before an automatic download. Favorites are kept.',
      'Never',
      'Not in the playlist',
      'After listening',
      '1 day after listening',
      '3 days after listening',
      '7 days after listening',
      '14 days after listening',
      '30 days after listening',
      'Mobile data',
      'Network',
      'Data usage',
      'Episode downloads',
      'Streaming',
      'Wi-Fi only',
      'Wi-Fi and mobile data',
      'Automatic downloads wait for Wi-Fi. Starting one on mobile data asks first.',
      'This download will use mobile data.',
    ];
    for (final entry in interfaceMessages.entries) {
      for (final key in keys) {
        expect(
          entry.value.containsKey(key),
          isTrue,
          reason: '${entry.key} missing "$key"',
        );
      }
    }
  });

  test(
    'unknown download settings fall back without dropping a real choice',
    () async {
      SharedPreferences.setMockInitialValues({
        'automaticDownload': true,
        'episodeCacheSize': 7,
        'deleteAfterPlayback': true,
        'episodeCacheCleanup': 'nope',
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.automaticDownload, isTrue);
      expect(settings.episodeCacheSize, isNull);
      expect(settings.deleteAfterPlayback, isTrue);
      expect(settings.episodeCacheCleanup, EpisodeCacheCleanup.never);

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setEpisodeCacheSize(50);
      expect(container.read(settingsProvider).episodeCacheSize, 50);
      expect(preferences.getInt('episodeCacheSize'), 50);

      await notifier.setEpisodeCacheSize(3);
      expect(container.read(settingsProvider).episodeCacheSize, isNull);
      expect(preferences.containsKey('episodeCacheSize'), isFalse);

      await notifier.setEpisodeCacheCleanup(EpisodeCacheCleanup.after7Days);
      expect(preferences.getString('episodeCacheCleanup'), '7');
      expect(
        container.read(settingsProvider).episodeCacheCleanup.daysAfterListening,
        7,
      );
      await notifier.setDeleteAfterPlayback(false);
      expect(container.read(settingsProvider).deleteAfterPlayback, isFalse);
      expect(preferences.getBool('deleteAfterPlayback'), isFalse);
    },
  );

  testWidgets('download page stores the new settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final included = await _podcast(database, 'https://example.com/a.xml', 'A');
    final excluded = await _podcast(database, 'https://example.com/b.xml', 'B');
    final preview = await _podcast(
      database,
      'https://example.com/c.xml',
      'C',
      subscribed: false,
    );
    await database.setPodcastAutoDownload(excluded, autoDownload: false);

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          defaultDownloadDirectoryProvider.overrideWith(
            (ref) async => '/tmp/podavio-downloads',
          ),
        ],
        child: const MaterialApp(home: DownloadSettingsPage()),
      ),
    );
    await _frames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DownloadSettingsPage)),
    );
    expect(container.read(settingsProvider).automaticDownload, isFalse);
    expect(container.read(settingsProvider).allowMobileData, isFalse);
    expect(container.read(settingsProvider).episodeCacheSize, isNull);
    expect(container.read(settingsProvider).deleteAfterPlayback, isFalse);
    expect(
      container.read(settingsProvider).episodeCacheCleanup,
      EpisodeCacheCleanup.never,
    );
    expect(find.text('Illimité'), findsOneWidget);
    expect(find.textContaining('Jamais'), findsOneWidget);

    await _tapTile(tester, 'Téléchargement automatique');
    expect(preferences.getBool('automaticDownload'), isTrue);
    expect(await _autoDownload(database, included), isTrue);
    expect(await _autoDownload(database, excluded), isTrue);
    expect(await _autoDownload(database, preview), isFalse);

    await database.setPodcastAutoDownload(excluded, autoDownload: false);
    await _tapTile(tester, 'Téléchargement automatique');
    expect(preferences.getBool('automaticDownload'), isFalse);
    expect(await _autoDownload(database, included), isTrue);
    expect(await _autoDownload(database, excluded), isFalse);

    await _tapTile(tester, 'Téléchargement automatique');
    expect(await _autoDownload(database, excluded), isTrue);
    expect(await _autoDownload(database, preview), isFalse);

    await _tapTile(tester, 'Données mobiles');
    expect(container.read(settingsProvider).allowMobileData, isTrue);
    expect(preferences.getBool('allowMobileData'), isTrue);
    await _tapTile(tester, 'Données mobiles');
    expect(container.read(settingsProvider).allowMobileData, isFalse);

    await _openChoice(tester, 'Cache d’épisodes');
    await tester.tap(find.text('20 épisodes'));
    await _frames(tester);
    expect(container.read(settingsProvider).episodeCacheSize, 20);
    expect(preferences.getInt('episodeCacheSize'), 20);

    await _openChoice(tester, 'Cache d’épisodes');
    await tester.tap(find.text('Illimité'));
    await _frames(tester);
    expect(container.read(settingsProvider).episodeCacheSize, isNull);
    expect(preferences.containsKey('episodeCacheSize'), isFalse);

    await _tapTile(tester, 'Supprimer après la lecture');
    expect(container.read(settingsProvider).deleteAfterPlayback, isTrue);
    expect(preferences.getBool('deleteAfterPlayback'), isTrue);

    await _openChoice(tester, 'Libérer de la place');
    await tester.tap(find.text('Hors de la playlist'));
    await _frames(tester);
    expect(
      container.read(settingsProvider).episodeCacheCleanup,
      EpisodeCacheCleanup.notInPlaylist,
    );
    expect(preferences.getString('episodeCacheCleanup'), 'notInPlaylist');

    await _openChoice(tester, 'Libérer de la place');
    await tester.tap(find.text('14 jours après l’écoute'));
    await _frames(tester);
    expect(
      container.read(settingsProvider).episodeCacheCleanup.daysAfterListening,
      14,
    );
  });
}

Future<int> _podcast(
  AppDatabase database,
  String url,
  String title, {
  bool subscribed = true,
}) async {
  final saved = await database.saveFeed(
    FeedDraft(
      feedUrl: url,
      title: title,
      author: 'Auteur',
      description: 'Description',
      episodes: [
        EpisodeDraft(
          guid: '$title-1',
          title: 'Épisode',
          description: 'Notes',
          audioUrl: '$url/1.mp3',
        ),
      ],
    ),
    subscribed: subscribed,
  );
  return saved.podcastId;
}

Future<bool> _autoDownload(AppDatabase database, int id) async {
  final podcast = await database.getPodcast(id);
  return podcast!.autoDownload;
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapTile(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(SwitchListTile, title));
  await _frames(tester);
}

Future<void> _openChoice(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(ListTile, title));
  await _frames(tester);
}
