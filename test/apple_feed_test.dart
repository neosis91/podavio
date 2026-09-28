import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/apple_feed.dart';

void main() {
  test('the show feed is read from the Apple page', () {
    const html = '''
https://amp-api.podcasts.apple.com/v1/catalog/fr/podcasts/916500028?extend=feedUrl
"adamId":"916500028","feedUrl":"https://radiofrance-podcast.net/podcast09/show.xml"
"feedUrl":"https://example.com/autre.xml"
''';
    expect(
      appleFeedUrlFromPage(html),
      'https://radiofrance-podcast.net/podcast09/show.xml',
    );
  });

  test('an escaped feed address is accepted', () {
    const html = r'"feedUrl":"https:\/\/cdn.example\/show\u0026lang=fr.xml"';
    expect(appleFeedUrlFromPage(html), 'https://cdn.example/show&lang=fr.xml');
  });

  test('a page without a public feed yields nothing', () {
    expect(appleFeedUrlFromPage('<html></html>'), isNull);
    expect(
      appleFeedUrlFromPage('"feedUrl":"https://podcasts.apple.com/id1"'),
      isNull,
    );
  });
}
