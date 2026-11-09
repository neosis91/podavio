import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/cover_tone.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../data/app_database.dart';
import '../data/catalog_categories.dart';
import '../data/discover_providers.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'category_subjects_sheet.dart';
import 'library_hub_page.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/frosted_header.dart';
import 'widgets/cover.dart';
import 'widgets/playing_cover.dart';
import 'widgets/episode_tile.dart';
import 'podcasts/podcasts_tiles.dart';
import 'widgets/empty_state.dart';
import 'widgets/list_metrics.dart';
import 'widgets/marquee_text.dart';
import 'widgets/selection_chip.dart';

String _homeGreeting(BuildContext context) {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour <= 12) return context.tr('Good morning');
  if (hour >= 13 && hour <= 17) return context.tr('Good afternoon');
  if (hour >= 18 && hour <= 23) return context.tr('Good evening');
  return context.tr('Good night');
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

  /// `null` = la pastille Tout, l’accueil habituel.
  String? _category;

  void _selectCategory(String? id) {
    setState(() => _category = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

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
    ref.watch(podcastCategoryBackfillProvider);
    final chosen = ref.watch(displayedHomeCategoriesProvider);
    final grouped = ref.watch(homeCategoryPodcastsProvider);
    final categories = HomeCategories(
      order: chosen.order,
      enabled: {
        for (final id in chosen.enabled)
          if (grouped.containsKey(id)) id,
      },
    );
    final category = categories.isOn(_category ?? '') ? _category : null;
    final shelfOrder = ref.watch(
      settingsProvider.select((settings) => settings.homeShelves),
    );
    final shelves = <_HomeShelf>[
      for (final id in shelfOrder.visible)
        ?_homeShelf(
          context,
          ref,
          id: id,
          inProgress: inProgress,
          fresh: fresh,
          favorites: favorites,
          played: played,
          random: random,
          subscriptions: subscriptions,
          downloads: downloads,
        ),
    ];
    final filled =
        subscriptions.isNotEmpty ||
        inProgress.isNotEmpty ||
        fresh.isNotEmpty ||
        favorites.isNotEmpty ||
        played.isNotEmpty ||
        random.isNotEmpty ||
        downloads.isNotEmpty;
    final categoryCover = category == null
        ? null
        : _firstPodcastCover(grouped[category]);
    return Scaffold(
      body: Stack(
        children: [
          if (categoryCover != null || (category == null && shelves.isNotEmpty))
            Positioned.fill(
              child: _HomePageWash(
                scroll: _scroll,
                entry: categoryCover == null ? shelves.first.entry : null,
                podcast: categoryCover == null ? shelves.first.podcast : null,
                imageUrl: categoryCover,
              ),
            ),
          if (category != null)
            _CategoryHome(
              scroll: _scroll,
              headerTop: headerTop,
              categoryId: category,
            )
          else if (waiting)
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
          else if (shelves.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: headerTop),
              child: EmptyState(
                title: context.tr('Every shelf is hidden'),
                message: context.tr('Show them again in Interface.'),
                action: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.appearance),
                  icon: const Icon(Icons.tune),
                  label: Text(context.tr('Interface')),
                ),
              ),
            )
          else
            ListView(
              controller: _scroll,
              padding: underChrome(
                context,
                EdgeInsets.only(top: headerTop, bottom: 24),
              ),
              children: [for (final shelf in shelves) shelf.shelf],
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _HomeHeaderOverlay(
              scrolled: _scrolled,
              categories: categories,
              selected: category,
              onSelected: _selectCategory,
            ),
          ),
        ],
      ),
    );
  }
}

