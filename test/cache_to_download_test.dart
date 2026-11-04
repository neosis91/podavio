import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';

void main() {
  test('a cached episode is saved as a download without fetching it', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final root = await Directory.systemTemp.createTemp(
      'podavio-cache-download',
    );
    addTearDown(() => root.delete(recursive: true));
    final downloads = Directory('${root.path}/downloads')..createSync();
    final cache = File('${root.path}/stream-12.mp3');
    await cache.writeAsBytes([1, 2, 3, 4]);

    final podcastId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Premier: soir',
            description: '',
            audioUrl: 'https://example.com/secret-source.mp3',
          ),
        ],
      ),
    )).podcastId;
    final created = await database.watchEpisodes(podcastId: podcastId).first;
    final episode = created.single.episode;
    await database.setCachePath(episode.id, cache.path);

    final progress = <double>[];
    await DownloadService(database).download(
      episode.copyWith(cachePath: const Value(null)),
      directory: downloads.path,
      onProgress: progress.add,
    );

    final saved = (await database.episodeById(episode.id))!;
    final name = '[Essai] Premier soir.mp3';
    expect(saved.downloadPath, '${downloads.path}/$name');
    expect(saved.cachePath, isNull);
    expect(File(saved.downloadPath!).readAsBytesSync(), [1, 2, 3, 4]);
    expect(cache.existsSync(), isFalse);
    expect(progress, [1]);
  });
}
