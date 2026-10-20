import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_database.dart';
import '../l10n/l10n.dart';
import '../data/providers.dart';
import 'playlist_membership.dart';
import 'router.dart';
import 'widgets/empty_state.dart';
import 'widgets/frosted_header.dart';
import 'widgets/episode_list.dart';
import 'widgets/list_play_button.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: Text(context.tr('Playlists')),
        actions: [
          IconButton(
            tooltip: 'Nouvelle playlist',
            onPressed: () => _createPlaylist(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: playlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: 'Impossible de charger les playlists',
          message: error.toString(),
        ),
        data: (items) => ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final playlist = items[index];
            return ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(playlist.name),
              subtitle: Text(_playlistSubtitle(playlist)),
              onTap: () => context.push(AppRoutes.playlist(playlist.id)),
              trailing: _PlaylistMenu(playlist: playlist),
            );
          },
        ),
      ),
    );
  }
}

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  EpisodeSelectionSession? _selection;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final playlist = playlists.asData?.value
        .where((item) => item.id == widget.playlistId)
        .firstOrNull;
    if (playlist == null) {
      return FrostedScaffold(
        appBar: FrostedAppBar(title: Text(context.tr('Playlist'))),
        body: playlists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            title: 'Impossible de charger la playlist',
            message: error.toString(),
          ),
          data: (_) => const EmptyState(
            title: 'Playlist introuvable',
            message: 'Elle a été supprimée.',
          ),
        ),
      );
    }

    final query = playlist.isDefault
        ? const EpisodeQuery(queuedOnly: true, paginated: false)
        : EpisodeQuery(playlistId: playlist.id, paginated: false);
    final bulkActions = EpisodeBulkActions(
      favorite: true,
      download: true,
      removeLabel: 'Retirer de la playlist',
      onRemove: (entries) async {
        final database = ref.read(databaseProvider);
        if (playlist.isDefault) {
          for (final entry in entries) {
            await database.removeFromQueue(entry.episode.id);
          }
        } else {
          for (final entry in entries) {
            await database.removeFromPlaylist(playlist.id, entry.episode.id);
          }
        }
      },
    );

    return FrostedScaffold(
      appBar: _selection != null
          ? EpisodeSelectionAppBar(session: _selection!)
          : FrostedAppBar(
              title: Text(playlist.name),
              actions: [
                ListPlayButton(query: query),
                _PlaylistMenu(playlist: playlist, popOnDelete: true),
              ],
            ),
      body: EpisodeListBody(
        queueStyle: true,
        query: query,
        bulkActions: bulkActions,
        onSelectionChanged: (session) {
          if (!mounted) return;
          setState(() => _selection = session);
        },
        reorder: (entries, oldIndex, newIndex) {
          final next = [...entries];
          final moved = next.removeAt(oldIndex);
          next.insert(newIndex, moved);
          final ids = next.map((entry) => entry.episode.id).toList();
          if (playlist.isDefault) {
            ref.read(databaseProvider).setQueueOrder(ids);
          } else {
            ref.read(databaseProvider).setPlaylistOrder(playlist.id, ids);
          }
        },
        onRemove: (entry) {
          if (playlist.isDefault) {
            ref.read(databaseProvider).removeFromQueue(entry.episode.id);
          } else {
            ref
                .read(databaseProvider)
                .removeFromPlaylist(playlist.id, entry.episode.id);
          }
        },
        empty: EmptyState(
          title: playlist.isDefault
              ? 'La playlist est vide'
              : 'Cette playlist est vide',
          message: playlist.isDefault
              ? 'Ajoutez des épisodes pour les écouter les uns à la suite des autres.'
              : 'Ajoutez des épisodes depuis leur menu Playlists.',
        ),
      ),
    );
  }
}

class _PlaylistMenu extends ConsumerWidget {
  const _PlaylistMenu({required this.playlist, this.popOnDelete = false});

  final PlaylistSummary playlist;
  final bool popOnDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (action) async {
        switch (action) {
          case 'rename':
            final name = await askPlaylistName(
              context,
              title: 'Renommer',
              confirm: 'Renommer',
              initial: playlist.name,
            );
            if (name == null || !context.mounted) return;
            await ref.read(databaseProvider).renamePlaylist(playlist.id, name);
          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Supprimer cette playlist ?'),
                content: Text(
                  '« ${playlist.name} » sera retirée. Les épisodes restent dans la bibliothèque.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref.read(databaseProvider).deletePlaylist(playlist.id);
            if (popOnDelete && context.mounted) context.pop();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Renommer')),
        if (!playlist.isDefault)
          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    );
  }
}

Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
  final name = await askPlaylistName(context);
  if (name == null || !context.mounted) return;
  final id = await ref.read(databaseProvider).createPlaylist(name);
  if (context.mounted) context.push(AppRoutes.playlist(id));
}

String _playlistSubtitle(PlaylistSummary playlist) {
  final count = switch (playlist.episodeCount) {
    0 => 'Aucun épisode',
    1 => '1 épisode',
    _ => '${playlist.episodeCount} épisodes',
  };
  if (playlist.isDefault) return 'Par défaut · $count';
  return count;
}