String? _firstPodcastCover(List<Podcast>? podcasts) {
  if (podcasts == null) return null;
  for (final podcast in podcasts) {
    final url = podcast.imageUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

/// Hauteur de la barre (hors encoche), identique à l’ancien toolbar.
const _headerBrand = 72.0;

/// Rangée de pastilles, sous le logo, comme l’en-tête de SimpMusic.
const _headerChips = 48.0;

const _headerToolbar = _headerBrand + _headerChips;

class _HomeShelf {
  const _HomeShelf({required this.shelf, this.entry, this.podcast});

  final Widget shelf;
  final EpisodeEntry? entry;
  final Podcast? podcast;
}

_HomeShelf? _homeShelf(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required List<EpisodeEntry> inProgress,
  required List<EpisodeEntry> fresh,
  required List<EpisodeEntry> favorites,
  required List<EpisodeEntry> played,
  required List<EpisodeEntry> random,
  required List<Podcast> subscriptions,
  required List<EpisodeEntry> downloads,
}) {
  return switch (id) {
    'continue' when inProgress.isNotEmpty => _HomeShelf(
      shelf: _ContinueShelf(entries: inProgress),
      entry: inProgress.first,
    ),
    'fresh' when fresh.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr("What's new"),
        height: _episodeRowHeight,
        itemCount: fresh.length,
        onMore: () => context.push(AppRoutes.episodes),
        itemBuilder: (context, index) => _EpisodeCard(
          key: ValueKey(fresh[index].episode.id),
          entry: fresh[index],
        ),
      ),
      entry: fresh.first,
    ),
    'favorites' when favorites.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr('Favorites'),
        height: _episodeRowHeight,
        itemCount: favorites.length,
        onMore: () => context.push(AppRoutes.favorites),
        itemBuilder: (context, index) => _EpisodeCard(
          key: ValueKey(favorites[index].episode.id),
          entry: favorites[index],
        ),
      ),
      entry: favorites.first,
    ),
    'recent' when played.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr('Recent plays'),
        height: _episodeRowHeight,
        itemCount: played.length,
        onMore: () => context.push(AppRoutes.history),
        itemBuilder: (context, index) => _EpisodeCard(
          key: ValueKey(played[index].episode.id),
          entry: played[index],
        ),
      ),
      entry: played.first,
    ),
    'random' when random.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr('Random'),
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
      entry: random.first,
    ),
    'preferred' when subscriptions.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr('Preferred subscriptions'),
        height: _podcastRowHeight,
        itemCount: subscriptions.length,
        onMore: () => context.go(AppRoutes.podcasts),
        itemBuilder: (context, index) => _PodcastCard(
          key: ValueKey(subscriptions[index].id),
          podcast: subscriptions[index],
        ),
      ),
      podcast: subscriptions.first,
    ),
    'downloads' when downloads.isNotEmpty => _HomeShelf(
      shelf: _InlineSection(
        title: context.tr('Recent downloads'),
        height: _episodeRowHeight,
        itemCount: downloads.length,
        onMore: () => context.push(AppRoutes.downloads),
        itemBuilder: (context, index) => _EpisodeCard(
          key: ValueKey(downloads[index].episode.id),
          entry: downloads[index],
        ),
      ),
      entry: downloads.first,
    ),
    _ => null,
  };
}

class _HomeHeaderOverlay extends StatelessWidget {
  const _HomeHeaderOverlay({
    required this.scrolled,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final bool scrolled;
  final HomeCategories categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + _headerToolbar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FrostedHeaderBackdrop(scrolled: scrolled),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: Column(
              children: [
                SizedBox(
                  height: _headerBrand,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const PodavioLogo(width: 118),
                              const SizedBox(height: 4),
                              Text(
                                _homeGreeting(context),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const _EcoButton(),
                        const HistoryButton(),
                        const _WebButton(),
                        const PreferencesButton(),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: _headerChips,
                  child: _HomeChips(
                    categories: categories,
                    selected: selected,
                    onSelected: onSelected,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EcoButton extends ConsumerWidget {
  const _EcoButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsProvider.select((settings) => settings.ecoMode),
    );
    final idle = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: context.tr('Eco mode'),
      onPressed: () => ref.read(settingsProvider.notifier).setEcoMode(!enabled),
      icon: EcoIcon(color: enabled ? podavioGreen : idle),
    );
  }
}

class _HomeChips extends StatelessWidget {
  const _HomeChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final HomeCategories categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ids = categories.visible;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      itemCount: ids.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SelectionChip(
            label: context.tr('All'),
            selected: selected == null,
            onSelected: () => onSelected(null),
          );
        }
        final id = ids[index - 1];
        return SelectionChip(
          label: context.tr(homeCategoryTitle(id)),
          selected: selected == id,
          onSelected: () => onSelected(id),
        );
      },
    );
  }
}

class _CategoryHome extends ConsumerWidget {
  const _CategoryHome({
    required this.scroll,
    required this.headerTop,
    required this.categoryId,
  });

  final ScrollController scroll;
  final double headerTop;
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = context.tr(homeCategoryTitle(categoryId));
    final podcasts =
        ref.watch(homeCategoryPodcastsProvider)[categoryId] ??
        const <Podcast>[];
    final counts = ref.watch(unreadCountsByPodcastProvider).value ?? const {};
    return ListView.separated(
      controller: scroll,
      padding: underChrome(context, const EdgeInsets.only(bottom: 24)),
      itemCount: podcasts.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
        return Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.5),
        );
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: headerTop),
              _ShelfHeader(
                title: title,
                action: TextButton(
                  onPressed: () =>
                      showCategorySubjectsSheet(context, ref, categoryId),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    visualDensity: VisualDensity.compact,
                    textStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                  child: Text(context.tr('Subjects')),
                ),
              ),
              CategorySubjectChips(categoryId: categoryId),
              const SizedBox(height: 4),
            ],
          );
        }
        final podcast = podcasts[index - 1];
        return PodcastListTile(
          key: ValueKey(podcast.id),
          podcast: podcast,
          showName: true,
          highlightQuery: '',
          count: counts[podcast.id] ?? 0,
        );
      },
    );
  }
}

