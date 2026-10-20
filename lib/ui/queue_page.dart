import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EpisodeListScaffold(
      title: Text(context.tr('Playlist')),
      queueStyle: true,
      query: const EpisodeQuery(queuedOnly: true, paginated: false),
      reorder: (entries, oldIndex, newIndex) {
        final next = [...entries];
        final moved = next.removeAt(oldIndex);
        next.insert(newIndex, moved);
        ref
            .read(databaseProvider)
            .setQueueOrder(next.map((entry) => entry.episode.id).toList());
      },
      onRemove: (entry) =>
          ref.read(databaseProvider).removeFromQueue(entry.episode.id),
      bulkActions: EpisodeBulkActions(
        favorite: true,
        download: true,
        removeLabel: 'Retirer de la file',
        onRemove: (entries) async {
          final database = ref.read(databaseProvider);
          for (final entry in entries) {
            await database.removeFromQueue(entry.episode.id);
          }
        },
      ),
      empty: const EmptyState(
        title: 'La file est vide',
        message:
            'Ajoutez des épisodes pour les écouter les uns à la suite des autres.',
      ),
    );
  }
}
