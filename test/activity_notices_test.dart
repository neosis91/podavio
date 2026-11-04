import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/ui/activity_notices.dart';

void main() {
  test('offline stays first, downloads pass ahead of a refresh', () {
    expect(
      activityNoticeOrder(
        offline: true,
        refresh: true,
        downloads: false,
        opml: true,
        messages: true,
      ),
      [
        ActivityNotice.offline,
        ActivityNotice.refresh,
        ActivityNotice.opml,
        ActivityNotice.messages,
      ],
    );
    expect(
      activityNoticeOrder(
        offline: true,
        refresh: true,
        downloads: true,
        opml: false,
        messages: false,
      ),
      [
        ActivityNotice.offline,
        ActivityNotice.downloads,
        ActivityNotice.refresh,
      ],
    );
    expect(
      activityNoticeOrder(
        offline: false,
        refresh: false,
        downloads: true,
        opml: true,
        messages: false,
      ),
      [ActivityNotice.downloads, ActivityNotice.opml],
    );
  });

  test('download progress counts episodes still to fetch', () {
    final activity = downloadActivityProgress(
      running: const [0.5, 1],
      waiting: 2,
    );
    expect(activity.remaining, 4);
    expect(activity.progress, closeTo(1.5 / 4, 0.0001));
    expect(
      downloadActivityProgress(running: const [], waiting: 0).remaining,
      0,
    );
  });

  test('refresh counts podcasts still to update', () {
    expect(podcastsLeftToRefresh(done: 3, total: 10), 7);
    expect(podcastsLeftToRefresh(done: 10, total: 10), 0);
    expect(podcastsLeftToRefresh(done: 12, total: 10), 0);
  });
}
