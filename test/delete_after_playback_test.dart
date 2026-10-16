import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/download_policy.dart';

void main() {
  test('finished playback removes the local file and keeps favorites', () {
    expect(
      shouldDeleteAfterPlayback(
        enabled: true,
        favorite: false,
        downloadPath: '/podcasts/episode.mp3',
      ),
      isTrue,
    );
    expect(
      shouldDeleteAfterPlayback(
        enabled: true,
        favorite: false,
        downloadPath: 'content://downloads/episode.mp3',
      ),
      isTrue,
    );

    expect(
      shouldDeleteAfterPlayback(
        enabled: true,
        favorite: true,
        downloadPath: '/podcasts/episode.mp3',
      ),
      isFalse,
    );
    expect(
      shouldDeleteAfterPlayback(
        enabled: false,
        favorite: false,
        downloadPath: '/podcasts/episode.mp3',
      ),
      isFalse,
    );
    expect(
      shouldDeleteAfterPlayback(
        enabled: true,
        favorite: false,
        downloadPath: null,
      ),
      isFalse,
    );
    expect(
      shouldDeleteAfterPlayback(
        enabled: true,
        favorite: false,
        downloadPath: '   ',
      ),
      isFalse,
    );
  });
}
