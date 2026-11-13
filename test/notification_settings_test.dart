import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/status_notifications.dart';
import 'package:podavio/l10n/messages.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new episode notices stay off until they are asked for', () {
    expect(
      shouldNotifyNewEpisodes(
        notifyNewEpisodes: false,
        keepUpdated: true,
        episodeNotification: true,
        newCount: 2,
      ),
      isFalse,
    );
    expect(
      shouldNotifyNewEpisodes(
        notifyNewEpisodes: true,
        keepUpdated: true,
        episodeNotification: false,
        newCount: 2,
      ),
      isFalse,
    );
    expect(
      shouldNotifyNewEpisodes(
        notifyNewEpisodes: true,
        keepUpdated: false,
        episodeNotification: true,
        newCount: 2,
      ),
      isFalse,
    );
    expect(
      shouldNotifyNewEpisodes(
        notifyNewEpisodes: true,
        keepUpdated: true,
        episodeNotification: true,
        newCount: 1,
      ),
      isTrue,
    );
  });

  test('new episodes from several podcasts share one notice', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    final body = newEpisodesNotificationBody(
      container.read(settingsProvider),
      const [
        NewEpisodeArrival(podcastId: 1, title: 'Un', count: 1),
        NewEpisodeArrival(podcastId: 2, title: 'Deux', count: 3),
      ],
    );
    expect(body.contains('Un'), isTrue);
    expect(body.contains('Deux'), isTrue);
    expect(body.contains('\n'), isTrue);
    expect('\n'.allMatches(body), hasLength(1));
  });

  test('notification strings exist in every language', () {
    const keys = [
      'Notifications',
      'Errors',
      'Download progress',
      'Shows a notification while an episode downloads, and when it finishes.',
      'Download errors',
      'Shows a notification when a download fails.',
      'Synchronization errors',
      'Shows a notification when synchronization fails.',
      'Connect a synchronization service to enable this.',
      'New episodes',
      'Notify about new episodes',
      'Notifies when a subscription publishes. Each podcast can be turned off in its settings. Turning this off keeps those choices.',
      'Turn on New episodes in Notifications.',
      'Shows a notification when this podcast publishes an episode.',
      'The podcast is not kept up to date.',
      '1 new episode from {podcast}',
      '{count} new episodes from {podcast}',
      'Synchronization failed.',
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

  test('a new subscription does not notify until it is asked', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final saved = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/show.xml',
        title: 'Essai',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Un',
            description: '',
            audioUrl: 'https://example.com/1.mp3',
          ),
        ],
      ),
    );
    final podcast = await database.getPodcast(saved.podcastId);
    expect(podcast!.episodeNotification, isFalse);
    await database.setPodcastEpisodeNotification(
      saved.podcastId,
      enabled: true,
    );
    final updated = await database.getPodcast(saved.podcastId);
    expect(updated!.episodeNotification, isTrue);

    final other = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/other.xml',
        title: 'Autre',
        author: '',
        description: '',
        episodes: [],
      ),
    );
    await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/preview.xml',
        title: 'Aperçu',
        author: '',
        description: '',
        episodes: [],
      ),
      subscribed: false,
    );
    await database.enableEpisodeNotificationForSubscriptions();
    final included = await database.getPodcast(other.podcastId);
    final preview = await database.findByFeedUrl(
      'https://example.com/preview.xml',
    );
    expect(included!.episodeNotification, isTrue);
    expect(preview!.episodeNotification, isFalse);
  });

  testWidgets('notification page stores the error switches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationSettingsPage)),
    );
    expect(container.read(settingsProvider).notifyDownloadActivity, isFalse);
    expect(container.read(settingsProvider).notifyDownloadErrors, isFalse);
    expect(container.read(settingsProvider).notifySyncErrors, isFalse);
    expect(container.read(settingsProvider).notifyNewEpisodes, isFalse);
    expect(find.text('Prévenir des nouveaux épisodes'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Prévenir des nouveaux épisodes'),
    );
    await tester.pump();
    expect(container.read(settingsProvider).notifyNewEpisodes, isTrue);
    expect(preferences.getBool('notifyNewEpisodes'), isTrue);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Progression du téléchargement'),
    );
    await tester.pump();
    expect(container.read(settingsProvider).notifyDownloadActivity, isTrue);
    expect(preferences.getBool('notifyDownloadActivity'), isTrue);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Erreurs de téléchargement'),
    );
    await tester.pump();
    expect(container.read(settingsProvider).notifyDownloadErrors, isTrue);
    expect(preferences.getBool('notifyDownloadErrors'), isTrue);

    final syncTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Erreurs de synchronisation'),
    );
    expect(syncTile.onChanged, isNull);
    expect(container.read(settingsProvider).notifySyncErrors, isFalse);
  });
}
