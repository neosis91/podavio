import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/spotify_feed.dart';

void main() {
  test('spotify show links become a canonical page', () {
    expect(
      spotifyShowLink('https://open.spotify.com/intl-fr/show/abc123?si=xyz')
          ?.pageUrl,
      'https://open.spotify.com/show/abc123',
    );
    expect(
      spotifyShowLink('spotify:show:abc123')?.pageUrl,
      'https://open.spotify.com/show/abc123',
    );
    expect(spotifyShowLink('https://example.com/feed.xml'), isNull);
  });

  test('an episode link is refused', () {
    expect(
      () => spotifyShowLink('https://open.spotify.com/episode/abc123'),
      throwsFormatException,
    );
  });

  test('open graph tags identify the show', () {
    const html = '''
<meta property="og:title" content="Transfert"/>
<meta property="og:description" content="Podcast · Slate · Des récits."/>
''';
    final show = spotifyShowFromHtml(html);
    expect(show?.title, 'Transfert');
    expect(show?.author, 'Slate');
  });

  test('a public feed is chosen when the title matches', () {
    final feed = matchingFeedUrl(
      title: 'Transfert',
      author: 'Slate',
      candidates: const [
        FeedCandidate(
          title: 'Autre',
          author: 'Slate',
          feedUrl: 'https://example.com/autre.xml',
        ),
        FeedCandidate(
          title: 'Transfert',
          author: 'Slate Podcasts',
          feedUrl: 'https://example.com/transfert.xml',
        ),
      ],
    );
    expect(feed, 'https://example.com/transfert.xml');
    expect(
      matchingFeedUrl(
        title: 'Réservé Spotify',
        author: 'Studio',
        candidates: const [
          FeedCandidate(
            title: 'Autre chose',
            author: 'Studio',
            feedUrl: 'https://example.com/autre.xml',
          ),
        ],
      ),
      isNull,
    );
  });
}
