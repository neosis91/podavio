import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/feed_text.dart';

void main() {
  test('a UTF-8 feed without charset keeps its accents', () {
    final bytes = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<rss><channel><title>La Terre au carré</title></channel></rss>',
    );

    final text = decodeFeedDocument(bytes, contentType: 'application/xml');

    expect(text, contains('carré'));
    expect(text.contains('Ã'), isFalse);
  });

  test('the XML encoding wins over a Latin-1 content type', () {
    final bytes = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<title>Faites entrer l’accusé</title>',
    );

    final text = decodeFeedDocument(
      bytes,
      contentType: 'text/xml; charset=iso-8859-1',
    );

    expect(text, contains('accusé'));
  });

  test('an ISO-8859-1 feed keeps the accent declared in the XML', () {
    const xml =
        '<?xml version="1.0" encoding="ISO-8859-1"?><title>café</title>';
    final text = decodeFeedDocument(
      latin1.encode(xml),
      contentType: 'text/xml',
    );

    expect(text, contains('café'));
  });

  test('stored Latin-1 titles get their accents back', () {
    const title = 'La Bible en un an : le podcast chrétien';
    final broken = latin1.decode(utf8.encode(title));

    expect(broken, isNot(title));
    expect(repairMojibake(broken), title);
    expect(repairMojibake(title), title);
    expect(repairMojibake('Émancipées, le podcast'), 'Émancipées, le podcast');
  });

  test('repair rewrites the saved podcast and episode titles', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const podcastTitle = 'Clef de voûte';
    const episodeTitle = 'Aliénor d’Aquitaine';
    final podcastId = await database
        .into(database.podcasts)
        .insert(
          PodcastsCompanion.insert(
            feedUrl: 'https://example.com/feed.xml',
            title: latin1.decode(utf8.encode(podcastTitle)),
            subscribedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await database
        .into(database.episodes)
        .insert(
          EpisodesCompanion.insert(
            podcastId: podcastId,
            guid: 'episode-1',
            title: latin1.decode(utf8.encode(episodeTitle)),
            audioUrl: 'https://example.com/episode.mp3',
          ),
        );

    await database.repairMojibakeText();

    final podcast = await database.findByFeedUrl(
      'https://example.com/feed.xml',
    );
    final episode = await (database.select(
      database.episodes,
    )..where((table) => table.guid.equals('episode-1'))).getSingle();
    expect(podcast?.title, podcastTitle);
    expect(episode.title, episodeTitle);
  });
}
