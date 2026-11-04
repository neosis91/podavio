import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/activity_messages.dart';
import '../data/download_controller.dart';
import '../data/feed_refresh_controller.dart';
import '../data/online_status.dart';
import '../data/opml_import_controller.dart';
import '../l10n/l10n.dart';
import 'widgets/app_bottom_sheet.dart';

/// Avis affichés par le bouton à gauche du menu.
enum ActivityNotice { offline, refresh, downloads, opml, messages }

/// Hors ligne d’abord. Sinon l’actualisation, puis les téléchargements.
/// Un téléchargement en cours passe devant l’actualisation.
/// Les messages ponctuels ferment la liste.
List<ActivityNotice> activityNoticeOrder({
  required bool offline,
  required bool refresh,
  required bool downloads,
  required bool opml,
  required bool messages,
}) {
  final order = <ActivityNotice>[];
  if (offline) order.add(ActivityNotice.offline);
  if (downloads) {
    order.add(ActivityNotice.downloads);
    if (refresh) order.add(ActivityNotice.refresh);
  } else if (refresh) {
    order.add(ActivityNotice.refresh);
  }
  if (opml) order.add(ActivityNotice.opml);
  if (messages) order.add(ActivityNotice.messages);
  return order;
}

IconData activityNoticeIcon(List<ActivityNotice> order) {
  if (order.isEmpty) return Icons.notifications_none;
  return switch (order.first) {
    ActivityNotice.offline => Icons.wifi_off,
    ActivityNotice.refresh => Icons.sync,
    ActivityNotice.downloads => Icons.download_outlined,
    ActivityNotice.opml => Icons.cloud_download_outlined,
    ActivityNotice.messages => Icons.notifications,
  };
}

/// Épisodes encore à récupérer, et part déjà écrite des fichiers en cours.
/// Les fichiers en attente comptent dans le reste, avec une progression nulle.
({int remaining, double progress}) downloadActivityProgress({
  required Iterable<double> running,
  required int waiting,
}) {
  final remaining = running.length + waiting;
  if (remaining == 0) return (remaining: 0, progress: 0);
  final written = running.fold<double>(0, (sum, value) => sum + value);
  return (remaining: remaining, progress: written / remaining);
}

/// Podcasts pas encore traités dans l’actualisation en cours.
int podcastsLeftToRefresh({required int done, required int total}) {
  return (total - done).clamp(0, total);
}

List<ActivityNotice> activityNoticesOf(WidgetRef ref) {
  final offline = ref.watch(onlineStatusProvider) == false;
  final refresh = ref.watch(feedRefreshProvider).isVisible;
  final downloads =
      ref.watch(downloadProgressProvider).isNotEmpty ||
      ref.watch(downloadWaitingCountProvider) > 0;
  final opml = ref.watch(opmlImportProvider).isVisible;
  final messages = ref.watch(activityMessagesProvider).isNotEmpty;
  return activityNoticeOrder(
    offline: offline,
    refresh: refresh,
    downloads: downloads,
    opml: opml,
    messages: messages,
  );
}

void showActivityNotices(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    // La feuille peint elle-même son fond, qui suit l’avis prioritaire.
    backgroundColor: Colors.transparent,
    builder: (context) => const _ActivitySheet(),
  );
}

class _ActivitySheet extends ConsumerStatefulWidget {
  const _ActivitySheet();

