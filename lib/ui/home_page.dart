import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/cover_tone.dart';
import '../l10n/l10n.dart';
import '../data/app_database.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'library_hub_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/playing_cover.dart';
import 'widgets/episode_tile.dart';
import 'widgets/empty_state.dart';
import 'widgets/list_metrics.dart';

String _homeGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour <= 12) return 'Bonjour';
  if (hour >= 13 && hour <= 17) return 'Bon après-midi';
  if (hour >= 18 && hour <= 23) return 'Bonsoir';
  return 'Bonne nuit';
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  /// Vrai dès que la liste quitte le haut : le fond passe du transparent au flou.
  var _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = ref.watch(inProgressProvider).value ?? const [];
    final fresh = ref.watch(freshEpisodesProvider).value ?? const [];
    final downloads = ref.watch(recentDownloadsProvider).value ?? const [];
    final favorites = ref.watch(favoriteEpisodesProvider).value ?? const [];
    final played = ref.watch(recentPlayedProvider).value ?? const [];
    final random = ref.watch(randomEpisodesProvider).value ?? const [];
    final podcasts = ref.watch(preferredPodcastsProvider);
    final subscriptions = podcasts.value ?? const <Podcast>[];
    final waiting = podcasts.isLoading && podcasts.value == null;

    final headerTop = MediaQuery.paddingOf(context).top + _headerToolbar;
    final shelves = <Widget>[
      if (inProgress.isNotEmpty) _ContinueShelf(entries: inProgress),
      if (fresh.isNotEmpty)
        _InlineSection(
          title: 'Les nouveautés',
          height: _episodeRowHeight,
          itemCount: fresh.length,
          onMore: () => context.push(AppRoutes.episodes),
          itemBuilder: (context, index) => _EpisodeCard(
            key: ValueKey(fresh[index].episode.id),
            entry: fresh[index],
          ),
        ),
      if (favorites.isNotEmpty)
        _InlineSection(
          title: context.tr('Favorites'),
          height: _episodeRowHeight,
          itemCount: favorites.length,
          onMore: () => context.push(AppRoutes.favorites),
          itemBuilder: (context, index) => _EpisodeCard(
            key: ValueKey(favorites[index].episode.id),
            entry: favorites[index],
          ),
        ),
      if (played.isNotEmpty)
        _InlineSection(
          title: context.tr('Recent plays'),
          height: _episodeRowHeight,
          itemCount: played.length,
          onMore: () => context.push(AppRoutes.history),
          itemBuilder: (context, index) => _EpisodeCard(
            key: ValueKey(played[index].episode.id),
            entry: played[index],
          ),
        ),
      if (random.isNotEmpty)
        _InlineSection(
          title: 'Aléatoire',
          height: _episodeRowHeight,
          itemCount: random.length,
          action: IconButton(
            tooltip: 'Autres épisodes',
            onPressed: () =>
                ref.read(randomEpisodesProvider.notifier).reshuffle(),
            icon: const Icon(Icons.shuffle),
          ),
          itemBuilder: (context, index) => _EpisodeCard(
            key: ValueKey(random[index].episode.id),
            entry: random[index],
          ),
        ),
      if (subscriptions.isNotEmpty)
        _InlineSection(
          title: 'Abonnements préférés',
          height: _podcastRowHeight,
          itemCount: subscriptions.length,
          onMore: () => context.go(AppRoutes.podcasts),
          itemBuilder: (context, index) => _PodcastCard(
            key: ValueKey(subscriptions[index].id),
            podcast: subscriptions[index],
          ),
        ),
      if (downloads.isNotEmpty)
        _InlineSection(
          title: 'Derniers téléchargements',
          height: _episodeRowHeight,
          itemCount: downloads.length,
          onMore: () => context.push(AppRoutes.downloads),
          itemBuilder: (context, index) => _EpisodeCard(
            key: ValueKey(downloads[index].episode.id),
            entry: downloads[index],
          ),
        ),
    ];
    final washEntry = inProgress.isNotEmpty
        ? inProgress.first
        : fresh.isNotEmpty
        ? fresh.first
        : favorites.isNotEmpty
        ? favorites.first
        : played.isNotEmpty
        ? played.first
        : random.isNotEmpty
        ? random.first
        : downloads.isNotEmpty
        ? downloads.first
        : null;
    final filled =
        subscriptions.isNotEmpty ||
        inProgress.isNotEmpty ||
        fresh.isNotEmpty ||
        favorites.isNotEmpty ||
        played.isNotEmpty ||
        random.isNotEmpty ||
        downloads.isNotEmpty;
    return Scaffold(
      body: Stack(
        children: [
          if (waiting)
            Padding(
              padding: EdgeInsets.only(top: headerTop),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (!filled)
            Padding(
              padding: EdgeInsets.only(top: headerTop),
              child: EmptyState(
                title: context.tr('Nothing to play right now'),
                message: context.tr(
                  'Add a subscription to fill the home screen.',
                ),
                action: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.discover),
                  icon: const Icon(Icons.explore),
                  label: Text(context.tr('Explore')),
                ),
              ),
            )
          else
            ListView(
              controller: _scroll,
              padding: underChrome(context, const EdgeInsets.only(bottom: 24)),
              children: [
                for (var i = 0; i < shelves.length; i++)
                  if (i == 0)
                    _ShelfWash(
                      topGap: headerTop,
                      entry: washEntry,
                      podcast: washEntry == null && subscriptions.isNotEmpty
                          ? subscriptions.first
                          : null,
                      child: shelves[i],
                    )
                  else
                    shelves[i],
              ],
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _HomeHeaderOverlay(scrolled: _scrolled),
          ),
        ],
      ),
    );
  }
}

