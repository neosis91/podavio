import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download_controller.dart';
import '../../l10n/l10n.dart';

/// Nombre de téléchargements en cours, et ceux qui attendent un créneau.
class DownloadBanner extends ConsumerWidget {
  const DownloadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(downloadProgressProvider).length;
    final waiting = ref.watch(downloadWaitingCountProvider);
    if (running == 0 && waiting == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final parallel = running == 1
        ? context.tr('1 parallel download')
        : context.tr('{count} parallel downloads', {'count': '$running'});
    final label = waiting == 0
        ? parallel
        : '$parallel · ${waiting == 1 ? context.tr('1 waiting') : context.tr('{count} waiting', {'count': '$waiting'})}';

    return SafeArea(
      bottom: false,
      child: Material(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.download_outlined,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
