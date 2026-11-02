import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/download_controller.dart';
import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';
import 'widgets/list_play_button.dart';

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
      actions: const [ListPlayButton(query: query)],
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
