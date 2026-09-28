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

  test('buildOpml roundtrips subscriptions', () {
    final podcast = Podcast(
      id: 1,
      feedUrl: 'https://a.example/feed',
      title: 'A & B',
      author: '',
      description: '',
      subscribedAt: DateTime.utc(2026, 1, 1),
    );
    expect(parseOpml(buildOpml([podcast])), ['https://a.example/feed']);
  });
}
