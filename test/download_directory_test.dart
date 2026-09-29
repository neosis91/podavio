import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/download_service.dart';
import 'package:podavio/data/models.dart';

void main() {
  test('changing the download folder moves existing files', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final root = await Directory.systemTemp.createTemp('podavio-downloads');
    addTearDown(() => root.delete(recursive: true));
    final from = Directory('${root.path}/from')..createSync();
    final to = Directory('${root.path}/to')..createSync();

    final podcastId = await database.saveFeed(
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
          EpisodeDraft(
            guid: 'ep-2',
            title: 'Second',
            description: 'Notes',
            audioUrl: 'https://example.com/2.mp3',
          ),
        ],
      ),
    );
    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    final present = episodes.first.episode;
    final missing = episodes.last.episode;
    final source = File('${from.path}/${present.id}.mp3');
    await source.writeAsString('audio');
    await database.setDownloadPath(present.id, source.path);
    await database.setDownloadPath(missing.id, '${from.path}/absent.mp3');

    final result = await DownloadService(database)
        .relocateDownloads(from: from.path, to: to.path);

    expect(result.moved, 1);
    expect(result.failed, 0);
    expect(source.existsSync(), isFalse);
    final stored = await database.downloadedEpisodes();
    final moved = stored.singleWhere((episode) => episode.id == present.id);
    final left = stored.singleWhere((episode) => episode.id == missing.id);
    expect(moved.downloadPath, '${to.path}/${present.id}.mp3');
    expect(File(moved.downloadPath!).readAsStringSync(), 'audio');
    expect(left.downloadPath, '${from.path}/absent.mp3');
  });
}
