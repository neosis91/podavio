import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_controller.dart';
import 'package:podavio/data/download_notifications.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progress body names the podcast and the percent', () {
    expect(
      downloadProgressBody(
        const DownloadNotice(episodeId: 1, title: 'Épisode', podcast: 'Essai'),
      ),
      'Essai',
    );
    expect(
      downloadProgressBody(
        const DownloadNotice(
          episodeId: 1,
          title: 'Épisode',
          podcast: 'Essai',
          progress: 0.42,
        ),
      ),
      'Essai · 42 %',
    );
    expect(downloadFinishedBody('Essai'), 'Téléchargé · Essai');
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
      'progress:',
      'progress:0.42',
      'progress:1.0',
      'finished',
    ]);
    expect(harness.container.read(downloadProgressProvider), isEmpty);
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
      'progress:',
      'failed:Téléchargement impossible (500).',
    ]);
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

    expect(harness.notifications.events, ['progress:', 'dismiss']);
  });
}

class _Harness {
  _Harness(this.container, this.database, this.notifications, this.episode);

  final ProviderContainer container;
  final AppDatabase database;
  final _RecordingNotifications notifications;
  final Episode episode;

  DownloadProgressNotifier get notifier =>
      container.read(downloadProgressProvider.notifier);

  static Future<_Harness> open({
    required Future<void> Function(void Function(double progress)? onProgress)
    onDownload,
  }) async {
    SharedPreferences.setMockInitialValues({
      'enqueueDownloads': false,
      'notifyDownloadActivity': true,
      'notifyDownloadErrors': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    final podcastId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Premier',
            description: 'Notes',
            audioUrl: 'https://example.com/1.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
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
    return _Harness(container, database, notifications, episode);
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
  Future<void> showProgress(DownloadNotice notice) async {
    final progress = notice.progress;
    events.add(progress == null ? 'progress:' : 'progress:$progress');
  }

  @override
  Future<void> showFinished(DownloadNotice notice) async {
    events.add('finished');
  }

  @override
  Future<void> showFailed(DownloadNotice notice, String message) async {
    events.add('failed:$message');
  }

  @override
  Future<void> dismiss(int episodeId) async {
    events.add('dismiss');
  }
}
