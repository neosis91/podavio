import 'package:flutter/material.dart';

import '../data/listening_activity.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/frosted_header.dart';

const _weekLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _weekNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const _monthLetters = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];
const _monthShort = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key, required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final week = activity.weekExtremes;
    final year = activity.yearExtremes;
    final days = activity.weekdayExtremes;
    return ListView(
      padding: belowFrostedBar(
        context,
        const EdgeInsets.fromLTRB(16, 16, 16, 32),
      ),
      children: [
        _TotalCard(activity: activity),
        if (activity.dailyStreak == 0) ...[
          const SizedBox(height: 12),
          const _AdventureBanner(),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StreakCard(
                icon: Icons.local_fire_department,
                iconColor: scheme.primary,
                title: 'Série quotidienne',
                value: _count(activity.dailyStreak, 'jour', 'jours'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StreakCard(
                icon: Icons.bolt,
                iconColor: scheme.tertiary,
                title: 'Série hebdomadaire',
                value: _count(activity.weeklyStreak, 'semaine', 'semaines'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PeriodCard(
          title: 'Cette semaine',
          chart: _WeekDots(activity: activity),
          busiest: _join(_weekNames, week.busiest),
          calmest: _join(_weekNames, week.calmest),
        ),
        const SizedBox(height: 12),
        _PeriodCard(
          title: 'Cette année',
          chart: _YearBars(activity: activity),
          busiest: _join(_monthNames, year.busiest),
          calmest: _join(_monthNames, year.calmest),
        ),
        const SizedBox(height: 12),
        _HeatmapCard(activity: activity),
        const SizedBox(height: 12),
        _InsightsCard(activity: activity, days: days),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Temps total d’écoute',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _duration(activity.totalSeconds),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Appuyez pour voir le détail',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ListeningDetail(activity: activity),
    );
  }
}

class _ListeningDetail extends StatelessWidget {
  const _ListeningDetail({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = activity.monthsWithListening;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Temps d’écoute', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            _duration(activity.totalSeconds),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'Les mois apparaîtront après une première lecture.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_capital(_monthNames[row.month - 1])} ${row.year}',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          _duration(row.seconds),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AdventureBanner extends StatelessWidget {
  const _AdventureBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = scheme.primaryContainer.withValues(alpha: 0.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.outlined_flag, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commencez votre aventure !',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chaque aventure commence par un premier pas. '
                    'Écoutez aujourd’hui et commencez votre prochaine série !',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: _cardDecoration(theme.colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.title,
    required this.chart,
    required this.busiest,
    required this.calmest,
  });

  final String title;
  final Widget chart;
  final String busiest;
  final String calmest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: _cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            chart,
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Extreme(label: 'Le plus actif', value: busiest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Extreme(label: 'Le plus calme', value: calmest),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Extreme extends StatelessWidget {
  const _Extreme({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seconds = [for (var i = 0; i < 7; i++) activity.weekDaySeconds(i)];
    final elapsed = [
      for (var i = 0; i < 7; i++)
        if (!activity.weekDayIsFuture(i)) seconds[i],
    ];
    final maxSeconds = elapsed.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              children: [
                _Dot(
                  color: _dotColor(
                    scheme,
                    seconds: seconds[i],
                    maxSeconds: maxSeconds,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weekLetters[i],
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _YearBars extends StatelessWidget {
  const _YearBars({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seconds = [
      for (var month = 1; month <= 12; month++) activity.monthSeconds(month),
    ];
    final maxSeconds = seconds.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 12; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 88,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: maxSeconds == 0 || seconds[i] == 0
                        ? const SizedBox(width: 8)
                        : Container(
                            width: 8,
                            height: 8 + 80 * (seconds[i] / maxSeconds),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_monthLetters[i], style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = _monthShort[activity.semesterStartMonth - 1];
    final end = _monthShort[activity.semesterEndMonth - 1];
    return DecoratedBox(
      decoration: _cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Activité d’écoute : ${activity.year}, $start-$end '
              '(${_duration(activity.semesterSeconds)})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _Heatmap(activity: activity),
            const SizedBox(height: 10),
            const _HeatLegend(),
          ],
        ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activity});

  final ListeningActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final weeks = activity.semesterWeeks;
    var maxSeconds = 0;
    for (final week in weeks) {
      for (final day in week.days) {
        final seconds = day?.seconds ?? 0;
        if (seconds > maxSeconds) maxSeconds = seconds;
      }
    }
    const gap = 2.0;
    const labelWidth = 14.0;
    const monthLabelHeight = 14.0;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      height: 1,
    );
    if (weeks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = (constraints.maxWidth - labelWidth).clamp(
          0.0,
          double.infinity,
        );
        final stride = gridWidth / weeks.length;
        Widget square(HeatDay? day) {
          final level = day == null ? -1 : _heatLevel(day.seconds, maxSeconds);
          return SizedBox(
            height: stride,
            child: Padding(
              padding: const EdgeInsets.all(gap / 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: level < 0
                      ? Colors.transparent
                      : _heatColor(scheme, level),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Column(
                children: [
                  const SizedBox(height: monthLabelHeight),
                  for (var i = 0; i < 7; i++)
                    SizedBox(
                      height: stride,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          i.isEven ? _weekLetters[i] : '',
                          style: labelStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: monthLabelHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < weeks.length; i++)
                          if (weeks[i].labelMonth != null)
                            Positioned(
                              left: i * stride,
                              top: 0,
                              child: Text(
                                _monthShort[weeks[i].labelMonth! - 1],
                                style: labelStyle,
                              ),
                            ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final week in weeks)
                        Expanded(
                          child: Column(
                            children: [
                              for (final day in week.days) square(day),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Moins', style: style),
        const SizedBox(width: 6),
        for (var level = 0; level < 5; level++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _heatColor(scheme, level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 3),
        Text('Plus', style: style),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.activity, required this.days});

  final ListeningActivity activity;
  final IndexExtreme days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCategory = activity.categories.isEmpty
        ? 0
        : activity.categories.first.seconds;
    return DecoratedBox(
      decoration: _cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Catégories les plus populaires',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (activity.categories.isEmpty)
              Text(
                'Aucune catégorie pour le moment.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final category in activity.categories.take(6)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _duration(category.seconds),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: maxCategory == 0
                        ? 0
                        : category.seconds / maxCategory,
                    minHeight: 6,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Text(
              'Jour le plus populaire',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _join(_weekNames, days.busiest, capital: true),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Text(
              'Jour le moins populaire',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _join(_weekNames, days.calmest, capital: true),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(ColorScheme scheme) {
  return BoxDecoration(
    color: scheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
  );
}

Color _dotColor(
  ColorScheme scheme, {
  required int seconds,
  required int maxSeconds,
}) {
  if (seconds <= 0 || maxSeconds <= 0) return scheme.surfaceContainerHighest;
  if (seconds == maxSeconds) return scheme.primary;
  return scheme.primary.withValues(alpha: 0.38);
}

int _heatLevel(int seconds, int maxSeconds) {
  if (seconds <= 0 || maxSeconds <= 0) return 0;
  final ratio = seconds / maxSeconds;
  if (ratio > 0.75) return 4;
  if (ratio > 0.5) return 3;
  if (ratio > 0.25) return 2;
  return 1;
}

Color _heatColor(ColorScheme scheme, int level) {
  const alphas = [0.14, 0.32, 0.5, 0.72, 1.0];
  return scheme.primary.withValues(alpha: alphas[level.clamp(0, 4)]);
}

String _duration(int seconds) {
  if (seconds <= 0) return '0 minute';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return _count(minutes, 'minute', 'minutes');
  if (minutes == 0) return _count(hours, 'heure', 'heures');
  return '$hours h $minutes min';
}

String _count(int value, String one, String many) {
  final word = value <= 1 ? one : many;
  return '$value $word';
}

String _join(List<String> names, List<int> indexes, {bool capital = false}) {
  if (indexes.isEmpty) return '—';
  return [
    for (final index in indexes)
      capital ? _capital(names[index]) : names[index],
  ].join(', ');
}

String _capital(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
