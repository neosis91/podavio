import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/automatic_downloads.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';

/// Abonnements dont les nouveaux épisodes se téléchargent tout seuls.
class AutomaticDownloadsPage extends ConsumerStatefulWidget {
  const AutomaticDownloadsPage({super.key});

  @override
  ConsumerState<AutomaticDownloadsPage> createState() =>
      _AutomaticDownloadsPageState();
}

class _AutomaticDownloadsPageState
    extends ConsumerState<AutomaticDownloadsPage> {
  var _selecting = false;
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final podcasts = ref.watch(podcastsProvider);
    final items = podcasts.asData?.value ?? const <Podcast>[];
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelection();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar(items) : _titleBar(),
        body: podcasts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            title: context.tr('Automatic download'),
            message: '$error',
          ),
          data: (loaded) {
            if (loaded.isEmpty) {
              return EmptyState(
                title: context.tr('No subscribed podcasts'),
                message: context.tr(
                  'Choose which subscriptions download new episodes, and how many.',
                ),
              );
            }
            final sorted = [...loaded]
              ..sort(
                (a, b) =>
                    a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              );
            return ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final podcast = sorted[index];
                return _PodcastRow(
                  podcast: podcast,
                  selecting: _selecting,
                  selected: _selected.contains(podcast.id),
                  onLongPress: () => _enterSelection(podcast.id),
                  onTap: _selecting
                      ? () => _toggleSelected(podcast.id)
                      : () => _showMenu([podcast]),
                  onMenu: () => _showMenu([podcast]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  AppBar _titleBar() {
    return AppBar(title: Text(context.tr('Automatic download')));
  }

  AppBar _selectionBar(List<Podcast> items) {
    final count = _selected.length;
    final all = items.isNotEmpty && count == items.length;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Annuler',
        onPressed: _exitSelection,
        icon: const Icon(Icons.close),
      ),
      title: Text(
        count == 0
            ? 'Sélection'
            : count == 1
            ? '1 sélectionné'
            : '$count sélectionnés',
      ),
      actions: [
        IconButton(
          tooltip: all ? 'Tout désélectionner' : 'Tout sélectionner',
          onPressed: items.isEmpty
              ? null
              : () => setState(() {
                  if (all) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(items.map((item) => item.id));
                  }
                }),
          icon: all ? const DeselectAllIcon() : const SelectAllIcon(),
        ),
        if (count > 0)
          IconButton(
            tooltip: 'Actions',
            onPressed: () => _showMenu(_podcastsFor(_selected.toList())),
            icon: const MoreVertIcon(),
          ),
      ],
    );
  }

  void _enterSelection(int id) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selecting = false;
    });
  }

  List<Podcast> _podcastsFor(List<int> ids) {
    final items = ref.read(podcastsProvider).asData?.value ?? const [];
    final wanted = ids.toSet();
    return [
      for (final podcast in items)
        if (wanted.contains(podcast.id)) podcast,
    ];
  }

  Future<void> _showMenu(List<Podcast> podcasts) async {
    if (podcasts.isEmpty || !mounted) return;
    final fromSelection = _selecting;
    final ids = [for (final podcast in podcasts) podcast.id];
    var changed = false;
    await showAutomaticDownloadSheet(
      context,
      enabled: podcasts.every((podcast) => podcast.autoDownload),
      selected: _sheetSelection(podcasts),
      onEnabled: (enabled) async {
        if (!mounted) return;
        changed = true;
        await ref
            .read(databaseProvider)
            .setPodcastsAutoDownload(ids, autoDownload: enabled);
        if (!mounted || !enabled) return;
        unawaited(ref.read(automaticDownloadRunProvider.notifier).run());
      },
      onLimit: (choice) async {
        if (!mounted) return;
        changed = true;
        await ref
            .read(databaseProvider)
            .setPodcastsAutoDownloadLimit(ids, choice == 0 ? null : choice);
        if (!mounted) return;
        unawaited(ref.read(automaticDownloadRunProvider.notifier).run());
      },
    );
    if (fromSelection && changed && mounted) _exitSelection();
  }

  /// `0` = illimité. `null` si les limites diffèrent.
  int? _sheetSelection(List<Podcast> podcasts) {
    int? shared;
    var seen = false;
    for (final podcast in podcasts) {
      final value = podcastAutoDownloadLimit(podcast.autoDownloadLimit) ?? 0;
      if (!seen) {
        shared = value;
        seen = true;
      } else if (shared != value) {
        return null;
      }
    }
    return shared;
  }
}