  @override
  ConsumerState<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends ConsumerState<_ActivitySheet> {
  var _refreshOpen = false;
  var _opmlOpen = false;

  @override
  Widget build(BuildContext context) {
    final order = activityNoticesOf(ref);
    final colors = _sheetColors(context, order);
    final text = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: colors.foreground);
    return Material(
      color: colors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 32,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.foreground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            if (order.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Text('Aucune notification', style: text),
              )
            else
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                children: [
                  for (final notice in order) _line(notice, colors.foreground),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Fond et texte de l’avis le plus prioritaire.
  ({Color background, Color foreground}) _sheetColors(
    BuildContext context,
    List<ActivityNotice> order,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (order.isEmpty) {
      return (
        background: scheme.surfaceContainerLow,
        foreground: scheme.onSurface,
      );
    }
    return switch (order.first) {
      ActivityNotice.offline => (
        background: podavioRed,
        foreground: Colors.white,
      ),
      ActivityNotice.downloads => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
      ActivityNotice.refresh => _statusColors(
        scheme,
        failed: ref.watch(feedRefreshProvider).failures.isNotEmpty,
        running: ref.watch(feedRefreshProvider).isRunning,
      ),
      ActivityNotice.opml => _statusColors(
        scheme,
        failed: ref.watch(opmlImportProvider).failures.isNotEmpty,
        running: ref.watch(opmlImportProvider).isRunning,
      ),
      ActivityNotice.messages => (
        background: scheme.surfaceContainerLow,
        foreground: scheme.onSurface,
      ),
    };
  }

  ({Color background, Color foreground}) _statusColors(
    ColorScheme scheme, {
    required bool failed,
    required bool running,
  }) {
    if (failed && !running) {
      return (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
    }
    return (
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
    );
  }

  Widget _line(ActivityNotice notice, Color color) {
    return switch (notice) {
      ActivityNotice.offline => _textLine(
        icon: Icons.wifi_off,
        label: context.tr('No internet connection'),
        color: color,
      ),
      ActivityNotice.downloads => _downloadLine(color),
      ActivityNotice.refresh => _refreshLine(color),
      ActivityNotice.opml => _opmlLine(color),
      ActivityNotice.messages => _messages(color),
    };
  }

  Widget _messages(Color color) {
    final messages = ref.watch(activityMessagesProvider);
    return Column(
      children: [
        for (final message in messages)
          _textLine(
            icon: Icons.info_outline,
            label: message.text,
            color: color,
            trailing: [
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => ref
                    .read(activityMessagesProvider.notifier)
                    .dismiss(message.id),
                icon: Icon(Icons.close, color: color),
              ),
            ],
          ),
      ],
    );
  }

  Widget _downloadLine(Color color) {
    final activity = downloadActivityProgress(
      running: ref.watch(downloadProgressProvider).values,
      waiting: ref.watch(downloadWaitingCountProvider),
    );
    final label = activity.remaining == 1
        ? context.tr('1 episode left')
        : context.tr('{count} episodes left', {
            'count': '${activity.remaining}',
          });
    return _textLine(
      icon: Icons.download_outlined,
      label: label,
      color: color,
      progress: activity.progress,
      progressAroundIcon: true,
    );
  }

  Widget _refreshLine(Color color) {
    final refresh = ref.watch(feedRefreshProvider);
    final hasErrors = refresh.failures.isNotEmpty;
    final left = podcastsLeftToRefresh(
      done: refresh.done,
      total: refresh.total,
    );
    final remaining = left == 1
        ? context.tr('1 podcast to refresh')
        : context.tr('{count} podcasts to refresh', {'count': '$left'});
    final label = refresh.isRunning
        ? hasErrors
              ? '$remaining · ${refresh.failed} échec${refresh.failed > 1 ? 's' : ''}'
              : remaining
        : refresh.failed == 0
        ? 'Abonnements actualisés'
        : '${refresh.refreshed} actualisés, ${refresh.failed} en échec';
    return _textLine(
      icon: refresh.isRunning
          ? Icons.sync
          : hasErrors
          ? Icons.error_outline
          : Icons.check_circle_outline,
      label: label,
      color: color,
      progress: refresh.isRunning ? refresh.progress : null,
      progressAroundIcon: refresh.isRunning,
      trailing: [
        if (hasErrors)
          IconButton(
            tooltip: _refreshOpen ? 'Masquer les erreurs' : 'Voir les erreurs',
            onPressed: () => setState(() => _refreshOpen = !_refreshOpen),
            icon: Icon(
              _refreshOpen ? Icons.expand_less : Icons.expand_more,
              color: color,
            ),
          ),
        if (!refresh.isRunning)
          IconButton(
            tooltip: 'Fermer',
            onPressed: () {
              setState(() => _refreshOpen = false);
              ref.read(feedRefreshProvider.notifier).dismiss();
            },
            icon: Icon(Icons.close, color: color),
          ),
      ],
      details: _refreshOpen && hasErrors
          ? [
              for (final failure in refresh.failures)
                _failure(failure.title, failure.message, color),
            ]
          : const [],
    );
  }

  Widget _opmlLine(Color color) {
    final import = ref.watch(opmlImportProvider);
    final hasErrors = import.failures.isNotEmpty;
    final label = import.isRunning
        ? hasErrors
              ? 'Import OPML · ${import.done} / ${import.total} · ${import.failed} échec${import.failed > 1 ? 's' : ''}'
              : 'Import OPML · ${import.done} / ${import.total}'
        : import.failed == 0
        ? '${import.imported} abonnements importés'
        : '${import.imported} importés, ${import.failed} en échec';
    return _textLine(
      icon: import.isRunning
          ? Icons.cloud_download_outlined
          : hasErrors
          ? Icons.error_outline
          : Icons.check_circle_outline,
      label: label,
      color: color,
      progress: import.isRunning ? import.progress : null,
      trailing: [
        if (hasErrors)
          IconButton(
            tooltip: _opmlOpen ? 'Masquer les erreurs' : 'Voir les erreurs',
            onPressed: () => setState(() => _opmlOpen = !_opmlOpen),
            icon: Icon(
              _opmlOpen ? Icons.expand_less : Icons.expand_more,
              color: color,
            ),
          ),
        if (!import.isRunning)
          IconButton(
            tooltip: 'Fermer',
            onPressed: () {
              setState(() => _opmlOpen = false);
              ref.read(opmlImportProvider.notifier).dismiss();
            },
            icon: Icon(Icons.close, color: color),
          ),
      ],
      details: _opmlOpen && hasErrors
          ? [
              for (final failure in import.failures)
                _failure(failure.title, failure.message, color),
            ]
          : const [],
    );
  }

  Widget _failure(String title, String message, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _textLine({
    required IconData icon,
    required String label,
    required Color color,
    double? progress,
    bool progressAroundIcon = false,
    List<Widget> trailing = const [],
    List<Widget> details = const [],
  }) {
    final glyph = progressAroundIcon
        ? SizedBox.square(
            dimension: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.24),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
          )
        : Icon(icon, size: 20, color: color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null && !progressAroundIcon)
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              color: color,
              backgroundColor: color.withValues(alpha: 0.24),
            ),
          ),
        Row(
          children: [
            glyph,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: color),
              ),
            ),
            ...trailing,
          ],
        ),
        if (details.isNotEmpty) ...[const SizedBox(height: 8), ...details],
        const SizedBox(height: 12),
      ],
    );
  }
}