class _WebButton extends StatelessWidget {
  const _WebButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Podavio Web'),
      onPressed: () => context.push(AppRoutes.webCompanion),
      icon: const Icon(Icons.phonelink),
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
        _ShelfHeader(title: context.tr('Continue listening')),
        SizedBox(
          height: rows * _quickRowHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Deux colonnes visibles dès que chacune reste lisible.
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              final overflow = entries.length > rows * columns;
              final itemWidth = columns == 1
                  ? (constraints.maxWidth - 30).clamp(
                      220.0,
                      constraints.maxWidth,
                    )
                  : (constraints.maxWidth - 12 - (overflow ? 28 : 0)) / 2;
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
                label: episode.title,
                colorKey: entry.podcast.title,
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
                    MarqueeText(
                      text: episode.title,
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

/// Teinte de la pochette sur toute la page, en fondu depuis l’angle gauche.
///
/// Elle est calée sur le haut du contenu et part avec le défilement.
class _HomePageWash extends ConsumerStatefulWidget {
  const _HomePageWash({
    required this.scroll,
    this.entry,
    this.podcast,
    this.imageUrl,
  });

  final ScrollController scroll;
  final EpisodeEntry? entry;
  final Podcast? podcast;
  final String? imageUrl;

  @override
  ConsumerState<_HomePageWash> createState() => _HomePageWashState();
}

class _HomePageWashState extends ConsumerState<_HomePageWash> {
  Color? _color;
  String? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HomePageWash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.episode.id != widget.entry?.episode.id ||
        oldWidget.podcast?.id != widget.podcast?.id ||
        oldWidget.imageUrl != widget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final tintFromCover = ref.read(
      settingsProvider.select((settings) => settings.tintFromCover),
    );
    final eco = ref.read(
      settingsProvider.select((settings) => settings.ecoMode),
    );
    if (!tintFromCover) {
      _loaded = null;
      _color = null;
      return;
    }
    final prefer = ref.read(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    final entry = widget.entry;
    final podcast = widget.podcast;
    final path =
        entry?.imagePath(preferPodcastCover: prefer) ?? podcast?.imagePath;
    final url =
        widget.imageUrl ??
        entry?.imageUrl(preferPodcastCover: prefer) ??
        podcast?.imageUrl;
    final source = podcast ?? entry?.podcast;
    final request = '${path ?? ''}\n${url ?? ''}';
    if (request == _loaded) return;
    final tone = await loadCoverTone(
      path: path,
      url: url,
      allowDownload: !eco,
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
        widget.imageUrl ??
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
    final tintFromCover = ref.watch(
      settingsProvider.select((settings) => settings.tintFromCover),
    );
    ref.listen<bool>(
      settingsProvider.select((settings) => settings.tintFromCover),
      (previous, next) {
        if (previous != next) _load();
      },
    );
    ref.listen<bool>(settingsProvider.select((settings) => settings.ecoMode), (
      previous,
      next,
    ) {
      if (previous != next) _load();
    });
    final surface = Theme.of(context).colorScheme.surface;
    final tint = tintFromCover ? _color : null;
    return AnimatedBuilder(
      animation: widget.scroll,
      builder: (context, child) {
        final offset = widget.scroll.hasClients ? widget.scroll.offset : 0.0;
        return Transform.translate(offset: Offset(0, -offset), child: child);
      },
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: tint == null
                ? null
                : RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.45,
                    colors: [
                      tint.withValues(alpha: 0.55),
                      tint.withValues(alpha: 0.2),
                      surface.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.36, 0.72],
                  ),
          ),
        ),
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
              label: episode.title,
              colorKey: entry.podcast.title,
              httpHeaders: podcastAuthHeaders(
                username: entry.podcast.authUsername,
                password: entry.podcast.authPassword,
              ),
              size: _cardWidth,
              radius: 10,
              ecoTintFromImage: true,
            ),
            const SizedBox(height: 8),
            MarqueeText(
              text: episode.title,
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
                    label: podcast.title,
                    colorKey: podcast.title,
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
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: PreferredStarIcon(selected: true, size: 16),
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
