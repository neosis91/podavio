import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/playback_file.dart';

void main() {
  test('a stored download stays a local path', () {
    expect(
      filesystemPlaybackPath('/podcasts/[Show] Episode.mp3'),
      '/podcasts/[Show] Episode.mp3',
    );
    expect(
      filesystemPlaybackPath('  file:///podcasts/episode.mp3  '),
      '/podcasts/episode.mp3',
    );
    expect(
      filesystemPlaybackPath('content://downloads/episode.mp3'),
      isNull,
    );
    expect(filesystemPlaybackPath(null), isNull);
    expect(filesystemPlaybackPath('   '), isNull);
  });

  test('playback cache name is stable and safe', () {
    const source = 'content://downloads/primary%3APodcasts%2Fepisode.mp3';
    final name = playbackCacheName(source);
    expect(name, playbackCacheName(source));
    expect(name, endsWith('.mp3'));
    expect(name.contains(' '), isFalse);
    expect(name.contains('%'), isFalse);
  });

  test('cached playback file is reused when the size matches', () async {
    final root = await Directory.systemTemp.createTemp('podavio-playback');
    addTearDown(() => root.delete(recursive: true));
    var copies = 0;
    Future<String> cache(int length) {
      return cachedPlaybackFile(
        source: 'content://downloads/episode.mp3',
        cacheDirectory: root,
        copy: (source, dest) async {
          copies++;
          await File(dest).writeAsString('audio' * length);
        },
        sourceLength: (_) async => 5,
      );
    }

    final first = await cache(1);
    final second = await cache(1);
    expect(second, first);
    expect(copies, 1);
    expect(File(first).readAsStringSync(), 'audio');

    final replaced = await cachedPlaybackFile(
      source: 'content://downloads/episode.mp3',
      cacheDirectory: root,
      copy: (source, dest) async {
        copies++;
        await File(dest).writeAsString('audioaudio');
      },
      sourceLength: (_) async => 10,
    );
    expect(replaced, first);
    expect(copies, 2);
    expect(File(replaced).readAsStringSync(), 'audioaudio');
  });
}
