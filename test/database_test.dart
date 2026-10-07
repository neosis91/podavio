import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';

void main() {
  test('refreshing a feed keeps listening progress', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const draft = FeedDraft(
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
          durationSeconds: 120,
          publishedAt: null,
        ),
      ],
    );

    final podcastId = await database.saveFeed(draft);
    final created = await database.watchEpisodes(podcastId: podcastId).first;
    final episodeId = created.single.episode.id;
    await database.setFavorite(episodeId, favorite: true);
    await database.addToQueue(episodeId);
    await database.setPosition(episodeId, 15000);

    await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai mis à jour',
        author: 'Auteur',
        description: 'Nouvelle description',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Premier épisode',
            description: 'Notes revues',
            audioUrl: 'https://example.com/1.mp3',
            durationSeconds: 130,
          ),
        ],
      ),
    );

    final updated = await database.watchEpisodes(podcastId: podcastId).first;
    final episode = updated.single.episode;
    expect(updated.single.podcast.title, 'Essai mis à jour');
    expect(episode.title, 'Premier épisode');
    expect(episode.durationSeconds, 130);
    expect(episode.favorite, isTrue);
    expect(episode.queueIndex, 0);
    expect(episode.positionMs, 15000);
    expect(episode.played, isFalse);
  });

  test('episode windows load a page without show notes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final podcastId = await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Un',
            description: 'Notes secrètes',
            audioUrl: 'https://example.com/1.mp3',
            publishedAt: DateTime.utc(2024, 1, 1),
          ),
          const EpisodeDraft(
            guid: 'ep-2',
            title: 'Deux',
            description: 'Autre',
            audioUrl: 'https://example.com/2.mp3',
            publishedAt: null,
          ),
          EpisodeDraft(
            guid: 'ep-3',
            title: 'Trois',
            description: 'Suite',
            audioUrl: 'https://example.com/3.mp3',
            publishedAt: DateTime.utc(2024, 3, 1),
          ),
          EpisodeDraft(
            guid: 'ep-4',
            title: 'Épisode accentué',
            description: '',
            audioUrl: 'https://example.com/4.mp3',
            publishedAt: DateTime.utc(2024, 4, 1),
          ),
        ],
      ),
    );

    final page = await database
        .watchEpisodeWindow(podcastId: podcastId, limit: 2)
        .first;
    expect(page.map((entry) => entry.episode.title), [
      'Épisode accentué',
      'Trois',
    ]);
    expect(page.first.episode.description, isEmpty);

    final found = await database
        .watchEpisodeWindow(podcastId: podcastId, search: 'deux')
        .first;
    expect(found.single.episode.title, 'Deux');
    expect(found.single.episode.description, isEmpty);

    final accent = await database
        .watchEpisodeWindow(podcastId: podcastId, search: 'episode')
        .first;
    expect(accent.single.episode.title, 'Épisode accentué');

    final letterE = await database
        .watchEpisodeWindow(podcastId: podcastId, search: 'e')
        .first;
    expect(
      letterE.map((e) => e.episode.title),
      containsAll(['Deux', 'Trois', 'Épisode accentué']),
    );
  });

  test('subscriptions are ordered by latest episode date', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/old.xml',
        title: 'Ancien',
        author: '',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'old-1',
            title: 'Vieux',
            description: '',
            audioUrl: 'https://example.com/old.mp3',
            publishedAt: DateTime.utc(2024, 1, 1),
          ),
        ],
      ),
    );
    await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/new.xml',
        title: 'Récent',
        author: '',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'new-1',
            title: 'Frais',
            description: '',
            audioUrl: 'https://example.com/new.mp3',
            publishedAt: DateTime.utc(2024, 6, 1),
          ),
        ],
      ),
    );
    await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/empty.xml',
        title: 'Vide',
        author: '',
        description: '',
        episodes: [],
      ),
    );

    final ordered = await database.watchPodcasts().first;
    expect(ordered.map((podcast) => podcast.title), [
      'Récent',
      'Ancien',
      'Vide',
    ]);
  });

  test('home rows split progress, new episodes and preferred shows', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final alpha = await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/alpha.xml',
        title: 'Alpha',
        author: '',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'a1',
            title: 'Déjà commencé',
            description: '',
            audioUrl: 'https://example.com/a1.mp3',
            publishedAt: DateTime.utc(2024, 2, 1),
          ),
          EpisodeDraft(
            guid: 'a2',
            title: 'Tout neuf',
            description: '',
            audioUrl: 'https://example.com/a2.mp3',
            publishedAt: DateTime.utc(2024, 3, 1),
          ),
        ],
      ),
    );
    await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/zeta.xml',
        title: 'Zèbre',
        author: '',
        description: '',
        episodes: [],
      ),
    );

    final shows = await database.listPodcasts();
    final zebra = shows.singleWhere((podcast) => podcast.title == 'Zèbre');
    await database.setPodcastPreferred(zebra.id, preferred: true);
    final ordered = await database.watchPodcastsByPreference().first;
    expect(ordered.map((podcast) => podcast.title), ['Zèbre', 'Alpha']);

    final episodes = await database.watchEpisodes(podcastId: alpha).first;
    final started = episodes.singleWhere(
      (entry) => entry.episode.title == 'Déjà commencé',
    );
    await database.setPosition(started.episode.id, 4000);
    await database.setDownloadPath(started.episode.id, '/tmp/episode.mp3');

    final progress = await database.watchInProgress().first;
    expect(progress.single.episode.title, 'Déjà commencé');
    final fresh = await database.watchFreshEpisodes().first;
    expect(fresh.map((entry) => entry.episode.title), ['Tout neuf']);
    final downloads = await database.watchRecentDownloads().first;
    expect(downloads.single.episode.downloadedAt, isNotNull);

    await database.setPlayed(started.episode.id, played: true);
    final random = await database.randomEpisodes(limit: 10);
    expect(random.map((entry) => entry.episode.title), ['Tout neuf']);
  });

  test('podcastStats and libraryStats use aggregates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final podcastId = await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/stats.xml',
        title: 'Stats',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 's1',
            title: 'Ancien',
            description: '',
            audioUrl: 'https://example.com/s1.mp3',
            durationSeconds: 100,
            publishedAt: DateTime.utc(2024, 1, 1),
          ),
          EpisodeDraft(
            guid: 's2',
            title: 'En cours',
            description: '',
            audioUrl: 'https://example.com/s2.mp3',
            durationSeconds: 200,
            publishedAt: DateTime.utc(2024, 1, 8),
          ),
          EpisodeDraft(
            guid: 's3',
            title: 'Neuf',
            description: '',
            audioUrl: 'https://example.com/s3.mp3',
            durationSeconds: 300,
            publishedAt: DateTime.utc(2024, 1, 15),
          ),
        ],
      ),
    );

    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    final byTitle = {
      for (final entry in episodes) entry.episode.title: entry.episode.id,
    };
    await database.setPlayed(byTitle['Ancien']!, played: true);
    await database.setPosition(byTitle['En cours']!, 45000);
    await database.setFavorite(byTitle['Neuf']!, favorite: true);
    await database.setDownloadPath(byTitle['Neuf']!, '/tmp/s3.mp3');

    final stats = await database.podcastStats(podcastId);
    expect(stats.episodeCount, 3);
    expect(stats.completedCount, 1);
    expect(stats.inProgressCount, 1);
    expect(stats.unreadCount, 2);
    expect(stats.startedCount, 2);
    expect(stats.favoriteCount, 1);
    expect(stats.downloadCount, 1);
    expect(stats.listenedSeconds, 100 + 45);
    expect(stats.totalDurationSeconds, 600);
    expect(stats.averageDurationSeconds, 200);
    expect(stats.releaseInterval, const Duration(hours: 7 * 24));
    expect(stats.lastPublishedAt?.toUtc(), DateTime.utc(2024, 1, 15));

    final library = await database.libraryStats();
    expect(library.podcastCount, 1);
    expect(library.episodeCount, 3);
    expect(library.totalListenedSeconds, 145);
    expect(library.totalDownloadCount, 1);
    expect(library.subscriptions.single.completedCount, 1);
    expect(library.subscriptions.single.startedCount, 2);

    final signal = await database.watchPodcastStatsSignal(podcastId).first;
    expect(signal.$1, 3); // count
    expect(signal.$4, 1); // played
    expect(signal.$5, 1); // favorite
    expect(signal.$6, 1); // download
  });

  test('previousInQueue stays inside the playlist', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final podcastId = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'Un',
            description: '',
            audioUrl: 'https://example.com/1.mp3',
          ),
          EpisodeDraft(
            guid: 'b',
            title: 'Deux',
            description: '',
            audioUrl: 'https://example.com/2.mp3',
          ),
          EpisodeDraft(
            guid: 'c',
            title: 'Trois',
            description: '',
            audioUrl: 'https://example.com/3.mp3',
          ),
          EpisodeDraft(
            guid: 'd',
            title: 'Hors file',
            description: '',
            audioUrl: 'https://example.com/4.mp3',
          ),
        ],
      ),
    );

    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    final byTitle = {
      for (final entry in episodes) entry.episode.title: entry.episode.id,
    };
    final first = byTitle['Un']!;
    final second = byTitle['Deux']!;
    final third = byTitle['Trois']!;
    final outside = byTitle['Hors file']!;
    await database.addToQueue(first);
    await database.addToQueue(second);
    await database.addToQueue(third);

    expect(await database.previousInQueue(), isNull);
    expect(await database.previousInQueue(beforeEpisodeId: first), isNull);
    expect(
      (await database.previousInQueue(beforeEpisodeId: second))?.episode.id,
      first,
    );
    expect(
      (await database.previousInQueue(beforeEpisodeId: third))?.episode.id,
      second,
    );
    expect(await database.previousInQueue(beforeEpisodeId: outside), isNull);
  });
}
