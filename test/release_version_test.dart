import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/release_version.dart';
import 'package:podavio/data/app_release.dart';

void main() {
  test('a later calendar version is newer', () {
    expect(isNewerRelease('2026.10.6', '2026.10.11'), isTrue);
    expect(isNewerRelease('2026.9.2', '2026.10.1'), isTrue);
    expect(compareVersions('2026.10.11', '2026.10.6'), 1);
  });

  test('the same release and a newer local build are not offered', () {
    expect(isNewerRelease('2026.10.11', '2026.10.11'), isFalse);
    expect(isNewerRelease('2026.10.11', 'v2026.10.11'), isFalse);
    expect(isNewerRelease('2026.10.12', '2026.10.11'), isFalse);
    expect(isNewerRelease('2026.10.11-dev', '2026.10.11'), isFalse);
  });

  test('a hotfix with the same numbers is still offered', () {
    expect(isNewerRelease('2026.10.11', '2026.10.11-hf'), isTrue);
  });

  test('latest.json becomes a release', () {
    final release = AppRelease.tryParse('''
{
  "version": "2026.10.11",
  "date": "2026-10-07",
  "notes": ["Fichiers Android et Linux disponibles sur podavio.com."],
  "files": {
    "android-universal": "releases/2026.10.11/podavio-2026.10.11-android-universal.apk",
    "linux-x64": "releases/2026.10.11/podavio-2026.10.11-linux-x64.tar.gz"
  }
}
''');
    expect(release?.version, '2026.10.11');
    expect(release?.date, DateTime.parse('2026-10-07'));
    expect(release?.notes, [
      'Fichiers Android et Linux disponibles sur podavio.com.',
    ]);
    expect(
      release?.fileUri('android-universal')?.toString(),
      'https://podavio.com/releases/2026.10.11/podavio-2026.10.11-android-universal.apk',
    );
    expect(AppRelease.tryParse('{}'), isNull);
  });

  test('a GitHub release exposes its asset links', () {
    final release = AppRelease.tryParseGitHub('''
{
  "tag_name": "2026.10.11",
  "published_at": "2026-10-07T00:00:00Z",
  "body": "- Fichiers sur GitHub.\\n- Archive Linux.",
  "assets": [
    {
      "name": "podavio-2026.10.11-android-universal.apk",
      "browser_download_url": "https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-android-universal.apk"
    },
    {
      "name": "podavio-2026.10.11-linux-x64.tar.gz",
      "browser_download_url": "https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-linux-x64.tar.gz"
    },
    {
      "name": "podavio-2026.10.11-windows-x64.msi",
      "browser_download_url": "https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-windows-x64.msi"
    }
  ]
}
''');
    expect(release?.version, '2026.10.11');
    expect(release?.notes, ['Fichiers sur GitHub.', 'Archive Linux.']);
    expect(
      release?.fileUri('android-universal')?.toString(),
      'https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-android-universal.apk',
    );
    expect(
      release?.fileUri('linux-x64')?.toString(),
      'https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-linux-x64.tar.gz',
    );
    expect(
      release?.fileUri('windows-x64')?.toString(),
      'https://github.com/neosis91/podavio/releases/download/2026.10.11/podavio-2026.10.11-windows-x64.msi',
    );
    final tagged = AppRelease.tryParseGitHub('{"tag_name":"2026.10.11"}');
    expect(tagged?.version, '2026.10.11');
    expect(tagged?.files, isEmpty);
  });
}
