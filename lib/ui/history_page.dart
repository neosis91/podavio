import 'package:flutter/material.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EpisodeListScaffold(
      title: Text(context.tr('Recent plays')),
      queueStyle: true,
      query: const EpisodeQuery(historyOnly: true),
      bulkActions: const EpisodeBulkActions(favorite: true, download: true),
      empty: const EmptyState(
        title: 'Aucune lecture récente',
        message: 'Les épisodes que vous lancez apparaîtront ici.',
      ),
    );
  }
}
