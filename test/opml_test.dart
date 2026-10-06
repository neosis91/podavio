import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/opml.dart';

void main() {
  test('parseOpml keeps unique feed urls', () {
    const xml = '''
<opml version="2.0">
  <body>
    <outline text="A" xmlUrl="https://a.example/feed"/>
    <outline text="B" url="https://b.example/feed"/>
    <outline text="A again" xmlUrl="https://a.example/feed"/>
    <outline text="Empty" xmlUrl="  "/>
  </body>
</opml>
''';
    expect(parseOpml(xml), [
      'https://a.example/feed',
      'https://b.example/feed',
    ]);
  });

  test('parseOpmlEntries keeps title and optional image', () {
    const xml = '''
<opml version="2.0">
  <body>
    <outline text="Show A" title="Show A" xmlUrl="https://a.example/feed" imageUrl="https://a.example/cover.jpg"/>
    <outline text="Nested">
      <outline text="Show B" XMLURL="https://b.example/feed/" icon="https://b.example/icon.png"/>
    </outline>
  </body>
</opml>
''';
    final entries = parseOpmlEntries(xml);
    expect(entries, hasLength(2));
    expect(entries[0].title, 'Show A');
    expect(entries[0].imageUrl, 'https://a.example/cover.jpg');
    expect(entries[1].title, 'Show B');
    expect(entries[1].feedUrl, 'https://b.example/feed/');
    expect(entries[1].imageUrl, 'https://b.example/icon.png');
    expect(normalizeFeedUrl(entries[1].feedUrl), 'https://b.example/feed');
  });

  test('buildOpml roundtrips subscriptions', () {
    final podcast = Podcast(
      id: 1,
      feedUrl: 'https://a.example/feed',
      title: 'A & B',
      author: '',
      description: '',
      imageUrl: 'https://a.example/cover.jpg',
      subscribedAt: DateTime.utc(2026, 1, 1),
      preferred: false,
      autoDownload: false,
      keepUpdated: true,
      subscribed: true,
      skipIntroSeconds: 0,
      skipOutroSeconds: 0,
    );
    final entries = parseOpmlEntries(buildOpml([podcast]));
    expect(entries, hasLength(1));
    expect(entries.single.feedUrl, 'https://a.example/feed');
    expect(entries.single.imageUrl, 'https://a.example/cover.jpg');
  });
}