class ActivityButton extends ConsumerWidget {
  const ActivityButton({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final order = activityNoticesOf(ref);
    final downloads = downloadActivityProgress(
      running: ref.watch(downloadProgressProvider).values,
      waiting: ref.watch(downloadWaitingCountProvider),
    );
    final refresh = ref.watch(feedRefreshProvider);
    final podcastsLeft = podcastsLeftToRefresh(
      done: refresh.done,
      total: refresh.total,
    );
    final messageCount = ref.watch(activityMessagesProvider).length;
    final idle = order.isEmpty;
    final offline = order.contains(ActivityNotice.offline);
    final color = idle
        ? scheme.onSurfaceVariant
        : offline
        ? podavioRed
        : scheme.primary;
    final primary = order.isEmpty ? null : order.first;
    final showDownloadRing =
        primary == ActivityNotice.downloads && downloads.remaining > 0;
    final showRefreshRing =
        primary == ActivityNotice.refresh && refresh.isRunning;
    final showMessageCount =
        primary == ActivityNotice.messages && messageCount > 0;
    final badge = showDownloadRing
        ? downloads.remaining
        : showRefreshRing && podcastsLeft > 0
        ? podcastsLeft
        : showMessageCount
        ? messageCount
        : order.length > 1
        ? order.length
        : null;
    final notes = <String>[
      if (downloads.remaining > 0)
        downloads.remaining == 1
            ? context.tr('1 episode left')
            : context.tr('{count} episodes left', {
                'count': '${downloads.remaining}',
              }),
      if (refresh.isRunning && podcastsLeft > 0)
        podcastsLeft == 1
            ? context.tr('1 podcast to refresh')
            : context.tr('{count} podcasts to refresh', {
                'count': '$podcastsLeft',
              }),
    ];
    final showRing = showDownloadRing || showRefreshRing;
    return Material(
      color: scheme.surfaceContainer,
      shape: CircleBorder(
        side: showRing ? BorderSide.none : pureBlackOutline(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showActivityNotices(context),
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Tooltip(
            message: notes.isNotEmpty
                ? notes.join(' · ')
                : messageCount > 0
                ? ref.watch(activityMessagesProvider).first.text
                : 'Notifications',
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showRing)
                  SizedBox.square(
                    dimension: size,
                    child: CircularProgressIndicator(
                      value: showDownloadRing
                          ? downloads.progress
                          : refresh.progress,
                      strokeWidth: 3,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.22),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activityNoticeIcon(order),
                      color: color,
                      size: badge == null ? 24 : 20,
                    ),
                    if (badge != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
