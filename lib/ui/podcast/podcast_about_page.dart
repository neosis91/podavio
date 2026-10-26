import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/frosted_header.dart';
import '../widgets/messages.dart';
import 'podcast_header.dart';

class PodcastAboutPage extends ConsumerWidget {
  const PodcastAboutPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcast = ref.watch(podcastProvider(podcastId));
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => FrostedScaffold(
        appBar: FrostedAppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return FrostedScaffold(
            appBar: FrostedAppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        final description = plainText(item.description);
        final persons = item.persons;
        final funding = item.fundingLinks;
        final titleStyle = Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary);
        return FrostedScaffold(
          appBar: FrostedAppBar(
            title: Text(item.title, overflow: TextOverflow.ellipsis),
          ),
          body: ListView(
            children: [
              PodcastHeader(podcast: item),
              _PodcastStatsSection(
                podcastId: item.id,
                subscribedAt: item.subscribedAt,
              ),
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: titleStyle),
                      const SizedBox(height: 8),
                      SelectableText(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (persons.isNotEmpty)
                _PersonsSection(persons: persons, titleStyle: titleStyle),
              if (funding.isNotEmpty)
                _FundingSection(funding: funding, titleStyle: titleStyle),
            ],
          ),
        );
      },
    );
  }
}

class _PersonsSection extends StatelessWidget {
  const _PersonsSection({required this.persons, required this.titleStyle});

  final List<PodcastPerson> persons;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personnes', style: titleStyle),
          const SizedBox(height: 8),
          for (final person in persons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _PersonAvatar(person: person),
              title: Text(person.name),
              subtitle: person.role == null && person.group == null
                  ? null
                  : Text(
                      [
                        if (person.role != null) person.role!,
                        if (person.group != null) person.group!,
                      ].join(' · '),
                    ),
              trailing: person.link == null
                  ? null
                  : const Icon(Icons.open_in_new, size: 18),
              onTap: person.link == null
                  ? null
                  : () => _openExternalLink(context, person.link!),
            ),
        ],
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person});

  final PodcastPerson person;

  @override
  Widget build(BuildContext context) {
    final image = person.image;
    final initial = person.name.isEmpty
        ? '?'
        : person.name.substring(0, 1).toUpperCase();
    if (image == null) {
      return CircleAvatar(child: Text(initial));
    }
    return CircleAvatar(backgroundImage: NetworkImage(image));
  }
}

class _FundingSection extends StatelessWidget {
  const _FundingSection({required this.funding, required this.titleStyle});

  final List<PodcastFunding> funding;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Financement', style: titleStyle),
          const SizedBox(height: 8),
          for (final item in funding)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline),
              title: Text(
                item.label?.isNotEmpty == true
                    ? item.label!
                    : 'Soutenir ce podcast',
              ),
              subtitle: Text(
                item.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openExternalLink(context, item.url),
            ),
        ],
      ),
    );
  }
}

Future<void> _openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showMessage(context, 'Impossible d’ouvrir le lien');
  }
}

class _PodcastStatsSection extends ConsumerWidget {
  const _PodcastStatsSection({
    required this.podcastId,
    required this.subscribedAt,
  });

  final int podcastId;
  final DateTime subscribedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(podcastStatsProvider(podcastId));
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques', style: titleStyle),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Impossible de charger les statistiques.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            data: (value) =>
                _PodcastStatsBody(stats: value, subscribedAt: subscribedAt),
          ),
        ],
      ),
    );
  }
}

class _PodcastStatsBody extends StatelessWidget {
  const _PodcastStatsBody({required this.stats, required this.subscribedAt});

  final PodcastStats stats;
  final DateTime subscribedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = stats.episodeCount == 0
        ? 0.0
        : (stats.completedCount / stats.episodeCount).clamp(0.0, 1.0);
    final progressLabel = '${(progress * 100).round()} %';

    final completed = stats.completedCount.toDouble();
    final inProgress = stats.inProgressCount.toDouble();
    final unread = stats.unreadCount.toDouble();
    final totalSlices = completed + inProgress + unread;
    final hasSlices = totalSlices > 0;

    final completedColor = scheme.primary;
    final inProgressColor = scheme.tertiary;
    final unreadColor = scheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: hasSlices ? 2 : 0,
                      centerSpaceRadius: 42,
                      sections: hasSlices
                          ? [
                              if (completed > 0)
                                PieChartSectionData(
                                  value: completed,
                                  color: completedColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                              if (inProgress > 0)
                                PieChartSectionData(
                                  value: inProgress,
                                  color: inProgressColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                              if (unread > 0)
                                PieChartSectionData(
                                  value: unread,
                                  color: unreadColor,
                                  radius: 18,
                                  showTitle: false,
                                ),
                            ]
                          : [
                              PieChartSectionData(
                                value: 1,
                                color: scheme.surfaceContainerHighest,
                                radius: 18,
                                showTitle: false,
                              ),
                            ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progressLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'terminés',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatListeningTime(stats.listenedSeconds),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'd’écoute cumulée',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LegendDot(
                    color: completedColor,
                    label: 'Terminés · ${stats.completedCount}',
                  ),
                  if (stats.inProgressCount > 0) ...[
                    const SizedBox(height: 4),
                    _LegendDot(
                      color: inProgressColor,
                      label: 'En cours · ${stats.inProgressCount}',
                    ),
                  ],
                  const SizedBox(height: 4),
                  _LegendDot(
                    color: unreadColor,
                    label: 'Non lus · ${stats.unreadCount}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = _statColumnCount(constraints.maxWidth);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 112,
              ),
              itemBuilder: (context, index) {
                return switch (index) {
                  0 => _MetricTile(
                    icon: Icons.play_circle_outline,
                    label: 'Épisodes lancés',
                    value: '${stats.startedCount}',
                    hint: 'sur ${stats.episodeCount}',
                  ),
                  1 => _MetricTile(
                    icon: Icons.download_outlined,
                    label: 'Téléchargements',
                    value: stats.downloadCount == 0
                        ? 'Aucun'
                        : '${stats.downloadCount}',
                    hint: stats.downloadCount == 0
                        ? null
                        : formatBytes(stats.downloadBytes),
                  ),
                  2 => _MetricTile(
                    icon: Icons.schedule_outlined,
                    label: 'Rythme',
                    value: formatReleaseCadence(stats.releaseInterval),
                    hint: stats.lastPublishedAt == null
                        ? null
                        : 'Dernier · ${formatDate(stats.lastPublishedAt)}',
                  ),
                  _ => _MetricTile(
                    icon: Icons.upcoming_outlined,
                    label: 'Prochain épisode',
                    value: formatRelativeFuture(stats.nextEpisodeAt),
                    hint: stats.averageDurationSeconds == null
                        ? null
                        : '≈ ${formatListeningTime(stats.averageDurationSeconds!)}',
                  ),
                };
              },
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.library_music_outlined,
              label:
                  'Catalogue ${formatListeningTime(stats.totalDurationSeconds)}',
            ),
            if (stats.favoriteCount > 0)
              _InfoChip(
                icon: Icons.favorite_outline,
                label: '${stats.favoriteCount} favoris',
              ),
            _InfoChip(
              icon: Icons.event_available_outlined,
              label: 'Abonné ${formatDate(subscribedAt)}',
            ),
          ],
        ),
      ],
    );
  }
}

int _statColumnCount(double width) {
  const minTileWidth = 150.0;
  return (width / minTileWidth).floor().clamp(1, 4);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
