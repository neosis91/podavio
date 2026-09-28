import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/messages.dart';

class PodcastsPage extends ConsumerWidget {
  const PodcastsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcasts = ref.watch(podcastsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcasts'),
        actions: [
          IconButton(
            tooltip: 'Ajouter un flux RSS',
            onPressed: () => _addFeed(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: podcasts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: 'Abonnements indisponibles',
          message: error.toString(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'Aucun abonnement',
              message:
                  'Ajoutez un flux RSS ou cherchez un podcast dans Explorer.',
              action: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.discover),
                icon: const Icon(Icons.explore),
                label: const Text('Explorer'),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final podcast = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(AppRoutes.podcast(podcast.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PodcastCover(
                        url: podcast.imageUrl,
                        size: null,
                        radius: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      podcast.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (podcast.author.isNotEmpty)
                      Text(
                        podcast.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addFeed(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un flux'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://exemple.com/flux.xml',
            labelText: 'Adresse RSS',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    await subscribeToFeed(context, ref, url);
  }
}

Future<void> subscribeToFeed(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Ajout de l’abonnement…')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  try {
    final result = await ref.read(feedServiceProvider).subscribe(url);
    closeDialog();
    if (!context.mounted) return;
    showMessage(
      context,
      result.created ? 'Abonnement ajouté' : 'Flux déjà suivi, épisodes mis à jour',
    );
    context.push(AppRoutes.podcast(result.podcastId));
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
  }
}