/// Hauteur de la barre (hors encoche), identique à l’ancien toolbar.
const _headerToolbar = 72.0;

class _HomeHeaderOverlay extends StatelessWidget {
  const _HomeHeaderOverlay({required this.scrolled});

  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final frostAlpha = surface.computeLuminance() >= 0.5 ? 0.35 : 0.55;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + _headerToolbar,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: scrolled ? 1 : 0),
        duration: const Duration(milliseconds: 300),
        builder: (context, t, child) {
          final tint = ColoredBox(
            color: surface.withValues(alpha: frostAlpha * t),
            child: const SizedBox.expand(),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              if (t > 0)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24 * t, sigmaY: 24 * t),
                    child: tint,
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: top, left: 16, right: 4),
                child: child,
              ),
            ],
          );
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PodavioLogo(width: 118),
                  const SizedBox(height: 4),
                  Text(_homeGreeting(), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const HistoryButton(),
            const PreferencesButton(),
          ],
        ),
      ),
    );
  }
}

const _cardWidth = 160.0;
const _episodeRowHeight = 236.0;
const _podcastWidth = 160.0;
const _podcastRowHeight = 220.0;
const _quickRowHeight = 72.0;

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.title, this.action, this.onMore});

  final String title;
  final Widget? action;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.bodySmall,
              ),
              child: Text(context.tr('More')),
            ),
          ?action,
        ],
      ),
    );
  }
}

class _InlineSection extends StatelessWidget {
  const _InlineSection({
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.action,
    this.onMore,
  });

  final String title;
  final double height;
  final int itemCount;
  final Widget? action;
  final VoidCallback? onMore;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(title: title, action: action, onMore: onMore),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

class _ContinueShelf extends ConsumerWidget {
  const _ContinueShelf({required this.entries});

