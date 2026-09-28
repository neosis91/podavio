import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/messages.dart';

class PodcastsPage extends ConsumerWidget {
  const PodcastsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcasts = ref.watch(podcastsProvider);
    final settings = ref.watch(settingsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = _maxColumns(constraints.maxWidth);
        final columns = settings.podcastList
            ? 1
            : _columnsForWidth(constraints.maxWidth, settings.podcastColumns);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Abonnements'),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Affichage',
                icon: Icon(
                  settings.podcastList ? Icons.view_list : Icons.grid_view,
                ),
                onSelected: (value) => ref
                    .read(settingsProvider.notifier)
                    .setPodcastLayout(
                      list: value == 0,
                      columns: value == 0 ? null : value,
                    ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 0,
                    child: Row(
                      children: [
                        const Expanded(child: Text('Liste')),
                        if (settings.podcastList)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                  for (var count = 1; count <= maxColumns; count++)
                    PopupMenuItem(
                      value: count,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$count ${count == 1 ? 'colonne' : 'colonnes'}',
                            ),
                          ),
                          if (!settings.podcastList && count == columns)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
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
                  message: 'Ajoutez un flux RSS ou cherchez un podcast dans Explorer.',
                  action: FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.discover),
                    icon: const Icon(Icons.explore),
                    label: const Text('Explorer'),
                  ),
                );
              }
              if (settings.podcastList) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final podcast = items[index];
                    return _PodcastListTile(podcast: podcast);
                  },
                );
              }
              return _PodcastGrid(items: items, columns: columns);
            },
          ),
        );
      },
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
            hintText: 'Flux RSS ou lien open.spotify.com/show/…',
            labelText: 'Adresse RSS ou émission Spotify',
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
      result.created
          ? 'Abonnement ajouté'
          : 'Flux déjà suivi, épisodes mis à jour',
    );
    context.push(AppRoutes.podcast(result.podcastId));
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
  }
}

const _gridPadding = 16.0;
const _gridSpacing = 16.0;
const _minTile = 148.0;

int _maxColumns(double width) {
  final inner = width - _gridPadding * 2;
  if (inner <= _minTile) return 1;
  var fit = 1;
  for (var count = 2; count <= 6; count++) {
    final tile = (inner - _gridSpacing * (count - 1)) / count;
    if (tile < _minTile) break;
    fit = count;
  }
  return fit;
}

int _columnsForWidth(double width, int preferred) {
  final maxFit = _maxColumns(width);
  final wanted = preferred.clamp(1, 6);
  return wanted > maxFit ? maxFit : wanted;
}

class _PodcastGrid extends StatelessWidget {
  const _PodcastGrid({required this.items, required this.columns});

  final List<Podcast> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final authorStyle = theme.textTheme.bodySmall?.copyWith(
      height: 1.25,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titleHeight =
        (titleStyle?.fontSize ?? 14) * (titleStyle?.height ?? 1.25) * 2;
    final authorHeight =
        (authorStyle?.fontSize ?? 12) * (authorStyle?.height ?? 1.25);
    final textHeight = 8 + titleHeight + 2 + authorHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth -
                _gridPadding * 2 -
                _gridSpacing * (columns - 1)) /
            columns;
        return GridView.builder(
          padding: const EdgeInsets.all(_gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileWidth + textHeight,
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
                  AspectRatio(
                    aspectRatio: 1,
                    child: PodcastCover(
                      url: podcast.imageUrl,
                      size: null,
                      radius: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: titleHeight,
                    child: Text(
                      podcast.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: authorHeight,
                    child: Text(
                      podcast.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: authorStyle,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PodcastListTile extends StatelessWidget {
  const _PodcastListTile({required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(AppRoutes.podcast(podcast.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              PodcastCover(url: podcast.imageUrl, size: 72, radius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (podcast.author.isNotEmpty)
                      Text(
                        podcast.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
