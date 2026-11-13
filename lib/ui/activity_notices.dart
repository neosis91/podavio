import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/activity_messages.dart';
import '../data/download_controller.dart';
import '../data/feed_refresh_controller.dart';
import '../data/online_status.dart';
import '../data/opml_import_controller.dart';

import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import 'router.dart';

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

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  var _refreshOpen = false;
  var _opmlOpen = false;
  var _hadNotices = false;
  var _closing = false;

  void _closeWhenEmpty(List<ActivityNotice> order) {
    if (order.isNotEmpty) {
      _hadNotices = true;
      return;
    }
    if (!_hadNotices || _closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = activityNoticesOf(ref);
    _closeWhenEmpty(order);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: order.isEmpty
              ? const _EmptyNotices()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final notice in order)
                      if (notice == ActivityNotice.messages)
                        ..._messageCards()
                      else
                        _card(notice),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _card(ActivityNotice notice) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: pureBlackOutline(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: _line(notice),
    );
    final dismiss = _dismissOf(notice);
    if (dismiss == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(dismiss.key),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(Alignment.centerLeft),
        secondaryBackground: _swipeBackground(Alignment.centerRight),
        onDismissed: (_) => dismiss.clear(),
        child: card,
      ),
    );
  }

  ({String key, VoidCallback clear})? _dismissOf(ActivityNotice notice) {
    return switch (notice) {
      ActivityNotice.refresh =>
        ref.watch(feedRefreshProvider).isRunning
            ? null
            : (
                key: 'refresh',
                clear: () => ref.read(feedRefreshProvider.notifier).dismiss(),
              ),
      ActivityNotice.opml =>
        ref.watch(opmlImportProvider).isRunning
            ? null
            : (
                key: 'opml',
                clear: () => ref.read(opmlImportProvider.notifier).dismiss(),
              ),
      _ => null,
    };
  }

  Widget _swipeBackground(Alignment alignment) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.done, color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }

  Color _accent(ActivityNotice notice) {
    final scheme = Theme.of(context).colorScheme;
    return switch (notice) {
      ActivityNotice.offline => podavioRed,
      ActivityNotice.downloads => scheme.primary,
      ActivityNotice.refresh =>
        ref.watch(feedRefreshProvider).failures.isNotEmpty &&
                !ref.watch(feedRefreshProvider).isRunning
            ? scheme.error
            : scheme.primary,
      ActivityNotice.opml =>
        ref.watch(opmlImportProvider).failures.isNotEmpty &&
                !ref.watch(opmlImportProvider).isRunning
            ? scheme.error
            : scheme.primary,
      ActivityNotice.messages => scheme.primary,
    };
  }

  Widget _line(ActivityNotice notice) {
    return switch (notice) {
      ActivityNotice.offline => _textLine(
        icon: Icons.wifi_off,
        accent: _accent(notice),
        title: context.tr('No internet connection'),
      ),
      ActivityNotice.downloads => _downloadLine(),
      ActivityNotice.refresh => _refreshLine(),
      ActivityNotice.opml => _opmlLine(),
      ActivityNotice.messages => const SizedBox.shrink(),
    };
  }

  List<Widget> _messageCards() {
    final scheme = Theme.of(context).colorScheme;
    final messages = ref.watch(activityMessagesProvider);
    return [
      for (final message in messages)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey('message-${message.id}'),
            direction: DismissDirection.horizontal,
            background: _swipeBackground(Alignment.centerLeft),
            secondaryBackground: _swipeBackground(Alignment.centerRight),
            onDismissed: (_) =>
                ref.read(activityMessagesProvider.notifier).dismiss(message.id),
            child: Material(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: pureBlackOutline(scheme),
              ),
              clipBehavior: Clip.antiAlias,
              child: _textLine(
                icon: Icons.info_outline,
                accent: scheme.primary,
                title: message.text,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _downloadLine() {
    final activity = downloadActivityProgress(
      running: ref.watch(downloadProgressProvider).values,
      waiting: ref.watch(downloadWaitingCountProvider),
    );
    final detail = activity.remaining == 1
        ? context.tr('1 episode left')
        : context.tr('{count} episodes left', {
            'count': '${activity.remaining}',
          });
    return _textLine(
      icon: Icons.download_outlined,
      accent: _accent(ActivityNotice.downloads),
      title: 'Téléchargement',
      subtitle: detail,
      progress: activity.progress,
    );
  }

  Widget _refreshLine() {
    final refresh = ref.watch(feedRefreshProvider);
    final hasErrors = refresh.failures.isNotEmpty;
    final left = podcastsLeftToRefresh(
      done: refresh.done,
      total: refresh.total,
    );
    final remaining = left == 1
        ? context.tr('1 podcast to refresh')
        : context.tr('{count} podcasts to refresh', {'count': '$left'});
    final subtitle = refresh.isRunning
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
      accent: _accent(ActivityNotice.refresh),
      title: 'Actualisation',
      subtitle: subtitle,
      progress: refresh.isRunning ? refresh.progress : null,
      onTap: hasErrors
          ? () => setState(() => _refreshOpen = !_refreshOpen)
          : null,
      trailing: hasErrors
          ? Icon(
              _refreshOpen ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      details: _refreshOpen && hasErrors
          ? [
              for (final failure in refresh.failures)
                _failure(failure.title, failure.message),
            ]
          : const [],
    );
  }

  Widget _opmlLine() {
    final import = ref.watch(opmlImportProvider);
    final hasErrors = import.failures.isNotEmpty;
    final subtitle = import.isRunning
        ? hasErrors
              ? '${import.done} / ${import.total} · ${import.failed} échec${import.failed > 1 ? 's' : ''}'
              : '${import.done} / ${import.total}'
        : import.failed == 0
        ? '${import.imported} abonnements importés'
        : '${import.imported} importés, ${import.failed} en échec';
    return _textLine(
      icon: import.isRunning
          ? Icons.cloud_download_outlined
          : hasErrors
          ? Icons.error_outline
          : Icons.check_circle_outline,
      accent: _accent(ActivityNotice.opml),
      title: 'Import OPML',
      subtitle: subtitle,
      progress: import.isRunning ? import.progress : null,
      onTap: hasErrors ? () => setState(() => _opmlOpen = !_opmlOpen) : null,
      trailing: hasErrors
          ? Icon(
              _opmlOpen ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      details: _opmlOpen && hasErrors
          ? [
              for (final failure in import.failures)
                _failure(failure.title, failure.message),
            ]
          : const [],
    );
  }

  Widget _failure(String title, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _textLine({
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
    double? progress,
    VoidCallback? onTap,
    Widget? trailing,
    List<Widget> details = const [],
  }) {
    final scheme = Theme.of(context).colorScheme;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.16),
                    ),
                  ),
                ],
                ...details,
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class _EmptyNotices extends StatelessWidget {
  const _EmptyNotices();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.notifications_none,
          size: 48,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Aucune notification',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
        onTap: () => context.push(AppRoutes.activity),
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
