import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/activity_messages.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_controller.dart';
import 'package:podavio/data/download_notifications.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a batch is one notice, whether it holds one episode or several', () {
    expect(
      downloadBatchProgressBody(
        const DownloadBatch(remaining: 1, progress: 0.42, podcast: 'Essai'),
      ),
      'Essai · 42 %',
    );
    expect(
      downloadBatchProgressTitle(
        const DownloadBatch(remaining: 4, progress: 0.2),
      ),
      'Téléchargements',
    );
    expect(
      downloadBatchProgressBody(
        const DownloadBatch(remaining: 4, progress: 0.2, failed: 1),
      ),
      '4 épisodes · 20 % · 1 échec',
    );
    expect(
      downloadBatchOutcomeBody(
        const DownloadBatch(
          remaining: 0,
          progress: 1,
          title: 'Premier',
          podcast: 'Essai',
          succeeded: 1,
        ),
      ),
      'Premier · Téléchargé · Essai',
    );
    expect(
      downloadBatchOutcomeBody(
        const DownloadBatch(remaining: 0, progress: 1, succeeded: 3, failed: 2),
      ),
      '3 téléchargés, 2 échecs',
    );
    expect(
      downloadErrorText(Exception('Téléchargement refusé')),
      'Téléchargement refusé',
    );
  });

  test('a download notifies progress then completion', () async {
    final harness = await _Harness.open(
      onDownload: (onProgress) async {
        onProgress?.call(0.42);
        onProgress?.call(0.424);
        onProgress?.call(1);
      },
    );
    addTearDown(harness.close);

    await harness.notifier.download(harness.episode);

    expect(harness.notifications.events, [
      'progress:1:0.0',
      'progress:1:0.0',
      'progress:1:0.42',
      'progress:1:1.0',
      'finished:1:0',
    ]);
    expect(harness.container.read(downloadProgressProvider), isEmpty);
    expect(
      harness.container.read(activityMessagesProvider).single.text,
      'Premier · Téléchargé · Essai',
    );
  });

  test('a failed download notifies the error', () async {
    final harness = await _Harness.open(
      onDownload: (_) async {
        throw Exception('Téléchargement impossible (500).');
      },
    );
    addTearDown(harness.close);

    await expectLater(
      harness.notifier.download(harness.episode),
      throwsA(isA<Exception>()),
    );

    expect(harness.notifications.events, [
      'progress:1:0.0',
      'progress:1:0.0',
      'finished:0:1',
    ]);
    expect(
      harness.container.read(activityMessagesProvider).single.text,
      contains('Téléchargement impossible (500).'),
    );
  });

  test('a cancelled download removes the notification', () async {
    final harness = await _Harness.open(
      onDownload: (_) async {
        throw const DownloadCancelled();
      },
    );
    addTearDown(harness.close);

    await expectLater(
      harness.notifier.download(harness.episode),
      throwsA(isA<DownloadCancelled>()),
    );

    expect(harness.notifications.events, [
      'progress:1:0.0',
      'progress:1:0.0',
      'dismiss',
    ]);
    expect(harness.container.read(activityMessagesProvider), isEmpty);
  });

  test('a group of downloads ends in a single notice', () async {
    final harness = await _Harness.open(
      episodeCount: 2,
      onDownload: (onProgress) async {
        onProgress?.call(1);
      },
    );
    addTearDown(harness.close);

    await Future.wait([
      for (final episode in harness.episodes)
        harness.notifier.download(episode),
    ]);

    expect(
      harness.notifications.events.where(
        (event) => event.startsWith('finished'),
      ),
      ['finished:2:0'],
    );
    expect(
      harness.container.read(activityMessagesProvider).single.text,
      '2 épisodes téléchargés',
    );
  });
}

class _Harness {
  _Harness(this.container, this.database, this.notifications, this.episodes);

  final ProviderContainer container;
  final AppDatabase database;
  final _RecordingNotifications notifications;
  final List<Episode> episodes;

  Episode get episode => episodes.first;

  DownloadProgressNotifier get notifier =>
      container.read(downloadProgressProvider.notifier);

  static Future<_Harness> open({
    required Future<void> Function(void Function(double progress)? onProgress)
    onDownload,
    int episodeCount = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'enqueueDownloads': false,
      'notifyDownloadActivity': true,
      'notifyDownloadErrors': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    final podcastId = (await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          for (var index = 0; index < episodeCount; index++)
            EpisodeDraft(
              guid: 'ep-$index',
              title: index == 0 ? 'Premier' : 'Épisode $index',
              description: 'Notes',
              audioUrl: 'https://example.com/$index.mp3',
            ),
        ],
      ),
    )).podcastId;
    final stored = [
      for (final entry
          in await database.watchEpisodes(podcastId: podcastId).first)
        entry.episode,
    ];
    final notifications = _RecordingNotifications();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(database),
        downloadNotificationsProvider.overrideWithValue(notifications),
        downloadServiceProvider.overrideWith(
          (ref) => _ScriptedDownloadService(
            ref.watch(databaseProvider),
            onDownload: onDownload,
          ),
        ),
      ],
    );
    return _Harness(container, database, notifications, stored);
  }

  Future<void> close() async {
    container.dispose();
    await database.close();
  }
}

class _ScriptedDownloadService extends DownloadService {
  _ScriptedDownloadService(super.database, {required this.onDownload});

  final Future<void> Function(void Function(double progress)? onProgress)
  onDownload;

  @override
  Future<void> download(
    Episode episode, {
    String? directory,
    void Function(double progress)? onProgress,
  }) {
    return onDownload(onProgress);
  }
}

class _RecordingNotifications implements DownloadNotifications {
  final events = <String>[];

  @override
  Future<void> showProgress(DownloadBatch batch) async {
    events.add('progress:${batch.remaining}:${batch.progress}');
  }

  @override
  Future<void> showFinished(DownloadBatch batch) async {
    events.add('finished:${batch.succeeded}:${batch.failed}');
  }

  @override
  Future<void> dismiss() async {
    events.add('dismiss');
  }
}
