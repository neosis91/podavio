import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(inProgressProvider).value ?? const [];
    final fresh = ref.watch(freshEpisodesProvider).value ?? const [];
    final downloads = ref.watch(recentDownloadsProvider).value ?? const [];
    final random = ref.watch(randomEpisodesProvider).value ?? const [];
    final podcasts = ref.watch(preferredPodcastsProvider);
    final subscriptions = podcasts.value ?? const <Podcast>[];
    final waiting = podcasts.isLoading && podcasts.value == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: waiting
          ? const Center(child: CircularProgressIndicator())
          : subscriptions.isEmpty &&
                inProgress.isEmpty &&
                fresh.isEmpty &&
                random.isEmpty &&
                downloads.isEmpty
          ? EmptyState(
              title: 'Rien à écouter pour le moment',
              message: 'Ajoutez un abonnement pour remplir l’accueil.',
              action: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.discover),
                icon: const Icon(Icons.explore),
                label: const Text('Explorer'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (inProgress.isNotEmpty)
                  _InlineSection(
                    title: 'Continuer d’écouter',
                    height: _episodeRowHeight,
                    itemCount: inProgress.length,
                    itemBuilder: (context, index) => _EpisodeCard(
                      entry: inProgress[index],
                      showProgress: true,
                    ),
                  ),
                if (fresh.isNotEmpty)
                  _InlineSection(
                    title: 'Les nouveautés',
                    height: _episodeRowHeight,
                    itemCount: fresh.length,
                    itemBuilder: (context, index) =>
                        _EpisodeCard(entry: fresh[index]),
                  ),
                if (random.isNotEmpty)
                  _InlineSection(
                    title: 'Aléatoire',
                    height: _episodeRowHeight,
                    itemCount: random.length,
                    action: IconButton(
                      tooltip: 'Autres épisodes',
                      onPressed: () =>
                          ref.read(randomEpisodesProvider.notifier).reshuffle(),
                      icon: const Icon(Icons.shuffle),
                    ),
                    itemBuilder: (context, index) =>
                        _EpisodeCard(entry: random[index]),
                  ),
                if (subscriptions.isNotEmpty)
                  _InlineSection(
                    title: 'Abonnements préférés',
                    height: _podcastRowHeight,
                    itemCount: subscriptions.length,
                    itemBuilder: (context, index) =>
                        _PodcastCard(podcast: subscriptions[index]),
                  ),
                if (downloads.isNotEmpty)
                  _InlineSection(
                    title: 'Derniers téléchargements',
                    height: _episodeRowHeight,
                    itemCount: downloads.length,
                    itemBuilder: (context, index) =>
                        _EpisodeCard(entry: downloads[index]),
                  ),
              ],
            ),
    );
  }
}

const _cardWidth = 148.0;
const _episodeRowHeight = 232.0;
const _podcastWidth = 132.0;
const _podcastRowHeight = 188.0;

class _InlineSection extends StatelessWidget {
  const _InlineSection({
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.action,
  });

  final String title;
  final double height;
  final int itemCount;
  final Widget? action;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ?action,
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.entry, this.showProgress = false});

  final EpisodeEntry entry;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episode = entry.episode;
    final duration = episode.durationSeconds == null
        ? null
        : Duration(seconds: episode.durationSeconds!);
    final position = Duration(milliseconds: episode.positionMs);
    final fraction = duration == null || duration == Duration.zero
        ? null
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: _cardWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.episode(episode.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastCover(url: entry.imageUrl, size: _cardWidth, radius: 12),
            if (showProgress && fraction != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: fraction, minHeight: 3),
              ),
            ] else
              const SizedBox(height: 9),
            const SizedBox(height: 6),
            Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.podcast.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastCard extends StatelessWidget {
  const _PodcastCard({required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _podcastWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.podcast(podcast.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _podcastWidth,
              height: _podcastWidth,
              child: Stack(
                children: [
                  PodcastCover(
                    url: podcast.imageUrl,
                    size: _podcastWidth,
                    radius: 12,
                  ),
                  if (podcast.preferred)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              podcast.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
