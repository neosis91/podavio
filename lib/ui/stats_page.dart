import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiques'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Abonnements'),
              Tab(text: 'Années'),
              Tab(text: 'Téléchargements'),
            ],
          ),
        ),
        body: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            title: 'Statistiques indisponibles',
            message: error.toString(),
          ),
          data: (value) => TabBarView(
            children: [
              _SubscriptionsTab(stats: value),
              _YearsTab(stats: value),
              _DownloadsTab(stats: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.subscriptions.isEmpty) {
      return const EmptyState(
        title: 'Aucun abonnement',
        message: 'Abonnez-vous à un podcast pour voir ses statistiques.',
      );
    }

    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: stats.subscriptions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${stats.podcastCount} abonnements · '
              '${formatListeningTime(stats.totalListenedSeconds)} d’écoute',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final item = stats.subscriptions[index - 1];
        return _SubscriptionTile(item: item);
      },
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.item});

  final SubscriptionStat item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progress;
    return ListTile(
      leading: PodcastCover(url: item.imageUrl, size: 48, radius: 8),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${formatListeningTime(item.listenedSeconds)} · '
            '${item.completedCount}/${item.episodeCount} terminés',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.push(AppRoutes.podcast(item.podcastId)),
    );
  }
}

class _YearsTab extends StatefulWidget {
  const _YearsTab({required this.stats});

  final LibraryStats stats;

  @override
  State<_YearsTab> createState() => _YearsTabState();
}

class _YearsTabState extends State<_YearsTab> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.stats.years.first.year;
  }

  @override
  void didUpdateWidget(covariant _YearsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final years = {for (final year in widget.stats.years) year.year};
    if (!years.contains(_selectedYear) && widget.stats.years.isNotEmpty) {
      _selectedYear = widget.stats.years.first.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    if (stats.years.isEmpty) {
      return const EmptyState(
        title: 'Pas encore d’historique',
        message:
            'Les années d’écoute apparaîtront après vos premières lectures.',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = stats.years.firstWhere(
      (year) => year.year == _selectedYear,
      orElse: () => stats.years.first,
    );
    final months = selected.months;
    final maxSeconds = months
        .map((item) => item.listenedSeconds)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (stats.years.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stats.years.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final year = stats.years[index].year;
                final selectedYear = year == _selectedYear;
                return ChoiceChip(
                  label: Text('$year'),
                  selected: selectedYear,
                  onSelected: (_) => setState(() => _selectedYear = year),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Temps d’écoute · $_selectedYear',
          style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxSeconds.toDouble() * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final month = months[group.x.toInt()];
                    return BarTooltipItem(
                      '${formatMonthShort(month.month)} '
                      '${month.year}\n'
                      '${formatListeningTime(month.listenedSeconds)}',
                      TextStyle(color: scheme.onInverseSurface),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      // Affiche un label tous les 2 mois pour rester lisible.
                      if (index.isOdd) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          formatMonthShort(months[index].month),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: months[i].listenedSeconds.toDouble(),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: scheme.primary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final year in stats.years) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${year.year}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: year.year == _selectedYear
                              ? scheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedYear = year.year),
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatListeningTime(year.listenedSeconds),
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${year.completedCount} terminés · '
                                '${year.startedCount} lancés',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final month in year.months.where(
                    (item) =>
                        item.listenedSeconds > 0 ||
                        item.startedCount > 0 ||
                        item.completedCount > 0,
                  )) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              formatMonthShort(month.month),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              formatListeningTime(month.listenedSeconds),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${month.completedCount} terminés',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}


class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.downloads.isEmpty) {
      return const EmptyState(
        title: 'Aucun téléchargement',
        message: 'Les épisodes hors ligne apparaîtront ici avec l’espace utilisé.',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxBytes = stats.downloads
        .map((item) => item.downloadBytes)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 62);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: stats.downloads.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatBytes(stats.totalDownloadBytes),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stats.totalDownloadCount} fichiers téléchargés',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        final item = stats.downloads[index - 1];
        final ratio = (item.downloadBytes / maxBytes).clamp(0.0, 1.0);
        return ListTile(
          leading: PodcastCover(url: item.imageUrl, size: 48, radius: 8),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${item.downloadCount} fichiers · ${formatBytes(item.downloadBytes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () => context.push(AppRoutes.podcast(item.podcastId)),
        );
      },
    );
  }
}
