import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../settings/settings_controller.dart';
import '../widgets/selection_chip.dart';

/// Rangée de filtres sous le titre, comme les abonnements.
class EpisodeFilterChips extends StatelessWidget
    implements PreferredSizeWidget {
  const EpisodeFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final EpisodeFilters filters;
  final ValueChanged<EpisodeFilters> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final chips = <(String, bool, EpisodeFilters)>[
      (
        context.tr('Unplayed'),
        filters.unreadOnly,
        filters.copyWith(unreadOnly: !filters.unreadOnly),
      ),
      (
        context.tr('Downloaded'),
        filters.downloadsOnly,
        filters.copyWith(downloadsOnly: !filters.downloadsOnly),
      ),
      (
        context.tr('In progress'),
        filters.inProgressOnly,
        filters.copyWith(inProgressOnly: !filters.inProgressOnly),
      ),
    ];

    return SizedBox(
      height: preferredSize.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final (label, selected, next) = chips[index];
          return SelectionChip(
            label: label,
            selected: selected,
            onSelected: () => onChanged(next),
          );
        },
      ),
    );
  }
}

Future<void> showEpisodeFilterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  var draft = ref.read(settingsProvider).episodeFilters;
  final applied = await showDialog<EpisodeFilters>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.tr('Filter')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Unplayed')),
                    value: draft.unreadOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(unreadOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Downloaded')),
                    value: draft.downloadsOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(downloadsOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('In progress')),
                    subtitle: Text(context.tr('Started and not finished')),
                    value: draft.inProgressOnly,
                    onChanged: (value) {
                      setState(() {
                        draft = draft.copyWith(inProgressOnly: value ?? false);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, EpisodeFilters.empty),
                child: Text(context.tr('Clear')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: Text(context.tr('Apply')),
              ),
            ],
          );
        },
      );
    },
  );
  if (applied == null) return;
  await ref.read(settingsProvider.notifier).setEpisodeFilters(applied);
}