class _PodcastRow extends StatelessWidget {
  const _PodcastRow({
    required this.podcast,
    required this.selecting,
    required this.selected,
    required this.onLongPress,
    required this.onTap,
    required this.onMenu,
  });

  final Podcast podcast;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final limit = podcastAutoDownloadLimit(podcast.autoDownloadLimit);
    final limitLabel = context.tr(automaticDownloadLimitLabel(limit));
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(selecting ? 4 : 16, 8, 4, 8),
        child: Row(
          children: [
            if (selecting)
              Checkbox(value: selected, onChanged: (_) => onTap?.call()),
            PodcastCover(
              url: podcast.imageUrl,
              localPath: podcast.imagePath,
              label: podcast.title,
              httpHeaders: podcastAuthHeaders(
                username: podcast.authUsername,
                password: podcast.authPassword,
              ),
              size: 56,
              radius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Limite : $limitLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (podcast.autoDownload) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.downloading,
                          size: 18,
                          color: downloadActiveColor,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!selecting)
              IconButton(
                tooltip: 'Actions',
                onPressed: onMenu,
                icon: const MoreVertIcon(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur, puis la liste des limites. `0` = illimité.
///
/// L’interrupteur laisse la feuille ouverte. Choisir une limite la ferme.
Future<void> showAutomaticDownloadSheet(
  BuildContext context, {
  required bool enabled,
  required int? selected,
  required Future<void> Function(bool enabled) onEnabled,
  required Future<void> Function(int choice) onLimit,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Chrome à nous : la colonne partagée n’a pas de hauteur bornée pour
    // une liste, et la poignée la faisait déborder.
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _AutomaticDownloadSheet(
        enabled: enabled,
        selected: selected,
        onEnabled: onEnabled,
        onLimit: onLimit,
      );
    },
  );
}

class _AutomaticDownloadSheet extends StatefulWidget {
  const _AutomaticDownloadSheet({
    required this.enabled,
    required this.selected,
    required this.onEnabled,
    required this.onLimit,
  });

  final bool enabled;
  final int? selected;
  final Future<void> Function(bool enabled) onEnabled;
  final Future<void> Function(int choice) onLimit;

  @override
  State<_AutomaticDownloadSheet> createState() =>
      _AutomaticDownloadSheetState();
}

class _AutomaticDownloadSheetState extends State<_AutomaticDownloadSheet> {
  late var _enabled = widget.enabled;
  var _closed = false;

  Future<void> _choose(int value) async {
    if (_closed) return;
    _closed = true;
    await widget.onLimit(value);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final options = <({int value, String label})>[
      (value: 0, label: automaticDownloadLimitLabel(null)),
      for (final limit in automaticDownloadLimits)
        (value: limit, label: automaticDownloadLimitLabel(limit)),
    ];
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final listMax = constraints.maxHeight - 28;
        return Material(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const SheetDragHandle(),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMax),
                child: RadioGroup<int>(
                  groupValue: widget.selected,
                  onChanged: (value) {
                    if (value == null) return;
                    _choose(value);
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        title: Text(context.tr('Automatic download')),
                        value: _enabled,
                        onChanged: (value) async {
                          setState(() => _enabled = value);
                          await widget.onEnabled(value);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          context.tr(
                            'When this is on, the newest unplayed or in-progress episodes stay on the device, up to this limit. Finished episodes are not downloaded.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          context.tr('Download limit'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final option in options)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: Text(context.tr(option.label)),
                          leading: Radio<int>(value: option.value),
                          onTap: () => _choose(option.value),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
