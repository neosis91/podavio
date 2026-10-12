import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryPage(
      title: 'Favoris',
      query: const EpisodeQuery(favoritesOnly: true),
      emptyTitle: 'Aucun favori',
      emptyMessage: 'Marquez un épisode pour le retrouver ici.',
    );
  }
}

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryPage(
      title: 'Téléchargements',
      query: const EpisodeQuery(downloadsOnly: true),
      emptyTitle: 'Aucun téléchargement',
      emptyMessage: 'Téléchargez un épisode pour l’écouter sans connexion.',
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.title,
    required this.query,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String title;
  final EpisodeQuery query;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EpisodeListBody(
        query: query,
        empty: EmptyState(title: emptyTitle, message: emptyMessage),
      ),
    );
  }
}
