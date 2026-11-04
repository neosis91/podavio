import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/download_controller.dart';
import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/brand.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';
import 'widgets/list_play_button.dart';
import 'widgets/messages.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const query = EpisodeQuery(favoritesOnly: true);
    return EpisodeListScaffold(
      title: Text(context.tr('Favorites')),
      actions: const [ListPlayButton(query: query)],
      query: query,
      queueStyle: true,
      onRemove: (entry) => ref
          .read(databaseProvider)
          .setFavorite(entry.episode.id, favorite: false),
      bulkActions: EpisodeBulkActions(
        download: true,
        removeLabel: 'Retirer des favoris',
        onRemove: (entries) async {
          final database = ref.read(databaseProvider);
          for (final entry in entries) {
            await database.setFavorite(entry.episode.id, favorite: false);
          }
        },
      ),
      empty: const EmptyState(
        title: 'Aucun favori',
        message: 'Marquez un épisode pour le retrouver ici.',
      ),
    );
  }
}

class CachePage extends ConsumerWidget {
  const CachePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const query = EpisodeQuery(cacheOnly: true);
    return EpisodeListScaffold(
      title: Text(context.tr('Episode cache')),
      actions: const [
        ListPlayButton(query: query),
        _CacheMenu(),
      ],
      query: query,
      queueStyle: true,
      onRemove: (entry) =>
          ref.read(downloadServiceProvider).forgetStreamCache(entry.episode.id),
      bulkActions: EpisodeBulkActions(
        favorite: true,
        removeLabel: 'Retirer du cache',
        onRemove: (entries) async {
          final downloads = ref.read(downloadServiceProvider);
          for (final entry in entries) {
            await downloads.forgetStreamCache(entry.episode.id);
          }
        },
      ),
      empty: const EmptyState(
        title: 'Aucun fichier en cache',
        message: 'Les épisodes gardés pendant la lecture apparaissent ici.',
      ),
    );
  }
}

class _CacheMenu extends ConsumerWidget {
  const _CacheMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Actions',
      onPressed: () => _open(context, ref),
      icon: const MoreVertIcon(),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final entries = await ref
        .read(databaseProvider)
        .watchEpisodeWindow(cacheOnly: true)
        .first;
    if (!context.mounted) return;
    final canDownload = entries.isNotEmpty;
    final canFavorite = entries.any((entry) => !entry.episode.favorite);
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canDownload)
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Télécharger'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _downloadAll(context, ref, entries);
                  },
                ),
              if (canFavorite)
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Ajouter aux favoris'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _favoriteAll(context, ref, entries);
                  },
                ),
              if (!canDownload && !canFavorite)
                const ListTile(
                  enabled: false,
                  title: Text('Aucun fichier en cache'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _downloadAll(
    BuildContext context,
    WidgetRef ref,
    List<EpisodeEntry> entries,
  ) {
    final downloads = ref.read(downloadProgressProvider.notifier);
    final inFlight = ref.read(downloadProgressProvider);
    var started = 0;
    for (final entry in entries) {
      final episode = entry.episode;
      if (episode.downloadPath != null) continue;
      if (inFlight.containsKey(episode.id)) continue;
      started++;
      unawaited(downloads.download(episode));
    }
    showMessage(
      context,
      started == 0
          ? 'Aucun téléchargement à lancer'
          : started == 1
          ? 'Téléchargement lancé'
          : '$started téléchargements lancés',
    );
  }

  Future<void> _favoriteAll(
    BuildContext context,
    WidgetRef ref,
    List<EpisodeEntry> entries,
  ) async {
    final database = ref.read(databaseProvider);
    for (final entry in entries) {
      if (!entry.episode.favorite) {
        await database.setFavorite(entry.episode.id, favorite: true);
      }
    }
    if (context.mounted) showMessage(context, 'Ajoutés aux favoris');
  }
}

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const query = EpisodeQuery(downloadsOnly: true);
    return EpisodeListScaffold(
      title: Text(context.tr('Downloads')),
      actions: const [ListPlayButton(query: query)],
      query: query,
      queueStyle: true,
      onRemove: (entry) => ref
          .read(downloadProgressProvider.notifier)
          .deleteDownload(entry.episode),
      bulkActions: EpisodeBulkActions(
        favorite: true,
        removeLabel: 'Supprimer les téléchargements',
        onRemove: (entries) async {
          final downloads = ref.read(downloadProgressProvider.notifier);
          for (final entry in entries) {
            await downloads.deleteDownload(entry.episode);
          }
        },
      ),
      empty: const EmptyState(
        title: 'Aucun téléchargement',
        message: 'Téléchargez un épisode pour l’écouter sans connexion.',
      ),
    );
  }
}
