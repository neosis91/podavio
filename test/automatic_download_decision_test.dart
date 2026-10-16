import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/download_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  DownloadCandidate candidate(
    int id,
    DateTime? publishedAt, {
    bool included = true,
    bool played = false,
    bool downloaded = false,
  }) {
    return DownloadCandidate(
      id: id,
      included: included,
      played: played,
      downloaded: downloaded,
      publishedAt: publishedAt,
    );
  }

  LocalDownload file(
    int id, {
    bool favorite = false,
    bool inPlaylist = false,
    bool played = false,
    DateTime? downloadedAt,
    DateTime? publishedAt,
    DateTime? lastPlayedAt,
  }) {
    return LocalDownload(
      id: id,
      favorite: favorite,
      inPlaylist: inPlaylist,
      played: played,
      downloadedAt: downloadedAt,
      publishedAt: publishedAt,
      lastPlayedAt: lastPlayedAt,
    );
  }

  AutomaticDownloadDecision decide({
    bool enabled = true,
    int? cacheSize = 5,
    EpisodeCacheCleanup cleanup = EpisodeCacheCleanup.never,
    List<DownloadCandidate> incoming = const [],
    List<LocalDownload> cached = const [],
  }) {
    return decideAutomaticDownloads(
      enabled: enabled,
      cacheSize: cacheSize,
      cleanup: cleanup,
      incoming: incoming,
      cached: cached,
      now: now,
    );
  }

  test('a disabled mechanism downloads and deletes nothing', () {
    final decision = decide(
      enabled: false,
      cacheSize: 1,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      incoming: [candidate(1, now)],
      cached: [file(9, downloadedAt: now)],
    );
    expect(decision.downloadIds, isEmpty);
    expect(decision.deleteIds, isEmpty);
  });

  test('an unlimited cache keeps every eligible episode, newest first', () {
    final decision = decide(
      cacheSize: null,
      incoming: [
        candidate(1, DateTime.utc(2026, 1, 1)),
        candidate(2, DateTime.utc(2026, 3, 1), played: true),
        candidate(3, DateTime.utc(2026, 4, 1), included: false),
        candidate(4, DateTime.utc(2026, 2, 1), downloaded: true),
        candidate(5, null),
        candidate(6, DateTime.utc(2026, 5, 1)),
        candidate(6, DateTime.utc(2026, 6, 1)),
      ],
      cached: [file(7, downloadedAt: now)],
    );
    expect(decision.downloadIds, [6, 1, 5]);
    expect(decision.deleteIds, isEmpty);
  });

  test('downloads stop at the cache while there is still room', () {
    final decision = decide(
      cacheSize: 2,
      cached: [file(1, downloadedAt: DateTime.utc(2026, 1, 1))],
      incoming: [
        candidate(2, DateTime.utc(2026, 1, 2)),
        candidate(3, DateTime.utc(2026, 1, 4)),
        candidate(4, DateTime.utc(2026, 1, 3)),
      ],
    );
    expect(decision.downloadIds, [3]);
    expect(decision.deleteIds, isEmpty);
  });

  test('deletions fill the cache with the newest episodes and then stop', () {
    final decision = decide(
      cacheSize: 3,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      cached: [
        file(1, downloadedAt: DateTime.utc(2026, 1, 1)),
        file(2, downloadedAt: DateTime.utc(2026, 1, 2)),
      ],
      incoming: [
        candidate(3, DateTime.utc(2026, 2, 1)),
        candidate(4, DateTime.utc(2026, 2, 2)),
        candidate(5, DateTime.utc(2026, 2, 3)),
        candidate(6, DateTime.utc(2026, 2, 4)),
      ],
    );
    expect(decision.deleteIds, [1, 2]);
    expect(decision.downloadIds, [6, 5, 4]);
  });

  test('a full cache with never cleanup stays as it is', () {
    final decision = decide(
      cacheSize: 2,
      cleanup: EpisodeCacheCleanup.never,
      cached: [
        file(1, downloadedAt: DateTime.utc(2026, 1, 1)),
        file(2, downloadedAt: DateTime.utc(2026, 1, 2)),
      ],
      incoming: [candidate(3, DateTime.utc(2026, 2, 1))],
    );
    expect(decision.downloadIds, isEmpty);
    expect(decision.deleteIds, isEmpty);
  });

  test('not in the playlist frees only the slots the new episodes need', () {
    final decision = decide(
      cacheSize: 3,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      cached: [
        file(1, downloadedAt: DateTime.utc(2026, 1, 1), inPlaylist: true),
        file(2, downloadedAt: DateTime.utc(2026, 1, 2), favorite: true),
        file(3, downloadedAt: DateTime.utc(2026, 1, 3)),
      ],
      incoming: [
        candidate(5, DateTime.utc(2026, 2, 1)),
        candidate(6, DateTime.utc(2026, 2, 2)),
      ],
    );
    expect(decision.deleteIds, [3]);
    expect(decision.downloadIds, [6]);
  });

  test('after listening deletes the oldest played files, not favorites', () {
    final decision = decide(
      cacheSize: 2,
      cleanup: EpisodeCacheCleanup.afterListening,
      cached: [
        file(
          1,
          played: true,
          inPlaylist: true,
          lastPlayedAt: DateTime.utc(2026, 1, 2),
          downloadedAt: DateTime.utc(2026, 1, 2),
        ),
        file(
          2,
          played: true,
          favorite: true,
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          downloadedAt: DateTime.utc(2026, 1, 1),
        ),
        file(3, lastPlayedAt: DateTime.utc(2026, 1, 3)),
      ],
      incoming: [
        candidate(4, DateTime.utc(2026, 3, 1)),
        candidate(5, DateTime.utc(2026, 3, 2)),
      ],
    );
    expect(decision.deleteIds, [1]);
    expect(decision.downloadIds, [5]);
  });

  test('a delay keeps a recent listen and a played file without a date', () {
    final recent = decide(
      cacheSize: 1,
      cleanup: EpisodeCacheCleanup.after7Days,
      cached: [
        file(
          1,
          played: true,
          lastPlayedAt: DateTime.utc(2026, 10, 10),
          downloadedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      incoming: [candidate(2, now)],
    );
    expect(recent.deleteIds, isEmpty);
    expect(recent.downloadIds, isEmpty);

    final ready = decide(
      cacheSize: 1,
      cleanup: EpisodeCacheCleanup.after7Days,
      cached: [
        file(
          1,
          played: true,
          lastPlayedAt: DateTime.utc(2026, 10, 8),
          downloadedAt: DateTime.utc(2026, 9, 1),
        ),
        file(3, played: true, downloadedAt: DateTime.utc(2026, 1, 1)),
      ],
      incoming: [candidate(2, now)],
    );
    expect(ready.deleteIds, [1]);
    expect(ready.downloadIds, [2]);
  });

  test('an overfull library only yields one old file per new episode', () {
    final decision = decide(
      cacheSize: 2,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      cached: [
        file(1, downloadedAt: DateTime.utc(2026, 1, 1)),
        file(2, downloadedAt: DateTime.utc(2026, 1, 2)),
        file(3, downloadedAt: DateTime.utc(2026, 1, 3)),
        file(4, downloadedAt: DateTime.utc(2026, 1, 4)),
      ],
      incoming: [
        candidate(5, DateTime.utc(2026, 2, 1)),
        candidate(6, DateTime.utc(2026, 2, 2)),
        candidate(7, DateTime.utc(2026, 2, 3)),
      ],
    );
    expect(decision.deleteIds, [1, 2, 3]);
    expect(decision.downloadIds, [7, 6, 5]);
  });

  test('without enough victims, only the episodes that fit are downloaded', () {
    final decision = decide(
      cacheSize: 3,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      cached: [
        file(1, downloadedAt: DateTime.utc(2026, 1, 1), inPlaylist: true),
        file(2, downloadedAt: DateTime.utc(2026, 1, 2), favorite: true),
        file(3, downloadedAt: DateTime.utc(2026, 1, 3)),
      ],
      incoming: [
        candidate(4, DateTime.utc(2026, 2, 1)),
        candidate(5, DateTime.utc(2026, 2, 2)),
      ],
    );
    expect(decision.deleteIds, [3]);
    expect(decision.downloadIds, [5]);
  });

  test(
    'same publication date prefers the higher id, undated files go last',
    () {
      final sameDay = DateTime.utc(2026, 4, 1);
      final decision = decide(
        cacheSize: null,
        incoming: [
          candidate(2, sameDay),
          candidate(8, null),
          candidate(5, sameDay),
        ],
      );
      expect(decision.downloadIds, [5, 2, 8]);
    },
  );

  test('the oldest file is the one downloaded first', () {
    final decision = decide(
      cacheSize: 1,
      cleanup: EpisodeCacheCleanup.notInPlaylist,
      cached: [
        file(
          1,
          publishedAt: DateTime.utc(2020, 1, 1),
          downloadedAt: DateTime.utc(2026, 6, 1),
        ),
        file(
          2,
          publishedAt: DateTime.utc(2026, 1, 1),
          downloadedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      incoming: [candidate(3, now)],
    );
    expect(decision.deleteIds, [2]);
    expect(decision.downloadIds, [3]);
  });
}
