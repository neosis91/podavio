import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../data/feed_refresh_controller.dart';
import 'router.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';
import 'widgets/messages.dart';

class EpisodesPage extends ConsumerStatefulWidget {
  const EpisodesPage({super.key});

  @override
  ConsumerState<EpisodesPage> createState() => _EpisodesPageState();
}

class _EpisodesPageState extends ConsumerState<EpisodesPage> {
  var _unreadOnly = true;
  var _search = '';
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refreshing = ref.watch(
      feedRefreshProvider.select((s) => s.isRunning),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Épisodes'),
        actions: [
          IconButton(
            tooltip: refreshing
                ? 'Actualisation en cours'
                : 'Actualiser les abonnements',
            onPressed: refreshing
                ? null
                : () => refreshSubscriptions(context, ref),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'played') {
                await ref.read(databaseProvider).markAllPlayed();
                if (context.mounted) {
                  showMessage(context, 'Épisodes marqués comme lus');
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'played',
                child: Text('Tout marquer comme lu'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Non lus')),
                    ButtonSegment(value: false, label: Text('Tous')),
                  ],
                  selected: {_unreadOnly},
                  onSelectionChanged: (selection) {
                    setState(() => _unreadOnly = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher un épisode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _searchTimer?.cancel();
                    _searchTimer = Timer(const Duration(milliseconds: 250), () {
                      if (!mounted) return;
                      setState(() => _search = value.trim());
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: EpisodeListBody(
              query: EpisodeQuery(unreadOnly: _unreadOnly, search: _search),
              onRefresh: refreshing
                  ? null
                  : () => refreshSubscriptions(context, ref),
              empty: EmptyState(
                title: _search.isEmpty
                    ? 'Aucun épisode à écouter'
                    : 'Aucun résultat',
                message: _search.isEmpty
                    ? 'Abonnez-vous à un podcast depuis Explorer, ou collez l’adresse d’un flux RSS.'
                    : 'Essayez un autre mot, ou affichez tous les épisodes.',
                action: _search.isEmpty
                    ? FilledButton(
                        onPressed: () => context.go(AppRoutes.discover),
                        child: const Text('Explorer'),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> refreshSubscriptions(BuildContext context, WidgetRef ref) async {
  if (ref.read(feedRefreshProvider).isRunning) {
    showMessage(context, 'Actualisation déjà en cours');
    return;
  }
  final started = await ref.read(feedRefreshProvider.notifier).start();
  if (!started && context.mounted) {
    showMessage(context, 'Aucun abonnement à actualiser');
  }
}
