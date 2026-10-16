import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/sync/sync_protocol.dart';

void main() {
  test('parses a server address with a folder', () {
    final host = parseSyncHost('example.com/nextcloud/');
    expect(host?.scheme, 'https');
    expect(host?.host, 'example.com');
    expect(host?.folder, '/nextcloud');
    expect(
      host?.resolve('/index.php/apps/gpoddersync/subscriptions').path,
      '/nextcloud/index.php/apps/gpoddersync/subscriptions',
    );
    expect(parseSyncHost(''), isNull);
    expect(parseSyncHost('ftp://example.com'), isNull);
  });

  test('reads devices, subscription changes and episode actions', () {
    final devices = SyncDevice.parseList('''
[
  {"id": "phone", "caption": "Téléphone", "type": "mobile", "subscriptions": 3}
]
''');
    expect(devices.single.caption, 'Téléphone');

    final changes = SyncSubscriptionChanges.parse('''
{"add": ["https://example.com/feed"], "remove": ["not-a-url"], "timestamp": 42}
''');
    expect(changes.added, ['https://example.com/feed']);
    expect(changes.removed, isEmpty);
    expect(changes.timestamp, 42);

    final episodes = SyncEpisodeChanges.parse('''
{
  "timestamp": 7,
  "actions": [
    {
      "podcast": "https://example.com/feed",
      "episode": "https://example.com/a.mp3",
      "guid": "a",
      "action": "play",
      "position": 12,
      "started": 0,
      "total": 40
    }
  ]
}
''');
    expect(episodes.timestamp, 7);
    expect(episodes.actions.single.position, 12);
    expect(
      syncActionTimestamp(DateTime.utc(2009, 12, 12, 9)),
      '2009-12-12T09:00:00',
    );
  });

  test('a queued local action overrides the remote one', () {
    const remote = SyncEpisodeAction(
      podcast: 'https://feed',
      episode: 'https://audio',
      action: 'play',
      position: 1,
    );
    const queued = SyncEpisodeAction(
      podcast: 'https://feed',
      episode: 'https://audio',
      action: 'play',
      position: 9,
    );
    expect(remoteActionsToApply([remote], [queued]), isEmpty);
    expect(remoteActionsToApply([remote], const []), hasLength(1));
  });

  test('nextcloud login flow parses the browser challenge', () {
    final start = NextcloudLoginStart.parse('''
{
  "poll": {"token": "abc", "endpoint": "https://cloud.example/login/v2/poll"},
  "login": "https://cloud.example/login/v2/flow/abc"
}
''');
    expect(start?.token, 'abc');
    final result = NextcloudLoginResult.parse('''
{"server": "https://cloud.example", "loginName": "ada", "appPassword": "secret"}
''');
    expect(result?.username, 'ada');
    expect(result?.appPassword, 'secret');
  });
}
