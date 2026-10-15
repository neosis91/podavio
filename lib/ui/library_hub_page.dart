import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'history_page.dart';
import 'nav_catalog.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/empty_state.dart';
import 'widgets/list_metrics.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  static const _history = EpisodeQuery(historyOnly: true);
  EpisodeWindow? _previous;

  @override
  Widget build(BuildContext context) {
    final next = ref.watch(episodesProvider(_history));
    final loaded = next.asData?.value;
    if (loaded != null) _previous = loaded;
    final window = loaded ?? _previous;
    final entries = window?.entries;
    final favorites = navPageByPath(AppRoutes.favorites)!;
    final episodes = navPageByPath(AppRoutes.episodes)!;
    final downloads = navPageByPath(AppRoutes.downloads)!;
    final playlists = navPageByPath(AppRoutes.playlists)!;
    final stats = navPageByPath(AppRoutes.stats)!;
    const tiles = <_LibraryTileData>[
      _LibraryTileData(
        path: AppRoutes.favorites,
        background: Color(0xffff99ae),
        icon: Icons.favorite,
        iconColor: favoriteHeartColor,
      ),
      _LibraryTileData(
        path: AppRoutes.episodes,
        background: Color(0xff00BCD4),
        icon: Icons.podcasts,
        iconColor: Colors.black,
      ),
      _LibraryTileData(
        path: AppRoutes.downloads,
        background: Color(0xff4CAF50),
        icon: Icons.downloading,
        iconColor: Colors.black,
      ),
      _LibraryTileData(
        path: AppRoutes.playlists,
        background: Color(0xffFFEB3B),
        icon: Icons.playlist_play,
        iconColor: Colors.black,
      ),
      _LibraryTileData(
        path: AppRoutes.stats,
        background: Color(0xffCE93D8),
        icon: Icons.insights,
        iconColor: Colors.black,
      ),
    ];
    final pages = {
      favorites.path: favorites,
      episodes.path: episodes,
      downloads.path: downloads,
      playlists.path: playlists,
      stats.path: stats,
    };
    final recentCount = entries == null
        ? 1
        : entries.isEmpty
        ? 1
        : entries.length + (window!.hasMore ? 1 : 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Library')),
        actions: const [PreferencesButton()],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is! ScrollUpdateNotification &&
              notification is! ScrollEndNotification) {
            return false;
          }
          if (notification.metrics.extentAfter < 800) {
            ref.read(episodesProvider(_history).notifier).loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: underChrome(
            context,
            const EdgeInsets.only(top: 10, bottom: 24),
          ),
          itemCount: 2 + recentCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    for (var tile = 0; tile < tiles.length; tile += 2)
                      Padding(
                        padding: EdgeInsets.only(top: tile == 0 ? 0 : 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: _LibraryTile(
                                page: pages[tiles[tile].path]!,
                                data: tiles[tile],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: tile + 1 < tiles.length
                                  ? _LibraryTile(
                                      page: pages[tiles[tile + 1].path]!,
                                      data: tiles[tile + 1],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 10, 0),
                child: SizedBox(
                  height: 35,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lectures récentes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              );
            }
            if (entries == null) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: next.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => EmptyState(
                    title: 'Impossible de charger les épisodes',
                    message: error.toString(),
                  ),
                  data: (_) => const SizedBox.shrink(),
                ),
              );
            }
            if (entries.isEmpty) {
              return const SizedBox(
                height: 130,
                child: Center(child: Text('Aucune lecture récente')),
              );
            }
            final entryIndex = index - 2;
            if (entryIndex >= entries.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return HistoryEpisodeRow(
              key: ValueKey(entries[entryIndex].episode.id),
              entry: entries[entryIndex],
              showMenu: true,
            );
          },
        ),
      ),
    );
  }
}

class _LibraryTileData {
  const _LibraryTileData({
    required this.path,
    required this.background,
    required this.icon,
    required this.iconColor,
  });

  final String path;
  final Color background;
  final IconData icon;
  final Color iconColor;
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.page, required this.data});

  final NavPage page;
  final _LibraryTileData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.background,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => context.push(page.path),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(data.icon, size: 30, color: data.iconColor),
            ),
            Expanded(
              child: Text(
                context.tr(page.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryButton extends StatelessWidget {
  const HistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Lectures récentes',
      onPressed: () => context.push(AppRoutes.history),
      icon: const HistoryIcon(),
    );
  }
}

class PreferencesButton extends StatelessWidget {
  const PreferencesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Préférences',
      onPressed: () => context.push(AppRoutes.preferences),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}