  final List<EpisodeEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = entries.length >= 3 ? 3 : entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShelfHeader(title: 'Continuer d’écouter'),
        SizedBox(
          height: rows * _quickRowHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 30).clamp(
                220.0,
                constraints.maxWidth,
              );
              return GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: rows,
                  mainAxisExtent: itemWidth,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) => _ContinueRow(
                  key: ValueKey(entries[index].episode.id),
                  entry: entries[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueRow extends ConsumerWidget {
  const _ContinueRow({super.key, required this.entry});

  final EpisodeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episode = entry.episode;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    final duration = episode.durationSeconds;
    final fraction = duration == null || duration == 0
        ? null
        : (episode.positionMs / (duration * 1000)).clamp(0.0, 1.0);
    final current = ref.watch(
      playerProvider.select((state) => state.episodeId == episode.id),
    );
    return Material(
      color: current
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(AppRoutes.episode(episode.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              PlayingEpisodeCover(
                episodeId: episode.id,
                url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
                localPath: entry.imagePath(
                  preferPodcastCover: preferPodcastCover,
                ),
                httpHeaders: podcastAuthHeaders(
                  username: entry.podcast.authUsername,
                  password: entry.podcast.authPassword,
                ),
                size: 44,
                radius: 10,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    EpisodeListSubtitle(
                      entry: entry,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (fraction != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dégradé de la première étagère, calé sur la pochette, qui s’éteint
/// vers le fond de la page.
class _ShelfWash extends ConsumerStatefulWidget {
  const _ShelfWash({
    required this.topGap,
    required this.child,
    this.entry,
    this.podcast,
  });

  final double topGap;
  final EpisodeEntry? entry;
  final Podcast? podcast;
  final Widget child;

  @override
  ConsumerState<_ShelfWash> createState() => _ShelfWashState();
}

class _ShelfWashState extends ConsumerState<_ShelfWash> {
  Color? _color;
  String? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ShelfWash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.episode.id != widget.entry?.episode.id ||
        oldWidget.podcast?.id != widget.podcast?.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final prefer = ref.read(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    final entry = widget.entry;
    final podcast = widget.podcast;
    final path =
        entry?.imagePath(preferPodcastCover: prefer) ?? podcast?.imagePath;
    final url =
        entry?.imageUrl(preferPodcastCover: prefer) ?? podcast?.imageUrl;
    final source = podcast ?? entry?.podcast;
    final request = '${path ?? ''}\n${url ?? ''}';
    if (request == _loaded) return;
    final tone = await loadCoverTone(
      path: path,
      url: url,
      headers: source == null
          ? null
          : podcastAuthHeaders(
              username: source.authUsername,
              password: source.authPassword,
            ),
    );
    if (!mounted) return;
    final current = widget.entry;
    final currentPodcast = widget.podcast;
    final currentPath =
        current?.imagePath(preferPodcastCover: prefer) ??
        currentPodcast?.imagePath;
    final currentUrl =
        current?.imageUrl(preferPodcastCover: prefer) ??
        currentPodcast?.imageUrl;
    if ('${currentPath ?? ''}\n${currentUrl ?? ''}' != request) return;
    setState(() {
      _loaded = request;
      _color = tone?.background;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final tint = _color;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: const Alignment(-1, -0.2),
                end: const Alignment(0.4, 1),
                colors: [
                  tint.withValues(alpha: 0.5),
                  tint.withValues(alpha: 0.18),
                  surface.withValues(alpha: 0),
                ],
                stops: const [0, 0.42, 1],
              ),
      ),
      child: Column(
        children: [
          SizedBox(height: widget.topGap),
          widget.child,
        ],
      ),
    );
  }
}

class _EpisodeCard extends ConsumerWidget {
  const _EpisodeCard({super.key, required this.entry});

  final EpisodeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episode = entry.episode;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    return SizedBox(
      width: _cardWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(AppRoutes.episode(episode.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastCover(
              url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
              localPath: entry.imagePath(
                preferPodcastCover: preferPodcastCover,
              ),
              httpHeaders: podcastAuthHeaders(
                username: entry.podcast.authUsername,
                password: entry.podcast.authPassword,
              ),
              size: _cardWidth,
              radius: 10,
            ),
            const SizedBox(height: 8),
            Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(height: 1.25),
            ),
            const SizedBox(height: 2),
            Text(
              entry.podcast.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastCard extends StatelessWidget {
  const _PodcastCard({super.key, required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _podcastWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(AppRoutes.podcast(podcast.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _podcastWidth,
              height: _podcastWidth,
              child: Stack(
                children: [
                  PodcastCover(
                    url: podcast.imageUrl,
                    localPath: podcast.imagePath,
                    httpHeaders: podcastAuthHeaders(
                      username: podcast.authUsername,
                      password: podcast.authPassword,
                    ),
                    size: _podcastWidth,
                    radius: 10,
                  ),
                  if (podcast.preferred)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              podcast.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
