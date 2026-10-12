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
  "notes": ["Fichiers Android et Linux disponibles sur podavio.com."]
}
''');
    expect(release?.version, '2026.10.11');
    expect(release?.date, DateTime.parse('2026-10-07'));
    expect(release?.notes, [
      'Fichiers Android et Linux disponibles sur podavio.com.',
    ]);
    expect(AppRelease.tryParse('{}'), isNull);
  });
}
