import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/activity_messages.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_controller.dart';
import 'package:podavio/data/download_notifications.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/online_status.dart';
import 'package:podavio/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a queued episode is not counted as a new download', () {
    expect(
      downloadAlreadyRequested(2, running: const {1: 0}, waiting: const {2, 3}),
      isTrue,
    );
    expect(
      downloadAlreadyRequested(1, running: const {1: 0.4}, waiting: const {}),
      isTrue,
    );
    expect(
      downloadAlreadyRequested(4, running: const {1: 0.2}, waiting: const {2}),
      isFalse,
    );
  });

  test('a batch is one notice, whether it holds one episode or several', () {
    expect(
      downloadBatchProgressBody(
        const DownloadBatch(remaining: 1, progress: 0.42, podcast: 'Essai'),
      ),
      'Essai · 0/1 · 42 %',
    );
    expect(
      downloadBatchProgressTitle(
        const DownloadBatch(remaining: 4, progress: 0.2),
      ),
      'Téléchargements',
    );
    expect(
      downloadBatchProgressBody(
        const DownloadBatch(
          remaining: 5,
          progress: 0.5,
          succeeded: 2,
          failed: 1,
        ),
      ),
      '2/5 · 50 % · 1 échec',
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

  test('a finished episode stays in the batch total', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    var started = 0;
    final harness = await _Harness.open(
      episodeCount: 3,
      simultaneousDownloads: 1,
      onDownload: (onProgress) async {
        final gate = started == 0 ? first : second;
        started++;
        await gate.future;
        onProgress?.call(1);
      },
    );
    addTearDown(harness.close);

    final pending = [
      for (final episode in harness.episodes.take(2))
        harness.notifier.download(episode),
    ];
    first.complete();
    await pending[0];

    expect(harness.notifications.events, contains('progress:2:0.5'));
    expect(harness.container.read(downloadBatchTallyProvider).finished, 1);

    final third = harness.notifier.download(harness.episodes[2]);
    expect(harness.notifications.events.last, 'progress:3:${1 / 3}');

    final cancelled = expectLater(third, throwsA(isA<DownloadCancelled>()));
    harness.notifier.cancel(harness.episodes[2].id);
    expect(harness.notifications.events.last, 'progress:2:0.5');
    expect(harness.container.read(downloadBatchTallyProvider).finished, 1);
    await cancelled;

    second.complete();
    await pending[1];
    expect(harness.container.read(downloadBatchTallyProvider).finished, 0);
  });

  test('a failure keeps the bytes already received', () async {
    final gate = Completer<void>();
    var calls = 0;
    final harness = await _Harness.open(
      episodeCount: 2,
      simultaneousDownloads: 2,
      onDownload: (onProgress) async {
        final index = calls++;
        if (index == 0) {
          onProgress?.call(0.5);
          throw Exception('coupé');
        }
        await gate.future;
      },
    );
    addTearDown(harness.close);

    final pending = [
      for (final episode in harness.episodes)
        harness.notifier.download(episode),
    ];
    final failed = expectLater(pending[0], throwsA(isA<Exception>()));
    await failed;

    final tally = harness.container.read(downloadBatchTallyProvider);
    final activity = downloadActivityProgress(
      running: harness.container.read(downloadProgressProvider).values,
      waiting: harness.container.read(downloadWaitingCountProvider),
      finished: tally.finished,
      failed: tally.failed,
      failedWritten: tally.failedWritten,
      skipped: tally.skipped,
    );
    expect(activity.total, 2);
    expect(activity.progress, closeTo(0.25, 0.0001));
    expect(harness.notifications.events.last, 'progress:2:0.25');

    gate.complete();
    await pending[1];
  });

  test('a mobile skip stays in the batch total', () async {
    final gate = Completer<void>();
    final harness = await _Harness.open(
      episodeCount: 2,
      simultaneousDownloads: 2,
      mobileData: true,
      onDownload: (_) => gate.future,
    );
    addTearDown(harness.close);

    final manual = harness.notifier.download(harness.episodes[0]);
    final skipped = harness.notifier.download(
      harness.episodes[1],
      automatic: true,
    );
    await skipped;

    final tally = harness.container.read(downloadBatchTallyProvider);
    final activity = downloadActivityProgress(
      running: harness.container.read(downloadProgressProvider).values,
      waiting: harness.container.read(downloadWaitingCountProvider),
      finished: tally.finished,
      failed: tally.failed,
      failedWritten: tally.failedWritten,
      skipped: tally.skipped,
    );
    expect(tally.skipped, 1);
    expect(activity.total, 2);
    expect(activity.progress, 0);
    expect(harness.container.read(downloadProgressProvider), hasLength(1));

    gate.complete();
    await manual;
  });

  test('episodes waiting for a slot stay listed', () async {
    final gate = Completer<void>();
    final harness = await _Harness.open(
      episodeCount: 3,
      simultaneousDownloads: 1,
      onDownload: (_) => gate.future,
    );
    addTearDown(harness.close);

    final pending = [
      for (final episode in harness.episodes)
        harness.notifier.download(episode),
    ];

    expect(harness.container.read(downloadProgressProvider).keys, {
      harness.episodes.first.id,
    });
    expect(harness.container.read(downloadWaitingIdsProvider), {
      harness.episodes[1].id,
      harness.episodes[2].id,
    });

    harness.notifier.cancel(harness.episodes[2].id);
    expect(harness.container.read(downloadWaitingIdsProvider), {
      harness.episodes[1].id,
    });

    gate.complete();
    await expectLater(pending[2], throwsA(isA<DownloadCancelled>()));
    await pending[0];
    await pending[1];
    expect(harness.container.read(downloadWaitingIdsProvider), isEmpty);
    expect(harness.container.read(downloadProgressProvider), isEmpty);
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
    int simultaneousDownloads = 2,
    bool mobileData = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'enqueueDownloads': false,
      'notifyDownloadActivity': true,
      'notifyDownloadErrors': true,
      'simultaneousDownloads': simultaneousDownloads,
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
        if (mobileData)
          mobileDataProbeProvider.overrideWithValue(() async => true),
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
