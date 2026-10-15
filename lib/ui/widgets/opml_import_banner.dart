import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/opml_import_controller.dart';

class OpmlImportBanner extends ConsumerStatefulWidget {
  const OpmlImportBanner({super.key});

  @override
  ConsumerState<OpmlImportBanner> createState() => _OpmlImportBannerState();
}

class _OpmlImportBannerState extends ConsumerState<OpmlImportBanner> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final import = ref.watch(opmlImportProvider);
    if (!import.isVisible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final hasErrors = import.failures.isNotEmpty;
    final label = import.isRunning
        ? hasErrors
              ? 'Import OPML · ${import.done} / ${import.total} · ${import.failed} échec${import.failed > 1 ? 's' : ''}'
              : 'Import OPML · ${import.done} / ${import.total}'
        : import.failed == 0
        ? '${import.imported} abonnements importés'
        : '${import.imported} importés, ${import.failed} en échec';

    return SafeArea(
      bottom: false,
      child: Material(
        color: hasErrors && !import.isRunning
            ? scheme.errorContainer
            : scheme.secondaryContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (import.isRunning)
              LinearProgressIndicator(
                value: import.progress,
                minHeight: 2,
                backgroundColor: scheme.secondaryContainer,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    import.isRunning
                        ? Icons.cloud_download_outlined
                        : hasErrors
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 20,
                    color: hasErrors && !import.isRunning
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasErrors && !import.isRunning
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
                        color: hasErrors && !import.isRunning
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  if (!import.isRunning)
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () {
                        setState(() => _expanded = false);
                        ref.read(opmlImportProvider.notifier).dismiss();
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
                  itemCount: import.failures.length,
                  itemBuilder: (context, index) {
                    final failure = import.failures[index];
                    final color = import.isRunning
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
