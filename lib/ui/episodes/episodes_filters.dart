import 'package:flutter/material.dart';

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
