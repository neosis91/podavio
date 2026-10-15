import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feed_refresh_controller.dart';

class FeedRefreshBanner extends ConsumerStatefulWidget {
  const FeedRefreshBanner({super.key});

  @override
  ConsumerState<FeedRefreshBanner> createState() => _FeedRefreshBannerState();
}

class _FeedRefreshBannerState extends ConsumerState<FeedRefreshBanner> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final refresh = ref.watch(feedRefreshProvider);
    if (!refresh.isVisible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final hasErrors = refresh.failures.isNotEmpty;
    final label = refresh.isRunning
        ? hasErrors
              ? 'Actualisation · ${refresh.done} / ${refresh.total} · ${refresh.failed} échec${refresh.failed > 1 ? 's' : ''}'
              : 'Actualisation · ${refresh.done} / ${refresh.total}'
        : refresh.failed == 0
        ? 'Abonnements actualisés'
        : '${refresh.refreshed} actualisés, ${refresh.failed} en échec';

    return SafeArea(
      bottom: false,
      child: Material(
        color: hasErrors && !refresh.isRunning
            ? scheme.errorContainer
            : scheme.secondaryContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (refresh.isRunning)
              LinearProgressIndicator(
                value: refresh.progress,
                minHeight: 2,
                backgroundColor: scheme.secondaryContainer,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    refresh.isRunning
                        ? Icons.sync
                        : hasErrors
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 20,
                    color: hasErrors && !refresh.isRunning
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasErrors && !refresh.isRunning
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (hasErrors)
                    IconButton(
                      tooltip: _expanded
                          ? 'Masquer les erreurs'
                          : 'Voir les erreurs',
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: hasErrors && !refresh.isRunning
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  if (!refresh.isRunning)
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () {
                        setState(() => _expanded = false);
                        ref.read(feedRefreshProvider.notifier).dismiss();
                      },
                      icon: Icon(
                        Icons.close,
                        color: hasErrors
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
            if (_expanded && hasErrors)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: refresh.failures.length,
                  itemBuilder: (context, index) {
                    final failure = refresh.failures[index];
                    final color = refresh.isRunning
                        ? scheme.onSecondaryContainer
                        : scheme.onErrorContainer;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            failure.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            failure.message,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
