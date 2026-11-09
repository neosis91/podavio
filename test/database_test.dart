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

    final podcastId = (await database.saveFeed(draft)).podcastId;
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

    final podcastId = (await database.saveFeed(
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
    )).podcastId;

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

  test('oldest first starts a podcast at its first episode', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final podcastId = (await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Janvier',
            description: '',
            audioUrl: 'https://example.com/1.mp3',
            publishedAt: DateTime.utc(2024, 1, 1),
          ),
          EpisodeDraft(
            guid: 'ep-2',
            title: 'Mars',
            description: '',
            audioUrl: 'https://example.com/2.mp3',
            publishedAt: DateTime.utc(2024, 3, 1),
          ),
          EpisodeDraft(
            guid: 'ep-3',
            title: 'Avril',
            description: '',
            audioUrl: 'https://example.com/3.mp3',
            publishedAt: DateTime.utc(2024, 4, 1),
          ),
        ],
      ),
    )).podcastId;

    final newest = await database
        .watchEpisodeWindow(podcastId: podcastId)
        .first;
    expect(newest.map((entry) => entry.episode.title), [
      'Avril',
      'Mars',
      'Janvier',
    ]);

    final oldest = await database
        .watchEpisodeWindow(podcastId: podcastId, oldestFirst: true)
        .first;
    expect(oldest.map((entry) => entry.episode.title), [
      'Janvier',
      'Mars',
      'Avril',
    ]);
  });

  test('playback pages walk backward and prepend keeps queue order', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final sameDay = DateTime.utc(2024, 2, 1);
    final podcastId = (await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: '',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'A',
            description: '',
            audioUrl: 'https://example.com/a.mp3',
            publishedAt: DateTime.utc(2024, 1, 1),
          ),
          EpisodeDraft(
            guid: 'b',
            title: 'B',
            description: '',
            audioUrl: 'https://example.com/b.mp3',
            publishedAt: sameDay,
          ),
          EpisodeDraft(
            guid: 'c',
            title: 'C',
            description: '',
            audioUrl: 'https://example.com/c.mp3',
            publishedAt: sameDay,
          ),
          EpisodeDraft(
            guid: 'd',
            title: 'D',
            description: '',
            audioUrl: 'https://example.com/d.mp3',
            publishedAt: DateTime.utc(2024, 3, 1),
          ),
        ],
      ),
    )).podcastId;

    final all = await database.readPlaybackPage(
      podcastId: podcastId,
      limit: 10,
    );
    expect(all.entries.map((entry) => entry.episode.title), [
      'D',
      'C',
      'B',
      'A',
    ]);

    final anchor = all.entries[2];
    final before = await database.readPlaybackPage(
      podcastId: podcastId,
      before: anchor,
      limit: 1,
    );
    expect(before.entries.single.episode.title, 'C');
    expect(before.mayHaveMore, isTrue);

    final earlier = await database.readPlaybackPage(
      podcastId: podcastId,
      before: before.entries.single,
      limit: 10,
    );
    expect(earlier.entries.map((entry) => entry.episode.title), ['D']);
    expect(earlier.mayHaveMore, isFalse);

    final after = await database.readPlaybackPage(
      podcastId: podcastId,
      after: anchor,
      limit: 10,
    );
    expect(after.entries.map((entry) => entry.episode.title), ['A']);

    await database.replaceQueue([
      before.entries.single.episode.id,
      anchor.episode.id,
      after.entries.single.episode.id,
    ]);
    await database.prependToQueue([
      for (final entry in earlier.entries) entry.episode.id,
    ]);
    final queued = await database.watchEpisodeWindow(queuedOnly: true).first;
    expect(queued.map((entry) => entry.episode.title), ['D', 'C', 'B', 'A']);
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

    final alpha = (await database.saveFeed(
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
    )).podcastId;
    final beta = (await database.saveFeed(
      FeedDraft(
        feedUrl: 'https://example.com/beta.xml',
        title: 'Beta',
        author: '',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'b1',
            title: 'À peine commencé',
            description: '',
            audioUrl: 'https://example.com/b1.mp3',
            publishedAt: DateTime.utc(2024, 2, 1),
          ),
        ],
      ),
    )).podcastId;
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
    await database.setPodcastPreferred(beta, preferred: true);

    final alphaEpisodes = await database.watchEpisodes(podcastId: alpha).first;
    final started = alphaEpisodes.singleWhere(
      (entry) => entry.episode.title == 'Déjà commencé',
    );
    await database.setPosition(started.episode.id, 4000);
    await database.setDownloadPath(started.episode.id, '/tmp/episode.mp3');

    final betaEpisodes = await database.watchEpisodes(podcastId: beta).first;
    await database.setPosition(betaEpisodes.single.episode.id, 9000);

    // Préférés d’abord (Beta plus écouté que Zèbre), puis Alpha (écoute).
    final ordered = await database.watchPodcastsByPreference().first;
    expect(ordered.map((podcast) => podcast.title), ['Beta', 'Zèbre', 'Alpha']);

    final progress = await database.watchInProgress().first;
    expect(
      progress.map((entry) => entry.episode.title),
      containsAll(['Déjà commencé', 'À peine commencé']),
    );
    final fresh = await database.watchFreshEpisodes().first;
    expect(fresh.map((entry) => entry.episode.title), ['Tout neuf']);
    final downloads = await database.watchRecentDownloads().first;
    expect(downloads.single.episode.downloadedAt, isNotNull);

    await database.setPlayed(started.episode.id, played: true);
    final random = await database.randomEpisodes(limit: 10);
    expect(random.map((entry) => entry.episode.title).toSet(), {
      'Tout neuf',
      'À peine commencé',
    });
  });

  test('podcastStats and libraryStats use aggregates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final podcastId = (await database.saveFeed(
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
    )).podcastId;

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

    final podcastId = (await database.saveFeed(
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
    )).podcastId;

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

    await database.queueNext(outside, afterEpisodeId: first);
    final queued = await database.watchEpisodeWindow(queuedOnly: true).first;
    expect(queued.map((entry) => entry.episode.id).toList(), [
      first,
      outside,
      second,
      third,
    ]);
  });

  test('custom playlists keep order and the default one stays', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final initial = await database.watchPlaylists().first;
    expect(initial, hasLength(1));
    expect(initial.single.isDefault, isTrue);
    expect(initial.single.name, 'Playlist');
    await database.deletePlaylist(initial.single.id);
    expect(await database.watchPlaylists().first, hasLength(1));

    final podcastId = (await database.saveFeed(
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
        ],
      ),
    )).podcastId;
    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    final byTitle = {
      for (final entry in episodes) entry.episode.title: entry.episode.id,
    };
    final first = byTitle['Un']!;
    final second = byTitle['Deux']!;
    final custom = await database.createPlaylist('Soir');
    await database.addToPlaylist(custom, second);
    await database.addToPlaylist(custom, first);
    expect(
      (await database.watchPlaylistEpisodes(custom).first)
          .map((entry) => entry.episode.id)
          .toList(),
      [second, first],
    );
    await database.setPlaylistOrder(custom, [first, second]);
    expect(
      (await database.watchPlaylistEpisodes(custom).first)
          .map((entry) => entry.episode.id)
          .toList(),
      [first, second],
    );

    await database.addToPlaylist(initial.single.id, first);
    final queued = await database.watchEpisodeWindow(queuedOnly: true).first;
    expect(queued.single.episode.id, first);

    await database.renamePlaylist(custom, 'Matin');
    final named = await database.watchPlaylists().first;
    expect(named.map((playlist) => playlist.name), ['Playlist', 'Matin']);
    expect(named.first.episodeCount, 1);
    expect(named.last.episodeCount, 2);

    await database.deletePlaylist(custom);
    final remaining = await database.watchPlaylists().first;
    expect(remaining.map((playlist) => playlist.id), [initial.single.id]);
  });

  test(
    'saveFeed reports new episodes only for an existing subscription',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final created = await database.saveFeed(
        _feed('https://example.com/show.xml', const [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Archive',
            description: '',
            audioUrl: 'https://example.com/1.mp3',
          ),
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Doublon',
            description: '',
            audioUrl: 'https://example.com/1b.mp3',
          ),
        ]),
      );
      expect(created.newEpisodeIds, isEmpty);
      final archived = await database
          .watchEpisodes(podcastId: created.podcastId)
          .first;
      expect(archived, hasLength(1));

      final refreshed = await database.saveFeed(
        _feed('https://example.com/show.xml', [
          const EpisodeDraft(
            guid: 'ep-1',
            title: 'Archive revue',
            description: 'Notes',
            audioUrl: 'https://example.com/1.mp3',
          ),
          const EpisodeDraft(
            guid: 'ep-2',
            title: 'Nouveau',
            description: '',
            audioUrl: 'https://example.com/2.mp3',
          ),
          const EpisodeDraft(
            guid: 'ep-3',
            title: 'Suivant',
            description: '',
            audioUrl: 'https://example.com/3.mp3',
          ),
          const EpisodeDraft(
            guid: 'ep-3',
            title: 'Suivant encore',
            description: '',
            audioUrl: 'https://example.com/3b.mp3',
          ),
        ]),
      );
      final byGuid = {
        for (final entry
            in await database.watchEpisodes(podcastId: created.podcastId).first)
          entry.episode.guid: entry.episode,
      };
      expect(refreshed.podcastId, created.podcastId);
      expect(refreshed.newEpisodeIds, [byGuid['ep-2']!.id, byGuid['ep-3']!.id]);
      expect(byGuid['ep-1']!.title, 'Archive revue');
      expect(byGuid, hasLength(3));

      final unchanged = await database.saveFeed(
        _feed('https://example.com/show.xml', const [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Archive revue',
            description: 'Notes',
            audioUrl: 'https://example.com/1.mp3',
          ),
          EpisodeDraft(
            guid: 'ep-2',
            title: 'Nouveau',
            description: '',
            audioUrl: 'https://example.com/2.mp3',
          ),
          EpisodeDraft(
            guid: 'ep-3',
            title: 'Suivant',
            description: '',
            audioUrl: 'https://example.com/3.mp3',
          ),
        ]),
      );
      expect(unchanged.newEpisodeIds, isEmpty);

      final preview = await database.saveFeed(
        _feed('https://example.com/preview.xml', const [
          EpisodeDraft(
            guid: 'p-1',
            title: 'Aperçu',
            description: '',
            audioUrl: 'https://example.com/p1.mp3',
          ),
        ]),
        subscribed: false,
      );
      expect(preview.newEpisodeIds, isEmpty);

      final previewRefresh = await database.saveFeed(
        _feed('https://example.com/preview.xml', const [
          EpisodeDraft(
            guid: 'p-1',
            title: 'Aperçu',
            description: '',
            audioUrl: 'https://example.com/p1.mp3',
          ),
          EpisodeDraft(
            guid: 'p-2',
            title: 'Toujours un aperçu',
            description: '',
            audioUrl: 'https://example.com/p2.mp3',
          ),
        ]),
      );
      expect(previewRefresh.newEpisodeIds, isEmpty);

      final firstSubscribe = await database.saveFeed(
        _feed('https://example.com/preview.xml', const [
          EpisodeDraft(
            guid: 'p-1',
            title: 'Aperçu',
            description: '',
            audioUrl: 'https://example.com/p1.mp3',
          ),
          EpisodeDraft(
            guid: 'p-2',
            title: 'Toujours un aperçu',
            description: '',
            audioUrl: 'https://example.com/p2.mp3',
          ),
          EpisodeDraft(
            guid: 'p-3',
            title: 'Arrivé avec l’abonnement',
            description: '',
            audioUrl: 'https://example.com/p3.mp3',
          ),
        ]),
        subscribed: true,
      );
      expect(firstSubscribe.newEpisodeIds, isEmpty);

      final afterSubscribe = await database.saveFeed(
        _feed('https://example.com/preview.xml', const [
          EpisodeDraft(
            guid: 'p-1',
            title: 'Aperçu',
            description: '',
            audioUrl: 'https://example.com/p1.mp3',
          ),
          EpisodeDraft(
            guid: 'p-2',
            title: 'Toujours un aperçu',
            description: '',
            audioUrl: 'https://example.com/p2.mp3',
          ),
          EpisodeDraft(
            guid: 'p-3',
            title: 'Arrivé avec l’abonnement',
            description: '',
            audioUrl: 'https://example.com/p3.mp3',
          ),
          EpisodeDraft(
            guid: 'p-4',
            title: 'Après l’abonnement',
            description: '',
            audioUrl: 'https://example.com/p4.mp3',
          ),
        ]),
      );
      final subscribedEpisodes = await database
          .watchEpisodes(podcastId: preview.podcastId)
          .first;
      final arrived = subscribedEpisodes.singleWhere(
        (entry) => entry.episode.guid == 'p-4',
      );
      expect(afterSubscribe.newEpisodeIds, [arrived.episode.id]);
    },
  );

  test('saveFeed stores podcast persons and funding', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final saved = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/people.xml',
        title: 'Émission',
        author: 'Alice, Bob',
        description: '',
        persons: [
          PodcastPerson(
            name: 'Alice',
            role: 'host',
            link: 'https://alice.example',
          ),
          PodcastPerson(name: 'Bob', role: 'guest'),
        ],
        funding: [
          PodcastFunding(url: 'https://donate.example', label: 'Soutenir'),
        ],
        episodes: [],
      ),
    );
    final podcast = await database.getPodcast(saved.podcastId);
    expect(podcast, isNotNull);
    expect(podcast!.persons, hasLength(2));
    expect(podcast.persons.first.name, 'Alice');
    expect(podcast.persons.first.role, 'host');
    expect(podcast.fundingLinks, hasLength(1));
    expect(podcast.fundingLinks.single.label, 'Soutenir');
  });

  test(
    'automatic download keeps unplayed and in-progress episodes only',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final podcastId = (await database.saveFeed(
        _feed('https://example.com/auto.xml', [
          EpisodeDraft(
            guid: 'unread',
            title: 'Non lu',
            description: '',
            audioUrl: 'https://example.com/unread.mp3',
            publishedAt: DateTime.utc(2026, 1, 1),
          ),
          EpisodeDraft(
            guid: 'progress',
            title: 'En cours',
            description: '',
            audioUrl: 'https://example.com/progress.mp3',
            publishedAt: DateTime.utc(2026, 2, 1),
          ),
          EpisodeDraft(
            guid: 'played',
            title: 'Lu',
            description: '',
            audioUrl: 'https://example.com/played.mp3',
            publishedAt: DateTime.utc(2026, 3, 1),
          ),
          EpisodeDraft(
            guid: 'file',
            title: 'Déjà là',
            description: '',
            audioUrl: 'https://example.com/file.mp3',
            publishedAt: DateTime.utc(2026, 4, 1),
          ),
        ]),
      )).podcastId;
      await database.setPodcastAutoDownload(podcastId, autoDownload: true);
      final episodes = await database.episodesForPodcast(podcastId);
      final byGuid = {for (final episode in episodes) episode.guid: episode};
      await database.setPosition(byGuid['progress']!.id, 12000);
      await database.setPlayed(byGuid['played']!.id, played: true);
      await database.setDownloadPath(byGuid['file']!.id, '/tmp/file.mp3');

      final candidates = await database.automaticDownloadCandidates();
      expect(candidates.map((episode) => episode.id).toSet(), {
        byGuid['unread']!.id,
        byGuid['progress']!.id,
      });
    },
  );
}

FeedDraft _feed(String url, List<EpisodeDraft> episodes) {
  return FeedDraft(
    feedUrl: url,
    title: 'Essai',
    author: 'Auteur',
    description: 'Description',
    episodes: episodes,
  );
}
